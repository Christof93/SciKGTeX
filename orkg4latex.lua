local MY_XMP = require('set-xmp')
MY_XMP.add_paper_node('R1234565')
MY_XMP.add_contribution('contribution1')

local Annotation_object = {}
Annotation_object.whole_string = ""

local envs = {
    'Background',
    'Contribution',
    'Problem Statement',
    'Results',
    'Methods'
}

local env_names = {
    'background',
    'contribution',
    'problem statement',
    'results',
    'methods'
}

local env_used = {}
for i, env in pairs(env_names) do env_used[env] = false end 

local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
 end

function Annotation_object.register_environment(env_type)
    env_used[env_type] = true
end

function Annotation_object.get_environment_body()
    local str_without_end = Annotation_object.whole_string:gsub("\\end{.*}\n?","")
    return (trim(str_without_end))
end

function Annotation_object.remember_body()
    Annotation_object.whole_string = ""
    luatexbase.add_to_callback(
        "process_input_buffer",
        Annotation_object.add_input_line,
        "add_input_line")
end

function Annotation_object.stop_remember_body()
    luatexbase.remove_from_callback("process_input_buffer", "add_input_line")
end

function Annotation_object.add_input_line(input_line)
    Annotation_object.whole_string = Annotation_object.whole_string .. input_line .. " " 
end

function Annotation_object.add_background(sentence)
    MY_XMP.add_annotation(envs[0], sentence, 'annotation1')
end

function Annotation_object.add_contribution(sentence)
    MY_XMP.add_annotation(envs[1], sentence, 'annotation2')
end

function Annotation_object.add_methods(sentence)
    MY_XMP.add_annotation(envs[3], sentence, 'annotation3')
end

function Annotation_object.add_problem_statement(sentence)
    MY_XMP.add_annotation(envs[2], sentence, 'annotation4')
end

function Annotation_object.add_results(sentence)
    MY_XMP.add_annotation(envs[4], sentence, 'annotation5')
end

local function warn_unused_environments()
    warning_message = [[No %s annotation found!
    Are you sure you don't want to mark a sentence with the %s environment?]]
    for env, val in pairs(env_used) do
        if not val then
            texio.write_nl("term and log", 
                [[Package orkg4latex Warning: ]] .. string.format(warning_message, env, env));
            -- tex.print(string.format(warning_message, env, env))
        end
    end
end

callback.register('stop_run', function()
    warn_unused_environments()
end)

return Annotation_object