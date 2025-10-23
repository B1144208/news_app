import requests
from bs4 import BeautifulSoup
import json

url = "https://slashdot.org/"
res = requests.get(url, headers={"User-Agent": "Mozilla/5.0"})
soup = BeautifulSoup(res.text, "html.parser")

articles = soup.find_all("article", class_="fhitem-story")

data_list = []
for art in articles:
    # 取出標題文字
    title_tag = art.find("h2", class_="story").find("a", onclick="return toggle_fh_body_wrap_return(this);")
    title = title_tag.get_text(strip=True) if title_tag else ""

    # 取出內文段落文字
    body_div = art.find("div", class_="body")
    discuss_texts = []
    if body_div:
        for p in body_div.find_all("div", class_="p"):
            # 轉換 <br> 為換行
            for br in p.find_all("br"):
                br.replace_with("\n")
            discuss_texts.append(p.get_text(" ", strip=True))

    # 加入結果
    if title or discuss_texts:
        data_list.append({
            "data": title,
            "discuss": discuss_texts
        })

# 輸出成 JSON 檔案
with open("SLASHDOT_DATA.json", "w", encoding="utf-8") as f:
    json.dump(data_list, f, ensure_ascii=False, indent=2)

print("共爬取", len(data_list), "篇文章，已輸出 SLASHDOT_DATA.json")