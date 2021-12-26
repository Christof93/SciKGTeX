local ORKG = {}
ORKG.whole_string = ""
ORKG.properties_used = {}
ORKG.PRODUCE_XMP_FILE = true
ORKG.WARNING_LEVEL = 1

local XMP = {}
XMP.lines = {}
XMP.namespaces = {}
XMP.PACKET_START = [[<?xpacket begin="" id="b0e1b454-39bf-11ec-8d3d-0242ac130003"?>]]
XMP.XMP_TOP = [[<x:xmpmeta xmlns:x="adobe:ns:meta/">]]
XMP.XMP_BOTTOM = [[</rdf:RDF>
</x:xmpmeta>]]
XMP.PACKET_END = [[<?xpacket end="r"?>]]

---------------------------- utilities -------------------------------
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

function escape_xml_content(s)
    s = s:gsub('&', '&amp;')
    return s:gsub('<', '&lt;')
end

function remove_latex_commands(s)
    s = s:gsub('\\begin%s+{.-}{.-}','')
    s = s:gsub('\\begin%s+{.-}','')
    s = s:gsub('\\end%s+{.-}','')
    s, c = s:gsub('\\.-{(.-)}','%1')
    if c > 0 then
        return remove_latex_commands(s)
    end
    s, c = s:gsub('\\.-%s+{(.-)}','%1')
    if c > 0 then
        return remove_latex_commands(s)
    end
    s, c = s:gsub('\\.-%s','')
    if c > 0 then
        return remove_latex_commands(s)
    end
    return s
end

function uri_valid(s)
    if s:find('http') ~= 1 then
        return false
    else
        return true
    end
end 

function resolve_entity(s)
    uri, found = s:gsub('\\ORKGuri%s*{(.*)}%s*{.*}', '%1')
    if found == 1 then
        label = s:gsub('\\ORKGuri%s*{.*}%s*{(.*)}', '%1')
        entity = string.format('<rdf:Description rdf:about=\"%s\"><rdfs:label>%s</rdfs:label></rdf:Description>', uri, label)
        return entity
    else
        uri, found = s:gsub('\\ORKGuri%s*{(.*)}', '%1')
        if found == 1 then
            entity = string.format('<rdf:Description rdf:about=\"%s\"></rdf:Description>', uri)
            return entity
        else
            return false
        end
    end
end

---------------------------- Main class methods -------------------------------

function ORKG:set_warning_level(wl)
    self.WARNING_LEVEL = wl
end

function ORKG:warn(warning_message, ...)
    if self.WARNING_LEVEL > 0 then
        texio.write_nl("term and log", 
                [[Package orkg4latex Warning: ]] .. string.format(warning_message, ...))
        texio.write_nl("term and log","\n")
    end
end

function ORKG:error(warning_message, ...)
    tex.error([[Package orkg4latex Error: ]] .. string.format(warning_message, ...))
end

ORKG.command_factory = {}

ORKG.command_factory.cmd_top = [[\newcommand{\%s}[2][]{]]
 
ORKG.command_factory.cmd_top_star = [[\WithSuffix\newcommand\%s*[2][]{]]
 
ORKG.command_factory.cmd_top_override = [[\renewcommand{\%s}[2][]{]]

ORKG.command_factory.cmd_top_star_override = [[\WithSuffix\renewcommand\%s*[2][]{]]

ORKG.command_factory.directlua_part = [[  \directlua{
    local content = "\luaescapestring{\unexpanded{#2}}"
    local belongs_to_contribution = "\luaescapestring{\unexpanded{#1}}"
    ORKG.XMP:add_annotation(belongs_to_contribution, '%s', '%s', content, 'annotation-id')
  }]]

ORKG.command_factory.cmd_bottom = [[}]]
ORKG.command_factory.cmd_bottom_star = [[\ignorespaces}]]

function ORKG.command_factory:build_command(command_name, property_URI)
    full_cmd = self.cmd_top .. "\n" .. self.directlua_part .. "\n  #2\n" .. self.cmd_bottom
    formatted_cmd = string.format(full_cmd, command_name, command_name, property_URI)
    for i, line in ipairs(formatted_cmd:split("\n")) do
        tex.print(line .. "%")
    end
end

function ORKG.command_factory:build_star_command(command_name, property_URI)
    full_cmd = self.cmd_top_star .. "\n" .. self.directlua_part .. "\n" .. self.cmd_bottom_star
    formatted_cmd = string.format(full_cmd, command_name, command_name, property_URI)
    for i, line in ipairs(formatted_cmd:split("\n")) do
        tex.print(line .. "%")
    end
end

function ORKG.command_factory:override_command(command_name, property_URI)
    full_cmd = self.cmd_top_override .. "\n" .. self.directlua_part .. "\n  #2\n" .. self.cmd_bottom
    formatted_cmd = string.format(full_cmd, command_name, command_name, property_URI)
    for i, line in ipairs(formatted_cmd:split("\n")) do
        tex.print(line .. "%")
    end
end

function ORKG.command_factory:override_star_command(command_name, property_URI)
    full_cmd = self.cmd_top_star_override .. "\n" .. self.directlua_part .. "\n" .. self.cmd_bottom_star
    formatted_cmd = string.format(full_cmd, command_name, command_name, property_URI)
    for i, line in ipairs(formatted_cmd:split("\n")) do
        tex.print(line .. "%")
    end
end

function ORKG:make_new_property(new_property, namespace)
    -- Prepend the ORKG namespace if not already specified
    if new_property:sub(1,4) ~= 'ORKG' then
        ORKG:error([[Method ORKGaddproperty: Missing Prefix.
    Command %s could be ambiguous!
    You can still use the command with ORKG%s{}.
    Prepend 'ORKG' already in the property definition to avoid this error.]], new_property, new_property)
    new_property = 'ORKG' .. new_property

    end
    -- check if property already exists
    if self.properties_used[new_property]~=nil then
        self:warn([[Method ORKGaddproperty: Repeated definition.
    Command %s already exists!
    Are you sure you want to override it?]], new_property)
        self.command_factory:override_command(new_property, namespace)
        self.command_factory:override_star_command(new_property, namespace)
    else
        self.properties_used[new_property] = false
        self.command_factory:build_command(new_property, namespace)
        self.command_factory:build_star_command(new_property, namespace)
    end
end

function ORKG:register_property(prop_type)
    self.properties_used[prop_type] = true
end

function ORKG:warn_unused_command()
    warning_message = [[No %s annotation found!
    Are you sure you don't want to mark an entity with %s?]]
    for env, val in pairs(self.properties_used) do
        if not val then
            self:warn(warning_message, env, env);
        end
    end
end

function ORKG:print_entity(uri, label)
    if label ~= "" then
        tex.print(string.format('\\href{%s}{%s}',uri , label))
    else
        tex.print(string.format('\\url{%s}',uri))
    end
end

---------------------------- XMP class methods -------------------------------

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
    contribution.id = contribution_iri:gsub("<(default_contribution)>", "ORKG_default")
    self.paper.contributions[key] = contribution
end

function XMP:extract_namespace_prefix(ns_arg)
    if ns_arg == '' then
        return nil
    end
    
    uri_and_prefix = ns_arg:split(',%s+?')
    
    if table.getn(uri_and_prefix) < 2 then
        ORKG:error([[Method ORKGaddproperty: No prefix found.
    Unknown prefix, URI specification: %s.
    Please specify the arguments as [prefix, URI]!]], ns_arg)
        return nil
    elseif table.getn(uri_and_prefix) > 2 then
        ORKG:warn([[Method ORKGaddproperty: Too many arguments.
    Too many arguments in prefix, URI specification: %s.
    Excess arguments are ignored.]], ns_arg)
    end

    if not uri_valid(uri_and_prefix[2]) then 
        message = [[Method ORKGaddproperty: Invalid URI.
    The given URI %s is not a valid choice!
    Please use a resolvable URI starting with 'http'.]]
        ORKG:error(message, uri_and_prefix[2])
        return nil
    end
    -- add the namespace if it has not been added yet    
    if self.namespaces[uri_and_prefix[1]]==nil then
        self:add_namespace(uri_and_prefix[1], uri_and_prefix[2])
    end
    return uri_and_prefix[1] 
end

function XMP:process_content(c)
    c = escape_xml_content(c)
    entity = resolve_entity(c)
    if entity ~= false then
        return entity
    end
    c = remove_latex_commands(c)
    return c
end

function XMP:add_annotation(contribution_ids, annotation_type, annotation_type_uri, content, annotation_id)
    local annotation = {}
    if contribution_ids == '' then
        contribution_ids = '<default_contribution>'
    end
    contributions_ids_t = contribution_ids:split(',%s+?')

    annotation.content = content
    annotation.id = annotation_id
    annotation.type = annotation_type
    annotation.prefix = self:extract_namespace_prefix(annotation_type_uri) or 'orkg_property'

    -- register the use of the property in text
    ORKG:register_property(annotation_type)

    -- add the annotations at the specified contribution
    for i, contribution_id in ipairs(contributions_ids_t) do
        -- add a new contribution if it has not been added yet
        if self.paper.contributions[contribution_id] == nil then
            self:add_contribution(contribution_id, 'contribution_'..contribution_id)
        end
        -- add the property annotation to the list of properties of a contribution
        table.insert(self.paper.contributions[contribution_id].properties, annotation)
    end
end

function XMP:add_namespace(abbr, uri)
    self.namespaces[abbr] = uri
end

function XMP:generate_rdf_root()
    ns_key_array = {}
    for ns, uri in pairs(self.namespaces) do table.insert(ns_key_array, ns) end
    root_string = [[<rdf:RDF ]]
    table.sort(ns_key_array)
    for i, key in ipairs(ns_key_array) do
        root_string = root_string .. "\n  xmlns:" .. key .. [[="]] .. self.namespaces[key] .. [["]]
    end
    root_string = root_string .. [[>]]
    return root_string
end

function XMP:generate_xmp_string(lb_char)
    lb_char = lb_char or "\n"
    if lb_char == "r" then
        lb_char = "\r"
    end
    output_string = ""
    sorted_contributions = {}
    for cb_id, contribution in pairs(XMP.paper.contributions) do 
        table.insert(sorted_contributions,cb_id)
    end
    table.sort(sorted_contributions)

    self:add_line(self.XMP_TOP)
    self:add_line(self:generate_rdf_root())
    --print(debug.traceback())
    if self.paper then
        self:add_line('  <rdf:Description rdf:about="%s">', self.paper.id)
        self:add_line('    <rdf:type rdf:resource="http://orkg.org/core#Paper"/>')
        for i, cb_id in pairs(sorted_contributions) do
            contribution = XMP.paper.contributions[cb_id]
            self:add_line('    <orkg:hasResearchContribution>')
            self:add_line('      <orkg:ResearchContribution rdf:about="%s">', contribution.id)
            for j, property in ipairs(contribution.properties) do
                self:add_line('          <%s:%s>%s</%s:%s>', property.prefix, property.type, 
                    self:process_content(property.content), property.prefix, property.type)
            end
            self:add_line('      </orkg:ResearchContribution>')
            self:add_line('    </orkg:hasResearchContribution>')
        end
        self:add_line('  </rdf:Description>')
    end
    self:add_line(self.XMP_BOTTOM)
    return table.concat(self.lines, lb_char)

end

function XMP:attach_metadata_pdfstream()
    local xmp_string = self:generate_xmp_string()
    local new_pdf = pdf.obj {
        type = 'stream',
        attr = '/Type/Metadata /Subtype/XML',
        immediate = true,
        compresslevel = 0,
        string = self.PACKET_START .. xmp_string .. self.PACKET_END,
    }
    self.lines = {}
    return new_pdf
end

function XMP:dump_metadata()
    local xmp_string = self:generate_xmp_string()
    f = io.open('xmp_metadata.xml','w')
    io.output(f)
    --io.write([[<?xml version="1.0" encoding="UTF-8"?>\n]])
    io.write(xmp_string)
    io.close(f)
end

luatexbase.add_to_callback('stop_run', function()
    ORKG:warn_unused_command()
end, 'at_end')

-- 1 Writing metadata packets
luatexbase.add_to_callback('finish_pdffile', function()
    if XMP.paper then
        local metadata_obj = XMP:attach_metadata_pdfstream()
        local catalog = pdf.getcatalog() or ''
        pdf.setcatalog(catalog..string.format('/Metadata %s 0 R', metadata_obj))
        if ORKG.PRODUCE_XMP_FILE then
            XMP:dump_metadata()
        end
    end
end, 'finish')

-- TODO: real identifier assigned
XMP:add_paper_node('R1234565')
XMP:add_namespace("rdf","http://www.w3.org/1999/02/22-rdf-syntax-ns#")
XMP:add_namespace("rdfs","http://www.w3.org/2000/01/rdf-schema#")
XMP:add_namespace("orkg","http://orkg.org/core#")
XMP:add_namespace("orkg_property","http://orkg.org/property")

ORKG.XMP = XMP
return ORKG