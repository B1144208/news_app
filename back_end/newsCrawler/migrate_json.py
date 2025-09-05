import os
import json

BASE_PATH = os.path.join(os.path.dirname(__file__), "newsCrawler")

def migrate_old_news(path, channel="未知來源", group=""):
    if not os.path.exists(path):
        print(f"⚠️ 找不到檔案 {path}")
        return

    # 讀舊資料
    with open(path, "r", encoding="utf-8") as f:
        try:
            old_data = json.load(f)
        except json.JSONDecodeError:
            print(f"⚠️ JSON 解析錯誤: {path}")
            return

    new_data = []
    for item in old_data:
        # 🔄 轉換新結構
        news = {
            "url": item.get("url") or item.get("link", ""),
            "group": group,
            "channel": channel,
            "cover_img": {
                "src": item.get("cover_img") or item.get("image") or "",
                "alt": ""
            },
            "news_title": item.get("news_title") or item.get("title") or "",
            "publish_date": item.get("publish_date") or item.get("date") or "",
            "location": "",
            "detail": [],
            "keyword": []
        }

        # 🔎 detail 處理
        if isinstance(item.get("detail"), list):
            news["detail"] = item["detail"]
        elif isinstance(item.get("detail"), str):
            news["detail"] = [{"text": p.strip(), "img": {"src": "", "alt": ""}}
                              for p in item["detail"].split("\n") if p.strip()]
        elif isinstance(item.get("content"), str):
            news["detail"] = [{"text": p.strip(), "img": {"src": "", "alt": ""}}
                              for p in item["content"].split("\n") if p.strip()]

        # 🔑 keyword 固定格式（沒有就給 [""]）
        if "keyword" in item and item["keyword"]:
            news["keyword"] = item["keyword"]
        else:
            news["keyword"] = [""]

        new_data.append(news)

    # ⏩ 產生新檔名 (加 V2)
    base, ext = os.path.splitext(path)
    new_path = base + "_V2" + ext

    with open(new_path, "w", encoding="utf-8") as f:
        json.dump(new_data, f, ensure_ascii=False, indent=2)

    print(f"✅ 已轉換並輸出 {new_path}（共 {len(new_data)} 筆）")


if __name__ == "__main__":
    migrate_old_news(os.path.join(BASE_PATH, "NEWS_DATA_Danie_V2l.json"), channel="BBC", group="BBC新聞")
    migrate_old_news(os.path.join(BASE_PATH, "NEWS_DATA_Daniel_CTS_V2.json"), channel="CTS", group="CTS新聞")
