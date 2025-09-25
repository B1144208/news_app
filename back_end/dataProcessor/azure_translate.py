#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
將腳本和location_states.sql放在同一個目錄下執行
"""

import re
import time
import json
import requests
import uuid
import logging
import sqlite3
import threading
from datetime import datetime
from typing import List, Tuple, Dict, Optional
from dataclasses import dataclass, asdict
from concurrent.futures import ThreadPoolExecutor, as_completed
import sys
import os

@dataclass
class LocationRecord:
    id: int
    table_type: str
    name_original: str  # 改名為 name_original 更通用
    name_zh_cn: str = ""
    name_zh_tw: str = ""
    detected_language: str = ""  # 新增：偵測到的語言
    confidence: float = 0.0
    translation_status: str = "pending"  # pending, completed, failed
    error_message: str = ""
    translated_at: str = ""

class OptimizedAzureTranslator:
    def __init__(self, subscription_key: str, region: str = "eastasia"):
        """
        優化版 Azure 翻譯器 - 自動偵測語言版本
        
        Args:
            subscription_key: Azure 翻譯服務密鑰
            region: Azure 服務區域
        """
        self.subscription_key = subscription_key
        self.region = region
        self.endpoint = "https://api.cognitive.microsofttranslator.com"
        
        # 請求設置
        self.headers = {
            'Ocp-Apim-Subscription-Key': subscription_key,
            'Ocp-Apim-Subscription-Region': region,
            'Content-type': 'application/json',
            'X-ClientTraceId': str(uuid.uuid4())
        }
        
        # 翻譯設置
        self.batch_size = 50  # 降低批次大小以支持雙語翻譯
        self.max_workers = 2   # 降低並發以避免過度請求
        self.request_delay = 0.2  # 增加請求間隔
        self.max_retries = 3   # 最大重試次數
        
        # 進度保存設置
        self.progress_db = "translation_progress.db"
        self.session_id = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # 設置日誌
        self.setup_logging()
        
        # 初始化進度數據庫
        self.setup_progress_db()
        
        # 統計信息
        self.stats = {
            'total_records': 0,
            'completed_records': 0,
            'failed_records': 0,
            'skipped_records': 0,
            'characters_translated_cn': 0,  # 簡體翻譯字符數
            'characters_translated_tw': 0,  # 繁體翻譯字符數
            'api_calls_cn': 0,  # 簡體API調用次數
            'api_calls_tw': 0,  # 繁體API調用次數
            'detected_languages': {},  # 偵測到的語言統計
            'start_time': datetime.now()
        }
        
        # 測試連接
        self.test_connection()
        
        self.logger.info("優化版 Azure 自動偵測語言翻譯器初始化完成")
    
    def setup_logging(self):
        """設置日誌系統"""
        log_filename = f"azure_autodetect_translation_{self.session_id}.log"
        
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_filename, encoding='utf-8'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger('AzureAutoDetectTranslator')
        
        print(f"📝 日誌文件: {log_filename}")
    
    def setup_progress_db(self):
        """設置進度數據庫"""
        self.db_lock = threading.Lock()
        
        # 創建進度數據庫
        with sqlite3.connect(self.progress_db) as conn:
            conn.execute('''
                CREATE TABLE IF NOT EXISTS translation_progress (
                    session_id TEXT,
                    record_id INTEGER,
                    table_type TEXT,
                    name_original TEXT,
                    name_zh_cn TEXT,
                    name_zh_tw TEXT,
                    detected_language TEXT,
                    confidence REAL,
                    status TEXT,
                    error_message TEXT,
                    translated_at TEXT,
                    api_calls_cn INTEGER DEFAULT 0,
                    api_calls_tw INTEGER DEFAULT 0,
                    PRIMARY KEY (session_id, record_id, table_type)
                )
            ''')
            conn.commit()
    
    def test_connection(self):
        """測試 Azure 連接"""
        try:
            # 測試多種語言的自動偵測翻譯
            test_cases = [
                ("Hello World", "英文"),
                ("Bonjour", "法文"),
                ("Hola", "西班牙文"),
                ("こんにちは", "日文"),
                ("안녕하세요", "韓文")
            ]
            
            print("🔍 測試自動語言偵測...")
            
            for test_text, lang_name in test_cases:
                try:
                    result_cn, result_tw, detected_lang = self.translate_with_detection(test_text)
                    if result_cn and result_tw:
                        print(f"✅ {lang_name} ({detected_lang}): {test_text} -> 簡:{result_cn} 繁:{result_tw}")
                        break
                except:
                    continue
            else:
                raise Exception("所有測試案例都失敗")
                
            self.logger.info("Azure API 自動偵測連接測試成功")
            print("✅ Azure 翻譯服務自動偵測連接成功")
            
        except Exception as e:
            self.logger.error(f"Azure 連接測試失敗: {e}")
            print(f"❌ Azure 連接失敗: {e}")
            print("\n請檢查:")
            print("1. 訂閱密鑰是否正確")
            print("2. 服務區域是否正確")
            print("3. 網路連接是否正常")
            print("4. Azure 服務是否正常運行")
            raise
    
    def translate_with_detection(self, text: str) -> Tuple[Optional[str], Optional[str], Optional[str]]:
        """
        自動偵測語言並翻譯成雙語中文
        
        Args:
            text: 要翻譯的文本
            
        Returns:
            Tuple: (簡體中文, 繁體中文, 偵測到的語言)
        """
        if not text or not text.strip():
            return text, text, None
        
        # 先偵測語言
        detected_lang = self.detect_language(text)
        
        # 如果已經是中文，直接處理
        if detected_lang in ['zh-Hans', 'zh-Hant', 'zh']:
            if detected_lang == 'zh-Hans':
                # 原文是簡體，翻譯成繁體
                zh_tw = self.translate_single(text, 'zh-Hant')
                return text, zh_tw or text, detected_lang
            elif detected_lang == 'zh-Hant':
                # 原文是繁體，翻譯成簡體
                zh_cn = self.translate_single(text, 'zh-Hans')
                return zh_cn or text, text, detected_lang
            else:
                # 通用中文，嘗試轉換
                zh_cn = self.translate_single(text, 'zh-Hans')
                zh_tw = self.translate_single(text, 'zh-Hant')
                return zh_cn or text, zh_tw or text, detected_lang
        
        # 非中文，翻譯成雙語中文
        zh_cn = self.translate_single(text, 'zh-Hans')
        zh_tw = self.translate_single(text, 'zh-Hant')
        
        return zh_cn, zh_tw, detected_lang
    
    def detect_language(self, text: str) -> Optional[str]:
        """偵測文本語言"""
        if not text or not text.strip():
            return None
        
        try:
            url = f"{self.endpoint}/detect"
            params = {'api-version': '3.0'}
            body = [{'text': text}]
            
            response = requests.post(
                url,
                params=params,
                headers=self.headers,
                json=body,
                timeout=30
            )
            
            if response.status_code == 200:
                result = response.json()
                if result and result[0].get('language'):
                    detected_lang = result[0]['language']
                    score = result[0].get('score', 0)
                    
                    # 記錄偵測統計
                    if detected_lang not in self.stats['detected_languages']:
                        self.stats['detected_languages'][detected_lang] = 0
                    self.stats['detected_languages'][detected_lang] += 1
                    
                    self.logger.debug(f"語言偵測: {text[:20]}... -> {detected_lang} (信心:{score:.2f})")
                    return detected_lang
            
        except Exception as e:
            self.logger.warning(f"語言偵測失敗: {e} - {text[:20]}...")
        
        return None
    
    def translate_single(self, text: str, target_lang: str = 'zh-Hans') -> Optional[str]:
        """
        翻譯單個文本，自動偵測源語言
        
        Args:
            text: 要翻譯的文本
            target_lang: 目標語言 ('zh-Hans' 為簡體, 'zh-Hant' 為繁體)
        """
        if not text or not text.strip():
            return text
        
        for attempt in range(self.max_retries):
            try:
                url = f"{self.endpoint}/translate"
                params = {
                    'api-version': '3.0',
                    # 不指定 'from' 參數，讓 Azure 自動偵測源語言
                    'to': target_lang
                }
                
                body = [{'text': text}]
                response = requests.post(
                    url, 
                    params=params, 
                    headers=self.headers, 
                    json=body, 
                    timeout=30
                )
                
                if response.status_code == 200:
                    result = response.json()
                    if result and result[0]['translations']:
                        translated = result[0]['translations'][0]['text'].strip()
                        
                        # 記錄偵測到的源語言
                        if 'detectedLanguage' in result[0]:
                            detected_lang = result[0]['detectedLanguage']['language']
                            self.logger.debug(f"偵測語言: {detected_lang} -> {target_lang}: {text[:20]}...")
                        
                        # 統計字符和API調用
                        if target_lang == 'zh-Hans':
                            self.stats['characters_translated_cn'] += len(text)
                            self.stats['api_calls_cn'] += 1
                        elif target_lang == 'zh-Hant':
                            self.stats['characters_translated_tw'] += len(text)
                            self.stats['api_calls_tw'] += 1
                        
                        return translated
                elif response.status_code == 429:  # 限流
                    wait_time = (attempt + 1) * 3  # 增加等待時間
                    self.logger.warning(f"API 限流，等待 {wait_time} 秒... (目標語言: {target_lang})")
                    time.sleep(wait_time)
                    continue
                else:
                    self.logger.warning(f"HTTP 錯誤 {response.status_code}: {text[:20]}... (目標語言: {target_lang})")
                    
            except Exception as e:
                if attempt < self.max_retries - 1:
                    wait_time = (attempt + 1) * 2
                    self.logger.warning(f"翻譯錯誤 (嘗試 {attempt + 1}/{self.max_retries}): {e} (目標語言: {target_lang})")
                    time.sleep(wait_time)
                else:
                    self.logger.error(f"翻譯失敗: {e} - {text[:20]}... (目標語言: {target_lang})")
        
        return None
    
    def translate_batch(self, texts: List[str], target_lang: str) -> List[Optional[str]]:
        """批量翻譯（指定目標語言，自動偵測源語言）"""
        if not texts:
            return []
        
        try:
            url = f"{self.endpoint}/translate"
            params = {
                'api-version': '3.0',
                # 不指定 'from' 參數，讓 Azure 自動偵測源語言
                'to': target_lang
            }
            
            # 準備批量請求
            body = [{'text': text} for text in texts if text and text.strip()]
            
            response = requests.post(
                url,
                params=params,
                headers=self.headers,
                json=body,
                timeout=90  # 增加超時時間
            )
            
            if response.status_code == 200:
                results = response.json()
                translations = []
                
                for i, result in enumerate(results):
                    if result.get('translations'):
                        translated = result['translations'][0]['text'].strip()
                        translations.append(translated)
                        
                        # 記錄偵測語言
                        if 'detectedLanguage' in result:
                            detected_lang = result['detectedLanguage']['language']
                            if detected_lang not in self.stats['detected_languages']:
                                self.stats['detected_languages'][detected_lang] = 0
                            self.stats['detected_languages'][detected_lang] += 1
                        
                        # 統計
                        if target_lang == 'zh-Hans':
                            self.stats['characters_translated_cn'] += len(texts[i])
                        elif target_lang == 'zh-Hant':
                            self.stats['characters_translated_tw'] += len(texts[i])
                    else:
                        translations.append(None)
                
                # 統計API調用
                if target_lang == 'zh-Hans':
                    self.stats['api_calls_cn'] += 1
                elif target_lang == 'zh-Hant':
                    self.stats['api_calls_tw'] += 1
                
                return translations
            else:
                self.logger.error(f"批量翻譯失敗: HTTP {response.status_code} (目標語言: {target_lang})")
                return [None] * len(texts)
                
        except Exception as e:
            self.logger.error(f"批量翻譯錯誤: {e} (目標語言: {target_lang})")
            return [None] * len(texts)
    
    def save_progress(self, record: LocationRecord, api_calls_cn: int = 0, api_calls_tw: int = 0):
        """保存翻譯進度"""
        with self.db_lock:
            with sqlite3.connect(self.progress_db) as conn:
                conn.execute('''
                    INSERT OR REPLACE INTO translation_progress 
                    (session_id, record_id, table_type, name_original, name_zh_cn, name_zh_tw, 
                     detected_language, confidence, status, error_message, translated_at, api_calls_cn, api_calls_tw)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    self.session_id,
                    record.id,
                    record.table_type,
                    record.name_original,
                    record.name_zh_cn,
                    record.name_zh_tw,
                    record.detected_language,
                    record.confidence,
                    record.translation_status,
                    record.error_message,
                    record.translated_at,
                    api_calls_cn,
                    api_calls_tw
                ))
                conn.commit()
    
    def load_progress(self) -> Dict[Tuple[int, str], LocationRecord]:
        """載入之前的翻譯進度"""
        progress = {}
        
        with sqlite3.connect(self.progress_db) as conn:
            cursor = conn.execute('''
                SELECT record_id, table_type, name_original, name_zh_cn, name_zh_tw,
                       detected_language, confidence, status, error_message, translated_at,
                       api_calls_cn, api_calls_tw
                FROM translation_progress 
                WHERE session_id = ? AND status = 'completed'
            ''', (self.session_id,))
            
            for row in cursor:
                record = LocationRecord(
                    id=row[0],
                    table_type=row[1],
                    name_original=row[2],
                    name_zh_cn=row[3],
                    name_zh_tw=row[4],
                    detected_language=row[5],
                    confidence=row[6],
                    translation_status=row[7],
                    error_message=row[8],
                    translated_at=row[9]
                )
                progress[(record.id, record.table_type)] = record
                
                # 載入API調用統計
                if row[10]:  # api_calls_cn
                    self.stats['api_calls_cn'] += row[10]
                if row[11]:  # api_calls_tw  
                    self.stats['api_calls_tw'] += row[11]
                
                # 載入語言偵測統計
                if row[5]:  # detected_language
                    if row[5] not in self.stats['detected_languages']:
                        self.stats['detected_languages'][row[5]] = 0
                    self.stats['detected_languages'][row[5]] += 1
        
        return progress
    
    def parse_sql_files(self) -> List[LocationRecord]:
        """解析所有SQL文件"""
        all_records = []
        
        # 文件映射
        sql_files = [
            ('location_states.sql', 'states'),
            ('location_countries.sql', 'countries'),
            ('location_regions.sql', 'regions')
        ]
        
        for filename, table_type in sql_files:
            if os.path.exists(filename):
                records = self.parse_sql_file(filename, table_type)
                all_records.extend(records)
                self.logger.info(f"{filename}: 提取 {len(records)} 條記錄")
                print(f"✅ {filename}: {len(records)} 條記錄")
            else:
                self.logger.warning(f"文件不存在: {filename}")
                print(f"⚠️ 文件不存在: {filename}")
        
        return all_records
    
    def parse_sql_file(self, filename: str, table_type: str) -> List[LocationRecord]:
        """解析單個SQL文件"""
        try:
            with open(filename, 'r', encoding='utf-8') as f:
                content = f.read()
        except Exception as e:
            self.logger.error(f"讀取文件失敗 {filename}: {e}")
            return []
        
        # 提取INSERT語句
        table_name = f"location_{table_type}"
        pattern = rf"INSERT INTO `{table_name}`.*?VALUES\s*(.*?);"
        matches = re.findall(pattern, content, re.DOTALL | re.IGNORECASE)
        
        records = []
        
        for match in matches:
            lines = match.strip().split('\n')
            for line in lines:
                line = line.strip()
                if line.startswith('(') and (line.endswith('),') or line.endswith(');')):
                    record = self.parse_sql_line(line, table_type)
                    if record:
                        records.append(record)
        
        return records
    
    def parse_sql_line(self, line: str, table_type: str) -> Optional[LocationRecord]:
        """解析單行SQL數據"""
        try:
            # 移除括號
            line = line.strip('(),; ')
            
            # 簡單解析
            parts = []
            current = ""
            in_quote = False
            
            for char in line:
                if char == "'" and not in_quote:
                    in_quote = True
                elif char == "'" and in_quote:
                    in_quote = False
                    parts.append(current)
                    current = ""
                elif char == "," and not in_quote:
                    if current.strip() and not current.strip().startswith("'"):
                        parts.append(current.strip())
                    current = ""
                else:
                    if in_quote:
                        current += char
                    elif char != " " or current:
                        current += char
            
            if current.strip():
                parts.append(current.strip())
            
            # 根據表類型創建記錄
            if table_type == "states" and len(parts) >= 4:
                return LocationRecord(
                    id=int(parts[0]),
                    table_type=table_type,
                    name_original=parts[3]  # 改為 name_original
                )
            elif table_type == "countries" and len(parts) >= 6:
                return LocationRecord(
                    id=int(parts[0]),
                    table_type=table_type,
                    name_original=parts[5]  # 改為 name_original
                )
            elif table_type == "regions" and len(parts) >= 2:
                return LocationRecord(
                    id=int(parts[0]),
                    table_type=table_type,
                    name_original=parts[1]  # 改為 name_original
                )
                
        except Exception as e:
            self.logger.error(f"解析行失敗: {line[:50]}... - {e}")
        
        return None
    
    def translate_record(self, record: LocationRecord) -> LocationRecord:
        """翻譯單個記錄 - 自動偵測語言版本"""
        api_calls_cn = 0
        api_calls_tw = 0
        
        try:
            # 自動偵測語言並翻譯成雙語中文
            zh_cn, zh_tw, detected_lang = self.translate_with_detection(record.name_original)
            
            # 統計API調用（translate_with_detection內部已統計，這裡記錄用於進度保存）
            if zh_cn and zh_cn != record.name_original:
                api_calls_cn = 1
            if zh_tw and zh_tw != record.name_original:
                api_calls_tw = 1
            
            # 檢查翻譯結果
            if zh_cn and zh_tw and (zh_cn != record.name_original or zh_tw != record.name_original):
                # 翻譯成功
                record.name_zh_cn = zh_cn
                record.name_zh_tw = zh_tw
                record.detected_language = detected_lang or "unknown"
                
                # 根據翻譯情況設定信心分數
                if zh_cn != record.name_original and zh_tw != record.name_original:
                    record.confidence = 0.95  # 雙語都翻譯成功
                elif zh_cn != record.name_original or zh_tw != record.name_original:
                    record.confidence = 0.85  # 單語翻譯成功
                else:
                    record.confidence = 0.60  # 可能是中文互轉
                
                record.translation_status = "completed"
                record.translated_at = datetime.now().isoformat()
                
                self.stats['completed_records'] += 1
                
                self.logger.info(f"翻譯成功 [{detected_lang}]: {record.name_original} -> 簡: {zh_cn}, 繁: {zh_tw}")
                
            else:
                # 翻譯失敗，保持原文
                record.name_zh_cn = record.name_original
                record.name_zh_tw = record.name_original
                record.detected_language = detected_lang or "unknown"
                record.confidence = 0.0
                record.translation_status = "failed"
                record.error_message = "翻譯返回空結果或與原文相同"
                
                self.stats['failed_records'] += 1
                
                self.logger.error(f"翻譯失敗 [{detected_lang}]: {record.name_original}")
                
        except Exception as e:
            record.translation_status = "failed"
            record.error_message = str(e)
            self.stats['failed_records'] += 1
            self.logger.error(f"翻譯記錄失敗: {record.name_original} - {e}")
        
        # 保存進度
        self.save_progress(record, api_calls_cn, api_calls_tw)
        
        return record
    
    def translate_all_records(self, records: List[LocationRecord]) -> List[LocationRecord]:
        """翻譯所有記錄"""
        self.stats['total_records'] = len(records)
        
        # 載入之前的進度
        previous_progress = self.load_progress()
        
        # 過濾已完成的記錄
        pending_records = []
        completed_records = []
        
        for record in records:
            key = (record.id, record.table_type)
            if key in previous_progress:
                completed_record = previous_progress[key]
                completed_records.append(completed_record)
                self.stats['skipped_records'] += 1
            else:
                pending_records.append(record)
        
        self.logger.info(f"載入進度: 已完成 {len(completed_records)} 條，待處理 {len(pending_records)} 條")
        print(f"📊 進度統計: 已完成 {len(completed_records)} 條，待處理 {len(pending_records)} 條")
        
        if not pending_records:
            print("✅ 所有記錄已完成翻譯")
            return completed_records
        
        # 顯示已偵測的語言統計
        if self.stats['detected_languages']:
            print(f"\n🔍 已偵測語言:")
            for lang, count in sorted(self.stats['detected_languages'].items()):
                print(f"  {lang}: {count} 條")
        
        # 開始翻譯待處理記錄
        self.logger.info(f"開始自動偵測語言翻譯 {len(pending_records)} 條記錄")
        print(f"\n🔄 開始自動偵測語言翻譯 {len(pending_records)} 條記錄")
        print(f"使用服務: Azure Translator (自動偵測 -> 雙語中文)")
        print(f"預估API調用: {len(pending_records) * 2} 次")
        
        # 使用線程池並發翻譯
        translated_records = []
        
        with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            # 提交翻譯任務
            future_to_record = {
                executor.submit(self.translate_record, record): record 
                for record in pending_records
            }
            
            # 處理完成的任務
            for i, future in enumerate(as_completed(future_to_record), 1):
                try:
                    translated_record = future.result()
                    translated_records.append(translated_record)
                    
                    # 進度報告
                    progress = (i / len(pending_records)) * 100
                    success_rate = (self.stats['completed_records'] / max(i, 1)) * 100
                    
                    print(f"[{i}/{len(pending_records)}] ({translated_record.detected_language}) {translated_record.name_original}")
                    print(f"  簡中: {translated_record.name_zh_cn}")
                    print(f"  繁中: {translated_record.name_zh_tw}")
                    print(f"  信心: {translated_record.confidence:.2f}")
                    
                    if i % 20 == 0 or i == len(pending_records):
                        total_api_calls = self.stats['api_calls_cn'] + self.stats['api_calls_tw']
                        total_chars = self.stats['characters_translated_cn'] + self.stats['characters_translated_tw']
                        
                        self.logger.info(
                            f"進度: {i}/{len(pending_records)} ({progress:.1f}%) | "
                            f"成功率: {success_rate:.1f}% | "
                            f"API調用: {total_api_calls} | "
                            f"字符數: {total_chars:,}"
                        )
                        print(f"\n📈 進度: {progress:.1f}% | 成功率: {success_rate:.1f}% | API調用: {total_api_calls}")
                        
                        # 顯示當前語言分布
                        if self.stats['detected_languages']:
                            print("   🔍 語言分布:", end=" ")
                            for lang, count in list(self.stats['detected_languages'].items())[:5]:
                                print(f"{lang}({count})", end=" ")
                            if len(self.stats['detected_languages']) > 5:
                                print("...")
                            else:
                                print()
                        print()
                    
                except Exception as e:
                    record = future_to_record[future]
                    self.logger.error(f"處理記錄失敗: {record.name_original} - {e}")
                
                # 請求間隔
                time.sleep(self.request_delay)
        
        # 合併結果
        all_translated = completed_records + translated_records
        
        return all_translated
    
    def save_results(self, records: List[LocationRecord]):
        """保存翻譯結果"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # 保存SQL文件
        sql_filename = f"azure_autodetect_translated_{timestamp}.sql"
        self.save_sql_file(records, sql_filename)
        
        # 保存JSON文件（完整數據）
        json_filename = f"azure_autodetect_data_{timestamp}.json"
        self.save_json_file(records, json_filename)
        
        # 保存統計報告
        report_filename = f"azure_autodetect_report_{timestamp}.txt"
        self.save_report(report_filename)
        
        print(f"\n📁 輸出文件:")
        print(f"  📄 {sql_filename} (數據庫更新)")
        print(f"  📊 {json_filename} (完整數據)")
        print(f"  📈 {report_filename} (統計報告)")
    
    def save_sql_file(self, records: List[LocationRecord], filename: str):
        """保存SQL更新文件"""
        with open(filename, 'w', encoding='utf-8') as f:
            f.write("-- Azure 自動偵測語言翻譯更新文件\n")
            f.write(f"-- 生成時間: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"-- 會話ID: {self.session_id}\n")
            f.write(f"-- 翻譯服務: Azure Translator (自動偵測語言)\n")
            f.write(f"-- 總記錄數: {len(records)}\n")
            f.write(f"-- 成功翻譯: {self.stats['completed_records']}\n")
            f.write(f"-- 簡體字符: {self.stats['characters_translated_cn']:,}\n")
            f.write(f"-- 繁體字符: {self.stats['characters_translated_tw']:,}\n")
            f.write(f"-- API調用: {self.stats['api_calls_cn'] + self.stats['api_calls_tw']}\n")
            
            # 語言分布
            if self.stats['detected_languages']:
                f.write(f"-- 偵測語言: {', '.join([f'{k}({v})' for k, v in sorted(self.stats['detected_languages'].items())])}\n")
            
            f.write("\nUSE `news`;\n\n")
            
            # 按表類型分組
            for table_type in ['regions', 'countries', 'states']:
                table_records = [r for r in records if r.table_type == table_type]
                if table_records:
                    f.write(f"-- 更新 location_{table_type} 表 ({len(table_records)} 條記錄)\n")
                    for record in table_records:
                        zh_tw = record.name_zh_tw.replace("'", "\\'")
                        zh_cn = record.name_zh_cn.replace("'", "\\'")
                        
                        id_field = f"{table_type[:-1]}_id"
                        name_field = f"{table_type[:-1]}_name"
                        
                        f.write(f"UPDATE `location_{table_type}` SET\n")
                        f.write(f"  `{name_field}_zh_tw` = '{zh_tw}',\n")
                        f.write(f"  `{name_field}_zh_cn` = '{zh_cn}'\n")
                        f.write(f"WHERE `{id_field}` = {record.id};\n")
                        f.write(f"-- 偵測語言: {record.detected_language}, 信心: {record.confidence:.2f}\n\n")
            
            f.write("COMMIT;\n")
        
        self.logger.info(f"SQL文件已保存: {filename}")
    
    def save_json_file(self, records: List[LocationRecord], filename: str):
        """保存JSON數據文件"""
        # 處理統計數據中的 datetime 對象
        stats_copy = self.stats.copy()
        if 'start_time' in stats_copy and isinstance(stats_copy['start_time'], datetime):
            stats_copy['start_time'] = stats_copy['start_time'].isoformat()
        
        data = {
            'metadata': {
                'session_id': self.session_id,
                'generated_at': datetime.now().isoformat(),
                'translation_service': 'Azure Translator (Auto-Detect)',
                'total_records': len(records),
                'detected_languages': self.stats['detected_languages'],
                'statistics': stats_copy
            },
            'records': [asdict(record) for record in records]
        }
        
        # 使用自定義編碼器處理可能的 datetime 對象
        class DateTimeEncoder(json.JSONEncoder):
            def default(self, obj):
                if isinstance(obj, datetime):
                    return obj.isoformat()
                return super().default(obj)
        
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2, cls=DateTimeEncoder)
        
        self.logger.info(f"JSON文件已保存: {filename}")
    
    def save_report(self, filename: str):
        """保存統計報告"""
        duration = datetime.now() - self.stats['start_time']
        total_api_calls = self.stats['api_calls_cn'] + self.stats['api_calls_tw']
        total_chars = self.stats['characters_translated_cn'] + self.stats['characters_translated_tw']
        
        with open(filename, 'w', encoding='utf-8') as f:
            f.write("Azure 自動偵測語言翻譯系統統計報告\n")
            f.write("=" * 60 + "\n\n")
            f.write(f"會話ID: {self.session_id}\n")
            f.write(f"生成時間: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            
            f.write("📊 翻譯統計:\n")
            f.write(f"  總記錄數: {self.stats['total_records']:,}\n")
            f.write(f"  成功翻譯: {self.stats['completed_records']:,}\n")
            f.write(f"  翻譯失敗: {self.stats['failed_records']:,}\n")
            f.write(f"  跳過記錄: {self.stats['skipped_records']:,}\n")
            f.write(f"  成功率: {(self.stats['completed_records'] / max(self.stats['total_records'], 1)) * 100:.2f}%\n\n")
            
            f.write("🔍 語言偵測統計:\n")
            if self.stats['detected_languages']:
                for lang, count in sorted(self.stats['detected_languages'].items(), key=lambda x: x[1], reverse=True):
                    percentage = (count / self.stats['total_records']) * 100
                    f.write(f"  {lang}: {count:,} 條 ({percentage:.1f}%)\n")
            else:
                f.write("  無偵測數據\n")
            f.write("\n")
            
            f.write("🔤 字符統計:\n")
            f.write(f"  簡體翻譯字符: {self.stats['characters_translated_cn']:,}\n")
            f.write(f"  繁體翻譯字符: {self.stats['characters_translated_tw']:,}\n")
            f.write(f"  總翻譯字符: {total_chars:,}\n\n")
            
            f.write("🔌 API 調用統計:\n")
            f.write(f"  簡體API調用: {self.stats['api_calls_cn']:,}\n")
            f.write(f"  繁體API調用: {self.stats['api_calls_tw']:,}\n")
            f.write(f"  總API調用: {total_api_calls:,}\n\n")
            
            f.write("⏱️ 時間統計:\n")
            f.write(f"  開始時間: {self.stats['start_time'].strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"  總耗時: {duration}\n")
            f.write(f"  平均速度: {self.stats['completed_records'] / max(duration.total_seconds(), 1):.2f} 記錄/秒\n")
            f.write(f"  API效率: {total_api_calls / max(duration.total_seconds(), 1):.2f} 調用/秒\n\n")
            
            f.write("💰 成本估算:\n")
            estimated_cost = max(0, (total_chars - 2000000) / 1000000 * 10)
            f.write(f"  翻譯字符: {total_chars:,}\n")
            f.write(f"  預估費用: ${estimated_cost:.2f} USD (超出免費額度部分)\n")
            f.write(f"  免費額度: 2,000,000 字符/月\n")
            f.write(f"  語言偵測: 免費 (包含在翻譯API中)\n\n")
            
            f.write("💡 建議:\n")
            f.write("  1. 在數據庫中執行生成的SQL文件\n")
            f.write("  2. 檢查失敗記錄並手動處理\n")
            f.write("  3. 定期清理進度數據庫\n")
            f.write("  4. 監控Azure使用量避免超出限額\n")
            f.write("  5. 檢查偵測語言的準確性\n")
            f.write("  6. 對比簡繁翻譯結果的一致性\n")
        
        self.logger.info(f"統計報告已保存: {filename}")


def main():
    """主程序"""
    print("🚀 優化版 Azure 自動偵測語言翻譯系統")
    print("=" * 60)
    print("✨ 特點: 自動偵測語言 | 雙語翻譯 | 斷點續傳 | 批量優化 | 進度跟蹤")
    print("")
    
    # 獲取 Azure 配置
    print("🔋 Azure 配置:")
    print("請確保您已經:")
    print("1. 註冊 Azure 免費帳戶")
    print("2. 創建翻譯服務")
    print("3. 獲取API密鑰和區域")
    print("4. 系統將自動偵測源語言並翻譯成中文")
    print("")
    
    subscription_key = input("請輸入 Azure 訂閱密鑰: ").strip()
    if not subscription_key:
        print("❌ 需要 Azure 訂閱密鑰")
        return
    
    region = input("請輸入服務區域 (預設: eastasia): ").strip() or "eastasia"
    
    try:
        # 初始化翻譯器
        print("\n🔧 初始化自動偵測語言翻譯系統...")
        translator = OptimizedAzureTranslator(subscription_key, region)
        
        # 解析SQL文件
        print("\n📖 解析SQL文件...")
        all_records = translator.parse_sql_files()
        
        if not all_records:
            print("❌ 沒有找到地名數據")
            return
        
        # 顯示統計信息
        print(f"\n📊 數據統計:")
        by_type = {}
        for record in all_records:
            by_type[record.table_type] = by_type.get(record.table_type, 0) + 1
        
        for table_type, count in by_type.items():
            print(f"  {table_type}: {count:,} 條")
        
        print(f"\n總計: {len(all_records):,} 條記錄")
        
        # 估算成本和時間
        total_chars = sum(len(record.name_original) for record in all_records)
        estimated_api_calls = len(all_records) * 2  # 雙語翻譯
        estimated_time = len(all_records) * 0.2 / 60  # 估算分鐘
        estimated_cost = max(0, (total_chars * 2 - 2000000) / 1000000 * 10)  # 雙語成本
        
        print(f"📈 預估:")
        print(f"  原始字符: {total_chars:,}")
        print(f"  翻譯字符: {total_chars * 2:,} (雙語)")
        print(f"  API調用: {estimated_api_calls:,}")
        print(f"  翻譯時間: {estimated_time:.1f} 分鐘")
        print(f"  預估費用: ${estimated_cost:.2f} USD (超出免費額度部分)")
        
        # 確認開始
        print("\n⚠️ 重要提醒:")
        print("- 系統將自動偵測每個文本的語言")
        print("- 英文、日文、韓文等將翻譯成中文")
        print("- 中文將進行簡繁互轉")
        print("- 支持斷點續傳，可隨時中斷和恢復")
        print("- 進度會自動保存到本地數據庫")
        
        if input("\n是否開始自動偵測語言翻譯? (y/n): ").lower().strip() not in ['y', 'yes']:
            print("👋 翻譯已取消")
            return
        
        # 開始翻譯
        print("\n" + "="*60)
        translated_records = translator.translate_all_records(all_records)
        
        # 保存結果
        print("\n💾 保存翻譯結果...")
        translator.save_results(translated_records)
        
        # 顯示完成報告
        duration = datetime.now() - translator.stats['start_time']
        success_rate = (translator.stats['completed_records'] / translator.stats['total_records']) * 100
        total_api_calls = translator.stats['api_calls_cn'] + translator.stats['api_calls_tw']
        total_chars = translator.stats['characters_translated_cn'] + translator.stats['characters_translated_tw']
        
        print(f"\n🎉 自動偵測語言翻譯完成！")
        print(f"⏱️ 總耗時: {duration}")
        print(f"📊 成功率: {success_rate:.1f}%")
        print(f"🔤 翻譯字符: {total_chars:,}")
        print(f"🔌 API調用: {total_api_calls}")
        
        # 顯示語言分布
        if translator.stats['detected_languages']:
            print(f"\n🔍 偵測到的語言:")
            for lang, count in sorted(translator.stats['detected_languages'].items(), key=lambda x: x[1], reverse=True):
                percentage = (count / len(all_records)) * 100
                print(f"  {lang}: {count} 條 ({percentage:.1f}%)")
        
        if translator.stats['failed_records'] > 0:
            print(f"\n⚠️ 失敗記錄: {translator.stats['failed_records']} 條")
            print("建議檢查日誌文件了解失敗原因")
        
        print(f"\n💡 下一步:")
        print("1. 檢查偵測語言的準確性")
        print("2. 在數據庫中執行生成的SQL文件")
        print("3. 比較簡繁翻譯結果的一致性")
        print("4. 手動檢查失敗記錄")
        print("5. 清理進度數據庫（如不需要恢復）")
        
    except KeyboardInterrupt:
        print("\n⏹️ 翻譯被中斷")
        print("💡 提示: 下次運行時會自動從中斷點恢復")
    except Exception as e:
        print(f"\n❌ 翻譯失敗: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()