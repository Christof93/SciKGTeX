
local M = {}

local function log(msg, ...)
    texio.write_nl('log', string.format(msg, ...))
end

--1 capturing the callback mechanism

-- if ltluatex is loaded, we must get callback.register back
if luatexbase ~= nil then
	local luatex_base = luatexbase
	luatexbase.uninstall ()
	luatexbase = luatex_base
end

local primitives = { }
M.primitives = primitives
primitives.register = callback.register
primitives.find     = callback.find
primitives.list     = callback.list

local own_callbacks = {}
local callback_lists = {}
local callback_stacks = {}

--1 finding callbacks

function M.find (name)
    local f = own_callbacks[name]
    if f == nil then
        return primitives.find(name)
    else
        return f
    end
end

function M.list (name)
    local t = {}
    for n,f in pairs(callback_lists) do
        if f then
            t[n] = #f
        else
            t[n] = false
        end
    end
    for n,f in pairs(own_callbacks) do
        if f then
            t[n] = t[n] or true
        else
            t[n] = t[n] or false
        end
    end
    for n,f in pairs(primitives.list()) do
        if f then
            t[n] = t[n] or true
        else
            t[n] = t[n] or false
        end
    end
    return t
end

--1 registering callbacks

local function register_simple (cb,f)
    -- prefer user-defined callbacks over built-in
    local x = own_callbacks[cb]
    if x == nil then
        return primitives.register (cb, f)
    else
        -- default to false because nil would delete the callback itself
        own_callbacks[cb] = f or false
        return -1
    end
end

-- will be redefined later
local function announce_callback(cb, f) end

function M.register (cb, f)
    announce_callback(cb, f)
    local list = callback_lists[cb]
    local stack = callback_stacks[cb]
    if stack then
        if f == nil then -- pop
            local p = stack[#stack]
            stack[#stack] = nil
            return register_simple (cb,p)
        else             -- push
            stack[#stack+1] = M.find (cb)
            return register_simple (cb,f)
        end
    elseif list ~= nil then
        list[#list+1] = f
        return -2
    else
        return register_simple (cb,f)
    end
end


--1 lists of callback functions

local function call_list_node (lst)
    return function (head, ...)
        local list = callback_lists[lst]
        for _,f in ipairs(list) do
            local newhead = f(head,...)
            if node.is_node(newhead) then
                head = newhead
            elseif newhead == false then
                return false
            end
        end
        return head
    end
end

local function call_list_data (lst)
    return function (str)
        local list = callback_lists[lst]
        for _,f in ipairs(list) do
            str = f(str) or str
        end
        return str
    end
end

local function call_list_simple (lst)
    return function (...)
        local list = callback_lists[lst]
        for _,f in ipairs(list) do
            f(...)
        end
    end
end

--1 creating and calling callbacks

local function register_list (lst, fn)
    M.register (lst, fn(lst))
    callback_lists[lst] = {}
end

local function stack_callback (cb)
    callback_stacks[cb] = {}
end

function M.new_callback (name, prop)
    own_callbacks[name] = false -- false means empty here
    if prop == 'stack' then
        stack_callback (name)
    elseif prop == 'node' then
        register_list (name, call_list_node)
    elseif prop == 'simple' then
        register_list (name, call_list_simple)
    elseif prop == 'data' then
        register_list (name, call_list_data)
    end
end

function M.call_callback (name, ...)
    local f = own_callbacks[name]
    if f then
        return f (...)
    else
        return false
    end
end

--1 initialisation

-- save all registered callbacks
local saved = {}
for n,s in pairs(primitives.list()) do
    if s then
        log('save callback: %s', n)
        saved[n] = callback.find(n)
    end
end

-- replace the primitive registering
callback.register = M.register
callback.find     = M.find
callback.list     = M.list

-- string processing callbacks
register_list ('process_input_buffer', call_list_data)
register_list ('process_output_buffer', call_list_data)
register_list ('process_jobname', call_list_data)

-- node list processing callbacks
register_list ('pre_linebreak_filter', call_list_node)
register_list ('post_linebreak_filter', call_list_node)
--register_list ('append_to_vlist_filter', call_list_node) -- TODO this breaks something
register_list ('hpack_filter', call_list_node)
register_list ('vpack_filter', call_list_node)
register_list ('pre_output_filter', call_list_node)

-- mlist_to_mlist and mlist_to_mlist
M.new_callback ('mlist_to_mlist', 'node')
M.new_callback ('mlist_to_hlist', 'stack')
M.register ('mlist_to_hlist', node.mlist_to_hlist )
primitives.register ('mlist_to_hlist', function (head, ...)
    local newhead = M.call_callback ('mlist_to_mlist', head, ...)
    if newhead ~= true then
        head = newhead or head
    end
    newhead = M.call_callback ('mlist_to_hlist', head, ...)
    return newhead
end)

-- simple listable callbacks
register_list ('contribute_filter', call_list_simple)
register_list ('pre_dump', call_list_simple)
register_list ('wrapup_run', call_list_simple)
register_list ('finish_pdffile', call_list_simple)
register_list ('finish_pdfpage', call_list_simple)
register_list ('insert_local_par', call_list_simple)

register_list ('ligaturing', call_list_simple)
register_list ('kerning', call_list_simple)

-- stack callbacks
stack_callback ('hpack_quality')
stack_callback ('vpack_quality')
stack_callback ('hyphenate')
stack_callback ('linebreak_filter')
stack_callback ('buildpage_filter')
stack_callback ('build_page_insert')

-- process_rule
M.new_callback ('process_rule', 'simple')
primitives.register ('process_rule', function (rule, ...)
    local p = own_callbacks[rule.index]
    if p then
        p (rule, ...)
    else
        M.call_callback ('process_rule')
    end
end)

-- restore all registered callbacks
for n,f in pairs(saved) do
    log('restore callback: %s', n)
    M.register (n,f)
end
saved = nil


local function announce_callback(cb, f)
    if f then
        log('callback added: %s', cb)
    else
        log('callback removed: %s', cb)
    end
end


--

return M


