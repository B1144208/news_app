# use countries.json

import json
import sys
import os
from mysql.connector import Error

# 捕捉錯誤 Value
def safe_float(numeric_code, value, default=0.0):
    try:
        return float(value)
    except (ValueError, TypeError):
        print('error: ${numeric_code}')
        return default


if __name__ == "__main__":

    # 將專案根目錄（back_end）加入 sys.path
    base_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../../', 'back_end'))
    sys.path.append(base_path)

    from db import get_connection   # 匯入連線

    connect = get_connection()      # 建立連線
    cursor = connect.cursor()       # 開啟操作游標

    # 讀取 JSON 檔案
    with open('./data/countries.json', 'r', encoding='utf-8') as f:
        countries = json.load(f)

    # INSERT 語法
    sql = """
    INSERT INTO region_countries (
        region_id,
        country_numeric_code, country_iso2, country_iso3,
        country_name_en, country_name_zh_cn,
        country_center_latitude, country_center_longitude
    )
    VALUES(%s, %s, %s, %s, %s, %s, %s, %s)
    """

    count = 1
    while True:

        # 嘗試從 countries 找到 id == count 的那筆資料
        country = next((c for c in countries if c.get('id') == count), None)
        if not country:
            break

        data = (
            country.get('region_id'),
            country.get('numeric_code'),
            country.get('iso2'),
            country.get('iso3'),
            country.get('name'),
            country.get('translations', {}).get('zh-CN'),
            safe_float(country.get('numeric_code'), country.get('latitude')),
            safe_float(country.get('numeric_code'), country.get('longitude'))
        )

        try:
            cursor.execute(sql, data)
        except Error as e:
            print(f"❌ 匯入失敗：id = {count}")
            print("🚫 錯誤訊息:", e)
            print("📝 錯誤資料:", data)

        count += 1

    connect.commit()
    cursor.close()
    connect.close()
    print("✅ countries 資料匯入完成")
