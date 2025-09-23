### 包含的物件 :
### 1. CrawlerData
### 2. CrawlerQueue
### 3. ErrorLog

import os
import json
import threading, time, signal, sys, atexit
import concurrent.futures

from pathlib import Path
from dotenv import load_dotenv
from queue import Queue, Empty
from collections import deque
from typing import Any, List, Dict, Tuple, Iterable, Optional, Literal, Callable
from selenium.webdriver.remote.webdriver import WebDriver

from utils import call_news_api, call_channel_api, save_data_to_json

env_path = Path(__file__).resolve().parent.parent / ".env"   # .env path
load_dotenv(dotenv_path=env_path)

# Data path 資訊 封裝
class CrawlerData:
    
    def __init__(self, channel_id):
        self.channel_id = channel_id
        self.path = Path(__file__).resolve().parent.parent / os.getenv("CRAWLER_DATA_PATH")
        self.news = channel_id + "_" + os.getenv("CRAWLER_NEWS_FILE")
        self.channel = channel_id + "_" + os.getenv("CRAWLER_CHANNEL_FILE")

# Queue 封裝
class CrawlerQueue:

    """
    一個可重用、可自動備份的佇列封裝：
    - push_one / push_many：放資料
    - pop / try_pop：取資料（阻塞 / 非阻塞）
    - snapshot / drain：快照或清空導出
    - start_autobackup / stop_autobackup：背景自動備份到 JSON
    - 自動攔截 SIGINT / SIGTERM 與 atexit，在退出前備份
    """

    def __init__(
        self,
        name: str,
        kind: Literal["news", "channel"],
        crawler_data: CrawlerData,
        interval_sec: int = 300,        # 每 5 分鐘自動備份
        progress_every: int = 50,       # 每 50 筆資料就呼叫 api
    ):
        self.Q = Queue(maxsize=5000)
        self.name = name + "-" + kind
        self.kind = kind
        self.channel_id = crawler_data.channel_id
        self.backup_path = crawler_data.path
        self.backup_file = crawler_data.news if kind=="news" else crawler_data.channel
        self.interval_sec = max ( 1, interval_sec)
        self.progress_every = max ( 1, progress_every)
        
        self._bk_thread: Optional[threading.Thread] = None
        self._bk_stop = threading.Event()
        self._is_backup_in_progress = threading.Event()

        # 開啟自動備份
        self.start_autobackup()

        # 註冊優雅退出備份
        atexit.register(self._graceful_backup)                  # 程式正常退出，呼叫備份
        signal.signal(signal.SIGINT, self._signal_handler)      # Ctrl + C
        signal.signal(signal.SIGTERM, self._signal_handler)     # Kill
    
    # ========== 基本操作 ==========
    def push_one ( self, item: Any ) -> None:
        self.Q.put(item)
    
    def push_many ( self, items: Iterable[Any] ) -> None:
        for it in items:
            self.push_one(it)
    
    def pop ( self, timeout: Optional[float] = None) -> Any:
        """ 阻塞式取出一筆 ( 可選 timeout 秒 ) """
        return self.Q.get(timeout=timeout)

    def try_pop ( self ) -> Optional[Any]:
        """ 非阻塞式取出，若無資料則回傳 None """
        try:
            return self.Q.get_nowait()
        except Empty:
            return None
    
    def qsize ( self ) -> int:  # 佇列長度
        return self.Q.qsize()
    
    def empty ( self ) -> bool:
        return self.Q.empty()
    
    # ========== 備份 / 匯出 ==========
    def snapshot ( self ) -> list:
        """ 不消費資料的快照 ( 淺拷貝 ) """
        # 讀取底層 deque，不改變佇列狀態
        return list ( self.Q.queue )
    
    def _safe_snapshot ( self ) -> list:
        """ 不消費資料的快照 ( 互斥鎖 ) """
        with self.Q.mutex:
            return self.snapshot()

    def drain ( self ) -> list:
        """ 把佇列全部取出 ( 會清空佇列 ) """
        items = []
        while not self.Q.empty():
            items.append ( self.Q.get())
        return items
    
    def _consume_n ( self, n: int ) -> list:
        """ 取出 n 筆資料 """
        taken = []
        for _ in range (n):
            try:
                taken.append(self.Q.get_nowait())
            except Empty:
                break
        return taken
    
    def save_json ( self, items: list, path: Optional[str] = None, file: Optional[str] = None ) -> None:
        """ 儲存 data 到 json """
        path = path or self.backup_path
        file = file or self.backup_file
        save_data_to_json( items, path, file )
        print(f"[{self.name}] saved {len(items)} items to {file}")

    def backup_snapshot ( self, path: Optional[str] = None, file: Optional[str] = None) -> None:
        self.save_json(self.snapshot(), path, file)
    
    def backup_drain (  self, path: Optional[str] = None, file: Optional[str] = None) -> None:
        self.save_json(self.drain(), path, file)
    
    # ========== 自動備份播走執行緒 ==========
    def start_autobackup (
        self,
        interval_sec: Optional[int] = None,
        progress_every: Optional[int] = None
    ) -> None:
        """ 每 interval_sec 秒 or progress_every 筆資料 自動備份 """
        # _bk_thread: start()啟動->Thread實例; set()請求停止; join最多等幾秒收尾; is_alive()是否仍在執行
        #             執行緒本體
        # _bk_stop  : set()->旗標設為True，告訴背景執行緒「該停了」; clear()->旗標設為False
        #             跨執行緒同步的布林旗標

        if interval_sec is None:
            interval_sec = self.interval_sec
        if progress_every is None:
            progress_every = self.progress_every

        if self._bk_thread and self._bk_thread.is_alive():      # 避免重複啟動多個備份執行緒
            return
        
        # 復原停止旗標，讓 _worker 迴圈可以運作
        self._bk_stop.clear()

        def _worker():
            last_backup = time.time()
            while not self._bk_stop.is_set():
                now = time.time()
                queue_len = self.Q.qsize()
                time_elapsed = now - last_backup

                # 判斷是否要觸發
                trigger = False
                if progress_every is not None and queue_len >= progress_every:
                    trigger = True
                elif time_elapsed >= interval_sec:
                    trigger = True

                if trigger:
                    # 檢查是否有備份正在進行
                    if not self._is_backup_in_progress.is_set():
                        # 設置正在備份
                        self._is_backup_in_progress.set()

                        data = self._safe_snapshot()
                        if data:
                            try:
                                with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
                                    # executor 提交任務
                                    future = executor.submit (
                                        call_news_api if self.kind=="news" else call_channel_api,
                                        data 
                                    )
                                    # 等待超過 30s
                                    success = future.result(timeout=30)
                                    
                                if success:
                                    self._consume_n(len(data))
                                else:
                                    self.save_json(data)

                            except concurrent.futures.TimeoutError:
                                print(f"[{self.name}] API call time out after 30s")
                                self.save_json(data)
                            
                            except Exception as e:
                                print(f"[{self.name}] API call exception: {e}")
                                self.save_json(data)

                        # 清除備份旗標
                        self._is_backup_in_progress.clear()

                    last_backup = time.time()
                else:
                    time.sleep(10)
        
        self._bk_thread = threading.Thread(target=_worker, daemon=True)
        self._bk_thread.start()
        print(f"[{self.name}] autobackup started ( every {interval_sec}s or {progress_every} items )")
    
    def stop_autobackup( self )-> None:
        if self._bk_thread and self._bk_thread.is_alive():
            self._bk_stop.set()             # 設定停止旗標，讓 _worker while 迴圈跳出
            self._bk_thread.join(timeout=5) # 等待執行緒結束，最多等 5 秒
            print(f"[{self.name}] autobackup stopped")
    
    # ========== 信號與退出處理 ==========
    def _graceful_backup ( self ):
        try:
            # 檢查是否有備份正在進行
            if not self._is_backup_in_progress.is_set():
                # 設置正在備份
                self._is_backup_in_progress.set()

                snap = self.snapshot()
                if snap:
                    self.save_json(snap)
                # 停掉自動備份執行緒
                self.stop_autobackup()

                # 清除備份旗標
                self._is_backup_in_progress.clear()
        except Exception as e:
            print(f"[{self.name}] graceful backup error: {e}")
    
    def _signal_handler ( self, signum, frame ):
        print(f"[{self.name}] received signal {signum}, doing graceful backup...")
        self._graceful_backup()
        sys.exit()


"""
# ErrorLog 封裝
class ErrorLog:
    def __init__(
        self,
        name: str,
        path: str,
        fn_map: List[Callable[..., Any]],
        file: str = "__errorlog__.json",
        init_data: Optional[List] = [],
        entry = None
    ):
        self.name = name
        self.path = path
        self.file = file
        self.full_path = Path(path) / file
        self.fn_map: Dict[str, Callable[..., Any]] = {}
        self.fn: List[Dict[str, Any]] = []
        self.data: Dict[str, Any] = {}
        self.data_ignore: List[str] = []

        # 建立 fn_map
        self.create_fn_map(fn_map)

        # 建立 初始資料
        print(f"==== init_data: {init_data} ====")
        if not len(init_data) == 0:
            self.set_many_data(init_data)

        print(f"==== data: {self.data} ====")
        read_success = self.read_json()
        if read_success:
            self.run_fn()
        else:
            self.clean_json()
            entry()

    
    # ========== Fn 操作 ( Stack ) ==========
    def push_fn ( self, fn: Callable[..., Any], params: Optional[Dict[str, Any]] = None ):
        self.fn.append({"fn_name":fn.__name__, "params": list(params.keys()) if params else []})
        print(f"push {self.fn[-1]["fn_name"]}")
        if params:
            for key, value in params.items():
                #print(f"*****{key}: {value}({type(value)})*****")
                self.set_data(key, value, False)

        self.save_json()
        return
    
    def pop_fn( self ):
        self.fn.pop()
        self.save_json()
        return
    
    def create_fn_map ( self, fn_list: List ):
        self.fn_map = {}
        for fn in fn_list:
            self.fn_map[fn.__name__] = fn
        return
    
    # ========== data 操作 ( Queue ) ==========
    def set_data ( self, data_name: str, new_data: Any, ignore: bool=False, save_json: bool=True ):

        print(f"=========\n{data_name}: {new_data}({type(new_data)})")
        self.data[data_name] = deque(new_data) if isinstance (new_data, list) else new_data
        print(f"\n{data_name}: {self.data[data_name]}({type(self.data[data_name])})\n=========")
        if ignore and data_name not in self.data_ignore:
            self.data_ignore.append(data_name)

        if save_json:
            self.save_json()
        return
    
    def set_many_data ( self, set_data_list ):
        for item in set_data_list:
            self.set_data(item[0], item[1], None or item[2], None or item[3])
        return
    
    def pop_data ( self, data_name: str ):
        print(f"=========\npop_data [{data_name}]: {self.data[data_name]}({type(self.data[data_name])})")
        self.data[data_name].popleft()
        print(f"\npop_data [{data_name}]: {self.data[data_name]}({type(self.data[data_name])})\n=========")
        self.save_json()
        return
    
    # ========== 儲存 / 讀取 json ==========
    def save_json ( self ):
        err_log = {}
        err_log["fn"] = self.fn
        err_log["data"] = json.dumps(self.data, default=self.json_dumps_default, ensure_ascii=False, indent=2)
        save_data_to_json( err_log, self.path, self.file, overwrite=True)
        return

    def read_json ( self ) -> bool:
        # 讀取 __errorlog__
        try:
            with self.full_path.open("r", encoding="utf-8") as f:
                err_log = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            self.save_json()
            return False
        except Exception as e:
            print(f"read_json error: {e}")
            self.save_json()
            return False
        
        # fn, data 如果不存在或型態錯誤，就重建 err_log
        fn = err_log.get("fn")
        data = err_log.get("data")
        data = json.loads(data)
        if not isinstance ( fn, list ):
            self.save_json()
            return False
        if not isinstance ( data, dict ):
            self.save_json()
            return False

        # data 轉換資料型態
        for key, value in data.items():
            if key not in self.data_ignore:
                data[key] = self.json_loads_default_hook(value, errLog=self)
            else:
                data[key] = self.data[key]

        self.fn = fn
        self.data = data
        return False if len(self.fn)==0 else True
    
    def clean_json( self ):
        save_data_to_json( {}, self.path, self.file, overwrite=True)


    # ========== json 序列 & 反序列轉換 ==========
    def json_dumps_default(self, obj, **kwargs):
        # deque, CrawlerData, CrawlerQueue
        if isinstance(obj, deque):
            return {
                "__type__": "deque",
                "items": list(obj)
            }
        elif isinstance(obj, ErrorLog):
            return {
                "__type__": "ErrorLog"
            }
        elif isinstance(obj, dict):
            return {
                "__type__": "dict",
                "items": str(obj)
            }
        return None
    
    def json_loads_default_hook(self, dct, errLog):

        if dct is None:
            return None
        
        try:
            obj_type = dct.get("__type__")

            if obj_type == "deque":
                return deque(dct["items"])
            elif obj_type == "ErrorLog":
                return errLog
            elif obj_type == "dict":
                return json.loads(dct["items"])
            return

        except Exception as e:
            return self
        

    # 呼叫所有函式
    def run_fn ( self ):

        print("----------------------------------------------------")

        for item in reversed ( self.fn ):
            print(f"item: {item}\n")
            print("----------------------------------------------------")
            try:
                print("========== 1 ==========")
                fn_name = item["fn_name"]
                if fn_name not in self.fn_map:
                    print(f"[ErrorLog] fn_map 不包含此 fn_name: {fn_name}")
                    continue
                print("========== 2 ==========")
                fn = self.fn_map[fn_name]
                kwargs = { name: self.data[name] for name in item["params"] if name in self.data }
                print("========== 3 ==========")
            except Exception as e:
                print("+++++++++++++ 1 +++++++++++++")
                print(f"[ErrorLog] 函式 {fn.__name__} 執行失敗: {e}")

            try:
                print("========== 4 ==========")
                self.pop_fn()
                print("========== 5 ==========")
                fn(**kwargs)
                print("========== 6 ==========")
            except Exception as e:
                print("+++++++++++++ 2 +++++++++++++")
                print(f"[ErrorLog] 函式 {fn.__name__} 執行失敗: {e}")

        return
"""

# ErrorLog 封裝
class ErrorLog:
    def __init__(
        self,
        name: str,
        path: str,
        file: str = "__errorlog__.json",
        fn_map: List[Tuple[Callable[..., Any], List[str]]] = [],
        init_data: List = [],
        entry = None
    ):
        self.name = name
        self.path = path
        self.file = file
        self.full_path = Path(path) / file
        self.fn_map: Dict[Dict] = []        # Dict { fn, params }
        self.fn: List[str] = []      # fn_name
        self.data: Dict = {}

        # 建立 fn_map
        self.create_fn_map(fn_map)

        # 建立 初始資料
        self.set_many_data(init_data)

        read_success = self.read_json()
        if read_success:
            self.run_fn()
        else:
            self.clean_json()
            entry()

    
    # ========== Fn 操作 ( Stack ) ==========
    def push_fn ( self, fn: Callable[..., Any] ):
        self.fn.append(fn.__name__)
        return
    
    def pop_fn( self ):
        self.fn.pop()
        return
    
    def create_fn_map ( self, fn_map: List ):
        """
            "fn_name": {
                "fn": function,
                "params": List[str]
            }, ...
        """
        if fn_map is None or len(fn_map) == 0:
            self.fn_map = []
            return

        fn_map_data = {}
        
        for item in fn_map:
            item_data = {}
            item_data["fn"] = item[0]
            item_data["param"] = item[1] # list
            fn_map_data[item[0].__name__] = item_data

        self.fn_map = fn_map_data
        return
    
    # ========== data 操作 ( Queue ) ==========
    def set_data ( self, data_name: str, new_data: Any, save_json: bool=True ):
        self.data[data_name] = new_data
        if save_json:
            self.save_json()
        return
    
    def set_many_data ( self, set_data_list ):
        if isinstance(set_data_list, list) or not len(set_data_list)==0:
            for item in set_data_list:
                self.set_data(item[0], item[1], None or item[2])
        return

    # ========== 儲存 / 讀取 json ==========
    def save_json ( self ):
        err_log = {}
        err_log["fn"] = self.fn
        err_log["data"] = json.dumps(self.data, default=self.json_dumps_default, ensure_ascii=False, indent=2)
        save_data_to_json( err_log, self.path, self.file, overwrite=True)
        return

    def read_json ( self ) -> bool:
        # 讀取 __errorlog__.json
        try:
            with self.full_path.open("r", encoding="utf-8") as f:
                err_log = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            # 重建
            self.save_json()
            return False
        except Exception as e:
            # 重建
            print(f"read_json error: {e}")
            self.save_json()
            return False
        
        # fn, data 如果不存在或型態錯誤，就重建 err_log
        fn = err_log.get("fn")
        data = err_log.get("data")
        data = json.loads(data)
        if not isinstance ( fn, list ):
            self.save_json()
            return False
        if not isinstance ( data, dict ):
            self.save_json()
            return False

        """
        # data 轉換資料型態
        for key, value in data.items():
            if key not in self.data_ignore:
                data[key] = self.json_loads_default_hook(value)
            else:
                data[key] = self.data[key]"""

        self.fn = fn
        self.data = data
        return False if len(self.fn)==0 else True
    
    def clean_json( self ):
        save_data_to_json( {}, self.path, self.file, overwrite=True)


    # ========== json 序列 & 反序列轉換 ==========
    def json_dumps_default(self, obj, **kwargs):
        # deque, CrawlerData, CrawlerQueue
        
        """if isinstance(obj, dict):
            return {
                "__type__": "dict",
                "items": str(obj)
            }"""
        return None
    
    def json_loads_default_hook(self, dct):

        if dct is None:
            return None
        
        """try:
            obj_type = dct.get("__type__")
            if obj_type == "dict":
                return json.loads(dct["items"])
            return

        except Exception as e:
            return self"""
        return None
        

    # 呼叫所有函式
    def run_fn ( self ):
        
        # 1) 空檢查
        if not isinstance(self.fn, list) or len(self.fn) == 0:
            return 

         # 2) 逐一從尾端處理，直到無可執行項
        while self.fn:
            fn_name = self.fn[-1]  # 取最後一項
            if not isinstance(fn_name, str):
                print(f"[ErrorLog] 非法的 fn 名稱型別：{type(fn_name)}, 內容={fn_name}，將略過並移除。")
                self.fn.pop()
                continue

            # 3) 由 fn_map 取出對應定義
            entry = self.fn_map.get(fn_name)
            if not entry or not isinstance(entry, dict) or "fn" not in entry:
                print(f"[ErrorLog] fn_map 不包含此 fn_name：{fn_name}，將略過並移除。")
                self.fn.pop()
                continue

            func = entry.get("fn")
            params = entry.get("params", [])
            if not callable(func):
                print(f"[ErrorLog] fn_map['{fn_name}']['fn'] 不是可呼叫物件，將略過並移除。")
                self.fn.pop()
                continue
            if not isinstance(params, list):
                print(f"[ErrorLog] fn_map['{fn_name}']['params'] 應為 List[str]，實際為 {type(params)}，將略過並移除。")
                self.fn.pop()
                continue

            # 4) 從 self.data 收集參數
            missing = [p for p in params if p not in self.data]
            if missing:
                print(f"[ErrorLog] 函式 {fn_name} 缺少參數：{missing}。此次不執行，保留以待資料齊全。")
                # 不 pop，直接結束這次 run，等待之後資料補齊再跑
                return

            kwargs = {p: self.data[p] for p in params}

            # 5) 呼叫函式
            try:
                func(**kwargs)
            except Exception as e:
                print(f"[ErrorLog] 函式 {fn_name} 執行失敗：{e}。")
                self.fn.pop()   # pop 掉錯誤執行
                return

            # 6) 成功後移除堆疊最後一項，繼續處理前一項
            #self.fn.pop()

        print("[ErrorLog] 所有排程函式皆已成功執行。")

        """for item in reversed ( self.fn ):
            print(f"item: {item}\n")
            try:
                
                fn_name = item["fn_name"]
                if fn_name not in self.fn_map:
                    print(f"[ErrorLog] fn_map 不包含此 fn_name: {fn_name}")
                    continue
                fn = self.fn_map[fn_name]
                kwargs = { name: self.data[name] for name in item["params"] if name in self.data }
            except Exception as e:
                print(f"[ErrorLog] 函式 {fn.__name__} 執行失敗: {e}")

            try:
                self.pop_fn()
                fn(**kwargs)
            except Exception as e:
                print(f"[ErrorLog] 函式 {fn.__name__} 執行失敗: {e}")

        return"""