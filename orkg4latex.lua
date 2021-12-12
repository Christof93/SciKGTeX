local PRODUCE_XMP_FILE = true
local WARNING_LEVEL = 1
local XMP = {}
XMP.lines = {}

local Annotation_object = {}
Annotation_object.whole_string = ""



Annotation_object.properties_used = {}

local PACKET_START = [[<?xpacket begin="" id="b0e1b454-39bf-11ec-8d3d-0242ac130003"?>]]

local XMP_TOP = [[<x:xmpmeta xmlns:x="adobe:ns:meta/">
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:orkg="http://orkg.org/core#"
  xmlns:orkg_property="http://orkg.org/property"
  xmlns:po="http://purl.org/spar/po#"
  xmlns:c4o="http://purl.org/spar/c4o#"
  xmlns:deo="http://purl.org/spar/deo#">]]

local XMP_BOTTOM = [[</rdf:RDF>
</x:xmpmeta>]]

local PACKET_END = [[<?xpacket end="r"?>]]

local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function string:split(sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in self:gmatch("([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

function XMP:add_line(...)
    table.insert(self.lines, string.format(...))
end

function XMP:add_paper_node(paper_iri) 
    self.paper = {}
    self.paper.contributions = {}
    self.paper.id = paper_iri
end

function XMP:add_contribution(key, contribution_iri)
    local contribution = {}
    contribution.properties = {}
    contribution.id = contribution_iri:gsub("<(default_contribution)>","ORKG_default")
    self.paper.contributions[key] = contribution
end

function XMP:add_annotation(contribution_ids, annotation_type, annotation_type_uri, content, annotation_id)
    local annotation = {}
    annotation.content = content
    annotation.id = annotation_id
    if contribution_ids == '' then
        contribution_ids = '<default_contribution>'
    end
    contributions_ids_t = contribution_ids:split(',%s?')

    if annotation_type_uri == '' then
        annotation_type_uri = 'https://www.orkg.org/orkg/property'
    elseif not uri_valid(annotation_type_uri) then 
        message = [[The given URI %s is not a valid choice!
            Please use a resolvable URI starting with 'http']]
        orkg_warn(message, annotation_type_uri)
    end

    annotation.type = annotation_type
    Annotation_object:register_property(annotation_type)
    -- add the annotations at the specified contribution
    for i, contribution_id in ipairs(contributions_ids_t) do
        if self.paper.contributions[contribution_id] == nil then
            self:add_contribution(contribution_id, 'contribution_'..contribution_id)
        end
        table.insert(self.paper.contributions[contribution_id].properties, annotation)
    end
end

function Annotation_object:set_warning_level(wl)
    WARNING_LEVEL = wl
end

function Annotation_object:add_property_to_list(p)
    if self.properties_used[p]~=nil then
        orkg_warn([[Command %s already exists!]], p)
    else
        self.properties_used[p] = false
    end
end

function escape_xml_content(s)
    s = s:gsub('&', '&amp;')
    return s:gsub('<', '&lt;')
end

function remove_latex_commands(s)
    return s:gsub('\\.-%s?{(.-)}','%1')
end

function uri_valid(s)
    if s:find('http') ~= 1 then
        return false
    else
        return true
    end
end

function orkg_warn(warning_message, ...)
    if WARNING_LEVEL > 0 then
        texio.write_nl("term and log", 
                [[Package orkg4latex Warning: ]] .. string.format(warning_message, ...))
    end
end 

function XMP:generate_xmp_string(lb_char)
    lb_char = lb_char or "\n"
    if lb_char == "r" then
        lb_char = "\r"
    end
    output_string = ""
    self:add_line(XMP_TOP)
    --print(debug.traceback())

    if self.paper then
        self:add_line('  <rdf:Description rdf:about="%s">', self.paper.id)
        self:add_line('    <rdf:type rdf:resource="http://orkg.org/core#Paper"/>')
        for cb_id, contribution in pairs(XMP.paper.contributions) do
            self:add_line('    <orkg:hasResearchContribution>')
            self:add_line('      <orkg:ResearchContribution rdf:about="%s">', contribution.id)
            for j, property in ipairs(contribution.properties) do
                self:add_line('          <orkg_property:%s>%s</orkg_property:%s>', property.type, 
                    escape_xml_content(remove_latex_commands(property.content)), property.type)
            end
            self:add_line('      </orkg:ResearchContribution>')
            self:add_line('    </orkg:hasResearchContribution>')
        end
        self:add_line('  </rdf:Description>')
    end
    self:add_line(XMP_BOTTOM)
    return table.concat(self.lines, lb_char)

end

function XMP:attach_metadata_pdfstream()
    local xmp_string = XMP:generate_xmp_string()
    local new_pdf = pdf.obj {
        type = 'stream',
        attr = '/Type/Metadata /Subtype/XML',
        immediate = true,
        compresslevel = 0,
        string = PACKET_START .. xmp_string .. PACKET_END,
    }
    self.lines = {}
    return new_pdf
end

function XMP:dump_metadata()
    local xmp_string = XMP:generate_xmp_string()
    f = io.open('xmp_metadata.xml','w')
    io.output(f)
    --io.write([[<?xml version="1.0" encoding="UTF-8"?>\n]])
    io.write(xmp_string)
    io.close(f)
end

function Annotation_object:register_property(prop_type)
    self.properties_used[prop_type] = true
end

function Annotation_object:get_environment_body()
    local str_without_end = Annotation_object.whole_string:gsub("\\end{.*}\n?","")
    return (trim(str_without_end))
end

function Annotation_object:remember_body()
    Annotation_object.whole_string = ""
    luatexbase.add_to_callback(
        "process_input_buffer",
        Annotation_object.add_input_line,
        "add_input_line")
end

function Annotation_object:stop_remember_body()
    luatexbase.remove_from_callback("process_input_buffer", "add_input_line")
end

function Annotation_object:add_input_line(input_line)
    Annotation_object.whole_string = Annotation_object.whole_string .. input_line .. " " 
end

function Annotation_object:warn_unused_environments()
    warning_message = [[No %s annotation found!
    Are you sure you don't want to mark an entity with %s?]]
    for env, val in pairs(self.properties_used) do
        if not val then
            orkg_warn(warning_message, env, env);
            -- tex.print(string.format(warning_message, env, env))
        end
    end
end

luatexbase.add_to_callback('stop_run', function()
    Annotation_object:warn_unused_environments()
end, 'at_end')

-- 1 Writing metadata packets
luatexbase.add_to_callback('finish_pdffile', function()
    if XMP.paper then
        local metadata_obj = XMP:attach_metadata_pdfstream()
        local catalog = pdf.getcatalog() or ''
        pdf.setcatalog(catalog..string.format('/Metadata %s 0 R', metadata_obj))
        if PRODUCE_XMP_FILE then
            XMP:dump_metadata()
        end
    end
end, 'finish')

-- TODO: real identifier assigned
XMP:add_paper_node('R1234565')

Annotation_object.XMP = XMP
return Annotation_object