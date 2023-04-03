RANDOM_SEED = math.randomseed(os.time())
MATRIX_AND = {{0,0},{0,1}}
MATRIX_OR = {{0,1},{1,1}}
HEXES = '0123456789abcdef'
local SciKGTeX = {}
SciKGTeX.whole_string = ""
SciKGTeX.properties_used = {}
SciKGTeX.property_commands = {}
SciKGTeX.mandatory_properties = {
    'researchproblem',
    'objective',
    'method',
    'result',
    'conclusion'
}
SciKGTeX.PRODUCE_XMP_FILE = true
SciKGTeX.WARNING_LEVEL = 1

local XMP = {}
XMP.lines = {}
XMP.namespaces = {}
XMP.property_ns = {}
XMP.XMP_TOP = [[<x:xmpmeta xmlns:x="adobe:ns:meta/">]]
XMP.XMP_BOTTOM = [[</x:xmpmeta>]]
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

function get_output_dir()
    if arg ~= nil then
        for k,v in ipairs(arg) do
            val, is_output_argument = v:gsub('%-%-output%-directory=(.*)','%1')
            if is_output_argument > 0 then
                return val
            end
        end
        return  nil
    end
    return nil
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

function spaces_to_underscores(s)
    return s:gsub('%s+','_')
end

function remove_environments(s)
    s,c = s:gsub('\\begin%s*{.-}{.-}%s*','')
    s,c = s:gsub('\\begin%s*{.-}%s*','')
    s,c = s:gsub('\\end%s*{.-}%s*','')
    return s
end

function remove_any_latex_command(s)
    s, c = s:gsub('\\%w+%s*%[%d*%]%s*{(.*)}','%1')
    if c > 0 then
        return remove_latex_commands(s)
    end
    s, c = s:gsub('\\%w+%s*{(.*)}','%1')
    if c > 0 then
        return remove_latex_commands(s)
    end
    s, c = s:gsub('\\%w+%s*','')
    if c > 0 then
        return remove_latex_commands(s)
    end
    return s
end

function find_last_occurence(s, repls)
    occurences = {}
    for pattern, repl in pairs(repls) do
        i, j = s:find(pattern)
        if i ~= nil then
            table.insert(occurences, {i,j,pattern})
        end
    end
    table.sort(occurences, function(l, r) return l[1]>r[1] end)
    if #occurences > 0 then
        return occurences[1]
    else
        return nil
    end
end

function exhaustively_replace_last_occurence_of_pattern(s, repls)
    last_occurence = find_last_occurence(s, repls)
    if last_occurence ~= nil then
        starts, ends, pattern = table.unpack(last_occurence)
        to_replace = s:sub(starts,ends)
    else
        return s
    end
    new_string = s:sub(0,starts-1) .. to_replace:gsub(pattern, repls[pattern], 1) .. s:sub(ends+1)
    return exhaustively_replace_last_occurence_of_pattern(new_string, repls)
end

function remove_latex_commands(s)
    replacements = {
        -- contribution with * and []
        ['\\contribution%s*%*%s*%[%d*%]%s*{.-}{.*}%s*'] = '',
        -- contribution with *
        ['\\contribution%s*%*%s*{.-}%s*{.*}%s*'] = '',
        -- contribution with []
        ['\\contribution%s*%[%d*%]%s*{.-}{(.*)}'] = '%1',
        -- contribution normal
        ['\\contribution%s*{.-}%s*{(.*)}'] = '%1',

        ['\\uri%s*{.-}%s*{(.*)}'] = '%1',
    }
    for cmd, used in pairs(SciKGTeX.property_commands) do
        -- []
        replacements['\\'.. cmd .. '%s*%[%d*%]%s*{(.*)}'] = '%1'
        -- normal command 
        replacements['\\'.. cmd .. '%s*{(.*)}'] = '%1'
        -- with * and []
        replacements['\\'.. cmd .. '%s*%*%s*%[%d*%]%s*{.*}%s*'] = ''
        -- with *
        replacements['\\'.. cmd .. '%s*%*%s*{.*}%s*'] =''
    end
    s = remove_environments(s)
    s = exhaustively_replace_last_occurence_of_pattern(s, replacements)    
    s = remove_any_latex_command(s)
    -- remove escape chars
    s = s:gsub('\\','')
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
    -- make sure the entity is only resolved at the innermost of nested commands.
    for _, cmd in ipairs(SciKGTeX.mandatory_properties) do
        if s:find('\\' .. cmd) then
            return false
        end
    end
    if s:find('\\contribution') then
        return false
    end
    uri, found = s:gsub('.*\\uri%s*{(.-)}%s*{.*}.*', '%1')
    if found == 1 then
        label = s:gsub('.*\\uri%s*{.-}%s*{(.*)}.*', '%1')
        entity = string.format('<rdf:Description rdf:about=\"%s\"><rdfs:label>%s</rdfs:label></rdf:Description>', uri, label)
        return entity
    else
        uri, found = s:gsub('.*\\uri%s*{(.-)}.*', '%1')
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
      -- should come from mac address
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

function SciKGTeX:set_warning_level(wl)
    self.WARNING_LEVEL = wl
end

function SciKGTeX:warn(warning_message, ...)
    if self.WARNING_LEVEL > 0 then
        texio.write_nl("term and log", 
                [[Package SciKGTeX Warning: ]] .. string.format(warning_message, ...))
        texio.write_nl("term and log","\n")
    end
end

function SciKGTeX:error(warning_message, ...)
    tex.error([[Package SciKGTeX Error: ]] .. string.format(warning_message, ...))
end

SciKGTeX.command_factory = {}

SciKGTeX.command_factory.cmd_top = [[\newcommand{\%s}[2][]{]]
 
SciKGTeX.command_factory.cmd_top_star = [[\WithSuffix\newcommand\%s*[2][]{]]
 
SciKGTeX.command_factory.cmd_top_override = [[\renewcommand{\%s}[2][]{]]

SciKGTeX.command_factory.cmd_top_star_override = [[\WithSuffix\renewcommand\%s*[2][]{]]

SciKGTeX.command_factory.directlua_part = [[  \directlua{
    local content = "\luaescapestring{\unexpanded{#2}}"
    local belongs_to_contribution = "\luaescapestring{\unexpanded{#1}}"
    SciKGTeX.XMP:add_annotation(belongs_to_contribution, '%s', content, 'annotation-id')
  }]]

SciKGTeX.command_factory.cmd_bottom = [[}]]
SciKGTeX.command_factory.cmd_bottom_star = [[\ignorespaces}]]

function SciKGTeX.command_factory:build_command(command_name)
    full_cmd = self.cmd_top .. "\n" .. self.directlua_part .. "\n  #2\n" .. self.cmd_bottom
    formatted_cmd = string.format(full_cmd, command_name, command_name)
    for i, line in ipairs(formatted_cmd:split("\n")) do
        tex.print(line .. "%")
    end
end

function SciKGTeX.command_factory:build_star_command(command_name)
    full_cmd = self.cmd_top_star .. "\n" .. self.directlua_part .. "\n" .. self.cmd_bottom_star
    formatted_cmd = string.format(full_cmd, command_name, command_name)
    for i, line in ipairs(formatted_cmd:split("\n")) do
        tex.print(line .. "%")
    end
end

function SciKGTeX.command_factory:override_command(command_name)
    full_cmd = self.cmd_top_override .. "\n" .. self.directlua_part .. "\n  #2\n" .. self.cmd_bottom
    formatted_cmd = string.format(full_cmd, command_name, command_name)
    for i, line in ipairs(formatted_cmd:split("\n")) do
        tex.print(line .. "%")
    end
end

function SciKGTeX.command_factory:override_star_command(command_name)
    full_cmd = self.cmd_top_star_override .. "\n" .. self.directlua_part .. "\n" .. self.cmd_bottom_star
    formatted_cmd = string.format(full_cmd, command_name, command_name)
    for i, line in ipairs(formatted_cmd:split("\n")) do
        tex.print(line .. "%")
    end
end

function SciKGTeX:make_new_command(new_property, namespace)
    -- check if property already exists
    if self.property_commands[new_property]~=nil then
        self:warn([[Method newpropertycommand: Repeated definition.
    Command %s already exists!
    Are you sure you want to override it?]], new_property)
        self:add_property(new_property, namespace)
        self.command_factory:override_command(new_property, namespace)
        self.command_factory:override_star_command(new_property, namespace)
    else
        self.property_commands[new_property] = false
        self:add_property(new_property, namespace)
        self.command_factory:build_command(new_property, namespace)
        self.command_factory:build_star_command(new_property, namespace)
    end
end

function SciKGTeX:add_property(new_property, namespace)
    new_property = self.XMP:escape_xml_tags(new_property)
    -- check if property already exists
    if self.properties_used[new_property]~=nil then
        self:warn([[Method addmetaproperty: Repeated definition.
    Property %s already added!
    Are you sure you want to replace it?]], new_property)
    -- if not make it known to the object
    else
        self.properties_used[new_property] = false
    end
    ns_prefix = self.XMP:extract_namespace_prefix(namespace)
    self.XMP.property_ns[new_property] = ns_prefix
end

function SciKGTeX:register_property(prop_type)
    self.properties_used[prop_type] = true
end

function SciKGTeX:warn_unused_command()
    warning_message = [[No %s annotation found!
    Are you sure you don't want to mark an entity with %s?]]
    for i, p in ipairs(self.mandatory_properties) do
        used = self.properties_used[p]
        if not used then
            self:warn(warning_message, p, p);
        end
    end
end

function SciKGTeX:print_entity(uri, label, hyperrefloaded)
    if label ~= "" and hyperrefloaded then
        tex.print(string.format('\\href{%s}{%s}', uri , label))
    elseif label ~= "" then
        tex.print(label)
    elseif hyperrefloaded then
        tex.print(string.format('\\url{%s}',uri))
    else
        tex.print(uri)
    end
end

---------------------------- XMP class methods -------------------------------

function XMP:escape_xml_tags(s)
    s = spaces_to_underscores(s)
    s, i = s:gsub('[^%a%d%.-_]','')
    if i > 0 then
        SciKGTeX:warn([[Method escape_xml_tags: Forbidden characters.
        Property %s can only contain letters, digits, underscores, hyphens and periods!
        Forbidden characters removed.]], s)
    end
    s, i = s:gsub('^([Xx][Mm][Ll])','_%1')
    if i > 0 then
        SciKGTeX:warn([[Method escape_xml_tags: Forbidden characters.
        Property %s can not start with xml!
        Changed to _xml.]], s)
    end
    return s
end

function XMP:escape_xml_content(s)
    s = s:gsub('&', '&amp;')
    s = s:gsub('>', '&gt;')
    return s:gsub('<', '&lt;')
end

function XMP:add_line(...)
    table.insert(self.lines, string.format(...))
end

function XMP:add_paper_node(paper_iri) 
    self.paper = {}
    self.paper.contributions = {}
    self.paper.id = paper_iri
    self.paper.title = nil
    self.paper.authors = {}
    self.paper.researchfield = nil
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
        SciKGTeX:error([[Method addmetaproperty: No prefix found.
    Unknown prefix, URI specification: %s.
    Please specify the arguments as [prefix, URI]!]], ns_arg)
        return nil
    elseif #uri_and_prefix > 2 then
        SciKGTeX:warn([[Method addmetaproperty: Too many arguments.
    Too many arguments in prefix, URI specification: %s.
    Excess arguments are ignored.]], ns_arg)
    end

    if not uri_valid(uri_and_prefix[2]) then 
        message = [[Method addmetaproperty: Invalid URI.
    The given URI %s is not a valid choice!
    Please use a resolvable URI starting with 'http'.]]
        SciKGTeX:error(message, uri_and_prefix[2])
        return nil
    end
    -- add the namespace if it has not been added yet    
    if self.namespaces[uri_and_prefix[1]]==nil then
        self:add_namespace(uri_and_prefix[1], uri_and_prefix[2])
    end
    return uri_and_prefix[1] 
end

function XMP:process_content(c)
    c = self:escape_xml_content(c)
    entity = resolve_entity(c)
    if entity ~= false then
        return entity
    end
    c = remove_latex_commands(c)
    return c
end

function XMP:property_has_namespace(annotation_type)
    annotation_type_t = annotation_type:split(':')
    
    if #annotation_type_t > 1 then
        annotation_type = annotation_type_t[2]
        prefix = annotation_type_t[1]
    else
        annotation_type = annotation_type_t[1]
        prefix = nil
    end
    return prefix, annotation_type 
end

function XMP:set_title(title)
    self.paper.title = title
end

function XMP:add_author(author)
    table.insert(self.paper.authors, author)
end

function XMP:set_researchfield(researchfield)
    self.paper.researchfield = researchfield
end

function XMP:add_annotation(contribution_ids, annotation_type, content, annotation_id)
    local annotation = {}
    -- check if a namespace is attached to the property specification
    prefix, annotation_type = self:property_has_namespace(annotation_type)

    annotation.content = content
    annotation.id = annotation_id
    annotation.type = self:escape_xml_tags(annotation_type)

    -- take the prefix given, the prefix saved in the namespace dictionary or the default ns 
    annotation.prefix = prefix or self.property_ns[annotation.type] or 'orkg_property'

    -- register the use of the property in text
    SciKGTeX:register_property(annotation.type)

    -- check if the annotation was numbered
    if contribution_ids == '' then
        contribution_ids = '<default_contribution>'
    end
    contributions_ids_t = contribution_ids:split(',%s+?')
    -- add the annotations at the specified contribution
    for i, contribution_id in ipairs(contributions_ids_t) do
        -- add a new contribution if it has not been added yet
        if self.paper.contributions[contribution_id] == nil then
            self:add_contribution(contribution_id, 'contribution_'..contribution_id)
        end
        -- add the property annotation to the list of properties of a contribution
        -- check if the same annotation already exists (in case of double evaluation of the LaTeX command for example)
        already_there = false
        for _, prop in pairs(self.paper.contributions[contribution_id].properties) do
            if prop.content == annotation.content and prop.type == annotation.type then
                already_there = true
                break
            end
        end
        if not already_there then
            table.insert(self.paper.contributions[contribution_id].properties, annotation)
        end
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
        self:add_line(
            '  <rdf:Description rdf:about="https://www.orkg.org/orkg/paper/%s">',
             self.paper.id
        )
        self:add_line('    <rdf:type rdf:resource="http://orkg.org/core#Paper"/>')
        if self.paper.title ~= nil then
            self:add_line(
                '    <orkg:hasTitle>%s</orkg:hasTitle>', 
                self:process_content(self.paper.title)
            )
        end
        for i, author in ipairs(self.paper.authors) do
          self:add_line(
            '    <orkg:hasAuthor>%s</orkg:hasAuthor>',
            self:process_content(author))
        end
        if self.paper.researchfield ~= nil then
            self:add_line(
                '    <orkg:hasResearchField>%s</orkg:hasResearchField>',
                self:process_content(self.paper.researchfield)
            )
        end
        for i, cb_id in pairs(sorted_contributions) do
            contribution = self.paper.contributions[cb_id]
            if i==1 then
                if #sorted_contributions > 1 then
                    self:add_line('    <orkg:hasResearchContribution rdf:parseType="Collection">')
                else
                    self:add_line('    <orkg:hasResearchContribution>')
                end
            end
            self:add_line(
                '      <orkg:ResearchContribution rdf:about="https://www.orkg.org/orkg/paper/%s">', 
                self.paper.id .. "/" ..contribution.id
            )
            for j, property in ipairs(contribution.properties) do
                self:add_line(
                    '          <%s:%s>%s</%s:%s>', 
                    property.prefix,
                    property.type, 
                    self:process_content(property.content),
                    property.prefix,
                    property.type
                )
            end
            self:add_line('      </orkg:ResearchContribution>')
            if i == #sorted_contributions then
                self:add_line('    </orkg:hasResearchContribution>')
            end
        end
        self:add_line('  </rdf:Description>')
    end
    self:add_line('</rdf:RDF>')
    self:add_line(self.XMP_BOTTOM)
    self:add_line(self.PACKET_END)

    return table.concat(self.lines, lb_char)

end

function XMP:attach_metadata_pdfstream(metadata_type)
    local xmp_string = self:generate_xmp_string()
    local new_pdf = pdf.obj {
        type = 'stream',
        attr = '/Type /'..metadata_type..' /Subtype /XML',
        immediate = true,
        compresslevel = 0,
        string = xmp_string,
    }
    self.lines = {}
    return new_pdf
end

function XMP:dump_metadata()
    local xmp_string = self:generate_xmp_string()
    local dir = get_output_dir() or '.'
    f = io.open(dir .. '/' .. tex.jobname .. '.xmp_metadata.xml','w')
    io.output(f)
    io.write(xmp_string)
    io.close(f)
end

luatexbase.add_to_callback('stop_run', function()
    SciKGTeX:warn_unused_command()
    if SciKGTeX.PRODUCE_XMP_FILE then
        XMP:dump_metadata()
    end
end, 'at_end')

--  Writing metadata packets
luatexbase.add_to_callback('finish_pdffile', function()
    if XMP.paper then
        if CONFORM_TO_PDFA then
            catalog_key='SciKGMetadata'
        else
            catalog_key='Metadata'
        end
        local metadata_obj = XMP:attach_metadata_pdfstream(catalog_key)
        local catalog = pdf.getcatalog() or ''
        pdf.setcatalog(catalog..string.format('/%s %s 0 R', catalog_key, metadata_obj))
    end
end, 'finish')

-- TODO: real identifier assigned

-- get the id or generate UUID
local output_dir = get_output_dir() or '.'
local header = read_header_of_file(output_dir .. '/' .. tex.jobname .. '.xmp_metadata.xml')
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
XMP:add_namespace("orkg_property","http://orkg.org/property/")

SciKGTeX.XMP = XMP
return SciKGTeX