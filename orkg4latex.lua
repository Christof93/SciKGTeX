RANDOM_SEED = math.randomseed(os.time())
MATRIX_AND = {{0,0},{0,1} }
MATRIX_OR = {{0,1},{1,1}}
HEXES = '0123456789abcdef'
local ORKG = {}
ORKG.whole_string = ""
ORKG.properties_used = {}
ORKG.PRODUCE_XMP_FILE = true
ORKG.WARNING_LEVEL = 1

local XMP = {}
XMP.lines = {}
XMP.namespaces = {}
XMP.XMP_TOP = [[<x:xmpmeta xmlns:x="adobe:ns:meta/">]]
XMP.XMP_BOTTOM = [[</rdf:RDF>
</x:xmpmeta>]]
XMP.PACKET_END = [[<?xpacket end="r"?>]]

local UUID = {}

---------------------------- utilities -------------------------------

-- performs the bitwise operation specified by truth matrix on two numbers.
function BITWISE(x, y, matrix)
  local z = 0
  local pow = 1
  while x > 0 or y > 0 do
    z = z + (matrix[x%2+1][y%2+1] * pow)
    pow = pow * 2
    x = math.floor(x/2)
    y = math.floor(y/2)
  end
  return z
end

function INT2HEX(x)
  local s,base,pow = '',16,0
  local d
  while x > 0 do
    d = x % base + 1
    x = math.floor(x/base)
    s = string.sub(HEXES, d, d)..s
  end
  if #s == 1 then s = "0" .. s end
  return s
end

function read_header_of_file(path)
    local fh = io.open(path, "rb")
    if fh then
        local first_line = assert(fh:read())
        fh:close()
        return first_line
    else
        print ("No xmp metadata file found!")
        return nil 
    end
end
  
function extract_uuid_from_header(header)
    return header:gsub('.*id=\"(.-)\".*','%1')
end

function generate_UUID()
    UUID:initialize('00:0c:29:69:41:c6')
    return UUID:toString()
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

---------------------------- UUID class methods  -------------------------------------

-- hwaddr is a string: hexes delimited by colons. e.g.: 00:0c:29:69:41:c6
function UUID:initialize(hwaddr)
    -- bytes are treated as 8bit unsigned bytes.
    self._bytes = {
      math.random(0, 255),
      math.random(0, 255),
      math.random(0, 255),
      math.random(0, 255),
      math.random(0, 255),
      math.random(0, 255),
      math.random(0, 255),
      math.random(0, 255),
      math.random(0, 255),
      math.random(0, 255),
      -- no split() in lua. :(
      tonumber(hwaddr:sub(1, 2), 16),
      tonumber(hwaddr:sub(4, 5), 16),
      tonumber(hwaddr:sub(7, 8), 16),
      tonumber(hwaddr:sub(10, 11), 16),
      tonumber(hwaddr:sub(13, 14), 16),
      tonumber(hwaddr:sub(16, 17), 16)
    }
    -- set the version
    self._bytes[7] = BITWISE(self._bytes[7], 0x0f, MATRIX_AND)
    self._bytes[7] = BITWISE(self._bytes[7], 0x40, MATRIX_OR)
    -- set the variant
    self._bytes[9] = BITWISE(self._bytes[7], 0x3f, MATRIX_AND)
    self._bytes[9] = BITWISE(self._bytes[7], 0x80, MATRIX_OR)
    self._string = nil
  end
  
  -- lazy string creation.
  function UUID:toString()
    if self._string == nil then
      self._string = INT2HEX(self._bytes[1])..INT2HEX(self._bytes[2])..INT2HEX(self._bytes[3])..INT2HEX(self._bytes[4]).."-"..
           INT2HEX(self._bytes[5])..INT2HEX(self._bytes[6]).."-"..
           INT2HEX(self._bytes[7])..INT2HEX(self._bytes[8]).."-"..
           INT2HEX(self._bytes[9])..INT2HEX(self._bytes[10]).."-"..
           INT2HEX(self._bytes[11])..INT2HEX(self._bytes[12])..INT2HEX(self._bytes[13])..INT2HEX(self._bytes[14])..INT2HEX(self._bytes[15])..INT2HEX(self._bytes[16])
    end
    return self._string
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

    if #uri_and_prefix < 2 then
        ORKG:error([[Method ORKGaddproperty: No prefix found.
    Unknown prefix, URI specification: %s.
    Please specify the arguments as [prefix, URI]!]], ns_arg)
        return nil
    elseif #uri_and_prefix > 2 then
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
    self:add_line('<?xpacket begin="?" id="%s"?>',self.paper.id)
    self:add_line(self.XMP_TOP)
    self:add_line(self:generate_rdf_root())
    --print(debug.traceback())
    if self.paper then
        self:add_line('  <rdf:Description rdf:about="https://www.orkg.org/orkg/paper/%s">', self.paper.id)
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
    self:add_line(self.PACKET_END)

    return table.concat(self.lines, lb_char)

end

function XMP:attach_metadata_pdfstream()
    local xmp_string = self:generate_xmp_string()
    local new_pdf = pdf.obj {
        type = 'stream',
        attr = '/Type/Metadata /Subtype/XML',
        immediate = true,
        compresslevel = 0,
        string = xmp_string,
    }
    self.lines = {}
    return new_pdf
end

function XMP:dump_metadata()
    local xmp_string = self:generate_xmp_string()
    f = io.open(tex.jobname .. '.xmp_metadata.xml','w')
    io.output(f)
    --io.write([[<?xml version="1.0" encoding="UTF-8"?>\n]])
    io.write(xmp_string)
    io.close(f)
end

luatexbase.add_to_callback('stop_run', function()
    ORKG:warn_unused_command()
end, 'at_end')

--  Writing metadata packets
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

-- get the id or generate UUID
local header = read_header_of_file(tex.jobname .. '.xmp_metadata.xml')
if  header ~= nil then
    id = extract_uuid_from_header(header)
end
if id == nil then
    id = generate_UUID()
    print('generate new id:', id)
end
XMP:add_paper_node(id)
XMP:add_namespace("rdf","http://www.w3.org/1999/02/22-rdf-syntax-ns#")
XMP:add_namespace("rdfs","http://www.w3.org/2000/01/rdf-schema#")
XMP:add_namespace("orkg","http://orkg.org/core#")
XMP:add_namespace("orkg_property","http://orkg.org/property")

ORKG.XMP = XMP
return ORKG