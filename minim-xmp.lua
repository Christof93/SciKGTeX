
local M = { } 
local alloc = require('minim-alloc')
alloc.remember('minim-xmp')

local function sorted_pairs(t)
    local keys, i = { }, 0
    for k, _ in pairs(t) do table.insert(keys, k) end
    table.sort(keys)
    return function()
        i = i + 1
        local k = keys[i]
        if k then
            return k, t[k]
        end
    end
end

-- 1 Reading and writing metadata values

M.getters = {
    Text = function(v) return v or '' end,
    ['Lang Alt'] = function(t, a) return t[a or 'x-default'] or '' end,
}

M.setters = {
    Text = function(new, orig, opt, k)
        if opt then alloc.msg('Warning: no alternative for %s', k) end
        if orig then alloc.msg('Warning: overwriting metadata field %s', k) end
        return new
    end,
    ['Lang Alt'] = function(value, orig, lang)
        orig = orig or { }
        orig[lang or 'x-default'] = value
        return orig
    end,
    Integer = function(new, orig, opt, k)
        if opt then alloc.msg('Warning: no alternative for %s', k) end
        if orig then alloc.msg('Warning: overwriting metadata field %s', k) end
        return tonumber(new) and new or alloc.err('Not a number: %s', new)
    end,
    Date = function(new, orig, opt, k)
        if opt then alloc.msg('Warning: no alternative for %s', k) end
        if orig then alloc.msg('Warning: overwriting metadata field %s', k) end
        return string.match(new, '^%d%d%d%d')
           and new or alloc.err('Date must start with year')
    end,
    Boolean = function(s)
        return s == 'True'
            or s == 'False'
           and s or alloc.err('Boolean value must be True or False')
    end,
}

-- 1 Namespace definitions

local namespace_info = alloc.saved_table ('metadata namespace info')

function M.add_key(prefix, name, t)
    namespace_info[prefix].keys[name] = {
        type = t.type or t[1],
        description = t.description or t[2],
        isInternal = t.isInternal or t[3] or false,
        inUse = false,
    }
end

function M.add_valuetype(prefix, name, t)
    local ns = namespace_info[prefix]
    ns.valuetypes = ns.valuetypes or { }
    ns.valuetypes[name] = {
        description = t.description or t[1],
        uri = t.uri or ns.uri,
        prefix = t.prefix or ns.prefix,
        inUse = false,
    }
    t.fields = t.fields or t[2]
    if t.fields then
        local fields = { }
        ns.valuetypes[name].fields = fields
        for n, f in pairs(t.fields)  do
            fields[n] = { type = f.type or f[1], description = f.description or f[2] }
        end
        M.getters[name] = function(t, k)
            if k then
                return (fields[k] or alloc.err('Unknown field ‘%s’', k))
                    and t and t[k] or 'not found'
            else
                local res = { }
                for k, v in sorted_pairs(t) do
                    table.insert(res, string.format('/{%s} {%s}', k, v))
                end
                return table.concat(res, ' ')
            end
        end
        M.setters[name] = function(value, orig, key, k)
            if not key then
                alloc.err('Missing key for metadata field %s', k)
            elseif not fields[key] then
                alloc.err('Unknown field ‘%s’', key)
            else
                orig = orig or { }
                local setter = M.setters[fields[key].type] or M.setters.Text
                orig[key] = setter(value, orig[key], nil, k)
            end
            return orig
        end
    end
end

function M.add_namespace(description, prefix, uri, keys, valuetypes, predefined)
    namespace_info[prefix] = {
        uri = uri,
        description = description,
        keys = { },
        predefined = predefined or false,
        inUse = false,
    }
    for name, t in pairs(keys) do
        M.add_key(prefix, name, t)
    end
    for name, t in pairs(valuetypes or { }) do
        M.add_valuetype(prefix, name, t)
    end
end

local function get_resource_type(ns, vtype)
    local vtypes = namespace_info[ns].valuetypes
    return vtypes and vtypes[vtype] and vtypes[vtype].fields
       and vtypes[vtype] or false
end

local function parse_type_name(vtype)
    local c = string.sub(vtype, 1, 4)
    local t = string.sub(vtype, 5)
    if c == 'Bag ' then
        return t, 'Bag'
    elseif c == 'Seq ' then
        return t, 'Seq'
    else
        return vtype, false
    end
end

-- 1 Built-in namespaces

M.add_namespace('Adobe PDF', 'pdf', 'http://ns.adobe.com/pdf/1.3/', {
    Keywords   = { 'Text', 'Keywords' },
    PDFVersion = { 'Text', 'PDF version ', true},
    Producer   = { 'AgentName', 'Creator tool', true },
}, nil, true)

M.add_namespace('PDF/A Identification', 'pdfaid', 'http://www.aiim.org/pdfa/ns/id/', {
    amd         = { 'Text', 'Amendment identifier', true },
    corr        = { 'Text', 'Corrigendum identifier', true },
    conformance = { 'Text', 'Conformance level', true },
    part        = { 'Integer', 'Version identifier', true },
}, nil, true)

M.add_namespace('Dublin Core', 'dc', 'http://purl.org/dc/elements/1.1/', {
    contributor = { 'Bag ProperName', 'Other contributors' },
    coverage    = { 'Text', 'Extent or scope' },
    creator     = { 'Seq ProperName', 'Authors' },
    date        = { 'Seq Date', 'Relevant dates' },
    description = { 'Lang Alt', 'Description of contents' },
    format      = { 'MIMEType', 'File format (application/pdf)', true },
    identifier  = { 'Text', 'Unique identifier' },
    language    = { 'Bag Locale', 'Used languages', true },
    publisher   = { 'Bag ProperName', 'Publishers' },
    relation    = { 'Bag Text', 'Relationships to other documents', true },
    rights      = { 'Lang Alt', 'Copyright statement' },
    source      = { 'Text', 'Document source unique identifier' },
    subject     = { 'Bag Text', 'Keywords' },
    title       = { 'Lang Alt', 'Title' },
    type        = { 'Bag Text', 'Document type' },
}, nil, true)

M.add_namespace('XMP Basic', 'xmp', 'http://ns.adobe.com/xap/1.0/', {
    BaseUrl      = { 'URL', 'Base for relative URLs in the document', true },
    CreateDate   = { 'Date', 'Creation date' },
    CreatorTool  = { 'AgentName', 'Creator tool', true },
    Identifier   = { 'Bag Text', 'Multiple identifiers' },
    MetadataDate = { 'Date', 'Metadata modification date', true },
    ModifyDate   = { 'Date', 'Document modification date', true },
    Nickname     = { 'Text', 'Informal name' },
}, nil, true)

M.add_namespace('XMP Rights Management', 'xmpRights', 'http://ns.adobe.com/xap/1.0/rights/', {
    Certificate  = { 'URL', 'Online rights management cerfificate' },
    Marked       = { 'Boolean', 'Indicates this is a rights-managed resource' },
    Owner        = { 'Bag ProperName', 'Right holders' },
    UsageTerms   = { 'Lang Alt', 'Instructions on usage' },
    WebStatement = { 'URL', 'Location of rights statement' },
}, nil, true)

M.add_namespace('XMP Media Managament', 'xmpMM', 'http://ns.adobe.com/xap/1.0/mm/', {
    DerivedFrom     = { 'ResourceRef', 'Reference to original document', true },
    DocumentID      = { 'URI', 'UUID-based identifier across versions', true },
    History         = { 'Seq ResourceEvent', 'Human-readable history of changes', true },
    ManagedFrom     = { 'ResourceRef', 'Reference to unmanaged document', true },
    Manager         = { 'AgentName', 'Asset management system', true },
    ManagerVariant  = { 'Text', 'Particular variant', true },
    ManageTo        = { 'URI', 'Managed resource identifier', true },
    ManageUI        = { 'URI', 'Web browser interface', true },
    RenditionClass  = { 'RenditionClass', 'Rendition class name', true },
    RenditionParams = { 'Text', 'Additional rendition parameters', true },
    VersionID       = { 'Text', 'Document version identifier', true },
    Versions        = { 'Seq Version', 'Version history', true },
}, {
    ResourceEvent = { 'Reference to a resource', {
        action        = { 'Text', 'Action that occurred' },
        instanceID    = { 'URI', 'Instance ID of modifier resource' },
        parameters    = { 'Text', 'Additional description' },
        softwareAgent = { 'AgentName', 'Software agent performing the action' },
        when          = { 'Date', 'Optional timestamp of the action' },
    }, prefix = 'stEvt', uri = 'http://ns.adobe.com/xap/1.0/sType/ResourceEvent#' },
    ResourceRef = { 'Reference to a resource', {
        instanceID      = { 'URI', 'referenced xmpMM:instanceID' },
        documentID      = { 'URI', 'referenced xmpMM:documentID' },
        versionID       = { 'Text', 'referenced xmpMM:versionID' },
        renditionClass  = { 'RenditionClass', 'referenced xmpMM:renditionClass' },
        renditionParams = { 'Text', 'referenced xmpMM:renditionParams' },
        manager         = { 'AgentName', 'referenced xmpMM:manager' },
        managerVariant  = { 'Text', 'referenced xmpMM:managerVariant' },
        manageTo        = { 'URI', 'referenced xmpMM:manageTo' },
        manageUI        = { 'URI', 'referenced xmpMM:manageUI' },
    }, prefix = 'stRef', uri = 'http://ns.adobe.com/xap/1.0/sType/ResourceRef#' },
    Version = { 'Document version', {
        comments   = { 'Text', 'Description of changes' },
        event      = { 'Text', 'Description of changes' },
        modifyDate = { 'Date', 'Check-in date' },
        modifier   = { 'ProperName', 'Person making the modifications' },
        version    = { 'Text', 'New version number' },
    }, prefix = 'stVer', uri = 'http://ns.adobe.com/xap/1.0/sType/Version#' },
}, true)

-- 1 Writing metadata packets

local XMP = alloc.saved_table('metadata values')
XMP[1] = XMP[1] or { dc = { format = 'application/pdf' } } -- document-level metadata

function M.push_metadata()
    XMP[#XMP+1] = { }
end

local function get_xmp()
    return XMP[#XMP]
end

local function escape_xml_content(s)
    -- NB not to be used for attribute values
    s = string.gsub(s, '&', '&amp;')
    return string.gsub(s, '<', '&lt;')
end

-- 2 extension schemas

local function get_metadata_extensions()
    local namespaces, anyInUse = { }, false
    for prefix, ns in pairs(namespace_info) do
        if not ns.predefined and ns.inUse then
            namespaces[prefix] = ns
            anyInUse = true
        end
    end
    if not anyInUse then return false end
    local rv = { [[  <rdf:Description rdf:about=""
      xmlns:pdfaExtension="http://www.aiim.org/pdfa/ns/extension/"
      xmlns:pdfaSchema="http://www.aiim.org/pdfa/ns/schema#"
      xmlns:pdfaProperty="http://www.aiim.org/pdfa/ns/property#"
      xmlns:pdfaType="http://www.aiim.org/pdfa/ns/type#"
      xmlns:pdfaField="http://www.aiim.org/pdfa/ns/field#" >
    <pdfaExtension:schemas>
      <rdf:Bag>]] }
    local add = function (...) table.insert(rv, string.format(...)) end
    for prefix, ns in sorted_pairs(namespaces) do
        add('        <rdf:li rdf:parseType="Resource">')
        add('          <pdfaSchema:schema>%s</pdfaSchema:schema>', ns.description)
        add('          <pdfaSchema:namespaceURI>%s</pdfaSchema:namespaceURI>', ns.uri)
        add('          <pdfaSchema:prefix>%s</pdfaSchema:prefix>', prefix)
        table.insert(rv, '          <pdfaSchema:property>\n            <rdf:Seq>')
        for name, key in sorted_pairs(ns.keys) do if key.inUse then
            add('              <rdf:li rdf:parseType="Resource">')
            add('                <pdfaProperty:name>%s</pdfaProperty:name>', name)
            add('                <pdfaProperty:valueType>%s</pdfaProperty:valueType>', key.type)
            add('                <pdfaProperty:category>%s</pdfaProperty:category>', key.isInternal and 'internal' or 'external')
            add('                <pdfaProperty:description>%s</pdfaProperty:description>', key.description)
            add('              </rdf:li>')
        end end
        add('            </rdf:Seq>\n          </pdfaSchema:property>')
        if ns.valuetypes then
            add('          <pdfaSchema:valueType>\n            <rdf:Seq>')
            for name, vtype in sorted_pairs(ns.valuetypes) do
                if vtype.inUse then
                    add('              <rdf:li rdf:parseType="Resource">')
                    add('                <pdfaType:type>%s</pdfaType:type>', name)
                    if vtype.fields then
                        add('                <pdfaType:namespaceURI>%s</pdfaType:namespaceURI>', vtype.uri)
                        add('                <pdfaType:prefix>%s</pdfaType:prefix>', vtype.prefix)
                    end
                    add('                <pdfaType:description>%s</pdfaType:description>', vtype.description)
                    if vtype.fields then
                        add('                <pdfaType:field>\n                  <rdf:Seq>')
                        for name, field in sorted_pairs(vtype.fields) do
                            add('                    <rdf:li rdf:parseType="Resource">')
                            add('                      <pdfaField:name>%s</pdfaField:name>', name)
                            add('                      <pdfaField:valueType>%s</pdfaField:valueType>', field.type)
                            add('                      <pdfaField:description>%s</pdfaField:description>', field.description)
                            add('                    </rdf:li>')
                        end
                        add('                  </rdf:Seq>\n                </pdfaType:field>')
                    end
                    add('              </rdf:li>')
                end
            end
            add('            </rdf:Seq>\n          </pdfaSchema:valueType>')
        end
        add('        </rdf:li>')
    end
    add('      </rdf:Bag>\n    </pdfaExtension:schemas>\n  </rdf:Description>')
    return table.concat(rv, '\n')
end

-- 2 main xmp packet

local function write_fields(add, res, value, pre, name, indent)
    indent = indent or ''
    if res then
        add('%s    <%s:%s rdf:parseType="Resource">', indent, pre, name)
        for k, _ in sorted_pairs(res.fields) do
            if value[k] then
                add('%s      <%s:%s>%s</%s:%s>', indent, res.prefix, k, value[k], res.prefix, k)
            end
        end
        add('%s    </%s:%s>', indent, pre, name)
    else
        add('%s    <%s:%s>%s</%s:%s>', indent, pre, name, escape_xml_content(value), pre, name)
    end
end

local function make_xmp_packet(xmp)
    local rv = { } ; local add = function(...) table.insert(rv, string.format(...)) end
    -- wrapper and opening tags
    add('<?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>')
    add('<x:xmpmeta xmlns:x="adobe:ns:meta/">')
    add('<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">')
    -- namespaces
    for id, keys in sorted_pairs(xmp) do
        local info = namespace_info[id]
        -- xml namespaces in enclosing description element
        add('  <rdf:Description rdf:about="" xmlns:%s="%s"', id, info.uri)
        local xmlns_uris = { }
        for _, vt in pairs(info.valuetypes or {}) do
            if vt.fields and vt.inUse
            and (vt.prefix ~= id or vt.uri ~= info.uri) then
                xmlns_uris[vt.prefix] = vt.uri
            end
        end
        for pre, uri in pairs(xmlns_uris) do
            add('      xmlns:%s="%s"', pre, uri)
        end
        rv[#rv] = rv[#rv] .. '>'
        -- metadata namespace contents
        for key, value in sorted_pairs(keys) do
            local vtype, lst = parse_type_name(info.keys[key].type)
            local res = get_resource_type(id, vtype)
            -- list values
            if lst then
                add('    <%s:%s>\n      <rdf:%s>', id, key, lst)
                for _, v in ipairs(value) do
                    write_fields(add, res, v, 'rdf', 'li', '    ')
                end
                add('      </rdf:%s>\n    </%s:%s>', lst, id, key)
            -- language alternatives
            elseif vtype == 'Lang Alt' then
                add('    <%s:%s>\n      <rdf:Alt>', id, key)
                for lang, v in sorted_pairs(value) do
                    add('        <rdf:li xml:lang="%s">%s</rdf:li>', lang, escape_xml_content(v))
                end
                add('      </rdf:Alt>\n    </%s:%s>', id, key)
            -- simple values
            else
                if lst then value = value[1] end
                write_fields(add, res, value, id, key)
            end
        end
        add('  </rdf:Description>')
    end
    -- extension schemas
    if #XMP == 1 and xmp.pdfaid then
        local schemas = get_metadata_extensions()
        if schemas then add(schemas) end
    end
    -- closing tags and wrapper
    local editable = tex.count['metadatamodification'] > 0
    add('</rdf:RDF>\n</x:xmpmeta>')
    if editable then add(string.rep(string.rep(' ', 80), 25, '\n')) end
    add('<?xpacket end="%s"?>', editable and 'w' or 'r')
    return table.concat(rv, '\n')
end

-- 2

function M.write_metadata()
    local xmp = make_xmp_packet(XMP[#XMP])
    local nr = pdf.obj {
        type = 'stream',
        attr = '/Type/Metadata /Subtype/XML',
        immediate = true,
        compresslevel = 0,
        string = xmp,
    }
    XMP[#XMP] = nil
    return nr
end

-- 1 Getting and setting metadata values

local function get_metadata_info(fullkey)
    local id, k = string.match(fullkey, '([^:]+):(.+)')
    if not id then return alloc.err('Malformed metadata key %s', fullkey) end
    local ns = namespace_info[id]
    if not ns then return alloc.err('Unknown namespace %s', id) end
    local key = ns.keys[k]
    if not key then return alloc.err('Unknown key %s in namespace %s', k, id) end
    local vtype, lst = parse_type_name(key.type)
    ns.inUse, key.inUse = true, true
    if ns.valuetypes and ns.valuetypes[vtype] then ns.valuetypes[vtype].inUse = true end
    return id, k, lst, vtype
end

local function get_separator()
    return string.utfcharacter(tex.count['metadataseparator'])
end

function M.get_metadata(k, a)
    local xmp = get_xmp()
    local ns, key, lst, vtype = get_metadata_info(k)
    local getter = M.getters[vtype] or M.getters.Text
    if not ns or not xmp[ns] then
        return ''
    elseif lst then
        local rv = { }
        for _, v in ipairs(xmp[ns][key]) do
            table.insert(rv, getter(v, a))
        end
        return table.concat(rv, get_separator())
    else
        return getter(xmp[ns][key], a)
    end
end

local function split_metadata_input(s)
    local rv = string.explode(s, get_separator())
    for i = 1, #rv do
        rv[i] = string.gsub(rv[i], '^ *', '')
        rv[i] = string.gsub(rv[i], ' *$', '')
    end
    return rv
end

function M.set_metadata(k, v, o)
    local ns, key, lst, vtype = get_metadata_info(k)
    if not ns then return end -- an error has already occurred
    local xmp = get_xmp()
    xmp[ns] = xmp[ns] or { }
    local setter = M.setters[vtype] or M.setters.Text
    if not v or v == '' then
        xmp[ns][key] = nil
    elseif lst then
        local l = xmp[ns][key] or { }
        xmp[ns][key] = l
        local nst = namespace_info[ns].valuetypes
        local f = nst and nst[vtype] and nst[vtype].fields
        if o and #l>0 and f and f[o] and not l[#l][o] then
            -- special case: add to property type
            l[#l] = setter(v, l[#l], o, l)
        else
            for _, val in ipairs(split_metadata_input(v)) do
                table.insert(l, setter(val, nil, o, k))
            end
        end
    else
        xmp[ns][key] = setter(v, xmp[ns][key], o, k)
    end
end

-- 1 Callbacks and tex interface

M.aliases = {
    author = { 'dc:creator' },
    title = { 'dc:title' },
    date = { 'dc:date', 'xmp:CreateDate', 'xmp:ModifyDate' },
    language = { 'dc:language' },
    keywords = { 'dc:subject',
        also = function(values)
            local kw = M.get_metadata('pdf:Keywords')
            if kw ~= '' then kw = kw..', ' end
            M.set_metadata('pdf:Keywords') -- prevent warning
            M.set_metadata('pdf:Keywords', kw..table.concat(split_metadata_input(values), ', '))
        end },
    publisher = { 'dc:publisher' },
    abstract = { 'dc:description' },
    copyright = { 'dc:rights' },
    identifier = { 'dc:identifier' },
    version = { 'xmpMM:VersionID' },
}

callback.register('finish_pdffile', function()
    if #XMP > 1 then
        alloc.err('Not all metadata has been written out.')
        XMP = { [1] = XMP[1] }
    elseif #XMP > 0 then
        local metadata_obj = M.write_metadata()
        local catalog = pdf.getcatalog() or ''
        pdf.setcatalog(catalog..string.format('/Metadata %s 0 R', metadata_obj))
    end
end)

alloc.luadef('getmetadata', function()
    local option = token.scan_keyword('/') and token.scan_string()
    local keyname = token.scan_word()
    local alias = M.aliases[keyname]
    local key = alias and alias[1] or keyname
    tex.sprint(M.get_metadata(key, option))
end)

local function set_aliased_metadata(keyname, value, option)
    local keys = M.aliases[keyname] or { keyname }
    for _, key in ipairs(keys) do
        M.set_metadata(key, value, option)
    end
    if keys.also then keys.also(value, option) end
end

alloc.luadef('setmetadata', function()
    local option = token.scan_keyword('/') and token.scan_string()
    local keyname = token.scan_word()
    local value = token.scan_string()
    set_aliased_metadata(keyname, value, option)
end, 'protected')

alloc.luadef('startmetadata', function()
    local key = token.scan_word()
    local opt = token.scan_keyword('/') and token.scan_string()
    repeat
        repeat
            set_aliased_metadata(key, token.scan_string(), opt)
            opt = token.scan_keyword('/') and token.scan_string()
        until not opt
        key = token.scan_word()
        opt = token.scan_keyword('/') and token.scan_string()
    until key == 'stopmetadata'
end)

alloc.luadef('newmetadata', function()
    M.push_metadata()
end, 'protected')

alloc.luadef('writemetadata', function()
    tex.sprint(M.write_metadata())
end)

alloc.luadef('includemetadata', function()
    local file = kpse.find_file(token.scan_string())
    if not file then
        alloc.err('Metadata file not found');
        tex.sprint(0);
    else
        tex.sprint( pdf.obj {
            type = 'stream',
            attr = '/Type/Metadata /Subtype/XML',
            immediate = true,
            compresslevel = 0,
            file = file,
        })
    end
end)

-- 

return M

