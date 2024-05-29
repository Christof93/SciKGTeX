import json
import requests

def crawl_predicates():
    host = "https://orkg.org"
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
        else:
            print(predicates_page_request)
    print(f"number of labels: {len(name_id_store)}")
    print(f"number of predicates: {pred_count}")
    return name_id_store

def get_predicates_from_dump():
    host = "https://orkg.org"
    name_id_store = {}

    predicates_request = requests.get(
        f"{host}/files/mappings/predicate-ids_to_label.json",
        headers = {
            "content-type": "application/json;charset=utf-8",
            "Accept": "application/json",
        }
    )
    if predicates_request.status_code==200:
        pred_dict = predicates_request.json()
        for pred_id, name in pred_dict.items():
            if name in name_id_store:
                name_id_store[name] += [pred_id]
            else:
                name_id_store[name] = [pred_id]
    else:
        return
    
    print(f"number of labels: {len(name_id_store)}")
    print(f"number of predicates: {len(pred_dict)}")
    return name_id_store

def save_json_to_file(obj, fn):
    with open(fn, "w") as f:
        json.dump(obj, f)

if __name__=="__main__":
    name_id_store = get_predicates_from_dump()
    if name_id_store is not None:
        save_json_to_file(name_id_store, "./build/orkg_predicates.json")