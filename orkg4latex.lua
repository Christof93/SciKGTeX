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

local Annotation_object = {}
Annotation_object.whole_string = ""

Annotation_object.properties = {}

Annotation_object.properties_used = {}
for i, env in pairs(Annotation_object.properties) do 
    Annotation_object.properties_used[env] = false
end 

local XMP = {}
XMP.lines = {}

local xmp_top = [[<?xpacket begin="" id="b0e1b454-39bf-11ec-8d3d-0242ac130003"?>
<x:xmpmeta xmlns:x="adobe:ns:meta/">
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:orkg="http://orkg.org/core/"
  xmlns:po="http://purl.org/spar/po/"
  xmlns:c4o="http://purl.org/spar/c4o"
  xmlns:deo="http://purl.org/spar/deo">
  <rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:format>application/pdf</dc:format>
  </rdf:Description>]]

local xmp_bottom = [[</rdf:RDF>
</x:xmpmeta>
<?xpacket end="r"?>]]

function XMP:add_line(...)
    table.insert(XMP.lines, string.format(...))
end

function XMP:add_paper_node(paper_iri) 
    self.paper = {}
    self.paper.contributions = {}
    self.paper.id = paper_iri
end

function XMP:add_contribution(key, contribution_iri)
    local contribution = {}
    contribution.annotations = {}
    contribution.id = contribution_iri:gsub("<(default_contribution)>","ORKG_default")
    XMP.paper.contributions[key] = contribution
end

function XMP:add_annotation(contribution_ids, annotation_type, annotation_type_uri, content, annotation_id)
    local annotation = {}
    annotation.content = content
    annotation.id = annotation_id
    if contribution_ids == '' then
        contribution_ids = '<default_contribution>'
    end
    print(contribution_ids)
    contributions_ids_t = contribution_ids:split(',%s?')

    if annotation_type_uri == '' then
        annotation_type_uri = 'https://www.orkg.org/orkg/property'
    elseif not uri_valid(annotation_type_uri) then 
        message = [[The given URI %s is not a valid choice!
            Please use a resolvable URI starting with 'http']]
        orkg_warn(message, s)
    end
    annotation.type_uri = annotation_type_uri .. '#' .. annotation_type
    Annotation_object:register_property(annotation_type)
    -- add the annotations at the specified contribution
    for i, contribution_id in ipairs(contributions_ids_t) do
        print(contribution_id)
        if self.paper.contributions[contribution_id] == nil then
            self:add_contribution(contribution_id, 'contribution_'..contribution_id)
        end
        table.insert(self.paper.contributions[contribution_id].annotations, annotation)
    end
end

function Annotation_object:add_property_to_list(p)
    self.properties_used[p] = false
    table.insert(self.properties,p)
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
    texio.write_nl("term and log", 
                [[Package orkg4latex Warning: ]] .. string.format(warning_message, ...))
end 

function XMP:generate_output()
    output_string = ""
    XMP:add_line(xmp_top)
    --print(debug.traceback())

    if XMP.paper then
        XMP:add_line('  <rdf:Description rdf:about="%s">', XMP.paper.id)
        XMP:add_line('    <rdf:type rdf:resource="http://orkg.org/core#Paper"/>')
        for cb_id, contribution in pairs(XMP.paper.contributions) do
            XMP:add_line('    <orkg:hasResearchContribution>')
            XMP:add_line('      <orkg:ResearchContribution rdf:about="%s">', contribution.id)
            for j, annotation in ipairs(contribution.annotations) do
                XMP:add_line('        <po:contains>')
                XMP:add_line('          <orkg:Annotation rdf:about="%s">', annotation.id)
                XMP:add_line('            <rdf:type rdf:resource="%s"/>', annotation.type_uri)
                XMP:add_line('            <c4o:hasContent>%s</c4o:hasContent>', escape_xml_content(remove_latex_commands(annotation.content)))
                XMP:add_line('          </orkg:Annotation>')
                XMP:add_line('        </po:contains>')
            end
            XMP:add_line('      </orkg:ResearchContribution>')
            XMP:add_line('    </orkg:hasResearchContribution>')
        end
        XMP:add_line('  </rdf:Description>')
    end
    XMP:add_line(xmp_bottom)
    return table.concat(XMP.lines, '\n')

end

function XMP:make_metadata_object()
    local xmp_string = XMP:generate_output()
    local new_pdf = pdf.obj {
        type = 'stream',
        attr = '/Type/Metadata /Subtype/XML',
        immediate = true,
        compresslevel = 0,
        string = xmp_string,
    }
    XMP.lines = nil
    return new_pdf
end

XMP:add_paper_node('R1234565')

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
    Are you sure you don't want to mark a sentence with the %s environment?]]
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
        local metadata_obj = XMP:make_metadata_object()
        local catalog = pdf.getcatalog() or ''
        pdf.setcatalog(catalog..string.format('/Metadata %s 0 R', metadata_obj))
    end
end, 'finish')

Annotation_object.XMP = XMP
return Annotation_object