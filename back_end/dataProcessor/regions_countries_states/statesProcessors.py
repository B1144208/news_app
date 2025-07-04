# use states.json

import json
import sys
import os
from mysql.connector import Error
from countriesProcessor import safe_float

# 將專案根目錄（back_end）加入 sys.path
base_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../../', 'back_end'))
sys.path.append(base_path)

from db import get_connection   # 匯入連線

connect = get_connection()      # 建立連線
cursor = connect.cursor()       # 開啟操作游標

# 讀取 
cursor.execute('SELECT country_id, country_iso2 FROM countries;')
countries = cursor.fetchall()
country_map = {c[0]: c[1] for c in countries}

# 讀取 JSON 檔案
with open ('./data/states.json', 'r', encoding='utf-8') as f:
    states = json.load(f)

# INSERT 語法
sql = """
INSERT INTO region_states (
    country_id,  state_code, state_name_en,
    state_center_latitude, state_center_longitude
) VALUES (%s, %s, %s, %s, %s);
"""

success = 0
failed = 0

for state in states:
    # 檢查 country 是否一致
    c_id = state.get('country_id')
    c_code = state.get('country_code')
    if (c_id not in country_map) or (country_map[c_id] != c_code):
        print(f"❌ Error: {state.get('state_code')} -> country_id={c_id} 與 country_code={c_code} 不一致，跳過")
        failed += 1
        continue

    data = (
        state.get('country_id'),
        state.get('state_code'),
        state.get('name'),
        safe_float(state.get('country_id'), state.get('latitude')),
        safe_float(state.get('country_id'), state.get('longitude'))
    )

    try:
        cursor.execute(sql, data)
        success += 1
    except Error as e:
        print(f"❌ state_id={state.get('id')} 寫入錯誤:", e)
        failed += 1
    
connect.commit()
cursor.close()
connect.close()
print(f"✅ 匯入完成：成功 {success} 筆，失敗 {failed} 筆")