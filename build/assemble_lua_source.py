import json

def get_from_file(fn):
    with open(fn, "r") as f:
        obj = json.load(f)
    return obj

def escape_forbidden_symbols(table_entry):
    return table_entry.replace(
        "\\", ""
    ).replace(
        "\n", " "
    ).replace(
        "'", "\\'" 
    ).replace(
        "\r", ""
    ).replace(
        '"', '\\"'
    ).replace(
        "--"," "
    )

def fix_main_properties(property_dict):
    property_dict.update({
        'research_problem': ['P32'],
        'objective': ['P15051'],
        'method': ['P1005'],
        'result': ['P1006'],
        'conclusion': ['P15419'],
    })
    return property_dict
    
def make_lua_code(prettify_table = False):
    if prettify_table:
        table_constructor_delimiter = "\n"
    else:
        table_constructor_delimiter = ""
    begin = "SciKGTeX.orkg_property_uri_map = {" + table_constructor_delimiter
    middle = ""
    name_id_store = fix_main_properties(get_from_file("./build/orkg_predicates.json"))
    for p_name in name_id_store:
        p_id_list = name_id_store[p_name]
        p_id_list = [f"'{escape_forbidden_symbols(id)}'" for id in p_id_list]
        p_name = escape_forbidden_symbols(p_name)
        if len(p_id_list)==1:
            middle += f"['{p_name}']={p_id_list[0]},{table_constructor_delimiter}"
        else:
            middle += f"['{p_name}']={{{','.join(p_id_list)}}},{table_constructor_delimiter}"
    end = table_constructor_delimiter + "}"
    return begin + middle + end

def save_lua_code_to_file(code_str, fn, append=False, replace_linenr=0):
    if append:
        with open(fn, "r") as f:
            static_lines=f.readlines()
            static_lines[replace_linenr] = code_str + "\n"
            code_str = "".join(static_lines)
    with open(fn, "w") as f:
        f.write(code_str)

if __name__=="__main__":
    # TODO: test this code injection
    # print(escape_forbidden_symbols("'\\\']=nil} print('hello world') -- '"))
    code = make_lua_code()
    save_lua_code_to_file(code, "./scikgtex.lua", append=True, replace_linenr=-2)
