local MY_XMP = require('set-xmp')
MY_XMP.add_paper_node('R1234565')
MY_XMP.add_contribution('contribution1')

local Annotation_object = {}
Annotation_object.whole_string = ""

local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
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
    MY_XMP.add_annotation('Background', sentence, 'annotation1')
end

function Annotation_object.add_contribution(sentence)
    MY_XMP.add_annotation('Contribution', sentence, 'annotation2')
end

function Annotation_object.add_methods(sentence)
    MY_XMP.add_annotation('Methods', sentence, 'annotation3')
end

function Annotation_object.add_problem_statement(sentence)
    MY_XMP.add_annotation('ProblemStatement', sentence, 'annotation4')
end

function Annotation_object.add_results(sentence)
    MY_XMP.add_annotation('Results', sentence, 'annotation5')
end

return Annotation_object