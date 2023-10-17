import json
import requests

def crawl_predicates():
    host = "https://incubating.orkg.org"
    name_id_store = {}
    page_n = 0
    last = False
    pred_count = 0
    while not last:
        predicates_page_request = requests.get(
            f"{host}/api/predicates/",
            params = {
                "page":page_n,
                "sortBy": "id",
            },
            headers = {
                "content-type": "application/json;charset=utf-8",
                "Accept": "application/json",
            }
        )
        if predicates_page_request.status_code==200:
            body = predicates_page_request.json()
            page_n = body["pageable"]["pageNumber"] + 1
            last = body["last"]
            for pred in body["content"]:
                pred_count+=1
                name = pred["label"]
                id = pred["id"]
                if name in name_id_store:
                    name_id_store[name] += [id]
                else:
                    name_id_store[name] = [id]
    print(name_id_store)
    print(f"number of labels: {len(name_id_store)}")
    print(f"number of predicates: {pred_count}")
    return name_id_store
def save_json_to_file(obj, fn):
    with open(fn, "w") as f:
        json.dump(obj, f)

def get_from_file(fn):
    with open(fn, "r") as f:
        obj = json.load(f)
    return obj

def make_lua_code(prettify_table = False):
    if prettify_table:
        table_constructor_delimiter = "\n"
    begin = "SciKGTeX.orkg_property_uri_map = {" + table_constructor_delimiter
    middle = ""
    name_id_store = get_from_file("orkg_predicates.json")
    for p_name in name_id_store:
        p_id_list = name_id_store[p_name]
        p_id_list = [f"'{id}'" for id in p_id_list]
        if len(p_id_list)==1:
            middle += f"'{p_name}'={p_id_list[0]},{table_constructor_delimiter}"
        else:
            middle += f"'{p_name}'={{{','.join(p_id_list)}}},{table_constructor_delimiter}"
    end = table_constructor_delimiter + "}"
    return begin + middle + end

def save_lua_code_to_file(code_str, fn):
    with open(fn, "w") as f:
        f.write(code_str)

if __name__=="__main__":
    # name_id_store = crawl_predicates()
    # save_json_to_file(name_id_store, "orkg_predicates.json")

    code = make_lua_code(prettify_table=True)
    save_lua_code_to_file(code, "lua_table_code.lua")
