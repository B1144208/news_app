import os
import json
from .BBC import bbc_spider
from .CTS import cts_spider

NAME = "Daniel"
BASE_PATH = os.path.join(os.path.dirname(__file__), "newsCrawler")
os.makedirs(BASE_PATH, exist_ok=True)

def load_json(path):
    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                return json.load(f)
        except:
            return []
    return []

def save_json(data, path, key="url"):
    old_data = load_json(path)
    existing_keys = {item[key] for item in old_data if key in item}

    new_items = []
    for item in data:
        if key in item and item[key] not in existing_keys:
            new_items.append(item)

    all_data = old_data + new_items

    with open(path, "w", encoding="utf-8") as f:
        json.dump(all_data, f, ensure_ascii=False, indent=2)

    print(f"✅ 已保存 {path}（新增 {len(new_items)} 筆，總共 {len(all_data)} 筆）")

def main():
    # BBC
    channel_info = bbc_spider.get_channel_info()
    news_list = bbc_spider.fetch_news_list(limit=5)

    channel_path = os.path.join(BASE_PATH, f"CHANNEL_DATA_{NAME}.json")
    news_path = os.path.join(BASE_PATH, f"NEWS_DATA_{NAME}_V2.json")

    save_json([channel_info], channel_path, key="name")
    save_json(news_list, news_path, key="url")

    # CTS
    channel_info = cts_spider.get_channel_info()
    news_list = cts_spider.fetch_news_list(limit=20)

    cts_channel_path = os.path.join(BASE_PATH, f"CHANNEL_DATA_{NAME}_CTS.json")
    cts_news_path = os.path.join(BASE_PATH, f"NEWS_DATA_{NAME}_CTS_V2.json")

    save_json([channel_info], cts_channel_path, key="name")
    save_json(news_list, cts_news_path, key="url")


if __name__ == "__main__":
    main()
