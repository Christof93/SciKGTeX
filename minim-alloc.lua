
local M = {}

-- 1 messages

function M.msg(...)
    texio.write_nl(string.format(...))
end

function M.amsg(...)
    texio.write(string.format(...))
end

function M.log(...)
    texio.write_nl('log', string.format(...))
end

function M.alog(...)
    texio.write('log', string.format(...))
end

function M.term(...)
    texio.write_nl('term', string.format(...))
end

function M.err (...)
    tex.error(string.format(...))
end

--1 saving modules and tables

local tables = package.loaded['minim-saved-tables']
    or { ['minim:modules'] = { } }
local modules = tables ['minim:modules']

function M.remember (name)
    if modules[name] == nil then
        modules[name] = false -- will be a number if a bytecode register is reserved
        modules[#modules+1] = name
    end
end

function M.saved_table (identifier, table)
    if tables[identifier] == nil then
        tables[identifier] = table or { }
    end
    return tables[identifier]
end

-- saved tables may only contain values that can be converted to and from 
-- strings with tostring() or other tables meeting the same requirement.
function M.table_to_text (tbl)
    local r = { }
    for i,t in pairs(tbl) do
        local l = ''
        if type(i) == 'string' then
            l = string.format('[%q] = ', i)
        else
            l = string.format('[%s] = ', i)
        end
        if type(t) == 'table' then
            l = l .. M.table_to_text (t)
        elseif type(t) == 'string' then
            l = l .. string.format ('%q', t)
        else
            l = l .. tostring(t)
        end
        r[#r+1] = l
    end
    return '{ ' .. table.concat (r,', ') .. ' }'
end

require('minim-callbacks')
M.remember('minim-callbacks')
M.remember('minim-alloc')

-- 1 allocation functions

-- like \unset
M.unset = -0x7FFFFFFF

local allocations = M.saved_table ('minim:allocations')

local function make_alloc_new (fname, globcount)
    allocations[fname] = allocations[fname] or { }
    M['new_'..fname] = function (id)
        local nr
        if id and allocations[fname][id] then
            nr = allocations[fname][id]
        else
            nr = tex.count[globcount] + 1
            tex.setcount('global', globcount, nr)
            if id then allocations[fname][id] = nr end
            M.log('\\%s%d : %s', fname, nr, id or '<unnamed>')
        end
        return nr
    end
end

make_alloc_new ('attribute'    , 'e@alloc@attribute@count'   )
make_alloc_new ('whatsit'      , 'e@alloc@whatsit@count'     )
make_alloc_new ('luabytecode'  , 'e@alloc@bytecode@count'    )
make_alloc_new ('function'     , 'e@alloc@luafunction@count' )
make_alloc_new ('luachunkname' , 'e@alloc@luachunk@count'    )
make_alloc_new ('catcodetable' , 'e@alloc@ccodetable@count'  )
make_alloc_new ('userrule'     , 'e@alloc@rule@count'        )

-- We need different allocation functions for the older registers, because 
-- etex’s global allocation macros are off-by-one w.r.t. all other.
--
local function make_alloc_old (fname, globcount, loccount)
    allocations[fname] = allocations[fname] or { }
    M['new_'..fname] = function (id)
        local nr
        if id and allocations[fname][id] then
            nr = allocations[fname][id]
        else
            nr = tex.count[globcount]
            tex.setcount('global', globcount, nr + 1)
            if id then allocations[fname][id] = nr end
            M.log('\\%s%d : %s', fname, nr, id or '<unnamed>')
        end
        return nr
    end
    M['local_'..fname] = function ()
        local nr = tex.count[loccount] - 1
        tex.setcount(loccount, nr)
        return nr
    end
end

-- existing allocation counters
make_alloc_old ('count',  260, 270 )
make_alloc_old ('dimen',  261, 271 )
make_alloc_old ('skip',   262, 272 )
make_alloc_old ('muskip', 263, 273 )
make_alloc_old ('box',    264, 274 )
make_alloc_old ('toks',   265, 275 )
make_alloc_old ('marks',  266, 276 )

function M.luadef (csname, fn, ...)
    local nr = M.new_function(csname)
    lua.get_functions_table()[nr] = fn
    token.set_lua(csname, nr, ...)
end

M.luadef ('minim:rememberalloc', function()
    allocations[token.scan_string()][token.scan_string()] = tex.count['allocationnumber']
end)

--1 dumping information to the format file

-- reserve a bytecode register
local saved_tables_bytecode = M.new_luabytecode('saved_tables_bytecode')

-- we cannot use set_lua because lua functions are not included in the format file
token.set_macro('minim:restoremodules', '\\luabytecodecall'..saved_tables_bytecode)

local function dump_saved_tables()
    M.msg('pre_dump: save modules and tables to format file')
    -- save modules
    for i,name in ipairs (modules) do
        if not modules[name] then
            M.msg('saving module '..name)
            -- reserve (if necessary) a bytecode register
            modules[name] = M.new_luabytecode ('module '..name)
            -- store the file into the format file
            lua.bytecode[modules[name]] = loadfile(kpse.find_file(name,'lua'))
        end
    end
    -- save tables (and restore modules)
    local saved_tables = [[
        
        -- include all saved tables in this bytecode register
        local t = ]]..M.table_to_text(tables)..[[

        -- and make them available via require()
        package.loaded['minim-saved-tables'] = t

        -- restore all remembered modules from their saved bytecode
        local s = t['minim:modules']
        for _, name in ipairs (s) do
            texio.write_nl('log', 'minim: restoring module '..name)
            package.loaded[name] = lua.bytecode[ s[name] ] ()
        end

        ]]
    lua.bytecode[saved_tables_bytecode] = load(saved_tables)
end

callback.register ('pre_dump', dump_saved_tables)

--

return M

