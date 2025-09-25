-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- 主機： 127.0.0.1
-- 產生時間： 2025-09-21 22:01:36
-- 伺服器版本： 10.4.32-MariaDB
-- PHP 版本： 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- 資料庫： `news`
--

-- --------------------------------------------------------

--
-- 資料表結構 `anonymous_data`
--

CREATE TABLE `anonymous_data` (
  `anonymous_id` int(10) UNSIGNED NOT NULL,
  `anonymous_name` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `channel_data`
--

CREATE TABLE `channel_data` (
  `channel_id` bigint(20) UNSIGNED NOT NULL,
  `origin_url` varchar(100) DEFAULT NULL,
  `image_id` bigint(20) UNSIGNED DEFAULT NULL,
  `channel_name` varchar(50) NOT NULL,
  `channel_type` varchar(20) DEFAULT NULL,
  `channel_introduction` text DEFAULT NULL,
  `channel_url` varchar(300) DEFAULT NULL,
  `total_view` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_recent_view` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_share` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_recent_share` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_bookmark` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_recent_bookmark` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_comment` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_recent_comment` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_score` float NOT NULL DEFAULT 0,
  `total_rater` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_recent_score` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_heat` float NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 觸發器 `channel_data`
--
DELIMITER $$
CREATE TRIGGER `caculate_heat (bi_channel_data)` BEFORE INSERT ON `channel_data` FOR EACH ROW BEGIN
    -- 定義參數
    DECLARE v_view, v_comment, v_bookmark, v_share, v_score FLOAT DEFAULT 1.0;
    DECLARE v_recent_view, v_recent_comment, v_recent_bookmark, v_recent_share FLOAT DEFAULT 1.0;
    
    -- 獲取參數係數
    SELECT adjust_value INTO v_view 			FROM value_adjust WHERE adjust_type = 'view' 	 			LIMIT 1;
    SELECT adjust_value INTO v_comment 			FROM value_adjust WHERE adjust_type = 'comment'  			LIMIT 1;
    SELECT adjust_value INTO v_bookmark 		FROM value_adjust WHERE adjust_type = 'bookmark' 			LIMIT 1;
    SELECT adjust_value INTO v_share 			FROM value_adjust WHERE adjust_type = 'share' 	 			LIMIT 1;
    SELECT adjust_value INTO v_recent_view		FROM value_adjust WHERE adjust_type = 'recent_view'			LIMIT 1;
    SELECT adjust_value INTO v_recent_comment	FROM value_adjust WHERE adjust_type = 'recent_comment'		LIMIT 1;
    SELECT adjust_value INTO v_recent_bookmark	FROM value_adjust WHERE adjust_type = 'recent_bookmark'		LIMIT 1;
    SELECT adjust_value INTO v_recent_share		FROM value_adjust WHERE adjust_type = 'recent_share'		LIMIT 1;
    SELECT adjust_value INTO v_score 			FROM value_adjust WHERE adjust_type = 'score' 	 			LIMIT 1;
    
    -- 計算 favorite
    SET NEW.total_heat = 
    COALESCE(NEW.total_view, 0) * v_view + 
    COALESCE(NEW.total_comment, 0) * v_comment + 
    COALESCE(NEW.total_bookmark, 0) * v_bookmark + 
    COALESCE(NEW.total_share, 0) * v_share + 
    COALESCE(NEW.total_recent_view, 0) * v_recent_view + 
    COALESCE(NEW.total_recent_comment, 0) * v_recent_comment + 
    COALESCE(NEW.total_recent_bookmark, 0) * v_recent_bookmark + 
    COALESCE(NEW.total_recent_share, 0) * v_recent_share + 
    COALESCE(NEW.total_score, 0) * COALESCE (NEW.total_rater, 0) * v_score;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `caculate_heat (bu_channel_data)` BEFORE UPDATE ON `channel_data` FOR EACH ROW BEGIN
	-- 定義參數
    DECLARE v_view, v_comment, v_bookmark, v_share, v_score FLOAT DEFAULT 1.0;
    DECLARE v_recent_view, v_recent_comment, v_recent_bookmark, v_recent_share FLOAT DEFAULT 1.0;
    
    IF NOT (
        (NEW.total_view <=> OLD.total_view) AND 
        (NEW.total_comment <=> OLD.total_comment) AND
        (NEW.total_bookmark <=> OLD.total_bookmark) AND
        (NEW.total_share <=> OLD.total_share) AND
        (NEW.total_score <=> OLD.total_score) AND
        (NEW.total_recent_view <=> OLD.total_recent_view) AND
        (NEW.total_recent_comment <=> OLD.total_recent_comment) AND
        (NEW.total_recent_bookmark <=> OLD.total_recent_bookmark) AND
        (NEW.total_recent_share <=> OLD.total_recent_share) AND
        (NEW.total_heat <=> OLD.total_heat)
    )
    THEN
        -- 獲取參數係數
        SELECT adjust_value INTO v_view 			FROM value_adjust WHERE adjust_type = 'view' 	 			LIMIT 1;
        SELECT adjust_value INTO v_comment 			FROM value_adjust WHERE adjust_type = 'comment'  			LIMIT 1;
        SELECT adjust_value INTO v_bookmark 		FROM value_adjust WHERE adjust_type = 'bookmark' 			LIMIT 1;
        SELECT adjust_value INTO v_share 			FROM value_adjust WHERE adjust_type = 'share' 	 			LIMIT 1;
        SELECT adjust_value INTO v_recent_view		FROM value_adjust WHERE adjust_type = 'recent_view'			LIMIT 1;
        SELECT adjust_value INTO v_recent_comment	FROM value_adjust WHERE adjust_type = 'recent_comment'		LIMIT 1;
        SELECT adjust_value INTO v_recent_bookmark	FROM value_adjust WHERE adjust_type = 'recent_bookmark'		LIMIT 1;
        SELECT adjust_value INTO v_recent_share		FROM value_adjust WHERE adjust_type = 'recent_share'		LIMIT 1;
        SELECT adjust_value INTO v_score 			FROM value_adjust WHERE adjust_type = 'score' 	 			LIMIT 1;

        -- 計算 favorite
        SET NEW.total_heat = 
        COALESCE(NEW.total_view, 0) * v_view + 
        COALESCE(NEW.total_comment, 0) * v_comment + 
        COALESCE(NEW.total_bookmark, 0) * v_bookmark + 
        COALESCE(NEW.total_share, 0) * v_share + 
        COALESCE(NEW.total_recent_view, 0) * v_recent_view + 
        COALESCE(NEW.total_recent_comment, 0) * v_recent_comment + 
        COALESCE(NEW.total_recent_bookmark, 0) * v_recent_bookmark + 
        COALESCE(NEW.total_recent_share, 0) * v_recent_share + 
        COALESCE(NEW.total_score, 0) * COALESCE (NEW.total_rater, 0) * v_score;
	END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `reset_timestamp (bu_channel_data)` BEFORE UPDATE ON `channel_data` FOR EACH ROW IF NOT (
	NEW.image_id <=> OLD.image_id AND
	NEW.channel_name <=> OLD.channel_name AND
	NEW.channel_type <=> OLD.channel_type AND
	NEW.channel_introduction <=> OLD.channel_introduction
)
THEN
	SET NEW.updated_at = NOW();
END IF
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- 資料表結構 `error_logs`
--

CREATE TABLE `error_logs` (
  `error_id` int(11) NOT NULL,
  `error_message` varchar(255) NOT NULL,
  `error_description` varchar(50) DEFAULT NULL,
  `error_stack` text DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `eventsorting_data`
--

CREATE TABLE `eventsorting_data` (
  `eventsorting_id` bigint(20) UNSIGNED NOT NULL,
  `eventsorting_image` bigint(20) UNSIGNED DEFAULT NULL,
  `eventsorting_title` varchar(50) DEFAULT NULL,
  `eventsorting_summary` longtext DEFAULT NULL,
  `eventsorting_url` varchar(100) DEFAULT NULL,
  `total_view` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_recent_view` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_share` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_recent_share` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_bookmark` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_recent_bookmark` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_comment` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_recent_comment` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_score` float NOT NULL DEFAULT 0,
  `total_rater` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_recent_score` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_heat` float NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 觸發器 `eventsorting_data`
--
DELIMITER $$
CREATE TRIGGER `caculate_heat (bi_eventsorting_data)` BEFORE INSERT ON `eventsorting_data` FOR EACH ROW BEGIN
    -- 定義參數
    DECLARE v_view, v_comment, v_bookmark, v_share, v_score FLOAT DEFAULT 1.0;
    DECLARE v_recent_view, v_recent_comment, v_recent_bookmark, v_recent_share FLOAT DEFAULT 1.0;
    
    -- 獲取參數係數
    SELECT adjust_value INTO v_view 			FROM value_adjust WHERE adjust_type = 'view' 	 			LIMIT 1;
    SELECT adjust_value INTO v_comment 			FROM value_adjust WHERE adjust_type = 'comment'  			LIMIT 1;
    SELECT adjust_value INTO v_bookmark 		FROM value_adjust WHERE adjust_type = 'bookmark' 			LIMIT 1;
    SELECT adjust_value INTO v_share 			FROM value_adjust WHERE adjust_type = 'share' 	 			LIMIT 1;
    SELECT adjust_value INTO v_recent_view		FROM value_adjust WHERE adjust_type = 'recent_view'			LIMIT 1;
    SELECT adjust_value INTO v_recent_comment	FROM value_adjust WHERE adjust_type = 'recent_comment'		LIMIT 1;
    SELECT adjust_value INTO v_recent_bookmark	FROM value_adjust WHERE adjust_type = 'recent_bookmark'		LIMIT 1;
    SELECT adjust_value INTO v_recent_share		FROM value_adjust WHERE adjust_type = 'recent_share'		LIMIT 1;
    SELECT adjust_value INTO v_score 			FROM value_adjust WHERE adjust_type = 'score' 	 			LIMIT 1;
    
    -- 計算 favorite
    SET NEW.total_heat = 
    COALESCE(NEW.total_view, 0) * v_view + 
    COALESCE(NEW.total_comment, 0) * v_comment + 
    COALESCE(NEW.total_bookmark, 0) * v_bookmark + 
    COALESCE(NEW.total_share, 0) * v_share + 
    COALESCE(NEW.total_recent_view, 0) * v_recent_view + 
    COALESCE(NEW.total_recent_comment, 0) * v_recent_comment + 
    COALESCE(NEW.total_recent_bookmark, 0) * v_recent_bookmark + 
    COALESCE(NEW.total_recent_share, 0) * v_recent_share + 
    COALESCE(NEW.total_score, 0) * COALESCE (NEW.total_rater, 0) * v_score;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `caculate_heat (bu_eventsorting_data)` BEFORE UPDATE ON `eventsorting_data` FOR EACH ROW BEGIN
	-- 定義參數
    DECLARE v_view, v_comment, v_bookmark, v_share, v_score FLOAT DEFAULT 1.0;
    DECLARE v_recent_view, v_recent_comment, v_recent_bookmark, v_recent_share FLOAT DEFAULT 1.0;
    
    IF NOT (
        (NEW.total_view <=> OLD.total_view) AND 
        (NEW.total_comment <=> OLD.total_comment) AND
        (NEW.total_bookmark <=> OLD.total_bookmark) AND
        (NEW.total_share <=> OLD.total_share) AND
        (NEW.total_score <=> OLD.total_score) AND
        (NEW.total_recent_view <=> OLD.total_recent_view) AND
        (NEW.total_recent_comment <=> OLD.total_recent_comment) AND
        (NEW.total_recent_bookmark <=> OLD.total_recent_bookmark) AND
        (NEW.total_recent_share <=> OLD.total_recent_share) AND
        (NEW.total_heat <=> OLD.total_heat)
    )
    THEN
        -- 獲取參數係數
        SELECT adjust_value INTO v_view 			FROM value_adjust WHERE adjust_type = 'view' 	 			LIMIT 1;
        SELECT adjust_value INTO v_comment 			FROM value_adjust WHERE adjust_type = 'comment'  			LIMIT 1;
        SELECT adjust_value INTO v_bookmark 		FROM value_adjust WHERE adjust_type = 'bookmark' 			LIMIT 1;
        SELECT adjust_value INTO v_share 			FROM value_adjust WHERE adjust_type = 'share' 	 			LIMIT 1;
        SELECT adjust_value INTO v_recent_view		FROM value_adjust WHERE adjust_type = 'recent_view'			LIMIT 1;
        SELECT adjust_value INTO v_recent_comment	FROM value_adjust WHERE adjust_type = 'recent_comment'		LIMIT 1;
        SELECT adjust_value INTO v_recent_bookmark	FROM value_adjust WHERE adjust_type = 'recent_bookmark'		LIMIT 1;
        SELECT adjust_value INTO v_recent_share		FROM value_adjust WHERE adjust_type = 'recent_share'		LIMIT 1;
        SELECT adjust_value INTO v_score 			FROM value_adjust WHERE adjust_type = 'score' 	 			LIMIT 1;

        -- 計算 favorite
        SET NEW.total_heat = 
        COALESCE(NEW.total_view, 0) * v_view + 
        COALESCE(NEW.total_comment, 0) * v_comment + 
        COALESCE(NEW.total_bookmark, 0) * v_bookmark + 
        COALESCE(NEW.total_share, 0) * v_share + 
        COALESCE(NEW.total_recent_view, 0) * v_recent_view + 
        COALESCE(NEW.total_recent_comment, 0) * v_recent_comment + 
        COALESCE(NEW.total_recent_bookmark, 0) * v_recent_bookmark + 
        COALESCE(NEW.total_recent_share, 0) * v_recent_share + 
        COALESCE(NEW.total_score, 0) * COALESCE (NEW.total_rater, 0) * v_score;
	END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `reset_timestamp (bu_eventsorting_data)` BEFORE UPDATE ON `eventsorting_data` FOR EACH ROW IF NOT(
	NEW.eventsorting_image <=> OLD.eventsorting_image AND
	NEW.eventsorting_title <=> OLD.eventsorting_title AND
	NEW.eventsorting_summary <=> OLD.eventsorting_summary
)
THEN
	SET NEW.updated_at = NOW();
END IF
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `update_relation_heat (ai_eventsorting_data)` AFTER INSERT ON `eventsorting_data` FOR EACH ROW IF NOT (
    NEW.total_heat <=> 0
)
THEN
	UPDATE relation_data
    SET total_eventsorting_heat = NEW.total_heat
    WHERE relation_id = NEW.eventsorting_id;
END IF
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `update_relation_heat (au_eventsorting_data)` AFTER UPDATE ON `eventsorting_data` FOR EACH ROW IF NOT (
    NEW.total_heat <=> OLD.total_heat
)
THEN
	UPDATE relation_data
    SET total_eventsorting_heat = NEW.total_heat
    WHERE relation_id = NEW.eventsorting_id;
END IF
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- 資料表結構 `eventsorting_horizontal`
--

CREATE TABLE `eventsorting_horizontal` (
  `eventsorting_id` bigint(20) UNSIGNED NOT NULL,
  `horizontal_id` bigint(20) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 觸發器 `eventsorting_horizontal`
--
DELIMITER $$
CREATE TRIGGER `reset_timestamp (ai_eventsorting_horizontal)` AFTER INSERT ON `eventsorting_horizontal` FOR EACH ROW UPDATE eventsorting_data
SET updated_at = CURRENT_TIMESTAMP
WHERE eventsorting_id = NEW.eventsorting_id
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `reset_timestamp (au_eventsorting_horizontal)` AFTER UPDATE ON `eventsorting_horizontal` FOR EACH ROW UPDATE eventsorting_data
SET updated_at = CURRENT_TIMESTAMP
WHERE eventsorting_id = NEW.eventsorting_id
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- 資料表結構 `eventsorting_vertical`
--

CREATE TABLE `eventsorting_vertical` (
  `eventsorting_id` bigint(20) UNSIGNED NOT NULL,
  `news_id` bigint(20) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 觸發器 `eventsorting_vertical`
--
DELIMITER $$
CREATE TRIGGER `reset_timestamp (ai_eventsorting_vertical)` AFTER INSERT ON `eventsorting_vertical` FOR EACH ROW UPDATE eventsorting_data
SET updated_at = CURRENT_TIMESTAMP
WHERE eventsorting_id = NEW.eventsorting_id
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `reset_timestamp (au_eventsorting_vertical)` AFTER UPDATE ON `eventsorting_vertical` FOR EACH ROW UPDATE eventsorting_data
SET updated_at = CURRENT_TIMESTAMP
WHERE eventsorting_id = NEW.eventsorting_id
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- 資料表結構 `groupcustomize_bookmark`
--

CREATE TABLE `groupcustomize_bookmark` (
  `groupcustomize_id` bigint(20) UNSIGNED NOT NULL,
  `user_id` int(10) UNSIGNED NOT NULL,
  `groupcustomize_type` enum('news','channel','eventsorting','multipleperspectives') DEFAULT 'news',
  `groupcustomize_name` varchar(10) DEFAULT NULL,
  `groupcustomize_order` bigint(20) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `groupcustomize_general`
--

CREATE TABLE `groupcustomize_general` (
  `user_id` int(10) UNSIGNED NOT NULL,
  `group_id` int(10) UNSIGNED NOT NULL,
  `group_order` int(11) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `group_data`
--

CREATE TABLE `group_data` (
  `group_id` int(10) UNSIGNED NOT NULL,
  `group_name` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 傾印資料表的資料 `group_data`
--

INSERT INTO `group_data` (`group_id`, `group_name`) VALUES
(5, '健康'),
(14, '優惠'),
(15, '其他'),
(2, '國際'),
(12, '天氣'),
(6, '娛樂'),
(11, '房產'),
(1, '政治'),
(13, '數位專題'),
(10, '汽車'),
(8, '生活'),
(9, '社會'),
(4, '科技'),
(3, '財經'),
(7, '運動');

-- --------------------------------------------------------

--
-- 資料表結構 `group_detail`
--

CREATE TABLE `group_detail` (
  `group_detail_id` int(10) UNSIGNED NOT NULL,
  `group_id` int(10) UNSIGNED NOT NULL,
  `group_detail_name` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 傾印資料表的資料 `group_detail`
--

INSERT INTO `group_detail` (`group_detail_id`, `group_id`, `group_detail_name`) VALUES
(1, 1, '政府政策'),
(2, 1, '選舉'),
(3, 1, '國會/立法院'),
(4, 1, '政黨動態'),
(5, 1, '外交/國防'),
(6, 2, '亞洲新聞'),
(7, 2, '歐美新聞'),
(8, 2, '兩岸關係'),
(9, 2, '戰爭/衝突'),
(10, 2, '國際政治/經濟'),
(11, 3, '股市'),
(12, 3, '匯率'),
(13, 3, '金融保險'),
(14, 3, '房地產'),
(15, 3, '就業與勞工'),
(16, 3, '創業與產業趨勢'),
(17, 4, 'AI/人工智慧'),
(18, 4, '手機/電腦'),
(19, 4, '網路科技'),
(20, 4, '半導體/電子'),
(21, 4, '社群平台動態'),
(22, 5, '疾病/疫情'),
(23, 5, '醫療新聞'),
(24, 5, '心理健康'),
(25, 5, '養生保健'),
(26, 5, '醫療政策'),
(27, 6, '影視藝人'),
(28, 6, '綜藝節目'),
(29, 6, '韓流/日系藝人'),
(30, 6, '音樂'),
(31, 6, '八卦/緋聞'),
(32, 7, '棒球'),
(33, 7, '籃球'),
(34, 7, '足球'),
(35, 7, '奧運/國際賽事'),
(36, 7, '電競'),
(37, 8, '旅遊'),
(38, 8, '美食'),
(39, 8, '家居/裝潢'),
(40, 8, '時尚'),
(41, 8, '寵物/動物'),
(42, 8, '育兒'),
(43, 8, '命理/星座'),
(44, 9, '犯罪/法院'),
(45, 9, '意外/災難'),
(46, 9, '募捐/社福'),
(47, 9, '地方新聞'),
(48, 9, '校園事件'),
(49, 10, '新車發表'),
(50, 10, '試駕報導'),
(51, 10, '車展'),
(52, 10, '電動車'),
(53, 10, '汽車政策'),
(54, 11, '房市分析'),
(55, 11, '建案資訊'),
(56, 11, '不動產稅制'),
(57, 11, '區域開發'),
(58, 12, '氣象預報'),
(59, 12, '災害警報'),
(60, 12, '氣候變遷'),
(61, 13, '長篇專題'),
(62, 13, '數據新聞'),
(63, 13, '多媒體互動專題'),
(64, 14, '優惠情報'),
(65, 14, '好好買'),
(66, 14, '年度大促');

-- --------------------------------------------------------

--
-- 資料表結構 `image_data`
--

CREATE TABLE `image_data` (
  `image_id` bigint(20) UNSIGNED NOT NULL,
  `image_secure_url` varchar(500) DEFAULT NULL,
  `image_public_id` varchar(200) DEFAULT NULL,
  `image_text` varchar(500) DEFAULT NULL,
  `image_origin_url` varchar(500) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `keyword_data`
--

CREATE TABLE `keyword_data` (
  `keyword_id` bigint(20) UNSIGNED NOT NULL,
  `keyword_relation_id` bigint(20) UNSIGNED NOT NULL,
  `keyword_text` varchar(100) NOT NULL,
  `total_search` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_recent_search` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_search_heat` int(10) UNSIGNED NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 觸發器 `keyword_data`
--
DELIMITER $$
CREATE TRIGGER `caculate_heat (bi_keyword_data)` BEFORE INSERT ON `keyword_data` FOR EACH ROW BEGIN
    -- 定義參數
    DECLARE v_search, v_recent_search FLOAT DEFAULT 1.0;
    
    -- 獲取參數係數
    SELECT adjust_value INTO v_search 			FROM value_adjust WHERE adjust_type = 'search' 	 		LIMIT 1;
    SELECT adjust_value INTO v_recent_search	FROM value_adjust WHERE adjust_type = 'recent_search'	LIMIT 1;
    
    -- 計算 favorite
    SET NEW.total_search_heat = 
    COALESCE(NEW.total_search, 0) * v_search + 
    COALESCE(NEW.total_recent_search, 0) * v_recent_search;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `caculate_heat (bu_keyword_data)` BEFORE UPDATE ON `keyword_data` FOR EACH ROW BEGIN
    -- 定義參數
    DECLARE v_search, v_recent_search FLOAT DEFAULT 1.0;
    
    IF NOT (
        (NEW.total_search <=> OLD.total_search) AND 
        (NEW.total_recent_search <=> OLD.total_recent_search) AND 
        (NEW.total_search_heat <=> OLD.total_search_heat)
    )
    THEN
        -- 獲取參數係數
        SELECT adjust_value INTO v_search 			FROM value_adjust WHERE adjust_type = 'search' 	 		LIMIT 1;
        SELECT adjust_value INTO v_recent_search	FROM value_adjust WHERE adjust_type = 'recent_search'	LIMIT 1;

        -- 計算 favorite
        SET NEW.total_search_heat = 
        COALESCE(NEW.total_search, 0) * v_search + 
        COALESCE(NEW.total_recent_search, 0) * v_recent_search;
	END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `update_relation_heat (ai_keyword_data)` AFTER INSERT ON `keyword_data` FOR EACH ROW IF NOT (
    NEW.total_search_heat <=> 0
)
THEN
    UPDATE keyword_relation
    SET total_search_heat = total_search_heat + NEW.total_search_heat
    WHERE keyword_relation_id = NEW.keyword_relation_id;
END IF
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `update_relation_heat (au_keyword_data)` AFTER UPDATE ON `keyword_data` FOR EACH ROW IF NOT (
    NEW.total_search_heat <=> OLD.total_search_heat
)
THEN
    UPDATE keyword_relation
    SET total_search_heat = total_search_heat + ( NEW.total_search_heat - OLD.total_search_heat )
    WHERE keyword_relation_id = NEW.keyword_relation_id;
END IF
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- 資料表結構 `keyword_relation`
--

CREATE TABLE `keyword_relation` (
  `keyword_relation_id` bigint(20) UNSIGNED NOT NULL,
  `total_search_heat` int(10) UNSIGNED NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `location_countries`
--

CREATE TABLE `location_countries` (
  `country_id` int(11) NOT NULL,
  `region_id` int(11) NOT NULL,
  `country_numeric_code` char(3) NOT NULL,
  `country_iso2` char(2) NOT NULL,
  `country_iso3` char(3) NOT NULL,
  `country_name_en` varchar(100) NOT NULL,
  `country_name_zh_tw` varchar(100) DEFAULT NULL,
  `country_name_zh_cn` varchar(100) NOT NULL,
  `country_center_latitude` decimal(10,7) NOT NULL,
  `country_center_longitude` decimal(10,7) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 傾印資料表的資料 `location_countries`
--

INSERT INTO `location_countries` (`country_id`, `region_id`, `country_numeric_code`, `country_iso2`, `country_iso3`, `country_name_en`, `country_name_zh_tw`, `country_name_zh_cn`, `country_center_latitude`, `country_center_longitude`) VALUES
(1, 3, '004', 'AF', 'AFG', 'Afghanistan', '阿富汗', '阿富汗', 33.0000000, 65.0000000),
(2, 4, '248', 'AX', 'ALA', 'Aland Islands', '奧蘭群島', '奥兰群岛', 60.1166670, 19.9000000),
(3, 4, '008', 'AL', 'ALB', 'Albania', '阿爾巴尼亞', '阿尔巴尼亚', 41.0000000, 20.0000000),
(4, 1, '012', 'DZ', 'DZA', 'Algeria', '阿爾及利亞', '阿尔及利亚', 28.0000000, 3.0000000),
(5, 5, '016', 'AS', 'ASM', 'American Samoa', '美屬薩摩亞', '美属萨摩亚', -14.3333333, -170.0000000),
(6, 4, '020', 'AD', 'AND', 'Andorra', '安道爾', '安道尔', 42.5000000, 1.5000000),
(7, 1, '024', 'AO', 'AGO', 'Angola', '安哥拉', '安哥拉', -12.5000000, 18.5000000),
(8, 2, '660', 'AI', 'AIA', 'Anguilla', '安圭拉', '安圭拉', 18.2500000, -63.1666667),
(9, 6, '010', 'AQ', 'ATA', 'Antarctica', '南極洲', '南极洲', -74.6500000, 4.4800000),
(10, 2, '028', 'AG', 'ATG', 'Antigua and Barbuda', '安地卡及巴布達', '安提瓜和巴布达', 17.0500000, -61.8000000),
(11, 2, '032', 'AR', 'ARG', 'Argentina', '阿根廷', '阿根廷', -34.0000000, -64.0000000),
(12, 3, '051', 'AM', 'ARM', 'Armenia', '亞美尼亞', '亚美尼亚', 40.0000000, 45.0000000),
(13, 2, '533', 'AW', 'ABW', 'Aruba', '阿魯巴', '阿鲁巴', 12.5000000, -69.9666667),
(14, 5, '036', 'AU', 'AUS', 'Australia', '澳洲', '澳大利亚', -27.0000000, 133.0000000),
(15, 4, '040', 'AT', 'AUT', 'Austria', '奧地利', '奥地利', 47.3333333, 13.3333333),
(16, 3, '031', 'AZ', 'AZE', 'Azerbaijan', '亞塞拜然', '阿塞拜疆', 40.5000000, 47.5000000),
(17, 2, '044', 'BS', 'BHS', 'The Bahamas', '巴哈馬', '巴哈马', 24.2500000, -76.0000000),
(18, 3, '048', 'BH', 'BHR', 'Bahrain', '巴林', '巴林', 26.0000000, 50.5500000),
(19, 3, '050', 'BD', 'BGD', 'Bangladesh', '孟加拉', '孟加拉', 24.0000000, 90.0000000),
(20, 2, '052', 'BB', 'BRB', 'Barbados', '巴貝多', '巴巴多斯', 13.1666667, -59.5333333),
(21, 4, '112', 'BY', 'BLR', 'Belarus', '白俄羅斯', '白俄罗斯', 53.0000000, 28.0000000),
(22, 4, '056', 'BE', 'BEL', 'Belgium', '比利時', '比利时', 50.8333333, 4.0000000),
(23, 2, '084', 'BZ', 'BLZ', 'Belize', '貝里斯', '伯利兹', 17.2500000, -88.7500000),
(24, 1, '204', 'BJ', 'BEN', 'Benin', '貝南', '贝宁', 9.5000000, 2.2500000),
(25, 2, '060', 'BM', 'BMU', 'Bermuda', '百慕達', '百慕大', 32.3333333, -64.7500000),
(26, 3, '064', 'BT', 'BTN', 'Bhutan', '不丹', '不丹', 27.5000000, 90.5000000),
(27, 2, '068', 'BO', 'BOL', 'Bolivia', '玻利維亞', '玻利维亚', -17.0000000, -65.0000000),
(28, 4, '070', 'BA', 'BIH', 'Bosnia and Herzegovina', '波士尼亞與赫塞哥維納', '波斯尼亚和黑塞哥维那', 44.0000000, 18.0000000),
(29, 1, '072', 'BW', 'BWA', 'Botswana', '波札那', '博茨瓦纳', -22.0000000, 24.0000000),
(30, 6, '074', 'BV', 'BVT', 'Bouvet Island', '布維島', '布维岛', -54.4333333, 3.4000000),
(31, 2, '076', 'BR', 'BRA', 'Brazil', '巴西', '巴西', -10.0000000, -55.0000000),
(32, 1, '086', 'IO', 'IOT', 'British Indian Ocean Territory', '英屬印度洋領地', '英属印度洋领地', -6.0000000, 71.5000000),
(33, 3, '096', 'BN', 'BRN', 'Brunei', '汶萊', '文莱', 4.5000000, 114.6666667),
(34, 4, '100', 'BG', 'BGR', 'Bulgaria', '保加利亞', '保加利亚', 43.0000000, 25.0000000),
(35, 1, '854', 'BF', 'BFA', 'Burkina Faso', '布吉納法索', '布基纳法索', 13.0000000, -2.0000000),
(36, 1, '108', 'BI', 'BDI', 'Burundi', '蒲隆地', '布隆迪', -3.5000000, 30.0000000),
(37, 3, '116', 'KH', 'KHM', 'Cambodia', '柬埔寨', '柬埔寨', 13.0000000, 105.0000000),
(38, 1, '120', 'CM', 'CMR', 'Cameroon', '喀麥隆', '喀麦隆', 6.0000000, 12.0000000),
(39, 2, '124', 'CA', 'CAN', 'Canada', '加拿大', '加拿大', 60.0000000, -95.0000000),
(40, 1, '132', 'CV', 'CPV', 'Cape Verde', '維德角', '佛得角', 16.0000000, -24.0000000),
(41, 2, '136', 'KY', 'CYM', 'Cayman Islands', '開曼群島', '开曼群岛', 19.5000000, -80.5000000),
(42, 1, '140', 'CF', 'CAF', 'Central African Republic', '中非', '中非', 7.0000000, 21.0000000),
(43, 1, '148', 'TD', 'TCD', 'Chad', '查德', '乍得', 15.0000000, 19.0000000),
(44, 2, '152', 'CL', 'CHL', 'Chile', '智利', '智利', -30.0000000, -71.0000000),
(45, 3, '156', 'CN', 'CHN', 'China', '中國', '中国', 35.0000000, 105.0000000),
(46, 5, '162', 'CX', 'CXR', 'Christmas Island', '聖誕島', '圣诞岛', -10.5000000, 105.6666667),
(47, 5, '166', 'CC', 'CCK', 'Cocos (Keeling) Islands', '科科斯（基林）群島', '科科斯（基林）群岛', -12.5000000, 96.8333333),
(48, 2, '170', 'CO', 'COL', 'Colombia', '哥倫比亞', '哥伦比亚', 4.0000000, -72.0000000),
(49, 1, '174', 'KM', 'COM', 'Comoros', '葛摩', '科摩罗', -12.1666667, 44.2500000),
(50, 1, '178', 'CG', 'COG', 'Congo', '剛果', '刚果', -1.0000000, 15.0000000),
(51, 1, '180', 'CD', 'COD', 'Democratic Republic of the Congo', '剛果民主共和國', '刚果（金）', 0.0000000, 25.0000000),
(52, 5, '184', 'CK', 'COK', 'Cook Islands', '庫克群島', '库克群岛', -21.2333333, -159.7666667),
(53, 2, '188', 'CR', 'CRI', 'Costa Rica', '哥斯大黎加', '哥斯达黎加', 10.0000000, -84.0000000),
(54, 1, '384', 'CI', 'CIV', 'Cote D\'Ivoire (Ivory Coast)', '科特迪瓦（象牙海岸）', '科特迪瓦', 8.0000000, -5.0000000),
(55, 4, '191', 'HR', 'HRV', 'Croatia', '克羅埃西亞', '克罗地亚', 45.1666667, 15.5000000),
(56, 2, '192', 'CU', 'CUB', 'Cuba', '古巴', '古巴', 21.5000000, -80.0000000),
(57, 4, '196', 'CY', 'CYP', 'Cyprus', '賽普勒斯', '塞浦路斯', 35.0000000, 33.0000000),
(58, 4, '203', 'CZ', 'CZE', 'Czech Republic', '捷克共和國', '捷克', 49.7500000, 15.5000000),
(59, 4, '208', 'DK', 'DNK', 'Denmark', '丹麥', '丹麦', 56.0000000, 10.0000000),
(60, 1, '262', 'DJ', 'DJI', 'Djibouti', '吉布地', '吉布提', 11.5000000, 43.0000000),
(61, 2, '212', 'DM', 'DMA', 'Dominica', '多明尼加', '多米尼加', 15.4166667, -61.3333333),
(62, 2, '214', 'DO', 'DOM', 'Dominican Republic', '多明尼加共和國', '多明尼加共和国', 19.0000000, -70.6666667),
(63, 3, '626', 'TL', 'TLS', 'Timor-Leste', '東帝汶', '东帝汶', -8.8333333, 125.9166667),
(64, 2, '218', 'EC', 'ECU', 'Ecuador', '厄瓜多', '厄瓜多尔', -2.0000000, -77.5000000),
(65, 1, '818', 'EG', 'EGY', 'Egypt', '埃及', '埃及', 27.0000000, 30.0000000),
(66, 2, '222', 'SV', 'SLV', 'El Salvador', '薩爾瓦多', '萨尔瓦多', 13.8333333, -88.9166667),
(67, 1, '226', 'GQ', 'GNQ', 'Equatorial Guinea', '赤道幾內亞', '赤道几内亚', 2.0000000, 10.0000000),
(68, 1, '232', 'ER', 'ERI', 'Eritrea', '厄利垂亞', '厄立特里亚', 15.0000000, 39.0000000),
(69, 4, '233', 'EE', 'EST', 'Estonia', '愛沙尼亞', '爱沙尼亚', 59.0000000, 26.0000000),
(70, 1, '231', 'ET', 'ETH', 'Ethiopia', '衣索比亞', '埃塞俄比亚', 8.0000000, 38.0000000),
(71, 2, '238', 'FK', 'FLK', 'Falkland Islands', '福克蘭群島', '福克兰群岛', -51.7500000, -59.0000000),
(72, 4, '234', 'FO', 'FRO', 'Faroe Islands', '法羅群島', '法罗群岛', 62.0000000, -7.0000000),
(73, 5, '242', 'FJ', 'FJI', 'Fiji Islands', '斐濟群島', '斐济', -18.0000000, 175.0000000),
(74, 4, '246', 'FI', 'FIN', 'Finland', '芬蘭', '芬兰', 64.0000000, 26.0000000),
(75, 4, '250', 'FR', 'FRA', 'France', '法國', '法国', 46.0000000, 2.0000000),
(76, 2, '254', 'GF', 'GUF', 'French Guiana', '法屬圭亞那', '法属圭亚那', 4.0000000, -53.0000000),
(77, 5, '258', 'PF', 'PYF', 'French Polynesia', '法屬玻里尼西亞', '法属波利尼西亚', -15.0000000, -140.0000000),
(78, 1, '260', 'TF', 'ATF', 'French Southern Territories', '法屬南部領土', '法属南部领地', -49.2500000, 69.1670000),
(79, 1, '266', 'GA', 'GAB', 'Gabon', '加彭', '加蓬', -1.0000000, 11.7500000),
(80, 1, '270', 'GM', 'GMB', 'The Gambia ', '甘比亞', '冈比亚', 13.4666667, -16.5666667),
(81, 3, '268', 'GE', 'GEO', 'Georgia', '喬治亞州', '格鲁吉亚', 42.0000000, 43.5000000),
(82, 4, '276', 'DE', 'DEU', 'Germany', '德國', '德国', 51.0000000, 9.0000000),
(83, 1, '288', 'GH', 'GHA', 'Ghana', '迦納', '加纳', 8.0000000, -2.0000000),
(84, 4, '292', 'GI', 'GIB', 'Gibraltar', '直布羅陀', '直布罗陀', 36.1333333, -5.3500000),
(85, 4, '300', 'GR', 'GRC', 'Greece', '希臘', '希腊', 39.0000000, 22.0000000),
(86, 2, '304', 'GL', 'GRL', 'Greenland', '格陵蘭', '格陵兰岛', 72.0000000, -40.0000000),
(87, 2, '308', 'GD', 'GRD', 'Grenada', '格瑞那達', '格林纳达', 12.1166667, -61.6666667),
(88, 2, '312', 'GP', 'GLP', 'Guadeloupe', '瓜德羅普島', '瓜德罗普岛', 16.2500000, -61.5833330),
(89, 5, '316', 'GU', 'GUM', 'Guam', '關島', '关岛', 13.4666667, 144.7833333),
(90, 2, '320', 'GT', 'GTM', 'Guatemala', '瓜地馬拉', '危地马拉', 15.5000000, -90.2500000),
(91, 4, '831', 'GG', 'GGY', 'Guernsey', '根西島', '根西岛', 49.4666667, -2.5833333),
(92, 1, '324', 'GN', 'GIN', 'Guinea', '幾內亞', '几内亚', 11.0000000, -10.0000000),
(93, 1, '624', 'GW', 'GNB', 'Guinea-Bissau', '幾內亞比紹', '几内亚比绍', 12.0000000, -15.0000000),
(94, 2, '328', 'GY', 'GUY', 'Guyana', '蓋亞那', '圭亚那', 5.0000000, -59.0000000),
(95, 2, '332', 'HT', 'HTI', 'Haiti', '海地', '海地', 19.0000000, -72.4166667),
(96, 5, '334', 'HM', 'HMD', 'Heard Island and McDonald Islands', '赫德島和麥克唐納群島', '赫德·唐纳岛及麦唐纳岛', -53.1000000, 72.5166667),
(97, 2, '340', 'HN', 'HND', 'Honduras', '宏都拉斯', '洪都拉斯', 15.0000000, -86.5000000),
(98, 3, '344', 'HK', 'HKG', 'Hong Kong S.A.R.', '香港特別行政區', '中国香港', 22.2500000, 114.1666667),
(99, 4, '348', 'HU', 'HUN', 'Hungary', '匈牙利', '匈牙利', 47.0000000, 20.0000000),
(100, 4, '352', 'IS', 'ISL', 'Iceland', '冰島', '冰岛', 65.0000000, -18.0000000),
(101, 3, '356', 'IN', 'IND', 'India', '印度', '印度', 20.0000000, 77.0000000),
(102, 3, '360', 'ID', 'IDN', 'Indonesia', '印尼', '印度尼西亚', -5.0000000, 120.0000000),
(103, 3, '364', 'IR', 'IRN', 'Iran', '伊朗', '伊朗', 32.0000000, 53.0000000),
(104, 3, '368', 'IQ', 'IRQ', 'Iraq', '伊拉克', '伊拉克', 33.0000000, 44.0000000),
(105, 4, '372', 'IE', 'IRL', 'Ireland', '愛爾蘭', '爱尔兰', 53.0000000, -8.0000000),
(106, 3, '376', 'IL', 'ISR', 'Israel', '以色列', '以色列', 31.5000000, 34.7500000),
(107, 4, '380', 'IT', 'ITA', 'Italy', '義大利', '意大利', 42.8333333, 12.8333333),
(108, 2, '388', 'JM', 'JAM', 'Jamaica', '牙買加', '牙买加', 18.2500000, -77.5000000),
(109, 3, '392', 'JP', 'JPN', 'Japan', '日本', '日本', 36.0000000, 138.0000000),
(110, 4, '832', 'JE', 'JEY', 'Jersey', '澤西島', '泽西岛', 49.2500000, -2.1666667),
(111, 3, '400', 'JO', 'JOR', 'Jordan', '約旦', '约旦', 31.0000000, 36.0000000),
(112, 3, '398', 'KZ', 'KAZ', 'Kazakhstan', '哈薩克', '哈萨克斯坦', 48.0000000, 68.0000000),
(113, 1, '404', 'KE', 'KEN', 'Kenya', '肯亞', '肯尼亚', 1.0000000, 38.0000000),
(114, 5, '296', 'KI', 'KIR', 'Kiribati', '吉里巴斯', '基里巴斯', 1.4166667, 173.0000000),
(115, 3, '408', 'KP', 'PRK', 'North Korea', '北韓', '朝鲜', 40.0000000, 127.0000000),
(116, 3, '410', 'KR', 'KOR', 'South Korea', '韓國', '韩国', 37.0000000, 127.5000000),
(117, 3, '414', 'KW', 'KWT', 'Kuwait', '科威特', '科威特', 29.5000000, 45.7500000),
(118, 3, '417', 'KG', 'KGZ', 'Kyrgyzstan', '吉爾吉斯斯坦', '吉尔吉斯斯坦', 41.0000000, 75.0000000),
(119, 3, '418', 'LA', 'LAO', 'Laos', '寮國', '寮人民民主共和国', 18.0000000, 105.0000000),
(120, 4, '428', 'LV', 'LVA', 'Latvia', '拉脫維亞', '拉脱维亚', 57.0000000, 25.0000000),
(121, 3, '422', 'LB', 'LBN', 'Lebanon', '黎巴嫩', '黎巴嫩', 33.8333333, 35.8333333),
(122, 1, '426', 'LS', 'LSO', 'Lesotho', '賴索托', '莱索托', -29.5000000, 28.5000000),
(123, 1, '430', 'LR', 'LBR', 'Liberia', '賴比瑞亞', '利比里亚', 6.5000000, -9.5000000),
(124, 1, '434', 'LY', 'LBY', 'Libya', '利比亞', '利比亚', 25.0000000, 17.0000000),
(125, 4, '438', 'LI', 'LIE', 'Liechtenstein', '列支敦斯登', '列支敦士登', 47.2666667, 9.5333333),
(126, 4, '440', 'LT', 'LTU', 'Lithuania', '立陶宛', '立陶宛', 56.0000000, 24.0000000),
(127, 4, '442', 'LU', 'LUX', 'Luxembourg', '盧森堡', '卢森堡', 49.7500000, 6.1666667),
(128, 3, '446', 'MO', 'MAC', 'Macau S.A.R.', '澳門特別行政區', '中国澳门', 22.1666667, 113.5500000),
(129, 4, '807', 'MK', 'MKD', 'North Macedonia', '北馬其頓', '北馬其頓', 41.8333333, 22.0000000),
(130, 1, '450', 'MG', 'MDG', 'Madagascar', '馬達加斯加', '马达加斯加', -20.0000000, 47.0000000),
(131, 1, '454', 'MW', 'MWI', 'Malawi', '馬拉威', '马拉维', -13.5000000, 34.0000000),
(132, 3, '458', 'MY', 'MYS', 'Malaysia', '馬來西亞', '马来西亚', 2.5000000, 112.5000000),
(133, 3, '462', 'MV', 'MDV', 'Maldives', '馬爾地夫', '马尔代夫', 3.2500000, 73.0000000),
(134, 1, '466', 'ML', 'MLI', 'Mali', '馬裡', '马里', 17.0000000, -4.0000000),
(135, 4, '470', 'MT', 'MLT', 'Malta', '馬爾他', '马耳他', 35.8333333, 14.5833333),
(136, 4, '833', 'IM', 'IMN', 'Man (Isle of)', '馬恩島', '马恩岛', 54.2500000, -4.5000000),
(137, 5, '584', 'MH', 'MHL', 'Marshall Islands', '馬紹爾群島', '马绍尔群岛', 9.0000000, 168.0000000),
(138, 2, '474', 'MQ', 'MTQ', 'Martinique', '馬提尼克島', '马提尼克岛', 14.6666670, -61.0000000),
(139, 1, '478', 'MR', 'MRT', 'Mauritania', '茅利塔尼亞', '毛里塔尼亚', 20.0000000, -12.0000000),
(140, 1, '480', 'MU', 'MUS', 'Mauritius', '模里西斯', '毛里求斯', -20.2833333, 57.5500000),
(141, 1, '175', 'YT', 'MYT', 'Mayotte', '馬約特島', '马约特', -12.8333333, 45.1666667),
(142, 2, '484', 'MX', 'MEX', 'Mexico', '墨西哥', '墨西哥', 23.0000000, -102.0000000),
(143, 5, '583', 'FM', 'FSM', 'Micronesia', '密克羅尼西亞', '密克罗尼西亚', 6.9166667, 158.2500000),
(144, 4, '498', 'MD', 'MDA', 'Moldova', '摩爾多瓦', '摩尔多瓦', 47.0000000, 29.0000000),
(145, 4, '492', 'MC', 'MCO', 'Monaco', '摩納哥', '摩纳哥', 43.7333333, 7.4000000),
(146, 3, '496', 'MN', 'MNG', 'Mongolia', '蒙古', '蒙古', 46.0000000, 105.0000000),
(147, 4, '499', 'ME', 'MNE', 'Montenegro', '蒙特內哥羅', '黑山', 42.5000000, 19.3000000),
(148, 2, '500', 'MS', 'MSR', 'Montserrat', '蒙特塞拉特', '蒙特塞拉特', 16.7500000, -62.2000000),
(149, 1, '504', 'MA', 'MAR', 'Morocco', '摩洛哥', '摩洛哥', 32.0000000, -5.0000000),
(150, 1, '508', 'MZ', 'MOZ', 'Mozambique', '莫三比克', '莫桑比克', -18.2500000, 35.0000000),
(151, 3, '104', 'MM', 'MMR', 'Myanmar', '緬甸', '缅甸', 22.0000000, 98.0000000),
(152, 1, '516', 'NA', 'NAM', 'Namibia', '納米比亞', '纳米比亚', -22.0000000, 17.0000000),
(153, 5, '520', 'NR', 'NRU', 'Nauru', '諾魯', '瑙鲁', -0.5333333, 166.9166667),
(154, 3, '524', 'NP', 'NPL', 'Nepal', '尼泊爾', '尼泊尔', 28.0000000, 84.0000000),
(155, 2, '535', 'BQ', 'BES', 'Bonaire, Sint Eustatius and Saba', '博內爾島、聖尤斯特歇斯島和薩巴島', '博内尔岛、圣尤斯特歇斯和萨巴岛', 12.1500000, -68.2666670),
(156, 4, '528', 'NL', 'NLD', 'Netherlands', '荷蘭', '荷兰', 52.5000000, 5.7500000),
(157, 5, '540', 'NC', 'NCL', 'New Caledonia', '新喀裡多尼亞', '新喀里多尼亚', -21.5000000, 165.5000000),
(158, 5, '554', 'NZ', 'NZL', 'New Zealand', '紐西蘭', '新西兰', -41.0000000, 174.0000000),
(159, 2, '558', 'NI', 'NIC', 'Nicaragua', '尼加拉瓜', '尼加拉瓜', 13.0000000, -85.0000000),
(160, 1, '562', 'NE', 'NER', 'Niger', '尼日', '尼日尔', 16.0000000, 8.0000000),
(161, 1, '566', 'NG', 'NGA', 'Nigeria', '奈及利亞', '尼日利亚', 10.0000000, 8.0000000),
(162, 5, '570', 'NU', 'NIU', 'Niue', '紐埃', '纽埃', -19.0333333, -169.8666667),
(163, 5, '574', 'NF', 'NFK', 'Norfolk Island', '諾福克島', '诺福克岛', -29.0333333, 167.9500000),
(164, 5, '580', 'MP', 'MNP', 'Northern Mariana Islands', '北馬裡亞納群島', '北马里亚纳群岛', 15.2000000, 145.7500000),
(165, 4, '578', 'NO', 'NOR', 'Norway', '挪威', '挪威', 62.0000000, 10.0000000),
(166, 3, '512', 'OM', 'OMN', 'Oman', '阿曼', '阿曼', 21.0000000, 57.0000000),
(167, 3, '586', 'PK', 'PAK', 'Pakistan', '巴基斯坦', '巴基斯坦', 30.0000000, 70.0000000),
(168, 5, '585', 'PW', 'PLW', 'Palau', '帛琉', '帕劳', 7.5000000, 134.5000000),
(169, 3, '275', 'PS', 'PSE', 'Palestinian Territory Occupied', '巴勒斯坦被佔領土', '巴勒斯坦', 31.9000000, 35.2000000),
(170, 2, '591', 'PA', 'PAN', 'Panama', '巴拿馬', '巴拿马', 9.0000000, -80.0000000),
(171, 5, '598', 'PG', 'PNG', 'Papua New Guinea', '巴布亞紐幾內亞', '巴布亚新几内亚', -6.0000000, 147.0000000),
(172, 2, '600', 'PY', 'PRY', 'Paraguay', '巴拉圭', '巴拉圭', -23.0000000, -58.0000000),
(173, 2, '604', 'PE', 'PER', 'Peru', '秘魯', '秘鲁', -10.0000000, -76.0000000),
(174, 3, '608', 'PH', 'PHL', 'Philippines', '菲律賓', '菲律宾', 13.0000000, 122.0000000),
(175, 5, '612', 'PN', 'PCN', 'Pitcairn Island', '皮特凱恩島', '皮特凯恩群岛', -25.0666667, -130.1000000),
(176, 4, '616', 'PL', 'POL', 'Poland', '波蘭', '波兰', 52.0000000, 20.0000000),
(177, 4, '620', 'PT', 'PRT', 'Portugal', '葡萄牙', '葡萄牙', 39.5000000, -8.0000000),
(178, 2, '630', 'PR', 'PRI', 'Puerto Rico', '波多黎各', '波多黎各', 18.2500000, -66.5000000),
(179, 3, '634', 'QA', 'QAT', 'Qatar', '卡達', '卡塔尔', 25.5000000, 51.2500000),
(180, 1, '638', 'RE', 'REU', 'Reunion', '留尼旺島', '留尼汪岛', -21.1500000, 55.5000000),
(181, 4, '642', 'RO', 'ROU', 'Romania', '羅馬尼亞', '罗马尼亚', 46.0000000, 25.0000000),
(182, 4, '643', 'RU', 'RUS', 'Russia', '俄羅斯', '俄罗斯联邦', 60.0000000, 100.0000000),
(183, 1, '646', 'RW', 'RWA', 'Rwanda', '盧安達', '卢旺达', -2.0000000, 30.0000000),
(184, 1, '654', 'SH', 'SHN', 'Saint Helena', '聖赫勒拿島', '圣赫勒拿', -15.9500000, -5.7000000),
(185, 2, '659', 'KN', 'KNA', 'Saint Kitts and Nevis', '聖克里斯多福及尼維斯', '圣基茨和尼维斯', 17.3333333, -62.7500000),
(186, 2, '662', 'LC', 'LCA', 'Saint Lucia', '聖露西亞', '圣卢西亚', 13.8833333, -60.9666667),
(187, 2, '666', 'PM', 'SPM', 'Saint Pierre and Miquelon', '聖皮埃爾和密克隆群島', '圣皮埃尔和密克隆', 46.8333333, -56.3333333),
(188, 2, '670', 'VC', 'VCT', 'Saint Vincent and the Grenadines', '聖文森及格瑞那丁', '圣文森特和格林纳丁斯', 13.2500000, -61.2000000),
(189, 2, '652', 'BL', 'BLM', 'Saint-Barthelemy', '聖巴泰勒米', '圣巴泰勒米', 18.5000000, -63.4166667),
(190, 2, '663', 'MF', 'MAF', 'Saint-Martin (French part)', '聖馬丁島（法國部分）', '法属圣马丁', 18.0833333, -63.9500000),
(191, 5, '882', 'WS', 'WSM', 'Samoa', '薩摩亞', '萨摩亚', -13.5833333, -172.3333333),
(192, 4, '674', 'SM', 'SMR', 'San Marino', '聖馬利諾', '圣马力诺', 43.7666667, 12.4166667),
(193, 1, '678', 'ST', 'STP', 'Sao Tome and Principe', '聖多美和普林西比', '圣多美和普林西比', 1.0000000, 7.0000000),
(194, 3, '682', 'SA', 'SAU', 'Saudi Arabia', '沙烏地阿拉伯', '沙特阿拉伯', 25.0000000, 45.0000000),
(195, 1, '686', 'SN', 'SEN', 'Senegal', '塞內加爾', '塞内加尔', 14.0000000, -14.0000000),
(196, 4, '688', 'RS', 'SRB', 'Serbia', '塞爾維亞', '塞尔维亚', 44.0000000, 21.0000000),
(197, 1, '690', 'SC', 'SYC', 'Seychelles', '塞席爾', '塞舌尔', -4.5833333, 55.6666667),
(198, 1, '694', 'SL', 'SLE', 'Sierra Leone', '獅子山', '塞拉利昂', 8.5000000, -11.5000000),
(199, 3, '702', 'SG', 'SGP', 'Singapore', '新加坡', '新加坡', 1.3666667, 103.8000000),
(200, 4, '703', 'SK', 'SVK', 'Slovakia', '斯洛伐克', '斯洛伐克', 48.6666667, 19.5000000),
(201, 4, '705', 'SI', 'SVN', 'Slovenia', '斯洛維尼亞', '斯洛文尼亚', 46.1166667, 14.8166667),
(202, 5, '090', 'SB', 'SLB', 'Solomon Islands', '索羅門群島', '所罗门群岛', -8.0000000, 159.0000000),
(203, 1, '706', 'SO', 'SOM', 'Somalia', '索馬利亞', '索马里', 10.0000000, 49.0000000),
(204, 1, '710', 'ZA', 'ZAF', 'South Africa', '南非', '南非', -29.0000000, 24.0000000),
(205, 2, '239', 'GS', 'SGS', 'South Georgia', '南喬治亞島', '南乔治亚', -54.5000000, -37.0000000),
(206, 1, '728', 'SS', 'SSD', 'South Sudan', '南蘇丹', '南苏丹', 7.0000000, 30.0000000),
(207, 4, '724', 'ES', 'ESP', 'Spain', '西班牙', '西班牙', 40.0000000, -4.0000000),
(208, 3, '144', 'LK', 'LKA', 'Sri Lanka', '斯里蘭卡', '斯里兰卡', 7.0000000, 81.0000000),
(209, 1, '729', 'SD', 'SDN', 'Sudan', '蘇丹', '苏丹', 15.0000000, 30.0000000),
(210, 2, '740', 'SR', 'SUR', 'Suriname', '蘇利南', '苏里南', 4.0000000, -56.0000000),
(211, 4, '744', 'SJ', 'SJM', 'Svalbard and Jan Mayen Islands', '斯瓦爾巴群島和揚馬延群島', '斯瓦尔巴和扬马延群岛', 78.0000000, 20.0000000),
(212, 1, '748', 'SZ', 'SWZ', 'Eswatini', '史瓦濟蘭', '斯威士兰', -26.5000000, 31.5000000),
(213, 4, '752', 'SE', 'SWE', 'Sweden', '瑞典', '瑞典', 62.0000000, 15.0000000),
(214, 4, '756', 'CH', 'CHE', 'Switzerland', '瑞士', '瑞士', 47.0000000, 8.0000000),
(215, 3, '760', 'SY', 'SYR', 'Syria', '敘利亞', '叙利亚', 35.0000000, 38.0000000),
(216, 3, '158', 'TW', 'TWN', 'Taiwan', '台灣', '台湾', 23.5000000, 121.0000000),
(217, 3, '762', 'TJ', 'TJK', 'Tajikistan', '塔吉克', '塔吉克斯坦', 39.0000000, 71.0000000),
(218, 1, '834', 'TZ', 'TZA', 'Tanzania', '坦尚尼亞', '坦桑尼亚', -6.0000000, 35.0000000),
(219, 3, '764', 'TH', 'THA', 'Thailand', '泰國', '泰国', 15.0000000, 100.0000000),
(220, 1, '768', 'TG', 'TGO', 'Togo', '多哥', '多哥', 8.0000000, 1.1666667),
(221, 5, '772', 'TK', 'TKL', 'Tokelau', '托克勞', '托克劳', -9.0000000, -172.0000000),
(222, 5, '776', 'TO', 'TON', 'Tonga', '東加', '汤加', -20.0000000, -175.0000000),
(223, 2, '780', 'TT', 'TTO', 'Trinidad and Tobago', '千里達及托巴哥', '特立尼达和多巴哥', 11.0000000, -61.0000000),
(224, 1, '788', 'TN', 'TUN', 'Tunisia', '突尼西亞', '突尼斯', 34.0000000, 9.0000000),
(225, 3, '792', 'TR', 'TUR', 'Turkey', '土耳其', '土耳其', 39.0000000, 35.0000000),
(226, 3, '795', 'TM', 'TKM', 'Turkmenistan', '土庫曼', '土库曼斯坦', 40.0000000, 60.0000000),
(227, 2, '796', 'TC', 'TCA', 'Turks and Caicos Islands', '特克斯和凱科斯群島', '特克斯和凯科斯群岛', 21.7500000, -71.5833333),
(228, 5, '798', 'TV', 'TUV', 'Tuvalu', '吐瓦魯', '图瓦卢', -8.0000000, 178.0000000),
(229, 1, '800', 'UG', 'UGA', 'Uganda', '烏干達', '乌干达', 1.0000000, 32.0000000),
(230, 4, '804', 'UA', 'UKR', 'Ukraine', '烏克蘭', '乌克兰', 49.0000000, 32.0000000),
(231, 3, '784', 'AE', 'ARE', 'United Arab Emirates', '阿拉伯聯合大公國', '阿拉伯联合酋长国', 24.0000000, 54.0000000),
(232, 4, '826', 'GB', 'GBR', 'United Kingdom', '英國', '英国', 54.0000000, -2.0000000),
(233, 2, '840', 'US', 'USA', 'United States', '美國', '美国', 38.0000000, -97.0000000),
(234, 2, '581', 'UM', 'UMI', 'United States Minor Outlying Islands', '美國本土外小島嶼', '美国本土外小岛屿', 0.0000000, 0.0000000),
(235, 2, '858', 'UY', 'URY', 'Uruguay', '烏拉圭', '乌拉圭', -33.0000000, -56.0000000),
(236, 3, '860', 'UZ', 'UZB', 'Uzbekistan', '烏茲別克', '乌兹别克斯坦', 41.0000000, 64.0000000),
(237, 5, '548', 'VU', 'VUT', 'Vanuatu', '萬那杜', '瓦努阿图', -16.0000000, 167.0000000),
(238, 4, '336', 'VA', 'VAT', 'Vatican City State (Holy See)', '梵蒂岡城國（教廷）', '梵蒂冈', 41.9000000, 12.4500000),
(239, 2, '862', 'VE', 'VEN', 'Venezuela', '委內瑞拉', '委内瑞拉', 8.0000000, -66.0000000),
(240, 3, '704', 'VN', 'VNM', 'Vietnam', '越南', '越南', 16.1666667, 107.8333333),
(241, 2, '092', 'VG', 'VGB', 'Virgin Islands (British)', '英屬維京群島', '英属维京群岛', 18.4313830, -64.6230500),
(242, 2, '850', 'VI', 'VIR', 'Virgin Islands (US)', '美屬維京群島', '维尔京群岛（美国）', 18.3400000, -64.9300000),
(243, 5, '876', 'WF', 'WLF', 'Wallis and Futuna Islands', '瓦利斯和富圖納群島', '瓦利斯群岛和富图纳群岛', -13.3000000, -176.2000000),
(244, 1, '732', 'EH', 'ESH', 'Western Sahara', '西撒哈拉', '西撒哈拉', 24.5000000, -13.0000000),
(245, 3, '887', 'YE', 'YEM', 'Yemen', '葉門', '也门', 15.0000000, 48.0000000),
(246, 1, '894', 'ZM', 'ZMB', 'Zambia', '尚比亞', '赞比亚', -15.0000000, 30.0000000),
(247, 1, '716', 'ZW', 'ZWE', 'Zimbabwe', '辛巴威', '津巴布韦', -20.0000000, 30.0000000),
(248, 4, '926', 'XK', 'XKX', 'Kosovo', '科索沃', '科索沃', 42.5612909, 20.3403035),
(249, 2, '531', 'CW', 'CUW', 'Curaçao', '庫拉索島', '库拉索', 12.1166670, -68.9333330),
(250, 2, '534', 'SX', 'SXM', 'Sint Maarten (Dutch part)', '聖馬丁島（荷屬部分）', '圣马丁岛（荷兰部分）', 18.0333330, -63.0500000);

-- --------------------------------------------------------

--
-- 資料表結構 `location_regions`
--

CREATE TABLE `location_regions` (
  `region_id` int(11) NOT NULL,
  `region_name_en` varchar(100) NOT NULL,
  `region_name_zh_tw` varchar(100) NOT NULL,
  `region_name_zh_cn` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 傾印資料表的資料 `location_regions`
--

INSERT INTO `location_regions` (`region_id`, `region_name_en`, `region_name_zh_tw`, `region_name_zh_cn`) VALUES
(1, 'Africa', '非洲', '非洲'),
(2, 'Americas', '美洲', '美洲'),
(3, 'Asia', '亞洲', '亚洲'),
(4, 'Europe', '歐洲', '欧洲'),
(5, 'Oceania', '大洋洲', '大洋洲'),
(6, 'Polar', '南極洲', '南极洲');

-- --------------------------------------------------------

--
-- 資料表結構 `location_states`
--

CREATE TABLE `location_states` (
  `state_id` int(11) NOT NULL,
  `country_id` int(11) NOT NULL,
  `state_code` varchar(10) NOT NULL,
  `state_name_en` varchar(100) NOT NULL,
  `state_name_zh_tw` varchar(100) DEFAULT NULL,
  `state_name_zh_cn` varchar(100) DEFAULT NULL,
  `state_center_latitude` decimal(10,7) NOT NULL,
  `state_center_longitude` decimal(10,7) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 傾印資料表的資料 `location_states`
--

INSERT INTO `location_states` (`state_id`, `country_id`, `state_code`, `state_name_en`, `state_name_zh_tw`, `state_name_zh_cn`, `state_center_latitude`, `state_center_longitude`) VALUES
(1, 1, 'BDS', 'Badakhshan', '巴達赫尚', '巴达赫尚', 36.7347725, 70.8119953),
(2, 1, 'BDG', 'Badghis', '巴吉斯', '巴吉斯', 35.1671339, 63.7695384),
(3, 1, 'BGL', 'Baghlan', '巴格蘭', '巴格兰', 36.1789026, 68.7453064),
(4, 1, 'BAL', 'Balkh', '巴爾赫', '巴尔赫', 36.7550603, 66.8975372),
(5, 1, 'BAM', 'Bamyan', '巴米揚', '巴米扬', 34.8100067, 67.8212104),
(6, 1, 'DAY', 'Daykundi', '戴昆迪', '戴昆迪', 33.6694950, 66.0463534),
(7, 1, 'FRA', 'Farah', '法拉', '法拉', 32.4953280, 62.2626627),
(8, 1, 'FYB', 'Faryab', '法里亞布', '法里亚布', 36.0795613, 64.9059550),
(9, 1, 'GHA', 'Ghazni', '加茲尼', '加兹尼', 33.5450587, 68.4173972),
(10, 1, 'GHO', 'Ghōr', '戈爾', '戈尔', 34.0995776, 64.9059550),
(11, 1, 'HEL', 'Helmand', '赫爾曼德', '赫尔曼德省', 39.2989361, -76.6160472),
(12, 1, 'HER', 'Herat', '赫拉特', '赫拉特', 34.3528650, 62.2040287),
(13, 1, 'JOW', 'Jowzjan', '喬茲詹', '乔兹詹', 36.8969692, 65.6658568),
(14, 1, 'KAB', 'Kabul', '承諾', '接受', 34.5553494, 69.2074860),
(15, 1, 'KAN', 'Kandahar', '坎大哈', '坎大哈', 31.6288710, 65.7371749),
(16, 1, 'KAP', 'Kapisa', '卡普薩', '卡普萨', 34.9810572, 69.6214562),
(17, 1, 'KHO', 'Khost', '霍斯特', '霍斯特', 33.3338472, 69.9371673),
(18, 1, 'KNR', 'Kunar', '庫納爾', '库纳尔', 34.8465893, 71.0973170),
(19, 1, 'KDZ', 'Kunduz Province', '昆都士省', '昆都士省', 36.7285511, 68.8678982),
(20, 1, 'LAG', 'Laghman', '拉格曼', '拉格曼', 34.6897687, 70.1455805),
(21, 1, 'LOG', 'Logar', '洛加爾', '洛加尔', 34.0145518, 69.1923916),
(22, 1, 'NAN', 'Nangarhar', '楠格哈爾', '楠格哈尔', 34.1718313, 70.6216794),
(23, 1, 'NIM', 'Nimruz', '尼姆魯茲', '尼姆鲁兹', 31.0261488, 62.4504154),
(24, 1, 'NUR', 'Nuristan', '努里斯坦', '努里斯坦', 35.3250223, 70.9071236),
(25, 1, 'PIA', 'Paktia', '帕克蒂亞', '帕克蒂亚', 33.7061990, 69.3831079),
(26, 1, 'PKA', 'Paktika', '帕克蒂卡', '帕克蒂卡', 32.2645386, 68.5247149),
(27, 1, 'PAN', 'Panjshir', '潘傑希爾', '潘杰希尔', 38.8802391, -77.1717238),
(28, 1, 'PAR', 'Parwan', '帕爾萬', '帕尔万', 34.9630977, 68.8108849),
(29, 1, 'SAM', 'Samangan', '薩曼甘', '三满眼', 36.3155506, 67.9642863),
(30, 1, 'SAR', 'Sar-e Pol', '薩爾波爾', '萨尔波尔', 36.2166280, 65.9333600),
(31, 1, 'TAK', 'Takhar', '塔哈爾', '塔哈尔', 36.6698013, 69.4784541),
(32, 1, 'URU', 'Urozgan', '烏羅茲甘', '乌罗兹甘', 32.9271287, 66.1415263),
(33, 1, 'ZAB', 'Zabul', '扎布爾', '扎布尔', 32.1918782, 67.1894488),
(34, 2, '', 'Brändö', '布蘭多', '布兰多', 60.4125908, 21.0229942),
(35, 2, '', 'Eckerö', '埃克羅', '埃克罗', 60.2231814, 19.5389379),
(36, 2, '', 'Finström', '芬斯特倫', '芬斯特伦', 60.2299321, 19.9674636),
(37, 2, '', 'Föglö', '福格洛', '福格洛', 60.0146277, 20.3933407),
(38, 2, '', 'Geta', '能', '能', 60.3749727, 19.8265962),
(39, 2, '', 'Hammarland', '哈馬蘭', '哈马兰', 60.2164183, 19.7196403),
(40, 2, '', 'Jomala', '喬馬拉', '乔马拉', 60.1522391, 19.8747981),
(41, 2, '', 'Kökar', '廚師', '厨师', 59.9208170, 20.8885302),
(42, 2, '', 'Kumlinge', '庫姆林格', '库姆林格', 60.2599272, 20.7587500),
(43, 2, '', 'Lemland', '萊姆蘭', '莱姆兰', 60.0688705, 20.0658140),
(44, 2, '', 'Lumparland', '蘭帕蘭', '兰帕兰', 60.1152357, 20.2414280),
(45, 2, '', 'Mariehamn', '瑪麗港', '玛丽港', 60.0945578, 19.7950530),
(46, 2, '', 'Saltvik', '薩爾特維克', '萨尔特维克', 60.2755446, 20.0413192),
(47, 2, '', 'Sottunga', '減', '减去', 60.1307977, 20.6459821),
(48, 2, '', 'Sund', '健', '健康', 60.2308476, 19.8239705),
(49, 2, '', 'Vårdö', 'Vårdö', 'Vårdö', 60.2423396, 20.3528105),
(50, 3, 'BR', 'Berat', '重', '重', 40.7086377, 19.9437314),
(51, 3, '01', 'Berat', '重', '重', 40.6953012, 20.0449662),
(52, 3, 'BU', 'Bulqizë', '布爾奇扎', '布尔奇扎', 41.4942587, 20.2147157),
(53, 3, 'DL', 'Delvinë', '德爾維娜', '德尔维娜', 39.9481364, 20.0955891),
(54, 3, 'DV', 'Devoll', '滿', '满', 40.6447347, 20.9506636),
(55, 3, '09', 'Dibër', '迪貝爾', '迪贝尔', 41.5888163, 20.2355647),
(56, 3, 'DI', 'Dibër', '迪貝爾', '迪贝尔', 41.5888163, 20.2355647),
(57, 3, 'DR', 'Durrës', '都拉斯', '都拉斯', 41.3706517, 19.5211063),
(58, 3, '02', 'Durrës', '都拉斯', '都拉斯', 41.5080972, 19.6163185),
(59, 3, '03', 'Elbasan', '艾爾巴桑', '厄尔巴桑', 41.1266672, 20.2355647),
(60, 3, 'FR', 'Fier', '驕傲', '骄傲', 40.7275040, 19.5627596),
(61, 3, '04', 'Fier', '驕傲', '骄傲', 40.9191392, 19.6639309),
(62, 3, 'GJ', 'Gjirokastër', '吉羅卡斯特拉', '吉罗卡斯特拉', 40.0672874, 20.1045229),
(63, 3, '05', 'Gjirokastër', '吉羅卡斯特拉', '吉罗卡斯特拉', 40.0672874, 20.1045229),
(64, 3, 'GR', 'Gramsh', '格拉姆什', '格拉姆什', 40.8669873, 20.1849323),
(65, 3, 'HA', 'Has', '有', '有', 42.7901336, -83.6122012),
(66, 3, 'KA', 'Kavajë', '卡瓦亞', '卡瓦亚', 41.1844529, 19.5627596),
(67, 3, 'ER', 'Kolonjë', '科隆傑', '科隆耶', 40.3373262, 20.6794676),
(68, 3, '06', 'Korçë', '科爾薩', '科尔萨', 40.5905670, 20.6168921),
(69, 3, 'KO', 'Korçë', '科爾薩', '科尔萨', 40.5905670, 20.6168921),
(70, 3, 'KR', 'Krujë', '克魯亞', '克鲁亚', 41.5094765, 19.7710732),
(71, 3, 'KC', 'Kuçovë', '庫索瓦', '库索瓦', 40.7837063, 19.8782348),
(72, 3, 'KU', 'Kukës', '庫克斯', '库克斯', 42.0807464, 20.4142923),
(73, 3, '07', 'Kukës', '庫克斯', '库克斯', 42.0807464, 20.4142923),
(74, 3, 'KB', 'Kurbin', '庫爾賓', '库尔宾', 41.6412644, 19.7055950),
(75, 3, '08', 'Lezhë', '樂吒', '乐栅', 41.7813759, 19.8067916),
(76, 3, 'LE', 'Lezhë', '樂吒', '乐栅', 41.7860730, 19.6460758),
(77, 3, 'LB', 'Librazhd', '利布拉日德', '利布拉日德', 41.1829232, 20.3174769),
(78, 3, 'LU', 'Lushnjë', 'Lushnjë', 'Lushnjë', 40.9419830, 19.6996428),
(79, 3, 'MM', 'Malësi e Madhe', 'Malësi e Madhe', 'Malësi e Madhe', 42.4245173, 19.6163185),
(80, 3, 'MK', 'Mallakastër', '馬拉卡斯特爾', '马拉卡斯特', 40.5273376, 19.7829791),
(81, 3, 'MT', 'Mat', '食', '食物', 41.5937675, 19.9973244),
(82, 3, 'MR', 'Mirditë', '米爾迪塔', '米尔迪塔', 41.7642860, 19.9020509),
(83, 3, 'PQ', 'Peqin', '北京', '北京', 41.0470902, 19.7502384),
(84, 3, 'PR', 'Përmet', '佩爾梅特', '佩尔梅特', 40.2361837, 20.3517334),
(85, 3, 'PG', 'Pogradec', '波格拉德克', '波格拉德', 40.9015314, 20.6556289),
(86, 3, 'PU', 'Pukë', '普克', '普克', 42.0469772, 19.8960968),
(87, 3, 'SR', 'Sarandë', '薩蘭達', '萨兰达', 39.8592119, 20.0271001),
(88, 3, '10', 'Shkodër', '斯庫台', '斯库台', 42.1503710, 19.6639309),
(89, 3, 'SH', 'Shkodër', '斯庫台', '斯库台', 42.0692985, 19.5032559),
(90, 3, 'SK', 'Skrapar', '斯克拉帕爾', '斯克拉帕尔', 40.5349946, 20.2832217),
(91, 3, 'TE', 'Tepelenë', '特佩萊納', '特佩莱纳', 40.2966632, 20.0181673),
(92, 3, 'TR', 'Tirana', '地拉那', '地拉那', 41.3275459, 19.8186982),
(93, 3, '11', 'Tirana', '地拉那', '地拉那', 41.2427598, 19.8067916),
(94, 3, 'TP', 'Tropojë', '跌跌撞撞', '绊脚石', 42.3982151, 20.1625955),
(95, 3, '12', 'Vlorë', '發羅拉', '发罗拉', 40.1500960, 19.8067916),
(96, 3, 'VL', 'Vlorë', '發羅拉', '发罗拉', 40.4660668, 19.4913560),
(97, 4, '01', 'Adrar', '阿德拉爾', '阿德拉尔', 26.4181310, -0.6014717),
(98, 4, '44', 'Aïn Defla', '艾因·德弗拉', '艾因·德弗拉', 36.2509429, 1.9393815),
(99, 4, '46', 'Aïn Témouchent', '艾恩·特穆森特', 'Aïn Témouchent', 35.2992698, -1.1392792),
(100, 4, '16', 'Algiers', '阿爾及爾', '阿尔及尔', 36.6997294, 3.0576199),
(101, 4, '23', 'Annaba', '安納巴', '安纳巴', 36.8020508, 7.5247243),
(102, 4, '05', 'Batna', '巴特納', '巴特纳', 35.5965954, 5.8987139),
(103, 4, '08', 'Béchar', '貝夏爾', '贝沙尔', 31.6238098, -2.2162443),
(104, 4, '06', 'Béjaïa', '貝賈亞', '贝贾亚', 36.7515258, 5.0556837),
(105, 4, '53', 'Béni Abbès', '貝尼·阿貝斯', '贝尼·阿贝斯', 30.0831042, -2.8345052),
(106, 4, '07', 'Biskra', '比斯克拉', '比斯克拉', 34.8449437, 5.7248567),
(107, 4, '09', 'Blida', '布利達', '布利达', 36.5311230, 2.8976254),
(108, 4, '52', 'Bordj Baji Mokhtar', '博爾吉·巴吉·莫赫塔爾', '博尔吉·巴吉·莫赫塔尔', 22.9663350, -3.9472732),
(109, 4, '34', 'Bordj Bou Arréridj', '博爾吉·布·阿雷里吉', '博尔吉·布·阿雷里吉', 36.0739925, 4.7630271),
(110, 4, '10', 'Bouïra', '布伊拉', '布伊拉', 36.3691846, 3.9006194),
(111, 4, '35', 'Boumerdès', '布默德斯', '布默德斯', 36.6839559, 3.6217802),
(112, 4, '02', 'Chlef', '克萊夫', 'Chlef', 36.1693515, 1.2891036),
(113, 4, '25', 'Constantine', '君士坦丁', '君士坦丁', 36.3373911, 6.6638120),
(114, 4, '56', 'Djanet', '賈內特', '贾内特', 23.8310872, 8.7004672),
(115, 4, '17', 'Djelfa', '傑爾法', '杰尔法', 34.6703956, 3.2503761),
(116, 4, '32', 'El Bayadh', '埃爾巴亞德', '埃尔巴亚德', 32.7148824, 0.9056623),
(117, 4, '49', 'El M\'ghair', 'The M', 'The M', 33.9540561, 5.1346418),
(118, 4, '50', 'El Menia', '梅尼亞', '梅尼亚', 31.3642250, 2.5784495),
(119, 4, '39', 'El Oued', '烏德', '乌德', 33.3678110, 6.8516511),
(120, 4, '36', 'El Tarf', '塔夫', '塔夫', 36.7576678, 8.3076343),
(121, 4, '47', 'Ghardaïa', '加爾達亞', '加尔达亚', 32.4943741, 3.6444600),
(122, 4, '24', 'Guelma', '圭爾馬', '圭尔马', 36.4627444, 7.4330833),
(123, 4, '33', 'Illizi', '伊利茲', '伊利兹', 26.1690005, 8.4842465),
(124, 4, '58', 'In Guezzam', '位於蓋扎姆', '在盖扎姆', 20.3864323, 4.7789394),
(125, 4, '57', 'In Salah', '在薩拉赫', '在萨拉赫', 27.2149229, 1.8484396),
(126, 4, '18', 'Jijel', '吉傑爾', '吉杰尔', 36.7179681, 5.9832577),
(127, 4, '40', 'Khenchela', '肯切拉', '肯切拉', 35.4269404, 7.1460155),
(128, 4, '03', 'Laghouat', '拉古特', '拉古特', 33.8078341, 2.8628294),
(129, 4, '28', 'M\'Sila', 'M', 'M', 35.7186646, 4.5233423),
(130, 4, '29', 'Mascara', '睫毛膏', '睫毛膏', 35.3904125, 0.1494988),
(131, 4, '26', 'Médéa', '美狄亞', '美狄亚', 36.2637078, 2.7587857),
(132, 4, '43', 'Mila', '千', '千', 36.3647957, 6.1526985),
(133, 4, '27', 'Mostaganem', '莫斯塔加南', '莫斯塔加南', 35.9583054, 0.3371889),
(134, 4, '45', 'Naama', '臉', '脸', 33.2667317, -0.3128659),
(135, 4, '31', 'Oran', '奧蘭', '奥兰', 35.6082351, -0.5636090),
(136, 4, '30', 'Ouargla', '瓦爾格拉', '瓦尔格拉', 32.2264863, 5.7299821),
(137, 4, '51', 'Ouled Djellal', '烏萊德·傑拉爾', '乌莱德·杰拉尔', 34.4178221, 4.9685843),
(138, 4, '04', 'Oum El Bouaghi', '烏姆·埃爾·布瓦吉', '乌姆·埃尔·布瓦吉', 35.8688789, 7.1108266),
(139, 4, '48', 'Relizane', '雷利扎內', '瑞利赞', 35.7383405, 0.7532809),
(140, 4, '20', 'Saïda', '齋田', '斋田', 34.8415207, 0.1456055),
(141, 4, '19', 'Sétif', '塞蒂夫', '塞蒂夫', 36.3073389, 5.5617279),
(142, 4, '22', 'Sidi Bel Abbès', '西迪·貝爾·阿貝斯', '西迪·贝尔·阿贝斯', 34.6806024, -1.0999495),
(143, 4, '21', 'Skikda', '斯基克達', '斯基克达', 36.6721198, 6.8350999),
(144, 4, '41', 'Souk Ahras', '阿拉斯露天市場', '阿赫拉斯露天市场', 36.2801062, 7.9384033),
(145, 4, '11', 'Tamanghasset', '塔曼加塞特', '塔曼加塞特', 22.7902972, 5.5193268),
(146, 4, '12', 'Tébessa', '泰貝薩', 'Tébessa', 35.1290691, 7.9592863),
(147, 4, '14', 'Tiaret', '蒂亞雷特', '蒂亚雷特', 35.3708689, 1.3217852),
(148, 4, '54', 'Timimoun', '蒂米蒙', '蒂米蒙', 29.6789060, 0.5004608),
(149, 4, '37', 'Tindouf', '廷杜夫', '廷杜夫', 27.8063119, -5.7299821),
(150, 4, '42', 'Tipasa', '蒂帕薩', '蒂帕萨', 36.5462650, 2.1843285),
(151, 4, '38', 'Tissemsilt', '蒂塞姆西爾特', '蒂塞姆西尔特', 35.6053781, 1.8130980),
(152, 4, '15', 'Tizi Ouzou', '提子歐祖', '提子欧祖', 36.7069110, 4.2333355),
(153, 4, '13', 'Tlemcen', '特萊姆森', '特莱姆森', 34.6780284, -1.3662160),
(154, 4, '55', 'Touggourt', '圖古特', '图古尔特', 33.1248476, 5.7832715),
(155, 5, '02', 'Eastern', '東', '东部', -14.2756039, -170.8085592),
(156, 5, '03', 'Manuʻa', '受傷', '损伤', -14.2112641, -169.7111892),
(157, 5, '05', 'Rose', '玫', '玫', -14.5449161, -168.1763292),
(158, 5, '04', 'Swains', '斯溫斯', '斯温斯', -11.0565878, -171.0882909),
(159, 5, '01', 'Western', '西方的', '西方', -14.3330751, -170.9431502),
(160, 6, '07', 'Andorra la Vella', '安道爾城', '安道尔城', 42.5063174, 1.5218355),
(161, 6, '02', 'Canillo', '卡尼洛', '卡尼略', 42.5978249, 1.6566377),
(162, 6, '03', 'Encamp', '紮營', '安坎普', 42.5359764, 1.5836773),
(163, 6, '08', 'Escaldes-Engordany', '埃斯卡爾德斯-恩戈爾達尼', '埃斯卡尔德斯-恩戈尔达尼', 42.4909379, 1.5886966),
(164, 6, '04', 'La Massana', '拉馬薩納', '拉马萨纳', 42.5456250, 1.5147392),
(165, 6, '05', 'Ordino', '奧迪諾', '奥迪诺', 42.5994433, 1.5402327),
(166, 6, '06', 'Sant Julià de Lòria', '聖朱利亞德洛里亞', '圣朱利亚德洛里亚', 42.4529631, 1.4918235),
(167, 7, 'BGO', 'Bengo', '本戈', '本戈', -9.1042257, 13.7289167),
(168, 7, 'BGU', 'Benguela', '本格拉', '本格拉', -12.8003744, 13.9143990),
(169, 7, 'BIE', 'Bié', '比埃', '比埃', -12.5727907, 17.6688870),
(170, 7, 'CAB', 'Cabinda', '卡賓達', '卡宾达', -5.0248749, 12.3463875),
(171, 7, 'CCU', 'Cuando Cubango', '當古巴哥', '当古巴哥', -16.4180824, 18.8076195),
(172, 7, 'CUS', 'Cuanza', '寬扎', '宽扎', -10.5951910, 15.4068079),
(173, 7, 'CNO', 'Cuanza Norte', '北寬扎', '北宽扎', -9.2398513, 14.6587821),
(174, 7, 'CNN', 'Cunene', '庫寧', '楔形', -16.2802221, 16.1580937),
(175, 7, 'HUA', 'Huambo', '萬博', '万博', -12.5268221, 15.5943388),
(176, 7, 'HUI', 'Huíla', '惠拉', '威拉', -14.9280553, 14.6587821),
(177, 7, 'LUA', 'Luanda', '羅安達', '罗安达', -9.0350880, 13.2663479),
(178, 7, 'LNO', 'Lunda Norte', '北隆達', '北隆达', -8.3525022, 19.1880047),
(179, 7, 'LSU', 'Lunda Sul', '南隆達', '南隆达', -10.2866578, 20.7122465),
(180, 7, 'MAL', 'Malanje', '明天', '明天', -9.8251183, 16.9122510),
(181, 7, 'MOX', 'Moxico', '莫西科', '莫西科', -13.4293579, 20.3308814),
(182, 7, 'UIG', 'Uíge', '威熱', '威热', -7.1736732, 15.4068079),
(183, 7, 'ZAI', 'Zaire', '扎伊爾', '扎伊尔', -6.5733458, 13.1740348),
(184, 8, '', 'Blowing Point', '吹點', '吹点', 18.1765553, -63.1021296),
(185, 8, '', 'East End', '東區', '东区', 18.2356173, -63.0149715),
(186, 8, '', 'George Hill', '喬治·希爾', '乔治·希尔', 18.1997811, -63.0776114),
(187, 8, '', 'Island Harbour', '港島', '港岛', 18.2552125, -63.0140590),
(188, 8, '', 'North Hill', '北山', '北山', 18.2050863, -63.0858457),
(189, 8, '', 'North Side', '北側', '北侧', 18.2300544, -63.0518890),
(190, 8, '', 'Sandy Ground', '沙地', '沙地', 18.2018551, -63.0973471),
(191, 8, '', 'Sandy Hill', '桑迪山', '桑迪山', 18.2189210, -63.0129916),
(192, 8, '', 'South Hill', '南山', '南山', 18.1892475, -63.0976367),
(193, 8, '', 'Stoney Ground', '石地', '石地', 18.2179101, -63.0496986),
(194, 8, '', 'The Farrington', '法靈頓酒店', '法灵顿酒店', 18.2134701, -63.0272162),
(195, 8, '', 'The Quarter', '季度', '季度', 18.2145334, -63.0564489),
(196, 8, '', 'The Valley', '山谷', '山谷', 18.2152166, -63.0700628),
(197, 8, '', 'West End', '西區', '西区', 18.1715394, -63.1719127),
(198, 10, '10', 'Barbuda', '巴布達', '巴布达', 17.6266242, -61.7713028),
(199, 10, '11', 'Redonda', '圓', '圆', 16.9384160, -62.3455148),
(200, 10, '03', 'Saint George', '聖喬治', '圣乔治', 17.1261929, -61.8192183),
(201, 10, '04', 'Saint John', '聖約翰', '圣约翰', 17.1136338, -61.9282714),
(202, 10, '05', 'Saint Mary', '聖瑪麗', '圣玛丽', 17.0544373, -61.8969037),
(203, 10, '06', 'Saint Paul', '聖保羅', '圣保罗', 17.0319384, -61.8126604),
(204, 10, '07', 'Saint Peter', '聖彼得', '圣彼得', 17.1054838, -61.7912317),
(205, 10, '08', 'Saint Philip', '聖菲利普', '圣菲利普', 17.0674913, -61.7419026),
(206, 11, 'C', 'Autonomous City of Buenos Aires', '布宜諾斯艾利斯自治市', '布宜诺斯艾利斯自治市', -34.6036844, -58.3815591),
(207, 11, 'B', 'Buenos Aires', '布宜諾斯艾利斯', '布宜诺斯艾利斯', -37.2017285, -59.8410697),
(208, 11, 'K', 'Catamarca', '卡塔馬卡', '卡塔马卡', -28.4715877, -65.7877209),
(209, 11, 'H', 'Chaco', '查科', '查哥', -27.4257175, -59.0243784),
(210, 11, 'U', 'Chubut', '丘布特', '丘布特', -43.2934246, -65.1114818),
(211, 11, 'X', 'Córdoba', '科爾多瓦', '科尔多瓦', -31.3992876, -64.2643842),
(212, 11, 'W', 'Corrientes', '電流', '电流', -27.4692131, -58.8306349),
(213, 11, 'E', 'Entre Ríos', 'Entre Ríos', 'Entre Ríos', -31.7746654, -60.4956461),
(214, 11, 'P', 'Formosa', '台灣', '台湾', -26.1894804, -58.2242806),
(215, 11, 'Y', 'Jujuy', '胡胡伊', '胡胡伊', -24.1843397, -65.3021770),
(216, 11, 'L', 'La Pampa', '拉潘帕', '拉潘帕', -36.6147573, -64.2839209),
(217, 11, 'F', 'La Rioja', '拉里奧哈', '拉里奥哈', -29.4193793, -66.8559932),
(218, 11, 'M', 'Mendoza', '門多薩', '门多萨', -32.8894587, -68.8458386),
(219, 11, 'N', 'Misiones', '任務', '任务', -27.4269255, -55.9467076),
(220, 11, 'Q', 'Neuquén', '內烏肯', '内乌肯', -38.9458700, -68.0730925),
(221, 11, 'R', 'Río Negro', '里奧內格羅', '里约内格罗', -40.8261434, -63.0266339),
(222, 11, 'A', 'Salta', '薩爾塔', '萨尔塔', -24.7997688, -65.4150367),
(223, 11, 'J', 'San Juan', '聖胡安', '圣胡安', -31.5316976, -68.5676962),
(224, 11, 'D', 'San Luis', '聖路易斯', '圣路易斯', -33.2962042, -66.3294948),
(225, 11, 'Z', 'Santa Cruz', '聖克魯斯', '圣克鲁斯', -51.6352821, -69.2474353),
(226, 11, 'S', 'Santa Fe', '聖達菲', '圣菲', -31.5855109, -60.7238016),
(227, 11, 'G', 'Santiago del Estero', '聖地亞哥德爾埃斯特羅', '圣地亚哥德尔埃斯特罗', -27.7833574, -64.2641670),
(228, 11, 'V', 'Tierra del Fuego', '火地島', '火地岛', -54.8053998, -68.3242061),
(229, 11, 'T', 'Tucumán', '圖庫曼', '图库曼', -26.8221127, -65.2192903),
(230, 12, 'AG', 'Aragatsotn', '阿拉加索頓', '阿拉加索顿', 40.3347301, 44.3748296),
(231, 12, 'AR', 'Ararat', '亞拉臘', '亚拉腊', 39.9139415, 44.7200004),
(232, 12, 'AV', 'Armavir', '阿瑪韋爾', '阿马韦', 40.1554631, 44.0372446),
(233, 12, 'GR', 'Gegharkunik', '格加爾庫尼克', '格加尔库尼克', 40.3526426, 45.1260414),
(234, 12, 'KT', 'Kotayk', '科塔克', '科塔克', 40.5410214, 44.7690148),
(235, 12, 'LO', 'Lori', '蘿莉', '罗莉', 40.9698452, 44.4900138),
(236, 12, 'SH', 'Shirak', '希拉克', '希拉克', 40.9630814, 43.8102461),
(237, 12, 'SU', 'Syunik', '舒尼克', '舒尼克', 39.5133112, 46.3393234),
(238, 12, 'TV', 'Tavush', '塔武什', '塔武什', 40.8866296, 45.3393490),
(239, 12, 'VD', 'Vayots Dzor', '瓦約茨·佐爾', '瓦约茨·佐尔', 39.7641996, 45.3337528),
(240, 12, 'ER', 'Yerevan', '埃里溫', '埃里温', 40.1872023, 44.5152090),
(241, 13, '', 'Noord', '北', '北', 12.5824329, -70.0676118),
(242, 13, '', 'Oranjestad', '奧拉涅斯塔德', '奥拉涅斯塔德', 12.5083705, -70.0545253),
(243, 13, '', 'Oranjestad East', '奧拉涅斯塔德東', '奥拉涅斯塔德东', 12.5133181, -70.0504818),
(244, 13, '', 'Oranjestad West', '奧拉涅斯塔德西', '奥拉涅斯塔德西', 12.5352293, -70.0628404),
(245, 13, '', 'Paradera', '帕拉德拉', '帕拉德拉', 12.5362871, -70.0148511),
(246, 13, '', 'San Nicolaas Noord', '聖尼古拉斯北', '圣尼古拉斯北', 12.4642717, -69.9434939),
(247, 13, '', 'San Nicolaas Zuid', '聖尼古拉斯南區', '圣尼古拉斯南区', 12.4278558, -69.9381079),
(248, 13, '', 'Santa Cruz', '聖克魯斯', '圣克鲁斯', 12.5112836, -69.9876966),
(249, 13, '', 'Savaneta', '薩瓦內塔', '萨瓦内塔', 12.4618419, -69.9855858),
(250, 14, 'ACT', 'Australian Capital Territory', '澳大利亞首都特區', '澳大利亚首都特区', -35.4734679, 149.0123679),
(251, 14, 'NSW', 'New South Wales', '新南威爾士州', '新南威尔士州', -31.2532183, 146.9210990),
(252, 14, 'NT', 'Northern Territory', '北領地', '北部地区', -19.4914108, 132.5509603),
(253, 14, 'QLD', 'Queensland', '昆士蘭州', '昆士兰', -20.9175738, 142.7027956),
(254, 14, 'SA', 'South Australia', '南澳大利亞', '南澳大利亚', -30.0002315, 136.2091547),
(255, 14, 'TAS', 'Tasmania', '塔斯馬尼亞', '塔斯马尼亚', -41.4545196, 145.9706647),
(256, 14, 'VIC', 'Victoria', '維多利亞', '维多利亚', -36.4856423, 140.9779425),
(257, 14, 'WA', 'Western Australia', '西澳大利亞州', '西澳大利亚州', -27.6728168, 121.6283098),
(258, 15, '1', 'Burgenland', '布爾根蘭', '布尔根兰', 47.1537165, 16.2688797),
(259, 15, '2', 'Carinthia', '克恩頓州', '克恩顿州', 46.7222030, 14.1805882),
(260, 15, '3', 'Lower Austria', '下奧地利州', '下奥地利州', 48.1080770, 15.8049558),
(261, 15, '5', 'Salzburg', '薩爾茨堡', '萨尔茨堡', 47.8094900, 13.0550100),
(262, 15, '6', 'Styria', '施蒂利亞州', '施蒂里亚州', 47.3593442, 14.4699827),
(263, 15, '7', 'Tyrol', '蒂羅爾', '蒂罗尔', 47.2537414, 11.6014870),
(264, 15, '4', 'Upper Austria', '上奧地利州', '上奥地利州', 48.0258540, 13.9723665),
(265, 15, '9', 'Vienna', '維也納', '维也纳', 48.2081743, 16.3738189),
(266, 15, '8', 'Vorarlberg', '福拉爾貝格州', '福拉尔贝格州', 47.2497427, 9.9797373),
(267, 16, 'ABS', 'Absheron', '阿布謝隆', '阿布谢隆', 40.3629693, 49.2736815),
(268, 16, 'AGM', 'Agdam', '阿格達姆', '阿格达姆', 39.9931853, 46.9949562),
(269, 16, 'AGS', 'Agdash', '阿格達什', '阿格达什', 40.6335427, 47.4674310),
(270, 16, 'AGC', 'Aghjabadi', '阿賈巴迪', '阿贾巴迪', 28.7891841, 77.5160788),
(271, 16, 'AGA', 'Agstafa', '阿格斯塔法', '阿格斯塔法', 41.2655933, 45.5134291),
(272, 16, 'AGU', 'Agsu', '阿格蘇', '阿格苏', 40.5283339, 48.3650835),
(273, 16, 'AST', 'Astara', '阿斯塔拉', '阿斯塔拉', 38.4937845, 48.6944365),
(274, 16, 'BAB', 'Babek', '嬰兒', '婴儿', 39.1507613, 45.4485368),
(275, 16, 'BA', 'Baku', '巴庫', '巴库', 40.4092617, 49.8670924),
(276, 16, 'BAL', 'Balakan', '巴拉坎', '巴拉坎', 41.7037509, 46.4044213),
(277, 16, 'BAR', 'Barda', '圍牆', '栅栏', 40.3706555, 47.1378909),
(278, 16, 'BEY', 'Beylagan', '貝拉根', '贝拉根', 39.7723073, 47.6154166),
(279, 16, 'BIL', 'Bilasuvar', '比拉蘇瓦爾', '比拉苏瓦尔', 39.4598833, 48.5509813),
(280, 16, 'DAS', 'Dashkasan', '達什卡桑', '达什卡桑', 40.5202257, 46.0779304),
(281, 16, 'FUZ', 'Fizuli', '菲祖利', '菲祖利', 39.5378605, 47.3033877),
(282, 16, 'GA', 'Ganja', '甘賈', '大麻', 36.3687338, -95.9985767),
(283, 16, 'GAD', 'Gədəbəy', '結論', '加纳', 40.5699639, 45.8106883),
(284, 16, 'QOB', 'Gobustan', '戈布斯坦', '戈布斯坦', 40.5326104, 48.9273750),
(285, 16, 'GOR', 'Goranboy', '戈蘭博伊', '戈兰博伊', 40.5380506, 46.5990891),
(286, 16, 'GOY', 'Goychay', '戈伊查伊', '戈伊查伊', 40.6236168, 47.7403034),
(287, 16, 'GYG', 'Goygol', '戈伊戈爾', '戈伊戈尔', 40.5595378, 46.3314953),
(288, 16, 'HAC', 'Hajigabul', '哈芝加布爾', '哈吉加布尔', 40.0393770, 48.9202533),
(289, 16, 'IMI', 'Imishli', '伊米什利', '伊米什利', 39.8694686, 48.0665218),
(290, 16, 'ISM', 'Ismailli', '伊斯梅利', '伊斯梅利', 40.7429936, 48.2125556),
(291, 16, 'CAB', 'Jabrayil', '加百列', '加布里埃尔', 39.2645544, 46.9621562),
(292, 16, 'CAL', 'Jalilabad', '賈利拉巴德', '贾利拉巴德', 39.2051632, 48.5100604),
(293, 16, 'CUL', 'Julfa', '朱爾法', '朱尔发', 38.9604983, 45.6292939),
(294, 16, 'KAL', 'Kalbajar', '卡爾巴賈爾', '卡尔巴贾尔', 40.1024329, 46.0364872),
(295, 16, 'KAN', 'Kangarli', '袋鼠', '袋鼠', 39.3871940, 45.1639852),
(296, 16, 'XAC', 'Khachmaz', '哈奇馬茲', '哈奇马兹', 41.4591168, 48.8020626),
(297, 16, 'XIZ', 'Khizi', '希茲', '希兹', 40.9109489, 49.0729264),
(298, 16, 'XCI', 'Khojali', '霍賈利', '霍贾利', 39.9132553, 46.7943050),
(299, 16, 'KUR', 'Kurdamir', '庫爾達米爾', '库尔达米尔', 40.3698651, 48.1644626),
(300, 16, 'LAC', 'Lachin', '拉欽', '拉钦', 39.6383414, 46.5460853),
(301, 16, 'LAN', 'Lankaran', '蘭卡蘭', '兰卡兰', 38.7528669, 48.8475015),
(302, 16, 'LA', 'Lankaran', '蘭卡蘭', '兰卡兰', 38.7528669, 48.8475015),
(303, 16, 'LER', 'Lerik', '萊里克', '莱里克', 38.7736192, 48.4151483),
(304, 16, 'XVD', 'Martuni', '馬圖尼', '马尔图尼', 39.7914693, 47.1100814),
(305, 16, 'MAS', 'Masally', '馬薩利', '马萨利', 39.0340722, 48.6589354),
(306, 16, 'MI', 'Mingachevir', '明加切韋爾', '明加切韦', 40.7702563, 47.0496015),
(307, 16, 'NX', 'Nakhchivan', '納希切萬', '纳希切万', 39.3256814, 45.4912648),
(308, 16, 'NEF', 'Neftchala', '內夫查拉', '内夫查拉', 39.3881052, 49.2413743),
(309, 16, 'OGU', 'Oghuz', '烏古斯', '乌古斯语', 41.0727924, 47.4650672),
(310, 16, 'ORD', 'Ordubad', '奧爾杜巴德', '奥尔杜巴德', 38.9021622, 46.0237625),
(311, 16, 'QAB', 'Qabala', '卡巴拉', '卡巴拉', 40.9253925, 47.8016106),
(312, 16, 'QAX', 'Qakh', '卡赫', '卡赫', 41.4206827, 46.9320184),
(313, 16, 'QAZ', 'Qazakh', '卡扎克', '卡扎赫', 41.0971074, 45.3516331),
(314, 16, 'QBA', 'Quba', '曲巴', '曲巴', 41.1564242, 48.4135021),
(315, 16, 'QBI', 'Qubadli', '庫巴德利', '库巴德利', 39.2713996, 46.6354312),
(316, 16, 'QUS', 'Qusar', '庫薩爾', '库萨尔', 41.4266886, 48.4345577),
(317, 16, 'SAT', 'Saatly', '薩特利', '萨特利', 39.9095503, 48.3595122),
(318, 16, 'SAB', 'Sabirabad', '薩比拉巴德', '萨比拉巴德', 39.9870663, 48.4692545),
(319, 16, 'SAD', 'Sadarak', '薩達拉克', '萨达拉克', 39.7105114, 44.8864277),
(320, 16, 'SAL', 'Salyan', '薩利安', '萨利安', 28.3524811, 82.1278400),
(321, 16, 'SMX', 'Samukh', '薩穆克', '萨穆克', 40.7604631, 46.4063181),
(322, 16, 'SBN', 'Shabran', '沙布蘭', '沙布兰', 41.2228376, 48.8457304),
(323, 16, 'SAH', 'Shahbuz', '沙布茲', '沙布兹', 39.4452103, 45.6568009),
(324, 16, 'SA', 'Shaki', '疑點', '怀疑', 41.1974753, 47.1571241),
(325, 16, 'SAK', 'Shaki', '疑點', '怀疑', 41.1134662, 47.1316927),
(326, 16, 'SMI', 'Shamakhi', '沙馬基', '沙马基', 40.6318731, 48.6363801),
(327, 16, 'SKR', 'Shamkir', '沙姆基爾', '沙姆基尔', 40.8288144, 46.0166879),
(328, 16, 'SAR', 'Sharur', '沙魯爾', '沙鲁尔', 39.5536332, 44.9845680),
(329, 16, 'SR', 'Shirvan', '希爾萬', '希尔万', 39.9469707, 48.9223919),
(330, 16, 'SUS', 'Shusha', '舒沙', '舒沙', 39.7537438, 46.7464755),
(331, 16, 'SIY', 'Siazan', '錫亞贊', '锡亚赞', 41.0783833, 49.1118477),
(332, 16, 'SM', 'Sumqayit', '蘇姆卡伊特', '苏姆卡伊特', 40.5854765, 49.6317411),
(333, 16, 'TAR', 'Tartar', '牙垢', '牙垢', 40.3443875, 46.9376519),
(334, 16, 'TOV', 'Tovuz', '托武茲', '托武兹', 40.9954523, 45.6165907),
(335, 16, 'UCA', 'Ujar', '烏賈爾', '乌贾尔', 40.5067525, 47.6489641),
(336, 16, 'YAR', 'Yardymli', '亞德姆利', '亚德姆利', 38.9058917, 48.2496127),
(337, 16, 'YE', 'Yevlakh', '葉夫拉赫', '叶夫拉赫', 40.6196638, 47.1500324),
(338, 16, 'YEV', 'Yevlakh', '葉夫拉赫', '叶夫拉赫', 40.6196638, 47.1500324),
(339, 16, 'ZAN', 'Zangilan', '贊吉蘭', '赞吉兰', 39.0856899, 46.6524728),
(340, 16, 'ZAQ', 'Zaqatala', '扎卡塔拉', '扎卡塔拉', 41.5906889, 46.7240373),
(341, 16, 'ZAR', 'Zardab', '扎達布', '扎达布', 40.2148114, 47.7149440),
(342, 18, '13', 'Capital', '首都', '资本', 26.1929274, 50.4925670),
(343, 18, '16', 'Central', '中', '中央', 26.1426093, 50.5653294),
(344, 18, '15', 'Muharraq', '穆哈拉克', '穆哈拉克', 26.2685653, 50.6482517),
(345, 18, '17', 'Northern', '北', '北方', 26.1551914, 50.4825173),
(346, 18, '14', 'Southern', '南方的', '南部', 25.9381018, 50.5756887),
(347, 19, 'A', 'Barisal ', '巴里薩爾', '巴里萨尔', 22.3811131, 90.3371889),
(348, 19, 'B', 'Chittagong ', '吉大港', '吉大港', 23.1793157, 91.9881527),
(349, 19, 'C', 'Dhaka ', '達卡', '达卡', 23.9535742, 90.1494988),
(350, 19, 'D', 'Khulna ', '庫爾納', '库尔纳', 22.8087816, 89.2467191),
(351, 19, 'H', 'Mymensingh ', '邁門辛', '迈门辛', 24.7136200, 90.4502368),
(352, 19, 'E', 'Rajshahi ', '拉傑沙希', '拉杰沙希', 24.7105776, 88.9413865),
(353, 19, 'F', 'Rangpur ', '朗普爾', '朗普尔', 25.8483388, 88.9413865),
(354, 19, 'G', 'Sylhet ', '錫爾赫特', '锡尔赫特', 24.7049811, 91.6760691),
(355, 20, '01', 'Christ Church', '基督教堂', '基督教堂', 13.0852899, -59.6239014),
(356, 20, '02', 'Saint Andrew', '聖安德魯', '圣安德鲁', 13.2494607, -59.6126957),
(357, 20, '03', 'Saint George', '聖喬治', '圣乔治', 13.1403863, -59.5854677),
(358, 20, '04', 'Saint James', '聖雅各', '圣詹姆斯', 13.1879348, -59.6622402),
(359, 20, '05', 'Saint John', '聖約翰', '圣约翰', 13.1741118, -59.5404507),
(360, 20, '06', 'Saint Joseph', '聖若瑟', '圣约瑟夫', 13.2021912, -59.5838577),
(361, 20, '07', 'Saint Lucy', '聖露西', '圣露西', 13.3045828, -59.6536618),
(362, 20, '08', 'Saint Michael', '聖邁克爾', '圣迈克尔', 13.1184767, -59.6434902),
(363, 20, '09', 'Saint Peter', '聖彼得', '圣彼得', 13.2622709, -59.6511343),
(364, 20, '10', 'Saint Philip', '聖菲利普', '圣菲利普', 13.1309523, -59.5071467),
(365, 20, '11', 'Saint Thomas', '聖托馬斯', '圣托马斯', 18.3380965, -64.8940946),
(366, 21, 'BR', 'Brest', '布列斯特', '布列斯特', 52.5296641, 25.4606480),
(367, 21, 'HO', 'Gomel', '戈梅利', '戈梅利', 52.1648754, 29.1333251),
(368, 21, 'HR', 'Grodno', '格羅德諾', '格罗德诺', 53.6599945, 25.3448571),
(369, 21, 'MI', 'Minsk', '明斯克', '明斯克', 54.1067889, 27.4129245),
(370, 21, 'HM', 'Minsk', '明斯克', '明斯克', 53.9006011, 27.5589720),
(371, 21, 'MA', 'Mogilev', '莫吉廖夫', '莫吉廖夫', 53.5101791, 30.4006444),
(372, 21, 'VI', 'Vitebsk', '維捷布斯克', '维捷布斯克', 55.2959833, 28.7583627),
(373, 22, 'VAN', 'Antwerp', '安特衛普', '安特卫普', 51.2194475, 4.4024643),
(374, 22, 'BRU', 'Brussels-Capital ', '布魯塞爾首都', '布鲁塞尔-首都', 50.8503463, 4.3517211),
(375, 22, 'VOV', 'East Flanders', '東佛蘭德斯', '东佛兰德斯', 51.0362101, 3.7373124),
(376, 22, 'VLG', 'Flanders', '佛蘭德斯', '佛兰德斯', 51.0108706, 3.7264613),
(377, 22, 'VBR', 'Flemish Brabant', '佛蘭德布拉班特', '佛兰德布拉班特', 50.8815434, 4.5645970),
(378, 22, 'WHT', 'Hainaut', '埃諾', '埃诺', 50.5257076, 4.0621017),
(379, 22, 'WLG', 'Liège', '塞', '软木', 50.6325574, 5.5796662),
(380, 22, 'VLI', 'Limburg', '林堡', '林堡', 50.9959462, 4.7862645),
(381, 22, 'WLX', 'Luxembourg', '盧森堡', '卢森堡', 49.9650000, 5.5010000),
(382, 22, 'WNA', 'Namur', '那慕爾', '那慕尔', 50.4673883, 4.8719854),
(383, 22, 'WAL', 'Wallonia', '瓦隆', '瓦隆', 50.4175637, 4.4510066),
(384, 22, 'WBR', 'Walloon Brabant', '瓦隆布拉班特', '瓦隆布拉班特', 50.6332410, 4.5243150),
(385, 22, 'VWV', 'West Flanders', '西佛蘭德斯', '西佛兰德斯', 51.0404747, 2.9994213),
(386, 23, 'BZ', 'Belize', '貝里斯', '伯利兹', 17.5677679, -88.4016041),
(387, 23, 'CY', 'Cayo', '繭', '老茧', 17.0984445, -88.9413865),
(388, 23, 'CZL', 'Corozal', '科羅薩爾', '科罗扎尔', 18.1349238, -88.2461183),
(389, 23, 'OW', 'Orange Walk', '奧蘭治步道', '橙色步行', 17.7603530, -88.8646980),
(390, 23, 'SC', 'Stann Creek', '斯坦恩溪', '斯坦溪', 16.8116631, -88.4016041),
(391, 23, 'TOL', 'Toledo', '托萊多', '托莱多', 16.2491923, -88.8646980),
(392, 24, 'AL', 'Alibori', '阿里博里', '阿里博里', 10.9681093, 2.7779813),
(393, 24, 'AK', 'Atakora', '阿塔科拉', '阿塔科拉', 10.7954931, 1.6760691),
(394, 24, 'AQ', 'Atlantique', '大西洋', '大西洋', 6.6588391, 2.2236667),
(395, 24, 'BO', 'Borgou', '博爾古', '博尔古', 9.5340864, 2.7779813),
(396, 24, 'CO', 'Collines', '山丘', '山', 8.3022297, 2.3024460),
(397, 24, 'DO', 'Donga', '東阿', '东阿', 9.7191867, 1.6760691),
(398, 24, 'KO', 'Kouffo', '庫福', '库福', 7.0035894, 1.7538817),
(399, 24, 'LI', 'Littoral', '沿海', '滨海', 6.3806973, 2.4406387),
(400, 24, 'MO', 'Mono', '單聲道', '单', 37.9218608, -118.9528645),
(401, 24, 'OU', 'Ouémé', '韋梅', 'Ouémé', 6.6148152, 2.4999918),
(402, 24, 'PL', 'Plateau', '塝', '高原', 7.3445141, 2.5396030),
(403, 24, 'ZO', 'Zou', '會', '愿意', 7.3469268, 2.0665197),
(404, 25, 'DEV', 'Devonshire', '德文郡', '德文 郡', 32.3038062, -64.7606954),
(405, 25, 'HA', 'Hamilton', '漢密爾頓', '哈密尔顿', 32.3449432, -64.7236500),
(406, 25, 'PAG', 'Paget', '佩吉特', '佩吉特', 32.2810740, -64.7784787),
(407, 25, 'PEM', 'Pembroke', '彭布羅克', '彭布罗克', 32.3007672, -64.7962630),
(408, 25, 'SGE', 'Saint George\'s', '聖喬治', '圣乔治', 17.1257759, -62.5619811),
(409, 25, 'SAN', 'Sandys', '桑迪斯', '桑迪斯', 32.2999528, -64.8674103),
(410, 25, 'SMI', 'Smith\'s', '鐵匠', '史密斯', 32.3133966, -64.7310588),
(411, 25, 'SOU', 'Southampton', '南安普敦', '南安普敦', 32.2540095, -64.8259058),
(412, 25, 'WAR', 'Warwick', '沃里克', '华 威', 32.2661534, -64.8081198),
(413, 26, '33', 'Bumthang ', '布姆唐', '布姆唐', 27.6418390, 90.6773046),
(414, 26, '12', 'Chukha ', '楚卡', '楚卡', 27.0784304, 89.4742177),
(415, 26, '22', 'Dagana ', '日', '日', 27.0322861, 89.8879304),
(416, 26, 'GA', 'Gasa ', '加薩', '加沙', 28.0185886, 89.9253233),
(417, 26, '13', 'Haa ', '哈', '哈', 27.2651669, 89.1705998),
(418, 26, '44', 'Lhuntse ', '倫茨', '伦策', 27.8264989, 91.1353020),
(419, 26, '42', 'Mongar ', '蒙加爾', '蒙加尔', 27.2617059, 91.2891036),
(420, 26, '11', 'Paro ', '失業', '失业', 27.4285949, 89.4166516),
(421, 26, '43', 'Pemagatshel ', '佩馬加謝爾', '佩马加特谢尔', 27.0023820, 91.3469247),
(422, 26, '23', 'Punakha ', '普那卡', '普那卡', 27.6903716, 89.8879304),
(423, 26, '45', 'Samdrup Jongkhar ', '薩姆德魯普·瓊卡爾', '萨姆德鲁普·琼卡尔', 26.8035682, 91.5039207),
(424, 26, '14', 'Samtse ', '天鵝絨', '丝绒', 27.0291832, 89.0561532),
(425, 26, '31', 'Sarpang ', '沙邦', '沙邦', 26.9373041, 90.4879916),
(426, 26, '15', 'Thimphu ', '廷布', '廷布', 27.4712216, 89.6339041),
(427, 26, 'TY', 'Trashi Yangtse	', '特拉什揚子', '特拉什扬子', 27.7175850, 91.1981102),
(428, 26, '41', 'Trashigang ', '特拉西岡', '特拉西冈', 27.2566795, 91.7538817),
(429, 26, '32', 'Trongsa ', '特龍薩', '特龙萨', 27.5002269, 90.5080634),
(430, 26, '21', 'Tsirang ', '齊朗', '齐朗', 27.0322070, 90.1869644),
(431, 26, '24', 'Wangdue Phodrang ', '旺杜·福德朗', '旺杜·福德朗', 27.4526046, 90.0674928),
(432, 26, '34', 'Zhemgang ', '哲港', '哲岗', 27.0769750, 90.8294002),
(433, 27, 'B', 'Beni', '我', '我', -14.3782747, -65.0957792),
(434, 27, 'H', 'Chuquisaca', '丘基薩卡', '丘基萨卡', -20.0249144, -64.1478236),
(435, 27, 'C', 'Cochabamba', '科恰班巴', '科恰班巴', -17.5681675, -65.4757360),
(436, 27, 'L', 'La Paz', '拉巴斯', '拉巴斯', -14.9315782, -70.8299967),
(437, 27, 'O', 'Oruro', '奧魯羅', '奥鲁罗', -18.5711579, -67.7615983),
(438, 27, 'N', 'Pando', '曲', '歪', -10.7988901, -66.9988011),
(439, 27, 'P', 'Potosí', '波托西', '波托西', -20.6247130, -66.9988011),
(440, 27, 'S', 'Santa Cruz', '聖克魯斯', '圣克鲁斯', -16.7476037, -62.0750998),
(441, 27, 'T', 'Tarija', '塔里亞', '塔里亚', -21.5831595, -63.9586111),
(442, 155, 'BQ1', 'Bonaire', '博內爾島', '博内尔岛', 12.2018902, -68.2623822),
(443, 155, 'BQ2', 'Saba', '薩巴', '萨巴', 17.6354642, -63.2326763),
(444, 155, 'BQ3', 'Sint Eustatius', '聖尤斯特歇斯', '圣尤斯特歇斯', 17.4890306, -62.9735550),
(445, 28, '05', 'Bosnian Podrinje', '波斯尼亞波德林傑', '波斯尼亚波德林涅', 43.6874900, 18.8244394),
(446, 28, 'BRC', 'Brčko', '布爾奇科', '布尔奇科', 44.8405944, 18.7421530),
(447, 28, '10', 'Canton 10', '鄉鎮 10', '乡镇 10', 43.9534155, 16.9425187),
(448, 28, '06', 'Central Bosnia', '波斯尼亞中部', '波斯尼亚中部', 44.1381856, 17.6866714),
(449, 28, 'BIH', 'Federation of Bosnia and Herzegovina', '波斯尼亞和黑塞哥維那聯邦', '波斯尼亚和黑塞哥维那联邦', 43.8874897, 17.8427930),
(450, 28, '07', 'Herzegovina-Neretva', '黑塞哥維那-內雷特瓦', '黑塞哥维那-内雷特瓦', 43.5265159, 17.7636210),
(451, 28, '02', 'Posavina', '波薩維納', '波萨维纳', 45.0752094, 18.3776304),
(452, 28, 'SRP', 'Republika Srpska', '塞族共和國', '塞族共和国', 44.7280186, 17.3148136),
(453, 28, '09', 'Sarajevo', '薩拉熱窩', '萨拉热窝', 43.8512564, 18.2953442),
(454, 28, '03', 'Tuzla', '圖茲拉', '图兹拉', 44.5343463, 18.6972797),
(455, 28, '01', 'Una-Sana', '健康一體', '健康', 44.6503116, 16.3171629),
(456, 28, '08', 'West Herzegovina', '西黑塞哥維那', '西黑塞哥维那', 43.4369244, 17.3848831),
(457, 28, '04', 'Zenica-Doboj', '澤尼察-多博伊', '泽尼察-多博伊', 44.2127109, 18.1604625),
(458, 29, 'CE', 'Central', '中', '中央', -21.4603716, 23.9886542),
(459, 29, 'GH', 'Ghanzi', '甘茲', '甘子', -21.8652314, 21.8568586),
(460, 29, 'KG', 'Kgalagadi', '卡拉加迪', '卡拉加迪', -24.7550285, 21.8568586),
(461, 29, 'KL', 'Kgatleng', '加特倫', '加特伦', -24.1970445, 26.2304616),
(462, 29, 'KW', 'Kweneng', '克韋能', '克韦能', -23.8367249, 25.2837585),
(463, 29, 'NG', 'Ngamiland', '恩加米蘭', '恩加米兰', -19.1905321, 23.0011989),
(464, 29, 'NE', 'North-East', '東北', '东北', 37.5884461, -94.6863782),
(465, 29, 'NW', 'North-West', '西北', '西北', -19.4836226, 20.4472577),
(466, 29, 'SE', 'South-East', '東南', '东南', -24.9866816, 25.5290857),
(467, 29, 'SO', 'Southern', '南方的', '南部', -24.9096262, 23.0541976),
(468, 31, 'AC', 'Acre', '英畝', '英亩', -9.0237960, -70.8119950),
(469, 31, 'AL', 'Alagoas', '阿拉戈斯', '阿拉戈斯', -9.5713058, -36.7819505),
(470, 31, 'AP', 'Amapá', '阿馬帕', '阿马帕', 0.9019925, -52.0029565),
(471, 31, 'AM', 'Amazonas', '亞馬遜河', '亚马逊河', -3.0700000, -61.6600000),
(472, 31, 'BA', 'Bahia', '巴伊亞州', '巴伊亚', -11.4098740, -41.2808570),
(473, 31, 'CE', 'Ceará', '塞阿拉州', '塞阿拉州', -5.4983977, -39.3206241),
(474, 31, 'DF', 'Distrito Federal', '聯邦區', '联邦区', -15.7997654, -47.8644715),
(475, 31, 'ES', 'Espírito Santo', '聖埃斯皮里圖', '圣埃斯皮里图', -19.1834229, -40.3088626),
(476, 31, 'GO', 'Goiás', '戈亞斯', '戈亚斯', -15.8270369, -49.8362237),
(477, 31, 'MA', 'Maranhão', '馬拉尼昂', '马拉尼昂', -4.9609498, -45.2744159),
(478, 31, 'MT', 'Mato Grosso', '馬托格羅索州', '马托格罗索州', -12.6818712, -56.9210990),
(479, 31, 'MS', 'Mato Grosso do Sul', '南馬托格羅索州', '南马托格罗索州', -20.7722295, -54.7851531),
(480, 31, 'MG', 'Minas Gerais', '米納斯吉拉斯州', '米纳斯吉拉斯州', -18.5121780, -44.5550308),
(481, 31, 'PA', 'Pará', '停止', '停', -1.9981271, -54.9306152),
(482, 31, 'PB', 'Paraíba', '帕拉伊巴', '帕拉伊巴', -7.2399609, -36.7819505),
(483, 31, 'PR', 'Paraná', '巴拉那州', '巴拉那州', -25.2520888, -52.0215415),
(484, 31, 'PE', 'Pernambuco', '伯南布哥州', '伯南布哥州', -8.8137173, -36.9541070),
(485, 31, 'PI', 'Piauí', '皮奧伊', '皮奥伊', -7.7183401, -42.7289236),
(486, 31, 'RJ', 'Rio de Janeiro', '里約熱內盧', '里约热内卢', -22.9068467, -43.1728965),
(487, 31, 'RN', 'Rio Grande do Norte', '北里奧格蘭德州', '北里奥格兰德州', -5.4025803, -36.9541070),
(488, 31, 'RS', 'Rio Grande do Sul', '南里奧格蘭德州', '南里奥格兰德州', -30.0346316, -51.2176986),
(489, 31, 'RO', 'Rondônia', '朗多尼亞', '朗多尼亚', -11.5057341, -63.5806110),
(490, 31, 'RR', 'Roraima', '羅賴馬', '罗赖马', 2.7375971, -62.0750998),
(491, 31, 'SC', 'Santa Catarina', '聖卡塔琳娜州', '圣卡塔琳娜州', -27.3300000, -49.4400000),
(492, 31, 'SP', 'São Paulo', '聖保羅', '圣保罗', -23.5505199, -46.6333094),
(493, 31, 'SE', 'Sergipe', '塞爾希培', '塞尔希培州', -10.5740934, -37.3856581),
(494, 31, 'TO', 'Tocantins', '托坎廷斯', '托坎廷斯', -10.1752800, -48.2982474),
(495, 33, 'BE', 'Belait', '貝萊特', '贝莱特', 4.3750749, 114.6192899),
(496, 33, 'BM', 'Brunei-Muara', '汶萊-穆拉', '文莱-穆拉', 4.9311206, 114.9516869),
(497, 33, 'TE', 'Temburong', '騰布隆', '腾布隆', 4.6204128, 115.1414840),
(498, 33, 'TU', 'Tutong', '土通', '图通', 4.7140373, 114.6667939),
(499, 34, '01', 'Blagoevgrad', '布拉戈耶夫格勒', '布拉戈耶夫格勒', 42.0208614, 23.0943356),
(500, 34, '02', 'Burgas', '布爾加斯', '布尔加斯', 42.5048000, 27.4626079),
(501, 34, '08', 'Dobrich', '多布里奇', '多布里奇', 43.5727860, 27.8272802),
(502, 34, '07', 'Gabrovo', '加布羅沃', '加布罗沃', 42.8684700, 25.3168890),
(503, 34, '26', 'Haskovo', '哈斯科沃', '哈斯科沃', 41.9344178, 25.5554672),
(504, 34, '09', 'Kardzhali', '卡爾扎利', '卡扎利', 41.6338416, 25.3776687),
(505, 34, '10', 'Kyustendil', '庫斯滕迪爾', '库斯滕迪尔', 42.2868799, 22.6939635),
(506, 34, '11', 'Lovech', '洛維奇', '洛维奇', 43.1367798, 24.7139335),
(507, 34, '12', 'Montana', '蒙大拿州', '蒙大拿州', 43.4085148, 23.2257589),
(508, 34, '13', 'Pazardzhik', '帕扎爾日克', '帕扎尔日克', 42.1927567, 24.3336226),
(509, 34, '14', 'Pernik', '佩爾尼克', '佩尔尼克', 42.6051990, 23.0377916),
(510, 34, '15', 'Pleven', '普萊文', '普莱文', 43.4170169, 24.6066708),
(511, 34, '16', 'Plovdiv', '普羅夫迪夫', '普罗夫迪夫', 42.1354079, 24.7452904),
(512, 34, '17', 'Razgrad', '拉茲格勒', '拉兹格勒', 43.5271705, 26.5241228),
(513, 34, '18', 'Ruse', '詭計', '诡计', 43.8355964, 25.9656144),
(514, 34, '27', 'Shumen', '蜀門', '舒门', 43.2712398, 26.9361286),
(515, 34, '19', 'Silistra', '西利斯特拉', '西利斯特拉', 44.1147101, 27.2671454),
(516, 34, '20', 'Sliven', '斯利文', '斯利文', 42.6816702, 26.3228569),
(517, 34, '21', 'Smolyan', '斯莫利安', '斯莫利安', 41.5774148, 24.7010871),
(518, 34, '23', 'Sofia', '索非亞', '索菲亚', 42.6734400, 23.8334937),
(519, 34, '22', 'Sofia City', '索非亞市', '索非亚市', 42.7570109, 23.4504683),
(520, 34, '24', 'Stara Zagora', '斯塔拉·扎戈拉', '斯塔拉·扎戈拉', 42.4257709, 25.6344855),
(521, 34, '25', 'Targovishte', '塔爾戈維什特', '塔尔戈维什特', 43.2462349, 26.5691251),
(522, 34, '03', 'Varna', '誡', '警告', 43.2046477, 27.9105488),
(523, 34, '04', 'Veliko Tarnovo', '大特爾諾沃', '大特尔诺沃', 43.0756539, 25.6171500),
(524, 34, '05', 'Vidin', '維丁', '维丁', 43.9961739, 22.8679515),
(525, 34, '06', 'Vratsa', '弗拉察', '弗拉察', 43.2101806, 23.5529210),
(526, 34, '28', 'Yambol', '揚博爾', '扬博尔', 42.4841494, 26.5035296),
(527, 35, 'BAL', 'Balé', '芭蕾舞', '芭蕾舞', 11.7820602, -3.0175712),
(528, 35, 'BAM', 'Bam', '砰', '砰', 13.4461330, -1.5983959),
(529, 35, 'BAN', 'Banwa', '班瓦', '班瓦', 12.1323053, -4.1513764),
(530, 35, 'BAZ', 'Bazèga', '巴澤加', '巴泽加', 11.9767692, -1.4434690),
(531, 35, '01', 'Boucle du Mouhoun', '穆霍恩布克爾', '布克尔杜穆霍恩', 12.4166000, -3.4195527),
(532, 35, 'BGR', 'Bougouriba', '布古里巴', '布古里巴', 10.8722646, -3.3388917),
(533, 35, 'BLG', 'Boulgou', '布爾溝', '布尔沟', 11.4336766, -0.3748354),
(534, 35, 'BLK', 'Boulkiemde', '布爾基姆德', '布尔基姆德', 12.3224419, -2.4738052),
(535, 35, '02', 'Cascades', '級聯', '叶 栅', 10.4072992, -4.5624426),
(536, 35, '03', 'Centre', '中央', '中心', 12.3393720, -1.7796974),
(537, 35, '04', 'Centre-Est', '中東', '中东', 11.5247674, -0.1494988),
(538, 35, '05', 'Centre-Nord', '中北部', '中北部', 13.1724464, -0.9056623),
(539, 35, '06', 'Centre-Ouest', '中西部', '中西部', 11.8798466, -2.3024460),
(540, 35, '07', 'Centre-Sud', '中南部', '中南部', 11.5228911, -1.0586135),
(541, 35, 'COM', 'Comoé', '科摩埃', '科摩埃', 10.4072992, -4.5624426),
(542, 35, '08', 'Est', '東', '东', 12.4365526, 0.9056623),
(543, 35, 'GAN', 'Ganzourgou', '甘祖爾溝', '甘祖尔沟', 12.2537648, -0.7532809),
(544, 35, 'GNA', 'Gnagna', '格納納', '格纳尼亚', 12.8974992, 0.0746767),
(545, 35, 'GOU', 'Gourma', '古爾瑪', '古尔玛', 12.1624473, 0.6773046),
(546, 35, '09', 'Hauts-Bassins', '高級貝斯', '高级贝斯', 11.4942003, -4.2333355),
(547, 35, 'HOU', 'Houet', '胡埃特', '胡埃', 11.1320447, -4.2333355),
(548, 35, 'IOB', 'Ioba', '伊奧巴', '伊奥巴', 11.0562034, -3.0175712),
(549, 35, 'KAD', 'Kadiogo', '卡迪奧戈', '卡迪奥戈', 12.3425897, -1.4434690),
(550, 35, 'KEN', 'Kénédougou', '凱內杜古', '凯内杜古', 11.3919395, -4.9766540),
(551, 35, 'KMD', 'Komondjari', '小亞里', '小亚里', 12.7126527, 0.6773046),
(552, 35, 'KMP', 'Kompienga', '結論', 'Kompienga', 11.5238362, 0.7532809),
(553, 35, 'KOS', 'Kossi', '科西', '科西', 12.9604580, -3.9062688),
(554, 35, 'KOP', 'Koulpélogo', '庫爾佩洛戈', '库尔佩洛戈', 11.5247674, 0.1494988),
(555, 35, 'KOT', 'Kouritenga', '庫里騰加', '库里滕加', 12.1631813, -0.2244662),
(556, 35, 'KOW', 'Kourwéogo', '庫爾韋戈', '库尔韦奥戈', 12.7077495, -1.7538817),
(557, 35, 'LER', 'Léraba', '萊拉巴', '莱拉巴', 10.6648785, -5.3102505),
(558, 35, 'LOR', 'Loroum', '洛魯姆', '洛鲁姆', 13.8129814, -2.0665197),
(559, 35, 'MOU', 'Mouhoun', '穆霍恩', '牟勋', 12.1432381, -3.3388917),
(560, 35, 'NAO', 'Nahouri', '那霍里', '那胡里', 11.2502267, -1.1353020),
(561, 35, 'NAM', 'Namentenga', '納門滕加', '纳门滕加', 13.0812584, -0.5257823),
(562, 35, 'NAY', 'Nayala', '納亞拉', '纳亚拉', 12.6964558, -3.0175712),
(563, 35, '10', 'Nord', '北', '北', 13.7182520, -2.3024460),
(564, 35, 'NOU', 'Noumbiel', '努姆比爾', '努姆比尔', 9.8440946, -2.9775558),
(565, 35, 'OUB', 'Oubritenga', '烏布里滕加', '乌布里滕加', 12.7096087, -1.4434690),
(566, 35, 'OUD', 'Oudalan', '歐達蘭', '欧达兰', 14.4719020, -0.4502368),
(567, 35, 'PAS', 'Passoré', '帕索雷', '帕索雷', 12.8881221, -2.2236667),
(568, 35, '11', 'Plateau-Central', '中央高原', '中央高原', 12.2537648, -0.7532809),
(569, 35, 'PON', 'Poni', '小馬', '矮种马', 10.3325996, -3.3388917),
(570, 35, '12', 'Sahel', '薩赫勒', '萨赫勒', 14.1000865, -0.1494988),
(571, 35, 'SNG', 'Sanguié', 'Sanguié', 'Sanguié', 12.1501861, -2.6983868),
(572, 35, 'SMT', 'Sanmatenga', '桑馬滕加', '桑马腾加', 13.3565304, -1.0586135),
(573, 35, 'SEN', 'Séno', '瀨野', '濑野', 14.0072234, -0.0746767),
(574, 35, 'SIS', 'Sissili', '西西里', '西西里语', 11.2441219, -2.2236667),
(575, 35, 'SOM', 'Soum', '蘇姆', '苏姆', 14.0962841, -1.3662160),
(576, 35, 'SOR', 'Sourou', '蘇魯', '苏柔', 13.3418030, -2.9375739),
(577, 35, '13', 'Sud-Ouest', '西南', '西南', 10.4231493, -3.2583626),
(578, 35, 'TAP', 'Tapoa', '塔波亞', '塔波亚', 12.2497072, 1.6760691),
(579, 35, 'TUI', 'Tuy', '雖', '虽然', 38.8886840, -77.0047190),
(580, 35, 'YAG', 'Yagha', '亞加', '亚加', 13.3576157, 0.7532809),
(581, 35, 'YAT', 'Yatenga', '亞騰加', '亚腾加', 13.6249344, -2.3813621),
(582, 35, 'ZIR', 'Ziro', '齊羅', '齐罗', 11.6094995, -1.9099238),
(583, 35, 'ZON', 'Zondoma', '宗多馬', '宗多马', 13.1165926, -2.4208713),
(584, 35, 'ZOU', 'Zoundwéogo', 'Zoundwéogo', 'Zoundwéogo', 11.6141174, -0.9820668),
(585, 36, 'BB', 'Bubanza', '布班扎', '布班扎', -3.1572403, 29.3714909),
(586, 36, 'BM', 'Bujumbura Mairie', '布瓊布拉·邁里', '布琼布拉·迈里', -3.3884141, 29.3482646),
(587, 36, 'BL', 'Bujumbura Rural', '布瓊布拉鄉村', '布琼布拉乡村', -3.5090144, 29.4643590),
(588, 36, 'BR', 'Bururi', '布魯里', '布鲁里', -3.9006851, 29.5107708),
(589, 36, 'CA', 'Cankuzo', '坎庫佐', '坎库佐', -3.1527788, 30.6199895),
(590, 36, 'CI', 'Cibitoke', '蘇格蘭。', '苏格兰。', -2.8102897, 29.1855785),
(591, 36, 'GI', 'Gitega', '吉特加', '吉特加', -3.4929051, 29.9277947),
(592, 36, 'KR', 'Karuzi', '輪播', '轮播', -3.1340347, 30.1127350),
(593, 36, 'KY', 'Kayanza', '卡揚扎', '卡扬扎', -3.0077981, 29.6499162),
(594, 36, 'KI', 'Kirundo', '基倫多', '基伦多', -2.5762882, 30.1127350),
(595, 36, 'MA', 'Makamba', '馬坎巴', '马坎巴', -4.3257062, 29.6962677),
(596, 36, 'MU', 'Muramvya', '穆拉姆維亞', '穆拉姆维亚', -3.2898398, 29.6499162),
(597, 36, 'MY', 'Muyinga', '穆因加', '穆因加', -2.7793511, 30.2974199),
(598, 36, 'MW', 'Mwaro', '姆瓦羅', '姆瓦罗', -3.5025918, 29.6499162),
(599, 36, 'NG', 'Ngozi', '皮', '皮肤', -2.8958243, 29.8815203),
(600, 36, 'RM', 'Rumonge', '魯蒙格', '鲁蒙格', -3.9754049, 29.4388014),
(601, 36, 'RT', 'Rutana', '魯塔納', '鲁塔纳', -3.8791523, 30.0665236),
(602, 36, 'RY', 'Ruyigi', '如懿吉', '如意吉', -3.4462070, 30.2512728),
(603, 37, '1', 'Banteay Meanchey', '班迭棉芷', '班迭棉芷', 13.7531914, 102.9896150),
(604, 37, '2', 'Battambang', '馬德望', '马德望', 13.0286971, 102.9896150),
(605, 37, '3', 'Kampong Cham', '磅湛', '磅湛', 12.0982918, 105.3131185),
(606, 37, '4', 'Kampong Chhnang', '磅清南', '磅清南', 12.1392352, 104.5655273),
(607, 37, '5', 'Kampong Speu', '磅士卑島', '磅士卑岛', 11.6155109, 104.3791912),
(608, 37, '6', 'Kampong Thom', '甘榜襪', '甘榜袜', 12.8167485, 103.8413104),
(609, 37, '7', 'Kampot', '貢布', '贡布', 10.7325351, 104.3791912),
(610, 37, '8', 'Kandal', '坎達爾', '坎达尔', 11.2237383, 105.1258955),
(611, 37, '23', 'Kep', '白馬', '白马', 10.5360890, 104.3559158),
(612, 37, '9', 'Koh Kong', '戈公島', '戈公岛', 11.5762804, 103.3587288),
(613, 37, '10', 'Kratie', '桔井', '桔井', 12.5043608, 105.9699878),
(614, 37, '11', 'Mondulkiri', '蒙多基里', '蒙多基里', 12.7879427, 107.1011931),
(615, 37, '22', 'Oddar Meanchey', '奧達棉芷', '奥达棉芷', 14.1609738, 103.8216261),
(616, 37, '24', 'Pailin', '派林', '派林', 12.9092962, 102.6675575),
(617, 37, '12', 'Phnom Penh', '金邊', '金边', 11.5563738, 104.9282099),
(618, 37, '13', 'Preah Vihear', '柏威夏', '柏威夏', 14.0085797, 104.8454619),
(619, 37, '14', 'Prey Veng', '普雷文', '普雷·文', 11.3802442, 105.5005483),
(620, 37, '15', 'Pursat', '馬薩特', '珀萨特', 12.2720956, 103.7289167),
(621, 37, '16', 'Ratanakiri', '拉塔納切', '拉塔纳基里', 13.8576607, 107.1011931),
(622, 37, '17', 'Siem Reap', '暹粒', '暹粒', 13.3302660, 104.1001326),
(623, 37, '18', 'Sihanoukville', '西哈努克城', '西哈努克城', 10.7581899, 103.8216261),
(624, 37, '19', 'Stung Treng', 'Stung Treng', 'Stung Treng', 13.5764730, 105.9699878),
(625, 37, '20', 'Svay Rieng', '柴桢', '柴桢', 11.1427220, 105.8290298),
(626, 37, '21', 'Takeo', '武雄', '武雄', 10.9321519, 104.7987710),
(627, 38, 'AD', 'Adamawa', '阿達馬瓦', '阿达马瓦', 9.3264751, 12.3983853),
(628, 38, 'CE', 'Centre', '中央', '中心', 4.6826898, 10.4186101),
(629, 38, 'ES', 'East', '東', '东', 3.8883737, 11.7024964),
(630, 38, 'EN', 'Far North', '遠北地區', '远北', 11.5073543, 13.2306919),
(631, 38, 'LT', 'Littoral', '沿海', '滨海', 4.2944968, 8.8873658),
(632, 38, 'NO', 'North', '北', '北', 8.6280563, 11.2723239),
(633, 38, 'NW', 'Northwest', '西北', '西北', 6.4330598, 9.7409925),
(634, 38, 'SU', 'South', '南', '南', 2.9231493, 9.1068999),
(635, 38, 'SW', 'Southwest', '西南', '西南', 5.2178966, 7.9807247),
(636, 38, 'OU', 'West', '西', '西', 5.5353300, 9.9140012),
(637, 39, 'AB', 'Alberta', '艾伯塔省', '艾伯塔省', 53.9332706, -116.5765035),
(638, 39, 'BC', 'British Columbia', '不列顛哥倫比亞省', '不列颠哥伦比亚省', 53.7266683, -127.6476205),
(639, 39, 'MB', 'Manitoba', '曼尼托巴省', '马尼托巴省', 53.7608608, -98.8138762),
(640, 39, 'NB', 'New Brunswick', '新不倫瑞克省', '新不伦瑞克省', 46.5653163, -66.4619164),
(641, 39, 'NL', 'Newfoundland and Labrador', '紐芬蘭和拉布拉多', '纽芬兰和拉布拉多', 53.1355091, -57.6604364),
(642, 39, 'NT', 'Northwest Territories', '西北地區', '西北地区', 64.8255441, -124.8457334),
(643, 39, 'NS', 'Nova Scotia', '新斯科舍省', '新斯科舍省', 44.6819866, -63.7443110),
(644, 39, 'NU', 'Nunavut', '努納武特', '努纳武特', 70.2997711, -83.1075770),
(645, 39, 'ON', 'Ontario', '安大略省', '安大略省', 51.2537750, -85.3232140),
(646, 39, 'PE', 'Prince Edward Island', '愛德華王子島', '爱德华王子岛', 46.5107120, -63.4168136),
(647, 39, 'QC', 'Quebec', '魁北克省', '魁北克', 52.9399159, -73.5491361),
(648, 39, 'SK', 'Saskatchewan', '薩斯喀徹溫省', '萨斯喀彻温省', 52.9399159, -106.4508639),
(649, 39, 'YT', 'Yukon', '育空地區', '育 空', 35.5067215, -97.7625441),
(650, 40, 'B', 'Barlavento Islands', '巴拉文托群島', '巴拉文托群岛', 16.8236845, -23.9934881),
(651, 40, 'BV', 'Boa Vista', '博阿維斯塔', '博阿维斯塔', 38.7434660, -120.7304297),
(652, 40, 'BR', 'Brava', '好', '好', 40.9897778, -73.6835715),
(653, 40, 'MA', 'Maio', '五月', '五月', 15.2003098, -23.1679793),
(654, 40, 'MO', 'Mosteiros', '修道院', '修道院', 37.8904348, -25.8207556),
(655, 40, 'PA', 'Paul', '保羅', '保罗', 37.0625000, -95.6770680),
(656, 40, 'PN', 'Porto Novo', '波爾圖諾伏', '波尔图诺沃', 6.4968574, 2.6288523),
(657, 40, 'PR', 'Praia', '灘', '海滩', 14.9330500, -23.5133267),
(658, 40, 'RB', 'Ribeira Brava', '里貝拉·布拉瓦', '里贝拉布拉瓦', 16.6070739, -24.2033843),
(659, 40, 'RG', 'Ribeira Grande', '里貝拉格蘭德', '里贝拉格兰德', 37.8210369, -25.5148137),
(660, 40, 'RS', 'Ribeira Grande de Santiago', '聖地亞哥里貝拉大酒店', 'Ribeira Grande de Santiago', 14.9830298, -23.6561725),
(661, 40, 'SL', 'Sal', '年', '年', 26.5958122, -80.2045083),
(662, 40, 'CA', 'Santa Catarina', '聖卡塔琳娜州', '圣卡塔琳娜州', -27.2423392, -50.2188556),
(663, 40, 'CF', 'Santa Catarina do Fogo', '聖卡塔琳娜州佛戈', '圣卡塔琳娜州福戈', 14.9309104, -24.3222577),
(664, 40, 'CR', 'Santa Cruz', '聖克魯斯', '圣克鲁斯', 36.9741171, -122.0307963),
(665, 40, 'SD', 'São Domingos', '聖多明各', '圣多明各', 15.0286165, -23.5639220),
(666, 40, 'SF', 'São Filipe', '聖菲利普', '圣菲利普', 14.8951679, -24.4945636),
(667, 40, 'SO', 'São Lourenço dos Órgãos', '管風琴的聖勞倫斯', '管风琴的圣劳伦斯', 15.0537841, -23.6085612),
(668, 40, 'SM', 'São Miguel', '聖米格爾', '圣米格尔', 37.7804110, -25.4970466),
(669, 40, 'SV', 'São Vicente', '聖文森特', '圣文森特', -23.9607157, -46.3962022),
(670, 40, 'S', 'Sotavento Islands', '索塔文托群島', '索塔文托群岛', 15.0000000, -24.0000000),
(671, 40, 'TA', 'Tarrafal', '塔拉法爾', '塔拉法尔', 15.2760578, -23.7484077),
(672, 40, 'TS', 'Tarrafal de São Nicolau', '聖尼科勞塔拉法爾', '圣尼古劳塔拉法尔', 16.5636498, -24.3549420),
(673, 41, 'NULL', 'Cayman Brac', '開曼布拉克', '开曼布拉克', 19.7199970, -79.8907266),
(674, 41, 'NULL', 'Grand Cayman', '大開曼島', '大开曼岛', 19.3301271, -81.4172451),
(675, 41, 'NULL', 'Little Cayman', '小開曼島', '小开曼岛', 19.6856739, -80.1183019),
(676, 42, 'BB', 'Bamingui-Bangoran', '巴明吉-班戈蘭', '巴明吉-班戈兰', 8.2733455, 20.7122465),
(677, 42, 'BGF', 'Bangui', '班吉', '班吉', 4.3946735, 18.5581899),
(678, 42, 'BK', 'Basse-Kotto', '巴斯-科托', '巴斯-科托', 4.8719319, 21.2845025),
(679, 42, 'HM', 'Haut-Mbomou', '上姆博穆', '上姆博穆', 6.2537134, 25.4733554),
(680, 42, 'HK', 'Haute-Kotto', '上科托', '上科托', 7.7964379, 23.3823545),
(681, 42, 'KG', 'Kémo', '科莫', '科莫', 5.8867794, 19.3783206),
(682, 42, 'LB', 'Lobaye', '洛巴耶', '洛巴耶', 4.3525981, 17.4795173),
(683, 42, 'HS', 'Mambéré-Kadéï', '曼貝雷-卡德伊', '曼贝雷-卡德伊', 4.7055653, 15.9699878),
(684, 42, 'MB', 'Mbomou', '姆博穆', '姆博穆', 5.5568370, 23.7632828),
(685, 42, 'KB', 'Nana-Grébizi', '娜娜-格雷比齊', '娜娜-格雷比齐', 7.1848607, 19.3783206),
(686, 42, 'NM', 'Nana-Mambéré', '娜娜-曼貝雷', '娜娜-曼贝雷', 5.6932135, 15.2194808),
(687, 42, 'MP', 'Ombella-M\'Poko', '翁貝拉-M', 'Ombella-M', 5.1188825, 18.4276047),
(688, 42, 'UK', 'Ouaka', '瓦卡', '瓦卡', 6.3168216, 20.7122465),
(689, 42, 'AC', 'Ouham', '歐漢姆', '欧汉姆', 7.0909110, 17.6688870),
(690, 42, 'OP', 'Ouham-Pendé', '歐漢姆-彭德', '欧汉姆-彭德', 6.4850984, 16.1580937),
(691, 42, 'SE', 'Sangha-Mbaéré', '桑加-姆巴埃雷', '僧伽-姆巴埃雷', 3.4368607, 16.3463791),
(692, 42, 'VK', 'Vakaga', '瓦卡加', '瓦卡加', 9.5113296, 22.2384017),
(693, 43, 'BG', 'Bahr el Gazel', '巴赫爾加澤爾', '巴赫尔加泽尔', 14.7702266, 16.9122510),
(694, 43, 'BA', 'Batha', '巴塔', '巴塔', 13.9371775, 18.4276047),
(695, 43, 'BO', 'Borkou', '博爾卡', '博尔卡', 17.8688845, 18.8076195),
(696, 43, 'CB', 'Chari-Baguirmi', '查里-巴吉爾米', '查里-巴吉尔米', 11.4618626, 15.2446394),
(697, 43, 'EE', 'Ennedi-Est', '恩內迪-埃斯特', '恩内迪-埃斯特', 16.3420496, 23.0011989),
(698, 43, 'EO', 'Ennedi-Ouest', '恩尼迪-韋斯特', '恩内迪-韦斯特', 18.9775630, 21.8568586),
(699, 43, 'GR', 'Guéra', '蓋拉', '格拉', 11.1219015, 18.4276047),
(700, 43, 'HL', 'Hadjer-Lamis', '哈傑爾-拉米斯', '哈杰尔-拉米斯', 12.4577273, 16.7234639),
(701, 43, 'KA', 'Kanem', '卡內姆', '卡内姆', 14.8781262, 15.4068079),
(702, 43, 'LC', 'Lac', '湖', '湖', 13.6915377, 14.1001326),
(703, 43, 'LO', 'Logone Occidental', '西洛貢', '西洛贡', 8.7596760, 15.8760040),
(704, 43, 'LR', 'Logone Oriental', '洛貢東方酒店', 'Logone Oriental', 8.3149949, 16.3463791),
(705, 43, 'MA', 'Mandoul', '曼杜爾', '曼杜尔', 8.6030910, 17.4795173),
(706, 43, 'ME', 'Mayo-Kebbi Est', '梅奧-凱比東部', '梅奥-凯比东部', 9.4046039, 14.8454619),
(707, 43, 'MO', 'Mayo-Kebbi Ouest', '梅奧-凱比西', '梅奥-凯比西', 10.4113014, 15.5943388),
(708, 43, 'MC', 'Moyen-Chari', '中查里', '中查里', 9.0639998, 18.4276047),
(709, 43, 'ND', 'N\'Djamena', 'N', 'N', 12.1348457, 15.0557415),
(710, 43, 'OD', 'Ouaddaï', '瓦達伊', '瓦达伊', 13.7484760, 20.7122465),
(711, 43, 'SA', 'Salamat', '薩拉馬特', '萨拉马特', 10.9691601, 20.7122465),
(712, 43, 'SI', 'Sila', '請', '请', 12.1307400, 21.2845025),
(713, 43, 'TA', 'Tandjilé', '坦吉萊', '坦吉莱', 9.6625729, 16.7234639),
(714, 43, 'TI', 'Tibesti', '提貝斯提', '提贝斯提', 21.3650031, 16.9122510),
(715, 43, 'WF', 'Wadi Fira', '瓦迪費拉', '瓦迪费拉', 15.0892416, 21.4752851),
(716, 44, 'AI', 'Aisén del General Carlos Ibañez del Campo', '卡洛斯·伊巴涅斯·德爾·坎波將軍的艾松', '卡洛斯·伊巴涅斯·德尔·坎波将军的艾松', -46.3783450, -72.3007623),
(717, 44, 'AN', 'Antofagasta', '安托法加斯塔', '安托法加斯塔', -23.8369104, -69.2877535),
(718, 44, 'AP', 'Arica y Parinacota', '阿里卡和帕里納科塔', '阿里卡和帕里纳科塔', -18.5940485, -69.4784541),
(719, 44, 'AT', 'Atacama', '阿塔卡馬', '阿塔卡马', -27.5660558, -70.0503140),
(720, 44, 'BI', 'Biobío', '比奧比奧', '比奥比奥', -37.4464428, -72.1416132),
(721, 44, 'CO', 'Coquimbo', '科金博', '科金博', -30.5401810, -70.8119953),
(722, 44, 'AR', 'La Araucanía', '阿勞卡尼亞', '阿劳卡尼亚', -38.9489210, -72.3311130),
(723, 44, 'LI', 'Libertador General Bernardo O\'Higgins', '解放將軍貝爾納多·奧', '解放将军贝尔纳多·奥', -34.5755374, -71.0022311),
(724, 44, 'LL', 'Los Lagos', '湖泊', '湖泊', -41.9197779, -72.1416132),
(725, 44, 'LR', 'Los Ríos', '洛斯里奧斯', '洛斯里奥斯', -40.2310217, -72.3311130),
(726, 44, 'MA', 'Magallanes y de la Antártica Chilena', '麥哲倫和智利南極洲', '麦哲伦和智利南极洲', -52.2064316, -72.1685001),
(727, 44, 'ML', 'Maule', '槌', '槌', -35.5163603, -71.5723953),
(728, 44, 'NB', 'Ñuble', '努布爾', '努布尔', -36.7225743, -71.7622481),
(729, 44, 'RM', 'Región Metropolitana de Santiago', '聖地牙哥都會區', '圣地亚哥都会区', -33.4375545, -70.6504896),
(730, 44, 'TA', 'Tarapacá', '塔拉帕卡', '塔拉帕卡', -20.2028799, -69.2877535),
(731, 44, 'VS', 'Valparaíso', '瓦爾帕萊索', '瓦尔帕莱索', -33.0472380, -71.6126885),
(732, 45, 'AH', 'Anhui', '安徽', '安徽', 30.6006773, 117.9249002),
(733, 45, 'BJ', 'Beijing', '北京', '北京', 39.9041999, 116.4073963),
(734, 45, 'CQ', 'Chongqing', '重慶', '重庆', 29.4315861, 106.9122510),
(735, 45, 'FJ', 'Fujian', '福建', '福建', 26.4836842, 117.9249002),
(736, 45, 'GS', 'Gansu', '甘肅', '甘肃', 35.7518326, 104.2861116),
(737, 45, 'GD', 'Guangdong', '廣東', '广东', 23.3790333, 113.7632828),
(738, 45, 'GX', 'Guangxi Zhuang', '廣西壯', '广西壮', 23.7247599, 108.8076195),
(739, 45, 'GZ', 'Guizhou', '貴州', '贵州', 26.8429645, 107.2902839),
(740, 45, 'HI', 'Hainan', '海南', '海南', 19.5663947, 109.9496860),
(741, 45, 'HE', 'Hebei', '河北', '河北', 37.8956594, 114.9042208),
(742, 45, 'HL', 'Heilongjiang', '黑龍江', '黑龙江', 47.1216472, 128.7382310),
(743, 45, 'HA', 'Henan', '河南', '河南', 34.2904302, 113.3823545),
(744, 45, 'HK', 'Hong Kong SAR', '香港特別行政區', '香港特别行政区', 22.3193039, 114.1693611);
INSERT INTO `location_states` (`state_id`, `country_id`, `state_code`, `state_name_en`, `state_name_zh_tw`, `state_name_zh_cn`, `state_center_latitude`, `state_center_longitude`) VALUES
(745, 45, 'HB', 'Hubei', '湖北', '湖北', 30.7378118, 112.2384017),
(746, 45, 'HN', 'Hunan', '湖南', '湖南', 27.3683009, 109.2819347),
(747, 45, 'NM', 'Inner Mongolia', '內蒙古', '内蒙古', 43.3782200, 115.0594815),
(748, 45, 'JS', 'Jiangsu', '江蘇', '江苏', 33.1401715, 119.7889248),
(749, 45, 'JX', 'Jiangxi', '江西', '江西', 27.0874564, 114.9042208),
(750, 45, 'JL', 'Jilin', '吉林', '吉林', 43.8378830, 126.5495720),
(751, 45, 'LN', 'Liaoning', '遼寧', '辽宁', 41.9436543, 122.5290376),
(752, 45, 'MO', 'Macau SAR', '澳門特別行政區', '澳门特别行政区', 22.1987450, 113.5438730),
(753, 45, 'NX', 'Ningxia Huizu', '寧夏匯祖', '宁夏汇祖', 37.1987310, 106.1580937),
(754, 45, 'QH', 'Qinghai', '青海', '青海', 35.7447980, 96.4077358),
(755, 45, 'SN', 'Shaanxi', '陝西', '陕西', 35.3939908, 109.1880047),
(756, 45, 'SD', 'Shandong', '山東', '山东', 37.8006064, -122.2699918),
(757, 45, 'SH', 'Shanghai', '上海', '上海', 31.2304160, 121.4737010),
(758, 45, 'SX', 'Shanxi', '山西', '山西', 37.2425649, 111.8568586),
(759, 45, 'SC', 'Sichuan', '四川', '四川', 30.2638032, 102.8054753),
(760, 45, 'TJ', 'Tianjin', '天津', '天津', 39.1252291, 117.0153435),
(761, 45, 'XJ', 'Xinjiang', '新疆', '新疆', 42.5246357, 87.5395855),
(762, 45, 'XZ', 'Xizang', '西藏', '西藏', 30.1533605, 88.7878678),
(763, 45, 'YN', 'Yunnan', '雲南', '云南', 24.4752847, 101.3431058),
(764, 45, 'ZJ', 'Zhejiang', '浙江', '浙江', 29.1416432, 119.7889248),
(765, 48, 'AMA', 'Amazonas', '亞馬遜河', '亚马逊河', -1.4429123, -71.5723953),
(766, 48, 'ANT', 'Antioquia', '安蒂奧基亞', '安蒂奥基亚', 7.1986064, -75.3412179),
(767, 48, 'ARA', 'Arauca', '阿勞卡', '阿劳卡', 6.5473060, -71.0022311),
(768, 48, 'ATL', 'Atlántico', '大西洋', '大西洋', 10.6966159, -74.8741045),
(769, 48, 'DC', 'Bogotá D.C.', '波哥大特區', '波哥大特区', 4.2820415, -74.5027042),
(770, 48, 'BOL', 'Bolívar', '玻利瓦爾', '玻利瓦尔', 8.6704382, -74.0300122),
(771, 48, 'BOY', 'Boyacá', '博亞卡', '博亚卡', 5.4545110, -73.3620030),
(772, 48, 'CAL', 'Caldas', '卡爾達斯', '卡尔达斯', 5.2982600, -75.2479061),
(773, 48, 'CAQ', 'Caquetá', '卡克塔', '卡克塔', 0.8698920, -73.8419063),
(774, 48, 'CAS', 'Casanare', '卡薩納雷', '卡萨纳雷', 5.7589269, -71.5723953),
(775, 48, 'CAU', 'Cauca', '考卡', '考卡', 2.7049813, -76.8259652),
(776, 48, 'CES', 'Cesar', '塞薩爾', '恺撒', 9.3372948, -73.6536209),
(777, 48, 'CHO', 'Chocó', '喬科', '乔科', 5.2528033, -76.8259652),
(778, 48, 'COR', 'Córdoba', '科爾多瓦', '科尔多瓦', 8.0492930, -75.5740500),
(779, 48, 'CUN', 'Cundinamarca', '昆迪納馬卡', '昆迪纳马卡', 5.0260030, -74.0300122),
(780, 48, 'GUA', 'Guainía', '瓜伊尼亞', '瓜伊尼亚', 2.5853930, -68.5247149),
(781, 48, 'GUV', 'Guaviare', '瓜維亞爾', '番石榴', 2.0439240, -72.3311130),
(782, 48, 'HUI', 'Huila', '惠拉', '惠拉', 2.5359349, -75.5276699),
(783, 48, 'LAG', 'La Guajira', '拉瓜希拉', '拉瓜希拉', 11.3547743, -72.5204827),
(784, 48, 'MAG', 'Magdalena', NULL, NULL, 10.4113014, -74.4056612),
(785, 48, 'MET', 'Meta', '元數據', '元', 39.7673258, -104.9753595),
(786, 48, 'NAR', 'Nariño', '納里尼奧', '纳里尼奥', 1.2891510, -77.3579400),
(787, 48, 'NSA', 'Norte de Santander', '北桑坦德', '北桑坦德', 7.9462831, -72.8988069),
(788, 48, 'PUT', 'Putumayo', '普圖馬約', '普图马约', 0.4359506, -75.5276699),
(789, 48, 'QUI', 'Quindío', '昆迪奧', 'Quindío', 4.4610191, -75.6673560),
(790, 48, 'RIS', 'Risaralda', '里薩拉達', '里萨拉达', 5.3158475, -75.9927652),
(791, 48, 'SAP', 'San Andrés, Providencia y Santa Catalina', '聖安德魯、普羅維登斯和聖凱瑟琳', '圣安德鲁、普罗维登斯和圣凯瑟琳', 12.5567324, -81.7185253),
(792, 48, 'SAN', 'Santander', '桑坦德銀行', '桑坦德', 6.6437076, -73.6536209),
(793, 48, 'SUC', 'Sucre', '糖', '糖', 8.8139770, -74.7232830),
(794, 48, 'TOL', 'Tolima', '托利馬', '托利马', 4.0925168, -75.1545381),
(795, 48, 'VAC', 'Valle del Cauca', '考卡山谷', '考卡山谷', 3.8008893, -76.6412712),
(796, 48, 'VAU', 'Vaupés', '沃佩', '沃佩', 0.8553561, -70.8119953),
(797, 48, 'VID', 'Vichada', '維查達', '维查达', 4.4234452, -69.2877535),
(798, 49, 'A', 'Anjouan', '昂儒昂', '昂儒昂', -12.2138145, 44.4370606),
(799, 49, 'G', 'Grande Comore', '大科摩羅', '大科摩罗', -11.7167338, 43.3680788),
(800, 49, 'M', 'Mohéli', '莫赫利', '莫赫利', -12.3377376, 43.7334089),
(801, 50, '11', 'Bouenza', '布恩扎', '布恩扎', -4.1128079, 13.7289167),
(802, 50, 'BZV', 'Brazzaville', '布拉柴維爾', '布拉柴维尔', -4.2633597, 15.2428853),
(803, 50, '8', 'Cuvette', '盆', '盆地', -0.2877446, 16.1580937),
(804, 50, '15', 'Cuvette-Ouest', '西碗', '西碗', 0.1447550, 14.4723301),
(805, 50, '5', 'Kouilou', '庫伊樓', '库伊楼', -4.1428413, 11.8891721),
(806, 50, '2', 'Lékoumou', '萊庫穆', 'Lékoumou', -3.1703820, 13.3587288),
(807, 50, '7', 'Likouala', '利庫阿拉', '利库阿拉', 2.0439240, 17.6688870),
(808, 50, '9', 'Niari', '尼亞里', '尼亚里', -3.1842700, 12.2547919),
(809, 50, '14', 'Plateaux', '托盤', '托盘', -2.0680088, 15.4068079),
(810, 50, '16', 'Pointe-Noire', '黑角', '黑角', -4.7691623, 11.8663620),
(811, 50, '12', 'Pool', '池', '池', -3.7762628, 14.8454619),
(812, 50, '13', 'Sangha', '僧伽', '桑嘎', 1.4662328, 15.4068079),
(813, 53, 'A', 'Alajuela', '阿拉胡埃拉', '阿拉胡埃拉', 10.3915830, -84.4382721),
(814, 53, 'C', 'Cartago', '迦太基', '迦太基', 9.8622311, -83.9214187),
(815, 53, 'G', 'Guanacaste', '瓜納卡斯特', '瓜纳卡斯特', 10.6267399, -85.4436706),
(816, 53, 'H', 'Heredia', '埃雷迪亞', '埃雷迪亚', 10.4735230, -84.0167423),
(817, 53, 'L', 'Limón', '檸檬', '柠檬', 9.9896398, -83.0332417),
(818, 53, 'P', 'Puntarenas', '蓬塔雷納斯', '蓬塔雷纳斯', 9.2169531, -83.3361880),
(819, 53, 'SJ', 'San José', '聖荷西', '圣何塞', 9.9129727, -84.0768294),
(820, 54, 'AB', 'Abidjan', '阿比讓', '阿比让', 5.3599517, -4.0082563),
(821, 54, '16', 'Agnéby', '阿格尼比', '阿格尼比', 5.3224503, -4.3449529),
(822, 54, '17', 'Bafing', '巴芬', '巴芬', 8.3252047, -7.5247243),
(823, 54, 'BS', 'Bas-Sassandra', '巴斯-薩珊德拉', '巴斯-檫木', 5.2798356, -6.1526985),
(824, 54, '09', 'Bas-Sassandra', '巴斯-薩珊德拉', '巴斯-檫木', 5.3567916, -6.7493993),
(825, 54, 'CM', 'Comoé', '科摩埃', '科摩埃', 5.5527930, -3.2583626),
(826, 54, 'DN', 'Denguélé', '登蓋萊', '登盖莱', 48.0707763, -68.5609341),
(827, 54, '10', 'Denguélé', '登蓋萊', '登盖莱', 9.4662372, -7.4381355),
(828, 54, '06', 'Dix-Huit Montagnes', '十八大山', '十八山', 7.3762373, -7.4381355),
(829, 54, '18', 'Fromager', '奶酪販子', '奶酪贩子', 45.5450213, -73.6046223),
(830, 54, 'GD', 'Gôh-Djiboua', '戈吉布阿', '戈吉布阿', 5.8711393, -5.5617279),
(831, 54, '02', 'Haut-Sassandra', '上欹蛾', '上檫山', 6.8757848, -6.5783387),
(832, 54, '07', 'Lacs', '坎', '圈套', 47.7395866, -70.4186652),
(833, 54, 'LC', 'Lacs', '坎', '圈套', 48.1980169, -80.4564412),
(834, 54, '01', 'Lagunes', '潟湖', '泻湖', 5.8827334, -4.2333355),
(835, 54, 'LG', 'Lagunes', '潟湖', '泻湖', 5.8827334, -4.2333355),
(836, 54, '12', 'Marahoué', '馬拉胡埃', '马拉胡埃', 6.8846207, -5.8987139),
(837, 54, 'MG', 'Montagnes', '山脈', '山', 7.3762373, -7.4381355),
(838, 54, '19', 'Moyen-Cavally', '莫延-卡瓦利', '莫延-卡瓦利', 6.5208793, -7.6114217),
(839, 54, '05', 'Moyen-Comoé', '中科摩埃', '中科摩埃', 6.6514917, -3.5003454),
(840, 54, '11', 'N\'zi-Comoé', 'N', 'N', 7.2456749, -4.2333355),
(841, 54, 'SM', 'Sassandra-Marahoué', '薩珊德拉-馬拉胡埃', '萨珊德拉-马拉胡埃', 6.8803348, -6.2375947),
(842, 54, '03', 'Savanes', '薩瓦內斯', '萨瓦内斯', 9.6373527, -6.7007186),
(843, 54, '15', 'Sud-Bandama', '南班達馬', '南班达马', 5.5357083, -5.5617279),
(844, 54, '13', 'Sud-Comoé', '南科摩埃', '南科摩埃', 5.5527930, -3.2583626),
(845, 54, '04', 'Vallée du Bandama', '班達馬谷', '班达马山谷', 8.2789780, -4.8935627),
(846, 54, 'VB', 'Vallée du Bandama', '班達馬谷', '班达马山谷', 8.2789780, -4.8935627),
(847, 54, 'WR', 'Woroba', '沃羅巴', '沃罗巴', 8.2491372, -6.9209135),
(848, 54, '14', 'Worodougou', '沃羅杜溝', '沃罗杜沟', 8.2548962, -6.5783387),
(849, 54, 'YM', 'Yamoussoukro', '亞穆蘇克羅', '亚穆苏克罗', 6.8276228, -5.2893433),
(850, 54, 'ZZ', 'Zanzan', '三山', '山山', 8.8207904, -3.4195527),
(851, 55, '07', 'Bjelovar-Bilogora', '比耶洛瓦爾-比洛戈拉', 'Bjelovar-Bilogora', 45.8987972, 16.8423093),
(852, 55, '12', 'Brod-Posavina', '布羅德-波薩維納', '布罗德-波萨维纳', 45.2637951, 17.3264562),
(853, 55, '19', 'Dubrovnik-Neretva', '杜布羅夫尼克-內雷特瓦', '杜布罗夫尼克-内雷特瓦', 43.0766588, 17.5268471),
(854, 55, '18', 'Istria', '伊斯特拉', '伊斯特拉', 45.1286455, 13.9015420),
(855, 55, '04', 'Karlovac', '卡爾洛瓦茨', '卡尔洛瓦茨', 45.2613352, 15.5254202),
(856, 55, '06', 'Koprivnica-Križevci', 'Koprivnica-Križevci', 'Koprivnica-Križevci', 46.1568919, 16.8390826),
(857, 55, '02', 'Krapina-Zagorje', '克拉皮納-扎戈耶', '克拉皮纳-扎戈耶', 46.1013393, 15.8809693),
(858, 55, '09', 'Lika-Senj', '利卡-森吉', '利卡-森吉', 44.6192218, 15.4701608),
(859, 55, '20', 'Međimurje', 'Međimurje', 'Međimurje', 46.3766644, 16.4213298),
(860, 55, '14', 'Osijek-Baranja', '奧西耶克-巴拉尼亞', '奥西耶克-巴拉尼亚', 45.5576428, 18.3942141),
(861, 55, '11', 'Požega-Slavonia', '波熱加-斯拉沃尼亞', '波热加-斯拉沃尼亚', 45.3417868, 17.8114359),
(862, 55, '08', 'Primorje-Gorski Kotar', '濱海邊疆區-戈爾斯基科塔爾', '滨海边疆区-戈尔斯基科塔尔', 45.3173996, 14.8167466),
(863, 55, '15', 'Šibenik-Knin', '希貝尼克-克寧', '希贝尼克-克宁', 43.9281485, 16.1037694),
(864, 55, '03', 'Sisak-Moslavina', '西薩克-莫斯拉維納', '西萨克-莫斯拉维纳', 45.3837926, 16.5380994),
(865, 55, '17', 'Split-Dalmatia', '斯普利特-達爾馬提亞', '斯普利特-达尔马提亚', 43.5240328, 16.8178377),
(866, 55, '05', 'Varaždin', '瓦拉日丁', '瓦拉日丁', 46.2317473, 16.3360559),
(867, 55, '10', 'Virovitica-Podravina', '維羅維蒂卡-波德拉維納', '维罗维蒂卡-波德拉维纳', 45.6557985, 17.7932472),
(868, 55, '16', 'Vukovar-Syrmia', '武科瓦爾-西爾米亞', '武科瓦尔-锡尔米亚', 45.1773552, 18.8053527),
(869, 55, '13', 'Zadar', '扎達爾', '扎达尔', 44.1469390, 15.6164943),
(870, 55, '01', 'Zagreb', '薩格勒布', '萨格勒布', 45.8706612, 16.3954910),
(871, 55, '21', 'Zagreb', '薩格勒布', '萨格勒布', 45.8150108, 15.9819189),
(872, 56, '15', 'Artemisa', '艾', '艾', 22.7522903, -82.9931607),
(873, 56, '09', 'Camagüey', '卡馬圭', '卡马圭', 21.2167247, -77.7452081),
(874, 56, '08', 'Ciego de Ávila', 'Ciego de Ávila', 'Ciego de Ávila', 21.9329515, -78.5660852),
(875, 56, '06', 'Cienfuegos', '西恩富戈斯', '西恩富戈斯', 22.2379783, -80.3658650),
(876, 56, '12', 'Granma', '奶奶', '奶奶', 20.3844902, -76.6412712),
(877, 56, '14', 'Guantánamo', '關塔那摩', '关塔 那 摩', 20.1455917, -74.8741045),
(878, 56, '03', 'Havana', '哈瓦那', '哈瓦那', 23.0540698, -82.3451890),
(879, 56, '11', 'Holguín', '奧爾金', '奥尔金', 20.7837893, -75.8069082),
(880, 56, '99', 'Isla de la Juventud', '青春之島', '青年岛', 21.7084737, -82.8220232),
(881, 56, '10', 'Las Tunas', '拉斯圖納斯', '拉斯图纳斯', 21.0605162, -76.9182097),
(882, 56, '04', 'Matanzas', '馬坦薩斯', '马坦萨斯', 22.5767123, -81.3399414),
(883, 56, '16', 'Mayabeque', '瑪雅貝克', '马亚贝克', 22.8926529, -81.9534815),
(884, 56, '01', 'Pinar del Río', '比那爾德里奧', '比那尔德里奥', 22.4076256, -83.8473015),
(885, 56, '07', 'Sancti Spíritus', '聖斯皮里圖斯', 'Sancti Spíritus', 21.9938214, -79.4703885),
(886, 56, '13', 'Santiago de Cuba', '古巴聖地亞哥', '古巴圣地亚哥', 20.2397682, -75.9927652),
(887, 56, '05', 'Villa Clara', '克拉拉別墅', '克拉拉别墅', 22.4937204, -79.9192702),
(888, 57, '04', 'Famagusta (Mağusa)', '法馬古斯塔（法馬古斯塔）', '法马古斯塔（法马古斯塔）', 35.2857023, 33.8411288),
(889, 57, '06', 'Kyrenia (Keryneia)', '凱里尼亞（Keryneia）', '凯里尼亚（Keryneia）', 35.2991940, 33.2363246),
(890, 57, '03', 'Larnaca (Larnaka)', '拉納卡（拉納卡）', '拉纳卡（拉纳卡）', 34.8507206, 33.4831906),
(891, 57, '02', 'Limassol (Leymasun)', '利馬索爾（Leymasun）', '利马索尔 （Leymasun）', 34.7071301, 33.0226174),
(892, 57, '01', 'Nicosia (Lefkoşa)', '尼科西亞（尼科西亞）', '尼科西亚（尼科西亚）', 35.1855659, 33.3822764),
(893, 57, '05', 'Paphos (Pafos)', '帕福斯（Paphos）', '帕福斯（帕福斯）', 34.9164594, 32.4920088),
(894, 58, '201', 'Benešov', '貝內索夫', '贝内索夫', 49.6900828, 14.7764399),
(895, 58, '202', 'Beroun', '貝倫', '贝隆', 49.9573428, 13.9840715),
(896, 58, '641', 'Blansko', '布蘭斯科', '布兰斯科', 49.3648502, 16.6477552),
(897, 58, '644', 'Břeclav', '布熱茨拉夫', '布热茨拉夫', 48.7531400, 16.8825169),
(898, 58, '642', 'Brno-město', '布爾諾市', '布尔诺市', 49.1950602, 16.6068371),
(899, 58, '643', 'Brno-venkov', '布爾諾-鄉村', '布尔诺乡村', 49.1250138, 16.4558824),
(900, 58, '801', 'Bruntál', '布倫塔爾', '布伦塔尔', 49.9881767, 17.4636941),
(901, 58, '511', 'Česká Lípa', '捷克利帕', '捷克利帕', 50.6785201, 14.5396991),
(902, 58, '311', 'České Budějovice', '捷克布傑約維采', '捷克布杰约维采', 48.9775553, 14.5150747),
(903, 58, '312', 'Český Krumlov', '捷克克魯姆洛夫', '捷克克鲁姆洛夫', 48.8127354, 14.3174657),
(904, 58, '411', 'Cheb', '切布', '切布', 50.0795334, 12.3698636),
(905, 58, '422', 'Chomutov', '喬穆托夫', '乔穆托夫', 50.4583872, 13.3017910),
(906, 58, '531', 'Chrudim', '克魯丁', '克鲁迪姆', 49.8830216, 15.8290866),
(907, 58, '421', 'Děčín', '傑欽', '杰钦', 50.7725563, 14.2127612),
(908, 58, '321', 'Domažlice', 'Domažlice', 'Domažlice', 49.4397027, 12.9311435),
(909, 58, '802', 'Frýdek-Místek', 'Frýdek-Místek', 'Frýdek-Místek', 49.6819305, 18.3673216),
(910, 58, '631', 'Havlíčkův Brod', 'Havlíčkův Brod', 'Havlíčkův Brod', 49.6043364, 15.5796552),
(911, 58, '645', 'Hodonín', '霍多寧', '霍多宁', 48.8529391, 17.1260025),
(912, 58, '521', 'Hradec Králové', '赫拉德茨·克拉洛韋', '赫拉德茨·克拉洛韦', 50.2414805, 15.6743000),
(913, 58, '512', 'Jablonec nad Nisou', 'Jablonec nad Nisou', 'Jablonec nad Nisou', 50.7220528, 15.1703135),
(914, 58, '711', 'Jeseník', 'Jeseník', 'Jeseník', 50.2246249, 17.1980471),
(915, 58, '522', 'Jičín', '吉欽', '吉钦', 50.4353325, 15.3610440),
(916, 58, '632', 'Jihlava', '伊赫拉瓦', '伊赫拉瓦', 49.3983782, 15.5870415),
(917, 58, '31', 'Jihočeský kraj', 'Jihočeský kraj', 'Jihočeský kraj', 48.9457789, 14.4416055),
(918, 58, '64', 'Jihomoravský kraj', 'Jihomoravský kraj', 'Jihomoravský kraj', 48.9544528, 16.7676899),
(919, 58, '313', 'Jindřichův Hradec', 'Jindřichův Hradec', 'Jindřichův Hradec', 49.1444823, 15.0061389),
(920, 58, '41', 'Karlovarský kraj', '卡羅維發利地區', '卡罗维发利州', 50.1435000, 12.7501899),
(921, 58, '412', 'Karlovy Vary', '卡羅維發利', '卡罗维发利', 50.1435000, 12.7501899),
(922, 58, '803', 'Karviná', '卡爾維納', '卡尔维纳', 49.8566524, 18.5432186),
(923, 58, '203', 'Kladno', '克拉德諾', '克拉德诺', 50.1940258, 14.1043657),
(924, 58, '322', 'Klatovy', '克拉托維', '克拉托维', 49.3955549, 13.2950937),
(925, 58, '204', 'Kolín', '科隆', '科隆', 49.9883293, 15.0551977),
(926, 58, '63', 'Kraj Vysočina', '克拉伊·維索奇納', '克拉伊·维索奇纳', 49.4490052, 15.6405934),
(927, 58, '52', 'Královéhradecký kraj', 'Královéhradecký kraj', 'Královéhradecký kraj', 50.3512484, 15.7976459),
(928, 58, '721', 'Kroměříž', 'Kroměříž', 'Kroměříž', 49.2916582, 17.3993800),
(929, 58, '205', 'Kutná Hora', '庫特納霍拉', '库特纳霍拉', 49.9492089, 15.2470440),
(930, 58, '513', 'Liberec', '利貝雷茨', '利贝雷茨', 50.7564101, 14.9965041),
(931, 58, '51', 'Liberecký kraj', 'Liberecký kraj', 'Liberecký kraj', 50.6594240, 14.7632424),
(932, 58, '423', 'Litoměřice', 'Litoměřice', 'Litoměřice', 50.5384197, 14.1305458),
(933, 58, '424', 'Louny', '盧尼', '卢尼', 50.3539812, 13.8033551),
(934, 58, '206', 'Mělník', 'Mělník', 'Mělník', 50.3104415, 14.5179223),
(935, 58, '207', 'Mladá Boleslav', '姆拉達·博萊斯拉夫', '姆拉达·博莱斯拉夫', 50.4252317, 14.9362477),
(936, 58, '80', 'Moravskoslezský kraj', '摩拉維亞-西里西亞地區', '摩拉维亚-西里西亚地区', 49.7305327, 18.2332637),
(937, 58, '425', 'Most', '最', '最', 37.1554083, -94.2948884),
(938, 58, '523', 'Náchod', '納科德', '纳乔德', 50.4145722, 16.1656347),
(939, 58, '804', 'Nový Jičín', 'Nový Jičín', 'Nový Jičín', 49.5943251, 18.0135356),
(940, 58, '208', 'Nymburk', '寧伯克', '宁伯克', 50.1855816, 15.0436604),
(941, 58, '712', 'Olomouc', '奧洛穆茨', '奥洛穆茨', 49.5937780, 17.2508787),
(942, 58, '71', 'Olomoucký kraj', 'Olomoucký kraj', 'Olomoucký kraj', 49.6586549, 17.0811406),
(943, 58, '805', 'Opava', '奧帕瓦', '奥帕瓦', 49.9083757, 17.9163380),
(944, 58, '806', 'Ostrava-město', '俄斯特拉發市', '俄斯特拉发市', 49.8209226, 18.2625243),
(945, 58, '532', 'Pardubice', '帕爾杜比採', '帕尔杜比采', 49.9444479, 16.2856916),
(946, 58, '53', 'Pardubický kraj', '帕爾杜比采地區', '帕尔杜比采地区', 49.9444479, 16.2856916),
(947, 58, '633', 'Pelhřimov', '佩爾日莫夫', '佩尔日莫夫', 49.4306207, 15.2229830),
(948, 58, '314', 'Písek', '沙', '沙', 49.3419938, 14.2469760),
(949, 58, '324', 'Plzeň-jih', '比爾森-南', '比尔森-南', 49.5904885, 13.5715861),
(950, 58, '323', 'Plzeň-město', '比爾森城', '比尔森城', 49.7384314, 13.3736371),
(951, 58, '325', 'Plzeň-sever', '北比爾森', '比尔森-北', 49.8774893, 13.2537428),
(952, 58, '32', 'Plzeňský kraj', '比爾森地區', '比尔森地区', 49.4134812, 13.3157246),
(953, 58, '315', 'Prachatice', '普拉查蒂斯', '普拉查蒂斯', 49.0109100, 14.0000005),
(954, 58, '209', 'Praha-východ', '布拉格-東部', '布拉格-东部', 49.9389307, 14.7924472),
(955, 58, '20A', 'Praha-západ', '布拉格-西', '布拉格-西', 49.8935235, 14.3293779),
(956, 58, '10', 'Praha, Hlavní město', '首都布拉格', '首都布拉格', 50.0755381, 14.4378005),
(957, 58, '714', 'Přerov', '普熱羅夫', '普热罗夫', 49.4671356, 17.5077332),
(958, 58, '20B', 'Příbram', 'Příbram', 'Příbram', 49.6947959, 14.0823810),
(959, 58, '713', 'Prostějov', '普羅斯捷約夫', '普罗斯捷约夫', 49.4418401, 17.1277904),
(960, 58, '20C', 'Rakovník', 'Rakovník', 'Rakovník', 50.1061230, 13.7396623),
(961, 58, '326', 'Rokycany', '羅基卡尼', '罗基卡尼', 49.8262827, 13.6874943),
(962, 58, '524', 'Rychnov nad Kněžnou', 'Rychnov nad Kněžnou', 'Rychnov nad Kněžnou', 50.1659651, 16.2776842),
(963, 58, '514', 'Semily', '半', '半', 50.6051576, 15.3281409),
(964, 58, '413', 'Sokolov', '索科洛夫', '索科洛夫', 50.2013434, 12.6054636),
(965, 58, '316', 'Strakonice', '斯特拉科尼采', '斯特拉科尼采', 49.2604043, 13.9103085),
(966, 58, '20', 'Středočeský kraj', 'Středočeský kraj', 'Středočeský kraj', 49.8782223, 14.9362955),
(967, 58, '715', 'Šumperk', 'Šumperk', 'Šumperk', 49.9778407, 16.9717754),
(968, 58, '533', 'Svitavy', '斯維塔維', '斯维塔维', 49.7551629, 16.4691861),
(969, 58, '317', 'Tábor', '陣營', '营地', 49.3646293, 14.7191293),
(970, 58, '327', 'Tachov', '塔霍夫', '塔乔夫', 49.7987803, 12.6361921),
(971, 58, '426', 'Teplice', '特普利采', '特普利采', 50.6584605, 13.7513227),
(972, 58, '634', 'Třebíč', 'Třebíč', 'Třebíč', 49.2147869, 15.8795516),
(973, 58, '525', 'Trutnov', '特魯特諾夫', '特鲁特诺夫', 50.5653838, 15.9090923),
(974, 58, '722', 'Uherské Hradiště', 'Uherské Hradiště', 'Uherské Hradiště', 49.0597969, 17.4958501),
(975, 58, '42', 'Ústecký kraj', '拉貝河畔烏斯季', '拉贝河畔乌斯季', 50.6119037, 13.7870086),
(976, 58, '427', 'Ústí nad Labem', 'Ústí nad Labem', 'Ústí nad Labem', 50.6119037, 13.7870086),
(977, 58, '534', 'Ústí nad Orlicí', 'Ústí nad Orlicí', 'Ústí nad Orlicí', 49.9721801, 16.3996617),
(978, 58, '723', 'Vsetín', 'Vsetín', 'Vsetín', 49.3793250, 18.0618162),
(979, 58, '646', 'Vyškov', '維什科夫', '维什科夫', 49.2127445, 16.9855927),
(980, 58, '635', 'Žďár nad Sázavou', 'Žďár nad Sázavou', 'Žďár nad Sázavou', 49.5643012, 15.9391030),
(981, 58, '724', 'Zlín', '茲林', '兹林', 49.1696052, 17.8025220),
(982, 58, '72', 'Zlínský kraj', '茲林地區', '兹林地区', 49.2162296, 17.7720353),
(983, 58, '647', 'Znojmo', '茲諾伊莫', '兹诺伊莫', 48.9272327, 16.1037808),
(984, 51, 'BU', 'Bas-Uélé', 'Bas-Uélé', '下韦莱', 3.9901009, 24.9042208),
(985, 51, 'EQ', 'Équateur', '厄瓜多', '厄瓜多尔', -1.8312390, -78.1834060),
(986, 51, 'HK', 'Haut-Katanga', '上加丹加', '上加丹加', -10.4102075, 27.5495846),
(987, 51, 'HL', 'Haut-Lomami', '上洛馬米', '上洛马米', -7.7052752, 24.9042208),
(988, 51, 'HU', 'Haut-Uélé', '上韋萊', '上韦莱', 3.5845154, 28.2994350),
(989, 51, 'IT', 'Ituri', '伊圖里', '伊图里', 1.5957682, 29.4179324),
(990, 51, 'KS', 'Kasaï', '葛西', '葛西', -5.0471979, 20.7122465),
(991, 51, 'KC', 'Kasaï Central', '開賽中央', '开赛中心', -8.4404591, 20.4165934),
(992, 51, 'KE', 'Kasaï Oriental', '東方葛賽酒店', '东方开赛酒店', -6.0336230, 23.5728501),
(993, 51, 'KN', 'Kinshasa', '金沙薩', '金沙萨', -4.4419311, 15.2662931),
(994, 51, 'BC', 'Kongo Central', '剛果中部', '刚果中部', -5.2365685, 13.9143990),
(995, 51, 'KG', 'Kwango', '寬果', '宽果', -6.4337409, 17.6688870),
(996, 51, 'KL', 'Kwilu', '奎魯', '奎卢', -5.1188825, 18.4276047),
(997, 51, 'LO', 'Lomami', '採石場', '采石场', -6.1453931, 24.5242640),
(998, 51, 'LU', 'Lualaba', '盧阿拉巴', '卢阿拉巴', -10.4808698, 25.6297816),
(999, 51, 'MN', 'Mai-Ndombe', '邁恩東貝', '迈恩东贝', -2.6357434, 18.4276047),
(1000, 51, 'MA', 'Maniema', '馬尼埃瑪', '马涅玛', -3.0730929, 26.0413889),
(1001, 51, 'MO', 'Mongala', '蒙加拉', '蒙加拉', 1.9962324, 21.4752851),
(1002, 51, 'NK', 'Nord-Kivu', '北基伍省', '北基伍省', -0.7917729, 29.0459927),
(1003, 51, 'NU', 'Nord-Ubangi', '北烏班吉', '北乌班吉', 3.7878726, 21.4752851),
(1004, 51, 'SA', 'Sankuru', '桑庫魯', '桑库鲁', -2.8437453, 23.3823545),
(1005, 51, 'SK', 'Sud-Kivu', '南基伍省', '南基伍省', -3.0116580, 28.2994350),
(1006, 51, 'SU', 'Sud-Ubangi', '南烏班吉', '南乌班吉', 3.2299942, 19.1880047),
(1007, 51, 'TA', 'Tanganyika', '坦噶尼喀', '坦噶尼喀', -6.2740118, 27.9249002),
(1008, 51, 'TO', 'Tshopo', '喬波', '乔波', 0.5455462, 24.9042208),
(1009, 51, 'TU', 'Tshuapa', '茨瓦帕', '茨瓦帕', -0.9903023, 23.0288844),
(1010, 59, '82', 'Central Denmark', '丹麥中部', '丹麦中部', 56.3021390, 9.3027770),
(1011, 59, '84', 'Denmark', '丹麥', '丹麦', 55.6751812, 12.5493261),
(1012, 59, '81', 'North Denmark', '北丹麥', '北丹麦', 56.8307416, 9.4930527),
(1013, 59, '83', 'Southern Denmark', '丹麥南部', '丹麦南部', 55.3307714, 9.0924903),
(1014, 59, '85', 'Zealand', '西蘭', '新西兰', 55.4632518, 11.7214979),
(1015, 60, 'AS', 'Ali Sabieh', '阿里·薩比耶', '阿里·萨比耶', 11.1928973, 42.9416980),
(1016, 60, 'AR', 'Arta', '藝', '艺术', 11.5255528, 42.8479474),
(1017, 60, 'DI', 'Dikhil', '迪基爾', '迪基尔', 11.1054336, 42.3704744),
(1018, 60, 'DJ', 'Djibouti', '吉布地', '吉布提', 11.8251380, 42.5902750),
(1019, 60, 'OB', 'Obock', '奧博克', '奥博克', 12.3895691, 43.0194897),
(1020, 60, 'TA', 'Tadjourah', '塔朱拉', '塔朱拉', 11.9338885, 42.3938375),
(1021, 61, '02', 'Saint Andrew', '聖安德魯', '圣安德鲁', 15.5468152, -61.4399424),
(1022, 61, '03', 'Saint David', '聖大衛', '圣大卫', 15.4241823, -61.3676204),
(1023, 61, '04', 'Saint George', '聖喬治', '圣乔治', 15.3092532, -61.3870614),
(1024, 61, '05', 'Saint John', '聖約翰', '圣约翰', 15.5757467, -61.4817853),
(1025, 61, '06', 'Saint Joseph', '聖若瑟', '圣约瑟夫', 15.4475894, -61.4673363),
(1026, 61, '07', 'Saint Luke', '聖路加', '圣路加', 15.2550271, -61.3817636),
(1027, 61, '08', 'Saint Mark', '聖馬可', '圣马可', 15.2308636, -61.3724836),
(1028, 61, '09', 'Saint Patrick', '聖派翠克', '圣帕特里克', 15.2814797, -61.3348603),
(1029, 61, '10', 'Saint Paul', '聖保羅', '圣保罗', 15.3671913, -61.4121082),
(1030, 61, '11', 'Saint Peter', '聖彼得', '圣彼得', 15.5021502, -61.4802157),
(1031, 62, '02', 'Azua', '阿祖阿', '阿祖阿', 18.4552709, -70.7380928),
(1032, 62, '03', 'Baoruco', '寶魯科', '宝如科', 18.4879898, -71.4182249),
(1033, 62, '04', 'Barahona', '巴拉奧納', '巴拉奥纳', 18.2139066, -71.1043759),
(1034, 62, '05', 'Dajabón', '達賈邦', '达贾邦', 19.5499241, -71.7086514),
(1035, 62, '01', 'Distrito Nacional', '國家區', '国家区', 18.4860575, -69.9312117),
(1036, 62, '06', 'Duarte', '杜阿爾特', '杜阿尔特', 19.2090823, -70.0270004),
(1037, 62, '08', 'El Seibo', '埃爾西博', '埃尔西博', 18.7658496, -69.0406680),
(1038, 62, '09', 'Espaillat', '埃斯帕拉特', '埃斯帕拉特', 19.6277658, -70.2786775),
(1039, 62, '30', 'Hato Mayor', '鳩市長', 'Hato 市长', 18.7635799, -69.2557637),
(1040, 62, '19', 'Hermanas Mirabal', '米拉巴爾姐妹', '米拉巴尔姐妹', 19.3747559, -70.3513235),
(1041, 62, '10', 'Independencia', '自立', '独立', 32.6335748, -115.4289294),
(1042, 62, '11', 'La Altagracia', '拉阿爾塔格拉西亞', '拉阿尔塔格拉西亚', 18.5850236, -68.6201072),
(1043, 62, '12', 'La Romana', '拉羅馬納', '拉罗马纳', 18.4310271, -68.9837373),
(1044, 62, '13', 'La Vega', '拉維加', '拉维加', 19.2211554, -70.5288753),
(1045, 62, '14', 'María Trinidad Sánchez', '瑪麗亞·特立尼達·桑切斯', '玛丽亚·特立尼达·桑切斯', 19.3734597, -69.8514439),
(1046, 62, '28', 'Monseñor Nouel', '努埃爾主教', '努埃尔主教', 18.9215234, -70.3836815),
(1047, 62, '15', 'Monte Cristi', '蒙特克里斯蒂', '蒙特克里斯蒂', 19.7396899, -71.4433984),
(1048, 62, '29', 'Monte Plata', '普拉塔山', '普拉塔山', 18.8080878, -69.7869146),
(1049, 62, '16', 'Pedernales', '弗林茨', '火石', 17.8537626, -71.3303209),
(1050, 62, '17', 'Peravia', '佩拉維亞', '佩拉维亚', 18.2786594, -70.3335887),
(1051, 62, '18', 'Puerto Plata', '普拉塔港', '普拉塔港', 19.7543225, -70.8332847),
(1052, 62, '20', 'Samaná', '薩馬納', '萨马纳', 19.2058371, -69.3362949),
(1053, 62, '21', 'San Cristóbal', '聖克里斯托瓦爾', '圣克里斯托瓦尔', 18.4180414, -70.1065849),
(1054, 62, '31', 'San José de Ocoa', '聖何塞德奧科亞', '圣何塞德奥科亚', 18.5438580, -70.5041816),
(1055, 62, '22', 'San Juan', '聖胡安', '圣胡安', -31.5287127, -68.5360403),
(1056, 62, '23', 'San Pedro de Macorís', '聖佩德羅德馬科里斯', '圣佩德罗德马科里斯', 18.4626600, -69.3051234),
(1057, 62, '24', 'Sánchez Ramírez', '桑切斯·拉米雷斯', '桑切斯·拉米雷斯', 19.0527060, -70.1492264),
(1058, 62, '25', 'Santiago', '聖地牙哥', '圣地亚哥', -33.4500000, -70.6667000),
(1059, 62, '26', 'Santiago Rodríguez', '聖地亞哥·羅德里格斯', '圣地亚哥·罗德里格斯', 19.4713181, -71.3395801),
(1060, 62, '32', 'Santo Domingo', '聖多明各', '圣多明各', 18.5104253, -69.8404054),
(1061, 62, '27', 'Valverde', '巴爾韋德', '巴尔韦德', 19.5881221, -70.9803310),
(1062, 64, 'A', 'Azuay', '阿祖艾', '阿祖艾', -2.8943068, -78.9968344),
(1063, 64, 'B', 'Bolívar', '玻利瓦爾', '玻利瓦尔', -1.7095828, -79.0450429),
(1064, 64, 'F', 'Cañar', '卡尼亞爾', '卡纳尔', -2.5589315, -78.9388191),
(1065, 64, 'C', 'Carchi', '卡奇', '卡奇', 0.5026912, -77.9042521),
(1066, 64, 'H', 'Chimborazo', '欽博拉索', '钦博拉索', -1.6647995, -78.6543255),
(1067, 64, 'X', 'Cotopaxi', '科托帕希', '科托帕希', -0.8384206, -78.6662678),
(1068, 64, 'O', 'El Oro', '金', '金', -3.2592413, -79.9583541),
(1069, 64, 'E', 'Esmeraldas', '祖母綠', '祖母绿', 0.9681789, -79.6517202),
(1070, 64, 'W', 'Galápagos', '加拉帕戈斯群島', '加拉帕戈斯', -0.9537691, -90.9656019),
(1071, 64, 'G', 'Guayas', '瓜亞斯', '番石榴', -1.9574839, -79.9192702),
(1072, 64, 'I', 'Imbabura', '因巴布拉', '因巴布拉', 0.3499768, -78.1260129),
(1073, 64, 'L', 'Loja', '店', '店', -3.9931300, -79.2042200),
(1074, 64, 'R', 'Los Ríos', '洛斯里奧斯', '洛斯里奥斯', -1.0230607, -79.4608897),
(1075, 64, 'M', 'Manabí', '馬納比', '马纳比', -1.0543434, -80.4526440),
(1076, 64, 'S', 'Morona-Santiago', '莫羅納-聖地牙哥', '莫罗纳-圣地亚哥', -2.3051062, -78.1146866),
(1077, 64, 'N', 'Napo', '納波', '纳波', -0.9955964, -77.8129684),
(1078, 64, 'D', 'Orellana', '奧雷利亞納', '奥雷利亚纳', -0.4545163, -76.9950286),
(1079, 64, 'Y', 'Pastaza', '義大利麵', '意大利面食', -1.4882265, -78.0031057),
(1080, 64, 'P', 'Pichincha', '皮欽查', '皮钦查', -0.1464847, -78.4751945),
(1081, 64, 'SE', 'Santa Elena', '聖埃琳娜', '圣埃琳娜', -2.2267105, -80.8594990),
(1082, 64, 'SD', 'Santo Domingo de los Tsáchilas', '聖多明各德洛斯察奇拉斯', '圣多明各德洛斯察奇拉斯', -0.2521882, -79.1879383),
(1083, 64, 'U', 'Sucumbíos', 'Sucumbíos', 'Sucumbíos', 0.0889231, -76.8897557),
(1084, 64, 'T', 'Tungurahua', '通古拉瓦', '通古拉瓦', -1.2635284, -78.5660852),
(1085, 64, 'Z', 'Zamora Chinchipe', '薩莫拉·欽奇普', '萨莫拉·钦奇普', -4.0655892, -78.9503525),
(1086, 65, 'ALX', 'Alexandria', '亞歷山大', '亚历山德里亚', 30.8760568, 29.7426040),
(1087, 65, 'ASN', 'Aswan', '阿斯旺', '阿斯旺', 23.6966498, 32.7181375),
(1088, 65, 'AST', 'Asyut', '阿修特', '阿修特', 27.2133831, 31.4456179),
(1089, 65, 'BH', 'Beheira', '貝希拉', '贝希拉', 30.8480986, 30.3435506),
(1090, 65, 'BNS', 'Beni Suef', '貝尼·蘇夫', '贝尼·苏夫', 28.8938837, 31.4456179),
(1091, 65, 'C', 'Cairo', '開羅', '开罗', 29.9537564, 31.5370003),
(1092, 65, 'DK', 'Dakahlia', '達卡利亞', '达卡利亚', 31.1656044, 31.4913182),
(1093, 65, 'DT', 'Damietta', '達米埃塔', '达米埃塔', 31.3625799, 31.6739371),
(1094, 65, 'FYM', 'Faiyum', '費尤姆', '费尤姆', 29.3084021, 30.8428497),
(1095, 65, 'GH', 'Gharbia', '加爾比亞', '加尔比亚', 30.8753556, 31.0335100),
(1096, 65, 'GZ', 'Giza', '吉薩', '吉萨', 28.7666216, 29.2320784),
(1097, 65, 'IS', 'Ismailia', '伊斯梅利亞', '伊斯梅利亚', 30.5830934, 32.2653887),
(1098, 65, 'KFS', 'Kafr El-Sheikh', '卡夫爾謝赫', '卡夫尔谢赫', 31.3085444, 30.8039474),
(1099, 65, 'LX', 'Luxor', '盧克索', '卢克索', 25.3944444, 32.4920088),
(1100, 65, 'MT', 'Matrouh', '馬特魯', '马特鲁', 29.5696350, 26.4193890),
(1101, 65, 'MN', 'Minya', '敏雅', '敏雅', 28.2847290, 30.5279096),
(1102, 65, 'MNF', 'Monufia', '莫努菲亞', '莫努菲亚', 30.5972455, 30.9876321),
(1103, 65, 'WAD', 'New Valley', '新谷', '新谷', 24.5455638, 27.1735316),
(1104, 65, 'SIN', 'North Sinai', '北西奈半島', '北西奈', 30.2823650, 33.6175770),
(1105, 65, 'PTS', 'Port Said', '塞得港', '塞得港', 31.0758606, 32.2653887),
(1106, 65, 'KB', 'Qalyubia', '卡柳比亞', '卡柳比亚', 30.3292368, 31.2168466),
(1107, 65, 'KN', 'Qena', '奇娜', 'Qena', 26.2346033, 32.9888319),
(1108, 65, 'BA', 'Red Sea', '紅海', '红海', 24.6826316, 34.1531947),
(1109, 65, 'SHR', 'Sharqia', '沙爾奇亞', '沙尔基亚', 30.6730545, 31.1593247),
(1110, 65, 'SHG', 'Sohag', '索哈格', '索哈格', 26.6938340, 32.1746050),
(1111, 65, 'JS', 'South Sinai', '南西奈半島', '南西奈', 29.3101828, 34.1531947),
(1112, 65, 'SUZ', 'Suez', '蘇伊士', '苏伊士运河', 29.3682255, 32.1746050),
(1113, 66, 'AH', 'Ahuachapán', '阿瓦查潘', '阿瓦查潘', 13.8216148, -89.9253233),
(1114, 66, 'CA', 'Cabañas', '客艙', '小 木屋', 13.8648288, -88.7493998),
(1115, 66, 'CH', 'Chalatenango', '查拉特南戈', '查拉特南戈', 14.1916648, -89.1705998),
(1116, 66, 'CU', 'Cuscatlán', '庫斯卡特蘭', '库斯卡特兰', 13.8661957, -89.0561532),
(1117, 66, 'LI', 'La Libertad', '自由', '自由', 13.6817661, -89.3606298),
(1118, 66, 'PA', 'La Paz', '拉巴斯', '拉巴斯', 13.4662148, -89.1369972),
(1119, 66, 'UN', 'La Unión ', '工會', '联盟', 13.4886443, -87.8942451),
(1120, 66, 'MO', 'Morazán', '莫拉桑', '莫拉桑', 13.7682000, -88.1291387),
(1121, 66, 'SM', 'San Miguel', '聖米格爾', '圣米格尔', 13.4451041, -88.2461183),
(1122, 66, 'SS', 'San Salvador', '聖薩爾瓦多', '圣萨尔瓦多', 13.7739997, -89.2086773),
(1123, 66, 'SV', 'San Vicente', '聖文森特', '圣文森特', 13.5868561, -88.7493998),
(1124, 66, 'SA', 'Santa Ana', '聖安娜', '圣安娜', 14.1461121, -89.5120084),
(1125, 66, 'SO', 'Sonsonate', '桑索納特', '桑索纳特', 13.6823580, -89.6628111),
(1126, 66, 'US', 'Usulután', 'Usulután', '乌苏鲁坦', 13.4470634, -88.5565310),
(1127, 67, 'AN', 'Annobón', '安諾邦', '安诺邦', -1.4268782, 5.6352801),
(1128, 67, 'BN', 'Bioko Norte', '比奧科北', '比奥科北', 3.6595072, 8.7921836),
(1129, 67, 'BS', 'Bioko Sur', '蘇爾比奧科', '苏尔比奥科', 3.4209785, 8.6160674),
(1130, 67, 'CS', 'Centro Sur', '中南部', '中南部', 1.3436084, 10.4396560),
(1131, 67, 'I', 'Insular', '海島的', '岛的', 37.0902400, -95.7128910),
(1132, 67, 'KN', 'Kié-Ntem', '基恩特姆', '基恩特姆', 2.0280930, 11.0711758),
(1133, 67, 'LI', 'Litoral', '海岸', '海岸', 1.5750244, 9.8124935),
(1134, 67, 'C', 'Río Muni', '牟尼河', 'Muni River', 1.4610606, 9.6786894),
(1135, 67, 'WN', 'Wele-Nzas', '韋勒-恩薩斯', '韦勒-恩萨斯', 1.4166162, 11.0711758),
(1136, 68, 'AN', 'Anseba', '安塞巴', '安塞巴', 16.4745531, 37.8087693),
(1137, 68, 'DU', 'Debub', '德布布', '德布布', 14.9478692, 39.1543677),
(1138, 68, 'GB', 'Gash-Barka', '加什-巴爾卡', '加什-巴尔卡', 15.4068825, 37.6386622),
(1139, 68, 'MA', 'Maekel', '梅克爾', '梅克尔', 15.3551409, 38.8623683),
(1140, 68, 'SK', 'Northern Red Sea', '紅海北部', '红海北部', 16.2583997, 38.8205454),
(1141, 68, 'DK', 'Southern Red Sea', '紅海南部', '红海南部', 13.5137103, 41.7606472),
(1142, 69, '37', 'Harju', '哈爾朱', '哈尔朱', 59.3334239, 25.2466974),
(1143, 69, '39', 'Hiiu', '嗨嗨', '嗨嗨', 58.9239553, 22.5919468),
(1144, 69, '44', 'Ida-Viru', '艾達-維魯縣', '艾达-维鲁县', 59.2592663, 27.4136535),
(1145, 69, '51', 'Järva', 'Järva', '耶尔瓦', 58.8866713, 25.5000624),
(1146, 69, '49', 'Jõgeva', '約格瓦', '约格瓦', 58.7506143, 26.3604878),
(1147, 69, '57', 'Lääne', '西方的', '西方', 58.9722742, 23.8740834),
(1148, 69, '59', 'Lääne-Viru', '拉內-維魯縣', '莱讷-维鲁县', 59.3018816, 26.3280312),
(1149, 69, '67', 'Pärnu', '帕爾努', '帕尔努', 58.5261952, 24.4020159),
(1150, 69, '65', 'Põlva', 'Põlva', 'Põlva', 58.1160622, 27.2066394),
(1151, 69, '70', 'Rapla', '拉普拉', '拉普拉', 58.8492625, 24.7346569),
(1152, 69, '74', 'Saare', '島', '岛', 58.4849721, 22.6136408),
(1153, 69, '78', 'Tartu', '塔爾圖', '塔尔图', 58.4057128, 26.8015760),
(1154, 69, '82', 'Valga', '價值', '值得', 57.9103441, 26.1601819),
(1155, 69, '84', 'Viljandi', '維爾揚迪', '维尔扬迪', 58.2821746, 25.5752233),
(1156, 69, '86', 'Võru', 'Võru', 'Võru', 57.7377372, 27.1398938),
(1157, 212, 'HH', 'Hhohho', '嗚', '霍霍', -26.1365662, 31.3541631),
(1158, 212, 'LU', 'Lubombo', '盧邦博', '卢邦博', -26.7851773, 31.8107079),
(1159, 212, 'MA', 'Manzini', '曼齊尼', '曼齐尼', -26.5081999, 31.3713164),
(1160, 212, 'SH', 'Shiselweni', '希塞爾韋尼', '希塞尔韦尼', -26.9827577, 31.3541631),
(1161, 70, 'AA', 'Addis Ababa', '亞的斯亞貝巴', '亚的斯亚贝巴', 8.9806034, 38.7577605),
(1162, 70, 'AF', 'Afar', '四', '四', 11.7559388, 40.9586880),
(1163, 70, 'AM', 'Amhara', '阿姆哈拉', '阿姆哈拉语', 11.3494247, 37.9784585),
(1164, 70, 'BE', 'Benishangul-Gumuz', '貝尼尚古爾-古穆茲', '贝尼尚古尔-古穆兹', 10.7802889, 35.5657862),
(1165, 70, 'DD', 'Dire Dawa', '製作藥物', '制药', 9.6008747, 41.8501420),
(1166, 70, 'GA', 'Gambela', '甘貝拉', '甘贝拉', 7.9219687, 34.1531947),
(1167, 70, 'HA', 'Harari', '哈拉利', '哈拉利', 9.3148660, 42.1967716),
(1168, 70, 'OR', 'Oromia', '奧羅米亞', '奥罗米亚', 7.5460377, 40.6346851),
(1169, 70, 'SO', 'Somali', '索馬里語', '索马里语', 6.6612293, 43.7908453),
(1170, 70, 'SN', 'Southern Nations, Nationalities, and Peoples\'', '南方國家、民族和人民', '南方国家、民族和人民', 6.5156911, 36.9541070),
(1171, 70, 'TI', 'Tigray', '提格雷', '提格雷', 14.0323336, 38.3165725),
(1172, 72, 'EY', 'Eysturoy', '艾斯圖羅伊', '艾斯图罗伊', 62.1978737, -7.1823906),
(1173, 72, 'NO', 'Northern Isles', '北方群島', '北方群岛', 62.2805689, 6.7017061),
(1174, 72, 'SA', 'Sandoy', '桑多伊', '桑多伊', 61.8365169, -6.9630166),
(1175, 72, 'ST', 'Streymoy', '斯特雷莫伊', '斯特雷莫伊', 62.1233820, -7.3264108),
(1176, 72, 'SU', 'Suðuroy', '蘇杜羅伊', '苏杜罗伊', 61.5211816, -7.0019014),
(1177, 72, 'VA', 'Vágar', '瓦加爾', 'Vágar', 62.0899835, -7.4276837),
(1178, 73, '01', 'Ba', '三', '三', 36.0613893, -95.8005872),
(1179, 73, '02', 'Bua', '布阿', '布阿', 43.0964584, -89.5008800),
(1180, 73, '03', 'Cakaudrove', '卡考德羅夫', '卡考德罗夫', -16.5814105, 179.5120084),
(1181, 73, 'C', 'Central', '中', '中央', 34.0440066, -118.2472738),
(1182, 73, 'E', 'Eastern', '東', '东部', 32.8094305, -117.1289937),
(1183, 73, '04', 'Kadavu', '卡達武', '卡达武', -19.0127122, 178.1876676),
(1184, 73, '05', 'Lau', '葉', '叶', 31.6687015, -106.3955763),
(1185, 73, '06', 'Lomaiviti', '洛邁維蒂', '洛迈维蒂', -17.7090000, 179.0910000),
(1186, 73, '07', 'Macuata', '馬庫塔', '马夸塔', -16.4864922, 179.2847251),
(1187, 73, '08', 'Nadroga-Navosa', '納德羅加-納沃薩', '纳德罗加-纳沃萨', -17.9865278, 177.6581130),
(1188, 73, '09', 'Naitasiri', '奈塔西里', '奈塔西里', -17.8975754, 178.2071598),
(1189, 73, '10', 'Namosi', '納莫西', '纳莫西', -18.0864176, 178.1291387),
(1190, 73, 'N', 'Northern', '北', '北方', 32.8768766, -117.2156345),
(1191, 73, '11', 'Ra', '拉', '拉', 37.1003153, -95.6744246),
(1192, 73, '12', 'Rewa', '雷瓦', '雷瓦', 34.7923517, -82.3609264),
(1193, 73, 'R', 'Rotuma', '羅圖馬', '罗图马', -12.5025069, 177.0724164),
(1194, 73, '13', 'Serua', '塞魯阿', '塞鲁阿', -18.1804749, 178.0509790),
(1195, 73, '14', 'Tailevu', '泰萊武', '泰莱武', -17.8269111, 178.2932480),
(1196, 73, 'W', 'Western', '西方的', '西方', 42.9662198, -78.7021134),
(1197, 74, '01', 'Åland Islands', '奧蘭群島', '奥兰群岛', 60.1785247, 19.9156105),
(1198, 74, '08', 'Central Finland', '芬蘭中部', '芬兰中部', 62.5666743, 25.5549445),
(1199, 74, '07', 'Central Ostrobothnia', '中東博特尼亞', '中奥博特尼亚', 63.5621735, 24.0013631),
(1200, 74, '19', 'Finland Proper', '芬蘭本土', '芬兰本土', 60.3627914, 22.4439369),
(1201, 74, '05', 'Kainuu', '凱努', '凯努', 64.3736564, 28.7437475),
(1202, 74, '09', 'Kymenlaakso', '凱門拉克索', '凯门拉克索', 60.7805120, 26.8829336),
(1203, 74, '10', 'Lapland', '拉普蘭', '拉普兰', 67.9222304, 26.5046438),
(1204, 74, '13', 'North Karelia', '北卡累利阿', '北卡累利阿', 62.8062078, 30.1553887),
(1205, 74, '14', 'Northern Ostrobothnia', '北東博特尼亞', '北东博特尼亚', 65.2794930, 26.2890417),
(1206, 74, '15', 'Northern Savonia', '北薩沃尼亞', '北萨沃尼亚', 63.0844800, 27.0253504),
(1207, 74, '12', 'Ostrobothnia', '東博特尼亞', '东博特尼亚', 63.1181757, 21.9061062),
(1208, 74, '16', 'Päijänne Tavastia', 'Päijänne Tavastia', 'Päijänne Tavastia', 61.3230041, 25.7322496),
(1209, 74, '11', 'Pirkanmaa', '皮爾坎瑪', '皮尔坎马', 61.6986918, 23.7895598),
(1210, 74, '17', 'Satakunta', '薩塔昆塔', '萨塔昆塔', 61.5932758, 22.1483081),
(1211, 74, '02', 'South Karelia', '南卡累利阿', '南卡累利阿', 61.1181949, 28.1024372),
(1212, 74, '03', 'Southern Ostrobothnia', '南東博特尼亞', '南博特尼亚', 62.9433099, 23.5285267),
(1213, 74, '04', 'Southern Savonia', '南薩沃尼亞', '南萨沃尼亚', 61.6945148, 27.8005015),
(1214, 74, '06', 'Tavastia Proper', '塔瓦斯蒂亞', '塔瓦斯蒂亚', 60.9070150, 24.3005498),
(1215, 74, '18', 'Uusimaa', '烏西馬', '乌西马', 60.2187200, 25.2716210),
(1216, 75, '01', 'Ain', '艾因', '氮化 铝', 46.0650860, 4.8886150),
(1217, 75, '02', 'Aisne', '埃納河', '埃纳河', 49.4528921, 3.0465111),
(1218, 75, '03', 'Allier', '聨', '盟友', 46.3670863, 2.5808277),
(1219, 75, '04', 'Alpes-de-Haute-Provence', '阿爾卑斯-上普羅旺斯', '阿尔卑斯-上普罗旺斯', 44.1637752, 5.6724780),
(1220, 75, '06', 'Alpes-Maritimes', '濱海阿爾卑斯省', '滨海阿尔卑斯省', 43.9204170, 6.6167822),
(1221, 75, '6AE', 'Alsace', '阿爾薩斯', '阿尔萨斯', 48.3181795, 7.4416241),
(1222, 75, '07', 'Ardèche', '阿爾代什', '阿尔代什', 44.8148695, 3.8133483),
(1223, 75, '08', 'Ardennes', '阿登', '阿登', 49.6975951, 4.1489576),
(1224, 75, '09', 'Ariège', '阿里耶日', '阿里耶日', 42.9434783, 0.9404864),
(1225, 75, '10', 'Aube', '旦', '黎明', 48.3197547, 3.5637104),
(1226, 75, '11', 'Aude', '奧德', '奥德', 43.0541140, 1.9038476),
(1227, 75, 'ARA', 'Auvergne-Rhône-Alpes', '奧弗涅-羅納-阿爾卑斯大區', '奥弗涅-罗纳-阿尔卑斯大区', 45.4471431, 4.3852507),
(1228, 75, '12', 'Aveyron', '阿韋龍', '阿韦龙', 44.3156362, 2.0852379),
(1229, 75, '67', 'Bas-Rhin', '下萊茵', '下莱茵', 48.5986444, 7.0266676),
(1230, 75, '13', 'Bouches-du-Rhône', '羅納河谷布歇', '罗纳河谷布歇', 43.5403865, 4.4613829),
(1231, 75, 'BFC', 'Bourgogne-Franche-Comté', '勃艮第-弗朗什-孔泰', '勃艮第-弗朗什-孔泰', 47.2805127, 4.9994372),
(1232, 75, 'BRE', 'Bretagne', '布列塔尼', '布列塔尼', 48.2020471, -2.9326435),
(1233, 75, '14', 'Calvados', '卡爾瓦多斯', '卡尔瓦多斯', 49.0903514, -0.9170648),
(1234, 75, '15', 'Cantal', '康塔爾', '康塔尔', 45.0492177, 2.1567272),
(1235, 75, 'CVL', 'Centre-Val de Loire', '盧瓦爾河谷中心', '卢瓦尔河谷中心', 47.7515686, 1.6750631),
(1236, 75, '16', 'Charente', '夏朗德', '夏朗德省', 45.6658479, -0.3184577),
(1237, 75, '17', 'Charente-Maritime', '濱海夏朗德省', '滨海夏朗德省', 45.7296828, -1.3388116),
(1238, 75, '18', 'Cher', '貴', '贵', 47.0243628, 1.8662732),
(1239, 75, 'CP', 'Clipperton', '克利珀頓', '克利珀顿', 10.2833541, -109.2254215),
(1240, 75, '19', 'Corrèze', '科雷茲', '科雷兹', 45.3423707, 1.3171733),
(1241, 75, '20R', 'Corse', '科西嘉島', '科西嘉岛', 42.0396042, 9.0128926),
(1242, 75, '2A', 'Corse-du-Sud', '南科西嘉島', '南科西嘉岛', 41.8572055, 8.4109183),
(1243, 75, '21', 'Côte-d\'Or', '科特德', '科特德', 47.4651302, 4.2315495),
(1244, 75, '22', 'Côtes-d\'Armor', '科特德', '科特德', 48.4663336, -3.3478961),
(1245, 75, '23', 'Creuse', '克魯斯', '克鲁斯', 46.0590394, 1.4315050),
(1246, 75, '79', 'Deux-Sèvres', '雙塞夫爾', '双塞夫尔', 46.5386817, -0.9019948),
(1247, 75, '24', 'Dordogne', '多爾多涅省', '多尔多涅省', 45.1423416, 0.1427408),
(1248, 75, '25', 'Doubs', '杜布斯', '杜布斯', 46.9321774, 6.3476214),
(1249, 75, '26', 'Drôme', '德龍', '德龙', 44.7293357, 4.6782158),
(1250, 75, '91', 'Essonne', '埃松', '埃松', 48.5304615, 1.9699056),
(1251, 75, '27', 'Eure', '尒', '你', 49.0754035, 0.4893732),
(1252, 75, '28', 'Eure-et-Loir', '尤爾-盧瓦爾', '尤尔-卢瓦', 48.4469784, 0.8147025),
(1253, 75, '29', 'Finistère', '菲尼斯泰爾', '菲尼斯泰尔', 48.2269610, -4.8243733),
(1254, 75, '973', 'French Guiana', '法屬圭亞那', '法属圭亚那', 3.9338890, -53.1257820),
(1255, 75, 'PF', 'French Polynesia', '法屬玻里尼西亞', '法属波利尼西亚', -17.6797420, -149.4068430),
(1256, 75, 'TF', 'French Southern and Antarctic Lands', '法屬南部和南極地區', '法属南部和南极陆地', -47.5446604, 51.2837542),
(1257, 75, '30', 'Gard', '加德', '加德', 43.9595276, 3.4935681),
(1258, 75, '32', 'Gers', '熱爾', '热尔', 43.6950534, -0.0999728),
(1259, 75, '33', 'Gironde', '吉倫特', '吉伦特省', 44.8958469, -1.5940532),
(1260, 75, 'GES', 'Grand-Est', '格蘭德-埃斯特', '格兰德-埃斯特', 48.6998030, 6.1878074),
(1261, 75, '971', 'Guadeloupe', '瓜德羅普島', '瓜德罗普', 16.2650000, -61.5510000),
(1262, 75, '68', 'Haut-Rhin', '上萊茵', '上莱茵', 47.8653774, 6.6711381),
(1263, 75, '2B', 'Haute-Corse', '上科西嘉', '上科西嘉', 42.4295866, 8.5062561),
(1264, 75, '31', 'Haute-Garonne', '上加龍省', '上加龙省', 43.3050555, 0.6845515),
(1265, 75, '43', 'Haute-Loire', '上盧瓦爾河', '上卢瓦尔河', 45.0853806, 3.2260707),
(1266, 75, '52', 'Haute-Marne', '上馬恩省', '上马恩省', 48.1324821, 4.6983499),
(1267, 75, '70', 'Haute-Saône', '上索恩', '上索恩', 47.6378996, 5.5355055),
(1268, 75, '74', 'Haute-Savoie', '上薩瓦省', '上萨瓦省', 46.0445277, 5.8641380),
(1269, 75, '87', 'Haute-Vienne', '上維也納', '上维也纳', 45.9186878, 0.7097206),
(1270, 75, '05', 'Hautes-Alpes', '上阿爾卑斯山', '上阿尔卑斯山', 44.6562682, 5.6873211),
(1271, 75, '65', 'Hautes-Pyrénées', '上比利牛斯山脈', '上比利牛斯山脉', 43.1429462, -0.4009736),
(1272, 75, 'HDF', 'Hauts-de-France', '上法蘭西大區', '上法兰西岛', 50.4801153, 2.7937265),
(1273, 75, '92', 'Hauts-de-Seine', '上塞納河', '上塞纳河', 48.8403008, 2.1012559),
(1274, 75, '34', 'Hérault', '埃羅', '埃罗', 43.5911120, 2.8066108),
(1275, 75, 'IDF', 'Île-de-France', '法蘭西島', '法兰西岛', 48.8499198, 2.6370411),
(1276, 75, '35', 'Ille-et-Vilaine', '伊勒-維萊恩', 'Ille-et-Vilaine', 48.1762484, -2.2130401),
(1277, 75, '36', 'Indre', '內', '内', 46.8117550, 0.9755523),
(1278, 75, '37', 'Indre-et-Loire', '安德爾-盧瓦爾河', '安德尔-卢瓦尔河', 47.2228582, 0.1489619),
(1279, 75, '38', 'Isère', '伊澤爾', '伊泽尔', 45.2892271, 4.9902355),
(1280, 75, '39', 'Jura', '典', '法律', 46.7828741, 5.1691844),
(1281, 75, '974', 'La Réunion', '留尼汪島', '留尼汪', -21.1151410, 55.5363840),
(1282, 75, '40', 'Landes', '蘭德斯', '朗德', 44.0095080, -1.2538579),
(1283, 75, '41', 'Loir-et-Cher', '盧瓦雪爾', '卢瓦-谢尔', 47.6593760, 0.8537631),
(1284, 75, '42', 'Loire', '盧瓦爾河', '卢瓦尔', 46.3522812, -1.1756339),
(1285, 75, '44', 'Loire-Atlantique', '大西洋盧瓦爾河', '大西洋卢瓦尔河', 47.3475721, -2.3466312),
(1286, 75, '45', 'Loiret', '盧瓦雷', '卢瓦雷', 47.9135431, 1.7600990),
(1287, 75, '46', 'Lot', '籤', '很多', 44.6246070, 1.0357631),
(1288, 75, '47', 'Lot-et-Garonne', '洛特-加龍', '洛特-加龙', 44.3687314, -0.0916169),
(1289, 75, '48', 'Lozère', '洛澤爾', '洛泽尔', 44.5422779, 2.9293459),
(1290, 75, '49', 'Maine-et-Loire', '緬因-盧瓦爾河', '缅因-卢瓦尔河', 47.3890034, -1.1202527),
(1291, 75, '50', 'Manche', '一些', '一些', 49.0881734, -2.4627209),
(1292, 75, '51', 'Marne', '泥灰岩', '泥灰岩', 48.9610745, 3.6573767),
(1293, 75, '972', 'Martinique', '馬提尼克島', '马提尼克', 14.6415280, -61.0241740),
(1294, 75, '53', 'Mayenne', '馬耶訥', '马耶讷', 48.3066842, -0.6490182),
(1295, 75, '976', 'Mayotte', '馬約特島', '马约特', -12.8275000, 45.1662440),
(1296, 75, '69M', 'Métropole de Lyon', '里昂大都會', '里昂大都会', 45.7482629, 4.5958404),
(1297, 75, '54', 'Meurthe-et-Moselle', '默爾特-摩澤爾', '默尔特-摩泽尔', 48.9556615, 5.7142350),
(1298, 75, '55', 'Meuse', '默茲', '默兹', 49.0124620, 4.8108734),
(1299, 75, '56', 'Morbihan', '莫爾比昂', '莫尔比昂', 47.7439518, -3.4455524),
(1300, 75, '57', 'Moselle', '摩澤爾', '摩泽尔', 49.0204566, 6.2055322),
(1301, 75, '58', 'Nièvre', '尼夫爾', '涅夫尔', 47.1192164, 2.9779713),
(1302, 75, '59', 'Nord', '北', '北', 50.5285477, 2.6000776),
(1303, 75, 'NOR', 'Normandie', '諾曼第（Normandy）', '诺曼底', 48.8798704, 0.1712529),
(1304, 75, 'NAQ', 'Nouvelle-Aquitaine', '新阿基坦', '新阿基坦', 45.7087182, 0.6268910),
(1305, 75, 'OCC', 'Occitanie', '奧克西塔尼', '奥克西塔尼', 43.8927232, 3.2827625),
(1306, 75, '60', 'Oise', '瓦茲', '瓦兹', 49.4117335, 1.8668825),
(1307, 75, '61', 'Orne', '奧恩', '奥恩', 48.5757644, -0.5024295),
(1308, 75, '75C', 'Paris', '巴黎', '巴黎', 48.8566140, 2.3522219),
(1309, 75, '62', 'Pas-de-Calais', '加來海峽', '加来海峡', 50.5144699, 1.8114980),
(1310, 75, 'PDL', 'Pays-de-la-Loire', '盧瓦爾河地區', '卢瓦尔河地区', 47.7632836, -0.3299687),
(1311, 75, 'PAC', 'Provence-Alpes-Côte-d’Azur', '普羅旺斯-阿爾卑斯-蔚藍海岸', '普罗旺斯-阿尔卑斯-蔚蓝海岸', 43.9351691, 6.0679194),
(1312, 75, '63', 'Puy-de-Dôme', '多姆島', '多姆广场', 45.7714185, 2.6262676),
(1313, 75, '64', 'Pyrénées-Atlantiques', '比利牛斯-大西洋', '比利牛斯-大西洋', 43.1868170, -1.4417071),
(1314, 75, '66', 'Pyrénées-Orientales', '東比利牛斯山脈', '东比利牛斯-东比利牛斯', 42.6254179, 1.8892958),
(1315, 75, '69', 'Rhône', '羅納河谷', '罗纳河谷', 44.9343300, 4.2409329),
(1316, 75, 'PM', 'Saint Pierre and Miquelon', '聖皮埃爾和密克隆群島', '圣皮埃尔和密克隆群岛', 46.8852000, -56.3159000),
(1317, 75, 'BL', 'Saint-Barthélemy', '聖巴泰勒米', '圣巴泰勒米', 17.9005134, -62.8205871),
(1318, 75, 'MF', 'Saint-Martin', '聖馬丁', '圣马丁', 18.0708298, -63.0500809),
(1319, 75, '71', 'Saône-et-Loire', '索恩-盧瓦爾河', '索恩-卢瓦尔河', 46.6554883, 3.9835050),
(1320, 75, '72', 'Sarthe', '薩爾特', '萨尔特', 48.0262733, -0.3261317),
(1321, 75, '73', 'Savoie', '薩瓦省', '萨瓦省', 45.4946990, 5.8432984),
(1322, 75, '77', 'Seine-et-Marne', '塞納-馬恩省', '塞纳-马恩省', 48.6185394, 2.4152561),
(1323, 75, '76', 'Seine-Maritime', '濱海塞納河', '滨海塞纳河', 49.6609681, 0.3677561),
(1324, 75, '93', 'Seine-Saint-Denis', '塞納-聖但尼', '塞纳-圣但尼', 48.9099318, 2.3057379),
(1325, 75, '80', 'Somme', '金額', '和', 49.9685922, 1.7310696),
(1326, 75, '81', 'Tarn', '塔恩', '塔恩', 43.7914977, 1.6758893),
(1327, 75, '82', 'Tarn-et-Garonne', '塔恩-加龍', '塔恩-加龙', 44.0808950, 1.0891657),
(1328, 75, '90', 'Territoire de Belfort', '貝爾福領土', '贝尔福领土', 47.6293072, 6.6696200),
(1329, 75, '95', 'Val-d\'Oise', '瓦爾德', '瓦尔德', 49.0751818, 1.8216914),
(1330, 75, '94', 'Val-de-Marne', '馬恩河谷', '马恩河谷', 48.7747004, 2.3221039),
(1331, 75, '83', 'Var', '變', '变量', 43.3950730, 5.7342417),
(1332, 75, '84', 'Vaucluse', '沃克呂茲', '沃克吕兹', 44.0447500, 4.6427718),
(1333, 75, '85', 'Vendée', '旺代', '旺代', 46.6754103, -2.0298392),
(1334, 75, '86', 'Vienne', '維也納', '维也纳', 45.5221314, 4.8453136),
(1335, 75, '88', 'Vosges', '孚日', '孚日', 48.1630173, 5.7355600),
(1336, 75, 'WF', 'Wallis and Futuna', '瓦利斯和富圖納群島', '瓦利斯和富图纳群岛', -14.2938000, -178.1165000),
(1337, 75, '89', 'Yonne', '約訥', '约讷', 47.8547614, 3.0339404),
(1338, 75, '78', 'Yvelines', '伊夫林', '伊夫林', 48.7615301, 1.2772949),
(1339, 77, '01', 'Austral Islands', '南極群島', '南极群岛', -24.6210877, -154.7915586),
(1340, 77, '02', 'Leeward Islands', '背風群島', '背风群岛', -16.3314442, -155.4577062),
(1341, 77, '03', 'Marquesas Islands', '馬克薩斯群島', '马克萨斯群岛', -9.1785299, -140.9767026),
(1342, 77, '04', 'Tuamotu-Gambier', '圖阿莫圖-甘比爾', '图阿莫图-甘比尔', -18.3207157, -152.4487166),
(1343, 77, '05', 'Windward Islands', '向風群島', '向风群岛', -17.4253967, -150.6780227),
(1344, 79, '1', 'Estuaire', '河口', '河口', 0.4432864, 10.0807298),
(1345, 79, '2', 'Haut-Ogooué', '上奧古韋', '上奥古韦', -1.4762544, 13.9143990),
(1346, 79, '3', 'Moyen-Ogooué', '莫延-奧古韋', '莫延-奥古韦', -0.4427840, 10.4396560),
(1347, 79, '4', 'Ngounié', '恩古尼埃', '恩古尼埃', -1.4930303, 10.9807003),
(1348, 79, '5', 'Nyanga', '尼揚加', '尼扬加', -2.8821033, 11.1617356),
(1349, 79, '6', 'Ogooué-Ivindo', '奧古韋-伊文多', 'Ogooué-Ivindo', 0.8818311, 13.1740348),
(1350, 79, '7', 'Ogooué-Lolo', '奧古韋-洛洛', '奥古韦-洛洛', -0.8844093, 12.4380581),
(1351, 79, '8', 'Ogooué-Maritime', '奧古韋-海事', 'Ogooué-Maritime', -1.3465975, 9.7232673),
(1352, 79, '9', 'Woleu-Ntem', '沃勒烏-恩特姆', '沃勒恩特姆', 2.2989827, 11.4466914),
(1353, 81, 'AB', 'Abkhazia', '阿布哈茲', '阿布哈兹', 43.0015544, 41.0234070),
(1354, 81, 'AJ', 'Adjara', '阿扎拉', '阿扎尔', 41.6005626, 42.0688383),
(1355, 81, 'GU', 'Guria', '古里亞', '古里亚', 41.9442736, 42.0458091),
(1356, 81, 'IM', 'Imereti', '伊梅雷蒂', '伊梅雷蒂', 42.2301080, 42.9008664),
(1357, 81, 'KA', 'Kakheti', '卡赫季', '卡赫季', 41.6481602, 45.6905554),
(1358, 81, 'KK', 'Kvemo Kartli', '克維莫·卡特利', '克维莫·卡特利', 41.4791833, 44.6560451),
(1359, 81, 'MM', 'Mtskheta-Mtianeti', '姆茨赫塔-姆蒂亞內蒂', '姆茨赫塔-姆蒂亚内季', 42.1682185, 44.6506058),
(1360, 81, 'RL', 'Racha-Lechkhumi and Kvemo Svaneti', '拉查-萊赫胡米和克維莫·斯瓦涅蒂', 'Racha-Lechkhumi 和 Kvemo Svaneti', 42.6718873, 43.0562836),
(1361, 81, 'SZ', 'Samegrelo-Zemo Svaneti', '薩梅格雷洛-澤莫·斯瓦涅蒂', '萨梅格雷洛-泽莫·斯瓦涅蒂', 42.7352247, 42.1689362),
(1362, 81, 'SJ', 'Samtskhe-Javakheti', '薩姆茨赫-賈瓦赫季', '萨姆茨赫-爪哇赫季', 41.5479296, 43.2776400),
(1363, 81, 'SK', 'Shida Kartli', '希達·卡特利', '史达·卡特利', 42.0756944, 43.9540462),
(1364, 81, 'TB', 'Tbilisi', '第比利斯', '第比利斯', 41.7151377, 44.8270960),
(1365, 82, 'BW', 'Baden-Württemberg', '巴登-符騰堡州', '巴登-符腾堡州', 48.6616037, 9.3501336),
(1366, 82, 'BY', 'Bavaria', '巴伐利亞', '巴伐利亚', 48.7904472, 11.4978895),
(1367, 82, 'BE', 'Berlin', '柏林', '柏林', 52.5200066, 13.4049540),
(1368, 82, 'BB', 'Brandenburg', '勃蘭登堡', '勃兰登堡', 52.4125287, 12.5316444),
(1369, 82, 'HB', 'Bremen', '不來梅', '不来梅', 53.0792962, 8.8016936),
(1370, 82, 'HH', 'Hamburg', '漢堡', '汉堡', 53.5510846, 9.9936819),
(1371, 82, 'HE', 'Hessen', '黑森州', '黑森', 50.6520515, 9.1624376),
(1372, 82, 'NI', 'Lower Saxony', '下薩克森州', '下萨克森', 52.6367036, 9.8450766),
(1373, 82, 'MV', 'Mecklenburg-Vorpommern', '梅克倫堡-前波莫瑞州', '梅克伦堡-前波莫瑞州', 53.6126505, 12.4295953),
(1374, 82, 'NW', 'North Rhine-Westphalia', '北萊茵-威斯特法倫州', '北莱茵-威斯特法伦州', 51.4332367, 7.6615938),
(1375, 82, 'RP', 'Rhineland-Palatinate', '萊茵蘭-普法爾茨州', '莱茵兰-普法尔茨州', 50.1183460, 7.3089527),
(1376, 82, 'SL', 'Saarland', '薩爾州', '萨尔州', 49.3964234, 7.0229607),
(1377, 82, 'SN', 'Saxony', '薩克森州', '萨克森', 51.1045407, 13.2017384),
(1378, 82, 'ST', 'Saxony-Anhalt', '薩克森-安哈爾特州', '萨克森-安哈尔特州', 51.9502649, 11.6922734),
(1379, 82, 'SH', 'Schleswig-Holstein', '石勒蘇益格-荷爾斯泰因州', '石勒苏益格-荷尔斯泰因州', 54.2193672, 9.6961167),
(1380, 82, 'TH', 'Thuringia', '圖林根州', '图林根州', 51.0109892, 10.8453460),
(1381, 83, 'AF', 'Ahafo', '阿哈福', '阿哈福', 7.5821372, -2.5497463),
(1382, 83, 'AH', 'Ashanti', '阿散蒂', '阿散蒂', 6.7470436, -1.5208624),
(1383, 83, 'BO', 'Bono', '波諾', '波诺', 7.6500000, -2.5000000),
(1384, 83, 'BE', 'Bono East', '波諾東', '波诺东', 7.7500000, -1.0500000),
(1385, 83, 'CP', 'Central', '中', '中央', 5.5000000, -1.0000000),
(1386, 83, 'EP', 'Eastern', '東', '东部', 6.5000000, -0.5000000),
(1387, 83, 'AA', 'Greater Accra', '大阿克拉', '大阿克拉', 5.8142836, 0.0746767),
(1388, 83, 'NE', 'North East', '東北', '东北', 10.5166670, -0.3666670),
(1389, 83, 'NP', 'Northern', '北', '北方', 9.5000000, -1.0000000),
(1390, 83, 'OT', 'Oti', '熟', '做', 7.9000000, 0.3000000),
(1391, 83, 'SV', 'Savannah', '薩凡納', '萨凡纳', 9.0833330, -1.8166670),
(1392, 83, 'UE', 'Upper East', '上東區', '上东区', 10.7082499, -0.9820668),
(1393, 83, 'UW', 'Upper West', '上西區', '上西区', 10.2529757, -2.1450245),
(1394, 83, 'TV', 'Volta', '時間', '时间', 6.5781373, 0.4502368),
(1395, 83, 'WP', 'Western', '西方的', '西方', 5.5000000, -2.5000000),
(1396, 83, 'WN', 'Western North', '西北', '西北', 6.3000000, -2.8000000),
(1397, 85, '13', 'Achaea', '亞該亞', '亚该亚', 38.1158729, 21.9522491),
(1398, 85, '01', 'Aetolia-Acarnania', '埃托利亞-阿卡納尼亞', '埃托利亚-阿卡纳尼亚', 38.7084386, 21.3798928),
(1399, 85, '12', 'Arcadia', '阿卡迪亞', '世外桃源', 37.5557825, 22.3337769),
(1400, 85, '11', 'Argolis', '阿戈利斯', '阿戈利斯', 37.5710970, 22.2634737),
(1401, 85, 'I', 'Attica', '阿提卡', '阿提卡', 38.0457568, 23.8584737),
(1402, 85, '03', 'Boeotia', '維奧蒂亞', '维奥蒂亚', 38.3663664, 23.0965064),
(1403, 85, 'H', 'Central Greece', '希臘中部', '希腊中部', 38.6043984, 22.7152131),
(1404, 85, 'B', 'Central Macedonia', '馬其頓中部', '中马其顿', 40.6211730, 23.1918021),
(1405, 85, '94', 'Chania', '干尼亞', '干尼亚', 35.5138298, 24.0180367),
(1406, 85, '22', 'Corfu', '科孚島', '科孚岛', 39.6249838, 19.9223461),
(1407, 85, '15', 'Corinthia', '科林西亞', '科林西亚', 37.9206431, 22.0396553),
(1408, 85, 'M', 'Crete', '克里特島', '克里特', 35.2401170, 24.8092691),
(1409, 85, '52', 'Drama', '劇', '戏剧', 41.2340023, 24.2390498),
(1410, 85, 'A2', 'East Attica', '東阿提卡', '东阿提卡', 38.2054093, 23.8584737),
(1411, 85, 'A', 'East Macedonia and Thrace', '東馬其頓和色雷斯', '东马其顿和色雷斯', 41.1295126, 24.8877191),
(1412, 85, 'D', 'Epirus', '伊庇魯斯', '伊庇鲁斯', 39.5706413, 20.7642843),
(1413, 85, '04', 'Euboea', '優卑亞', '优卑亚', 38.5236036, 23.8584737),
(1414, 85, '51', 'Grevena', '格雷維娜', '格雷维娜', 40.0837626, 21.4273299),
(1415, 85, '53', 'Imathia ', '伊馬西亞', '伊马西亚', 40.6060067, 22.1430215),
(1416, 85, '33', 'Ioannina', '約阿尼納', '约阿尼纳', 39.6650288, 20.8537466),
(1417, 85, 'F', 'Ionian Islands', '愛奧尼亞群島', '爱奥尼亚群岛', 37.9694898, 21.3802372),
(1418, 85, '41', 'Karditsa', '卡迪察', '卡迪察', 39.3640258, 21.9214049),
(1419, 85, '56', 'Kastoria', '卡斯托里亞', '卡斯托里亚', 40.5192691, 21.2687171),
(1420, 85, '23', 'Kefalonia', '凱法利尼亞', '凯法利尼亚', 38.1753675, 20.5692179),
(1421, 85, '57', 'Kilkis', '基爾基斯', '基尔基斯', 40.9937071, 22.8753674),
(1422, 85, '58', 'Kozani', '科扎尼', '科扎尼', 40.3005586, 21.7887737),
(1423, 85, '16', 'Laconia', '拉科尼亞', '拉科尼亚', 43.5278546, -71.4703509),
(1424, 85, '42', 'Larissa', '拉里薩', '拉里萨', 39.6390224, 22.4191254),
(1425, 85, '24', 'Lefkada', '吹', '吹', 38.8333663, 20.7069108),
(1426, 85, '59', 'Pella', '佩拉', '佩拉', 40.9148039, 22.1430215),
(1427, 85, 'J', 'Peloponnese', '伯羅奔尼撒半島', '伯罗奔尼撒半岛', 37.5079472, 22.3734900),
(1428, 85, '06', 'Phthiotis', 'Phthiotis', 'Phthiotis', 38.9997850, 22.3337769),
(1429, 85, '34', 'Preveza', '普雷韋扎', '普雷韦扎', 38.9592649, 20.7517155),
(1430, 85, '62', 'Serres', '溫室', '温室', 41.0863854, 23.5483819),
(1431, 85, 'L', 'South Aegean', '南愛琴海', '南爱琴海', 37.0855302, 25.1489215),
(1432, 85, '54', 'Thessaloniki', '塞薩洛尼基', '塞萨洛尼基', 40.6400629, 22.9444191),
(1433, 85, 'G', 'West Greece', '西希臘', '西希腊', 38.5115496, 21.5706786),
(1434, 85, 'C', 'West Macedonia', '西馬其頓', '西马其顿', 40.3004058, 21.7903559),
(1435, 86, 'AV', 'Avannaata', '阿凡納塔', '阿凡纳塔', 74.1026743, -78.9875560),
(1436, 86, 'KU', 'Kujalleq', '庫賈勒克', '库贾勒克', 61.1666693, -50.5099788),
(1437, 86, 'QT', 'Qeqertalik', 'Qeqertalik', 'Qeqertalik', 68.8249553, -54.7622472),
(1438, 86, 'QE', 'Qeqqata', '蓋卡塔', '盖卡塔', 66.0805719, -54.2654639),
(1439, 86, 'SM', 'Sermersooq', '塞爾默蘇克', 'Sermersooq', 65.0823058, -57.2831195),
(1440, 87, '10', 'Carriacou', '卡里亞庫', '卡里亚库', 12.4828971, -61.5010261),
(1441, 87, '01', 'Saint Andrew', '聖安德魯', '圣安德鲁', 12.1109373, -61.7293504),
(1442, 87, '02', 'Saint David', '聖大衛', '圣大卫', 12.0412125, -61.7173042),
(1443, 87, '03', 'Saint George', '聖喬治', '圣乔治', 12.0478824, -61.8313189),
(1444, 87, '04', 'Saint John', '聖約翰', '圣约翰', 12.1431983, -61.7585737),
(1445, 87, '05', 'Saint Mark', '聖馬可', '圣马可', 12.1857764, -61.7384148),
(1446, 87, '06', 'Saint Patrick', '聖派翠克', '圣帕特里克', 12.2489648, -61.6957848),
(1447, 88, '01', 'Basse-Terre', '巴斯特雷', '巴斯特雷', 16.1011019, -62.0054546),
(1448, 88, '02', 'Pointe-à-Pitre', '皮特爾角', '皮特尔角', 16.1902438, -61.6291713);
INSERT INTO `location_states` (`state_id`, `country_id`, `state_code`, `state_name_en`, `state_name_zh_tw`, `state_name_zh_cn`, `state_center_latitude`, `state_center_longitude`) VALUES
(1449, 89, '', 'Agana Heights', '阿加納高地', '阿加纳高地', 13.4657592, 144.7319533),
(1450, 89, '', 'Asan-Maina', '牙山-邁納', '牙山-迈纳', 13.4729124, 144.7118041),
(1451, 89, '', 'Barrigada', '肚子', '肚皮', 13.4641827, 144.7882247),
(1452, 89, '', 'Chalan Pago-Ordot', '查蘭·帕戈-奧爾多', '查兰·帕戈-奥尔多', 13.4369980, 144.7486708),
(1453, 89, '', 'Dededo', '德德多', '德迪多', 13.5228990, 144.7989287),
(1454, 89, '', 'Hågat', '記得', '记得', 13.3852224, 144.6399698),
(1455, 89, '', 'Hagåtña', '哈加特尼亞', '哈加特尼亚', 13.4729829, 144.7274038),
(1456, 89, '', 'Inarajan (Inalåhan)', '伊納拉詹 （Inalåhan）', 'Inarajan （Inalåhan）', 13.2762049, 144.7203863),
(1457, 89, '', 'Mangilao', '曼吉勞', '曼吉劳', 13.4498509, 144.7830268),
(1458, 89, '', 'Merizo (Malesso)', '梅里佐（馬萊索）', '梅里佐（马莱索）', 13.2686085, 144.6579749),
(1459, 89, '', 'Mongmong-Toto-Maite', '蒙蒙-托托-邁特', '蒙蒙-托托-迈特', 13.4692201, 144.7533808),
(1460, 89, '', 'Piti', '有', '有', 13.4647446, 144.6876982),
(1461, 89, '', 'Santa Rita (Sånta Rita-Sumai)', '聖麗塔 （Sånta Rita-Sumai）', '圣丽塔 （Sånta Rita-Sumai）', 13.3867874, 144.6664227),
(1462, 89, '', 'Sinajana', '西納迦那', '西纳贾纳', 13.4609486, 144.7461208),
(1463, 89, '', 'Talofofo (Talo\'fo\'fo)', '塔洛福福 （Talo', '塔洛福福 （Talo', 13.3547144, 144.7345973),
(1464, 89, '', 'Tamuning', '塔穆寧', '塔穆宁', 13.4944762, 144.7804582),
(1465, 89, '', 'Umatac (Humåtak)', '烏馬塔克 （Humåtak）', '乌马塔克 （Humåtak）', 13.2945777, 144.6538283),
(1466, 89, '', 'Yigo', '伊戈', '伊戈', 13.5729377, 144.8231522),
(1467, 89, '', 'Yona', '尤娜', '尤娜', 13.4102060, 144.7555747),
(1468, 90, '16', 'Alta Verapaz ', '阿爾塔維拉帕斯', '阿尔塔维拉帕斯', 15.5942883, -90.1494988),
(1469, 90, '15', 'Baja Verapaz ', '下維拉帕斯', '下维拉帕斯', 15.1255867, -90.3748354),
(1470, 90, '04', 'Chimaltenango ', '奇馬爾特南戈', '奇马尔特南戈', 14.5634787, -90.9820668),
(1471, 90, '20', 'Chiquimula ', '奇基穆拉', '奇基穆拉', 14.7514999, -89.4742177),
(1472, 90, '02', 'El Progreso ', '進步', '进展', 14.9388732, -90.0746767),
(1473, 90, '05', 'Escuintla ', '埃斯昆特拉', '埃斯昆特拉', 14.1910912, -90.9820668),
(1474, 90, '01', 'Guatemala ', '瓜地馬拉', '危地马拉', 14.5649401, -90.5257823),
(1475, 90, '13', 'Huehuetenango ', '韋韋特南戈', '韦韦特南戈', 15.5879914, -91.6760691),
(1476, 90, '18', 'Izabal ', '伊薩巴爾', '伊萨巴尔', 15.4976517, -88.8646980),
(1477, 90, '21', 'Jalapa ', '哈拉帕', '哈拉帕', 14.6121446, -89.9626799),
(1478, 90, '22', 'Jutiapa ', '朱蒂亞帕', '朱蒂亚帕', 14.1930802, -89.9253233),
(1479, 90, '17', 'Petén ', '佩滕', '佩滕', 16.9120330, -90.2995785),
(1480, 90, '09', 'Quetzaltenango ', '羽蛇特南戈', '羽蛇特南戈', 14.7924330, -91.7149580),
(1481, 90, '14', 'Quiché ', '基切', '基切', 15.4983808, -90.9820668),
(1482, 90, '11', 'Retalhuleu ', '雷塔胡勒烏', '雷塔胡勒', 14.5245485, -91.6857880),
(1483, 90, '03', 'Sacatepéquez ', '薩卡特佩克斯', '萨卡特佩克斯', 14.5178379, -90.7152749),
(1484, 90, '12', 'San Marcos ', '聖馬科斯', '圣马科斯', 14.9309569, -91.9099238),
(1485, 90, '06', 'Santa Rosa ', '聖羅莎', '圣罗莎', 38.4405759, -122.7037543),
(1486, 90, '07', 'Sololá ', '索羅拉', 'Sololá', 14.7485230, -91.2891036),
(1487, 90, '10', 'Suchitepéquez ', 'Suchitepéquez', 'Suchitepéquez', 14.4215982, -91.4048249),
(1488, 90, '08', 'Totonicapán ', '托托尼卡潘', '托托尼卡潘', 14.9173402, -91.3613923),
(1489, 90, '19', 'Zacapa', '薩卡帕', '萨卡帕', 15.0092828, -89.9253233),
(1490, 91, '04', 'Alderney', '奧爾德尼島', '奥尔德尼岛', 49.7163710, -2.2403370),
(1491, 91, '01', 'Castel', '卡斯特爾', '卡斯特尔', 49.4666381, -2.6378501),
(1492, 91, '02', 'Forest', '森林', '森林', 49.4267793, -2.6170045),
(1493, 91, '07', 'Sark', '薩克號', '萨克', 49.4254252, -2.4099527),
(1494, 91, '03', 'St Andrew', '聖安德魯', '圣安德鲁', 49.4505853, -2.6020413),
(1495, 91, '05', 'St Martin', '聖馬丁', '圣马丁', 49.4337659, -2.5979965),
(1496, 91, '06', 'St Peter Port', '聖彼得港', '圣彼得港', 49.4592277, -2.5860930),
(1497, 91, '08', 'St Pierre du Bois', '聖皮埃爾·杜布瓦', '圣皮埃尔杜布瓦', 49.4411922, -2.6843855),
(1498, 91, '09', 'St Sampson', '聖桑普森', '圣桑普森', 49.4844202, -2.5810319),
(1499, 91, '10', 'St Saviour', '聖救世主', '圣救世主', 49.4511444, -2.6597752),
(1500, 91, '11', 'Torteval', '托爾特瓦爾', '托尔特瓦尔', 49.4288587, -2.6899094),
(1501, 91, '12', 'Vale', '山谷', '山谷', 49.4884605, -2.5807577),
(1502, 92, 'BE', 'Beyla', '貝拉', '贝拉', 8.9198178, -8.3088441),
(1503, 92, 'BF', 'Boffa', '博法', '博法', 10.1808254, -14.0391615),
(1504, 92, 'B', 'Boké', '博克', '博克', 11.1864672, -14.1001326),
(1505, 92, 'BK', 'Boké', '博克', '博克', 11.0847379, -14.3791912),
(1506, 92, 'C', 'Conakry', '科納克里', '科纳克里', 9.6411855, -13.5784012),
(1507, 92, 'CO', 'Coyah', '科亞', '科亚', 9.7715535, -13.3125299),
(1508, 92, 'DB', 'Dabola', '達博拉', '达博拉', 10.7297806, -11.1107854),
(1509, 92, 'DL', 'Dalaba', '達拉巴', '达拉巴', 10.6868176, -12.2490697),
(1510, 92, 'DI', 'Dinguiraye', '丁吉拉耶', '丁吉拉耶', 11.6844222, -10.8000051),
(1511, 92, 'DU', 'Dubréka', '杜布雷卡', '杜布雷卡', 9.7907348, -13.5147735),
(1512, 92, 'F', 'Faranah', '法拉納', '法拉纳', 10.5473035, -11.8507644),
(1513, 92, 'FA', 'Faranah', '法拉納', '法拉纳', 9.9057399, -10.8000051),
(1514, 92, 'FO', 'Forécariah', '福雷卡里亞', 'Forécariah', 9.3886187, -13.0817903),
(1515, 92, 'FR', 'Fria', '冷', '冷', 10.3674543, -13.5841871),
(1516, 92, 'GA', 'Gaoual', '高阿爾', '高阿尔', 11.5762804, -13.3587288),
(1517, 92, 'GU', 'Guéckédou', '蓋凱杜', '盖凯杜', 8.5649688, -10.1311163),
(1518, 92, 'KA', 'Kankan', '坎坎', '康康', 10.3034465, -9.3673084),
(1519, 92, 'K', 'Kankan', '坎坎', '康康', 10.1209230, -9.5450974),
(1520, 92, 'KE', 'Kérouané', 'Kérouané', 'Kérouané', 9.2536643, -9.0128926),
(1521, 92, 'D', 'Kindia', '金迪亞', '金迪亚', 10.1781694, -12.9896150),
(1522, 92, 'KD', 'Kindia', '金迪亞', '金迪亚', 10.1013292, -12.7135121),
(1523, 92, 'KS', 'Kissidougou', '基西杜古', '基西杜古', 9.2252022, -10.0807298),
(1524, 92, 'KB', 'Koubia', '庫比亞', '库比亚', 11.5823540, -11.8920237),
(1525, 92, 'KN', 'Koundara', '孔達拉', '孔达拉', 12.4894021, -13.3067562),
(1526, 92, 'KO', 'Kouroussa', '庫魯薩', '库鲁萨', 10.6489229, -9.8850586),
(1527, 92, 'LA', 'Labé', '實驗室', '实验室', 11.3541939, -12.3463875),
(1528, 92, 'L', 'Labé', '實驗室', '实验室', 11.3232042, -12.2891314),
(1529, 92, 'LE', 'Lélouma', '萊盧瑪', 'Lélouma', 11.1833330, -12.9333330),
(1530, 92, 'LO', 'Lola', '蘿拉', '罗拉', 7.9613818, -8.3964938),
(1531, 92, 'MC', 'Macenta', '馬森塔', '马森塔', 8.4615795, -9.2785583),
(1532, 92, 'ML', 'Mali', '馬利', '马里', 11.9837090, -12.2547919),
(1533, 92, 'M', 'Mamou', '媽媽', '妈妈', 10.5736024, -11.8891721),
(1534, 92, 'MM', 'Mamou', '媽媽', '妈妈', 10.5736024, -11.8891721),
(1535, 92, 'MD', 'Mandiana', '曼迪亞納', '曼迪亚纳', 10.6172827, -8.6985716),
(1536, 92, 'N', 'Nzérékoré', 'Nzérékoré', 'Nzérékoré', 8.0385870, -8.8362755),
(1537, 92, 'NZ', 'Nzérékoré', 'Nzérékoré', 'Nzérékoré', 7.7478359, -8.8252502),
(1538, 92, 'PI', 'Pita', '皮塔餅', '皮塔', 10.8062086, -12.7135121),
(1539, 92, 'SI', 'Siguiri', '跟', '跟随', 11.4148113, -9.1788304),
(1540, 92, 'TE', 'Télimélé', '泰利梅萊', '泰利梅勒', 10.9089364, -13.0299331),
(1541, 92, 'TO', 'Tougué', '圖蓋', '图盖', 11.3841583, -11.6157773),
(1542, 92, 'YO', 'Yomou', '悠謀', '悠谋', 7.5696279, -9.2591571),
(1543, 93, 'BA', 'Bafatá', NULL, NULL, 12.1735243, -14.6529520),
(1544, 93, 'BM', 'Biombo', '幔', '屏幕', 11.8529061, -15.7351171),
(1545, 93, 'BL', 'Bolama', '博拉馬', '博拉马', 11.1480591, -16.1345705),
(1546, 93, 'CA', 'Cacheu', '卡舒', '卡舒', 12.0551416, -16.0640179),
(1547, 93, 'GA', 'Gabú', '加布', '加布', 11.8962488, -14.1001326),
(1548, 93, 'L', 'Leste', '東', '东', 0.0000000, 0.0000000),
(1549, 93, 'N', 'Norte', '北', '北', 7.8721811, 123.8857747),
(1550, 93, 'OI', 'Oio', '奧伊奧', '奥伊奥', 12.2760709, -15.3131185),
(1551, 93, 'QU', 'Quinara', '奎納拉', '奎纳拉', 11.7955620, -15.1726816),
(1552, 93, 'S', 'Sul', '在', '上', -10.2866578, 20.7122465),
(1553, 93, 'TO', 'Tombali', '墳墓', '坟墓', 11.3632696, -14.9856176),
(1554, 94, 'BA', 'Barima-Waini', '巴里馬-瓦伊尼', '巴里马-瓦伊尼', 7.4882419, -59.6564494),
(1555, 94, 'CU', 'Cuyuni-Mazaruni', '庫尤尼-馬扎魯尼', '库尤尼-马扎鲁尼', 6.4642141, -60.2110752),
(1556, 94, 'DE', 'Demerara-Mahaica', '德梅拉拉-馬哈伊卡', '德梅拉拉-马哈伊卡', 6.5464260, -58.0982046),
(1557, 94, 'EB', 'East Berbice-Corentyne', '東伯比斯-科倫泰恩', '东伯比斯-科伦泰恩', 2.7477922, -57.4627259),
(1558, 94, 'ES', 'Essequibo Islands-West Demerara', '埃塞奎博群島-西德梅拉拉', '埃塞奎博群岛-西德梅拉拉', 6.5720132, -58.4629997),
(1559, 94, 'MA', 'Mahaica-Berbice', '馬哈伊卡-貝爾比斯', '马哈伊卡-贝尔比斯', 6.2384960, -57.9162555),
(1560, 94, 'PM', 'Pomeroon-Supenaam', '波麥隆-蘇佩納姆', '波麦隆-苏佩纳姆', 7.1294166, -58.9206295),
(1561, 94, 'PT', 'Potaro-Siparuni', '波塔羅-西帕魯尼', '波塔罗-西帕鲁尼', 4.7855853, -59.2879977),
(1562, 94, 'UD', 'Upper Demerara-Berbice', '上德梅拉拉-貝爾比斯', '上德梅拉拉-贝尔比斯', 5.3064879, -58.1892921),
(1563, 94, 'UT', 'Upper Takutu-Upper Essequibo', '上塔庫圖-上埃塞奎博', '上塔库图-上埃塞奎博', 2.9239595, -58.7373634),
(1564, 95, 'AR', 'Artibonite', '洋工石', '洋工', 19.3629020, -72.4258145),
(1565, 95, 'CE', 'Centre', '中央', '中心', 32.8370251, -96.7773882),
(1566, 95, 'GA', 'Grand\'Anse', '㶴', '大', 12.0166667, -61.7666667),
(1567, 95, 'NI', 'Nippes', '小玩意兒', '小玩意儿', 18.3990735, -73.4180211),
(1568, 95, 'ND', 'Nord', '北', '北', 43.1905260, -89.4379210),
(1569, 95, 'NE', 'Nord-Est', '東北', '东北', 19.4889723, -71.8571331),
(1570, 95, 'NO', 'Nord-Ouest', '西北', '西北', 19.8374009, -73.0405277),
(1571, 95, 'OU', 'Ouest', '西', '西', 45.4547249, -73.6502365),
(1572, 95, 'SD', 'Sud', '南', '南', 29.9213248, -90.0973772),
(1573, 95, 'SE', 'Sud-Est', '東南', '东南', 18.2783598, -72.3547915),
(1574, 97, 'AT', 'Atlántida', '亞特蘭蒂斯', '亚特兰蒂斯', 15.6696283, -87.1422895),
(1575, 97, 'IB', 'Bay Islands', '海灣群島', '海湾群岛', 16.4826614, -85.8793252),
(1576, 97, 'CH', 'Choluteca', '喬魯特卡', '乔鲁特卡', 13.2504325, -87.1422895),
(1577, 97, 'CL', 'Colón', '科隆', '科隆', 15.6425965, -85.5200240),
(1578, 97, 'CM', 'Comayagua', '科馬亞瓜', '科马亚瓜', 14.5534828, -87.6186379),
(1579, 97, 'CP', 'Copán', '科潘', '科潘', 14.9360838, -88.8646980),
(1580, 97, 'CR', 'Cortés', '有禮貌的', '礼貌', 15.4923508, -88.0900762),
(1581, 97, 'EP', 'El Paraíso', '天堂', '乐园', 13.9821294, -86.4996546),
(1582, 97, 'FM', 'Francisco Morazán', '弗朗西斯科·莫拉桑', '弗朗西斯科·莫拉桑', 14.4541100, -87.0624261),
(1583, 97, 'GD', 'Gracias a Dios', '謝天謝地', '谢天谢地', 15.3418060, -84.6060449),
(1584, 97, 'IN', 'Intibucá', '因蒂布卡', '因蒂布卡', 14.3727340, -88.2461183),
(1585, 97, 'LP', 'La Paz', '拉巴斯', '拉巴斯', -15.0892416, -68.5247149),
(1586, 97, 'LE', 'Lempira', '倫皮拉', '伦皮拉', 14.1887698, -88.5565310),
(1587, 97, 'OC', 'Ocotepeque', '奧科特佩克', '奥科特佩克', 14.5170347, -89.0561532),
(1588, 97, 'OL', 'Olancho', '奧蘭喬', '奥兰乔', 14.8067406, -85.7666645),
(1589, 97, 'SB', 'Santa Bárbara', '聖塔芭芭拉', '圣巴巴拉', 15.1202795, -88.4016041),
(1590, 97, 'VA', 'Valle', '山谷', '山谷', 13.5782936, -87.5791287),
(1591, 97, 'YO', 'Yoro', '養老', '养老', 15.2949679, -87.1422895),
(1592, 98, 'HCW', 'Central and Western', '中西部', '中西部', 22.2866600, 114.1549700),
(1593, 98, 'HEA', 'Eastern', '東', '东部', 22.2841100, 114.2241400),
(1594, 98, 'NIS', 'Islands', '島嶼', '岛屿', 22.2611400, 113.9460800),
(1595, 98, 'KKC', 'Kowloon City', '九龍城', '九龙城', 22.3282000, 114.1915500),
(1596, 98, 'NKT', 'Kwai Tsing', '葵青', '葵青', 22.3548800, 114.0840100),
(1597, 98, 'KKT', 'Kwun Tong', '觀塘', '观塘', 22.3132600, 114.2258100),
(1598, 98, 'NNO', 'North', '北', '北', 22.4947100, 114.1381200),
(1599, 98, 'NSK', 'Sai Kung', '西貢', '西贡', 22.3814300, 114.2705200),
(1600, 98, 'NST', 'Sha Tin', '沙田', '沙田', 22.3871500, 114.1953400),
(1601, 98, 'KSS', 'Sham Shui Po', '深水埗', '深水埗', 22.3307400, 114.1622000),
(1602, 98, 'HSO', 'Southern', '南方的', '南部', 22.2472500, 114.1588400),
(1603, 98, 'NTP', 'Tai Po', '大埔', '大埔', 22.4508500, 114.1642200),
(1604, 98, 'NTW', 'Tsuen Wan', '荃灣', '荃湾', 22.3628100, 114.1290700),
(1605, 98, 'NTM', 'Tuen Mun', '屯門', '屯门', 22.3916300, 113.9770885),
(1606, 98, 'HWC', 'Wan Chai', '灣仔', '湾仔', 22.2796800, 114.1716800),
(1607, 98, 'KWT', 'Wong Tai Sin', '黃大仙', '黄大仙', 22.3335300, 114.1968600),
(1608, 98, 'KYT', 'Yau Tsim Mong', '油尖旺', '油尖旺', 22.3213800, 114.1726000),
(1609, 98, 'NYL', 'Yuen Long', '元朗', '元朗', 22.4455900, 114.0221800),
(1610, 99, 'BK', 'Bács-Kiskun', '巴奇-基斯昆', '巴奇-基斯昆', 46.5661437, 19.4272464),
(1611, 99, 'BA', 'Baranya', '欄', '栏杆', 46.0484585, 18.2719173),
(1612, 99, 'BE', 'Békés', '安靜', '和平', 46.6704899, 21.0434996),
(1613, 99, 'BC', 'Békéscsaba', 'Békéscsaba', 'Békéscsaba', 46.6735939, 21.0877309),
(1614, 99, 'BZ', 'Borsod-Abaúj-Zemplén', 'Borsod-Abaúj-Zemplén', 'Borsod-Abaúj-Zemplén', 48.2939401, 20.6934112),
(1615, 99, 'BU', 'Budapest', '布達佩斯', '布达佩斯', 47.4979120, 19.0402350),
(1616, 99, 'CS', 'Csongrád County', '松拉德縣', 'Csongrád 县', 46.4167050, 20.2566161),
(1617, 99, 'DE', 'Debrecen', '德布勒森', '德布勒森', 47.5316049, 21.6273124),
(1618, 99, 'DU', 'Dunaújváros', 'Dunaújváros', 'Dunaújváros', 46.9619059, 18.9355227),
(1619, 99, 'EG', 'Eger', '埃格爾', '埃格尔', 47.9025348, 20.3772284),
(1620, 99, 'ER', 'Érd', '埃爾德', '埃尔德', 47.3919718, 18.9045440),
(1621, 99, 'FE', 'Fejér County', '費耶爾縣', '费耶尔县', 47.1217932, 18.5294815),
(1622, 99, 'GY', 'Győr', '傑爾', '杰尔', 47.6874569, 17.6503974),
(1623, 99, 'GS', 'Győr-Moson-Sopron County', '傑爾-莫森-索普龍縣', '杰尔-莫森-索普龙县', 47.6509285, 17.2505883),
(1624, 99, 'HB', 'Hajdú-Bihar County', '哈伊杜-比哈爾邦縣', '哈伊杜-比哈尔邦县', 47.4688355, 21.5453227),
(1625, 99, 'HE', 'Heves County', '赫維斯縣', '赫夫斯县', 47.8057617, 20.2038559),
(1626, 99, 'HV', 'Hódmezővásárhely', 'Hódmezővásárhely', 'Hódmezővásárhely', 46.4181262, 20.3300315),
(1627, 99, 'JN', 'Jász-Nagykun-Szolnok County', '雅斯-納吉昆-索爾諾克縣', '雅斯-纳吉昆-索尔诺克县', 47.2555579, 20.5232456),
(1628, 99, 'KV', 'Kaposvár', 'Kaposvár', 'Kaposvár', 46.3593606, 17.7967639),
(1629, 99, 'KM', 'Kecskemét', 'Kecskemét', 'Kecskemét', 46.8963711, 19.6896861),
(1630, 99, 'KE', 'Komárom-Esztergom', '科馬羅姆-埃斯泰爾戈姆', '科马罗姆-埃斯泰尔戈姆', 47.5779786, 18.1256855),
(1631, 99, 'MI', 'Miskolc', '米什科爾茨', '米什科尔茨', 48.1034775, 20.7784384),
(1632, 99, 'NK', 'Nagykanizsa', 'Nagykanizsa', '纳吉卡尼萨', 46.4590218, 16.9896796),
(1633, 99, 'NO', 'Nógrád County', '諾格拉德縣', '诺格拉德县', 47.9041031, 19.0498504),
(1634, 99, 'NY', 'Nyíregyháza', 'Nyíregyháza', 'Nyíregyháza', 47.9495324, 21.7244053),
(1635, 99, 'PS', 'Pécs', '胸肌', '胸 肌', 46.0727345, 18.2322660),
(1636, 99, 'PE', 'Pest County', '佩斯縣', '佩斯县', 47.4480001, 19.4618128),
(1637, 99, 'ST', 'Salgótarján', 'Salgótarján', 'Salgótarján', 48.0935237, 19.7999813),
(1638, 99, 'SO', 'Somogy County', '索莫吉縣', '索莫吉县', 46.5548590, 17.5866732),
(1639, 99, 'SN', 'Sopron', '索普隆', '索普隆', 47.6816619, 16.5844795),
(1640, 99, 'SZ', 'Szabolcs-Szatmár-Bereg County', '薩博爾茨-薩特馬爾-貝雷格縣', '萨博尔奇-萨特马尔-贝雷格县', 48.0394954, 22.0033300),
(1641, 99, 'SD', 'Szeged', '塞格德', '塞格德', 46.2530102, 20.1414253),
(1642, 99, 'SF', 'Székesfehérvár', 'Székesfehérvár', 'Székesfehérvár', 47.1860262, 18.4221358),
(1643, 99, 'SS', 'Szekszárd', 'Szekszárd', 'Szekszárd', 46.3474326, 18.7062293),
(1644, 99, 'SK', 'Szolnok', '索爾諾克', '索尔诺克', 47.1621355, 20.1824712),
(1645, 99, 'SH', 'Szombathely', '松巴特利', '松巴特利', 47.2306851, 16.6218441),
(1646, 99, 'TB', 'Tatabánya', '塔塔巴尼亞', '塔塔巴尼亚', 47.5692460, 18.4048180),
(1647, 99, 'TO', 'Tolna County', '托爾納縣', '托尔纳县', 46.4762754, 18.5570627),
(1648, 99, 'VA', 'Vas County', '瓦斯縣', '瓦斯县', 47.0929111, 16.6812183),
(1649, 99, 'VM', 'Veszprém', 'Veszprém', '维斯普雷姆', 47.1028087, 17.9093019),
(1650, 99, 'VE', 'Veszprém County', '維斯普雷姆縣', '维斯普雷姆县', 47.0930974, 17.9100763),
(1651, 99, 'ZA', 'Zala County', '扎拉縣', '扎拉县', 46.7384404, 16.9152252),
(1652, 99, 'ZE', 'Zalaegerszeg', 'Zalaegerszeg', 'Zalaegerszeg', 46.8416936, 16.8416322),
(1653, 100, '1', 'Capital', '首都', '资本', 64.1063839, -22.2910581),
(1654, 100, '7', 'Eastern', '東', '东部', 64.9597654, -18.0691038),
(1655, 100, '6', 'Northeastern', '東北', '东北', 65.4639984, -19.4327371),
(1656, 100, '5', 'Northwestern', '西北大學', '西北', 65.4621812, -21.0270800),
(1657, 100, '8', 'Southern', '南方的', '南部', 64.0581548, -22.2311740),
(1658, 100, '2', 'Southern Peninsula', '南部半島', '南部半岛', 63.9154803, -22.3649667),
(1659, 100, '3', 'Western', '西方的', '西方', 64.8865467, -24.5559296),
(1660, 100, '4', 'Westfjords', '西峽灣', '西峡湾', 65.6936820, -25.3976235),
(1661, 101, 'AN', 'Andaman and Nicobar Islands', '安達曼和尼科巴群島', '安达曼和尼科巴群岛', 11.7400867, 92.6586401),
(1662, 101, 'AP', 'Andhra Pradesh', '安得拉邦', '安得拉邦', 15.9128998, 79.7399875),
(1663, 101, 'AR', 'Arunachal Pradesh', '阿魯納恰爾邦', '阿鲁纳恰尔邦', 28.2179994, 94.7277528),
(1664, 101, 'AS', 'Assam', '阿薩姆邦', '阿萨姆邦', 26.2006043, 92.9375739),
(1665, 101, 'BR', 'Bihar', '比哈爾邦', '比哈尔邦', 25.0960742, 85.3131194),
(1666, 101, 'CH', 'Chandigarh', '昌迪加爾', '昌迪加尔', 30.7333148, 76.7794179),
(1667, 101, 'CT', 'Chhattisgarh', '恰蒂斯加爾邦', '恰蒂斯加尔邦', 21.2786567, 81.8661442),
(1668, 101, 'DH', 'Dadra and Nagar Haveli and Daman and Diu', '達德拉和納加爾哈維利以及達曼和迪烏', '达德拉和纳加尔哈维利以及达曼和第乌', 20.3973736, 72.8327991),
(1669, 101, 'DL', 'Delhi', '德里', '德里', 28.7040592, 77.1024902),
(1670, 101, 'GA', 'Goa', '果阿', '原羚', 15.2993265, 74.1239960),
(1671, 101, 'GJ', 'Gujarat', '古吉拉特邦', '古吉拉特邦', 22.2586520, 71.1923805),
(1672, 101, 'HR', 'Haryana', '哈里亞納邦', '哈里亚纳邦', 29.0587757, 76.0856010),
(1673, 101, 'HP', 'Himachal Pradesh', '喜馬偕爾邦', '喜马偕尔邦', 31.1048294, 77.1733901),
(1674, 101, 'JK', 'Jammu and Kashmir', '查謨和克什米爾', '查谟和克什米尔', 33.2778390, 75.3412179),
(1675, 101, 'JH', 'Jharkhand', '賈坎德邦', '贾坎德邦', 23.6101808, 85.2799354),
(1676, 101, 'KA', 'Karnataka', '卡納塔克邦', '卡纳塔克邦', 15.3172775, 75.7138884),
(1677, 101, 'KL', 'Kerala', '喀拉拉邦', '喀 拉拉邦', 10.8505159, 76.2710833),
(1678, 101, 'LA', 'Ladakh', '拉達克', '拉达克', 34.2268475, 77.5619419),
(1679, 101, 'LD', 'Lakshadweep', '拉克沙群島', '拉克沙群岛', 10.3280265, 72.7846336),
(1680, 101, 'MP', 'Madhya Pradesh', '中央邦', '中央邦', 22.9734229, 78.6568942),
(1681, 101, 'MH', 'Maharashtra', '馬哈拉施特拉邦', '马哈拉施特拉邦', 19.7514798, 75.7138884),
(1682, 101, 'MN', 'Manipur', '曼尼普爾邦', '曼尼普尔邦', 24.6637173, 93.9062688),
(1683, 101, 'ML', 'Meghalaya', '梅加拉亞邦', '梅加拉亚邦', 25.4670308, 91.3662160),
(1684, 101, 'MZ', 'Mizoram', '米佐拉姆邦', '米佐拉姆邦', 23.1645430, 92.9375739),
(1685, 101, 'NL', 'Nagaland', '那加蘭邦', '那加兰邦', 26.1584354, 94.5624426),
(1686, 101, 'OR', 'Odisha', '奧里薩邦', '奥里萨邦', 20.9516658, 85.0985236),
(1687, 101, 'PY', 'Puducherry', '本地治裡', '本地治里', 11.9415915, 79.8083133),
(1688, 101, 'PB', 'Punjab', '旁遮普邦', '旁 遮 普', 31.1471305, 75.3412179),
(1689, 101, 'RJ', 'Rajasthan', '拉賈斯坦邦', '拉贾斯坦邦', 27.0238036, 74.2179326),
(1690, 101, 'SK', 'Sikkim', '錫金', '锡金', 27.5329718, 88.5122178),
(1691, 101, 'TN', 'Tamil Nadu', '泰米爾納德邦', '泰米尔纳德邦', 11.1271225, 78.6568942),
(1692, 101, 'TG', 'Telangana', '特倫甘納邦', '特伦甘纳邦', 18.1124372, 79.0192997),
(1693, 101, 'TR', 'Tripura', '特里普拉邦', '特里普拉邦', 23.9408482, 91.9881527),
(1694, 101, 'UP', 'Uttar Pradesh', '北方邦', '北方邦', 26.8467088, 80.9461592),
(1695, 101, 'UK', 'Uttarakhand', '北阿坎德邦', '北阿坎德邦', 30.0667530, 79.0192997),
(1696, 101, 'WB', 'West Bengal', '西孟加拉邦', '西孟加拉邦', 22.9867569, 87.8549755),
(1697, 102, 'AC', 'Aceh', '亞齊', '亚齐', 4.6951350, 96.7493993),
(1698, 102, 'BA', 'Bali', '峇里島', '巴厘岛', -8.3405389, 115.0919509),
(1699, 102, 'BT', 'Banten', '萬丹', '万丹', -6.4058172, 106.0640179),
(1700, 102, 'BE', 'Bengkulu', '明古魯', '明古鲁', -3.7928451, 102.2607641),
(1701, 102, 'YO', 'DI Yogyakarta', '在日惹', '在日惹', -7.8753849, 110.4262088),
(1702, 102, 'JK', 'DKI Jakarta', '雅加達', '雅加达', -6.2087634, 106.8455990),
(1703, 102, 'GO', 'Gorontalo', '哥倫打洛', '哥伦打洛', 0.5435442, 123.0567693),
(1704, 102, 'JA', 'Jambi', '占碑', '占碑', -1.6101229, 103.6131203),
(1705, 102, 'JB', 'Jawa Barat', '西爪哇', '西爪哇', -7.0909110, 107.6688870),
(1706, 102, 'JT', 'Jawa Tengah', '中爪哇', '中爪哇', -7.1509750, 110.1402594),
(1707, 102, 'JI', 'Jawa Timur', '東爪哇', '东爪哇', -7.5360639, 112.2384017),
(1708, 102, 'KB', 'Kalimantan Barat', '西加里曼丹', '西加里曼丹', 0.4773475, 106.6131405),
(1709, 102, 'KS', 'Kalimantan Selatan', '加里曼丹塞拉坦', '加里曼丹塞拉坦', -3.0926415, 115.2837585),
(1710, 102, 'KT', 'Kalimantan Tengah', '中加里曼丹', '中加里曼丹', -1.6814878, 113.3823545),
(1711, 102, 'KI', 'Kalimantan Timur', '東加里曼丹', '东加里曼丹', 0.5386586, 116.4193890),
(1712, 102, 'KU', 'Kalimantan Utara', '北加里曼丹', '北加里曼丹', 3.0730929, 116.0413889),
(1713, 102, 'BB', 'Kepulauan Bangka Belitung', '邦加勿里洞群島', '邦加勿里洞群岛', -2.7410513, 106.4405872),
(1714, 102, 'KR', 'Kepulauan Riau', '廖內群島', '廖内群岛', 3.9456514, 108.1428669),
(1715, 102, 'LA', 'Lampung', '楠榜', '楠榜', -4.5585849, 105.4068079),
(1716, 102, 'MA', 'Maluku', '馬魯古', '马鲁古', -3.2384616, 130.1452734),
(1717, 102, 'MU', 'Maluku Utara', '北馬魯古', '北马鲁古', 1.5709993, 127.8087693),
(1718, 102, 'NB', 'Nusa Tenggara Barat', '努沙登加拉巴拉特', '努沙登加拉巴拉特', -8.6529334, 117.3616476),
(1719, 102, 'NT', 'Nusa Tenggara Timur', '努沙登加拉帖木兒', '努沙登加拉帖木儿', -8.6573819, 121.0793705),
(1720, 102, 'PA', 'Papua', '巴布亞', '巴布亚', -5.0122202, 141.3470159),
(1721, 102, 'PB', 'Papua Barat', '西巴布亞', '西巴布亚', -1.3361154, 133.1747162),
(1722, 102, 'PD', 'Papua Barat Daya', '巴布亞西南部', '巴布亚西南部', -0.9000000, 131.4000000),
(1723, 102, 'PE', 'Papua Pegunungan', '巴布亞佩古農安', '巴布亚佩古农安', -4.0000000, 139.5000000),
(1724, 102, 'PS', 'Papua Selatan', '巴布亞塞拉坦', '巴布亚塞拉坦', -6.5000000, 139.5000000),
(1725, 102, 'PT', 'Papua Tengah', '巴布亞中部', '巴布亚中部', -4.0000000, 136.0000000),
(1726, 102, 'RI', 'Riau', '廖內', '廖内', 0.2933469, 101.7068294),
(1727, 102, 'SR', 'Sulawesi Barat', '蘇拉威西巴拉特', '苏拉威西巴拉特', -2.8441371, 119.2320784),
(1728, 102, 'SN', 'Sulawesi Selatan', '蘇拉威西島塞拉坦', '苏拉威西塞拉坦', -3.6687994, 119.9740534),
(1729, 102, 'ST', 'Sulawesi Tengah', '蘇拉威西登加', '苏拉威西登加', -1.4300254, 121.4456179),
(1730, 102, 'SG', 'Sulawesi Tenggara', '蘇拉威西島東南部', '苏拉威西岛东南部', -4.1449100, 122.1746050),
(1731, 102, 'SA', 'Sulawesi Utara', '北蘇拉威西島', '北苏拉威西岛', 0.6246932, 123.9750018),
(1732, 102, 'SB', 'Sumatera Barat', '西蘇門答臘島', '西苏门答腊岛', -0.7399397, 100.8000051),
(1733, 102, 'SS', 'Sumatera Selatan', '南蘇門答臘島', '南苏门答腊岛', -3.3194374, 103.9143990),
(1734, 102, 'SU', 'Sumatera Utara', '北蘇門答臘島', '北苏门答腊岛', 2.1153547, 99.5450974),
(1735, 103, '30', 'Alborz', '厄爾布爾士', '厄尔布尔士', 35.9960467, 50.9289246),
(1736, 103, '24', 'Ardabil', '阿爾達比勒', '阿尔达比勒', 38.4853276, 47.8911209),
(1737, 103, '18', 'Bushehr', '布什爾', '布什尔', 28.7620739, 51.5150077),
(1738, 103, '14', 'Chaharmahal and Bakhtiari', '查哈馬哈爾和巴赫蒂亞里', '查哈马哈尔和巴赫蒂亚里', 31.9970419, 50.6613849),
(1739, 103, '03', 'East Azerbaijan', '東亞塞拜然', '东阿塞拜疆', 37.9035733, 46.2682109),
(1740, 103, '07', 'Fars', '法爾斯', '法尔斯', 29.1043813, 53.0458930),
(1741, 103, '01', 'Gilan', '吉蘭', '吉兰', 37.2809455, 49.5924134),
(1742, 103, '27', 'Golestan', '戈勒斯坦', '戈勒斯坦', 37.2898123, 55.1375834),
(1743, 103, '13', 'Hamadan', '濱馬丹', '哈马丹', 34.9193607, 47.4832925),
(1744, 103, '22', 'Hormozgan', '霍爾木茲甘', '霍尔莫兹甘', 27.1387230, 55.1375834),
(1745, 103, '16', 'Ilam', '伊拉姆', '伊拉姆', 33.2957618, 46.6705340),
(1746, 103, '10', 'Isfahan', '伊斯法罕', '伊斯法罕', 33.2771073, 52.3613378),
(1747, 103, '08', 'Kerman', '克爾曼', '克尔曼', 29.4850089, 57.6439048),
(1748, 103, '05', 'Kermanshah', '克爾曼沙', '克尔曼沙赫', 34.4576233, 46.6705340),
(1749, 103, '06', 'Khuzestan', '胡齊斯坦', '胡齐斯坦', 31.4360149, 49.0413120),
(1750, 103, '17', 'Kohgiluyeh and Boyer-Ahmad', '科吉盧耶和博耶-艾哈邁德', '科吉卢耶和博耶-艾哈迈德', 30.7245860, 50.8456323),
(1751, 103, '12', 'Kurdistan', '庫爾德斯坦', '库尔德斯坦', 35.9553579, 47.1362125),
(1752, 103, '15', 'Lorestan', '洛雷斯坦', '洛雷斯坦', 33.5818394, 48.3988186),
(1753, 103, '00', 'Markazi', '中心', '中心', 34.6123050, 49.8547266),
(1754, 103, '02', 'Mazandaran', '馬贊達蘭', '马赞达兰', 36.2262393, 52.5318604),
(1755, 103, '28', 'North Khorasan', '北呼羅珊', '北呼罗珊', 37.4710353, 57.1013188),
(1756, 103, '26', 'Qazvin', '卡茲溫', '卡兹温', 36.0881317, 49.8547266),
(1757, 103, '25', 'Qom', '庫姆', '库姆', 34.6415764, 50.8746035),
(1758, 103, '09', 'Razavi Khorasan', '拉扎維呼羅珊', '拉扎维呼罗珊', 35.1020253, 59.1041758),
(1759, 103, '20', 'Semnan', '塞姆南', '塞姆南', 35.2255585, 54.4342138),
(1760, 103, '11', 'Sistan and Baluchestan', '錫斯坦和俾路支斯坦', '锡斯坦和俾路支斯坦', 27.5299906, 60.5820676),
(1761, 103, '29', 'South Khorasan', '南呼羅珊', '南呼罗珊', 32.5175643, 59.1041758),
(1762, 103, '23', 'Tehran', '德黑蘭', '德黑兰', 35.7248416, 51.3816530),
(1763, 103, '04', 'West Azarbaijan', '西阿扎爾拜疆', '西阿扎尔拜疆', 37.4550062, 45.0000000),
(1764, 103, '21', 'Yazd', '亞茲德', '亚兹德', 32.1006387, 54.4342138),
(1765, 103, '19', 'Zanjan', '贊詹', '赞詹', 36.5018185, 48.3988186),
(1766, 104, 'AN', 'Al Anbar', '阿爾安巴爾', '安巴尔', 32.5597614, 41.9196471),
(1767, 104, 'MU', 'Al Muthanna', '阿爾·穆薩納', '穆萨纳', 29.9133171, 45.2993862),
(1768, 104, 'QA', 'Al-Qādisiyyah', '卡迪西亞', '卡迪西亚', 32.0436910, 45.1494505),
(1769, 104, 'BB', 'Babylon', '巴比倫', '巴比伦', 32.4681910, 44.5501935),
(1770, 104, 'BG', 'Baghdad', '巴格達', '巴格达', 33.3152618, 44.3660653),
(1771, 104, 'BA', 'Basra', '巴士拉', '巴士拉', 30.5114252, 47.8296253),
(1772, 104, 'DQ', 'Dhi Qar', '迪卡爾', '迪卡尔', 31.1042292, 46.3624686),
(1773, 104, 'DI', 'Diyala', '迪亞拉', '迪亚拉', 33.7733487, 45.1494505),
(1774, 104, 'DA', 'Dohuk', '杜胡克', '多胡克', 36.9077252, 43.0631689),
(1775, 104, 'AR', 'Erbil', '埃爾比勒', '埃尔比勒', 36.5570628, 44.3851263),
(1776, 104, 'KA', 'Karbala', '卡爾巴拉', '卡尔巴拉', 32.4045493, 43.8673222),
(1777, 104, 'KI', 'Kirkuk', '基爾庫克', '基尔库克', 35.3292014, 43.9436788),
(1778, 104, 'MA', 'Maysan', '梅桑', '梅桑', 31.8734002, 47.1362125),
(1779, 104, 'NA', 'Najaf', '納傑夫', '纳杰夫', 31.3517486, 44.0960311),
(1780, 104, 'NI', 'Nineveh', '尼尼微', '尼尼微', 36.2295740, 42.2362435),
(1781, 104, 'SD', 'Saladin', '薩拉丁', '萨拉丁', 34.5337527, 43.4837380),
(1782, 104, 'SU', 'Sulaymaniyah', '蘇萊曼尼亞', '苏莱曼尼亚', 35.5466348, 45.3003683),
(1783, 104, 'WA', 'Wasit', '裁判員', '裁判', 32.6024094, 45.7520985),
(1784, 105, 'CW', 'Carlow', '卡洛', '卡洛', 52.7232217, -6.8108295),
(1785, 105, 'CN', 'Cavan', '卡文', '卡文', 53.9765424, -7.2996623),
(1786, 105, 'CE', 'Clare', '克萊爾', '克莱尔', 43.0466400, -87.8995810),
(1787, 105, 'C', 'Connacht', '康諾特', '康诺特', 53.8376243, -8.9584481),
(1788, 105, 'CO', 'Cork', '塞', '软木', 51.8985143, -8.4756035),
(1789, 105, 'DL', 'Donegal', '多尼戈爾', '多尼戈尔', 54.6548993, -8.1040967),
(1790, 105, 'D', 'Dublin', '都柏林', '都柏林', 53.3498053, -6.2603097),
(1791, 105, 'G', 'Galway', '戈爾韋', '高威', 53.3564509, -8.8534113),
(1792, 105, 'KY', 'Kerry', '克里', '克里', 52.1544607, -9.5668633),
(1793, 105, 'KE', 'Kildare', '基爾代爾', '基尔代尔', 53.2120434, -6.8194708),
(1794, 105, 'KK', 'Kilkenny', '基爾肯尼', '基尔肯尼', 52.5776957, -7.2180020),
(1795, 105, 'LS', 'Laois', '老撾', '老挝', 52.9942950, -7.3323007),
(1796, 105, 'L', 'Leinster', '倫斯特', '伦斯特', 53.3271538, -7.5140841),
(1797, 105, 'LM', 'Leitrim', '萊特里姆', '莱特里姆', 54.1391630, -8.6666111),
(1798, 105, 'LK', 'Limerick', '利默里克', '利默里克', 52.5090517, -8.7474955),
(1799, 105, 'LD', 'Longford', '朗福德', '朗福德', 53.7274982, -7.7931527),
(1800, 105, 'LH', 'Louth', '勞斯', '劳斯', 53.9252324, -6.4889423),
(1801, 105, 'MO', 'Mayo', '五月', '五月', 54.0152604, -9.4289369),
(1802, 105, 'MH', 'Meath', '米斯', '米斯', 53.6055480, -6.6564169),
(1803, 105, 'MN', 'Monaghan', '莫納漢', '莫纳汉', 54.2492046, -6.9683132),
(1804, 105, 'M', 'Munster', '明斯特', '明斯特', 51.9471197, 7.5845320),
(1805, 105, 'OY', 'Offaly', '奧法利', '奥法利', 53.2356871, -7.7122229),
(1806, 105, 'RN', 'Roscommon', '羅斯康芒', '罗丝康门', 53.7592604, -8.2681621),
(1807, 105, 'SO', 'Sligo', '斯萊戈', '斯莱戈', 54.1553277, -8.6064532),
(1808, 105, 'TA', 'Tipperary', '蒂珀雷里', '蒂珀雷里', 52.4737894, -8.1618514),
(1809, 105, 'U', 'Ulster', '阿爾斯特', '阿尔斯特', 54.7616555, -6.9612273),
(1810, 105, 'WD', 'Waterford', '沃特福德', '沃特福德', 52.1943549, -7.6227512),
(1811, 105, 'WH', 'Westmeath', '韋斯特米斯', '韦斯特米斯', 53.5345308, -7.4653217),
(1812, 105, 'WX', 'Wexford', '韋克斯福德', '韦克斯福德', 52.4793603, -6.5839913),
(1813, 105, 'WW', 'Wicklow', '威克洛', '威克洛', 52.9862313, -6.3672543),
(1814, 106, 'M', 'Central', '中', '中央', 47.6087583, -122.2964235),
(1815, 106, 'HA', 'Haifa', '海法', '海法', 32.4814111, 34.9947510),
(1816, 106, 'JM', 'Jerusalem', '耶路撒冷', '耶路撒冷', 31.7648243, 34.9947510),
(1817, 106, 'Z', 'Northern', '北', '北方', 36.1511864, -95.9951763),
(1818, 106, 'D', 'Southern', '南方的', '南部', 40.7137586, -74.0009059),
(1819, 106, 'TA', 'Tel Aviv', '特拉維夫', '特拉维夫', 32.0929075, 34.8072165),
(1820, 107, '65', 'Abruzzo', '阿布魯佐', '阿布鲁佐', 42.1920119, 13.7289167),
(1821, 107, 'AG', 'Agrigento', '阿格里真托', '阿格里真托', 37.3105202, 13.5857978),
(1822, 107, 'AL', 'Alessandria', '亞歷山大', '亚历山德里亚', 44.8175587, 8.7046627),
(1823, 107, 'AN', 'Ancona', '安科納', '安科纳', 43.5493245, 13.2663479),
(1824, 107, '23', 'Aosta Valley', '奧斯塔谷', '奥斯塔谷', 45.7388878, 7.4261866),
(1825, 107, '75', 'Apulia', '普利亞', '普利亚', 40.7928393, 17.1011931),
(1826, 107, 'AR', 'Arezzo', '阿雷佐', '阿雷佐', 43.5162533, 11.2236872),
(1827, 107, 'AP', 'Ascoli Piceno', '阿斯科利·皮切諾', '阿斯科利·皮切诺', 42.8638933, 13.5899733),
(1828, 107, 'AT', 'Asti', '洎', '直到', 44.9007652, 8.2064315),
(1829, 107, 'AV', 'Avellino', '阿韋利諾', '阿韦利诺', 40.9964510, 15.1258955),
(1830, 107, 'BT', 'Barletta-Andria-Trani', '巴萊塔-安德里亞-特拉尼', '巴莱塔-安德里亚-特拉尼', 41.2004543, 16.2051484),
(1831, 107, '77', 'Basilicata', '巴西利卡塔', '巴西利卡塔', 40.6430766, 15.9699878),
(1832, 107, 'BL', 'Belluno', '貝盧諾', '贝卢诺', 46.2497659, 12.1969565),
(1833, 107, 'BN', 'Benevento', '貝內文托', '贝内文托', 41.2035093, 14.7520939),
(1834, 107, 'BG', 'Bergamo', '貝加莫', '贝加莫', 45.6982642, 9.6772698),
(1835, 107, 'BI', 'Biella', '連桿', '连杆', 45.5628176, 8.0582717),
(1836, 107, 'BS', 'Brescia', '布雷西亞', '布雷西亚', 45.5415526, 10.2118019),
(1837, 107, 'BR', 'Brindisi', '烤', '吐司', 40.6112663, 17.7636210),
(1838, 107, '78', 'Calabria', '卡拉布里亞', '卡拉布里亚', 39.3087714, 16.3463791),
(1839, 107, 'CL', 'Caltanissetta', '卡爾塔尼塞塔', '卡尔塔尼塞塔 Caltanissetta', 37.4860130, 14.0614982),
(1840, 107, '72', 'Campania', '坎帕尼亞', '坎帕尼亚', 40.6670887, 15.1068113),
(1841, 107, 'CB', 'Campobasso', '坎波巴索', '坎波巴索', 41.6738865, 14.7520939),
(1842, 107, 'CE', 'Caserta', '卡塞塔', '卡塞塔', 41.2078354, 14.1001326),
(1843, 107, 'CZ', 'Catanzaro', '卡坦扎羅', '卡坦扎罗', 38.8896348, 16.4405872),
(1844, 107, 'CH', 'Chieti', '基耶蒂', '基耶蒂', 42.0334428, 14.3791912),
(1845, 107, 'CO', 'Como', '如何', '如何', 45.8080416, 9.0851793),
(1846, 107, 'CS', 'Cosenza', '科森扎', '科森扎', 39.5644105, 16.2522143),
(1847, 107, 'CR', 'Cremona', '克雷莫納', '克雷莫纳', 45.2014375, 9.9836582),
(1848, 107, 'KR', 'Crotone', '克羅托內', '克罗托内', 39.1309856, 17.0067031),
(1849, 107, 'CN', 'Cuneo', '楔', '楔', 44.5970314, 7.6114217),
(1850, 107, '45', 'Emilia-Romagna', '艾米利亞-羅馬涅', '艾米利亚-罗马涅', 44.5967607, 11.2186396),
(1851, 107, 'EN', 'Enna', '恩娜', '恩娜', 37.5676216, 14.2795349),
(1852, 107, 'FM', 'Fermo', '硬', '公司', 43.0931367, 13.5899733),
(1853, 107, 'FE', 'Ferrara', '費拉拉', '费拉拉', 44.7663680, 11.7644068),
(1854, 107, 'FG', 'Foggia', '福賈', '福贾', 41.6384480, 15.5943388),
(1855, 107, 'FC', 'Forlì-Cesena', '弗利-切塞納', '弗利-切塞纳', 43.9947681, 11.9804613),
(1856, 107, '36', 'Friuli–Venezia Giulia', '弗留利-威尼斯朱利亞', '弗留利-威尼斯朱利亚', 46.2259177, 13.1033646),
(1857, 107, 'FR', 'Frosinone', '氟西酮', '弗罗西酮', 41.6576528, 13.6362715),
(1858, 107, 'GO', 'Gorizia', '戈里齊亞', '戈里齐亚', 45.9053899, 13.5163725),
(1859, 107, 'GR', 'Grosseto', '格羅塞托', '格罗塞托', 42.8518007, 11.2523792),
(1860, 107, 'IM', 'Imperia', '英佩里亞', '英佩里亚', 43.9418660, 7.8286368),
(1861, 107, 'IS', 'Isernia', '伊塞爾尼亞', '伊塞尔尼亚', 41.5891555, 14.1930918),
(1862, 107, 'AQ', 'L\'Aquila', 'L', 'L', 42.1256317, 13.6362715),
(1863, 107, 'SP', 'La Spezia', '拉斯佩齊亞', '拉斯佩齐亚', 44.2447913, 9.7678687),
(1864, 107, 'LT', 'Latina', '拉丁文', '拉丁语', 41.4087476, 13.0817903),
(1865, 107, '62', 'Lazio', '拉蒂姆', '拉蒂姆', 41.8122410, 12.7385100),
(1866, 107, 'LE', 'Lecce', '萊切', '莱切', 40.2347393, 18.1428669),
(1867, 107, 'LC', 'Lecco', '萊科', '莱科', 45.9382941, 9.3857290),
(1868, 107, '42', 'Liguria', '利古里亞', '利古里亚', 44.3167917, 8.3964938),
(1869, 107, 'LI', 'Livorno', '里窩那', '利沃诺', 43.0239848, 10.6647101),
(1870, 107, 'LO', 'Lodi', '洛迪', '洛迪', 45.2405036, 9.5292512),
(1871, 107, '25', 'Lombardy', '倫巴第大區', '伦巴第', 45.4790671, 9.8452433),
(1872, 107, 'LU', 'Lucca', '盧卡', '卢卡', 43.8376736, 10.4950530),
(1873, 107, 'MC', 'Macerata', '馬切拉塔', '马切拉塔', 43.2459322, 13.2663479),
(1874, 107, 'MN', 'Mantua', '曼圖亞', '曼图亚', 45.1667728, 10.7753613),
(1875, 107, '57', 'Marche', '㞈', '走', 43.3045620, 13.7194700),
(1876, 107, 'MS', 'Massa and Carrara', '馬薩和卡拉拉', '马萨和卡拉拉', 44.2213998, 10.0359661),
(1877, 107, 'MT', 'Matera', '馬泰拉', '马泰拉', 40.6663496, 16.6043636),
(1878, 107, 'MO', 'Modena', '摩德納', '摩德纳', 44.5513799, 10.9180480),
(1879, 107, '67', 'Molise', '莫利塞', '莫利塞', 41.6738865, 14.7520939),
(1880, 107, 'MB', 'Monza and Brianza', '蒙扎和布里安扎', '蒙扎和布里安扎', 45.6235990, 9.2588015),
(1881, 107, 'NO', 'Novara', '諾瓦拉', '诺瓦拉', 45.5485133, 8.5150793),
(1882, 107, 'NU', 'Nuoro', '諾羅', '诺罗', 40.3286904, 9.4561550),
(1883, 107, 'OR', 'Oristano', '奧里斯塔諾', '奥里斯塔诺', 40.0599068, 8.7481167),
(1884, 107, 'PD', 'Padua', '帕多瓦', '帕多瓦', 45.3661864, 11.8209139),
(1885, 107, 'PA', 'Palermo', '巴勒莫', '巴勒莫', 38.1156900, 13.3614868),
(1886, 107, 'PR', 'Parma', '帕爾馬', '帕尔马', 44.8015322, 10.3279354),
(1887, 107, 'PV', 'Pavia', '帕維亞', '帕维亚', 45.3218166, 8.8466236),
(1888, 107, 'PG', 'Perugia', '佩魯賈', '佩鲁贾', 42.9380040, 12.6216211),
(1889, 107, 'PU', 'Pesaro and Urbino', '佩薩羅和烏爾比諾', '佩萨罗和乌尔比诺', 43.6130118, 12.7135121),
(1890, 107, 'PE', 'Pescara', '佩斯卡拉', '佩斯卡拉', 42.3570655, 13.9608091),
(1891, 107, 'PC', 'Piacenza', '皮亞琴察', '皮亚琴察', 44.8263112, 9.5291447),
(1892, 107, '21', 'Piedmont', '皮埃蒙特', '皮德蒙特', 45.0522366, 7.5153885),
(1893, 107, 'PI', 'Pisa', '比薩', '比萨', 43.7228315, 10.4017194),
(1894, 107, 'PT', 'Pistoia', '皮斯托亞', '皮斯托亚', 43.9543733, 10.8903099),
(1895, 107, 'PN', 'Pordenone', '波代諾內', '波代农', 46.0378862, 12.7108350),
(1896, 107, 'PZ', 'Potenza', '力', '权力', 40.4182194, 15.8760040),
(1897, 107, 'PO', 'Prato', '牧場', '草 甸', 44.0453900, 11.1164452),
(1898, 107, 'RG', 'Ragusa', '拉古薩', '拉古萨', 36.9269273, 14.7255129),
(1899, 107, 'RA', 'Ravenna', '拉文納', '拉文纳', 44.4184443, 12.2035998),
(1900, 107, 'RE', 'Reggio Emilia', '雷焦艾米利亞', '雷焦艾米利亚', 44.5856580, 10.5564736),
(1901, 107, 'RI', 'Rieti', '列蒂', '列蒂', 42.3674405, 12.8975098),
(1902, 107, 'RN', 'Rimini', '里米尼', '里米尼', 44.0678288, 12.5695158),
(1903, 107, 'RO', 'Rovigo', '羅維戈', '罗维戈', 45.0241818, 11.8238162),
(1904, 107, 'SA', 'Salerno', '薩勒諾', '萨莱诺', 40.4287832, 15.2194808),
(1905, 107, '88', 'Sardinia', '撒丁島', '撒丁岛', 40.1208752, 9.0128926),
(1906, 107, 'SS', 'Sassari', '薩薩里', '萨萨里', 40.7967907, 8.5750407),
(1907, 107, 'SV', 'Savona', '薩沃納', '萨沃纳', 44.2887995, 8.2650580),
(1908, 107, '82', 'Sicily', '西西里島', '西西里岛', 37.5999938, 14.0153557),
(1909, 107, 'SI', 'Siena', '錫耶納', '锡耶纳', 43.2937732, 11.4339148),
(1910, 107, 'SR', 'Siracusa', '錫拉丘茲', '雪城', 37.0656924, 15.2857109),
(1911, 107, 'SO', 'Sondrio', '桑德里奧', '桑德里奥', 46.1727636, 9.7994917),
(1912, 107, 'SU', 'South Sardinia', '南撒丁島', '南撒丁岛', 39.3893535, 8.9397000),
(1913, 107, 'TA', 'Taranto', '塔蘭托', '塔兰托', 40.5740901, 17.2429976),
(1914, 107, 'TE', 'Teramo', '泰拉莫', '泰拉莫', 42.5895608, 13.6362715),
(1915, 107, 'TR', 'Terni', '特爾尼', '特尔尼', 42.5634534, 12.5298028),
(1916, 107, 'TP', 'Trapani', '特拉帕尼', '特拉帕尼', 38.0183116, 12.5148265),
(1917, 107, '32', 'Trentino-South Tyrol', '特倫蒂諾-南蒂羅爾', '特伦蒂诺-南蒂罗尔', 46.4336662, 11.1693296),
(1918, 107, 'TV', 'Treviso', '特雷維索', '特雷维索', 45.6668517, 12.2430617),
(1919, 107, 'TS', 'Trieste', '的里雅斯特', '的里雅斯特', 45.6894823, 13.7833072),
(1920, 107, '52', 'Tuscany', '托斯卡納', '托斯卡纳', 43.7710513, 11.2486208),
(1921, 107, 'UD', 'Udine', '烏迪內', '乌迪内', 46.1407972, 13.1662896),
(1922, 107, '55', 'Umbria', '翁布里亞', '翁布里亚', 42.9380040, 12.6216211),
(1923, 107, 'VA', 'Varese', '瓦雷澤', '瓦雷泽', 45.7990260, 8.7300945),
(1924, 107, '34', 'Veneto', '威尼托', '威尼托', 45.4414662, 12.3152595),
(1925, 107, 'VB', 'Verbano-Cusio-Ossola', '韋爾巴諾-庫西奧-奧索拉', '韦尔巴诺-库西奥-奥索拉', 46.1399688, 8.2724649),
(1926, 107, 'VC', 'Vercelli', '韋爾切利', '韦尔切利', 45.3202204, 8.4185080),
(1927, 107, 'VR', 'Verona', '維羅納', '维罗纳', 45.4418498, 11.0735316),
(1928, 107, 'VV', 'Vibo Valentia', '維博·瓦倫蒂亞', '维博·瓦伦蒂亚', 38.6378565, 16.2051484),
(1929, 107, 'VI', 'Vicenza', '維琴察', '维琴察', 45.6983995, 11.5661465),
(1930, 107, 'VT', 'Viterbo', '維泰博', '维泰博', 42.4002420, 11.8891721),
(1931, 108, '13', 'Clarendon', '克拉倫登', '克拉伦登', 17.9557183, -77.2405153),
(1932, 108, '09', 'Hanover', '漢諾威', '汉诺威', 18.4097707, -78.1336380),
(1933, 108, '01', 'Kingston', '金斯頓', '金斯敦', 17.9683271, -76.7827020),
(1934, 108, '12', 'Manchester', '曼徹斯特', '曼彻斯特', 18.0669654, -77.5160788),
(1935, 108, '04', 'Portland', '波特蘭', '波特兰', 18.0844274, -76.4100267),
(1936, 108, '02', 'Saint Andrew', '聖安德魯', '圣安德鲁', 37.2245103, -95.7021189),
(1937, 108, '06', 'Saint Ann', '聖安', '圣安', 37.2871452, -77.4103533),
(1938, 108, '14', 'Saint Catherine', '聖凱瑟琳', '圣凯瑟琳', 18.0364134, -77.0564464),
(1939, 108, '11', 'Saint Elizabeth', '聖伊麗莎白', '圣伊丽莎白', 38.9925308, -94.5899200),
(1940, 108, '08', 'Saint James', '聖雅各', '圣詹姆斯', 30.0179292, -90.7913227),
(1941, 108, '05', 'Saint Mary', '聖瑪麗', '圣玛丽', 36.0925220, -95.9738440),
(1942, 108, '03', 'Saint Thomas', '聖托馬斯', '圣托马斯', 41.4425389, -81.7402218),
(1943, 108, '07', 'Trelawny', '特里勞尼', '特里劳尼', 18.3526143, -77.6077865),
(1944, 108, '10', 'Westmoreland', '威斯特摩蘭', '威斯特摩兰', 18.2944378, -78.1564432),
(1945, 109, '23', 'Aichi', '愛知縣', '爱知县', 35.0182505, 137.2923893),
(1946, 109, '05', 'Akita', '秋田縣', '秋田', 40.1376293, 140.3343410),
(1947, 109, '02', 'Aomori', '青森縣', '青森', 40.7657077, 140.9175879),
(1948, 109, '12', 'Chiba', '千葉縣', '千叶', 35.3354155, 140.1832516),
(1949, 109, '38', 'Ehime', '愛媛縣', '爱媛县', 33.6025306, 132.7857583),
(1950, 109, '18', 'Fukui', '福井縣', '福井县', 35.8962270, 136.2111579),
(1951, 109, '40', 'Fukuoka', '福岡', '福冈', 33.5662559, 130.7158570),
(1952, 109, '07', 'Fukushima', '福島', '福岛', 37.3834373, 140.1832516),
(1953, 109, '21', 'Gifu', '岐阜縣', '岐阜县', 35.7437491, 136.9805103),
(1954, 109, '10', 'Gunma', '群馬縣', '群马县', 36.5605388, 138.8799972),
(1955, 109, '34', 'Hiroshima', '廣島', '广岛', 34.8823408, 133.0194897),
(1956, 109, '01', 'Hokkaidō', '北海道', '北海道', 43.2203266, 142.8634737),
(1957, 109, '28', 'Hyōgo', '兵庫縣', '兵库县', 34.8579518, 134.5453787),
(1958, 109, '08', 'Ibaraki', '茨城縣', '茨城县', 36.2193571, 140.1832516),
(1959, 109, '17', 'Ishikawa', '石川縣', '石川县', 36.3260317, 136.5289653),
(1960, 109, '03', 'Iwate', '岩手縣', '岩手县', 39.5832989, 141.2534574),
(1961, 109, '37', 'Kagawa', '香川縣', '香川县', 34.2225915, 134.0199152),
(1962, 109, '46', 'Kagoshima', '鹿兒島', '鹿儿岛', 31.3911958, 130.8778586),
(1963, 109, '14', 'Kanagawa', '神奈川縣', '神奈川县', 35.4913535, 139.2841430),
(1964, 109, '39', 'Kōchi', '高知縣', '高知县', 33.2879161, 132.2759262),
(1965, 109, '43', 'Kumamoto', '熊本縣', '熊本县', 32.8594427, 130.7969149),
(1966, 109, '26', 'Kyōto', '京都', '京都', 35.1566609, 135.5251982),
(1967, 109, '24', 'Mie', '我的', '我', 33.8143901, 136.0487047),
(1968, 109, '04', 'Miyagi', '宮城縣', '宫城县', 38.6306120, 141.1193048),
(1969, 109, '45', 'Miyazaki', '宮崎駿', '宫崎骏', 32.6036022, 131.4412510),
(1970, 109, '20', 'Nagano', '長野', '长野', 36.1543941, 137.9218204),
(1971, 109, '42', 'Nagasaki', '長崎', '长崎', 33.2488525, 129.6930912),
(1972, 109, '29', 'Nara', '奈良', '奈良', 34.2975528, 135.8279734),
(1973, 109, '15', 'Niigata', '新潟縣', '新泻县', 37.5178386, 138.9269794),
(1974, 109, '44', 'Ōita', '大分縣', '大分县', 33.1589299, 131.3611121),
(1975, 109, '33', 'Okayama', '岡山', '冈山县', 34.8963407, 133.6375314),
(1976, 109, '47', 'Okinawa', '沖繩', '冲绳', 26.1201911, 127.7025012),
(1977, 109, '27', 'Ōsaka', '大阪', '大阪', 34.6413315, 135.5629394),
(1978, 109, '41', 'Saga', '佐賀', '传奇', 33.3078371, 130.2271243),
(1979, 109, '11', 'Saitama', '埼玉縣', '埼玉县', 35.9962513, 139.4466005),
(1980, 109, '25', 'Shiga', '滋賀縣', '滋贺县', 35.3292014, 136.0563212),
(1981, 109, '32', 'Shimane', '島根縣', '岛根县', 35.1244094, 132.6293446),
(1982, 109, '22', 'Shizuoka', '靜岡縣', '静冈县', 35.0929397, 138.3190276),
(1983, 109, '09', 'Tochigi', '栃木縣', '栃木县', 36.6714739, 139.8547266),
(1984, 109, '36', 'Tokushima', '德島縣', '德岛', 33.9419655, 134.3236557),
(1985, 109, '13', 'Tokyo', '東京', '东京', 35.6761919, 139.6503106),
(1986, 109, '31', 'Tottori', '鳥取縣', '鸟取县', 35.3573161, 133.4066618),
(1987, 109, '16', 'Toyama', '富山縣', '富山', 36.6958266, 137.2137071),
(1988, 109, '30', 'Wakayama', '和歌山縣', '和歌山县', 33.9480914, 135.3745358),
(1989, 109, '06', 'Yamagata', '山形縣', '山形', 38.5370564, 140.1435198),
(1990, 109, '35', 'Yamaguchi', '山口縣', '山口县', 34.2796769, 131.5212742),
(1991, 109, '19', 'Yamanashi', '山梨縣', '山梨县', 35.6635113, 138.6388879),
(1992, 110, '01', 'Grouville', '格魯維爾', '格劳维尔', 49.1821257, -2.0941981),
(1993, 110, '02', 'St Brelade', '聖布雷拉德', '圣布雷拉德', 49.1848800, -2.2468508),
(1994, 110, '03', 'St Clement', '聖克萊門特', '圣克莱门特', 49.1696579, -2.0883934),
(1995, 110, '04', 'St Helier', '聖赫利爾', '圣赫利尔', 49.1811523, -2.1257426),
(1996, 110, '05', 'St John', '聖約翰', '圣约翰', 49.2391257, -2.1802684),
(1997, 110, '06', 'St Lawrence', '聖勞倫斯', '圣劳伦斯', 49.2152748, -2.1820770),
(1998, 110, '07', 'St Martin', '聖馬丁', '圣马丁', 49.2164149, -2.0813339),
(1999, 110, '08', 'St Mary', '聖瑪麗', '圣玛丽', 49.2378181, -2.1952213),
(2000, 110, '09', 'St Ouen', '聖旺', '圣旺', 49.2368076, -2.2583597),
(2001, 110, '10', 'St Peter', '聖彼得', '圣彼得', 49.2144278, -2.2323431),
(2002, 110, '11', 'St Saviour', '聖救世主', '圣救世主', 49.2011989, -2.1125739),
(2003, 110, '12', 'Trinity', '三位一體', '三位一体', 49.2305900, -2.1199936),
(2004, 111, 'AJ', 'Ajloun', '阿傑隆', '阿杰伦', 32.3325584, 35.7516844),
(2005, 111, 'AM', 'Amman', '安曼', '安曼', 31.9453633, 35.9283895),
(2006, 111, 'AQ', 'Aqaba', '亞喀巴', '亚喀巴', 29.5320860, 35.0062821),
(2007, 111, 'BA', 'Balqa', '巴爾卡', '巴尔卡', 32.0366806, 35.7288480),
(2008, 111, 'IR', 'Irbid', '伊爾比德', '伊尔比德', 32.5569636, 35.8478965),
(2009, 111, 'JA', 'Jerash', '傑拉什', '杰拉什', 32.2747237, 35.8960954),
(2010, 111, 'KA', 'Karak', '卡拉克', '卡拉克', 31.1853527, 35.7047682),
(2011, 111, 'MN', 'Ma\'an', '卻', '但', 30.1926789, 35.7249319),
(2012, 111, 'MD', 'Madaba', '馬達巴', '马达巴', 31.7196097, 35.7932754),
(2013, 111, 'MA', 'Mafraq', '馬弗拉克', '马弗拉克', 32.3416923, 36.2020175),
(2014, 111, 'AT', 'Tafilah', '塔菲拉', '塔菲拉', 30.8338063, 35.6160513),
(2015, 111, 'AZ', 'Zarqa', '扎卡', '扎尔卡', 32.0608505, 36.0942121),
(2016, 112, 'AKM', 'Akmola', '阿克莫拉', '阿克莫拉', 51.9165320, 69.4110494),
(2017, 112, 'AKT', 'Aktobe', '阿克托貝', '阿克托贝', 48.7797078, 57.9974378),
(2018, 112, 'ALM', 'Almaty', '阿拉木圖', '阿拉木图', 45.0119227, 78.4229392),
(2019, 112, 'ALA', 'Almaty', '阿拉木圖', '阿拉木图', 43.2220146, 76.8512485),
(2020, 112, 'AST', 'Astana', '阿斯塔納', '阿斯塔纳', 51.1605227, 71.4703558),
(2021, 112, 'ATY', 'Atyrau', '阿特勞', '阿特劳', 47.1076188, 51.9141330),
(2022, 112, 'BAY', 'Baikonur', '拜科努爾', '拜科努尔', 45.9645851, 63.3052428),
(2023, 112, 'VOS', 'East Kazakhstan', '東哈薩克斯坦', '东哈萨克斯坦', 48.7062687, 80.7922534),
(2024, 112, 'ZHA', 'Jambyl', '詹比爾', '詹比尔', 44.2220308, 72.3657967),
(2025, 112, 'KAR', 'Karaganda', '卡拉干達', '卡拉干达', 47.9022182, 71.7706807),
(2026, 112, 'KUS', 'Kostanay', '科斯塔奈', '科斯塔奈', 51.5077096, 64.0479073),
(2027, 112, 'KZY', 'Kyzylorda', '克孜勒奧爾達', '克孜勒奥尔达', 44.6922613, 62.6571885),
(2028, 112, 'MAN', 'Mangystau', '曼吉斯陶', '曼吉斯陶', 44.5908020, 53.8499508),
(2029, 112, 'SEV', 'North Kazakhstan', '北哈薩克斯坦', '北哈萨克斯坦', 54.1622066, 69.9387071),
(2030, 112, 'PAV', 'Pavlodar', '巴甫洛達爾', '巴甫洛达尔', 52.2878444, 76.9733453),
(2031, 112, 'YUZ', 'Turkestan', '土耳其斯坦', '突', 43.3666958, 68.4094405),
(2032, 112, 'ZAP', 'West Kazakhstan', '西哈薩克斯坦', '西哈萨克斯坦', 49.5679727, 50.8066616),
(2033, 113, '01', 'Baringo', '巴林戈', '巴林戈', 0.8554988, 36.0893406),
(2034, 113, '02', 'Bomet', '博美特', '博美特', -0.8015009, 35.3027226),
(2035, 113, '03', 'Bungoma', '邦戈馬', '邦戈马', 0.5695252, 34.5583766),
(2036, 113, '04', 'Busia', '布西亞', '布西亚', 0.4346506, 34.2421597),
(2037, 113, '05', 'Elgeyo-Marakwet', '埃爾格約-馬拉克韋特', '埃尔格约-马拉克韦特', 1.0498237, 35.4781926),
(2038, 113, '06', 'Embu', '恩布', '恩布', -0.6560477, 37.7237678),
(2039, 113, '07', 'Garissa', '加里薩', '加里萨', -0.4532293, 39.6460988),
(2040, 113, '08', 'Homa Bay', '霍馬灣', '霍马湾', -0.6220655, 34.3310364),
(2041, 113, '09', 'Isiolo', '伊西奧洛', '伊西奥洛', 0.3524352, 38.4849923),
(2042, 113, '10', 'Kajiado', '卡加多', '卡加多', -2.0980751, 36.7819505),
(2043, 113, '11', 'Kakamega', '卡卡梅加', '卡卡梅加', 0.3078940, 34.7740793),
(2044, 113, '12', 'Kericho', '凱里喬', '凯里乔', -0.1827913, 35.4781926),
(2045, 113, '13', 'Kiambu', '基安布', '基安布', -1.0313701, 36.8680791),
(2046, 113, '14', 'Kilifi', '基利菲', '基利菲', -3.5106508, 39.9093269),
(2047, 113, '15', 'Kirinyaga', '麒麟屋', '麒麟亚加', -0.6590565, 37.3827234),
(2048, 113, '16', 'Kisii', '基西', '基西', -0.6773340, 34.7796030),
(2049, 113, '17', 'Kisumu', '基蘇木', '基苏木', -0.0917016, 34.7679568),
(2050, 113, '18', 'Kitui', '基圖伊', '基图伊', -1.6832822, 38.3165725),
(2051, 113, '19', 'Kwale', '誇勒', '夸勒', -4.1816115, 39.4605612),
(2052, 113, '20', 'Laikipia', '萊基皮亞', '莱基皮亚', 0.3606063, 36.7819505),
(2053, 113, '21', 'Lamu', '駱駝', '骆马', -2.2355058, 40.4720004),
(2054, 113, '22', 'Machakos', '馬查科斯', '马查科斯', -1.5176837, 37.2634146),
(2055, 113, '23', 'Makueni', '麥肯齊', '麦肯齐', -2.2558734, 37.8936663),
(2056, 113, '24', 'Mandera', '曼德拉', '曼德拉', 3.5737991, 40.9586880),
(2057, 113, '25', 'Marsabit', '馬薩比特', '马萨比特', 2.4426403, 37.9784585),
(2058, 113, '26', 'Meru', '梅魯', '梅鲁', 0.3557174, 37.8087693),
(2059, 113, '27', 'Migori', '米戈里', '米戈里', -0.9365702, 34.4198243),
(2060, 113, '28', 'Mombasa', '蒙巴薩', '蒙巴萨', -3.9768291, 39.7137181),
(2061, 113, '29', 'Murang\'a', '穆朗', '穆朗', -0.7839281, 37.0400339),
(2062, 113, '30', 'Nairobi City', '內羅畢市', '内罗毕市', -1.2920659, 36.8219462),
(2063, 113, '31', 'Nakuru', '納庫魯', '纳库鲁', -0.3030988, 36.0800260),
(2064, 113, '32', 'Nandi', '南迪', '南迪', 0.1835867, 35.1268781),
(2065, 113, '33', 'Narok', '納羅克', '纳罗克', -1.1041110, 36.0893406),
(2066, 113, '34', 'Nyamira', '尼亞米拉', '尼亚米拉', -0.5669405, 34.9341234),
(2067, 113, '35', 'Nyandarua', '尼亞達魯阿', '尼亚达鲁阿', -0.1803855, 36.5229641),
(2068, 113, '36', 'Nyeri', '涅里', '涅里', -0.4196915, 37.0400339),
(2069, 113, '37', 'Samburu', '桑布魯', '桑布鲁', 1.2154506, 36.9541070),
(2070, 113, '38', 'Siaya', '西亞亞', '西亚亚', -0.0617328, 34.2421597),
(2071, 113, '39', 'Taita–Taveta', '泰塔-塔維塔', '泰塔-塔维塔', -3.3160687, 38.4849923),
(2072, 113, '40', 'Tana River', '塔納河', '塔纳河', -1.6518468, 39.6518165),
(2073, 113, '41', 'Tharaka-Nithi', '塔拉卡-尼蒂', '塔拉卡-尼蒂', -0.2964851, 37.7237678),
(2074, 113, '42', 'Trans Nzoia', '跨恩佐亞', '跨恩佐亚', 1.0566667, 34.9506625),
(2075, 113, '43', 'Turkana', '圖爾卡納', '图尔卡纳', 3.3122477, 35.5657862),
(2076, 113, '44', 'Uasin Gishu', '烏阿辛吉舒', '乌阿辛吉舒', 0.5527638, 35.3027226),
(2077, 113, '45', 'Vihiga', '維希加', '维希加', 0.0767553, 34.7077665),
(2078, 113, '46', 'Wajir', '瓦吉爾', '瓦吉尔', 1.6360475, 40.3088626),
(2079, 113, '47', 'West Pokot', '西波科特', '西波科特', 1.6210076, 35.3905046),
(2080, 114, 'G', 'Gilbert', '吉爾伯特', '吉尔伯特', 0.3524262, 174.7552634),
(2081, 114, 'L', 'Line', '線', '线', 1.7429439, -157.2132826),
(2082, 114, 'P', 'Phoenix', '鳳凰', '凤凰', 33.3284369, -111.9824774),
(2083, 248, 'XUF', 'Ferizaj', '費里扎伊', '费里扎伊', 42.3701844, 21.1483281),
(2084, 248, 'XDG', 'Gjakove', '賈科娃', '贾科娃', 42.4375756, 20.3785438),
(2085, 248, 'XGJ', 'Gjilan', '吉蘭', '吉兰', 42.4635206, 21.4694011),
(2086, 248, 'XKM', 'Mitrovica', '米特羅維察', '米特罗维察', 42.8913909, 20.8659995),
(2087, 248, 'PEJ', 'Peja', '佩賈', '佩贾', 42.7031709, 20.0616855),
(2088, 248, 'XPI', 'Pristina', '普里什蒂納', '普里什蒂纳', 42.6629138, 21.1655028),
(2089, 248, 'PRI', 'Prizren', '普里茲倫', '普里兹伦', 42.2324565, 20.4039366),
(2090, 117, 'AH', 'Al Ahmadi', '艾哈邁迪', '艾哈迈迪', 28.5745125, 48.1024743),
(2091, 117, 'KU', 'Al Asimah', '阿爾阿西瑪', '阿尔阿西玛', 26.2285161, 50.5860497),
(2092, 117, 'FA', 'Al Farwaniyah', '阿爾·法瓦尼亞', '阿尔法瓦尼亚', 29.2733570, 47.9400154),
(2093, 117, 'JA', 'Al Jahra', '賈赫拉', '贾赫拉', 29.9931831, 47.7634731),
(2094, 117, 'HA', 'Hawalli', '哈瓦利', '哈瓦利', 29.3056716, 48.0307613),
(2095, 117, 'MU', 'Mubarak Al-Kabeer', '穆巴拉克·卡比爾', '穆巴拉克·卡比尔', 29.2122400, 48.0605108),
(2096, 118, 'B', 'Batken', '巴特肯', '巴特肯', 39.9721425, 69.8597406),
(2097, 118, 'GB', 'Bishkek', '比什凱克', '比什凯克', 42.8746212, 74.5697617),
(2098, 118, 'C', 'Chuy', '楚伊', '楚伊', 42.5655000, 74.4056612),
(2099, 118, 'Y', 'Issyk-Kul', '伊塞克庫爾', '伊塞克湖', 42.1859428, 77.5619419),
(2100, 118, 'J', 'Jalal-Abad', '賈拉拉巴德', '贾拉拉巴德', 41.1068080, 72.8988069),
(2101, 118, 'N', 'Naryn', '納林', '纳林', 41.2943227, 75.3412179),
(2102, 118, 'GO', 'Osh', '奧什', '奥什', 36.0631399, -95.9182895),
(2103, 118, 'O', 'Osh', '奧什', '奥什', 39.8407366, 72.8988069),
(2104, 118, 'T', 'Talas', '怛羅斯', '怛罗斯', 42.2867339, 72.5204827),
(2105, 119, 'AT', 'Attapeu', '阿速坡', '阿速坡', 14.9363400, 107.1011931),
(2106, 119, 'BK', 'Bokeo', '博克', '博克', 20.2872662, 100.7097867),
(2107, 119, 'BL', 'Bolikhamsai', '博利卡姆賽', '博利卡姆赛', 18.4362924, 104.4723301),
(2108, 119, 'CH', 'Champasak', '占城', '占巴塞', 14.6578664, 105.9699878),
(2109, 119, 'HO', 'Houaphanh', '胡阿潘', '胡阿潘', 20.3254175, 104.1001326),
(2110, 119, 'KH', 'Khammouane', '卡穆安', '卡穆安', 17.6384066, 105.2194808),
(2111, 119, 'LM', 'Luang Namtha', '鑾南塔', '銮南塔', 20.9170187, 101.1617356),
(2112, 119, 'LP', 'Luang Prabang', '瑯勃拉邦', '琅勃拉邦', 20.0656229, 102.6216211),
(2113, 119, 'OU', 'Oudomxay', '烏多姆凱', '乌多姆凯', 20.4921929, 101.8891721),
(2114, 119, 'PH', 'Phongsaly', '豐薩利', '丰萨利', 21.5919377, 102.2547919),
(2115, 119, 'XA', 'Sainyabuli', '賽尼亞布利', '赛尼亚布利', 19.3907886, 101.5248055),
(2116, 119, 'SL', 'Salavan', '薩拉萬', '萨拉万', 15.8171073, 106.2522143),
(2117, 119, 'SV', 'Savannakhet', '沙灣拿吉', '沙湾拿吉', 16.5065381, 105.5943388),
(2118, 119, 'XE', 'Sekong', '色空', '色空', 15.5767446, 107.0067031),
(2119, 119, 'VI', 'Vientiane', '萬象', '万象', 18.5705063, 102.6216211),
(2120, 119, 'VT', 'Vientiane', '萬象', '万象', 18.1105410, 102.5298028),
(2121, 119, 'XS', 'Xaisomboun', '賽松邦', 'Xaisomboun', 18.4362924, 104.4723301),
(2122, 119, 'XI', 'Xiangkhouang', '香侯昂', '香侯昂', 19.6093003, 103.7289167),
(2123, 120, '011', 'Ādaži', '阿達茲', '阿达齐', 57.1112456, 24.1482311),
(2124, 120, '002', 'Aizkraukle', '艾茲克勞克爾', '艾兹克劳克尔', 56.6461080, 25.2370854),
(2125, 120, '007', 'Alūksne', 'Alūksne', 'Alūksne', 57.4254485, 27.0424968),
(2126, 120, '111', 'Augšdaugava', '奧格斯道加瓦', '奥格斯道加瓦', 55.9396978, 25.7431709),
(2127, 120, '015', 'Balvi', '巴爾維', '巴尔维', 57.1326240, 27.2646685),
(2128, 120, '016', 'Bauska', '鮑斯卡', '鲍斯卡', 56.4101868, 24.2000689),
(2129, 120, '022', 'Cēsis', '塞西斯', 'Cēsis', 57.3102897, 25.2676125),
(2130, 120, 'DGV', 'Daugavpils', '道格夫匹爾斯', '道格夫匹尔斯', 55.8747360, 26.5361790),
(2131, 120, '112', 'Dienvidkurzemes', '南庫澤姆', '南库尔泽梅', 56.5206312, 20.8321176),
(2132, 120, '026', 'Dobele', '多貝勒', '多贝勒', 56.6263050, 23.2809066),
(2133, 120, '033', 'Gulbene', '古爾本', '古尔本', 57.2155645, 26.6452955),
(2134, 120, '042', 'Jēkabpils', '傑卡皮爾斯', '杰卡皮尔斯', 56.2919320, 25.9812017),
(2135, 120, '041', 'Jelgava', '耶爾加瓦', '耶尔加瓦', 56.5895689, 23.6610481),
(2136, 120, 'JEL', 'Jelgava', '耶爾加瓦', '耶尔加瓦', 56.6511091, 23.7213541),
(2137, 120, 'JUR', 'Jūrmala', '尤爾馬拉', '尤尔马拉', 56.9470790, 23.6168485),
(2138, 120, '052', 'Ķekava', '伊卡瓦', '伊卡瓦', 56.8064351, 24.1939493),
(2139, 120, '047', 'Krāslava', '克拉斯拉瓦', '克拉斯拉瓦', 55.8951464, 27.1814577),
(2140, 120, '050', 'Kuldīga', '庫爾迪加', '库尔迪加', 56.9687257, 21.9613739),
(2141, 120, 'LPX', 'Liepāja', '利耶帕賈', '利耶帕亚', 56.5046678, 21.0108060),
(2142, 120, '054', 'Limbaži', '林巴日', '林巴日', 57.5403227, 24.7134451),
(2143, 120, '056', 'Līvāni', '利瓦尼', '利瓦尼', 56.3550942, 26.1725190),
(2144, 120, '058', 'Ludza', '盧扎', '卢扎', 56.5459590, 27.7143199),
(2145, 120, '059', 'Madona', '聖母像', '圣母玛利亚', 56.8598923, 26.2276201),
(2146, 120, '062', 'Mārupe', '馬魯佩', '马鲁佩', 56.8965717, 24.0460049),
(2147, 120, '067', 'Ogre', '食人魔', '怪物', 56.8147355, 24.6044555),
(2148, 120, '068', 'Olaine', '奧萊恩', '奥莱恩', 56.7952353, 24.0153589),
(2149, 120, '073', 'Preiļi', 'Preiļi', 'Preiļi', 56.1511157, 26.7439767),
(2150, 120, 'REZ', 'Rēzekne', 'Rēzekne', 'Rēzekne', 56.5099223, 27.3331357),
(2151, 120, '077', 'Rēzekne', 'Rēzekne', 'Rēzekne', 56.3273638, 27.3284331),
(2152, 120, 'RIX', 'Riga', '里加', '里加', 56.9496487, 24.1051865),
(2153, 120, '080', 'Ropaži', 'Ropaži', 'Ropaži', 56.9615786, 24.6010476),
(2154, 120, '087', 'Salaspils', '薩拉斯皮爾斯', '萨拉斯皮尔斯', 56.8608152, 24.3497881),
(2155, 120, '088', 'Saldus', '甜', '甜', 56.6665088, 22.4935493),
(2156, 120, '089', 'Saulkrasti', '索爾克拉斯蒂', '索尔克拉斯蒂', 57.2579418, 24.4183146),
(2157, 120, '091', 'Sigulda', '西古爾達', '西古尔达', 57.1055092, 24.8314259),
(2158, 120, '094', 'Smiltene', '斯米爾滕', '斯米尔滕', 57.4230332, 25.9002780),
(2159, 120, '097', 'Talsi', '塔爾西', '塔尔西', 57.3415208, 22.5713125),
(2160, 120, '099', 'Tukums', '圖庫姆斯', '图库姆斯', 56.9672868, 23.1524379),
(2161, 120, '101', 'Valka', '戰', '战争', 57.7743900, 26.0170050),
(2162, 120, '113', 'Valmiera', '瓦爾米埃拉', '瓦尔米耶拉', 57.5384659, 25.4263618),
(2163, 120, '102', 'Varakļāni', '瓦拉凱尼', '瓦拉凯尼', 56.6688006, 26.5636414);
INSERT INTO `location_states` (`state_id`, `country_id`, `state_code`, `state_name_en`, `state_name_zh_tw`, `state_name_zh_cn`, `state_center_latitude`, `state_center_longitude`) VALUES
(2164, 120, 'VEN', 'Ventspils', '文茨皮爾斯', '文茨皮尔斯', 57.3937216, 21.5647066),
(2165, 120, '106', 'Ventspils', '文茨皮爾斯', '文茨皮尔斯', 57.2833682, 21.8587558),
(2166, 121, 'AK', 'Akkar', '阿卡爾', '阿卡尔', 34.5328763, 36.1328132),
(2167, 121, 'BH', 'Baalbek-Hermel', '巴勒貝克-赫梅爾', '巴勒贝克-赫梅尔', 34.2658556, 36.3498097),
(2168, 121, 'BA', 'Beirut', '貝魯特', '贝鲁特', 33.8886106, 35.4954772),
(2169, 121, 'BI', 'Beqaa', '貝卡', '贝卡', 33.8462662, 35.9019489),
(2170, 121, 'JL', 'Mount Lebanon', '黎巴嫩山', '黎巴嫩山', 33.8100858, 35.5973139),
(2171, 121, 'NA', 'Nabatieh', '納巴蒂耶', '纳巴蒂赫', 33.3771693, 35.4838293),
(2172, 121, 'AS', 'North', '北', '北', 34.4380625, 35.8308233),
(2173, 121, 'JA', 'South', '南', '南', 33.2721479, 35.2032778),
(2174, 122, 'D', 'Berea', '伯里亞', '伯里亚', 41.3661614, -81.8543026),
(2175, 122, 'B', 'Butha-Buthe', '布塔-布特', '布塔-布特', -28.7653754, 28.2468148),
(2176, 122, 'C', 'Leribe', '萊里貝', '莱里贝', -28.8638065, 28.0478826),
(2177, 122, 'E', 'Mafeteng', '馬非騰', '马非腾', -29.8041008, 27.5026174),
(2178, 122, 'A', 'Maseru', '馬塞盧', '马塞卢', -29.5165650, 27.8311428),
(2179, 122, 'F', 'Mohale\'s Hoek', '莫哈爾', '莫哈勒', -30.1425917, 27.4673845),
(2180, 122, 'J', 'Mokhotlong', '莫霍特隆', '莫霍特隆', -29.2573193, 28.9528645),
(2181, 122, 'H', 'Qacha\'s Nek', '卡查', '卡查', -30.1114565, 28.6789790),
(2182, 122, 'G', 'Quthing', 'Quthing', 'Quthing', -30.4015687, 27.7080133),
(2183, 122, 'K', 'Thaba-Tseka', '塔巴-采卡', '塔巴-采卡', -29.5238975, 28.6089752),
(2184, 123, 'BM', 'Bomi', '波米', '波米', 6.7562926, -10.8451467),
(2185, 123, 'BG', 'Bong', '斯圖爾特·奧特', '斯图尔特·奥特', 6.8295019, -9.3673084),
(2186, 123, 'GP', 'Gbarpolu', '格巴波盧', '格巴波卢', 7.4952637, -10.0807298),
(2187, 123, 'GB', 'Grand Bassa', '大巴薩', '大巴萨', 6.2308452, -9.8124935),
(2188, 123, 'CM', 'Grand Cape Mount', '大岬山', '大角山', 7.0467758, -11.0711758),
(2189, 123, 'GG', 'Grand Gedeh', '大基德', '大格德', 5.9222078, -8.2212979),
(2190, 123, 'GK', 'Grand Kru', '大克魯', '大克鲁', 4.7613862, -8.2212979),
(2191, 123, 'LO', 'Lofa', '洛法', '洛法', 8.1911184, -9.7232673),
(2192, 123, 'MG', 'Margibi', '馬利克', '马利克', 6.5151875, -10.3048897),
(2193, 123, 'MY', 'Maryland', '馬里蘭州', '马里兰', 39.0457549, -76.6412712),
(2194, 123, 'MO', 'Montserrado', '蒙特塞拉多', '蒙特塞拉多', 6.5525815, -10.5296115),
(2195, 123, 'NI', 'Nimba', '寧巴', '宁巴', 7.6166667, -8.4166667),
(2196, 123, 'RI', 'River Cess', '塞斯河', '塞斯河', 5.9025328, -9.4561550),
(2197, 123, 'RG', 'River Gee', '吉河', '吉河', 5.2604894, -7.8721600),
(2198, 123, 'SI', 'Sinoe', '錫諾', '锡诺', 5.4987100, -8.6600586),
(2199, 124, 'WA', 'Al Wahat', '阿爾瓦哈特', '阿尔瓦哈特', 29.0466808, 21.8568586),
(2200, 124, 'BA', 'Benghazi', '班加西', '班加西', 32.1194242, 20.0867909),
(2201, 124, 'DR', 'Derna', '德爾納', '德尔纳', 32.7556130, 22.6377432),
(2202, 124, 'GT', 'Ghat', '高止山脈', '高止山脉', 24.9640371, 10.1759285),
(2203, 124, 'JA', 'Jabal al Akhdar', '賈巴爾·阿赫達爾', '贾巴尔·阿赫达尔', 23.1856081, 57.3713879),
(2204, 124, 'JG', 'Jabal al Gharbi', '賈巴爾·加爾比', '贾巴尔·加尔比', 30.2638032, 12.8054753),
(2205, 124, 'JI', 'Jafara', '賈法拉', '贾法拉', 32.4525904, 12.9435536),
(2206, 124, 'JU', 'Jufra', '朱弗拉', '朱夫拉', 27.9835135, 16.9122510),
(2207, 124, 'KF', 'Kufra', '庫夫拉', '库夫拉', 23.3112389, 21.8568586),
(2208, 124, 'MJ', 'Marj', '瑪吉', '玛吉', 32.0550363, 21.1891151),
(2209, 124, 'MI', 'Misrata', '米蘇拉塔', '米苏拉塔', 32.3255884, 15.0992556),
(2210, 124, 'MB', 'Murqub', '默庫布', '默库布', 32.4599677, 14.1001326),
(2211, 124, 'MQ', 'Murzuq', '穆爾祖克', '穆尔祖克', 25.9182262, 13.9260001),
(2212, 124, 'NL', 'Nalut', '納魯特', '纳鲁特', 31.8742348, 10.9750484),
(2213, 124, 'NQ', 'Nuqat al Khams', '努卡特·卡姆斯', '努卡特·卡姆斯', 32.6914909, 11.8891721),
(2214, 124, 'SB', 'Sabha', '薩卜哈', '萨卜哈', 27.0365406, 14.4290236),
(2215, 124, 'SR', 'Sirte', '蘇爾特', '苏尔特', 31.1896890, 16.5701927),
(2216, 124, 'TB', 'Tripoli', '的黎波里', '的黎波里', 32.6408021, 13.2663479),
(2217, 124, 'WD', 'Wadi al Hayaa', '哈亞河谷', '哈亚河谷', 26.4225926, 12.6216211),
(2218, 124, 'WS', 'Wadi al Shatii', '瓦迪沙蒂', '沙蒂河谷', 27.7351468, 12.4380581),
(2219, 124, 'ZA', 'Zawiya', '扎維亞', '扎维亚', 32.7630282, 12.7364962),
(2220, 125, '01', 'Balzers', '巴爾查斯', '巴尔查斯', 42.0528357, -88.0366848),
(2221, 125, '02', 'Eschen', '灰燼', '苍白', 40.7669574, -73.9522821),
(2222, 125, '03', 'Gamprin', '甘普林', '甘普林', 47.2132490, 9.5025195),
(2223, 125, '04', 'Mauren', '摩爾人', '荒原', 47.2189285, 9.5417350),
(2224, 125, '05', 'Planken', '架子', '货架', 40.6650576, -73.5047980),
(2225, 125, '06', 'Ruggell', '拉格爾', '拉格尔', 47.2529222, 9.5402127),
(2226, 125, '07', 'Schaan', '沙恩', '沙恩', 47.1204340, 9.5941602),
(2227, 125, '08', 'Schellenberg', '謝倫伯格', '谢伦贝格', 47.2309660, 9.5467843),
(2228, 125, '09', 'Triesen', '特里森', '特里森', 47.1097988, 9.5248296),
(2229, 125, '10', 'Triesenberg', '特里森貝格', '特里森贝格', 47.1224511, 9.5701985),
(2230, 125, '11', 'Vaduz', '瓦杜茲', '瓦杜兹', 47.1410303, 9.5209277),
(2231, 126, '01', 'Akmenė', '阿克梅涅', 'Akmenė', 56.2455029, 22.7471169),
(2232, 126, '03', 'Alytus', '艾莉圖斯', '艾莉图斯', 54.3297496, 24.1960931),
(2233, 126, 'AL', 'Alytus', '艾莉圖斯', '艾莉图斯', 54.2000214, 24.1512634),
(2234, 126, '02', 'Alytus', '艾莉圖斯', '艾莉图斯', 54.3962938, 24.0458761),
(2235, 126, '04', 'Anykščiai', 'Anykščiai', 'Anykščiai', 55.5475551, 24.7318166),
(2236, 126, '05', 'Birštonas', '比爾什托納斯', '比尔什托纳斯', 54.5669664, 24.0093098),
(2237, 126, '06', 'Biržai', '比爾扎伊', 'Biržai', 56.2017719, 24.7560118),
(2238, 126, '07', 'Druskininkai', '德魯斯基寧凱', '德鲁斯基宁凯', 53.9933685, 24.0342438),
(2239, 126, '08', 'Elektrėnai', 'Elektrėnai', 'Elektrėnai', 54.7653934, 24.7740583),
(2240, 126, '09', 'Ignalina', '伊格納琳娜', '伊格纳利娜', 55.4090342, 26.3284893),
(2241, 126, '10', 'Jonava', '喬納瓦', '乔纳瓦', 55.0727242, 24.2793337),
(2242, 126, '11', 'Joniškis', '約尼什基斯', '约尼什基斯', 56.2360730, 23.6136579),
(2243, 126, '12', 'Jurbarkas', '尤爾巴卡斯', '尤尔巴卡斯', 55.0774070, 22.7419569),
(2244, 126, '13', 'Kaišiadorys', '凱希亞多里斯', '凯希亚多里斯', 54.8588669, 24.4277929),
(2245, 126, '14', 'Kalvarija', '髑髏地', '髑髅山', 54.3761674, 23.1920321),
(2246, 126, '16', 'Kaunas', '考納斯', '考纳斯', 54.9936236, 23.6324941),
(2247, 126, 'KU', 'Kaunas', '考納斯', '考纳斯', 54.9872863, 23.9525736),
(2248, 126, '15', 'Kaunas', '考納斯', '考纳斯', 54.9145326, 23.9053518),
(2249, 126, '17', 'Kazlų Rūda', '卡茲魯魯達', '卡兹鲁鲁达', 54.7807526, 23.4840243),
(2250, 126, '18', 'Kėdainiai', '凱戴尼亞伊', 'Kėdainiai', 55.3560947, 23.9832683),
(2251, 126, '19', 'Kelmė', '凱爾梅', '凯尔梅', 55.6266352, 22.8781720),
(2252, 126, '20', 'Klaipeda', '克萊佩達', '克莱佩达', 55.7032948, 21.1442795),
(2253, 126, 'KL', 'Klaipėda', '克萊佩達', '克莱佩达', 55.6519744, 21.3743956),
(2254, 126, '21', 'Klaipėda', '克萊佩達', '克莱佩达', 55.6841615, 21.4416464),
(2255, 126, '22', 'Kretinga', '克雷廷加', '克雷廷加', 55.8838420, 21.2350919),
(2256, 126, '23', 'Kupiškis', '庫皮什基斯', '库皮什基斯', 55.8428741, 25.0295816),
(2257, 126, '24', 'Lazdijai', '榛子', '榛子', 54.2343267, 23.5156505),
(2258, 126, '25', 'Marijampolė', 'Marijampolė', 'Marijampolė', 54.5711094, 23.4859371),
(2259, 126, 'MR', 'Marijampolė', 'Marijampolė', 'Marijampolė', 54.7819971, 23.1341365),
(2260, 126, '26', 'Mažeikiai', 'Mažeikiai', 'Mažeikiai', 56.3092439, 22.3414680),
(2261, 126, '27', 'Molėtai', '莫萊泰', '莫莱泰', 55.2265309, 25.4180011),
(2262, 126, '28', 'Neringa', '內林加', '内林加', 55.4572403, 21.0839005),
(2263, 126, '29', 'Pagėgiai', 'Pagėgiai', 'Pagėgiai', 55.1721320, 21.9683614),
(2264, 126, '30', 'Pakruojis', '帕克魯吉斯', '帕克鲁吉斯', 56.0732605, 23.9389906),
(2265, 126, '31', 'Palanga', '帕蘭加', '帕兰加', 55.9201980, 21.0677614),
(2266, 126, '32', 'Panevėžys', 'Panevėžys', 'Panevėžys', 55.7347915, 24.3574774),
(2267, 126, 'PN', 'Panevėžys', 'Panevėžys', 'Panevėžys', 55.9748049, 25.0794767),
(2268, 126, '33', 'Panevėžys', 'Panevėžys', 'Panevėžys', 55.6166728, 24.3142283),
(2269, 126, '34', 'Pasvalys', '帕斯瓦利斯', '帕斯瓦利斯', 56.0604619, 24.3962910),
(2270, 126, '35', 'Plungė', '跳水', '暴跌', 55.9107840, 21.8454069),
(2271, 126, '36', 'Prienai', '普里埃奈', '普里埃奈', 54.6383580, 23.9468009),
(2272, 126, '37', 'Radviliškis', '拉德維利什基斯', '拉德维利什基斯', 55.8108399, 23.5464870),
(2273, 126, '38', 'Raseiniai', '拉塞尼亞', '拉塞尼亚', 55.3819499, 23.1156129),
(2274, 126, '39', 'Rietavas', '里塔瓦斯', '里塔瓦斯', 55.7021719, 21.9986564),
(2275, 126, '40', 'Rokiškis', '羅基什基斯', '罗基什基斯', 55.9555039, 25.5859249),
(2276, 126, '41', 'Šakiai', '沙基艾', '沙基艾', 54.9526710, 23.0480199),
(2277, 126, '42', 'Šalčininkai', 'Šalčininkai', 'Šalčininkai', 54.3097670, 25.3875640),
(2278, 126, '44', 'Šiauliai', 'Šiauliai', 'Šiauliai', 55.9721456, 23.0332371),
(2279, 126, '43', 'Šiauliai', 'Šiauliai', 'Šiauliai', 55.9349085, 23.3136823),
(2280, 126, 'SA', 'Šiauliai', 'Šiauliai', 'Šiauliai', 55.9985751, 23.1380051),
(2281, 126, '45', 'Šilalė ', '希拉萊', '希拉莱', 55.4926800, 22.1845559),
(2282, 126, '46', 'Šilutė', 'Šilutė', 'Šilutė', 55.3504140, 21.4659859),
(2283, 126, '47', 'Širvintos', '希爾文托斯', '希尔文托斯', 55.0431020, 24.9569810),
(2284, 126, '48', 'Skuodas', '斯庫達斯', '斯库达斯', 56.2702169, 21.5214331),
(2285, 126, '49', 'Švenčionys', 'Švenčionys', 'Švenčionys', 55.1028098, 26.0071855),
(2286, 126, 'TA', 'Tauragė', '陶拉蓋', '陶拉盖', 55.3072586, 22.3572939),
(2287, 126, '50', 'Tauragė', '陶拉蓋', '陶拉盖', 55.2503660, 22.2909500),
(2288, 126, '51', 'Telšiai', 'Telšiai', '泰尔希艾', 55.9175215, 22.3451840),
(2289, 126, 'TE', 'Telšiai', 'Telšiai', '泰尔希艾', 56.1026616, 22.1113915),
(2290, 126, '52', 'Trakai', '特拉凱', '特拉凯', 54.6379113, 24.9346894),
(2291, 126, '53', 'Ukmergė', 'Ukmergė', 'Ukmergė', 55.2452650, 24.7760749),
(2292, 126, '54', 'Utena', '烏蒂娜', '乌蒂娜', 55.5084614, 25.6832642),
(2293, 126, 'UT', 'Utena', '烏蒂娜', '乌蒂娜', 55.5318969, 25.7904699),
(2294, 126, '55', 'Varėna', '瓦雷納', '瓦雷纳', 54.2203330, 24.5789970),
(2295, 126, '56', 'Vilkaviškis', '維爾卡維什基斯', '维尔卡维什基斯', 54.6519450, 23.0351550),
(2296, 126, 'VL', 'Vilnius', '維爾紐斯', '维尔纽斯', 54.8086502, 25.2182139),
(2297, 126, '57', 'Vilnius', '維爾紐斯', '维尔纽斯', 54.6710761, 25.2878721),
(2298, 126, '58', 'Vilnius', '維爾紐斯', '维尔纽斯', 54.7732578, 25.5867113),
(2299, 126, '59', 'Visaginas', '維薩吉納斯', '维萨吉纳斯', 55.5941180, 26.4307954),
(2300, 126, '60', 'Zarasai', '扎拉賽', '扎拉赛', 55.7309609, 26.2452950),
(2301, 127, 'CA', 'Capellen', '卡佩倫', '卡佩伦', 49.6403931, 5.9553846),
(2302, 127, 'CL', 'Clervaux', NULL, NULL, 50.0546313, 6.0285875),
(2303, 127, 'DI', 'Diekirch', '迪基希', '迪基希', 49.8671784, 6.1595633),
(2304, 127, 'EC', 'Echternach', '埃希特納赫', '埃希特纳赫', 49.8114133, 6.4175635),
(2305, 127, 'ES', 'Esch-sur-Alzette', '阿爾澤特河畔埃施', '阿尔泽特河畔埃施', 49.5008805, 5.9860925),
(2306, 127, 'G', 'Grevenmacher', '格雷文馬赫', '格雷文马赫', 49.6808510, 6.4407524),
(2307, 127, 'L', 'Luxembourg ', '盧森堡', '卢森堡', 49.5953706, 6.1333178),
(2308, 127, 'ME', 'Mersch', '梅爾施', '梅尔施', 49.7542906, 6.1292185),
(2309, 127, 'RD', 'Redange', '雷丹奇', '雷丹吉', 49.7645500, 5.8894800),
(2310, 127, 'RM', 'Remich', '雷米奇', '雷米奇', 49.5450170, 6.3674222),
(2311, 127, 'VD', 'Vianden', '維安登', '维安登', 49.9341924, 6.2019917),
(2312, 127, 'WI', 'Wiltz', '威爾茨', '威尔茨', 49.9662200, 5.9324306),
(2313, 130, 'T', 'Antananarivo', '塔那那利佛', '塔那那利佛', -18.7051474, 46.8252838),
(2314, 130, 'D', 'Antsiranana', '機緣巧合', '偶然', -13.7715390, 49.5279996),
(2315, 130, 'F', 'Fianarantsoa', '聖保羅，聖保羅', '圣保罗，圣保罗', -22.3536240, 46.8252838),
(2316, 130, 'M', 'Mahajanga', '馬哈詹加', '马哈詹加', -16.5238830, 46.5162620),
(2317, 130, 'A', 'Toamasina', '托阿馬尼亞', '托阿马尼亚', -18.1442811, 49.3957836),
(2318, 130, 'U', 'Toliara', '托利亞拉', '托利亚拉', -23.3516191, 43.6854936),
(2319, 131, 'BA', 'Balaka', '巴拉卡', '巴拉卡', -15.0506595, 35.0828588),
(2320, 131, 'BL', 'Blantyre', '布蘭太爾', '布兰太尔', -15.6778541, 34.9506625),
(2321, 131, 'C', 'Central', '中', '中央', -13.7402364, 32.5039619),
(2322, 131, 'CK', 'Chikwawa', '奇克瓦瓦', '奇夸瓦', -16.1958446, 34.7740793),
(2323, 131, 'CR', 'Chiradzulu', '奇拉祖魯', '奇拉祖鲁', -15.7423151, 35.2587964),
(2324, 131, 'CT', 'Chitipa', '奇蒂帕', '奇蒂帕', -9.7037655, 33.2700253),
(2325, 131, 'DE', 'Dedza', '德扎', '德扎', -14.1894585, 34.2421597),
(2326, 131, 'DO', 'Dowa', '同和', '同和', -13.6041256, 33.8857747),
(2327, 131, 'KR', 'Karonga', '卡龍加', '卡龙加', -9.9036365, 33.9750018),
(2328, 131, 'KS', 'Kasungu', '卡松古', '卡松古', -13.1367065, 33.2587930),
(2329, 131, 'LK', 'Likoma', '萊姆病', '莱姆病', -12.0584005, 34.7354031),
(2330, 131, 'LI', 'Lilongwe', '利隆圭', '利隆圭', -14.0475228, 33.6175770),
(2331, 131, 'MH', 'Machinga', '馬欽加', '马钦加', -14.9407263, 35.4781926),
(2332, 131, 'MG', 'Mangochi', '萬高奇', '芒戈奇', -14.1388248, 35.0388164),
(2333, 131, 'MC', 'Mchinji', '姆欽吉', '姆钦吉', -13.7401525, 32.9888319),
(2334, 131, 'MU', 'Mulanje', '穆蘭傑', '木兰热', -15.9346434, 35.5220012),
(2335, 131, 'MW', 'Mwanza', '姆萬扎', '姆万扎', -2.4671197, 32.8986812),
(2336, 131, 'MZ', 'Mzimba', '姆津巴', '姆津巴', -11.7475452, 33.5280072),
(2337, 131, 'NE', 'Neno', '尼諾', '尼诺', -15.6904254, 34.2291386),
(2338, 131, 'NB', 'Nkhata Bay', '恩哈塔灣', '恩哈塔湾', -11.7185042, 34.3310364),
(2339, 131, 'NK', 'Nkhotakota', '恩霍塔科塔', '恩霍塔科塔', -12.7541961, 34.2421597),
(2340, 131, 'N', 'Northern', '北', '北方', -11.0495091, 32.6341461),
(2341, 131, 'NS', 'Nsanje', '恩桑傑', '恩桑杰', -16.7288202, 35.1708741),
(2342, 131, 'NU', 'Ntcheu', '恩徹', '恩彻', -14.9037538, 34.7740793),
(2343, 131, 'NI', 'Ntchisi', '結論', '结论', -13.2841992, 33.8857747),
(2344, 131, 'PH', 'Phalombe', '法隆貝', '法隆贝', -15.7092038, 35.6532848),
(2345, 131, 'RU', 'Rumphi', '倫菲', '伦菲', -10.7851537, 34.3310364),
(2346, 131, 'SA', 'Salima', '薩利瑪', '萨利玛', -13.6809586, 34.4198243),
(2347, 131, 'S', 'Southern', '南方的', '南部', -15.3024478, 33.7644083),
(2348, 131, 'TH', 'Thyolo', '蒂奧洛', '蒂奥洛', -16.1299177, 35.1268781),
(2349, 131, 'ZO', 'Zomba', '殭屍', '僵尸', -15.3765857, 35.3356518),
(2350, 132, '01', 'Johor', '柔佛州', '柔佛州', 1.4853682, 103.7618154),
(2351, 132, '02', 'Kedah', '吉打州', '吉打州', 6.1183964, 100.3684595),
(2352, 132, '03', 'Kelantan', '吉蘭丹', '吉兰丹', 6.1253969, 102.2380710),
(2353, 132, '14', 'Kuala Lumpur', '吉隆坡', '吉隆坡', 3.1390030, 101.6868550),
(2354, 132, '15', 'Labuan', '納閩', '纳闽', 5.2831456, 115.2308250),
(2355, 132, '04', 'Malacca', '馬六甲', '马六甲', 2.1895940, 102.2500868),
(2356, 132, '05', 'Negeri Sembilan', '森美蘭州', '森美兰州', 2.7258058, 101.9423782),
(2357, 132, '06', 'Pahang', '彭亨州', '彭亨州', 3.8126318, 103.3256204),
(2358, 132, '07', 'Penang', '檳城', '槟城', 5.4163935, 100.3326786),
(2359, 132, '08', 'Perak', '霹靂州', '霹雳', 4.5921126, 101.0901090),
(2360, 132, '09', 'Perlis', '玻璃市', '玻璃市', 29.9227094, -90.1228559),
(2361, 132, '16', 'Putrajaya', '布城', '布城', 2.9263610, 101.6964450),
(2362, 132, '12', 'Sabah', '上午', '上午', 5.9788398, 116.0753199),
(2363, 132, '13', 'Sarawak', '砂拉越', '沙捞越', 1.5532783, 110.3592127),
(2364, 132, '10', 'Selangor', '雪蘭莪', '雪兰莪', 3.0738379, 101.5183469),
(2365, 132, '11', 'Terengganu', '登嘉樓', '登嘉楼', 5.3116916, 103.1324154),
(2366, 133, '01', 'Addu', '阿杜', '阿杜', -0.6300995, 73.1585626),
(2367, 133, '02', 'Alif Alif', '阿里夫·阿里夫', '阿里夫·阿里夫', 4.0850000, 72.8515479),
(2368, 133, '00', 'Alif Dhaal', '阿里夫·達爾', '阿里夫·达尔', 3.6543302, 72.8042797),
(2369, 133, 'CE', 'Central', '中', '中央', 2.9693309, 72.9082619),
(2370, 133, '17', 'Dhaalu', '達魯', '达鲁', 2.8468502, 72.9460566),
(2371, 133, '14', 'Faafu', '噴出', '喷', 3.2309409, 72.9460566),
(2372, 133, '27', 'Gaafu Alif', '加夫·阿里夫', '加夫·阿里夫', 0.6124813, 73.3237080),
(2373, 133, '28', 'Gaafu Dhaalu', '加夫·達魯', '加夫·达鲁', 0.3588040, 73.1821623),
(2374, 133, '29', 'Gnaviyani', '格納維亞尼', '格纳维亚尼', -0.3006425, 73.4239143),
(2375, 133, '07', 'Haa Alif', '哈阿里夫', '哈阿阿里夫', 6.9903488, 72.9460566),
(2376, 133, '23', 'Haa Dhaalu', '哈達魯', '哈达鲁', 6.5782717, 72.9460566),
(2377, 133, '26', 'Kaafu', '卡夫', '卡夫', 4.4558979, 73.5594128),
(2378, 133, '05', 'Laamu', '鬼', '鬼', 1.9430737, 73.4180211),
(2379, 133, '03', 'Lhaviyani', '拉維亞尼', '拉维亚尼', 5.3747021, 73.5122928),
(2380, 133, 'MLE', 'Malé', '小', '小', 4.4166630, 73.4261798),
(2381, 133, '12', 'Meemu', '米姆', '米姆', 3.0090345, 73.5122928),
(2382, 133, '25', 'Noonu', '努努', '努努', 5.8551276, 73.3237080),
(2383, 133, 'NC', 'North Central', '中北部', '中北部', 4.1389788, 72.5734029),
(2384, 133, '13', 'Raa', '拉', '拉', 5.6006457, 72.9460566),
(2385, 133, '24', 'Shaviyani', '沙維亞尼', '沙维亚尼', 6.1751100, 73.1349605),
(2386, 133, 'SU', 'South', '南', '南', -0.4783126, 73.0768327),
(2387, 133, 'SC', 'South Central', '中南部', '中南部', 7.2564996, 80.7214417),
(2388, 133, '08', 'Thaa', '塔', '塔阿', 2.4311161, 73.1821623),
(2389, 133, 'US', 'Upper South', '上南區', '上南区', 0.2307000, 73.2794846),
(2390, 133, '04', 'Vaavu', '搖擺', '游移不定', 3.3955438, 73.5122928),
(2391, 134, 'BKO', 'Bamako', '巴馬科', '巴马科', 12.6392316, -8.0028892),
(2392, 134, '7', 'Gao', '高', '高', 16.9066332, 1.5208624),
(2393, 134, '1', 'Kayes', '凱耶斯', '凯斯', 14.0818308, -9.9018131),
(2394, 134, '8', 'Kidal', '基達爾', '基达尔', 18.7986832, 1.8318334),
(2395, 134, '2', 'Koulikoro', '庫利科羅', '库利科罗', 13.8018074, -7.4381355),
(2396, 134, '9', 'Ménaka', '梅納卡', '梅纳卡', 15.9156421, 2.3961740),
(2397, 134, '5', 'Mopti', '莫普提', '莫普提', 14.6338039, -3.4195527),
(2398, 134, '4', 'Ségou', '瀨溝', '塞古', 13.8394456, -6.0679194),
(2399, 134, '3', 'Sikasso', '西卡索', '西卡索', 10.8905186, -7.4381355),
(2400, 134, '10', 'Taoudénit', '陶德尼特', '陶德尼特', 22.6764132, -3.9789143),
(2401, 134, '6', 'Tombouctou', '廷巴克圖', '廷巴克图', 21.0526706, -3.7435090),
(2402, 135, '01', 'Attard', '阿塔德', '阿塔德', 35.8904967, 14.4199322),
(2403, 135, '02', 'Balzan', '巴爾贊', '巴尔赞', 35.8957414, 14.4534065),
(2404, 135, '03', 'Birgu', '比爾古', '比尔古', 35.8879214, 14.5225620),
(2405, 135, '04', 'Birkirkara', '比爾基卡拉', '比尔基卡拉', 35.8954706, 14.4665072),
(2406, 135, '05', 'Birżebbuġa', 'Birżebbuġa', 'Birżebbuġa', 35.8135989, 14.5247463),
(2407, 135, '06', 'Cospicua', '出眾的', '显著的', 35.8806753, 14.5218338),
(2408, 135, '07', 'Dingli', '鼎力', '鼎力', 35.8627309, 14.3850107),
(2409, 135, '08', 'Fgura', '弗古拉', '弗古拉', 35.8738269, 14.5232901),
(2410, 135, '09', 'Floriana', '弗洛里亞娜', '弗洛里亚纳', 45.4952185, -73.7139576),
(2411, 135, '10', 'Fontana', '泉', '喷泉', 34.0922335, -117.4350480),
(2412, 135, '13', 'Għajnsielem', 'Għajnsielem', 'Għajnsielem', 36.0247966, 14.2802961),
(2413, 135, '14', 'Għarb', '蓋爾布', '盖尔布', 36.0689090, 14.2018098),
(2414, 135, '15', 'Għargħur', 'Għargħur', 'Għargħur', 35.9220569, 14.4563176),
(2415, 135, '16', 'Għasri', '蓋斯里', '盖斯里', 36.0668075, 14.2192475),
(2416, 135, '17', 'Għaxaq', '蓋克薩克', '盖克萨克', 35.8440359, 14.5160090),
(2417, 135, '11', 'Gudja', '古賈', '古贾', 35.8469803, 14.5029040),
(2418, 135, '12', 'Gżira', '格茲拉', '格日拉', 35.9058970, 14.4953338),
(2419, 135, '18', 'Ħamrun', '阿姆倫', '阿姆伦', 35.8861237, 14.4883442),
(2420, 135, '19', 'Iklin', '伊克林', '伊克林', 35.9098774, 14.4577732),
(2421, 135, '21', 'Kalkara', '卡爾卡拉', '卡尔卡拉', 35.8914242, 14.5320278),
(2422, 135, '22', 'Kerċem', 'Kerċem', 'Kerċem', 36.0447939, 14.2250605),
(2423, 135, '23', 'Kirkop', '柯科普', '柯科普', 35.8437862, 14.4854324),
(2424, 135, '24', 'Lija', '沙紙', '砂纸', 49.1800760, -123.1033170),
(2425, 135, '25', 'Luqa', '盧卡', '卢卡', 35.8582865, 14.4868883),
(2426, 135, '26', 'Marsa', '火星', '火星', 34.0319587, -118.4455535),
(2427, 135, '27', 'Marsaskala', '馬薩斯卡拉', '马萨斯卡拉', 35.8603640, 14.5567876),
(2428, 135, '28', 'Marsaxlokk', '馬爾薩什洛克', '马萨什洛克', 35.8411699, 14.5393097),
(2429, 135, '29', 'Mdina', '姆迪納', '姆迪纳', 35.8880930, 14.4068357),
(2430, 135, '30', 'Mellieħa', '梅莉亞', '梅莉亚', 35.9523529, 14.3500975),
(2431, 135, '31', 'Mġarr', '梅爾', '梅尔', 35.9189327, 14.3617343),
(2432, 135, '32', 'Mosta', '橋', '桥', 35.9141504, 14.4228427),
(2433, 135, '33', 'Mqabba', '姆卡巴', '姆卡巴', 35.8444143, 14.4694186),
(2434, 135, '34', 'Msida', '姆西達', '姆西达', 35.8956388, 14.4868883),
(2435, 135, '35', 'Mtarfa', '姆塔爾法', '姆塔尔法', 35.8895125, 14.3951953),
(2436, 135, '36', 'Munxar', '蒙克薩爾', '蒙克萨尔', 36.0288058, 14.2250605),
(2437, 135, '37', 'Nadur', '納杜爾', '纳杜尔', 36.0447019, 14.2919273),
(2438, 135, '38', 'Naxxar', '納克薩爾', '纳克萨尔', 35.9317518, 14.4315746),
(2439, 135, '39', 'Paola', '保拉', '保拉', 38.5722353, -94.8791294),
(2440, 135, '40', 'Pembroke', '彭布羅克', '彭布罗克', 34.6801626, -79.1950373),
(2441, 135, '41', 'Pietà', '同情', '可惜', 42.2186200, -83.7346470),
(2442, 135, '42', 'Qala', '城', '城堡', 36.0388628, 14.3181010),
(2443, 135, '43', 'Qormi', '庫爾米', '库尔米', 35.8764388, 14.4694186),
(2444, 135, '44', 'Qrendi', '克倫迪', '克伦迪', 35.8328488, 14.4548621),
(2445, 135, '46', 'Rabat', '拉巴特', '拉巴特', 33.9715904, -6.8498129),
(2446, 135, '49', 'San Ġwann', '聖伊萬', '圣伊万', 35.9077365, 14.4752416),
(2447, 135, '50', 'San Lawrenz', '聖勞倫茲', '圣劳伦茨', 38.9578056, -95.2565689),
(2448, 135, '52', 'Sannat', '桑納特', '桑纳特', 36.0192643, 14.2599437),
(2449, 135, '53', 'Santa Luċija', '聖路易亞', '圣路易亚', 35.8561420, 14.5043600),
(2450, 135, '54', 'Santa Venera', '聖維內拉', '圣维内拉', 35.8902201, 14.4766974),
(2451, 135, '20', 'Senglea', '森格利亞', '森格莱亚', 35.8873041, 14.5167371),
(2452, 135, '55', 'Siġġiewi', 'Siġġiewi', 'Siġġiewi', 35.8463742, 14.4315746),
(2453, 135, '56', 'Sliema', '斯利馬', '斯利马', 35.9110081, 14.5029040),
(2454, 135, '48', 'St. Julian\'s', '聖朱利安', '圣朱利安', 42.2122513, -85.8917127),
(2455, 135, '51', 'St. Paul\'s Bay', '聖保羅', '圣保罗', 35.9360170, 14.3966503),
(2456, 135, '57', 'Swieqi', '斯威奇', '斯威奇', 35.9191182, 14.4694186),
(2457, 135, '58', 'Ta\' Xbiex', 'Ta', 'Ta', 35.8991448, 14.4963519),
(2458, 135, '59', 'Tarxien', '塔爾西恩', '塔尔西恩', 35.8672552, 14.5116405),
(2459, 135, '60', 'Valletta', '瓦萊塔', '瓦莱塔', 35.8989085, 14.5145528),
(2460, 135, '45', 'Victoria', '維多利亞', '维多利亚', 28.8052674, -97.0035982),
(2461, 135, '61', 'Xagħra', 'Xagħra', 'Xagħra', 36.0508450, 14.2674820),
(2462, 135, '62', 'Xewkija', '謝基亞', '谢基亚', 36.0299236, 14.2599437),
(2463, 135, '63', 'Xgħajra', 'Xgħajra', 'Xgħajra', 35.8868282, 14.5472391),
(2464, 135, '64', 'Żabbar', '扎巴爾', '扎巴尔', 35.8724715, 14.5451354),
(2465, 135, '65', 'Żebbuġ Gozo', 'Żebbuġ Gozo', 'Żebbuġ Gozo', 36.0716403, 14.2454080),
(2466, 135, '66', 'Żebbuġ Malta', 'Żebbuġ 馬耳他', 'Żebbuġ 马耳他', 35.8764648, 14.4390840),
(2467, 135, '67', 'Żejtun', 'Żejtun', 'Żejtun', 35.8548714, 14.5363969),
(2468, 135, '68', 'Żurrieq', 'Żurrieq', 'Żurrieq', 35.8216306, 14.4810648),
(2469, 136, '01', 'Ayre', '艾爾', '艾尔', 54.3297577, -4.6025879),
(2470, 136, '02', 'Garff', '加夫', '加夫', 54.2568720, -4.5547307),
(2471, 136, '03', 'Glenfaba', '格蘭法巴', '格兰法巴', 54.1985534, -4.8131407),
(2472, 136, '04', 'Michael', '邁克爾', '迈克尔', 54.2742778, -4.6427325),
(2473, 136, '05', 'Middle', '中', '中间', 54.1777052, -4.8106436),
(2474, 136, '06', 'Rushen', '如申', '如申', 54.0957406, -4.8283517),
(2475, 137, 'L', 'Ralik', '拉利克', '拉利克', 8.1361460, 164.8867956),
(2476, 137, 'T', 'Ratak', '拉塔克', '拉塔克', 10.2763276, 170.5500937),
(2477, 138, '01', 'Fort-de-France', '法蘭西堡', '法兰西堡', 14.6434995, -61.1143189),
(2478, 138, '02', 'La Trinité', '三位一體', '三位一体', 14.7551949, -61.2028197),
(2479, 138, '03', 'Le Marin', '水手', '水手', 14.5220581, -61.1201197),
(2480, 138, '04', 'Saint-Pierre', '聖皮埃爾', '圣皮埃尔', 14.7450520, -61.2363184),
(2481, 139, '07', 'Adrar', '阿德拉爾', '阿德拉尔', 19.8652176, -12.8054753),
(2482, 139, '03', 'Assaba', '阿薩巴', '阿萨巴', 16.7759558, -11.5248055),
(2483, 139, '05', 'Brakna', '布拉克納', '布拉克纳', 17.2317561, -13.1740348),
(2484, 139, '08', 'Dakhlet Nouadhibou', '達克萊特·努瓦迪布', '达克莱特·努瓦迪布', 20.5985588, -16.2522143),
(2485, 139, '04', 'Gorgol', '戈爾戈爾', '戈尔戈尔', 15.9717357, -12.6216211),
(2486, 139, '10', 'Guidimaka', '吉迪馬卡', '吉迪马卡', 15.2557331, -12.2547919),
(2487, 139, '01', 'Hodh Ech Chargui', '霍德·埃赫·查爾吉', '霍德·埃赫·查尔吉', 18.6737026, -7.0928770),
(2488, 139, '02', 'Hodh El Gharbi', '霍德·埃爾·加爾比', '霍德·埃尔·加尔比', 16.6912149, -9.5450974),
(2489, 139, '12', 'Inchiri', '因奇里', '因奇里', 20.0280561, -15.4068079),
(2490, 139, '14', 'Nouakchott-Nord', '努瓦克肖特-北', '努瓦克肖特-北', 18.1130205, -15.8994956),
(2491, 139, '13', 'Nouakchott-Ouest', '努瓦克肖特-西', '努瓦克肖特-西', 18.1511357, -15.9934910),
(2492, 139, '15', 'Nouakchott-Sud', '努瓦克肖特南', '努瓦克肖特-南', 17.9709288, -15.9464874),
(2493, 139, '09', 'Tagant', '從後面看', '从背面', 18.5467527, -9.9018131),
(2494, 139, '11', 'Tiris Zemmour', '蒂里斯·澤穆爾', '蒂里斯·泽穆尔', 24.5773764, -9.9018131),
(2495, 139, '06', 'Trarza', '垃圾', '垃圾', 17.8664964, -14.6587821),
(2496, 140, 'AG', 'Agalega Islands', '阿加萊加群島', '阿加莱加群岛', -10.4000000, 56.6166667),
(2497, 140, 'BL', 'Black River', '黑河', '黑河', -20.3708492, 57.3948649),
(2498, 140, 'FL', 'Flacq', '弗拉克', '弗拉克', -20.2257836, 57.7119274),
(2499, 140, 'GP', 'Grand Port', '大港', '大港', -20.3851546, 57.6665742),
(2500, 140, 'MO', 'Moka', '銜', '位', -20.2399782, 57.5759260),
(2501, 140, 'PA', 'Pamplemousses', '小冊子', '小册子', -20.1136008, 57.5759260),
(2502, 140, 'PW', 'Plaines Wilhems', '威爾漢斯平原', '威尔赫姆斯平原', -20.3054872, 57.4853561),
(2503, 140, 'PL', 'Port Louis', '路易港', '路易港', -20.1608912, 57.5012222),
(2504, 140, 'RR', 'Rivière du Rempart', '倫帕特河', '伦帕特河', -20.0560983, 57.6552389),
(2505, 140, 'RO', 'Rodrigues Island', '羅德里格斯島', '罗德里格斯岛', -19.7245385, 63.4272185),
(2506, 140, 'CC', 'Saint Brandon Islands', '聖布蘭登群島', '圣布兰登群岛', -16.5833330, 59.6166670),
(2507, 140, 'SA', 'Savanne', '稀樹草原', '稀树草原', -20.4739530, 57.4853561),
(2508, 141, '14', 'Acoua', '阿庫阿', '阿库阿', -12.7249126, 45.0265961),
(2509, 141, '16', 'Bandraboua', '班德拉布阿', '班德拉布阿', -12.7175686, 45.0825619),
(2510, 141, '05', 'Bandrélé', '班德雷萊', '班德雷莱', -12.9338049, 45.1463472),
(2511, 141, '07', 'Boueni', '布埃尼', '布埃尼', -12.9303566, 45.0574737),
(2512, 141, '11', 'Chiconi', '奇科尼', '奇科尼', -12.8322032, 45.1025122),
(2513, 141, '08', 'Chirongui', '奇龍貴', '奇龙贵', -12.9175233, 45.1019678),
(2514, 141, '04', 'Dembeni', '登貝尼', '登贝尼', -12.8530029, 45.1392512),
(2515, 141, '01', 'Dzaoudzi', '扎烏齊', '扎乌兹', -12.7760651, 45.2563246),
(2516, 141, '06', 'Kani Keli', '卡尼·凱利', '卡尼·凯利', -12.9746450, 45.0795143),
(2517, 141, '17', 'Koungou', '孔溝', '孔沟', -12.7416823, 45.1499871),
(2518, 141, '13', 'M\'Tsangamouji', 'M', 'M', -12.7550088, 45.0432792),
(2519, 141, '03', 'Mamoudzou', '馬穆祖', '马穆祖', -12.7875052, 45.1552201),
(2520, 141, '15', 'Mtsamboro', '姆桑伯勒', '姆桑伯勒', -12.6762580, 45.0215201),
(2521, 141, '10', 'Ouangani', '萬加尼', '万加尼', -12.8392508, 45.0971617),
(2522, 141, '02', 'Pamandzi', '帕曼齊', '帕曼齐', -12.8009693, 45.2636132),
(2523, 141, '09', 'Sada', '今', '现在', -12.8642439, 45.0722404),
(2524, 141, '12', 'Tsingoni', '青戈尼', '青戈尼', -12.7823696, 45.0922000),
(2525, 142, 'AGU', 'Aguascalientes', '阿瓜斯卡連特斯', '阿瓜斯卡连特斯', 21.8852562, -102.2915677),
(2526, 142, 'BCN', 'Baja California', '下加利福尼亞州', '下加利福尼亚州', 30.8406338, -115.2837585),
(2527, 142, 'BCS', 'Baja California Sur', '南下加利福尼亞州', '南下加利福尼亚州', 26.0444446, -111.6660725),
(2528, 142, 'CAM', 'Campeche', '坎佩切', '坎佩切', 19.8301251, -90.5349087),
(2529, 142, 'CHP', 'Chiapas', '恰帕斯州', '恰帕斯', 16.7569318, -93.1292353),
(2530, 142, 'CHH', 'Chihuahua', '吉娃娃', '吉娃娃', 28.6329957, -106.0691004),
(2531, 142, 'CMX', 'Ciudad de México', '墨西哥城', '墨西哥城', 19.4326077, -99.1332080),
(2532, 142, 'COA', 'Coahuila de Zaragoza', '科阿韋拉州薩拉戈薩', '科阿韦拉-德萨拉戈萨', 27.0586760, -101.7068294),
(2533, 142, 'COL', 'Colima', '科利馬', '科利马', 19.2452342, -103.7240868),
(2534, 142, 'DUR', 'Durango', '杜蘭戈', '杜兰戈', 37.2752800, -107.8800667),
(2535, 142, 'MEX', 'Estado de México', '墨西哥州', '墨西哥州', 23.6345010, -102.5527840),
(2536, 142, 'GUA', 'Guanajuato', '瓜納華托', '瓜纳华托州', 21.0190145, -101.2573586),
(2537, 142, 'GRO', 'Guerrero', '格雷羅州', '格雷罗', 17.4391926, -99.5450974),
(2538, 142, 'HID', 'Hidalgo', '伊達爾戈', '伊达尔戈', 26.1003547, -98.2630684),
(2539, 142, 'JAL', 'Jalisco', '哈利斯科州', '哈利斯科州', 20.6595382, -103.3494376),
(2540, 142, 'MIC', 'Michoacán de Ocampo', '米卻肯州德奧坎波', '米却肯州德奥坎波', 19.5665192, -101.7068294),
(2541, 142, 'MOR', 'Morelos', '莫雷洛斯', '莫雷洛斯', 18.6813049, -99.1013498),
(2542, 142, 'NAY', 'Nayarit', '納亞里特', '纳亚里特', 21.7513844, -104.8454619),
(2543, 142, 'NLE', 'Nuevo León', '新萊昂州', '新莱昂', 25.5921720, -99.9961947),
(2544, 142, 'OAX', 'Oaxaca', '瓦哈卡州', '瓦哈卡州', 17.0731842, -96.7265889),
(2545, 142, 'PUE', 'Puebla', '普埃布拉', '普埃布拉', 19.0414398, -98.2062727),
(2546, 142, 'QUE', 'Querétaro', '克雷塔羅', '克雷塔罗', 20.5887932, -100.3898881),
(2547, 142, 'ROO', 'Quintana Roo', '金塔納羅奧州', '金塔纳罗奥州', 19.1817393, -88.4791376),
(2548, 142, 'SLP', 'San Luis Potosí', '聖路易斯波托西', '圣路易斯波托西', 22.1564699, -100.9855409),
(2549, 142, 'SIN', 'Sinaloa', '錫那羅亞州', '锡那罗亚州', 25.1721091, -107.4795173),
(2550, 142, 'SON', 'Sonora', '索諾拉州', '索诺拉', 37.9829496, -120.3821724),
(2551, 142, 'TAB', 'Tabasco', '塔巴斯科辣醬', '塔巴斯科辣酱', 17.8409173, -92.6189273),
(2552, 142, 'TAM', 'Tamaulipas', '塔毛利帕斯州', '塔毛利帕斯州', 24.2669400, -98.8362755),
(2553, 142, 'TLA', 'Tlaxcala', '特拉斯卡拉', '特拉斯卡拉', 19.3181540, -98.2374954),
(2554, 142, 'VER', 'Veracruz de Ignacio de la Llave', '韋拉克魯斯州伊格納西奧德拉拉維', '韦拉克鲁斯州伊格纳西奥德拉拉维', 19.1737730, -96.1342241),
(2555, 142, 'YUC', 'Yucatán', '尤卡坦半島', '尤卡坦半岛', 20.7098786, -89.0943377),
(2556, 142, 'ZAC', 'Zacatecas', '薩卡特卡斯', '萨卡特卡斯', 22.7708555, -102.5832426),
(2557, 143, 'TRK', 'Chuuk', '楚克', '楚克', 7.1386759, 151.5593065),
(2558, 143, 'KSA', 'Kosrae', '科斯雷', '科斯雷', 5.3095618, 162.9814877),
(2559, 143, 'PNI', 'Pohnpei', '波納佩', '波纳佩', 6.8541254, 158.2623822),
(2560, 143, 'YAP', 'Yap', '去做吧', '做吧', 8.6716490, 142.8439335),
(2561, 144, 'AN', 'Anenii Noi', '阿內尼諾伊', '阿内尼·诺伊', 46.8795663, 29.2312175),
(2562, 144, 'BA', 'Bălți', '巴爾蒂', '巴尔蒂', 47.7539947, 27.9184148),
(2563, 144, 'BS', 'Basarabeasca', '巴薩拉貝斯卡', '巴萨拉贝斯卡', 46.4237060, 28.8935492),
(2564, 144, 'BD', 'Bender', '彎道機', '班德', 46.8227551, 29.4620101),
(2565, 144, 'BR', 'Briceni', '布里塞尼', '布里塞尼', 48.3632022, 27.0750398),
(2566, 144, 'CA', 'Cahul', '卡胡爾', '卡胡尔', 45.8939404, 28.1890275),
(2567, 144, 'CL', 'Călărași', '卡拉拉西', '卡拉拉西', 47.2869460, 28.2745310),
(2568, 144, 'CT', 'Cantemir', '坎特米爾', '坎特米尔', 46.2771742, 28.2009653),
(2569, 144, 'CS', 'Căușeni', '科索尼', '科塞尼', 46.6554715, 29.4091222),
(2570, 144, 'CU', 'Chișinău', '基希訥烏', '基希讷乌', 47.0104529, 28.8638102),
(2571, 144, 'CM', 'Cimișlia', '西米斯利亞', '西米斯利亚', 46.5250851, 28.7721835),
(2572, 144, 'CR', 'Criuleni', '克魯萊尼', '克鲁莱尼', 47.2136114, 29.1557519),
(2573, 144, 'DO', 'Dondușeni', '東杜塞尼', '东杜塞尼', 48.2338305, 27.5998087),
(2574, 144, 'DR', 'Drochia', '德羅基亞', '卓基亚', 48.0797788, 27.8604114),
(2575, 144, 'DU', 'Dubăsari', '杜巴薩里', '杜巴萨里', 47.2643942, 29.1550348),
(2576, 144, 'ED', 'Edineț', '埃迪內特', '埃迪内特', 48.1678991, 27.2936143),
(2577, 144, 'FA', 'Fălești', '法萊斯蒂', '法莱斯蒂', 47.5647725, 27.7265593),
(2578, 144, 'FL', 'Florești', '弗洛雷斯蒂', '弗洛雷斯蒂', 47.8667849, 28.3391864),
(2579, 144, 'GA', 'Gagauzia', '加告齊亞', '加告齐亚', 46.0979435, 28.6384645),
(2580, 144, 'GL', 'Glodeni', '格洛德尼', '格洛德尼', 47.7790156, 27.5168010),
(2581, 144, 'HI', 'Hîncești', '欣塞斯蒂', '欣塞斯蒂', 46.8281147, 28.5850889),
(2582, 144, 'IA', 'Ialoveni', '亞洛維尼', '亚洛维尼', 46.8630860, 28.8234218),
(2583, 144, 'NI', 'Nisporeni', '尼斯波雷尼', '尼斯波雷尼', 47.0751349, 28.1768155),
(2584, 144, 'OC', 'Ocnița', '奧克尼察', '奥克尼察', 48.4110435, 27.4768092),
(2585, 144, 'OR', 'Orhei', '奧爾黑', '奥尔黑', 47.3860400, 28.8303082),
(2586, 144, 'RE', 'Rezina', '樹脂', '树脂', 47.7180447, 28.8871024),
(2587, 144, 'RI', 'Rîșcani', '里斯卡尼', '里斯卡尼', 47.9070153, 27.5374996),
(2588, 144, 'SI', 'Sîngerei', '辛格雷', '辛格雷', 47.6389134, 28.1371816),
(2589, 144, 'SD', 'Șoldănești', 'Șoldănești', 'Șoldănești', 47.8147389, 28.7889586),
(2590, 144, 'SO', 'Soroca', '索羅卡', '索罗卡', 48.1549743, 28.2870783),
(2591, 144, 'SV', 'Ștefan Vodă', '斯特凡·沃達', '斯特凡·沃达', 46.5540488, 29.7022420),
(2592, 144, 'ST', 'Strășeni', '斯特拉塞尼', '斯特拉塞尼', 47.1450267, 28.6136736),
(2593, 144, 'TA', 'Taraclia', '塔拉克利亞', '塔拉克利亚', 45.8986510, 28.6671644),
(2594, 144, 'TE', 'Telenești', 'Telenești', '特莱内什蒂', 47.4983962, 28.3676019),
(2595, 144, 'SN', 'Transnistria', '德涅斯特河沿岸', '德涅斯特河沿岸', 47.2152972, 29.4638054),
(2596, 144, 'UN', 'Ungheni', '翁格尼', '翁格尼', 47.2305767, 27.7892661),
(2597, 145, 'CL', 'La Colle', '拉科萊', '拉科莱', 43.7327465, 7.4137276),
(2598, 145, 'CO', 'La Condamine', '拉康達明', '拉康达明', 43.7350665, 7.4199060),
(2599, 145, 'MG', 'Moneghetti', '莫內蓋蒂', '莫内盖蒂', 43.7364927, 7.4153383),
(2600, 146, '073', 'Arkhangai', '阿爾漢蓋', '阿尔汉盖', 47.8971101, 100.7240165),
(2601, 146, '071', 'Bayan-Ölgii', '巴彥-厄爾吉', '巴扬-厄尔吉', 48.3983254, 89.6625915),
(2602, 146, '069', 'Bayankhongor', '巴揚洪戈爾', '巴扬洪戈尔', 45.1526707, 100.1073667),
(2603, 146, '067', 'Bulgan', '布爾幹', '布尔干', 48.9690913, 102.8831723),
(2604, 146, '037', 'Darkhan-Uul', '達爾汗烏爾', '达尔汗-乌尔', 49.4648434, 105.9745919),
(2605, 146, '061', 'Dornod', '多諾德', '多诺德', 47.4658154, 115.3927120),
(2606, 146, '063', 'Dornogovi', '多諾格斯', '多诺格斯', 43.9653889, 109.1773459),
(2607, 146, '059', 'Dundgovi', '鄧德戈維', '邓德戈维', 45.5822786, 106.7644209),
(2608, 146, '065', 'Govi-Altai', '戈維-阿爾泰', '戈维-阿尔泰', 45.4511227, 95.8505766),
(2609, 146, '064', 'Govisümber', 'Govisümber', 'Govisümber', 46.4762754, 108.5570627),
(2610, 146, '039', 'Khentii', '肯蒂', '肯蒂', 47.6081209, 109.9372856),
(2611, 146, '043', 'Khovd', '霍夫德', '霍夫德', 47.1129654, 92.3110752),
(2612, 146, '041', 'Khövsgöl', '霍夫斯格爾', '霍夫斯格尔', 50.2204484, 100.3213768),
(2613, 146, '053', 'Ömnögovi', 'Ömnögovi', 'Ömnögovi', 43.5000240, 104.2861116),
(2614, 146, '035', 'Orkhon', '鄂爾渾', '鄂尔浑', 49.0047050, 104.3016527),
(2615, 146, '055', 'Övörkhangai', 'Övörkhangai', 'Övörkhangai', 45.7624392, 103.0917032),
(2616, 146, '049', 'Selenge', '塞倫格', '塞楞格', 50.0059273, 106.4434108),
(2617, 146, '051', 'Sükhbaatar', '蘇赫巴托爾', '苏赫巴托', 46.5653163, 113.5380836),
(2618, 146, '047', 'Töv', '延', '延迟', 47.2124056, 106.4154100),
(2619, 146, '046', 'Uvs', '烏夫斯', '乌布苏', 49.6449707, 93.2736576),
(2620, 146, '057', 'Zavkhan', '扎夫汗', '扎夫汗', 48.2388147, 96.0703019),
(2621, 147, '01', 'Andrijevica', '安德里耶維察', '安德里耶维察', 42.7362477, 19.7859556),
(2622, 147, '02', 'Bar', '攔', '酒吧', 42.1278119, 19.1404380),
(2623, 147, '03', 'Berane', '貝蘭', '贝兰', 42.8257289, 19.9020509),
(2624, 147, '04', 'Bijelo Polje', '白場', '白场', 43.0846526, 19.7115472),
(2625, 147, '05', 'Budva', '布德瓦', '布德瓦', 42.3140720, 18.8313832),
(2626, 147, '07', 'Danilovgrad', '丹尼洛夫格勒', '丹尼洛夫格勒', 42.5835700, 19.1404380),
(2627, 147, '22', 'Gusinje', '古辛傑', '古辛杰', 42.5563455, 19.8306051),
(2628, 147, '09', 'Kolašin', '科拉辛', '科拉辛', 42.7601916, 19.4259114),
(2629, 147, '10', 'Kotor', '科托爾', '科托尔', 42.5740261, 18.6413145),
(2630, 147, '11', 'Mojkovac', '莫伊科瓦茨', '莫伊科瓦茨', 42.9688018, 19.5211063),
(2631, 147, '12', 'Nikšić', '尼克希奇', '尼克希奇', 42.7997184, 18.7600963),
(2632, 147, '06', 'Old Royal Capital Cetinje', '舊王都採蒂涅', '旧皇家首都采蒂涅', 42.3930959, 18.9115964),
(2633, 147, '23', 'Petnjica', '佩特尼卡', '佩特尼卡', 42.9353480, 20.0211449),
(2634, 147, '13', 'Plav', '普拉夫', '普拉夫', 42.6001337, 19.9407541),
(2635, 147, '14', 'Pljevlja', '普列夫利亞', '普列夫利亚', 43.2723383, 19.2831531),
(2636, 147, '15', 'Plužine', 'Plužine', 'Plužine', 43.1593384, 18.8551484),
(2637, 147, '16', 'Podgorica', '波德戈里察', '波德戈里察', 42.3693834, 19.2831531),
(2638, 147, '17', 'Rožaje', 'Rožaje', 'Rožaje', 42.8408389, 20.1670628),
(2639, 147, '18', 'Šavnik', '沙夫尼克', '沙夫尼克', 42.9603756, 19.1404380),
(2640, 147, '19', 'Tivat', '蒂瓦特', '蒂瓦特', 42.4234800, 18.7185184),
(2641, 147, '20', 'Ulcinj', '烏爾齊尼', '乌尔齐尼', 41.9652795, 19.3069432),
(2642, 147, '21', 'Žabljak', 'Žabljak', 'Žabljak', 43.1555152, 19.1226018),
(2643, 148, '03', 'Saint Anthony', '聖安東尼', '圣安东尼', 16.7089300, -62.2340497),
(2644, 148, '02', 'Saint Georges', '聖喬治', '圣乔治', 16.7484755, -62.1907472),
(2645, 148, '01', 'Saint Peter', '聖彼得', '圣彼得', 16.7768658, -62.2443402),
(2646, 149, 'AGD', 'Agadir-Ida-Ou-Tanane', '阿加迪爾-伊達-歐-塔納內', '阿加迪尔-艾达-欧-塔纳内', 30.6462091, -9.8339061),
(2647, 149, 'HAO', 'Al Haouz', '阿爾·豪茲', '阿尔·豪兹', 31.2956729, -7.8721600),
(2648, 149, 'HOC', 'Al Hoceïma', '阿爾·霍塞馬', '阿尔霍塞马', 35.2445589, -3.9317468),
(2649, 149, 'AOU', 'Aousserd (EH)', '奧塞德 （EH）', '奥塞德 （EH）', 22.5521538, -14.3297353),
(2650, 149, 'ASZ', 'Assa-Zag (EH-partial)', 'Assa-Zag（EH-部分）', 'Assa-Zag（EH-部分）', 28.1402395, -9.7232673),
(2651, 149, 'AZI', 'Azilal', '阿齊拉爾', '阿齐拉尔', 32.0042620, -6.5783387),
(2652, 149, 'BEM', 'Béni Mellal', '貝尼·梅拉爾', '贝尼·梅拉尔', 32.3424430, -6.3757990),
(2653, 149, '05', 'Béni Mellal-Khénifra', '貝尼·梅拉爾-赫尼夫拉', '贝尼·梅拉尔-赫尼夫拉', 32.5719184, -6.0679194),
(2654, 149, 'BES', 'Benslimane', '本斯利曼', '本斯利曼', 33.6189698, -7.1305536),
(2655, 149, 'BER', 'Berkane', '貝爾卡內', '贝尔卡内', 34.8840876, -2.3418870),
(2656, 149, 'BRR', 'Berrechid', '貝雷奇德', '贝雷奇德', 33.2602523, -7.5984837),
(2657, 149, 'BOD', 'Boujdour (EH)', '布伊杜爾 （EH）', '布伊杜尔 （EH）', 26.1252493, -14.4847347),
(2658, 149, 'BOM', 'Boulemane', '布勒曼', '布勒曼', 33.3625159, -4.7303397),
(2659, 149, 'CAS', 'Casablanca', '卡薩布蘭卡', '卡萨布兰卡', 33.5722678, -7.6570326),
(2660, 149, '06', 'Casablanca-Settat', '卡薩布蘭卡-塞塔特', '卡萨布兰卡-塞塔特', 33.2160872, -7.4381355),
(2661, 149, 'CHE', 'Chefchaouen', '舍夫沙萬', '舍夫沙万', 35.0181720, -5.1432068),
(2662, 149, 'CHI', 'Chichaoua', '奇查瓦', '奇查瓦', 31.5383581, -8.7646388),
(2663, 149, 'CHT', 'Chtouka-Ait Baha', '奇圖卡-艾特巴哈', 'Chtouka-Ait Baha', 30.1072422, -9.2785583),
(2664, 149, '12', 'Dakhla-Oued Ed-Dahab (EH)', '達赫拉-烏德·埃德-達哈布 （EH）', '达赫拉-乌德·埃德-达哈布 （EH）', 22.7337892, -14.2861116),
(2665, 149, '08', 'Drâa-Tafilalet', '德拉-塔菲拉萊特', '德拉-塔菲拉莱特', 31.1499538, -5.3939551),
(2666, 149, 'DRI', 'Driouch', '德里烏奇', '德里乌奇', 34.9760320, -3.3964493),
(2667, 149, 'HAJ', 'El Hajeb', '埃爾·哈傑布', '埃尔·哈杰布', 33.6857350, -5.3677844),
(2668, 149, 'JDI', 'El Jadida', '賈迪達', '贾迪达', 33.2316326, -8.5007116),
(2669, 149, 'KES', 'El Kelâa des Sraghna', '埃爾凱拉德斯拉格納', 'El Kelâa des Sraghna', 32.0522767, -7.3516558),
(2670, 149, 'ERR', 'Errachidia', '埃拉希迪亞', '埃拉希迪亚 Errachidia', 31.9051275, -4.7277528),
(2671, 149, 'ESM', 'Es-Semara (EH-partial)', 'Es-Semara （EH-部分）', 'Es-Semara （EH-部分）', 26.7418560, -11.6783671),
(2672, 149, 'ESI', 'Essaouira', '索維拉', '索维拉', 31.5084926, -9.7595041),
(2673, 149, 'FAH', 'Fahs-Anjra', '法斯-安吉拉', '法斯-安吉拉', 35.7601992, -5.6668306),
(2674, 149, 'FES', 'Fès', '非斯', '菲斯', 34.0239579, -5.0367599),
(2675, 149, '03', 'Fès-Meknès', '非斯-梅克內斯', '非斯-梅克内斯', 34.0625290, -4.7277528),
(2676, 149, 'FIG', 'Figuig', '無花果', '无花果', 32.1092613, -1.2298060),
(2677, 149, 'FQH', 'Fquih Ben Salah', '弗基·本·薩拉赫', '本·萨拉赫', 32.5001680, -6.7100717),
(2678, 149, 'GUE', 'Guelmim', '圭爾米姆', '圭尔米姆', 28.9883659, -10.0527498),
(2679, 149, '10', 'Guelmim-Oued Noun (EH-partial)', 'Guelmim-Oued 名詞 （EH-partial）', 'Guelmim-Oued 名词（EH-部分）', 28.4844281, -10.0807298),
(2680, 149, 'GUF', 'Guercif', '格爾西夫', '格尔西夫', 34.2345036, -3.3813005),
(2681, 149, 'IFR', 'Ifrane', '伊夫蘭', '伊夫兰', 33.5228062, -5.1109552),
(2682, 149, 'INE', 'Inezgane-Ait Melloul', '伊內茲加內-艾特梅洛爾', '伊内斯加讷-艾特梅洛尔', 30.3509098, -9.3895110),
(2683, 149, 'JRA', 'Jerada', '傑拉達', '杰拉达', 34.3061791, -2.1794136),
(2684, 149, 'KEN', 'Kénitra', '凱尼特拉', '凯尼特拉', 34.2540503, -6.5890166),
(2685, 149, 'KHE', 'Khémisset', '凱米塞特', '赫米塞特', 33.8153704, -6.0573302),
(2686, 149, 'KHN', 'Khénifra', '赫尼弗拉', '赫尼弗拉', 32.9340471, -5.6615710),
(2687, 149, 'KHO', 'Khouribga', '庫里布加', '库里布加', 32.8860230, -6.9208655),
(2688, 149, '02', 'L\'Oriental', 'L', 'L', 37.0696830, -94.5122770),
(2689, 149, 'LAA', 'Laâyoune (EH)', '拉尤恩 （EH）', '拉尤恩 （EH）', 27.1500384, -13.1990758),
(2690, 149, '11', 'Laâyoune-Sakia El Hamra (EH-partial)', '拉尤恩-薩基亞埃爾哈姆拉 （EH-部分）', 'Laâyoune-Sakia El Hamra（EH-部分）', 27.8683194, -11.9804613),
(2691, 149, 'LAR', 'Larache', '拉拉什', '拉拉什', 35.1744271, -6.1473964),
(2692, 149, 'MDF', 'M’diq-Fnideq', '姆迪克-弗尼德克', '姆迪克-弗尼德克', 35.7733019, -5.5143300),
(2693, 149, 'MAR', 'Marrakech', '馬拉喀什', '马拉喀什', 31.6346023, -8.0778932),
(2694, 149, '07', 'Marrakesh-Safi', '馬拉喀什-薩菲', '马拉喀什-萨菲', 31.7330833, -8.1338558),
(2695, 149, 'MED', 'Médiouna', '地中海', '地中海', 33.4540939, -7.5166020),
(2696, 149, 'MEK', 'Meknès', '梅克內斯', '梅克内斯', 33.8810000, -5.5730397),
(2697, 149, 'MID', 'Midelt', '米德爾特', '米德尔特', 32.6855079, -4.7501709),
(2698, 149, 'MOH', 'Mohammadia', '穆罕默德', '穆罕默德', 33.6873749, -7.4239142),
(2699, 149, 'MOU', 'Moulay Yacoub', '穆萊·雅庫布', '穆莱·雅库布', 34.0874479, -5.1784019),
(2700, 149, 'NAD', 'Nador', '納多爾', '纳祖尔', 34.9171926, -2.8577105),
(2701, 149, 'NOU', 'Nouaceur', 'Nouaceur', 'Nouaceur', 33.3670393, -7.5732537),
(2702, 149, 'OUA', 'Ouarzazate', '瓦爾紮紮特', '瓦尔扎扎特', 30.9335436, -6.9370160),
(2703, 149, 'OUD', 'Oued Ed-Dahab (EH)', '烏德·埃德-達哈布 （EH）', '乌德·埃德-达哈布 （EH）', 22.7337892, -14.2861116),
(2704, 149, 'OUZ', 'Ouezzane', '烏埃扎內', '乌埃赞', 34.8063450, -5.5914505),
(2705, 149, 'OUJ', 'Oujda-Angad', '烏季達-安加德', '乌季达-安加德', 34.6837504, -2.2993239),
(2706, 149, 'RAB', 'Rabat', '拉巴特', '拉巴特', 33.9691990, -6.9273029),
(2707, 149, '04', 'Rabat-Salé-Kénitra', '拉巴特-薩萊-凱尼特拉', '拉巴特-萨莱-凯尼特拉', 34.0768640, -7.3454476),
(2708, 149, 'REH', 'Rehamna', '雷哈姆納', '雷哈姆纳', 32.2032905, -8.5689671),
(2709, 149, 'SAF', 'Safi', '薩菲', '萨菲', 32.2989872, -9.1013498),
(2710, 149, 'SAL', 'Salé', '鹹', '咸', 34.0377570, -6.8427073),
(2711, 149, 'SEF', 'Sefrou', '塞弗魯', '塞弗鲁', 33.8305244, -4.8353154),
(2712, 149, 'SET', 'Settat', '塞塔特', '塞塔特', 32.9924242, -7.6222665),
(2713, 149, 'SIB', 'Sidi Bennour', '西迪·本努爾', '西迪·本努尔', 32.6492602, -8.4471453),
(2714, 149, 'SIF', 'Sidi Ifni', '西迪·伊夫尼', '西迪·伊夫尼', 29.3665797, -10.2108485),
(2715, 149, 'SIK', 'Sidi Kacem', '西迪·卡西姆', '西迪·卡西姆', 34.2260172, -5.7129164),
(2716, 149, 'SIL', 'Sidi Slimane', '西迪·斯利曼', '西迪·斯利曼', 34.2737828, -5.9805972),
(2717, 149, 'SKH', 'Skhirate-Témara', '斯基拉特-特馬拉', '斯基拉特-特马拉', 33.7622425, -7.0419052),
(2718, 149, '09', 'Souss-Massa', '蘇斯-馬薩', '苏斯-马萨', 30.2750611, -8.1338558),
(2719, 149, 'TNT', 'Tan-Tan (EH-partial)', 'Tan-Tan（EH-部分）', '坦坦（EH-部分）', 28.0301200, -11.1617356),
(2720, 149, 'TNG', 'Tanger-Assilah', '丹吉爾-阿西拉', '丹吉尔-阿西拉', 35.7632539, -5.9045098),
(2721, 149, '01', 'Tanger-Tétouan-Al Hoceïma', '丹吉爾-得土安-阿爾霍塞馬', '丹吉尔-得土安-阿尔霍塞马', 35.2629558, -5.5617279),
(2722, 149, 'TAO', 'Taounate', '陶納特', '陶纳特', 34.5369170, -4.6398693),
(2723, 149, 'TAI', 'Taourirt', '陶里特', '陶里尔特', 34.2125980, -2.6983868),
(2724, 149, 'TAF', 'Tarfaya (EH-partial)', '塔爾法亞（EH-部分）', '塔尔法亚（EH-部分）', 27.9377701, -12.9294063),
(2725, 149, 'TAR', 'Taroudannt', '塔魯丹特', '塔鲁丹特', 30.4727126, -8.8748765),
(2726, 149, 'TAT', 'Tata', '系統', '系统', 29.7508770, -7.9756343),
(2727, 149, 'TAZ', 'Taza', '杯子', '杯子', 34.2788953, -3.5812692),
(2728, 149, 'TET', 'Tétouan', '得土安', '得土安', 35.5888995, -5.3625516),
(2729, 149, 'TIN', 'Tinghir', '廷吉爾', '廷吉尔', 31.4850794, -6.2019298),
(2730, 149, 'TIZ', 'Tiznit', '蒂茲尼特', '蒂兹尼特', 29.6933920, -9.7321570),
(2731, 149, 'YUS', 'Youssoufia', '優素菲亞', '优素菲亚', 32.0200679, -8.8692648),
(2732, 149, 'ZAG', 'Zagora', '扎戈拉', '扎戈拉', 30.5786093, -5.8987139),
(2733, 150, 'P', 'Cabo Delgado', '德爾加杜角', '德尔加杜角', -12.3335474, 39.3206241),
(2734, 150, 'G', 'Gaza', '加薩', '加沙', -23.0221928, 32.7181375),
(2735, 150, 'I', 'Inhambane', '伊尼揚巴內', '伊尼扬巴内', -22.8527997, 34.5508758),
(2736, 150, 'B', 'Manica', '袖', '袖', -19.5059787, 33.4383530),
(2737, 150, 'L', 'Maputo', '馬普托', '马普托', -25.2569876, 32.5372741),
(2738, 150, 'MPM', 'Maputo', '馬普托', '马普托', -25.9692480, 32.5731746),
(2739, 150, 'N', 'Nampula', '楠普拉', '楠普拉', -14.7604931, 39.3206241),
(2740, 150, 'A', 'Niassa', '尼亞薩', '尼亚萨', -12.7826202, 36.6093926),
(2741, 150, 'S', 'Sofala', '沙法拉', '沙法拉', -19.2039073, 34.8624166),
(2742, 150, 'T', 'Tete', '頭部', '头', -15.6596056, 32.7181375),
(2743, 150, 'Q', 'Zambezia', '贊比西亞', '赞比西亚', -16.5638987, 36.6093926),
(2744, 151, '07', 'Ayeyarwady', '伊洛瓦底江', '伊洛瓦底江', 17.0342125, 95.2266675),
(2745, 151, '02', 'Bago', '勃固', '勃固', 17.3220711, 96.4663286),
(2746, 151, '14', 'Chin', '下巴', '下巴', 22.0086978, 93.5812692),
(2747, 151, '11', 'Kachin', '克欽邦', '克钦语', 25.8509040, 97.4381355),
(2748, 151, '12', 'Kayah', '克耶', '克耶', 19.2342061, 97.2652858),
(2749, 151, '13', 'Kayin', '克倫', '克伦', 16.9459346, 97.9592863),
(2750, 151, '03', 'Magway', '馬圭', '马圭', 19.8871386, 94.7277528),
(2751, 151, '04', 'Mandalay', '曼德勒', '曼德勒', 21.5619058, 95.8987139),
(2752, 151, '15', 'Mon State', '孟州', '孟州', 16.3003133, 97.6982272),
(2753, 151, '18', 'Naypyidaw', '內比都', '内比都', 19.9386245, 96.1526985),
(2754, 151, '16', 'Rakhine', '若開邦', '若开邦', 20.1040818, 93.5812692),
(2755, 151, '01', 'Sagaing', '實皆', '实皆', 24.4283810, 95.3939551),
(2756, 151, '17', 'Shan', '單', '单', 22.0361985, 98.1338558),
(2757, 151, '05', 'Tanintharyi', '塔寧塔里', '塔宁塔里', 12.4706876, 99.0128926),
(2758, 151, '06', 'Yangon', '仰光', '仰光', 16.9143488, 96.1526985),
(2759, 152, 'ER', 'Erongo', '埃龍戈', '埃龙戈', -22.2565682, 15.4068079),
(2760, 152, 'HA', 'Hardap', '哈達普', '哈达普', -24.2310134, 17.6688870),
(2761, 152, 'KA', 'Karas', '戰', '战争', -26.8429645, 17.2902839),
(2762, 152, 'KE', 'Kavango East', '卡萬戈東', '卡万戈东', -18.2710480, 18.4276047),
(2763, 152, 'KW', 'Kavango West', '卡萬戈西', '卡万戈西', -18.2710480, 18.4276047),
(2764, 152, 'KH', 'Khomas', '霍馬斯', '霍马斯', -22.6377854, 17.1011931),
(2765, 152, 'KU', 'Kunene', '剛好。', '完全。', -19.4086317, 13.9143990),
(2766, 152, 'OW', 'Ohangwena', '奧杭韋納', '奥杭韦纳', -17.5979291, 16.8178377),
(2767, 152, 'OH', 'Omaheke', '奧馬赫科', '奥马赫科', -21.8466651, 19.1880047),
(2768, 152, 'OS', 'Omusati', '奧穆薩蒂', '奥穆萨蒂', -18.4070294, 14.8454619),
(2769, 152, 'ON', 'Oshana', '奧莎娜', '奥沙纳', -18.4305064, 15.6881788),
(2770, 152, 'OT', 'Oshikoto', '押琴', '押琴', -18.4152575, 16.9122510),
(2771, 152, 'OD', 'Otjozondjupa', '奧喬宗朱帕', '奥乔宗朱帕', -20.5486916, 17.6688870),
(2772, 152, 'CA', 'Zambezi', '贊比西', '赞比西河', -17.8193419, 23.9536466),
(2773, 153, '01', 'Aiwo', '愛沃', '爱沃', -0.5340012, 166.9138873),
(2774, 153, '02', 'Anabar', '阿納巴爾', '阿纳巴尔', -0.5133517, 166.9484624),
(2775, 153, '03', 'Anetan', '阿內坦', '阿内坦', -0.5064343, 166.9427006),
(2776, 153, '04', 'Anibare', '阿尼巴雷', '阿尼巴雷', -0.5294758, 166.9513432),
(2777, 153, '05', 'Baiti', '白提', '白体', -0.5104310, 166.9275744),
(2778, 153, '06', 'Boe', '京東方', '京东方', 39.0732776, -94.5710498),
(2779, 153, '07', 'Buada', '佛', '佛', -0.5328777, 166.9268541),
(2780, 153, '08', 'Denigomodu', '德尼戈莫杜', '德尼戈莫杜', -0.5247964, 166.9167689),
(2781, 153, '09', 'Ewa', '前夕', '前夕', -0.5087241, 166.9369384),
(2782, 153, '10', 'Ijuw', '伊朱', '伊朱', -0.5202767, 166.9571046),
(2783, 153, '11', 'Meneng', '梅能', '梅能', -0.5467240, 166.9383790),
(2784, 153, '12', 'Nibok', '尼博克', '尼博克', -0.5196208, 166.9189301),
(2785, 153, '13', 'Uaboe', '烏阿博', '乌阿博', -0.5202222, 166.9311761),
(2786, 153, '14', 'Yaren', '語言', '语言', -0.5466857, 166.9210913),
(2787, 154, 'P3', 'Bagmati', '巴格馬蒂', '巴格马蒂', 27.6489253, 83.9258834),
(2788, 154, 'P4', 'Gandaki', '甘達基', '甘达基', 28.3797812, 82.7177922),
(2789, 154, 'P6', 'Karnali', '卡納利', '卡纳利', 29.3039343, 81.0108860),
(2790, 154, 'P1', 'Koshi', '越', '越', 27.1547935, 82.4210749),
(2791, 154, 'P5', 'Lumbini', '藍毗尼', '蓝毗尼', 28.0224060, 77.7864628),
(2792, 154, 'P2', 'Madhesh', '馬德什', '马德什', 26.9391873, 84.4293467),
(2793, 154, 'P7', 'Sudurpashchim', '蘇杜爾帕什希姆', '苏杜尔帕什希姆', 29.3062371, 79.6135451),
(2794, 156, 'DR', 'Drenthe', '德倫特', '德伦特', 52.9476012, 6.6230586),
(2795, 156, 'FL', 'Flevoland', '弗萊沃蘭', '弗莱沃兰', 52.5279781, 5.5953508),
(2796, 156, 'FR', 'Friesland', '弗里斯蘭', '弗里斯兰', 53.1641642, 5.7817542),
(2797, 156, 'GE', 'Gelderland', '海爾德蘭', '海尔德兰', 52.0451550, 5.8718235),
(2798, 156, 'GR', 'Groningen', '格羅寧根', '格罗宁根', 53.2193835, 6.5665017),
(2799, 156, 'LI', 'Limburg', '林堡', '林堡', 51.4427238, 6.0608726),
(2800, 156, 'NB', 'North Brabant', '北布拉班特', '北布拉班特', 51.4826537, 5.2321687),
(2801, 156, 'NH', 'North Holland', '北荷蘭', '北荷兰', 52.5205869, 4.7884740),
(2802, 156, 'OV', 'Overijssel', '上艾瑟爾', '上艾瑟尔', 52.4387814, 6.5016411),
(2803, 156, 'ZH', 'South Holland', '南荷蘭', '南荷兰', 51.9966792, 4.5597397),
(2804, 156, 'UT', 'Utrecht', '烏得勒支', '乌德勒支', 52.0907374, 5.1214201),
(2805, 156, 'ZE', 'Zeeland', '澤蘭', '泽兰', 51.4940309, 3.8496815),
(2806, 157, '03', 'Loyalty Islands Province', '洛亞爾蒂群島省', '洛亚尔蒂群岛省', -20.9667000, 167.2333000),
(2807, 157, '02', 'North Province', '北省', '北省', -22.2758000, 166.4580000),
(2808, 157, '01', 'South Province', '南方省', '南方省', -22.2758000, 166.4580000),
(2809, 158, 'AUK', 'Auckland', '奧克蘭', '奥克兰', -36.6675328, 174.7733325),
(2810, 158, 'BOP', 'Bay of Plenty', '豐盛灣', '丰盛湾', -37.4233917, 176.7416374),
(2811, 158, 'CAN', 'Canterbury', '坎特伯雷', '坎特伯雷', -43.7542275, 171.1637245),
(2812, 158, 'CIT', 'Chatham Islands', '查塔姆群島', '查塔姆群岛', -44.0057523, -176.5400674),
(2813, 158, 'GIS', 'Gisborne', '吉斯本', '吉斯伯恩', -38.1358174, 178.3239309),
(2814, 158, 'HKB', 'Hawke\'s Bay', '霍克', '霍克', -39.6016597, 176.5804473),
(2815, 158, 'MWT', 'Manawatu-Wanganui', '馬納瓦圖-旺加努伊', '马纳瓦图-旺加努伊', -39.7273356, 175.4375574),
(2816, 158, 'MBH', 'Marlborough', '馬爾堡', '马尔伯勒', -41.5916883, 173.7624053),
(2817, 158, 'NSN', 'Nelson', '納爾遜', '纳尔逊', -41.2985397, 173.2441491),
(2818, 158, 'NTL', 'Northland', '北國', '北国', -35.4136172, 173.9320806),
(2819, 158, 'OTA', 'Otago', '奧塔哥', '奥塔哥', -45.4790671, 170.1547567),
(2820, 158, 'STL', 'Southland', '南國', '南国', -45.8489159, 167.6755387),
(2821, 158, 'TKI', 'Taranaki', '塔拉納基', '塔拉纳基', -39.3538149, 174.4382721),
(2822, 158, 'TAS', 'Tasman', '塔斯曼', '塔 斯 曼', -41.4571184, 172.8209740),
(2823, 158, 'WKO', 'Waikato', '懷卡托', '怀卡托', -37.6190862, 175.0233460),
(2824, 158, 'WGN', 'Wellington', '惠靈頓', '惠灵顿', -41.0299323, 175.4375574),
(2825, 158, 'WTC', 'West Coast', '西海岸', '西海岸', 62.4113634, -149.0729714),
(2826, 159, 'BO', 'Boaco', '博阿科', '博阿科', 12.4692840, -85.6614682),
(2827, 159, 'CA', 'Carazo', '地獄', '地狱', 11.7274729, -86.2158497),
(2828, 159, 'CI', 'Chinandega', '奇南德加', '奇南德加', 12.8820062, -87.1422895),
(2829, 159, 'CO', 'Chontales', 'Chontales', 'Chontales', 11.9394717, -85.1894045),
(2830, 159, 'ES', 'Estelí', '埃斯特利', '埃斯特利', 13.0851139, -86.3630197),
(2831, 159, 'GR', 'Granada', '手榴彈', '手榴弹', 11.9344073, -85.9560005),
(2832, 159, 'JI', 'Jinotega', '吉諾特加', '吉诺特加', 13.0883907, -85.9993997),
(2833, 159, 'LE', 'León', '獅子', '狮子', 12.5092037, -86.6611083),
(2834, 159, 'MD', 'Madriz', '馬德里斯', '马德里斯', 13.4726005, -86.4592091),
(2835, 159, 'MN', 'Managua', '馬那瓜', '马那瓜', 12.1391699, -86.3376761),
(2836, 159, 'MS', 'Masaya', '雅也', '雅也', 11.9759328, -86.0733498),
(2837, 159, 'MT', 'Matagalpa', '馬塔加爾帕', '马塔加尔帕 Matagalpa', 12.9498436, -85.4375574),
(2838, 159, 'AN', 'North Caribbean Coast', '北加勒比海岸', '北加勒比海岸', 13.8394456, -83.9320806),
(2839, 159, 'NS', 'Nueva Segovia', '新塞哥維亞', '新塞哥维亚', 13.7657061, -86.5370039),
(2840, 159, 'SJ', 'Río San Juan', '聖胡安河', '圣胡安河', 11.4781610, -84.7733325),
(2841, 159, 'RI', 'Rivas', '里瓦斯', '里瓦斯', 11.4023490, -85.6845780),
(2842, 159, 'AS', 'South Caribbean Coast', '南加勒比海岸', '南加勒比海岸', 12.1918502, -84.1012861),
(2843, 160, '1', 'Agadez', '阿加德茲', '阿加德兹', 20.6670752, 12.0718281),
(2844, 160, '2', 'Diffa', '迪法', '迪法', 13.6768647, 12.7135121),
(2845, 160, '3', 'Dosso', '多索', '多索', 13.1513947, 3.4195527),
(2846, 160, '4', 'Maradi', '馬拉迪', '马拉迪', 13.8018074, 7.4381355),
(2847, 160, '5', 'Tahoua', '塔瓦', '塔瓦', 16.0902543, 5.3939551),
(2848, 160, '6', 'Tillabéri', '蒂拉貝里', '蒂拉贝里', 14.6489525, 2.1450245),
(2849, 160, '7', 'Zinder', '辛德', '津德', 15.1718881, 10.2600125),
(2850, 161, 'AB', 'Abia', '僅', '几乎', 5.4527354, 7.5248414),
(2851, 161, 'FC', 'Abuja Federal Capital Territory', '阿布賈聯邦首都特區', '阿布贾联邦首都特区', 8.8940691, 7.1860402),
(2852, 161, 'AD', 'Adamawa', '阿達馬瓦', '阿达马瓦', 9.3264751, 12.3983853),
(2853, 161, 'AK', 'Akwa Ibom', '阿夸伊博姆', '阿夸伊博姆', 4.9057371, 7.8536675),
(2854, 161, 'AN', 'Anambra', '阿南布拉', '阿南布拉', 6.2208997, 6.9369559),
(2855, 161, 'BA', 'Bauchi', '包奇', '包奇', 10.7760624, 9.9991943),
(2856, 161, 'BY', 'Bayelsa', '巴耶爾薩', '巴耶尔萨', 4.7719071, 6.0698526),
(2857, 161, 'BE', 'Benue', '貝努埃', '贝努埃', 7.3369024, 8.7403687),
(2858, 161, 'BO', 'Borno', '博爾諾', '博尔诺', 11.8846356, 13.1519665),
(2859, 161, 'CR', 'Cross River', '克羅斯河', '克罗斯河', 5.8701724, 8.5988014),
(2860, 161, 'DE', 'Delta', '三角洲', '三角洲', 33.7453784, -90.7354508),
(2861, 161, 'EB', 'Ebonyi', '烏檀', '乌檀', 6.2649232, 8.0137302),
(2862, 161, 'ED', 'Edo', '或', '或', 6.6341831, 5.9304056),
(2863, 161, 'EK', 'Ekiti', '埃基蒂', '埃基蒂', 7.7189862, 5.3109505),
(2864, 161, 'EN', 'Enugu', '埃努古', '埃努古', 6.5363530, 7.4356194),
(2865, 161, 'GO', 'Gombe', '貢貝', '贡贝', 10.3637795, 11.1927587),
(2866, 161, 'IM', 'Imo', '伊莫', '国际 海事 组织', 5.5720122, 7.0588219),
(2867, 161, 'JI', 'Jigawa', '吉加瓦', '吉加瓦', 12.2280120, 9.5615867),
(2868, 161, 'KD', 'Kaduna', '卡杜納', '卡杜纳', 10.3764006, 7.7094537),
(2869, 161, 'KN', 'Kano', '卡諾', '卡诺', 11.7470698, 8.5247107),
(2870, 161, 'KT', 'Katsina', '卡齊納', '卡齐纳', 12.3796707, 7.6305748),
(2871, 161, 'KE', 'Kebbi', '凱比', '凯比', 11.4942003, 4.2333355),
(2872, 161, 'KO', 'Kogi', '科吉', '科吉', 7.7337325, 6.6905836),
(2873, 161, 'KW', 'Kwara', '誇祖魯-納塔爾省', '夸祖鲁-纳塔尔省', 8.9668961, 4.3874051);
INSERT INTO `location_states` (`state_id`, `country_id`, `state_code`, `state_name_en`, `state_name_zh_tw`, `state_name_zh_cn`, `state_center_latitude`, `state_center_longitude`) VALUES
(2874, 161, 'LA', 'Lagos', '湖泊', '湖泊', 6.5243793, 3.3792057),
(2875, 161, 'NA', 'Nasarawa', '納薩拉瓦', '纳萨拉瓦', 8.4997908, 8.1996937),
(2876, 161, 'NI', 'Niger', '尼日', '尼日尔', 9.9309224, 5.5983210),
(2877, 161, 'OG', 'Ogun', '戰', '战争', 6.9979747, 3.4737378),
(2878, 161, 'ON', 'Ondo', '不錯', '不错', 6.9148682, 5.1478144),
(2879, 161, 'OS', 'Osun', '奧孫', '奥孙', 7.5628964, 4.5199593),
(2880, 161, 'OY', 'Oyo', '那就是', '那是', 8.1573809, 3.6146534),
(2881, 161, 'PL', 'Plateau', '塝', '高原', 9.2182093, 9.5179488),
(2882, 161, 'RI', 'Rivers', '沱', '河流', 5.0213420, 6.4376022),
(2883, 161, 'SO', 'Sokoto', '索科托', '索科托', 13.0533143, 5.3222722),
(2884, 161, 'TA', 'Taraba', '塔拉巴', '塔拉巴', 7.9993616, 10.7739863),
(2885, 161, 'YO', 'Yobe', '職位', '工作', 12.2938760, 11.4390411),
(2886, 161, 'ZA', 'Zamfara', '贊法拉', '赞法拉', 12.1221805, 6.2235819),
(2887, 162, '14', 'Alofi North', '阿洛菲北', '阿洛菲北', -19.0488977, -169.9190905),
(2888, 162, '13', 'Alofi South', '阿洛菲南', '阿洛菲南', -19.0735968, -169.9480408),
(2889, 162, '11', 'Avatele', '阿瓦特爾', '阿瓦特勒', -19.1237302, -169.9165678),
(2890, 162, '09', 'Hakupu', '白府', '白府', -19.1287275, -169.8492123),
(2891, 162, '04', 'Hikutavake', '彥塔瓦克', '彦达岳', -18.9775511, -169.8944536),
(2892, 162, '07', 'Lakepa', '拉克帕', '拉克帕', -19.0096425, -169.8120046),
(2893, 162, '08', 'Liku', '絞', '扭曲', -19.0536907, -169.7942591),
(2894, 162, '01', 'Makefu', '馬克福', '马克福', -19.0032618, -169.9204732),
(2895, 162, '06', 'Mutalau', '穆塔勞', '穆塔劳', -18.9639385, -169.8327863),
(2896, 162, '03', 'Namukulu', '納穆庫魯', '纳穆库鲁', -18.9812275, -169.9029422),
(2897, 162, '12', 'Tamakautoga', '塔馬卡托加', '玉汽车', -19.1019851, -169.9301721),
(2898, 162, '05', 'Toi', '你', '你', -18.9737600, -169.8629774),
(2899, 162, '02', 'Tuapa', '圖阿帕', '图阿帕', -18.9912507, -169.9092078),
(2900, 162, '10', 'Vaiea', '去', '去', -19.1308358, -169.8938012),
(2901, 115, '04', 'Chagang', '茶崗', '茶岗', 40.7202809, 126.5621137),
(2902, 115, '07', 'Kangwon', '江原', '江原', 38.8432393, 127.5597067),
(2903, 115, '09', 'North Hamgyong', '咸鏡北道', '咸镜北道', 41.8148758, 129.4581955),
(2904, 115, '06', 'North Hwanghae', '黃海北道', '黄海北道', 38.3786085, 126.4364363),
(2905, 115, '03', 'North Pyongan', '平安北道', '平安北道', 39.9255618, 125.3928025),
(2906, 115, '01', 'Pyongyang', '平壤', '平壤', 39.0392193, 125.7625241),
(2907, 115, '13', 'Rason', '羅森', '罗森', 42.2569063, 130.2977186),
(2908, 115, '10', 'Ryanggang', '兩江', '两江', 41.2318921, 128.5076359),
(2909, 115, '08', 'South Hamgyong', '咸鏡南道', '咸镜南道', 40.3725339, 128.2988840),
(2910, 115, '05', 'South Hwanghae', '黃海南道', '黄海南道', 38.2007215, 125.4781926),
(2911, 115, '02', 'South Pyongan', '平安南道', '平安南道', 39.3539178, 126.1682710),
(2912, 129, '01', 'Aerodrom', '機場', '飞机场', 41.9464363, 21.4931713),
(2913, 129, '02', 'Aračinovo', '阿拉奇諾沃', '阿拉奇诺沃', 42.0247381, 21.5766407),
(2914, 129, '03', 'Berovo', '貝羅沃', '贝罗沃', 41.6661929, 22.7628830),
(2915, 129, '04', 'Bitola', '估計', '轨距', 41.0363302, 21.3321974),
(2916, 129, '05', 'Bogdanci', '博格丹奇', '博格丹奇', 41.1869616, 22.5960268),
(2917, 129, '06', 'Bogovinje', '女神們', '女神', 41.9236371, 20.9163887),
(2918, 129, '07', 'Bosilovo', '博西洛沃', '博西洛沃', 41.4904864, 22.7867174),
(2919, 129, '08', 'Brvenica', '布爾韋尼卡', '布尔韦尼卡', 41.9681482, 20.9819586),
(2920, 129, '09', 'Butel', '布特爾', '布特尔', 42.0895068, 21.4633610),
(2921, 129, '79', 'Čair', 'Čair', 'Čair', 41.9930355, 21.4365318),
(2922, 129, '80', 'Čaška', '查什卡', '查什卡', 41.6474380, 21.6914115),
(2923, 129, '77', 'Centar', '中央', '中心', 41.9698934, 21.4216267),
(2924, 129, '78', 'Centar Župa', '祖帕中心', '祖帕中心', 41.4652259, 20.5930548),
(2925, 129, '81', 'Češinovo-Obleševo', '捷克-奧布萊舍沃', '捷克-奥布列舍沃', 41.8639316, 22.2622460),
(2926, 129, '82', 'Čučer-Sandevo', '丘切爾-桑德沃', '丘切尔-桑德沃', 42.1483946, 21.4037407),
(2927, 129, '22', 'Debarca', '下船', '登陆', 41.3584077, 20.8552919),
(2928, 129, '23', 'Delčevo', '德爾切沃', '德尔切沃', 41.9684387, 22.7628830),
(2929, 129, '25', 'Demir Hisar', '鋼鐵堡壘', '钢铁堡垒', 41.2270830, 21.1414226),
(2930, 129, '24', 'Demir Kapija', '鐵卡皮亞', '铁卡皮亚', 41.3795538, 22.2145571),
(2931, 129, '26', 'Dojran', '多吉蘭', '多吉兰', 41.2436672, 22.6913764),
(2932, 129, '27', 'Dolneni', '多爾內尼', '多尔内尼', 41.4640935, 21.4037407),
(2933, 129, '28', 'Drugovo', '德魯戈沃', '德鲁戈沃', 41.4408153, 20.9268201),
(2934, 129, '17', 'Gazi Baba', '嘎茲巴巴', '加齐巴巴', 42.0162961, 21.4991334),
(2935, 129, '18', 'Gevgelija', 'Gevgelija', 'Gevgelija', 41.2118606, 22.3814624),
(2936, 129, '29', 'Gjorče Petrov', 'Gjorče Petrov', '格约尔切·彼得罗夫', 42.0606374, 21.3202736),
(2937, 129, '19', 'Gostivar', '戈斯蒂瓦爾', '戈斯蒂瓦尔', 41.8025541, 20.9089378),
(2938, 129, '20', 'Gradsko', '格拉茲科', '格拉兹科', 41.5991608, 21.8807064),
(2939, 129, '85', 'Greater Skopje', '大斯科普里', '大斯科普里', 41.9981294, 21.4254355),
(2940, 129, '34', 'Ilinden', '伊林登', '伊林登', 41.9957443, 21.5676975),
(2941, 129, '35', 'Jegunovce', '傑古諾夫采', '耶古诺夫采', 42.0740720, 21.1220478),
(2942, 129, '37', 'Karbinci', '卡爾賓奇', '卡尔宾奇', 41.8180159, 22.2324758),
(2943, 129, '38', 'Karpoš', '卡爾波什', '卡尔波什', 41.9709661, 21.3918168),
(2944, 129, '36', 'Kavadarci', '卡瓦達奇', '卡瓦达尔奇', 41.2890068, 21.9999435),
(2945, 129, '40', 'Kičevo', '基切沃', '基切沃', 41.5129112, 20.9525065),
(2946, 129, '39', 'Kisela Voda', '酸性水', '酸性水', 41.9274800, 21.4931713),
(2947, 129, '42', 'Kočani', '科查尼', '科查尼', 41.9858374, 22.4053046),
(2948, 129, '41', 'Konče', '完', '结束', 41.5171011, 22.3814624),
(2949, 129, '43', 'Kratovo', '克拉托沃', '克拉托沃', 42.0537141, 22.0714835),
(2950, 129, '44', 'Kriva Palanka', '克里瓦·帕蘭卡', '克里瓦·帕兰卡', 42.2058454, 22.3307965),
(2951, 129, '45', 'Krivogaštani', '克里沃加什塔尼', '克里沃加什塔尼', 41.3082306, 21.3679689),
(2952, 129, '46', 'Kruševo', '克魯塞沃', '克鲁塞沃', 41.3769331, 21.2606554),
(2953, 129, '47', 'Kumanovo', '庫馬諾沃', '库马诺沃', 42.0732613, 21.7853143),
(2954, 129, '48', 'Lipkovo', '利普科沃', '利普科沃', 42.2006626, 21.6183755),
(2955, 129, '49', 'Lozovo', '洛佐沃', '洛佐沃', 41.7818139, 21.9000827),
(2956, 129, '51', 'Makedonska Kamenica', '馬克頓斯卡·卡梅尼察', '马其顿斯卡梅尼察', 42.0694604, 22.5483490),
(2957, 129, '52', 'Makedonski Brod', '馬其頓斯基·布羅德', '马其顿斯基·布罗德', 41.5133088, 21.2174329),
(2958, 129, '50', 'Mavrovo and Rostuša', '馬夫羅沃和羅斯圖沙', '马夫罗沃和罗斯图沙', 41.6092427, 20.6012488),
(2959, 129, '53', 'Mogila', '莫吉拉', '莫吉拉', 41.1479645, 21.4514369),
(2960, 129, '54', 'Negotino', '內戈蒂諾', '内戈蒂诺', 41.4989985, 22.0953297),
(2961, 129, '55', 'Novaci', '諾瓦奇', '诺瓦奇', 41.0442661, 21.4588894),
(2962, 129, '56', 'Novo Selo', '新封印', '新印章', 41.4325580, 22.8820489),
(2963, 129, '58', 'Ohrid', '奧赫里德', '奥赫里德', 41.0682088, 20.7599266),
(2964, 129, '57', 'Oslomej ', '奧斯洛梅', '奥斯洛梅', 41.5758391, 21.0221960),
(2965, 129, '60', 'Pehčevo', '佩切沃', '佩切沃', 41.7737132, 22.8820489),
(2966, 129, '59', 'Petrovec', '彼得羅維茨', '彼得罗维茨', 41.9029897, 21.6899210),
(2967, 129, '61', 'Plasnica', '原漿菌', '原体', 41.4546349, 21.1056539),
(2968, 129, '62', 'Prilep', '泰盧固語', '泰卢固语', 41.2693142, 21.7137694),
(2969, 129, '63', 'Probištip', 'Probištip', 'Probištip', 41.9589146, 22.1668670),
(2970, 129, '64', 'Radoviš', '拉多維什', '拉多维什', 41.6495531, 22.4768287),
(2971, 129, '65', 'Rankovce', '蘭科夫采', '兰科夫采', 42.1808141, 22.0953297),
(2972, 129, '66', 'Resen', '雷森', '雷森', 40.9368093, 21.0460407),
(2973, 129, '67', 'Rosoman', '羅索曼', '罗索曼', 41.4848006, 21.8807064),
(2974, 129, '68', 'Saraj', '薩拉吉', '萨拉吉', 41.9869496, 21.2606554),
(2975, 129, '70', 'Sopište', '寫', '写', 41.8638492, 21.3083499),
(2976, 129, '71', 'Staro Nagoričane', '斯塔羅·納戈里查內', '斯塔罗·纳戈里查内', 42.2191692, 21.9045541),
(2977, 129, '83', 'Štip', '提示', 'Štip', 41.7079297, 22.1907122),
(2978, 129, '72', 'Struga', '車床', '车床', 41.3173744, 20.6645683),
(2979, 129, '73', 'Strumica', '斯特魯米卡', '斯特鲁米卡', 41.4378004, 22.6427428),
(2980, 129, '74', 'Studeničani', 'Studeničani', 'Studeničani', 41.9225639, 21.5363965),
(2981, 129, '84', 'Šuto Orizari', '舒托·奧里扎里', '舒托·奥里扎里', 42.0290416, 21.4097027),
(2982, 129, '69', 'Sveti Nikole', '聖尼古拉斯', '圣尼古拉斯', 41.8980312, 21.9999435),
(2983, 129, '75', 'Tearce', '蒂爾斯', '蒂尔斯', 42.0777511, 21.0534923),
(2984, 129, '76', 'Tetovo', '特托沃', '特托沃', 42.0274860, 20.9506636),
(2985, 129, '10', 'Valandovo', '瓦蘭多沃', '瓦兰多沃', 41.3211909, 22.5006693),
(2986, 129, '11', 'Vasilevo', '瓦西列沃', '瓦西列沃', 41.4741699, 22.6422128),
(2987, 129, '13', 'Veles', '韋萊斯', '韦莱斯', 41.7274426, 21.7137694),
(2988, 129, '12', 'Vevčani', 'Vevčani', '韦夫查尼', 41.2407543, 20.5915649),
(2989, 129, '14', 'Vinica', '葡萄園', '葡萄园', 41.8571020, 22.5721881),
(2990, 129, '15', 'Vraneštica', 'Vraneštica', '弗拉内什蒂卡', 41.4829087, 21.0579632),
(2991, 129, '16', 'Vrapčište', 'Vrapčište', 'Vrapčište', 41.8791160, 20.8314500),
(2992, 129, '31', 'Zajas', '扎哈斯', '扎哈斯', 41.6030328, 20.8791343),
(2993, 129, '32', 'Zelenikovo', '澤列尼科沃', '泽列尼科沃', 41.8733812, 21.6027250),
(2994, 129, '30', 'Želino', '熱利諾', '热利诺', 41.9006531, 21.1175767),
(2995, 129, '33', 'Zrnovci', 'Žrnovci', 'Žrnovci', 41.8228221, 22.4172256),
(2996, 165, '42', 'Agder', '學院', '大学', 58.7406934, 6.7531521),
(2997, 165, '34', 'Innlandet', '內陸', '内陆', 61.1935787, 5.5083266),
(2998, 165, '22', 'Jan Mayen', '揚·馬延', '扬·马延', 71.0318180, -8.2920346),
(2999, 165, '15', 'Møre og Romsdal', 'Møre og Romsdal', 'Møre og Romsdal', 62.8406833, 7.0071430),
(3000, 165, '18', 'Nordland', '諾德蘭', '诺德兰', 67.6930580, 12.7073936),
(3001, 165, '03', 'Oslo', '奧斯陸', '奥斯陆', 59.9138688, 10.7522454),
(3002, 165, '11', 'Rogaland', '羅加蘭', '罗加兰', 59.1489544, 6.0143432),
(3003, 165, '21', 'Svalbard', '斯瓦爾巴群島', '斯瓦尔巴群岛', 77.8749725, 20.9751821),
(3004, 165, '54', 'Troms og Finnmark', 'Troms og Finnmark', 'Troms og Finnmark', 69.7789067, 18.9940184),
(3005, 165, '50', 'Trøndelag', 'Trøndelag', 'Trøndelag', 63.5420125, 10.9369267),
(3006, 165, '38', 'Vestfold og Telemark', 'Vestfold og Telemark', 'Vestfold og Telemark', 59.4117482, 7.7647175),
(3007, 165, '46', 'Vestland', '維斯特蘭', '维斯特兰', 60.9069442, 3.9627081),
(3008, 165, '30', 'Viken', '灣', '湾', 59.9653005, 7.4505144),
(3009, 166, 'DA', 'Ad Dakhiliyah', '廣告達希利耶', '广告达希利耶', 22.8588758, 57.5394356),
(3010, 166, 'ZA', 'Ad Dhahirah', '阿德·達希拉', '阿德·达希拉', 23.2161674, 56.4907444),
(3011, 166, 'BS', 'Al Batinah North', '阿爾巴蒂納北', '阿尔巴蒂纳北', 24.3419846, 56.7298904),
(3012, 166, 'BA', 'Al Batinah Region', '阿爾巴蒂納地區', '巴蒂纳地区', 24.3419846, 56.7298904),
(3013, 166, 'BJ', 'Al Batinah South', '阿爾巴蒂納南', '阿尔巴蒂纳南', 23.4314903, 57.4239796),
(3014, 166, 'BU', 'Al Buraimi', '阿爾·布賴米', '阿尔·布赖米', 24.1671413, 56.1142253),
(3015, 166, 'WU', 'Al Wusta', '阿爾·烏斯塔', '阿尔·乌斯塔', 19.9571078, 56.2756846),
(3016, 166, 'SS', 'Ash Sharqiyah North', '阿什·沙基亞北', '阿什·沙基亚北', 22.7141196, 58.5308064),
(3017, 166, 'SH', 'Ash Sharqiyah Region', '阿什沙基亞地區', '阿什沙尔基亚地区', 22.7141196, 58.5308064),
(3018, 166, 'SJ', 'Ash Sharqiyah South', '阿什·沙基亞南', '阿什·沙基亚南', 22.0158249, 59.3251922),
(3019, 166, 'ZU', 'Dhofar', '佐法爾', '佐法尔', 17.0322121, 54.1425214),
(3020, 166, 'MU', 'Musandam', '穆桑達姆', '穆桑达姆', 26.1986144, 56.2460949),
(3021, 166, 'MA', 'Muscat', '馬斯喀特', '马斯喀特', 23.5880307, 58.3828717),
(3022, 167, 'JK', 'Azad Kashmir', '阿扎德克什米爾', '阿扎德克什米尔', 33.9259055, 73.7810334),
(3023, 167, 'BA', 'Balochistan', '俾路支省', '俾路支省', 28.4907332, 65.0957792),
(3024, 167, 'TA', 'Federally Administered Tribal Areas', '聯邦管理的部落地區', '联邦直辖部落地区', 32.6674760, 69.8597406),
(3025, 167, 'GB', 'Gilgit-Baltistan', '吉爾吉特-巴爾蒂斯坦', '吉尔吉特-巴尔蒂斯坦', 35.8025667, 74.9831808),
(3026, 167, 'IS', 'Islamabad', '伊斯蘭堡', '伊斯兰堡', 33.7204997, 73.0405277),
(3027, 167, 'KP', 'Khyber Pakhtunkhwa', '開伯爾-普赫圖赫瓦省', '开伯尔-普赫图赫瓦省', 34.9526205, 72.3311130),
(3028, 167, 'PB', 'Punjab', '旁遮普邦', '旁 遮 普', 31.1471305, 75.3412179),
(3029, 167, 'SD', 'Sindh', '信德省', '信德省', 25.8943018, 68.5247149),
(3030, 168, '002', 'Aimeliik', '類', '物种', 7.4455859, 134.5030878),
(3031, 168, '004', 'Airai', '愛來', '爱来', 7.3966118, 134.5690225),
(3032, 168, '010', 'Angaur', '安加爾', '安加尔', 6.9092230, 134.1387934),
(3033, 168, '050', 'Hatohobei', '鳩兵衛', '鸠穗兵卫', 3.0070658, 131.1237781),
(3034, 168, '100', 'Kayangel', '卡揚格爾', '卡扬格尔', 8.0700000, 134.7027780),
(3035, 168, '150', 'Koror', '科羅爾', '科罗尔', 7.3375646, 134.4889469),
(3036, 168, '212', 'Melekeok', '梅勒克克', '梅勒克', 7.5150286, 134.5972518),
(3037, 168, '214', 'Ngaraard', '恩加拉德', '恩加拉德', 7.6079400, 134.6348645),
(3038, 168, '218', 'Ngarchelong', '恩加切隆', '恩加切隆', 7.7105469, 134.6301646),
(3039, 168, '222', 'Ngardmau', '恩加德毛', '恩加德毛', 7.5850486, 134.5596089),
(3040, 168, '224', 'Ngatpang', '恩加蓬', '加特邦', 7.4710994, 134.5266466),
(3041, 168, '226', 'Ngchesar', '恩格薩爾', '恩格萨尔', 7.4523280, 134.5784342),
(3042, 168, '227', 'Ngeremlengui', 'Ngeremlengui', '恩格雷姆伦吉', 7.5198397, 134.5596089),
(3043, 168, '228', 'Ngiwal', '恩吉瓦爾', '恩吉瓦尔', 7.5614764, 134.6160619),
(3044, 168, '350', 'Peleliu', '貝里琉島', '贝里琉', 7.0022906, 134.2431628),
(3045, 168, '370', 'Sonsorol', '松索羅爾', '松索罗尔', 5.3268119, 132.2239117),
(3046, 169, 'BTH', 'Bethlehem', '伯利恆', '伯利恒', 31.7053996, 35.1936877),
(3047, 169, 'DEB', 'Deir El Balah', '代爾巴拉赫', '代尔巴拉赫', 31.4202897, 34.2861640),
(3048, 169, 'GZA', 'Gaza', '加薩', '加沙', 31.4872397, 34.1499890),
(3049, 169, 'HBN', 'Hebron', '希伯倫', '希伯伦', 31.5326001, 35.0639475),
(3050, 169, 'JEN', 'Jenin', '傑寧', '杰宁', 32.4263761, 35.0856887),
(3051, 169, 'JRH', 'Jericho ', '傑里哥', '耶利哥', 31.9676425, 35.1354279),
(3052, 169, 'JEM', 'Jerusalem (Quds)', '耶路撒冷（聖城）', '耶路撒冷（圣城）', 31.8020328, 34.9599664),
(3053, 169, 'KYS', 'Khan Yunis', '汗尤尼斯', '汗尤尼斯', 31.3298766, 34.2254833),
(3054, 169, 'NBS', 'Nablus', '納布盧斯', '纳布卢斯', 32.2243755, 35.2064793),
(3055, 169, 'NGZ', 'North Gaza', '北加沙', '北加沙', 31.5475060, 34.4281409),
(3056, 169, 'QQA', 'Qalqilya', NULL, NULL, 32.1810323, 34.9936999),
(3057, 169, 'RFH', 'Rafah', '拉法', '拉法', 31.2968899, 34.1116685),
(3058, 169, 'RBH', 'Ramallah', '拉馬拉', '拉马拉', 31.9430145, 34.8645651),
(3059, 169, 'SLT', 'Salfit', '薩爾菲特', '萨尔菲特', 32.1112272, 34.9578769),
(3060, 169, 'TBS', 'Tubas', '大號', '大号', 32.2938043, 34.8510980),
(3061, 169, 'TKM', 'Tulkarm', '圖勒凱姆', '图勒凯姆', 32.3276672, 34.9231108),
(3062, 170, '1', 'Bocas del Toro', '博卡斯德爾托羅', '博卡斯德尔托罗', 9.4165521, -82.5207787),
(3063, 170, '4', 'Chiriquí Province', '奇里基省', '奇里基省', 8.5848980, -82.3885783),
(3064, 170, '2', 'Coclé', '科克爾', '科克尔', 8.6266068, -80.3658650),
(3065, 170, '3', 'Colón', '科隆', '科隆', 9.1851989, -80.0534923),
(3066, 170, '5', 'Darién', '達里恩', '达里恩', 7.8681713, -77.8367282),
(3067, 170, 'EM', 'Emberá-Wounaan Comarca', 'Emberá-Wounaan Comarca', 'Emberá-Wounaan Comarca', 8.3766983, -77.6536125),
(3068, 170, 'KY', 'Guna', '古納', '古纳', 9.2344395, -78.1926250),
(3069, 170, '6', 'Herrera', '鐵匠', '铁匠', 7.7704282, -80.7214417),
(3070, 170, '7', 'Los Santos', '聖徒', '圣徒', 7.5909302, -80.3658650),
(3071, 170, 'NB', 'Ngöbe-Buglé Comarca', 'Ngöbe-Buglé Comarca', 'Ngöbe-Buglé Comarca', 8.6595833, -81.7787021),
(3072, 170, '8', 'Panamá', '巴拿馬', '巴拿马', 9.1196751, -79.2902133),
(3073, 170, '10', 'Panamá Oeste', '巴拿馬西部', '巴拿马西部', 9.1196751, -79.2902133),
(3074, 170, '9', 'Veraguas', '維拉瓜斯', '维拉瓜斯', 8.1231033, -81.0754657),
(3075, 171, 'NSB', 'Bougainville', '布干維爾', '布干维尔', -6.3753919, 155.3807101),
(3076, 171, 'CPM', 'Central', '中', '中央', -9.0849686, 146.7072733),
(3077, 171, 'CPK', 'Chimbu', '欽布', '钦布', -6.3087682, 144.8731219),
(3078, 171, 'EBR', 'East New Britain', '東新不列顛', '东新不列颠', -4.6128943, 151.8877321),
(3079, 171, 'ESW', 'East Sepik', '東塞皮克', '东塞皮克', -4.0000000, 143.7500000),
(3080, 171, 'EHG', 'Eastern Highlands', '東部高地', '东部高地', -6.5861674, 145.6689636),
(3081, 171, 'EPW', 'Enga', '不', '不', -5.3005849, 143.5635637),
(3082, 171, 'GPK', 'Gulf', '海灣', '海湾', -7.6400329, 142.1832677),
(3083, 171, 'HLA', 'Hela', '醫', '治愈', -5.6613108, 142.0899857),
(3084, 171, 'JWK', 'Jiwaka', '吉瓦卡', '吉瓦卡', -5.8691154, 144.6972774),
(3085, 171, 'MPM', 'Madang', '馬當', '马当', -4.9849733, 145.1375834),
(3086, 171, 'MRL', 'Manus', '腳本', '脚本', -2.0941169, 146.8760951),
(3087, 171, 'MBA', 'Milne Bay', '米爾恩灣', '米尔恩湾', -9.5221451, 150.6749653),
(3088, 171, 'MPL', 'Morobe', '莫羅貝', '莫罗贝', -6.8013737, 146.5616470),
(3089, 171, 'NIK', 'New Ireland', '新愛爾蘭', '新爱尔兰', -4.2853256, 152.9205918),
(3090, 171, 'NPP', 'Oro', '金', '金', -8.8988063, 148.1892921),
(3091, 171, 'NCD', 'Port Moresby', '莫爾茲比港', '莫尔兹比港', -9.4438004, 147.1802671),
(3092, 171, 'SAN', 'Sandaun', '桑道恩', '桑道恩', -3.7126179, 141.6834275),
(3093, 171, 'SHM', 'Southern Highlands', '南部高地', '南部高地', -6.4179083, 143.5635637),
(3094, 171, 'WBK', 'West New Britain', '西新不列顛', '西新不列颠', -5.7047432, 150.0259466),
(3095, 171, 'WPD', 'Western', '西方的', '西方', -7.1637537, 141.0635705),
(3096, 171, 'WHM', 'Western Highlands', '西部高地', '西部高地', -5.6268128, 144.2593118),
(3097, 172, '16', 'Alto Paraguay', '上巴拉圭', '上巴拉圭', -20.0852508, -59.4720904),
(3098, 172, '10', 'Alto Paraná', '上巴拉那州', '上巴拉那州', -25.6075546, -54.9611836),
(3099, 172, '13', 'Amambay', '阿曼拜', '阿曼拜', -22.5590272, -56.0249982),
(3100, 172, 'ASU', 'Asuncion', '亞松森', '亚松森', -25.2968297, -57.6806623),
(3101, 172, '19', 'Boquerón', '鯷', '鳀', -21.7449254, -60.9540073),
(3102, 172, '5', 'Caaguazú', '卡瓜蘇', '卡瓜苏', -25.4645818, -56.0138510),
(3103, 172, '6', 'Caazapá', '卡阿薩帕', '卡阿萨帕', -26.1827713, -56.3712327),
(3104, 172, '14', 'Canindeyú', '卡寧德尤', '卡宁德尤', -24.1378735, -55.6689636),
(3105, 172, '11', 'Central', '中', '中央', 36.1559229, -95.9662075),
(3106, 172, '1', 'Concepción', '概念', '概念', -23.4214264, -57.4344451),
(3107, 172, '3', 'Cordillera', '䃳', '山脉', -25.2289491, -57.0111681),
(3108, 172, '4', 'Guairá', '瓜伊拉', '瓜伊拉', -25.8810932, -56.2929381),
(3109, 172, '7', 'Itapúa', '伊塔普亞', '伊塔普亚', -26.7923623, -55.6689636),
(3110, 172, '8', 'Misiones', '任務', '任务', -26.8433512, -57.1013188),
(3111, 172, '12', 'Ñeembucú', 'Ñeembucú', 'Ñeembucú', -27.0299114, -57.8253950),
(3112, 172, '9', 'Paraguarí', '巴拉瓜里', '巴拉瓜里', -25.6262174, -57.1520642),
(3113, 172, '15', 'Presidente Hayes', '海斯會長', '海耶斯总统', -23.3512605, -58.7373634),
(3114, 172, '2', 'San Pedro', '聖佩德羅', '圣佩德罗', -24.1948668, -56.5616470),
(3115, 173, 'AMA', 'Amazonas', '亞馬遜河', '亚马逊河', -4.9856327, -79.2417436),
(3116, 173, 'ANC', 'Áncash', '安卡什', '安卡什', -9.3250497, -77.5619419),
(3117, 173, 'APU', 'Apurímac', '阿普里馬克', '阿普里马克', -14.0504533, -73.0877490),
(3118, 173, 'ARE', 'Arequipa', '阿雷基帕', '阿雷基帕', -16.4090474, -71.5374510),
(3119, 173, 'AYA', 'Ayacucho', '阿亞庫喬', '阿亚库乔', -13.1638737, -74.2235641),
(3120, 173, 'CAJ', 'Cajamarca', '卡哈馬卡', '卡哈马卡', -7.1617465, -78.5127855),
(3121, 173, 'CAL', 'Callao', '卡亞俄', '卡亚俄', -12.0508491, -77.1259843),
(3122, 173, 'CUS', 'Cusco', '庫斯科', '库斯科', -13.5319500, -71.9674626),
(3123, 173, 'HUV', 'Huancavelica', '萬卡維利卡', '万卡维利卡', -12.7861978, -74.9764024),
(3124, 173, 'HUC', 'Huanuco', '華努科', '华努科', -9.9207648, -76.2410843),
(3125, 173, 'ICA', 'Ica', '伊卡', '伊卡', -14.2006239, -76.8415195),
(3126, 173, 'JUN', 'Junín', '胡寧', '胡宁', -11.1581925, -75.9926306),
(3127, 173, 'LAL', 'La Libertad', '自由', '自由', -7.9540887, -79.6153395),
(3128, 173, 'LAM', 'Lambayeque', '蘭巴耶克', '兰巴耶克', -6.7197666, -79.9080757),
(3129, 173, 'LIM', 'Lima', '檔案', '文件', -12.0463731, -77.0427540),
(3130, 173, 'LOR', 'Loreto', '洛雷托', '洛雷托', -4.3741643, -76.1304264),
(3131, 173, 'MDD', 'Madre de Dios', '天主之母', '天主之母', -11.7668705, -70.8119953),
(3132, 173, 'MOQ', 'Moquegua', '莫克瓜', '莫克瓜', -17.1927361, -70.9328138),
(3133, 173, 'PAS', 'Pasco', '帕斯科', '帕斯科', -10.2980640, -76.7506193),
(3134, 173, 'PIU', 'Piura', '皮烏拉', '皮乌拉', -5.1782884, -80.6548882),
(3135, 173, 'PUN', 'Puno', '斯圖加特', '斯图加特', -15.8402218, -70.0218805),
(3136, 173, 'SAM', 'San Martín', '聖馬丁', '圣马丁', 37.0849464, -121.6102216),
(3137, 173, 'TAC', 'Tacna', '塔克納', '塔克纳', -18.0065679, -70.2462741),
(3138, 173, 'TUM', 'Tumbes', '通貝斯', '通贝斯', -3.5564921, -80.4270885),
(3139, 173, 'UCA', 'Ucayali', '烏卡亞利', '乌卡亚利', -9.8251183, -73.0877490),
(3140, 174, 'ABR', 'Abra', '阿布拉', '阿布拉', 42.4970830, -96.3844100),
(3141, 174, 'AGN', 'Agusan del Norte', '北阿古桑', '北阿古桑', 8.9456259, 125.5319234),
(3142, 174, 'AGS', 'Agusan del Sur', '南阿古桑', '南阿古桑', 8.0463888, 126.0615384),
(3143, 174, 'AKL', 'Aklan', '阿克蘭', '阿克兰', 11.8166109, 122.0941541),
(3144, 174, 'ALB', 'Albay', '阿爾拜', '阿尔拜', 13.1774827, 123.5280072),
(3145, 174, 'ANT', 'Antique', '古董', '古董', 37.0358695, -95.6361694),
(3146, 174, 'APA', 'Apayao', '阿帕堯', '阿帕尧', 18.0120304, 121.1710389),
(3147, 174, 'AUR', 'Aurora', '極光', '极光', 36.9708910, -93.7179790),
(3148, 174, '14', 'Autonomous Region in Muslim Mindanao', '棉蘭老島穆斯林自治區', '棉兰老岛穆斯林自治区', 6.9568313, 124.2421597),
(3149, 174, 'BAS', 'Basilan', '巴西蘭', '巴西兰', 6.4296349, 121.9870165),
(3150, 174, 'BAN', 'Bataan', '巴丹', '巴丹', 14.6416842, 120.4818446),
(3151, 174, 'BTN', 'Batanes', '巴丹群島', '巴丹群岛', 20.4485074, 121.9708129),
(3152, 174, 'BTG', 'Batangas', '八打雁', '八打雁', 13.7564651, 121.0583076),
(3153, 174, 'BEN', 'Benguet', '本格特', '本格特', 16.5577257, 120.8039474),
(3154, 174, '05', 'Bicol', '比科爾', '比科尔', 13.4209885, 123.4136736),
(3155, 174, 'BIL', 'Biliran', '比利蘭', '比利兰', 11.5833152, 124.4641848),
(3156, 174, 'BOH', 'Bohol', '薄荷島', '薄荷岛', 9.8499911, 124.1435427),
(3157, 174, 'BUK', 'Bukidnon', '布基農', '布基农', 8.0515054, 124.9229946),
(3158, 174, 'BUL', 'Bulacan', '布拉干島', '布拉干岛', 14.7942735, 120.8799008),
(3159, 174, 'CAG', 'Cagayan', '卡加延', '卡加延', 18.2489629, 121.8787833),
(3160, 174, '02', 'Cagayan Valley', '卡加延谷', '卡加延山谷', 16.9753758, 121.8107079),
(3161, 174, '40', 'Calabarzon', '卡拉巴松', '卡拉巴松', 14.1007803, 121.0793705),
(3162, 174, 'CAN', 'Camarines Norte', '北卡馬林', '北卡马林', 14.1390265, 122.7633036),
(3163, 174, 'CAS', 'Camarines Sur', '南卡馬林', '南卡马林', 13.5250197, 123.3486147),
(3164, 174, 'CAM', 'Camiguin', '甘米銀', '甘米银', 9.1732164, 124.7298765),
(3165, 174, 'CAP', 'Capiz', '卡皮茲', '卡皮斯', 11.5528816, 122.7407230),
(3166, 174, '13', 'Caraga', '卡拉加', '卡拉加', 8.8014562, 125.7406882),
(3167, 174, 'CAT', 'Catanduanes', '卡坦杜內斯', '卡坦杜内斯', 13.7088684, 124.2421597),
(3168, 174, 'CAV', 'Cavite', '甲米地', '甲米地', 14.4791297, 120.8969634),
(3169, 174, 'CEB', 'Cebu', '宿霧', '宿务', 10.3156992, 123.8854366),
(3170, 174, '03', 'Central Luzon', '呂宋島中部', '吕宋岛中部', 15.4827722, 120.7120023),
(3171, 174, '07', 'Central Visayas', '中米沙鄢群島', '中米沙鄢群岛', 9.8168750, 124.0641419),
(3172, 174, '15', 'Cordillera Administrative', '科迪勒拉行政區', '科迪勒拉行政区', 17.3512542, 121.1718851),
(3173, 174, 'NCO', 'Cotabato', '哥打巴托', '哥打巴托', 7.2046668, 124.2310439),
(3174, 174, '11', 'Davao', '達沃', '达沃', 7.3041622, 126.0893406),
(3175, 174, 'COM', 'Davao de Oro', '達沃德奧羅', '达沃德奥罗', 7.5125150, 126.1762615),
(3176, 174, 'DAV', 'Davao del Norte', '北達沃', '北达沃', 7.5617699, 125.6532848),
(3177, 174, 'DAS', 'Davao del Sur', '南達沃', '南达沃', 6.7662687, 125.3284269),
(3178, 174, 'DVO', 'Davao Occidental', '西達沃', '西达沃', 6.0941396, 125.6095474),
(3179, 174, 'DAO', 'Davao Oriental', '東方達沃酒店', '东方达沃', 7.3171585, 126.5419887),
(3180, 174, 'DIN', 'Dinagat Islands', '迪納加特群島', '迪纳加特群岛', 10.1281816, 125.6095474),
(3181, 174, 'EAS', 'Eastern Samar', '東薩馬島', '东萨马岛', 11.5000731, 125.4999908),
(3182, 174, '08', 'Eastern Visayas', '東米沙鄢群島', '东米沙鄢群岛', 12.2445533, 125.0388164),
(3183, 174, 'GUI', 'Guimaras', '吉馬拉斯', '吉马拉斯', 10.5928661, 122.6325081),
(3184, 174, 'IFU', 'Ifugao', '伊富高', '伊富高', 16.8330792, 121.1710389),
(3185, 174, '01', 'Ilocos', '伊羅戈', '伊罗戈', 16.0832144, 120.6199895),
(3186, 174, 'ILN', 'Ilocos Norte', '北伊羅戈', '北伊罗戈', 18.1647281, 120.7115592),
(3187, 174, 'ILS', 'Ilocos Sur', '伊羅戈', '伊罗戈', 17.2278664, 120.5739579),
(3188, 174, 'ILI', 'Iloilo', '伊洛伊洛', '伊洛伊洛', 10.7201501, 122.5621063),
(3189, 174, 'ISA', 'Isabela', '伊莎貝拉', '伊莎贝拉', 18.5007759, -67.0243462),
(3190, 174, 'KAL', 'Kalinga', '卡林加', '卡林加', 17.4740422, 121.3541631),
(3191, 174, 'LUN', 'La Union', '工會', '联盟', 38.8766878, -77.1280912),
(3192, 174, 'LAG', 'Laguna', '拉古納', '拉古纳', 33.5427189, -117.7853568),
(3193, 174, 'LAN', 'Lanao del Norte', '北拉瑙島', '北拉瑙岛', 7.8721811, 123.8857747),
(3194, 174, 'LAS', 'Lanao del Sur', '南拉瑙島', '南拉瑙岛', 7.8231760, 124.4198243),
(3195, 174, 'LEY', 'Leyte', '萊特島', '莱特岛', 10.8624536, 124.8811195),
(3196, 174, 'MGN', 'Maguindanao del Norte', '北馬京達瑙', '北马京达瑙', 6.9422581, 124.4198243),
(3197, 174, 'MGS', 'Maguindanao del Sur', '南馬京達瑙', '南马京达瑙', 14.6090537, 121.0222565),
(3198, 174, 'MAD', 'Marinduque', '馬林杜克', '马林杜克', 13.4767171, 121.9032192),
(3199, 174, 'MAS', 'Masbate', '馬斯巴特', '马斯巴特', 12.3574346, 123.5504076),
(3200, 174, '41', 'Mimaropa', '米瑪羅帕', '米马罗帕', 9.8432065, 118.7364783),
(3201, 174, 'MSC', 'Misamis Occidental', '西米薩米斯', 'Misamis Occidental', 8.3374903, 123.7070619),
(3202, 174, 'MSR', 'Misamis Oriental', '東方米薩米斯', '东方米萨米斯', 8.5045558, 124.6219592),
(3203, 174, 'MOU', 'Mountain Province', '山區省份', '山区省', 40.7075437, -73.9501033),
(3204, 174, '00', 'National Capital Region (Metro Manila)', '國家首都地區（馬尼拉大都會）', '国家首都地区（马尼拉大都会）', 14.5680707, 120.8558327),
(3205, 174, 'NEC', 'Negros Occidental', '西內格羅斯', '西内格罗斯', 10.2925609, 123.0246518),
(3206, 174, 'NER', 'Negros Oriental', '東內格羅斯', '东内格罗斯', 9.6282083, 122.9888319),
(3207, 174, '10', 'Northern Mindanao', '北棉蘭老島', '北棉兰老岛', 8.0201635, 124.6856509),
(3208, 174, 'NSA', 'Northern Samar', '北薩馬島', '北萨马岛', 12.3613199, 124.7740793),
(3209, 174, 'NUE', 'Nueva Ecija', '新埃西哈', '新埃西哈', 15.5783750, 121.1112615),
(3210, 174, 'NUV', 'Nueva Vizcaya', '新比斯開', '新比斯开', 16.3301107, 121.1710389),
(3211, 174, 'MDC', 'Occidental Mindoro', '西民都洛島', '西民都洛岛', 13.1024111, 120.7651284),
(3212, 174, 'MDR', 'Oriental Mindoro', '東民都洛島', '东民都洛岛', 13.0564598, 121.4069417),
(3213, 174, 'PLW', 'Palawan', '巴拉望島', '巴拉望岛', 9.8349493, 118.7383615),
(3214, 174, 'PAM', 'Pampanga', '邦板牙省', '邦板牙省', 15.0794090, 120.6199895),
(3215, 174, 'PAN', 'Pangasinan', '邦阿西南', '邦阿西南', 15.8949055, 120.2863183),
(3216, 174, 'QUE', 'Quezon', '奎松', '奎松', 14.0313906, 122.1130909),
(3217, 174, 'QUI', 'Quirino', '基里諾', '基里诺', 16.2700424, 121.5370003),
(3218, 174, 'RIZ', 'Rizal', '黎剎', '黎刹', 14.6037446, 121.3084088),
(3219, 174, 'ROM', 'Romblon', '隆布隆', '隆布隆', 12.5778016, 122.2691460),
(3220, 174, 'SAR', 'Sarangani', '薩蘭加尼', '萨兰加尼', 5.9267175, 124.9947510),
(3221, 174, 'SIG', 'Siquijor', '錫基霍爾', '锡基霍尔', 9.1998779, 123.5951925),
(3222, 174, '12', 'Soccsksargen', 'Soccsksargen', 'Soccsksargen', 6.2706918, 124.6856509),
(3223, 174, 'SOR', 'Sorsogon', '索索貢', '索索贡', 12.9927095, 124.0147464),
(3224, 174, 'SCO', 'South Cotabato', '南哥打巴托', '南哥打巴托', 6.3357565, 124.7740793),
(3225, 174, 'SLE', 'Southern Leyte', '南萊特島', '南莱特岛', 10.3346206, 125.1708741),
(3226, 174, 'SUK', 'Sultan Kudarat', '蘇丹庫達拉特', '苏丹库达拉特', 6.5069401, 124.4198243),
(3227, 174, 'SLU', 'Sulu', '蘇祿', '苏鲁', 5.9749011, 121.0335100),
(3228, 174, 'SUN', 'Surigao del Norte', '北蘇里高', '北苏里高', 9.5148280, 125.6969984),
(3229, 174, 'SUR', 'Surigao del Sur', '南蘇里高', '南苏里高', 8.5404906, 126.1144758),
(3230, 174, 'TAR', 'Tarlac', '打拉', '打拉', 15.4754786, 120.5963492),
(3231, 174, 'TAW', 'Tawi-Tawi', '塔威塔威', '塔威-塔威', 5.1338110, 119.9509260),
(3232, 174, 'WSA', 'Western Samar', '西薩馬島', '西萨马岛', 12.0000206, 124.9912452),
(3233, 174, '06', 'Western Visayas', '西米沙鄢群島', '西米沙鄢群岛', 11.0049836, 122.5372741),
(3234, 174, 'ZMB', 'Zambales', '三描禮士', '三描礼士', 15.5081766, 119.9697808),
(3235, 174, 'ZAN', 'Zamboanga del Norte', '北三寶顏', '北三宝颜', 8.3886282, 123.1688883),
(3236, 174, 'ZAS', 'Zamboanga del Sur', '南三寶顏', '南三宝颜', 7.8383054, 123.2966657),
(3237, 174, '09', 'Zamboanga Peninsula', '三寶顏半島', '三宝颜半岛', 8.1540770, 123.2587930),
(3238, 174, 'ZSI', 'Zamboanga Sibugay', '三寶顏錫布蓋', '三宝颜锡布盖', 7.5225247, 122.3107517),
(3239, 176, '30', 'Greater Poland', '蘭', '兰', 52.2799860, 17.3522939),
(3240, 176, '26', 'Holy Cross', '聖十字', '圣十字', 50.6261041, 20.9406279),
(3241, 176, '04', 'Kuyavia-Pomerania', '庫亞維亞-波美拉尼亞', '库亚维亚-波美拉尼亚', 53.1648363, 18.4834224),
(3242, 176, '12', 'Lesser Poland', '小波蘭', '小波兰', 49.7225306, 20.2503358),
(3243, 176, '02', 'Lower Silesia', '下西里西亞', '下西里西亚', 51.1339861, 16.8841961),
(3244, 176, '06', 'Lublin', '盧布林', '卢布林', 51.2493519, 23.1011392),
(3245, 176, '08', 'Lubusz', '盧布斯', '卢布什', 52.2274612, 15.2559103),
(3246, 176, '10', 'Łódź', '船', '船', 51.4634771, 19.1726974),
(3247, 176, '14', 'Mazovia', '馬佐維亞', '马佐维亚', 51.8927182, 21.0021679),
(3248, 176, '20', 'Podlaskie', '波德拉斯基省', 'Podlaskie Voivodeship', 53.0697159, 22.9674639),
(3249, 176, '22', 'Pomerania', '波美拉尼亞', '博美拉尼亚', 54.2944252, 18.1531164),
(3250, 176, '24', 'Silesia', '西里西亞', '西里西亚', 50.5716595, 19.3219768),
(3251, 176, '18', 'Subcarpathia', '喀爾巴阡下', '喀尔巴阡下', 50.0574749, 22.0895691),
(3252, 176, '16', 'Upper Silesia', '上西里西亞', '上西里西亚', 50.8003761, 17.9379890),
(3253, 176, '28', 'Warmia-Masuria', '瓦爾米亞-馬祖里', '瓦尔米亚-马祖里', 53.8671117, 20.7027861),
(3254, 176, '32', 'West Pomerania', '西波美拉尼亞', '西波美拉尼亚', 53.4657891, 15.1822581),
(3255, 177, '20', 'Açores', '亞速爾群島', '亚述尔群岛', 37.7412488, -25.6755944),
(3256, 177, '01', 'Aveiro', '阿威羅', '阿威罗', 40.7209023, -8.5721016),
(3257, 177, '02', 'Beja', '貝賈', '贝扎语', 37.9687786, -7.8721600),
(3258, 177, '03', 'Braga', '布拉加', '布拉加', 41.5503880, -8.4261301),
(3259, 177, '04', 'Bragança', '布拉幹薩', '布拉干萨', 41.8061652, -6.7567427),
(3260, 177, '05', 'Castelo Branco', '布蘭科堡', 'Castelo Branco', 39.8631323, -7.4814163),
(3261, 177, '06', 'Coimbra', '科英布拉', '科英布拉', 40.2057994, -8.4136900),
(3262, 177, '07', 'Évora', '埃武拉', '埃武拉', 38.5744468, -7.9076553),
(3263, 177, '08', 'Faro', '燈塔', '灯塔', 37.0193548, -7.9304397),
(3264, 177, '09', 'Guarda', '守', '警卫', 40.5385972, -7.2675772),
(3265, 177, '10', 'Leiria', '萊里亞', '莱里亚', 39.7709532, -8.7921836),
(3266, 177, '11', 'Lisbon', '里斯本', '里斯本', 38.7223263, -9.1392714),
(3267, 177, '30', 'Madeira', '木', '木', 32.7607074, -16.9594723),
(3268, 177, '12', 'Portalegre', 'Portalegre', 'Portalegre', 39.2967086, -7.4284755),
(3269, 177, '13', 'Porto', '港', '港', 41.1476629, -8.6078973),
(3270, 177, '14', 'Santarém', '聖塔倫', '圣塔伦', 39.2366687, -8.6859944),
(3271, 177, '15', 'Setúbal', '塞圖巴爾', '塞图巴尔', 38.5240933, -8.8925876),
(3272, 177, '16', 'Viana do Castelo', '維亞納堡', '维亚纳堡', 41.6918046, -8.8344510),
(3273, 177, '17', 'Vila Real', '維拉雷亞爾', '维拉雷亚尔', 41.3003527, -7.7457274),
(3274, 177, '18', 'Viseu', '維塞烏', '维塞乌', 40.6588424, -7.9147560),
(3275, 178, '001', 'Adjuntas', '附上', '附加', 18.1634848, -66.7231580),
(3276, 178, '003', 'Aguada', '阿瓜達', '阿瓜达', 18.3801579, -67.1887040),
(3277, 178, '005', 'Aguadilla', '阿瓜迪拉', '阿瓜迪亚', 18.4274454, -67.1540698),
(3278, 178, '007', 'Aguas Buenas', '好水', '好水', 18.2568989, -66.1029442),
(3279, 178, '009', 'Aibonito', '艾波尼托', '爱鲛人', 18.1399594, -66.2660016),
(3280, 178, '011', 'Añasco', '阿納斯科', '阿纳斯科', 18.2854476, -67.1402935),
(3281, 178, '013', 'Arecibo', '阿雷西博', '阿雷西博', 18.4705137, -66.7218472),
(3282, 178, 'AR', 'Arecibo', '阿雷西博', '阿雷西博', 18.4705556, -66.7208333),
(3283, 178, '015', 'Arroyo', '涓', '小溪', 17.9964220, -66.0924879),
(3284, 178, '017', 'Barceloneta', '巴塞羅那', '巴塞罗那', 41.3801061, 2.1896957),
(3285, 178, '019', 'Barranquitas', '巴蘭基塔斯', '巴兰基塔斯', 18.1866242, -66.3062802),
(3286, 178, 'BY', 'Bayamon', '松鼠', '松鼠', 18.1777778, -66.1133333),
(3287, 178, '021', 'Bayamón', '巴亞蒙', '巴亚蒙', 18.3893960, -66.1653224),
(3288, 178, '023', 'Cabo Rojo', '卡波羅霍', '卡波罗霍', 18.0866265, -67.1457347),
(3289, 178, 'CG', 'Caguas', '卡瓜斯', '卡瓜斯', 18.2333333, -66.0333333),
(3290, 178, '025', 'Caguas', '卡瓜斯', '卡瓜斯', 18.2387995, -66.0352490),
(3291, 178, '027', 'Camuy', '卡繆', '卡缪', 18.4838330, -66.8448994),
(3292, 178, '029', 'Canóvanas', '卡諾瓦納斯', '卡诺瓦纳斯', 18.3748748, -65.8997533),
(3293, 178, 'CL', 'Carolina', '卡羅萊納州', '卡罗莱纳州', 18.3888889, -65.9666667),
(3294, 178, '031', 'Carolina', '卡羅萊納州', '卡罗莱纳州', 18.3680877, -66.0424734),
(3295, 178, '033', 'Cataño', '卡塔尼奧', '卡塔尼奥', 18.4465355, -66.1355775),
(3296, 178, '035', 'Cayey', '凱伊', '凯伊', 18.1119051, -66.1660000),
(3297, 178, '037', 'Ceiba', '木棉', '木棉', 18.2475177, -65.9084953),
(3298, 178, '039', 'Ciales', '僚', '官员', 18.3360622, -66.4687823),
(3299, 178, '041', 'Cidra', '西德拉', '西德拉', 18.1757914, -66.1612779),
(3300, 178, '043', 'Coamo', '科阿莫', '科莫', 18.0799616, -66.3579473),
(3301, 178, '045', 'Comerío', 'Comerío', 'Comerío', 18.2192001, -66.2256022),
(3302, 178, '047', 'Corozal', '科羅薩爾', '科罗扎尔', 18.4030802, -88.3967536),
(3303, 178, '049', 'Culebra', '蛇', '蛇', 18.3103940, -65.3030705),
(3304, 178, '051', 'Dorado', '多拉多', '多拉多', 43.1480556, -77.5772222),
(3305, 178, '053', 'Fajardo', '法哈多', '法哈多', 18.3252148, -65.6539356),
(3306, 178, '054', 'Florida', '佛羅里達州', '佛罗里达州', 27.6648274, -81.5157535),
(3307, 178, '055', 'Guánica', '瓜尼卡', '瓜尼卡', 17.9725145, -66.9086264),
(3308, 178, '057', 'Guayama', '刮痧山', '刮痧', 17.9841328, -66.1137767),
(3309, 178, '059', 'Guayanilla', '瓜亞尼拉', '瓜亚尼拉', 18.0191314, -66.7918420),
(3310, 178, 'GN', 'Guaynabo', '瓜伊納博', '瓜伊纳博', 18.3666667, -66.1000000),
(3311, 178, '061', 'Guaynabo', '瓜伊納博', '瓜伊纳博', 18.3612954, -66.1102957),
(3312, 178, '063', 'Gurabo', '古拉博', '古拉博', 18.2543987, -65.9729421),
(3313, 178, '065', 'Hatillo', '哈蒂洛', '哈蒂略', 18.4284642, -66.7875321),
(3314, 178, '067', 'Hormigueros', '蟻丘', '蚁丘', 18.1334638, -67.1128123),
(3315, 178, '069', 'Humacao', '胡馬考', '胡马考', 18.1515736, -65.8248529),
(3316, 178, '071', 'Isabela', '伊莎貝拉', '伊莎贝拉', 16.9753758, 121.8107079),
(3317, 178, '073', 'Jayuya', '賈尤亞', '贾尤亚', 18.2185674, -66.5915617),
(3318, 178, '075', 'Juana Díaz', '胡安娜·迪亞斯', '胡安娜·迪亚斯', 18.0534372, -66.5075079),
(3319, 178, '077', 'Juncos', '蘆', '冲', 18.2274558, -65.9209970),
(3320, 178, '079', 'Lajas', '拉哈斯', '拉哈斯', 18.0499620, -67.0593449),
(3321, 178, '081', 'Lares', '首頁', '家庭', 34.0250802, -118.4594593),
(3322, 178, '083', 'Las Marías', '拉斯瑪麗亞斯', '拉斯玛丽亚斯', 35.8382238, -78.6103566),
(3323, 178, '085', 'Las Piedras', '滾石樂隊', '滚石乐队', 18.1855753, -65.8736245),
(3324, 178, '087', 'Loíza', '洛伊薩', '洛伊萨', 18.4329904, -65.8783600),
(3325, 178, '089', 'Luquillo', '盧基略', '卢基略', 18.3724507, -65.7165511),
(3326, 178, '091', 'Manatí', '海牛', '海牛', 18.4181215, -66.5262783),
(3327, 178, '093', 'Maricao', '馬里考', '马里考', 18.1807902, -66.9799001),
(3328, 178, '095', 'Maunabo', '莫納博', '莫纳博', 18.0071885, -65.8993289),
(3329, 178, 'MG', 'Mayagüez', '馬亞圭斯', '马亚圭斯', 18.2011111, -67.1397222),
(3330, 178, '097', 'Mayagüez', '馬亞圭斯', '马亚圭斯', 18.2013452, -67.1451549),
(3331, 178, '099', 'Moca', '摩卡', '摩卡', 18.3967929, -67.1479035),
(3332, 178, '101', 'Morovis', '莫羅維斯', '莫罗维斯', 18.3257850, -66.4065592),
(3333, 178, '103', 'Naguabo', '納瓜博', '纳瓜博', 18.2116247, -65.7348841),
(3334, 178, '105', 'Naranjito', '納蘭吉托', '纳兰吉托', 18.3007861, -66.2448904),
(3335, 178, '107', 'Orocovis', '奧羅科維斯', '奥罗科维斯', 18.2269224, -66.3911686),
(3336, 178, '109', 'Patillas', '鬢角', '连鬓胡子', 18.0037381, -66.0134059),
(3337, 178, '111', 'Peñuelas', '佩努埃拉斯', '佩努埃拉斯', 18.0633577, -66.7273896),
(3338, 178, 'PO', 'Ponce', '龐塞', '庞塞', 18.0000000, -66.6166667),
(3339, 178, '113', 'Ponce', '龐塞', '庞塞', 18.0110768, -66.6140616),
(3340, 178, '115', 'Quebradillas', '奎布拉迪拉斯', '奎布拉迪拉斯', 18.4738330, -66.9385120),
(3341, 178, '117', 'Rincón', '角', '角落', 18.3401514, -67.2499459),
(3342, 178, '119', 'Río Grande', '里奧格蘭德', '里奥格兰德', 28.8106383, -101.8353878),
(3343, 178, '121', 'Sabana Grande', '薩巴納格蘭德', '萨巴纳格兰德', 18.0777392, -66.9604549),
(3344, 178, '123', 'Salinas', '薩利納斯', '萨利纳斯', 36.6777372, -121.6555013),
(3345, 178, '125', 'San Germán', '聖日耳曼', '圣日耳曼', 18.0807082, -67.0411096),
(3346, 178, '127', 'San Juan', '聖胡安', '圣胡安', 18.4632030, -66.1147571),
(3347, 178, 'SJ', 'San Juan', '聖胡安', '圣胡安', 18.4500000, -66.0666667),
(3348, 178, '129', 'San Lorenzo', '聖洛倫索', '圣洛伦索', 18.1886912, -65.9765862),
(3349, 178, '131', 'San Sebastián', '聖塞巴斯蒂安', '圣塞巴斯蒂安', 43.3183340, -1.9812313),
(3350, 178, '133', 'Santa Isabel', '聖伊麗莎白', '圣伊丽莎白', 17.9660775, -66.4048920),
(3351, 178, '135', 'Toa Alta', '托阿阿爾塔', '大阿阿尔塔', 18.3882823, -66.2482237),
(3352, 178, 'TB', 'Toa Baja', '大東巴哈', '托阿巴哈', 18.4438890, -66.2597220),
(3353, 178, '137', 'Toa Baja', '大東巴哈', '托阿巴哈', 18.4444709, -66.2543293),
(3354, 178, 'TA', 'Trujillo Alto', '特魯希略上音', '特鲁希略上音', 18.3627780, -66.0175000),
(3355, 178, '139', 'Trujillo Alto', '特魯希略上音', '特鲁希略上音', 18.3546719, -66.0073876),
(3356, 178, '141', 'Utuado', '使用者', '用户', 18.2655095, -66.7004519),
(3357, 178, '143', 'Vega Alta', '維加阿爾塔', '维加阿尔塔', 18.4121703, -66.3312805),
(3358, 178, '145', 'Vega Baja', '維加巴哈', '织女星', 18.4461459, -66.4041967),
(3359, 178, '147', 'Vieques', '別克斯島', '别克斯岛', 18.1262854, -65.4400985),
(3360, 178, '149', 'Villalba', '維拉爾巴', '维拉尔巴', 18.1217554, -66.4985787),
(3361, 178, '151', 'Yabucoa', '亞布科亞', '亚布科亚', 18.0505201, -65.8793288),
(3362, 178, '153', 'Yauco', '尤科', '尤科', 18.0349640, -66.8498983),
(3363, 179, 'ZA', 'Al Daayen', '阿爾達延', '阿尔达延', 25.5784559, 51.4821387),
(3364, 179, 'KH', 'Al Khor', '阿爾霍爾', '阿尔霍尔', 25.6804078, 51.4968502),
(3365, 179, 'RA', 'Al Rayyan', '阿爾·雷揚', '阿尔·雷扬', 25.2522551, 51.4388713),
(3366, 179, 'WA', 'Al Wakrah', '瓦克拉', '瓦克拉', 25.1659314, 51.5975524),
(3367, 179, 'SH', 'Al-Shahaniya', '沙哈尼亞', '沙哈尼亚', 25.4106386, 51.1846025),
(3368, 179, 'DA', 'Doha', '多哈', '多哈', 25.2854473, 51.5310398),
(3369, 179, 'MS', 'Madinat ash Shamal', '麥地那灰沙馬爾', '古堡灰沙马尔', 26.1182743, 51.2157265),
(3370, 179, 'US', 'Umm Salal', '烏姆薩拉爾', '乌姆萨拉尔', 25.4875242, 51.3965680),
(3371, 180, '01', 'Saint-Benoît', '聖伯努瓦', '圣伯努瓦', -21.0810029, 55.3105289),
(3372, 180, '02', 'Saint-Denis', '聖但尼', '圣但尼', -20.9433470, 55.3462838),
(3373, 180, '03', 'Saint-Paul', '聖保羅', '圣保罗', -21.0724989, 55.1758458),
(3374, 180, '04', 'Saint-Pierre', '聖皮埃爾', '圣皮埃尔', -21.2373113, 55.2349598),
(3375, 181, 'AB', 'Alba', '旦', '黎明', 44.7009153, 8.0356911),
(3376, 181, 'AR', 'Arad', '阿拉德', '阿拉德', 46.2283651, 21.6597819),
(3377, 181, 'AG', 'Arges', '阿爾吉斯', '阿尔吉斯', 45.0722527, 24.8142726),
(3378, 181, 'BC', 'Bacău', '巴卡烏', '巴卡乌', 46.3258184, 26.6623780),
(3379, 181, 'BH', 'Bihor', '比霍爾', '比霍尔', 47.0157516, 22.1722660),
(3380, 181, 'BN', 'Bistrița-Năsăud', 'Bistrița-Năsăud', '比斯特里察-纳萨乌德', 47.2486107, 24.5322814),
(3381, 181, 'BT', 'Botoșani', '博托薩尼', '博托萨尼', 47.8924042, 26.7591781),
(3382, 181, 'BR', 'Braila', '布萊拉', '布莱拉', 45.2652463, 27.9594714),
(3383, 181, 'BV', 'Brașov', '布拉索夫', '布拉索夫', 45.7781844, 25.2225800),
(3384, 181, 'B', 'Bucharest', '布加勒斯特', '布加勒斯特', 44.4267674, 26.1025384),
(3385, 181, 'BZ', 'Buzău', '布扎烏', '布扎乌', 45.3350912, 26.7107578),
(3386, 181, 'CL', 'Călărași', '卡拉拉西', '卡拉拉西', 44.3658715, 26.7548607),
(3387, 181, 'CS', 'Caraș-Severin', '卡拉什-塞維林', '卡拉什-塞维林', 45.1139646, 22.0740993),
(3388, 181, 'CJ', 'Cluj', '克盧日', '克卢日', 46.7941797, 23.6121492),
(3389, 181, 'CT', 'Constanța', '康斯坦察', '康斯坦察', 44.2129870, 28.2550055),
(3390, 181, 'CV', 'Covasna', '科瓦斯納', '科瓦斯纳', 45.9426347, 25.8918984),
(3391, 181, 'DB', 'Dâmbovița', '丹博維察', '丹博维察', 44.9289893, 25.4253850),
(3392, 181, 'DJ', 'Dolj', '多爾吉', '多尔吉', 44.1623022, 23.6325054),
(3393, 181, 'GL', 'Galați', '加拉蒂', '加拉蒂', 45.7800569, 27.8251576),
(3394, 181, 'GR', 'Giurgiu', '朱爾吉烏', '朱尔久', 43.9037076, 25.9699265),
(3395, 181, 'GJ', 'Gorj', '戈爾吉', '戈尔吉', 44.9485595, 23.2427079),
(3396, 181, 'HR', 'Harghita', '哈吉塔', '哈吉塔', 46.4928507, 25.6456696),
(3397, 181, 'HD', 'Hunedoara', '胡內多阿拉', '胡内多阿拉', 45.7936380, 22.9975993),
(3398, 181, 'IL', 'Ialomița', '亞洛米塔', '伊亚洛米塔', 44.6031330, 27.3789914),
(3399, 181, 'IS', 'Iași', '雅西', '雅西', 47.2679653, 27.2185662),
(3400, 181, 'IF', 'Ilfov', '伊爾福夫', '伊尔福夫', 44.5355480, 26.2324886),
(3401, 181, 'MM', 'Maramureș', '馬拉穆雷什', '马拉穆雷什', 46.5569904, 24.6723215),
(3402, 181, 'MH', 'Mehedinți', '梅赫丁蒂', '梅赫丁蒂', 44.5515053, 22.9044157),
(3403, 181, 'MS', 'Mureș', '穆雷什', '穆雷什', 46.5569904, 24.6723215),
(3404, 181, 'NT', 'Neamț', '德國人', '德语', 46.9758685, 26.3818764),
(3405, 181, 'OT', 'Olt', '奧爾特', '奥尔特', 44.2007970, 24.5022981),
(3406, 181, 'PH', 'Prahova', '普拉霍瓦', '普拉霍瓦', 45.0891906, 26.0829313),
(3407, 181, 'SJ', 'Sălaj', '薩拉吉', 'Sălaj', 47.2090813, 23.2121901),
(3408, 181, 'SM', 'Satu Mare', '薩圖馬雷', 'Satu Mare', 47.7668905, 22.9241377),
(3409, 181, 'SB', 'Sibiu', '錫比烏', '锡比乌', 45.9269106, 24.2254807),
(3410, 181, 'SV', 'Suceava', '蘇恰瓦', '苏恰瓦', 47.5505548, 25.7410620),
(3411, 181, 'TR', 'Teleorman', '特萊奧曼', '特勒奥曼', 44.0160491, 25.2986628),
(3412, 181, 'TM', 'Timiș', '蒂米什', '蒂米什', 45.8138902, 21.3331055),
(3413, 181, 'TL', 'Tulcea', '圖爾恰', '图尔恰', 45.0450565, 29.0324912),
(3414, 181, 'VL', 'Vâlcea', '瓦爾西亞', '瓦尔西亚', 45.0798051, 24.0835283),
(3415, 181, 'VS', 'Vaslui', '瓦斯魯伊', '瓦斯鲁伊', 46.4631059, 27.7398031),
(3416, 181, 'VN', 'Vrancea', '弗蘭西亞', '弗兰西亚', 45.8134876, 27.0657531),
(3417, 182, 'AD', 'Adygea', '阿迪格', '阿迪格', 44.8229155, 40.1754463),
(3418, 182, 'ALT', 'Altai', '阿爾泰', '阿尔泰语', 51.7936298, 82.6758596),
(3419, 182, 'AL', 'Altai', '阿爾泰', '阿尔泰语', 50.6181924, 86.2199308),
(3420, 182, 'AMU', 'Amur', '阿穆爾', '阿穆尔', 54.6035065, 127.4801721),
(3421, 182, 'ARK', 'Arkhangelsk', '阿爾漢格爾斯克', '阿尔汉格尔斯克', 64.5458549, 40.5505769),
(3422, 182, 'AST', 'Astrakhan', '阿斯特拉罕', '阿斯特拉罕', 46.1321166, 48.0610115),
(3423, 182, 'BA', 'Bashkortostan', '巴什科爾托斯坦', '巴什科尔托斯坦', 54.2312172, 56.1645257),
(3424, 182, 'BEL', 'Belgorod', '別爾哥羅德', '别尔哥罗德', 50.7106926, 37.7533377),
(3425, 182, 'BRY', 'Bryansk', '布良斯克', '布良斯克', 53.0408599, 33.2690900),
(3426, 182, 'BU', 'Buryatia', '布里亞特', '布里亚特', 54.8331146, 112.4060530),
(3427, 182, 'CE', 'Chechen', '車臣', '车臣语', 43.4023301, 45.7187468),
(3428, 182, 'CHE', 'Chelyabinsk', '車里雅賓斯克', '车里雅宾斯克', 54.4319422, 60.8788963),
(3429, 182, 'CHU', 'Chukotka', '楚科奇', '楚科奇', 65.6298355, 171.6952159),
(3430, 182, 'CU', 'Chuvash', '楚瓦什語', '楚瓦什语', 55.5595992, 46.9283535),
(3431, 182, 'DA', 'Dagestan', '達吉斯坦', '达吉斯坦', 42.1431886, 47.0949799),
(3432, 182, 'IN', 'Ingushetia', '印古什', '印古什', 43.4051698, 44.8202999),
(3433, 182, 'IRK', 'Irkutsk', '伊爾庫茨克', '伊尔库茨克', 52.2854834, 104.2890222),
(3434, 182, 'IVA', 'Ivanovo', '伊万諾沃', '伊万诺沃', 57.1056854, 41.4830084),
(3435, 182, 'YEV', 'Jewish', '猶太人', '犹太的', 48.4808147, 131.7657367),
(3436, 182, 'KB', 'Kabardino-Balkar', '卡巴爾達-巴爾卡爾', '卡巴尔达-巴尔卡', 43.3932469, 43.5628498),
(3437, 182, 'KGD', 'Kaliningrad', '加里寧格勒', '加里宁格勒', 54.7104264, 20.4522144),
(3438, 182, 'KL', 'Kalmykia', '卡爾梅克', '卡尔梅克', 46.1867176, 45.0000000),
(3439, 182, 'KLU', 'Kaluga', '卡盧加', '卡卢加', 54.3872666, 35.1889094),
(3440, 182, 'KAM', 'Kamchatka', '堪察加半島', '堪察加', 61.4343981, 166.7884131),
(3441, 182, 'KC', 'Karachay-Cherkess', '卡拉恰伊-切爾克斯', '卡拉恰伊-切尔克斯', 43.8845143, 41.7303939),
(3442, 182, 'KR', 'Karelia', '卡累利阿', '卡累利阿', 63.1558702, 32.9905552),
(3443, 182, 'KEM', 'Kemerovo', '克麥羅沃', '克麦罗沃', 54.7574648, 87.4055288),
(3444, 182, 'KHA', 'Khabarovsk', '哈巴羅夫斯克', '哈巴罗夫斯克', 50.5888431, 135.0000000),
(3445, 182, 'KK', 'Khakassia', '哈卡斯', '哈卡斯', 53.0452281, 90.3982145),
(3446, 182, 'KHM', 'Khanty-Mansi', '漢特曼西', '汉特-曼西', 62.2287062, 70.6410057),
(3447, 182, 'KIR', 'Kirov', '基洛夫', '基洛夫', 58.4198529, 50.2097248),
(3448, 182, 'KO', 'Komi', '科米', '科米', 63.8630539, 54.8312690),
(3449, 182, 'KOS', 'Kostroma', '科斯特羅馬', '科斯特罗马', 58.5501069, 43.9541102),
(3450, 182, 'KDA', 'Krasnodar', '克拉斯諾達爾', '克拉斯诺达尔', 45.6415289, 39.7055977),
(3451, 182, 'KYA', 'Krasnoyarsk', '克拉斯諾亞爾斯克', '克拉斯诺亚尔斯克', 64.2479758, 95.1104176),
(3452, 182, 'KGN', 'Kurgan', '庫爾幹', '库尔干', 55.4481548, 65.1180975),
(3453, 182, 'KRS', 'Kursk', '庫爾斯克', '库尔斯克', 51.7634026, 35.3811812),
(3454, 182, 'LEN', 'Leningrad', '列寧格勒', '列宁格勒', 60.0793208, 31.8926645),
(3455, 182, 'LIP', 'Lipetsk', '利佩茨克', '利佩茨克', 52.5264702, 39.2032269),
(3456, 182, 'MAG', 'Magadan', '馬加丹', '马加丹', 62.6643417, 153.9149910),
(3457, 182, 'ME', 'Mari El', '馬里·埃爾', '玛丽·埃尔', 56.4384570, 47.9607758),
(3458, 182, 'MO', 'Mordovia', '莫爾多維亞', '莫尔多维亚', 54.2369441, 44.0683970),
(3459, 182, 'MOS', 'Moscow', '莫斯科', '莫斯科', 55.3403960, 38.2917651),
(3460, 182, 'MOW', 'Moscow', '莫斯科', '莫斯科', 55.7558260, 37.6172999),
(3461, 182, 'MUR', 'Murmansk', '摩爾曼斯克', '摩尔曼斯克', 67.8442674, 35.0884102),
(3462, 182, 'NEN', 'Nenets', '涅涅茨', '涅涅茨', 67.6078337, 57.6338331),
(3463, 182, 'NIZ', 'Nizhny Novgorod', '下諾夫哥羅德', '下诺夫哥罗德', 55.7995159, 44.0296769),
(3464, 182, 'SE', 'North Ossetia-Alania', '北奧塞梯-阿拉尼亞', '北奥塞梯-阿拉尼亚', 43.0451302, 44.2870972),
(3465, 182, 'NGR', 'Novgorod', '諾夫哥羅德', '诺夫哥罗德', 58.2427552, 32.5665190),
(3466, 182, 'NVS', 'Novosibirsk', '新西伯利亞', '新西伯利亚', 54.9832693, 82.8963831),
(3467, 182, 'OMS', 'Omsk', '鄂木斯克', '鄂木斯克', 55.0554669, 73.3167342),
(3468, 182, 'ORE', 'Orenburg', '奧倫堡', '奥伦堡', 51.7634026, 54.6188188),
(3469, 182, 'ORL', 'Oryol', '奧廖爾', '奥廖尔', 52.7856414, 36.9242344),
(3470, 182, 'PNZ', 'Penza', '奔薩', '奔萨', 53.1412105, 44.0940048),
(3471, 182, 'PER', 'Perm', '燙髮', '烫发', 58.8231929, 56.5872481),
(3472, 182, 'PRI', 'Primorsky', '濱海邊疆區', '滨海边疆区', 45.0525641, 135.0000000),
(3473, 182, 'PSK', 'Pskov', '普斯科夫', '普斯科夫', 56.7708599, 29.0940090),
(3474, 182, 'ROS', 'Rostov', '羅斯托夫', '罗斯托夫', 47.6853247, 41.8258952),
(3475, 182, 'RYA', 'Ryazan', '梁贊', '梁赞', 54.3875964, 41.2595661),
(3476, 182, 'SPE', 'Saint Petersburg', '聖彼得堡', '圣彼得堡', 59.9310584, 30.3609096),
(3477, 182, 'SA', 'Sakha', '薩哈', '雅库特语', 66.7613451, 124.1237530),
(3478, 182, 'SAK', 'Sakhalin', '庫頁島', '库页岛', 50.6909848, 142.9505689),
(3479, 182, 'SAM', 'Samara', '薩馬拉', '翅果', 53.4183839, 50.4725528),
(3480, 182, 'SAR', 'Saratov', '薩拉托夫', '萨拉托夫', 51.8369263, 46.7539397),
(3481, 182, 'SMO', 'Smolensk', '斯摩棱斯克', '斯摩棱斯克', 54.9882994, 32.6677378),
(3482, 182, 'STA', 'Stavropol', '斯塔夫羅波爾', '斯塔夫罗波尔', 44.6680993, 43.5202140),
(3483, 182, 'SVE', 'Sverdlovsk', '斯維爾德洛夫斯克', '斯维尔德洛夫斯克', 56.8430993, 60.6454086),
(3484, 182, 'TAM', 'Tambov', '坦波夫', '坦波夫', 52.6416589, 41.4216451),
(3485, 182, 'TA', 'Tatarstan', '韃靼斯坦', '鞑靼斯坦', 55.1802364, 50.7263945),
(3486, 182, 'TOM', 'Tomsk', '托木斯克', '托木斯克', 58.8969882, 82.6765500),
(3487, 182, 'TUL', 'Tula', '圖拉', '图拉', 54.1637680, 37.5649507),
(3488, 182, 'TY', 'Tuva', '圖瓦', '图瓦', 51.8872669, 95.6260172),
(3489, 182, 'TVE', 'Tver', '特維爾', '特维尔', 57.0021654, 33.9853142),
(3490, 182, 'TYU', 'Tyumen', '秋明', '秋明', 56.9634387, 66.9482780),
(3491, 182, 'UD', 'Udmurt', '烏德穆爾特語', '乌德穆尔特', 57.0670218, 53.0277948),
(3492, 182, 'ULY', 'Ulyanovsk', '烏里揚諾夫斯克', '乌里扬诺夫斯克', 53.9793357, 47.7762425),
(3493, 182, 'VLA', 'Vladimir', '弗拉基米爾', '弗拉基米尔', 56.1553465, 40.5926685),
(3494, 182, 'VGG', 'Volgograd Oblast', '伏爾加格勒州', 'Volgograd Oblast', 49.2587393, 39.8154463),
(3495, 182, 'VLG', 'Vologda', '沃洛格達', '沃洛格达', 59.8706711, 40.6555411),
(3496, 182, 'VOR', 'Voronezh', '沃羅涅日', '沃罗涅日', 50.8589713, 39.8644374),
(3497, 182, 'YAN', 'Yamalo-Nenets', '亞馬洛-涅涅茨', '亚马洛-涅涅茨', 66.0653057, 76.9345193),
(3498, 182, 'YAR', 'Yaroslavl', '雅羅斯拉夫爾', '雅罗斯拉夫尔', 57.8991523, 38.8388633),
(3499, 182, 'ZAB', 'Zabaykalsky', '扎拜卡爾斯基', '扎拜卡尔斯基', 53.0928771, 116.9676561),
(3500, 183, '02', 'Eastern', '東', '东部', -1.7424451, 29.7688698),
(3501, 183, '01', 'Kigali', '基加利', '基加利', -1.9297626, 29.9624332),
(3502, 183, '03', 'Northern', '北', '北方', -1.6108529, 29.5332066),
(3503, 183, '05', 'Southern', '南方的', '南部', -2.2855202, 29.3130756),
(3504, 183, '04', 'Western', '西方的', '西方', -2.1250057, 28.6090117),
(3505, 184, '01', 'Alarm Forest', '警報森林', '警报森林', -15.9467144, -5.7244752),
(3506, 184, '02', 'Blue Hill', '藍山', '蓝山', -15.9835472, -5.7965652),
(3507, 184, '03', 'Half Tree Hollow', '半樹谷', '半树谷', -15.9346845, -5.7313477),
(3508, 184, '04', 'Jamestown', '詹姆斯敦', '詹姆斯敦', -15.9288308, -5.7203338),
(3509, 184, '05', 'Levelwood', '萊夫伍德', '平木', -15.9747543, -5.7096080),
(3510, 184, '06', 'Longwood', '朗伍德', '朗伍德', -15.9445863, -5.6950272),
(3511, 184, '08', 'Saint Paul\'s', '聖保羅', '圣保罗', -15.9869581, -5.7809658),
(3512, 184, '07', 'Sandy Bay', '桑迪灣', '桑迪湾', -15.9918741, -5.7399151),
(3513, 185, '01', 'Christ Church Nichola Town', '尼古拉鎮基督教堂', '尼古拉镇基督教堂', 17.3604812, -62.7617837),
(3514, 185, 'N', 'Nevis', '尼維斯', '尼维斯', 17.1553558, -62.5796026),
(3515, 185, '02', 'Saint Anne Sandy Point', '聖安妮桑迪角', '圣安妮桑迪角', 17.3725333, -62.8441133),
(3516, 185, '03', 'Saint George Basseterre', '聖喬治巴斯特爾', '圣乔治·巴斯特尔', 17.2671011, -62.7693001),
(3517, 185, '04', 'Saint George Gingerland', '聖喬治金格蘭', '圣乔治姜乐园', 17.1257759, -62.5619811),
(3518, 185, '05', 'Saint James Windward', '聖詹姆斯迎風', '圣詹姆斯向风', 17.1769633, -62.5796026),
(3519, 185, '06', 'Saint John Capisterre', '聖約翰·卡皮斯特爾', '圣约翰·卡皮斯特尔', 17.3810341, -62.7911833),
(3520, 185, '07', 'Saint John Figtree', '聖約翰·菲格特里', '圣约翰·菲格特里', 17.1155748, -62.6031004),
(3521, 185, 'K', 'Saint Kitts', '聖基茨', '圣基茨', 17.3433796, -62.7559043),
(3522, 185, '08', 'Saint Mary Cayon', '聖瑪麗卡永', '圣玛丽卡永', 17.3462071, -62.7382671),
(3523, 185, '09', 'Saint Paul Capisterre', '聖保羅·卡皮斯特爾', '圣保罗卡皮斯特雷', 17.4016683, -62.8257332),
(3524, 185, '10', 'Saint Paul Charlestown', '聖保羅查爾斯敦', '圣保罗查尔斯敦', 17.1346297, -62.6133816),
(3525, 185, '11', 'Saint Peter Basseterre', '聖彼得·巴斯特爾', '圣彼得·巴斯特尔', 17.3102911, -62.7147533),
(3526, 185, '12', 'Saint Thomas Lowland', '聖托馬斯低地', '圣托马斯低地', 17.1650513, -62.6089753),
(3527, 185, '13', 'Saint Thomas Middle Island', '聖托馬斯中島', '圣托马斯中岛', 17.3348813, -62.8088251),
(3528, 185, '15', 'Trinity Palmetto Point', '三一棕櫚角', '三一棕榈角', 17.3063519, -62.7617837),
(3529, 186, '01', 'Anse la Raye', '安斯·拉·拉伊', '安斯·拉·拉耶', 13.9459424, -61.0369468),
(3530, 186, '12', 'Canaries', '加那利群島', '加那利群岛', 28.2915637, -16.6291304),
(3531, 186, '02', 'Castries', '卡斯特里', '卡斯特里', 14.0101094, -60.9874687),
(3532, 186, '03', 'Choiseul', '舒瓦瑟爾', '舒瓦瑟尔', 13.7750154, -61.0485910),
(3533, 186, '04', 'Dauphin', '海豚', '海豚', 14.0103396, -60.9190988),
(3534, 186, '05', 'Dennery', '丹納里', '丹纳里', 13.9267393, -60.9190988),
(3535, 186, '06', 'Gros Islet', '格羅斯島', '格罗斯岛', 14.0843578, -60.9452794),
(3536, 186, '07', 'Laborie', '拉伯利', '劳伯里', 13.7522783, -60.9932889),
(3537, 186, '08', 'Micoud', '米庫德', '米库德', 13.8211871, -60.9001934),
(3538, 186, '09', 'Praslin', '普拉蘭島', '普拉兰', 13.8752392, -60.8994663),
(3539, 186, '10', 'Soufrière', '蘇弗里埃', '苏弗里耶尔', 13.8570986, -61.0573248),
(3540, 186, '11', 'Vieux Fort', '古堡', '老堡', 13.7206080, -60.9496433),
(3541, 188, '01', 'Charlotte', '夏洛特', '夏 洛特', 13.2175451, -61.1636244),
(3542, 188, '06', 'Grenadines', '格林納丁斯', '格林纳丁斯', 13.0122965, -61.2277301),
(3543, 188, '02', 'Saint Andrew', '聖安德魯', '圣安德鲁', 43.0242999, -81.2025000),
(3544, 188, '03', 'Saint David', '聖大衛', '圣大卫', 43.8523095, -79.5236654),
(3545, 188, '04', 'Saint George', '聖喬治', '圣乔治', 42.9576090, -81.3267050),
(3546, 188, '05', 'Saint Patrick', '聖派翠克', '圣帕特里克', 39.7509186, -94.8450556),
(3547, 191, 'AA', 'A\'ana', '一個', '一个', -13.8984180, -171.9752995),
(3548, 191, 'AL', 'Aiga-i-le-Tai', '艾加勒泰', '艾加勒泰', -13.8513791, -172.0325401),
(3549, 191, 'AT', 'Atua', '使徒行傳', '行为', -13.9787053, -171.6254283),
(3550, 191, 'FA', 'Fa\'asaleleaga', '前', '前', -13.6307638, -172.2365981),
(3551, 191, 'GE', 'Gaga\'emauga', '嘎嘎', '狂热的', -13.5428666, -172.3668870),
(3552, 191, 'GI', 'Gaga\'ifomauga', '嘎嘎', '狂热的', -13.5468007, -172.4969331),
(3553, 191, 'PA', 'Palauli', '帕勞利', '帕劳利', -13.7294579, -172.4536115),
(3554, 191, 'SA', 'Satupa\'itea', '薩圖帕', '萨图帕', -13.6538214, -172.6159271),
(3555, 191, 'TU', 'Tuamasaga', '圖阿馬薩加', '图阿马萨加', -13.9163592, -171.8224362),
(3556, 191, 'VF', 'Va\'a-o-Fonoti', '瓦', '瓦', -13.9470903, -171.5431872),
(3557, 191, 'VS', 'Vaisigano', '維西加諾', '维西加诺', -13.5413827, -172.7023383),
(3558, 192, '01', 'Acquaviva', '阿奎維瓦', '阿夸维瓦', 41.8671597, 14.7469479),
(3559, 192, '06', 'Borgo Maggiore', '博爾戈·馬焦雷', '博尔戈·马焦雷', 43.9574882, 12.4552546),
(3560, 192, '02', 'Chiesanuova', '基耶薩諾娃', '基萨诺娃', 45.4226172, 7.6503854),
(3561, 192, '03', 'Domagnano', '多馬尼亞諾', '多马尼亚诺', 43.9501929, 12.4681537),
(3562, 192, '04', 'Faetano', '費塔諾', '法埃塔诺', 43.9348967, 12.4896554),
(3563, 192, '05', 'Fiorentino', '佛羅倫薩', '佛罗伦萨', 43.9078337, 12.4581209),
(3564, 192, '08', 'Montegiardino', '蒙特賈迪諾', '蒙特贾迪诺', 43.9052999, 12.4810542),
(3565, 192, '07', 'San Marino', '聖馬利諾', '圣马力诺', 43.9423600, 12.4577770),
(3566, 192, '09', 'Serravalle', '塞拉瓦萊', '塞拉瓦莱', 44.7232084, 8.8574005),
(3567, 193, 'P', 'Príncipe', '王子', '王子', 1.6139381, 7.4056928),
(3568, 193, 'S', 'São Tomé', '聖多美', '圣多美', 0.3301924, 6.7333430),
(3569, 194, '14', '\'Asir', '阿西爾', '阿西尔', 19.0969062, 42.8637875),
(3570, 194, '11', 'Al Bahah', '巴哈', '巴哈', 20.2722739, 41.4412510),
(3571, 194, '12', 'Al Jawf', '阿爾賈夫', '阿尔·贾夫', 29.8873560, 39.3206241),
(3572, 194, '03', 'Al Madinah', '麥地那', '麦地那', 24.8403977, 39.3206241);
INSERT INTO `location_states` (`state_id`, `country_id`, `state_code`, `state_name_en`, `state_name_zh_tw`, `state_name_zh_cn`, `state_center_latitude`, `state_center_longitude`) VALUES
(3573, 194, '05', 'Al-Qassim', '卡西姆', '卡西姆', 26.2078260, 43.4837380),
(3574, 194, '04', 'Eastern Province', '東部省', '东部省', 24.0439932, 45.6589225),
(3575, 194, '06', 'Ha\'il', '有', '有', 27.7076143, 41.9196471),
(3576, 194, '09', 'Jizan', '吉贊', '吉赞', 17.1738176, 42.7076107),
(3577, 194, '02', 'Makkah', '麥加', '麦加', 21.5235584, 41.9196471),
(3578, 194, '10', 'Najran', '奈季蘭', '奈季兰', 18.3514664, 45.6007108),
(3579, 194, '08', 'Northern Borders', '北部邊界', '北部边界', 30.0799162, 42.8637875),
(3580, 194, '01', 'Riyadh', '利雅得', '利雅得', 22.7554385, 46.2091547),
(3581, 194, '07', 'Tabuk', '忌諱', '禁忌', 28.2453335, 37.6386622),
(3582, 195, 'DK', 'Dakar', '達喀爾', '达喀尔', 14.7166770, -17.4676861),
(3583, 195, 'DB', 'Diourbel Region', '迪奧貝爾地區', '迪乌贝尔地区', 14.7283085, -16.2522143),
(3584, 195, 'FK', 'Fatick', '法蒂克', '法蒂克', 14.3390167, -16.4111425),
(3585, 195, 'KA', 'Kaffrine', '卡夫林', '卡夫林', 14.1052020, -15.5415755),
(3586, 195, 'KL', 'Kaolack', '考拉克', '考拉克', 14.1652083, -16.0757749),
(3587, 195, 'KE', 'Kédougou', '克杜溝', 'Kédougou', 12.5604607, -12.1747077),
(3588, 195, 'KD', 'Kolda', '科爾達', '科尔达', 12.9107495, -14.9505671),
(3589, 195, 'LG', 'Louga', '盧加', '卢加', 15.6141768, -16.2286800),
(3590, 195, 'MT', 'Matam', '殺', '杀', 15.6600225, -13.2576906),
(3591, 195, 'SL', 'Saint-Louis', '聖路易', '圣路易斯', 38.6270025, -90.1994042),
(3592, 195, 'SE', 'Sédhiou', '塞迪烏', '塞迪乌', 12.7046040, -15.5562304),
(3593, 195, 'TC', 'Tambacounda Region', '坦巴昆達地區', '坦巴昆达地区', 13.5619011, -13.1740348),
(3594, 195, 'TH', 'Thiès Region', '蒂耶斯地區', '蒂埃斯大区', 14.7910052, -16.9358604),
(3595, 195, 'ZG', 'Ziguinchor', '齊金喬爾', '齐金乔尔', 12.5641479, -16.2639825),
(3596, 196, '00', 'Belgrade', '貝爾格萊德', '贝尔格莱德', 44.7865680, 20.4489216),
(3597, 196, '14', 'Bor', '那里', '那里', 44.0698918, 22.0985086),
(3598, 196, '11', 'Braničevo', '布拉尼切沃', '布拉尼切沃', 44.6982246, 21.5446775),
(3599, 196, '02', 'Central Banat', '中央巴納特', '中央巴纳特', 45.4788485, 20.6082522),
(3600, 196, '23', 'Jablanica', '賈布拉尼卡', '贾布拉尼卡', 42.9481560, 21.8129321),
(3601, 196, '09', 'Kolubara', '科魯巴拉', '科鲁巴拉', 44.3509811, 20.0004305),
(3602, 196, '08', 'Mačva', 'Mačva', '马奇瓦', 44.5925314, 19.5082246),
(3603, 196, '17', 'Moravica', '莫拉維卡', '摩拉维卡', 43.8414700, 20.2904987),
(3604, 196, '20', 'Nišava', '尼沙瓦', '尼沙瓦', 43.3738902, 21.9322331),
(3605, 196, '01', 'North Bačka', '北巴奇卡', '北巴奇卡', 45.9803394, 19.5907001),
(3606, 196, '03', 'North Banat', '北巴納特', '北巴纳特', 45.9068390, 19.9993417),
(3607, 196, '24', 'Pčinja', 'Pčinja', 'Pčinja', 42.5836362, 22.1430215),
(3608, 196, '22', 'Pirot', '皮羅特', '皮罗特', 43.0874036, 22.5983044),
(3609, 196, '10', 'Podunavlje', 'Podunavlje', 'Podunavlje', 44.4729156, 20.9901426),
(3610, 196, '13', 'Pomoravlje', '波莫拉夫列', 'Pomoravlje', 43.9591379, 21.2713530),
(3611, 196, '19', 'Rasina', '拉西娜', '拉西娜', 43.5263525, 21.1588178),
(3612, 196, '18', 'Raška', '拉什卡', '拉什卡', 43.3373461, 20.5734005),
(3613, 196, '06', 'South Bačka', '南巴奇卡', '南巴奇卡', 45.4890344, 19.6976187),
(3614, 196, '04', 'South Banat', '南巴納特', '南巴纳特', 45.0027457, 21.0542509),
(3615, 196, '07', 'Srem', '斯雷姆', '斯雷姆', 45.0029171, 19.8013773),
(3616, 196, '12', 'Šumadija', '舒馬迪亞', '舒马迪亚', 44.2050678, 20.7856565),
(3617, 196, '21', 'Toplica', '托普利卡', '托普利卡', 43.1906592, 21.3407762),
(3618, 196, 'VO', 'Vojvodina', '伏伊伏丁那', '伏伊伏丁那', 45.2608651, 19.8319338),
(3619, 196, '05', 'West Bačka', '西巴奇卡', '西巴奇卡', 45.7355385, 19.1897364),
(3620, 196, '15', 'Zaječar', 'Zaječar', '扎耶查尔', 43.9015048, 22.2738011),
(3621, 196, '16', 'Zlatibor', '茲拉提博爾', '兹拉提博尔', 43.6454170, 19.7101455),
(3622, 197, '02', 'Anse Boileau', '安斯·布瓦洛', '安斯·布瓦洛', -4.7047268, 55.4859363),
(3623, 197, '05', 'Anse Royale', '皇家安斯', '皇家安斯', -4.7407988, 55.5081012),
(3624, 197, '01', 'Anse-aux-Pins', 'Anse-aux-Pins', 'Anse-aux-Pins', -4.6900443, 55.5150289),
(3625, 197, '04', 'Au Cap', '位於開普敦', '在开普敦', -4.7059723, 55.5081012),
(3626, 197, '06', 'Baie Lazare', '拉撒路灣', '拉撒路湾', -4.7482525, 55.4859363),
(3627, 197, '07', 'Baie Sainte Anne', '聖安妮灣', 'Baie Sainte Anne（圣安妮湾酒店）', 47.0525900, -64.9524579),
(3628, 197, '08', 'Beau Vallon', '美麗的山谷', '美丽的山谷', -4.6210967, 55.4277802),
(3629, 197, '09', 'Bel Air', '貝萊爾', '贝莱尔', 34.1002455, -118.4594630),
(3630, 197, '10', 'Bel Ombre', '貝爾漸變色', '贝尔渐变色', -20.5010095, 57.4259624),
(3631, 197, '11', 'Cascade', '瀑', '级 联', 44.5162821, -116.0417983),
(3632, 197, '12', 'Glacis', '格拉西斯', '格拉西斯', 47.1157303, -70.3028183),
(3633, 197, '13', 'Grand\'Anse Mahé', '㶴', '大', -4.6773920, 55.4637770),
(3634, 197, '14', 'Grand\'Anse Praslin', '㶴', '大', -4.3176219, 55.7078363),
(3635, 197, '15', 'La Digue', '這', '这', 49.7666922, -97.1546629),
(3636, 197, '16', 'La Rivière Anglaise', '英吉利河', '英吉利河', -4.6106150, 55.4540841),
(3637, 197, '24', 'Les Mamelles', '乳房', '乳房', 38.8250505, -90.4834517),
(3638, 197, '17', 'Mont Buxton', '巴克斯頓山', '巴克斯顿山', -4.6166667, 55.4457768),
(3639, 197, '18', 'Mont Fleuri', '弗勒里山', '弗勒里山', -4.6356543, 55.4554688),
(3640, 197, '19', 'Plaisance', '娛', '快乐', 45.6070950, -75.1142745),
(3641, 197, '20', 'Pointe La Rue', 'Pointe La Rue', 'Pointe La Rue', -4.6804890, 55.5191857),
(3642, 197, '21', 'Port Glaud', '格勞德港', '格劳德港', -4.6488523, 55.4194753),
(3643, 197, '25', 'Roche Caiman', '羅氏凱門鱷', '罗氏凯门鳄', -4.6396028, 55.4679315),
(3644, 197, '22', 'Saint Louis', '聖路易斯', '圣路易', 38.6270025, -90.1994042),
(3645, 197, '23', 'Takamaka', '高真香', '高真', 37.9645917, -1.2217727),
(3646, 198, 'E', 'Eastern', '東', '东部', 8.2101601, -11.5921809),
(3647, 198, 'N', 'Northern', '北', '北方', 9.1177571, -12.9330153),
(3648, 198, 'S', 'Southern', '南方的', '南部', 7.7054093, -13.4250766),
(3649, 198, 'W', 'Western', '西方的', '西方', 8.2967871, -13.2699761),
(3650, 199, '01', 'Central Singapore', '新加坡中部', '新加坡中部', 1.2884000, 103.8535000),
(3651, 199, '02', 'North East', '東北', '东北', 1.3824000, 103.8972000),
(3652, 199, '03', 'North West', '西北', '西北', 1.4180000, 103.8275000),
(3653, 199, '04', 'South East', '東南', '东南', 1.3571000, 103.7004000),
(3654, 199, '05', 'South West', '西南', '西南', 1.3571000, 103.9451000),
(3655, 200, 'BC', 'Banská Bystrica', 'Banská Bystrica', 'Banská Bystrica', 48.5312499, 19.3828740),
(3656, 200, 'BL', 'Bratislava', '布拉迪斯拉發', '布拉迪斯拉发', 48.3118304, 17.1973299),
(3657, 200, 'KI', 'Košice', '科希策', '科希策', 48.6375737, 21.0834225),
(3658, 200, 'NI', 'Nitra', '硝酸鹽', '硝酸盐', 48.0143765, 18.5416504),
(3659, 200, 'PV', 'Prešov', '普雷索夫', '普雷绍夫', 49.1716773, 21.3742001),
(3660, 200, 'TC', 'Trenčín', '特倫欽', '特伦钦', 48.8086758, 18.2324026),
(3661, 200, 'TA', 'Trnava', '特爾納瓦', '特尔纳瓦', 48.3943898, 17.7216205),
(3662, 200, 'ZI', 'Žilina', 'Žilina', 'Žilina', 49.2031435, 19.3645733),
(3663, 201, '001', 'Ajdovščina', 'Ajdovščina', 'Ajdovščina', 45.8870776, 13.9042818),
(3664, 201, '213', 'Ankaran', '安卡蘭', '安卡兰', 45.5784510, 13.7369174),
(3665, 201, '195', 'Apače', 'Apače', '阿帕切', 46.6974679, 15.9102534),
(3666, 201, '002', 'Beltinci', '貝爾廷奇', '贝尔廷奇', 46.6079153, 16.2365127),
(3667, 201, '148', 'Benedikt', '貝內迪克特', '贝内迪克特', 46.6155841, 15.8957281),
(3668, 201, '149', 'Bistrica ob Sotli', 'Bistrica ob Sotli', '比斯特里卡·奥布·索特利', 46.0565579, 15.6625947),
(3669, 201, '003', 'Bled', '村', '村', 46.3683266, 14.1145798),
(3670, 201, '150', 'Bloke', '傢伙', '小子', 45.7728141, 14.5063459),
(3671, 201, '004', 'Bohinj', '博希尼', '博希尼', 46.3005652, 13.9427195),
(3672, 201, '005', 'Borovnica', '博羅夫尼察', '硼尼卡', 45.9044525, 14.3824189),
(3673, 201, '006', 'Bovec', '博維克', '博维克', 46.3380495, 13.5524174),
(3674, 201, '151', 'Braslovče', '布拉斯洛夫切', '布拉斯洛夫切', 46.2836192, 15.0418320),
(3675, 201, '007', 'Brda', '山丘', '山', 45.9975652, 13.5270474),
(3676, 201, '009', 'Brežice', '布雷日策', '布雷日策', 45.9041096, 15.5943639),
(3677, 201, '008', 'Brezovica', '布雷佐維察', '布雷佐维察', 45.9559351, 14.4349952),
(3678, 201, '152', 'Cankova', '坎科娃', '坎科娃', 46.7182370, 16.0197222),
(3679, 201, '011', 'Celje', '采列', '采列', 46.2397495, 15.2677063),
(3680, 201, '012', 'Cerklje na Gorenjskem', 'Cerklje na Gorenjskem', 'Cerklje na Gorenjskem', 46.2517054, 14.4857979),
(3681, 201, '013', 'Cerknica', '切爾克尼卡', '切尔克尼卡', 45.7966255, 14.3921770),
(3682, 201, '014', 'Cerkno', '切爾克諾', '切尔克诺', 46.1288414, 13.9894027),
(3683, 201, '153', 'Cerkvenjak', '切爾克文雅克', '切尔克文亚克', 46.5670711, 15.9429753),
(3684, 201, '196', 'Cirkulane', '循環', '环形', 46.3298322, 15.9980666),
(3685, 201, '015', 'Črenšovci', 'Črenšovci', 'Črenšovci', 46.5720029, 16.2877346),
(3686, 201, '016', 'Črna na Koroškem', 'Črna na Koroškem', 'Črna na Koroškem', 46.4704529, 14.8499998),
(3687, 201, '017', 'Črnomelj', 'Črnomelj', 'Črnomelj', 45.5361225, 15.1944143),
(3688, 201, '018', 'Destrnik', '德斯特尼克', '德斯特尼克', 46.4922368, 15.8777956),
(3689, 201, '019', 'Divača', '迪瓦查', '迪瓦查', 45.6806069, 13.9720312),
(3690, 201, '154', 'Dobje', '多布傑', '多布杰', 46.1370037, 15.3941290),
(3691, 201, '020', 'Dobrepolje', '多布雷波列', '多布雷波列', 45.8524951, 14.7083109),
(3692, 201, '155', 'Dobrna', '多布爾納', '多布尔纳', 46.3356141, 15.2259732),
(3693, 201, '021', 'Dobrova–Polhov Gradec', '多布羅娃-波爾霍夫·格拉德茨', '多布罗娃-波尔霍夫·格拉德茨', 46.0648896, 14.3168195),
(3694, 201, '156', 'Dobrovnik', '多布羅夫尼克', '多布罗夫尼克', 46.6538662, 16.3506594),
(3695, 201, '022', 'Dol pri Ljubljani', 'Dol pri 盧布爾雅尼', '卢布尔雅那多尔普里', 46.0884386, 14.6424792),
(3696, 201, '157', 'Dolenjske Toplice', '多倫斯克·托普利采', 'Dolenjske Toplice', 45.7345711, 15.0129493),
(3697, 201, '023', 'Domžale', '多姆扎萊', '多姆扎莱', 46.1438269, 14.6375279),
(3698, 201, '024', 'Dornava', '多爾納瓦', '多尔纳瓦', 46.4443513, 15.9889159),
(3699, 201, '025', 'Dravograd', '德拉沃格勒', '德拉沃格勒', 46.5892190, 15.0246021),
(3700, 201, '026', 'Duplek', '午睡場所', '午睡场所', 46.5010016, 15.7546307),
(3701, 201, '027', 'Gorenja Vas–Poljane', '戈倫賈·瓦斯-波爾簡', '戈伦贾·瓦斯-波尔简', 46.1116582, 14.1149348),
(3702, 201, '028', 'Gorišnica', '戈里什尼察', '戈里什尼察', 46.4120271, 16.0133089),
(3703, 201, '207', 'Gorje', '戈爾傑', '戈尔杰', 46.3802458, 14.0685339),
(3704, 201, '029', 'Gornja Radgona', '戈爾尼亞·拉德戈納', '戈尔尼亚·拉德戈纳', 46.6767099, 15.9910847),
(3705, 201, '030', 'Gornji Grad', '上城區', '上城区', 46.2961712, 14.8062347),
(3706, 201, '031', 'Gornji Petrovci', '戈爾吉·彼得羅夫奇', '戈尔吉·彼得罗夫奇', 46.8037128, 16.2191379),
(3707, 201, '158', 'Grad', '度', '度', 46.8087320, 16.1092060),
(3708, 201, '032', 'Grosuplje', '格羅蘇普列', '格罗苏普列', 45.9557645, 14.6588990),
(3709, 201, '159', 'Hajdina', '哈伊迪納', '哈伊迪纳', 46.4185014, 15.8244722),
(3710, 201, '160', 'Hoče–Slivnica', '霍切-斯利夫尼察', 'Hoče-Slivnica', 46.4778580, 15.6476005),
(3711, 201, '161', 'Hodoš', '霍多什', 'Hodoš', 46.8314134, 16.3210680),
(3712, 201, '162', 'Horjul', '霍爾朱爾', '霍尔朱尔', 46.0225378, 14.2986269),
(3713, 201, '034', 'Hrastnik', '赫拉斯特尼克', '赫拉斯特尼克', 46.1417288, 15.0844894),
(3714, 201, '035', 'Hrpelje–Kozina', '赫爾佩列-科齊納', '赫尔佩列-科齐纳', 45.6091192, 13.9379148),
(3715, 201, '036', 'Idrija', '伊德里亞', '伊德里亚', 46.0040939, 13.9775493),
(3716, 201, '037', 'Ig', '伊格', '伊格', 45.9588868, 14.5270528),
(3717, 201, '038', 'Ilirska Bistrica', '伊利爾斯卡比斯特里卡', '伊利尔斯卡比斯特里卡', 45.5791323, 14.2809729),
(3718, 201, '039', 'Ivančna Gorica', '伊萬奇娜·戈里察', '伊万奇娜·戈里察', 45.9395841, 14.8047626),
(3719, 201, '040', 'Izola', '伊佐拉', '伊佐拉', 45.5313557, 13.6664649),
(3720, 201, '041', 'Jesenice', '傑塞尼斯', '杰塞尼采', 46.4367047, 14.0526057),
(3721, 201, '163', 'Jezersko', '湖區', '湖区', 46.3942794, 14.4985559),
(3722, 201, '042', 'Juršinci', '尤爾辛奇', '尤尔辛奇', 46.4898651, 15.9809230),
(3723, 201, '043', 'Kamnik', '卡姆尼克', '卡姆尼克', 46.2221666, 14.6070727),
(3724, 201, '044', 'Kanal ob Soči', 'Kanal ob Soči', 'Kanal ob Soči', 46.0673530, 13.6203350),
(3725, 201, '045', 'Kidričevo', '基德里切沃', '基德里切沃', 46.3957572, 15.7925906),
(3726, 201, '046', 'Kobarid', '科巴里德', '科巴里德', 46.2456971, 13.5786949),
(3727, 201, '047', 'Kobilje', '科比列', '科比列', 46.6851800, 16.3936719),
(3728, 201, '048', 'Kočevje', 'Kočevje', 'Kočevje', 45.6428000, 14.8615838),
(3729, 201, '049', 'Komen', '來', '来', 45.8175235, 13.7482711),
(3730, 201, '164', 'Komenda', '令', '命令', 46.2064880, 14.5382499),
(3731, 201, '050', 'Koper', '銅', '铜', 45.5480590, 13.7301877),
(3732, 201, '197', 'Kostanjevica na Krki', '科斯坦耶維察·納·克爾基', 'Kostanjevica na Krki', 45.8316638, 15.4411906),
(3733, 201, '165', 'Kostel', '教會', '教堂', 45.4928255, 14.8708235),
(3734, 201, '051', 'Kozje', '科澤', '科杰', 46.0733211, 15.5596719),
(3735, 201, '052', 'Kranj', '克拉尼', '克拉尼', 46.2585021, 14.3543569),
(3736, 201, '053', 'Kranjska Gora', '克拉尼斯卡戈拉', '克拉尼斯卡戈拉', 46.4845293, 13.7857145),
(3737, 201, '166', 'Križevci', '克里澤夫奇', '克里泽夫奇', 46.5701821, 16.1092653),
(3738, 201, '054', 'Krško', '克爾什科', '克尔什科', 45.9589609, 15.4923555),
(3739, 201, '055', 'Kungota', '昆戈塔', '昆戈塔', 46.6418793, 15.6036288),
(3740, 201, '056', 'Kuzma', '庫茲馬', '库兹马', 46.8351038, 16.0807100),
(3741, 201, '057', 'Laško', '拉什科', '拉什科', 46.1542236, 15.2361491),
(3742, 201, '058', 'Lenart', '萊納特', '莱纳特', 46.5834424, 15.8262125),
(3743, 201, '059', 'Lendava', '傳奇文學', '传说', 46.5513483, 16.4419839),
(3744, 201, '060', 'Litija', '麗蒂亞', '利蒂亚', 46.0573226, 14.8309636),
(3745, 201, '061', 'Ljubljana', '盧布爾雅那', '卢布尔雅那', 46.0569465, 14.5057515),
(3746, 201, '062', 'Ljubno', '柳布諾', '柳布诺', 46.3443125, 14.8335492),
(3747, 201, '063', 'Ljutomer', '左聚體', '左聚体', 46.5190848, 16.1893216),
(3748, 201, '208', 'Log–Dragomer', '原木-Dragomer', '原木-Dragomer', 46.0178747, 14.3687767),
(3749, 201, '064', 'Logatec', '洛加特', '洛加特', 45.9176110, 14.2351451),
(3750, 201, '065', 'Loška Dolina', '洛什卡·多利納', '洛什卡·多利纳', 45.6477908, 14.4973147),
(3751, 201, '066', 'Loški Potok', '洛什基波托克', '洛什基波托克', 45.6909637, 14.5985970),
(3752, 201, '167', 'Lovrenc na Pohorju', 'Lovrenc na Pohorju', 'Lovrenc na Pohorju', 46.5419638, 15.4000443),
(3753, 201, '067', 'Luče', '盧切', 'Luče', 46.3544925, 14.7471504),
(3754, 201, '068', 'Lukovica', '盧科維察', '卢科维察', 46.1696293, 14.6907259),
(3755, 201, '069', 'Majšperk', 'Majšperk', 'Majšperk', 46.3503019, 15.7340595),
(3756, 201, '198', 'Makole', '馬科萊', '马科莱', 46.3168697, 15.6664126),
(3757, 201, '070', 'Maribor', '馬里博爾', '马里博尔', 46.5506496, 15.6205439),
(3758, 201, '168', 'Markovci', '馬爾科夫奇', '马尔科夫奇', 46.3879309, 15.9586014),
(3759, 201, '071', 'Medvode', '梅德沃德', '梅德沃德', 46.1419080, 14.4032596),
(3760, 201, '072', 'Mengeš', '門格什', '门格什', 46.1659122, 14.5719694),
(3761, 201, '073', 'Metlika', '梅特利卡', '梅特利卡', 45.6480715, 15.3177838),
(3762, 201, '074', 'Mežica', '梅日卡', '梅日察', 46.5215027, 14.8521340),
(3763, 201, '169', 'Miklavž na Dravskem Polju', 'Miklavž na Dravskem Polju', 'Miklavž na Dravskem Polju', 46.5082628, 15.6952065),
(3764, 201, '075', 'Miren–Kostanjevica', '米倫-科斯坦耶維察', '米伦-科斯坦耶维察', 45.8436029, 13.6276647),
(3765, 201, '212', 'Mirna', '米爾納', '米尔纳', 45.9515647, 15.0620977),
(3766, 201, '170', 'Mirna Peč', '米爾娜·佩奇', '米尔纳·佩奇', 45.8481574, 15.0879450),
(3767, 201, '076', 'Mislinja', '米斯林賈', '米斯林亚', 46.4429403, 15.1987678),
(3768, 201, '199', 'Mokronog–Trebelno', '莫克羅諾-特雷貝爾諾', '莫克罗诺-特雷贝尔诺', 45.9088529, 15.1596736),
(3769, 201, '077', 'Moravče', '莫拉夫切', '莫拉夫切', 46.1362781, 14.7460010),
(3770, 201, '078', 'Moravske Toplice', '莫拉夫斯克·托普利采', '莫拉夫斯克托普利采', 46.6856932, 16.2224582),
(3771, 201, '079', 'Mozirje', '莫齊爾耶', '莫齐列', 46.3394350, 14.9602413),
(3772, 201, '080', 'Murska Sobota', '穆爾斯卡·索博塔', '穆尔斯卡·索博塔', 46.6432147, 16.1515754),
(3773, 201, '081', 'Muta', '穆塔', '穆塔', 46.6097366, 15.1629995),
(3774, 201, '082', 'Naklo', '納克洛', '纳克洛', 46.2718663, 14.3156932),
(3775, 201, '083', 'Nazarje', '納扎爾耶', '纳扎尔耶', 46.2821741, 14.9225629),
(3776, 201, '084', 'Nova Gorica', '新戈里察', '新戈里察', 45.9762760, 13.7308881),
(3777, 201, '085', 'Novo Mesto', '新梅斯托', '新梅斯托', 45.8010824, 15.1710089),
(3778, 201, '086', 'Odranci', '擅自佔地者', '寮 屋 居民', 46.5901017, 16.2788165),
(3779, 201, '171', 'Oplotnica', '密謀', '情节', 46.3871630, 15.4458131),
(3780, 201, '087', 'Ormož', '奧爾莫茲', 'Ormož', 46.4353333, 16.1543740),
(3781, 201, '088', 'Osilnica', '奧西爾尼察', '奥西尔尼察', 45.5418467, 14.7156303),
(3782, 201, '089', 'Pesnica', '佩斯尼卡', '佩斯尼卡', 46.6088755, 15.6757051),
(3783, 201, '090', 'Piran', '皮蘭', '皮兰', 45.5288856, 13.5680735),
(3784, 201, '091', 'Pivka', '皮夫卡', '皮夫卡', 45.6789296, 14.2542689),
(3785, 201, '092', 'Podčetrtek', 'Podčetrtek', 'Podčetrtek', 46.1739542, 15.6013816),
(3786, 201, '172', 'Podlehnik', '波德萊尼克', '波德莱尼克', 46.3310782, 15.8785836),
(3787, 201, '093', 'Podvelka', '泰盧固語', '泰卢固语', 46.6221952, 15.3889922),
(3788, 201, '200', 'Poljčane', 'Poljčane', 'Poljčane', 46.3139853, 15.5784791),
(3789, 201, '173', 'Polzela', '波爾澤拉', '波尔泽拉', 46.2808970, 15.0737321),
(3790, 201, '094', 'Postojna', '波斯托伊納', '波斯托伊纳', 45.7749390, 14.2134263),
(3791, 201, '174', 'Prebold', '預粗體', '预粗体', 46.2359136, 15.0936912),
(3792, 201, '095', 'Preddvor', '普雷德沃爾', '普雷德沃尔', 46.3017139, 14.4218165),
(3793, 201, '175', 'Prevalje', '普雷瓦列', '普雷瓦列', 46.5621146, 14.8847861),
(3794, 201, '096', 'Ptuj', '普圖伊', '普图伊', 46.4199535, 15.8696884),
(3795, 201, '097', 'Puconci', '普孔奇', '普孔奇', 46.7200418, 16.0997792),
(3796, 201, '098', 'Rače–Fram', '拉切-弗拉姆', '拉切-弗拉姆', 46.4542083, 15.6329467),
(3797, 201, '099', 'Radeče', '拉德切', '拉德切', 46.0666954, 15.1820438),
(3798, 201, '100', 'Radenci', NULL, NULL, 46.6231121, 16.0506903),
(3799, 201, '101', 'Radlje ob Dravi', 'Radlje ob Dravi', 'Radlje ob Dravi', 46.6135732, 15.2354438),
(3800, 201, '102', 'Radovljica', '拉多夫利察', '拉多夫利察', 46.3355827, 14.2094534),
(3801, 201, '103', 'Ravne na Koroškem', 'Ravne na Koroškem', 'Ravne na Koroškem', 46.5521194, 14.9599084),
(3802, 201, '176', 'Razkrižje', 'Razkrižje', 'Razkrižje', 46.5226339, 16.2668638),
(3803, 201, '209', 'Rečica ob Savinji', 'Rečica ob Savinji', 'Rečica ob Savinji', 46.3233790, 14.9223670),
(3804, 201, '201', 'Renče–Vogrsko', 'Renče–Vogrsko', 'Renče–Vogrsko', 45.8954617, 13.6785673),
(3805, 201, '104', 'Ribnica', '里布尼察', '里布尼察', 45.7400303, 14.7265782),
(3806, 201, '177', 'Ribnica na Pohorju', 'Ribnica na Pohorju', 'Ribnica na Pohorju', 46.5356145, 15.2674538),
(3807, 201, '106', 'Rogaška Slatina', '羅加什卡·斯拉蒂納', '罗加什卡·斯拉蒂纳', 46.2453973, 15.6265014),
(3808, 201, '105', 'Rogašovci', '羅加索夫奇', '罗加索夫奇', 46.8055785, 16.0345237),
(3809, 201, '107', 'Rogatec', '羅加特', '罗加特', 46.2286626, 15.6991338),
(3810, 201, '108', 'Ruše', '魯謝', '鲁谢', 46.5206265, 15.4817869),
(3811, 201, '033', 'Šalovci', '沙洛夫奇', '沙洛夫奇', 46.8533568, 16.2591791),
(3812, 201, '178', 'Selnica ob Dravi', 'Selnica ob Dravi', '德拉维的塞尔尼卡', 46.5513918, 15.4929410),
(3813, 201, '109', 'Semič', '塞米奇', '塞米奇', 45.6520534, 15.1820701),
(3814, 201, '183', 'Šempeter–Vrtojba', 'Šempeter–Vrtojba', 'Šempeter–Vrtojba', 45.9290095, 13.6415594),
(3815, 201, '117', 'Šenčur', 'Šenčur', 'Šenčur', 46.2433699, 14.4192223),
(3816, 201, '118', 'Šentilj', 'Šentilj', 'Šentilj', 46.6862839, 15.7103567),
(3817, 201, '119', 'Šentjernej', 'Šentjernej', 'Šentjernej', 45.8434130, 15.3378312),
(3818, 201, '120', 'Šentjur', 'Šentjur', 'Šentjur', 46.2654339, 15.4080000),
(3819, 201, '211', 'Šentrupert', 'Šentrupert', '森特鲁珀特', 45.9873142, 15.0829783),
(3820, 201, '110', 'Sevnica', '塞夫尼察', '塞夫尼察', 46.0070317, 15.3045679),
(3821, 201, '111', 'Sežana', '塞扎納', '塞扎纳', 45.7275109, 13.8661931),
(3822, 201, '121', 'Škocjan', '斯科詹', '斯科昌', 45.9175454, 15.3101736),
(3823, 201, '122', 'Škofja Loka', '斯科菲亞·洛卡', '斯科菲亚·洛卡', 46.1409844, 14.2811873),
(3824, 201, '123', 'Škofljica', '斯科夫利察', '斯科夫利察', 45.9840962, 14.5746626),
(3825, 201, '112', 'Slovenj Gradec', '斯洛文尼·格拉德克', '斯洛文尼·格拉德克', 46.4877718, 15.0729478),
(3826, 201, '113', 'Slovenska Bistrica', '斯洛文尼亞比斯特里察', '斯洛文尼亚比斯特里察', 46.3919813, 15.5727869),
(3827, 201, '114', 'Slovenske Konjice', '斯洛文尼亞斯科尼采', '斯洛文斯克·康吉采', 46.3369191, 15.4214708),
(3828, 201, '124', 'Šmarje pri Jelšah', 'Šmarje pri Jelšah', 'Šmarje pri Jelšah', 46.2287025, 15.5190353),
(3829, 201, '206', 'Šmarješke Toplice', 'Šmarješke Toplice', 'Šmarješke Toplice', 45.8680377, 15.2347422),
(3830, 201, '125', 'Šmartno ob Paki', 'Šmartno ob Paki', 'Šmartno ob Paki', 46.3290372, 15.0333937),
(3831, 201, '194', 'Šmartno pri Litiji', 'Šmartno pri Litiji', 'Šmartno pri Litiji', 46.0454971, 14.8410133),
(3832, 201, '179', 'Sodražica', '索德拉日察', 'Sodražica', 45.7616565, 14.6352853),
(3833, 201, '180', 'Solčava', '索爾查瓦', '索尔查瓦', 46.4023526, 14.6802304),
(3834, 201, '126', 'Šoštanj', '索什塔尼', 'Šoštanj', 46.3782836, 15.0461378),
(3835, 201, '202', 'Središče ob Dravi', 'Središče ob Dravi', 'Središče ob Dravi', 46.3959282, 16.2704915),
(3836, 201, '115', 'Starše', '斯塔謝', 'Starše', 46.4674331, 15.7640546),
(3837, 201, '127', 'Štore', '斯托雷', 'Štore', 46.2222514, 15.3126116),
(3838, 201, '203', 'Straža', '斯特拉扎', '斯特拉扎', 45.7768428, 15.0948694),
(3839, 201, '181', 'Sveta Ana', '斯維塔·安娜', '斯维塔·安娜', 46.6500000, 15.8452780),
(3840, 201, '204', 'Sveta Trojica v Slovenskih Goricah', '斯維塔·特羅伊卡 v 斯洛文斯基·戈里卡', '斯维塔·特罗伊卡 v 斯洛文斯基·戈里查', 46.5680809, 15.8823064),
(3841, 201, '182', 'Sveti Andraž v Slovenskih Goricah', '斯維蒂·安德拉茲 v 斯洛文斯基·戈里卡', '斯维蒂·安德拉兹 v 斯洛文斯基·戈里查', 46.5189747, 15.9498262),
(3842, 201, '116', 'Sveti Jurij ob Ščavnici', 'Sveti Jurij ob Ščavnici', 'Sveti Jurij ob Ščavnici', 46.5687452, 16.0222528),
(3843, 201, '210', 'Sveti Jurij v Slovenskih Goricah', '斯維蒂·尤里 v 斯洛文斯基·戈里卡', '斯维蒂·尤里 v 斯洛文斯基·戈里卡', 46.6170791, 15.7804677),
(3844, 201, '205', 'Sveti Tomaž', 'Sveti Tomaž', '斯维蒂·托马兹', 46.4835283, 16.0794420),
(3845, 201, '184', 'Tabor', '塔博爾', '泊', 46.2107921, 15.0174249),
(3846, 201, '010', 'Tišina', '靜', '安静', 46.6541884, 16.0754781),
(3847, 201, '128', 'Tolmin', '托爾明', '托尔明', 46.1857188, 13.7319838),
(3848, 201, '129', 'Trbovlje', '特爾博夫列', '特尔博夫列', 46.1503563, 15.0453137),
(3849, 201, '130', 'Trebnje', '特雷布涅', '特雷布涅', 45.9080163, 15.0131905),
(3850, 201, '185', 'Trnovska Vas', '特爾諾夫斯卡瓦斯', '特尔诺夫斯卡瓦斯', 46.5294035, 15.8853118),
(3851, 201, '131', 'Tržič', 'Tržič', 'Tržič', 46.3593514, 14.3006623),
(3852, 201, '186', 'Trzin', '特爾津', '特尔津', 46.1298241, 14.5577637),
(3853, 201, '132', 'Turnišče', 'Turnišče', 'Turnišče', 46.6137504, 16.3202100),
(3854, 201, '187', 'Velika Polana', '維利卡·波拉納', '维利卡·波拉纳', 46.5731715, 16.3444126),
(3855, 201, '134', 'Velike Lašče', 'Velike Lašče', 'Velike Lašče', 45.8336591, 14.6362363),
(3856, 201, '188', 'Veržej', 'Veržej', 'Veržej', 46.5841135, 16.1620800),
(3857, 201, '135', 'Videm', '視頻', '视频', 46.3638330, 15.8781212),
(3858, 201, '136', 'Vipava', '維帕瓦', '维帕瓦', 45.8412674, 13.9609613),
(3859, 201, '137', 'Vitanje', '維坦傑', '维坦野', 46.3815323, 15.2950687),
(3860, 201, '138', 'Vodice', '沃迪採', '沃迪策', 46.1896643, 14.4938539),
(3861, 201, '139', 'Vojnik', '沃伊尼克', '沃伊尼克', 46.2920581, 15.3020580),
(3862, 201, '189', 'Vransko', '弗蘭斯科', '弗兰斯科', 46.2390060, 14.9527249),
(3863, 201, '140', 'Vrhnika', '弗爾尼卡', '弗尔尼卡', 45.9502719, 14.3276422),
(3864, 201, '141', 'Vuzenica', '武澤尼察', 'Vuzenica', 46.5980836, 15.1657237),
(3865, 201, '142', 'Zagorje ob Savi', 'Zagorje ob Savi', 'Zagorje ob Savi', 46.1345202, 14.9964384),
(3866, 201, '190', 'Žalec', '扎萊克', '扎莱茨', 46.2519712, 15.1650072),
(3867, 201, '143', 'Zavrč', 'Zavrč', 'Zavrč', 46.3571300, 16.0477747),
(3868, 201, '146', 'Železniki', 'Železniki', 'Železniki', 46.2256377, 14.1693617),
(3869, 201, '191', 'Žetale', 'Žetale', 'Žetale', 46.2742833, 15.7913359),
(3870, 201, '147', 'Žiri', '陪審團', '陪审团', 46.0472499, 14.1098451),
(3871, 201, '192', 'Žirovnica', '日羅夫尼察', '日罗夫尼察', 46.3954403, 14.1539632),
(3872, 201, '144', 'Zreče', '茲雷切', '兹雷切', 46.4177786, 15.3709431),
(3873, 201, '193', 'Žužemberk', 'Žužemberk', 'Žužemberk', 45.8200350, 14.9535919),
(3874, 202, 'CE', 'Central', '中', '中央', -9.0202593, 158.2511830),
(3875, 202, 'CH', 'Choiseul', '舒瓦瑟爾', '舒瓦瑟尔', -7.0501494, 156.9511459),
(3876, 202, 'GU', 'Guadalcanal', '瓜達爾卡納爾島', '瓜达尔卡纳尔岛', -9.5773284, 160.1455805),
(3877, 202, 'CT', 'Honiara', '霍尼亞拉', '霍尼亚拉', -9.4456381, 159.9728999),
(3878, 202, 'IS', 'Isabel', '伊莎貝爾', '伊莎贝尔', -8.0592353, 159.1447081),
(3879, 202, 'MK', 'Makira-Ulawa', '馬基拉-烏拉瓦', '马基拉-乌拉瓦', -10.5737447, 161.8096941),
(3880, 202, 'ML', 'Malaita', '馬萊塔', '马莱塔', -8.9446168, 160.9071236),
(3881, 202, 'RB', 'Rennell and Bellona', '倫內爾和貝羅納', '伦内尔和贝罗纳', -11.6131435, 160.1693949),
(3882, 202, 'TE', 'Temotu', '特莫圖', '特莫图', -10.6869290, 166.0623979),
(3883, 202, 'WE', 'Western', '西方的', '西方', -7.7499869, 155.5642361),
(3884, 203, 'AW', 'Awdal', '奧達爾', '奥达尔', 10.6334285, 43.3294660),
(3885, 203, 'BK', 'Bakool', '巴庫爾', '巴库尔', 4.3657221, 44.0960311),
(3886, 203, 'BN', 'Banaadir', '班尼迪爾', '巴尼迪尔', 2.1187375, 45.3369459),
(3887, 203, 'BR', 'Bari', '巴里', '巴里', 41.1171432, 16.8718715),
(3888, 203, 'BY', 'Bay', '灣', '湾', 37.0365534, -95.6174767),
(3889, 203, 'GA', 'Galguduud', '加爾古杜德', '加尔古杜德', 5.1850128, 46.8252838),
(3890, 203, 'GE', 'Gedo', '蓋多', '盖多', 3.5039227, 42.2362435),
(3891, 203, 'HI', 'Hiran', '希蘭', '希兰', 4.3210150, 45.2993862),
(3892, 203, 'JH', 'Lower Juba', '下朱巴', '下朱巴', 0.2240210, 41.6011814),
(3893, 203, 'SH', 'Lower Shebelle', '下謝貝爾', '下谢贝尔', 1.8766458, 44.2479015),
(3894, 203, 'JD', 'Middle Juba', '朱巴中部', '朱巴中部', 2.0780488, 41.6011814),
(3895, 203, 'SD', 'Middle Shebelle', '中謝貝爾', '中谢贝尔', 2.9250247, 45.9039689),
(3896, 203, 'MU', 'Mudug', '穆杜格', '穆杜格', 6.5656726, 47.7637565),
(3897, 203, 'NU', 'Nugal', '努加爾', '努加尔', 43.2793861, 17.0339205),
(3898, 203, 'SA', 'Sanaag', '薩納格', '萨纳格', 10.3938218, 47.7637565),
(3899, 203, 'TO', 'Togdheer', '托格德希爾', '托格德尔', 9.4460587, 45.2993862),
(3900, 204, 'EC', 'Eastern Cape', '東開普省', '东开普省', -32.2968402, 26.4193890),
(3901, 204, 'FS', 'Free State', '自由州', '自由邦', 37.6858525, -97.2811256),
(3902, 204, 'GP', 'Gauteng', '豪登省', '豪登省', -26.2707593, 28.1122679),
(3903, 204, 'KZN', 'KwaZulu-Natal', '誇祖魯-納塔爾省', '夸祖鲁-纳塔尔省', -28.5305539, 30.8958242),
(3904, 204, 'LP', 'Limpopo', '林波波省', '林波波省', -23.4012946, 29.4179324),
(3905, 204, 'MP', 'Mpumalanga', '普馬蘭加省', '普马兰加省', -25.5653360, 30.5279096),
(3906, 204, 'NW', 'North West', '西北', '西北', 32.7588520, -97.3288060),
(3907, 204, 'NC', 'Northern Cape', '北開普省', '北开普省', -29.0466808, 21.8568586),
(3908, 204, 'WC', 'Western Cape', '西開普省', '西开普省', -33.2277918, 21.8568586),
(3909, 116, '26', 'Busan', '釜山', '釜山', 35.1795543, 129.0756416),
(3910, 116, '27', 'Daegu', '大邱', '大邱', 35.8714354, 128.6014450),
(3911, 116, '30', 'Daejeon', '大田', '大田', 36.3504119, 127.3845475),
(3912, 116, '42', 'Gangwon', '江原道', '江原道', 37.8228000, 128.1555000),
(3913, 116, '29', 'Gwangju', '光州', '光州', 35.1595454, 126.8526012),
(3914, 116, '41', 'Gyeonggi', '京畿道', '京畿道', 37.4138000, 127.5183000),
(3915, 116, '28', 'Incheon', '仁川', '仁川', 37.4562557, 126.7052062),
(3916, 116, '49', 'Jeju', '濟州島', '济州岛', 33.9568278, -84.1313500),
(3917, 116, '43', 'North Chungcheong', '忠清北道', '忠清北道', 36.8000000, 127.7000000),
(3918, 116, '47', 'North Gyeongsang', '慶尚北道', '庆尚北道', 36.4919000, 128.8889000),
(3919, 116, '45', 'North Jeolla', '全羅北道', '全罗北道', 35.7175000, 127.1530000),
(3920, 116, '50', 'Sejong City', '世宗市', '世宗市', 34.0523323, -118.3084897),
(3921, 116, '11', 'Seoul', '漢城', '首尔', 37.5665350, 126.9779692),
(3922, 116, '44', 'South Chungcheong', '忠清南道', '忠清南道', 36.5184000, 126.8000000),
(3923, 116, '48', 'South Gyeongsang', '慶尚南道', '庆尚南道', 35.4606000, 128.2132000),
(3924, 116, '46', 'South Jeolla', '全羅南道', '全罗南道', 34.8679000, 126.9910000),
(3925, 116, '31', 'Ulsan', '蔚山', '蔚山', 35.5383773, 129.3113596),
(3926, 206, 'EC', 'Central Equatoria', '中赤道', '中赤道', 4.6144063, 31.2626366),
(3927, 206, 'EE', 'Eastern Equatoria', '東赤道', '东赤道', 5.0692995, 33.4383530),
(3928, 206, 'JG', 'Jonglei State', '瓊萊州', '琼莱州', 7.1819619, 32.3560952),
(3929, 206, 'LK', 'Lakes', '湖泊', '湖泊', 37.1628255, -95.6911623),
(3930, 206, 'BN', 'Northern Bahr el Ghazal', '北加扎勒河', '北加扎勒河', 8.5360449, 26.7967849),
(3931, 206, 'UY', 'Unity', '團結', '统一', 37.7871276, -122.4034079),
(3932, 206, 'NU', 'Upper Nile', '上尼羅河', '上尼罗河', 9.8894202, 32.7181375),
(3933, 206, 'WR', 'Warrap', '戰爭', '战争拉普', 8.0886238, 28.6410641),
(3934, 206, 'BW', 'Western Bahr el Ghazal', '西加扎勒河', '西加扎勒河', 8.6452399, 25.2837585),
(3935, 206, 'EW', 'Western Equatoria', '西赤道', '西赤道', 5.3471799, 28.2994350),
(3936, 207, 'C', 'A Coruña', '拉科魯尼亞', '拉科鲁尼亚', 43.3619040, -8.4301932),
(3937, 207, 'AB', 'Albacete', '阿爾巴塞特', '阿尔巴塞特', 38.9922312, -1.8780989),
(3938, 207, 'A', 'Alicante', '阿利坎特', '阿利坎特', 38.3579546, -0.5425634),
(3939, 207, 'AL', 'Almeria', '阿爾梅里亞', '阿尔梅里亚', 36.8415268, -2.4746261),
(3940, 207, 'AN', 'Andalusia', '安達盧西亞', '安达卢西亚', 37.3084061, -7.2164446),
(3941, 207, 'VI', 'Araba', '車子', '汽车', 42.8395119, -3.8423774),
(3942, 207, 'AR', 'Aragon', '阿拉貢', '阿拉贡', 41.3801114, -2.0203159),
(3943, 207, 'AS', 'Asturias', '阿斯圖里亞斯', '阿斯图里亚斯', 43.2689279, -7.1683212),
(3944, 207, 'O', 'Asturias', '阿斯圖里亞斯', '阿斯图里亚斯', 43.3613953, -5.8593267),
(3945, 207, 'AV', 'Ávila', '阿維拉', '阿维拉', 40.6934511, -4.8935627),
(3946, 207, 'BA', 'Badajoz', '巴達霍斯', '巴达霍斯', 38.8793748, -7.0226983),
(3947, 207, 'IB', 'Balearic Islands', '巴利阿里群島', '巴利阿里群岛', 39.3621586, 1.4233452),
(3948, 207, 'B', 'Barcelona', '巴塞羅那', '巴塞罗那', 41.3926679, 2.1401891),
(3949, 207, 'PV', 'Basque Country', '巴斯克地區', '巴斯克地区', 42.9639085, -3.2505823),
(3950, 207, 'BI', 'Bizkaia', '比斯卡亞', '比斯卡亚', 43.2192199, -3.2111087),
(3951, 207, 'BU', 'Burgos', '布爾戈斯', '布尔戈斯', 42.3380758, -3.5812692),
(3952, 207, 'CC', 'Caceres', '卡塞雷斯', '卡塞雷斯', 39.4716313, -6.4257384),
(3953, 207, 'CA', 'Cádiz', '加的斯', '加的斯', 36.5163851, -6.2999767),
(3954, 207, 'CN', 'Canary Islands', '加那利群島', '加那利群岛', 28.2916000, 16.6291000),
(3955, 207, 'CB', 'Cantabria', '坎塔布里亞', '坎塔布里亚', 43.1349728, -4.6614518),
(3956, 207, 'S', 'Cantabria', '坎塔布里亞', '坎塔布里亚', 43.1828396, -3.9878427),
(3957, 207, 'CS', 'Castellón', '卡斯特利翁', '卡斯特利翁', 39.9811435, 0.0088407),
(3958, 207, 'CL', 'Castile and Leon', '卡斯蒂利亞和萊昂', '卡斯蒂利亚和莱昂', 41.6338445, -7.0713727),
(3959, 207, 'CM', 'Castilla-La Mancha', '卡斯蒂利亞-拉曼恰', '卡斯蒂利亚-拉曼恰', 39.6489544, -5.8063240),
(3960, 207, 'CT', 'Catalonia', '加泰羅尼亞', '加泰 罗尼亚', 41.6867211, 0.4239344),
(3961, 207, 'CE', 'Ceuta', '休達', '休达', 35.8890000, -5.3187000),
(3962, 207, 'CR', 'Ciudad Real', '雷亞爾城', '雷亚尔城', 38.9860758, -3.9444975),
(3963, 207, 'MD', 'Community of Madrid', '馬德里社區', '马德里自治区', 40.5244522, -4.4754103),
(3964, 207, 'CO', 'Córdoba', '科爾多瓦', '科尔多瓦', 36.5163851, -6.2999767),
(3965, 207, 'CU', 'Cuenca', '盆', '盆地', 40.0620036, -2.1655344),
(3966, 207, 'EX', 'Estremadura', '埃斯特雷馬杜拉', '埃斯特雷马杜拉', 39.2084979, -7.4165481),
(3967, 207, 'GA', 'Galicia', '加利西亞', '加利西亚', 42.7942875, -9.3395928),
(3968, 207, 'SS', 'Gipuzkoa', '吉普斯誇', '吉普斯夸', 43.1452360, -2.4461825),
(3969, 207, 'GI', 'Girona', '赫羅納', '赫罗纳', 41.9803445, 2.8011577),
(3970, 207, 'GR', 'Granada', '手榴彈', '手榴弹', 37.1809411, -3.6262910),
(3971, 207, 'GU', 'Guadalajara', '瓜達拉哈拉', '瓜达拉哈拉', 40.6322214, -3.1906820),
(3972, 207, 'H', 'Huelva', '韋爾瓦', '韦尔瓦', 37.2708666, -6.9571999),
(3973, 207, 'HU', 'Huesca', '韋斯卡', '韦斯卡', 41.5976275, -0.9056623),
(3974, 207, 'PM', 'Islas Baleares', '巴利阿里群島', '巴利阿里群岛', 39.3587759, 2.7356328),
(3975, 207, 'J', 'Jaén', '哈恩', '哈恩', 37.7800931, -3.8143745),
(3976, 207, 'RI', 'La Rioja', '拉里奧哈', '拉里奥哈', 42.2807692, -3.0672348),
(3977, 207, 'LO', 'La Rioja', '拉里奧哈', '拉里奥哈', 42.2870733, -2.5396030),
(3978, 207, 'GC', 'Las Palmas', '拉斯帕爾馬斯', '拉斯帕尔马斯', 28.2915637, -16.6291304),
(3979, 207, 'LE', 'León', '獅子', '狮子', 42.5987041, -5.5670839),
(3980, 207, 'L', 'Lleida', '萊里達', '莱里达', 41.6183731, 0.6024253),
(3981, 207, 'LU', 'Lugo', '盧戈', '卢戈', 43.0123137, -7.5740096),
(3982, 207, 'M', 'Madrid', '馬德里', '马德里', 40.4167515, -3.7038322),
(3983, 207, 'MA', 'Málaga', '馬拉加', '马拉加', 36.7182015, -4.5193060),
(3984, 207, 'ML', 'Melilla', '梅利利亞', '梅利利亚', 35.2937000, -2.9383000),
(3985, 207, 'MU', 'Murcia', '穆爾西亞', '穆尔西亚', 38.1398141, -1.3662160),
(3986, 207, 'NA', 'Navarra', '納瓦拉', '纳瓦拉', 42.6953909, -1.6760691),
(3987, 207, 'NC', 'Navarre', '納瓦拉', '纳瓦拉', 42.6114729, -2.2714543),
(3988, 207, 'OR', 'Ourense', '歐倫斯', '欧伦塞', 42.3383613, -7.8811951),
(3989, 207, 'P', 'Palencia', '帕倫西亞', '帕伦西亚', 42.0096832, -4.5287949),
(3990, 207, 'PO', 'Pontevedra', '龐特維德拉', '蓬特维德拉', 42.4338595, -8.6568552),
(3991, 207, 'MC', 'Region of Murcia', '穆爾西亞地區', '穆尔西亚大区', 38.0636582, -2.1554725),
(3992, 207, 'SA', 'Salamanca', '薩拉曼卡', '萨拉曼卡', 40.9515263, -6.2375947),
(3993, 207, 'TF', 'Santa Cruz de Tenerife', '聖克魯斯-德特內里費島', '圣克鲁斯-德特内里费岛', 28.4578914, -16.3213539),
(3994, 207, 'SG', 'Segovia', '塞哥維亞', '塞戈维亚', 40.9429296, -4.1088942),
(3995, 207, 'SE', 'Sevilla', '塞維利亞', '塞维利亚', 37.3753501, -6.0250973),
(3996, 207, 'SO', 'Soria', '索里亞', '索里亚', 41.7665464, -2.4790306),
(3997, 207, 'T', 'Tarragona', '塔拉戈納', '塔拉戈纳', 41.1258642, 1.2035642),
(3998, 207, 'TE', 'Teruel', '特魯埃爾', '特鲁埃尔', 40.3450410, -1.1184744),
(3999, 207, 'TO', 'Toledo', '托萊多', '托莱多', 39.8623200, -4.0694692),
(4000, 207, 'V', 'Valencia', '價', '原子价', 39.4840108, -0.7532809),
(4001, 207, 'VC', 'Valencian Community', '巴倫西亞社區', '巴伦西亚社区', 39.3108869, -1.7384172),
(4002, 207, 'VA', 'Valladolid', '巴利亞多利德', '巴利亚多利德', 41.6517375, -4.7244950),
(4003, 207, 'ZA', 'Zamora', '薩莫拉', '萨莫拉', 41.6095744, -5.8987139),
(4004, 207, 'Z', 'Zaragoza', '薩拉戈薩', '萨拉戈萨', 41.6517501, -0.9300002),
(4005, 208, '52', 'Ampara', '封面', '涵盖', 7.2911685, 81.6723761),
(4006, 208, '71', 'Anuradhapura', '阿努拉德普勒', '阿努拉德普勒', 8.3318305, 80.4029017),
(4007, 208, '81', 'Badulla', '巴杜拉', '巴杜拉', 6.9934009, 81.0549815),
(4008, 208, '51', 'Batticaloa', '拜蒂克洛', '拜蒂克洛', 7.8292781, 81.4718387),
(4009, 208, '2', 'Central', '中', '中央', 7.3816445, 80.0581296),
(4010, 208, '11', 'Colombo', '科倫坡', '科伦坡', 6.9269557, 79.8617306),
(4011, 208, '5', 'Eastern', '東', '东部', 7.7487176, 79.9936266),
(4012, 208, '31', 'Galle', '加勒', '加勒', 6.0577490, 80.2175572),
(4013, 208, '12', 'Gampaha', '甘帕哈', '甘帕哈', 7.0712619, 80.0087746),
(4014, 208, '33', 'Hambantota', '漢班托塔', '汉班托塔', 6.1535816, 81.1271490),
(4015, 208, '41', 'Jaffna', '賈夫納', '贾夫纳', 9.6930468, 80.1651854),
(4016, 208, '13', 'Kalutara', '卡盧塔拉', '卡卢塔拉', 6.6084686, 80.1428584),
(4017, 208, '21', 'Kandy', '康提', '凯迪', 7.2931588, 80.6350107),
(4018, 208, '92', 'Kegalle', '凱加勒', '凯加勒', 7.1204053, 80.3213106),
(4019, 208, '42', 'Kilinochchi', '基利諾奇', '基利诺奇', 9.3677971, 80.3213106),
(4020, 208, '61', 'Kurunegala', '庫魯內加拉', '库鲁内加拉', 7.7285647, 79.9089170),
(4021, 208, '43', 'Mannar', '馬納爾', '马纳尔', 8.9809531, 79.9043975),
(4022, 208, '22', 'Matale', '馬塔萊', '马塔莱', 7.4659646, 80.6234259),
(4023, 208, '32', 'Matara', '開', '打开', 5.9449348, 80.5487997),
(4024, 208, '82', 'Monaragala', '莫納拉加拉', '莫纳拉加拉', 6.8727781, 81.3506832),
(4025, 208, '45', 'Mullaitivu', '穆萊蒂武', '穆莱蒂武', 9.2675388, 80.8128254),
(4026, 208, '7', 'North Central', '中北部', '中北部', 8.1995638, 80.6326916),
(4027, 208, '6', 'North Western', '西北', '西北', 7.7584091, 80.1875065),
(4028, 208, '4', 'Northern', '北', '北方', 9.3723833, 79.8471377),
(4029, 208, '23', 'Nuwara Eliya', '努沃勒埃利耶', '努沃勒埃利耶', 6.9606532, 80.7692758),
(4030, 208, '72', 'Polonnaruwa', '波隆納魯沃', '波隆纳鲁沃', 7.9395567, 81.0003403),
(4031, 208, '62', 'Puttalam', '普塔蘭', '普塔兰', 8.0259915, 79.8471272),
(4032, 208, '91', 'Ratnapura', '拉特納普勒', '拉特纳普勒', 6.7055168, 80.3848389),
(4033, 208, '9', 'Sabaragamuwa', '薩巴拉加穆瓦', '萨巴拉加穆瓦', 6.7395941, 80.3658650),
(4034, 208, '3', 'Southern', '南方的', '南部', 6.2503650, 79.5250388),
(4035, 208, '53', 'Trincomalee', '亭可馬里', '亭可马里', 8.6013069, 81.1196075),
(4036, 208, '8', 'Uva', '葡萄', '葡萄', 6.8427612, 81.3399414),
(4037, 208, '44', 'Vavuniya', '瓦武尼亞', '瓦武尼亚', 8.7594739, 80.5000334),
(4038, 208, '1', 'Western', '西方的', '西方', 6.8282350, 79.7686403),
(4039, 209, 'GZ', 'Al Jazirah', '賈齊拉', '贾齐拉', 14.8859611, 33.4383530),
(4040, 209, 'GD', 'Al Qadarif', '卡達里夫', '卡达里夫', 14.0243070, 35.3685679),
(4041, 209, 'NB', 'Blue Nile', '青尼羅河', '青尼罗河', 47.5986730, -122.3344190),
(4042, 209, 'DC', 'Central Darfur', '達爾富爾中部', '中达尔富尔', 14.3782747, 24.9042208),
(4043, 209, 'DE', 'East Darfur', '東達爾富爾', '东达尔富尔', 14.3782747, 24.9042208),
(4044, 209, 'KA', 'Kassala', '卡薩拉', '卡萨拉', 15.4581332, 36.4039629),
(4045, 209, 'KH', 'Khartoum', '喀土穆', '喀土穆', 15.5006544, 32.5598994),
(4046, 209, 'DN', 'North Darfur', '北達爾富爾', '北达尔富尔', 15.7661969, 24.9042208),
(4047, 209, 'KN', 'North Kordofan', '北科爾多凡', '北科尔多凡州', 13.8306441, 29.4179324),
(4048, 209, 'NO', 'Northern', '北', '北方', 38.0638170, -84.4628648),
(4049, 209, 'RS', 'Red Sea', '紅海', '红海', 20.2802320, 38.5125730),
(4050, 209, 'NR', 'River Nile', '尼羅河', '尼罗河', 23.9727595, 32.8749206),
(4051, 209, 'SI', 'Sennar', '塞納爾', '塞纳尔', 13.5674690, 33.5672045),
(4052, 209, 'DS', 'South Darfur', '南達爾富爾', '南达尔富尔', 11.6488639, 24.9042208),
(4053, 209, 'KS', 'South Kordofan', '南科爾多凡', '南科尔多凡州', 11.1990192, 29.4179324),
(4054, 209, 'DW', 'West Darfur', '西達爾富爾', '西达尔富尔', 12.8463561, 23.0011989),
(4055, 209, 'GK', 'West Kordofan', '西科爾多凡', '西科尔多凡', 11.1990192, 29.4179324),
(4056, 209, 'NW', 'White Nile', '白尼羅河', '白尼罗河', 9.3321516, 31.4615300),
(4057, 210, 'BR', 'Brokopondo', '布羅科蓬多', '布罗科蓬多', 4.7710247, -55.0493375),
(4058, 210, 'CM', 'Commewijne', 'Commewijne', 'Commewijne', 5.7402110, -54.8731219),
(4059, 210, 'CR', 'Coronie', '電暈', '日冕', 5.6943271, -56.2929381),
(4060, 210, 'MA', 'Marowijne', 'Marowijne', 'Marowijne', 5.6268128, -54.2593118),
(4061, 210, 'NI', 'Nickerie', '尼克里', '尼克里', 5.5855469, -56.8311117),
(4062, 210, 'PR', 'Para', '為', '为', 5.4817318, -55.2259207),
(4063, 210, 'PM', 'Paramaribo', '帕拉馬里博', '帕拉马里博', 5.8520355, -55.2038278),
(4064, 210, 'SA', 'Saramacca', '薩拉馬卡', '萨拉马卡', 5.7240813, -55.6689636),
(4065, 210, 'SI', 'Sipaliwini', '西帕利文', '西帕利文', 3.6567382, -56.2035387),
(4066, 210, 'WA', 'Wanica', '萬妮卡', '万尼卡', 5.7323762, -55.2701235),
(4067, 213, 'K', 'Blekinge', '布萊金格', '布莱金格', 56.2833333, 15.1166667),
(4068, 213, 'W', 'Dalarna', '達拉納', '达拉纳', 61.0917012, 14.6663653),
(4069, 213, 'X', 'Gävleborg', '耶夫勒堡', '耶夫勒堡', 61.3011993, 16.1534214),
(4070, 213, 'I', 'Gotland', '哥特蘭島', '哥特兰岛', 57.4684121, 18.4867447),
(4071, 213, 'N', 'Halland', '哈蘭德', '哈兰', 56.8966805, 12.8033993),
(4072, 213, 'Z', 'Jämtland', '耶姆特蘭', '耶姆特兰', 63.2830620, 14.2382810),
(4073, 213, 'F', 'Jönköping', '延雪平', '延雪平', 57.3708434, 14.3439174),
(4074, 213, 'H', 'Kalmar', '卡爾馬', '卡尔马', 57.2350156, 16.1849349),
(4075, 213, 'G', 'Kronoberg', '克羅諾貝格', '克罗诺贝格', 56.7183403, 14.4114673),
(4076, 213, 'BD', 'Norrbotten', '北博滕', '北博滕', 66.8309216, 20.3991966),
(4077, 213, 'T', 'Örebro', '厄勒布魯', '厄勒布鲁', 59.5350360, 15.0065731),
(4078, 213, 'E', 'Östergötland', '東約特蘭', '东约特兰', 58.3453635, 15.5197844),
(4079, 213, 'M', 'Skåne', '斯科訥', '斯科讷', 55.9902572, 13.5957692),
(4080, 213, 'D', 'Södermanland', '南德曼蘭', '南德曼兰', 59.0336349, 16.7518899),
(4081, 213, 'AB', 'Stockholm', '斯德哥爾摩', '斯德哥尔摩', 59.6024958, 18.1384383),
(4082, 213, 'C', 'Uppsala', '烏普薩拉', '乌普萨拉', 60.0092262, 17.2714588),
(4083, 213, 'S', 'Värmland', '韋姆蘭', '韦姆兰', 59.7294065, 13.2354024),
(4084, 213, 'AC', 'Västerbotten', 'Västerbotten', 'Västerbotten', 65.3337311, 16.5161694),
(4085, 213, 'Y', 'Västernorrland', '韋斯特諾爾蘭', 'Västernorrland', 63.4276473, 17.7292444),
(4086, 213, 'U', 'Västmanland', 'Västmanland', 'Västmanland', 59.6713879, 16.2158953),
(4087, 213, 'O', 'Västra Götaland', 'Västra Götaland', 'Västra Götaland酒店', 58.2527926, 13.0596425),
(4088, 214, 'AG', 'Aargau', '阿爾高', '阿尔高', 47.3876664, 8.2554295),
(4089, 214, 'AR', 'Appenzell Ausserrhoden', '阿彭策爾 Ausserrhoden', '阿彭策尔·奥瑟罗登', 47.3664810, 9.3000916),
(4090, 214, 'AI', 'Appenzell Innerrhoden', '阿彭策爾內羅登', '阿彭策尔内罗登', 47.3161925, 9.4316573),
(4091, 214, 'BL', 'Basel-Land', '巴塞爾樂園', '巴塞尔兰', 47.4418122, 7.7644002),
(4092, 214, 'BS', 'Basel-Stadt', '施塔特', '施塔特', 47.5666670, 7.6000000),
(4093, 214, 'BE', 'Bern', '伯爾尼', '伯尔尼', 46.7988621, 7.7080701),
(4094, 214, 'FR', 'Fribourg', '弗里堡', '弗里堡', 46.6816748, 7.1172635),
(4095, 214, 'GE', 'Geneva', '日內瓦', '日内瓦', 46.2180073, 6.1216925),
(4096, 214, 'GL', 'Glarus', '格拉魯斯', '格拉鲁斯', 47.0411232, 9.0679000),
(4097, 214, 'GR', 'Graubünden', '格勞賓登州', '格劳宾登州', 46.6569871, 9.5780257),
(4098, 214, 'JU', 'Jura', '典', '法律', 47.3444474, 7.1430608),
(4099, 214, 'LU', 'Lucerne', '蓿', '苜蓿', 47.0795671, 8.1662445),
(4100, 214, 'NE', 'Neuchâtel', '納沙泰爾', '纳沙泰尔', 46.9899874, 6.9292732),
(4101, 214, 'NW', 'Nidwalden', '下瓦爾登', '下瓦尔登', 46.9267016, 8.3849982),
(4102, 214, 'OW', 'Obwalden', '上瓦爾登', '上瓦尔登湖', 46.8778580, 8.2512490),
(4103, 214, 'SH', 'Schaffhausen', '沙夫豪森', '沙夫豪森', 47.7009364, 8.5680040),
(4104, 214, 'SZ', 'Schwyz', '施維茲', '施维茨', 47.0207138, 8.6529884),
(4105, 214, 'SO', 'Solothurn', '索洛圖恩', '索洛图恩', 47.3320717, 7.6388385),
(4106, 214, 'SG', 'St. Gallen', '聖加侖', '圣加仑', 47.1456254, 9.3504332),
(4107, 214, 'TG', 'Thurgau', '圖爾高', '图尔高', 47.6037856, 9.0557371),
(4108, 214, 'TI', 'Ticino', '提契諾州', '提契诺州', 46.3317340, 8.8004529),
(4109, 214, 'UR', 'Uri', '你是嗎', '你是', 41.4860647, -71.5308537),
(4110, 214, 'VS', 'Valais', '瓦萊州', '瓦莱州', 46.1904614, 7.5449226),
(4111, 214, 'VD', 'Vaud', '沃州', '沃州', 46.5613135, 6.5367650),
(4112, 214, 'ZG', 'Zug', '火車', '火车', 47.1661505, 8.5154749),
(4113, 214, 'ZH', 'Zürich', '蘇黎世', '苏黎士', 47.3595360, 8.6356452),
(4114, 215, 'HA', 'Al-Hasakah', '哈塞克', '哈塞克', 36.4055150, 40.7969149),
(4115, 215, 'RA', 'Al-Raqqah', '拉卡', '拉卡', 35.9594106, 38.9981052),
(4116, 215, 'HL', 'Aleppo', '阿勒頗', '阿勒颇', 36.2262393, 37.4681396),
(4117, 215, 'SU', 'As-Suwayda', '阿斯-蘇韋達', '阿斯-苏韦达', 32.7989156, 36.7819505),
(4118, 215, 'DI', 'Damascus', '大馬士革', '大马士革', 33.5151444, 36.3931354),
(4119, 215, 'DR', 'Daraa', '達拉', '达拉', 32.9248813, 36.1762615),
(4120, 215, 'DY', 'Deir ez-Zor', '代爾祖爾', '代尔祖尔', 35.2879798, 40.3088626),
(4121, 215, 'HM', 'Hama', '兄弟', '兄弟', 35.1887865, 37.2115829),
(4122, 215, 'HI', 'Homs', '霍姆斯', '霍姆斯', 34.2567123, 38.3165725),
(4123, 215, 'ID', 'Idlib', '伊德利卜', '伊德利卜', 35.8268798, 36.6957216),
(4124, 215, 'LA', 'Latakia', '拉塔基亞', '拉塔基亚', 35.6129791, 36.0023225),
(4125, 215, 'QU', 'Quneitra', '庫奈特拉', '库奈特拉', 33.0776318, 35.8934136),
(4126, 215, 'RD', 'Rif Dimashq', '里夫·迪馬什克', '里夫·迪马什克', 33.5167289, 36.9541070),
(4127, 215, 'TA', 'Tartus', '塔爾圖', '塔尔图', 35.0006652, 36.0023225),
(4128, 216, 'CHA', 'Changhua', '彰化', '彰化', 24.0517963, 120.5161352),
(4129, 216, 'CYI', 'Chiayi', '嘉義', '嘉义', 23.4518428, 120.2554615),
(4130, 216, 'CYQ', 'Chiayi', '嘉義', '嘉义', 23.4800751, 120.4491113),
(4131, 216, 'HSQ', 'Hsinchu', '新竹', '新竹', 24.8387226, 121.0177246),
(4132, 216, 'HSZ', 'Hsinchu', '新竹', '新竹', 24.8138287, 120.9674798),
(4133, 216, 'HUA', 'Hualien', '花蓮', '花莲', 23.9871589, 121.6015714),
(4134, 216, 'KHH', 'Kaohsiung', '高雄', '高雄', 22.6272784, 120.3014353),
(4135, 216, 'KEE', 'Keelung', '基隆', '基隆', 25.1241862, 121.6475834),
(4136, 216, 'KIN', 'Kinmen', '金門', '金门', 24.3487792, 118.3285644),
(4137, 216, 'LIE', 'Lienchiang', '連江', '连江', 26.1505556, 119.9288889),
(4138, 216, 'MIA', 'Miaoli', '苗栗', '苗栗', 24.5601590, 120.8214265),
(4139, 216, 'NAN', 'Nantou', '南投', '南投', 23.9609981, 120.9718638),
(4140, 216, 'NWT', 'New Taipei', '新北', '新北', 24.9875278, 121.3645947),
(4141, 216, 'PEN', 'Penghu', '澎湖', '澎湖', 23.5711899, 119.5793157),
(4142, 216, 'PIF', 'Pingtung', '屏東', '屏东', 22.5519759, 120.5487597),
(4143, 216, 'TXG', 'Taichung', '台中', '台中', 24.1477358, 120.6736482),
(4144, 216, 'TNN', 'Tainan', '台南', '台南', 22.9997281, 120.2270277),
(4145, 216, 'TPE', 'Taipei', '舺', '台北', 25.0329694, 121.5654177),
(4146, 216, 'TTT', 'Taitung', '台東', '台东', 22.7972447, 121.0713702),
(4147, 216, 'TAO', 'Taoyuan', '桃園', '桃园', 24.9936281, 121.3009798),
(4148, 216, 'ILA', 'Yilan', '宜蘭', '宜兰', 24.7021073, 121.7377502),
(4149, 216, 'YUN', 'Yunlin', '雲林', '云林', 23.7092033, 120.4313373),
(4150, 217, 'GB', 'Gorno-Badakhshan', '戈爾諾-巴達赫尚', '戈尔诺-巴达赫尚', 38.4127320, 73.0877490),
(4151, 217, 'KT', 'Khatlon', '哈特隆', '哈特隆', 37.9113562, 69.0970230),
(4152, 217, 'RA', 'Nohiyahoi Tobei Jumhurí ', 'Nohiyahoi Tobei Jumhurí', 'Nohiyahoi Tobei Jumhurí', 39.0857902, 70.2408325),
(4153, 217, 'SU', 'Sughd ', '蘇格德', '苏格德', 39.5155326, 69.0970230),
(4154, 218, '01', 'Arusha', '阿魯沙', '阿鲁沙', -3.3869254, 36.6829927),
(4155, 218, '02', 'Dar es Salaam', '達累斯薩拉姆', '达累斯萨拉姆', -6.7923540, 39.2083284),
(4156, 218, '03', 'Dodoma', '多多馬', '多多马', -6.5738228, 36.2630846),
(4157, 218, '27', 'Geita', '蓋塔', '盖塔', -2.8242257, 32.2653887),
(4158, 218, '04', 'Iringa', '絞刑', '绞刑', -7.7887442, 35.5657862),
(4159, 218, '05', 'Kagera', '卡蓋拉', '卡盖拉', -1.3001115, 31.2626366),
(4160, 218, '28', 'Katavi', '卡塔維', '卡塔维', -6.3677125, 31.2626366),
(4161, 218, '08', 'Kigoma', '基戈馬', '基戈马', -4.8824092, 29.6615055),
(4162, 218, '09', 'Kilimanjaro', '乞力馬扎羅山', '乞力马扎罗山', -4.1336927, 37.8087693),
(4163, 218, '12', 'Lindi', '林迪', '林迪', -9.2343394, 38.3165725),
(4164, 218, '26', 'Manyara', '曼雅拉', '曼雅拉', -4.3150058, 36.9541070),
(4165, 218, '13', 'Mara', '瑪拉', '玛拉', -1.7753538, 34.1531947),
(4166, 218, '14', 'Mbeya', '姆貝亞', '姆贝亚', -8.2866112, 32.8132537),
(4167, 218, '16', 'Morogoro', '莫羅戈羅', '莫罗戈罗', -8.8137173, 36.9541070),
(4168, 218, '17', 'Mtwara', '姆特瓦拉', '姆特瓦拉', -10.3398455, 40.1657466),
(4169, 218, '18', 'Mwanza', '姆萬扎', '姆万扎', -2.4671197, 32.8986812),
(4170, 218, '29', 'Njombe', '恩瓊貝', '恩琼贝', -9.2422632, 35.1268781),
(4171, 218, '06', 'Pemba North', '奔巴北', '奔巴北', -5.0319352, 39.7755571),
(4172, 218, '10', 'Pemba South', '奔巴南', '奔巴南', -5.3146961, 39.7549511),
(4173, 218, '19', 'Pwani', '普瓦尼', '普瓦尼', -7.3237714, 38.8205454),
(4174, 218, '20', 'Rukwa', '魯克瓦', '鲁夸', -8.0109444, 31.4456179),
(4175, 218, '21', 'Ruvuma', '魯武馬', '鲁武马', -10.6878717, 36.2630846),
(4176, 218, '22', 'Shinyanga', '新揚加', '新扬加', -3.6809961, 33.4271403),
(4177, 218, '30', 'Simiyu', '西米尤', '思米玉', -2.8308738, 34.1531947),
(4178, 218, '23', 'Singida', '辛吉達', '辛吉达', -6.7453352, 34.1531947),
(4179, 218, '31', 'Songwe', '松圭', '松圭', -8.2726120, 31.7113174),
(4180, 218, '24', 'Tabora', '塔博拉', '塔博拉', -5.0342138, 32.8084496),
(4181, 218, '25', 'Tanga', '丁字褲', '皮带', -5.3049789, 38.3165725),
(4182, 218, '07', 'Zanzibar North', '桑給巴爾北部', '桑给巴尔北部', -5.9395093, 39.2791011),
(4183, 218, '11', 'Zanzibar South', '桑給巴爾南部', '桑给巴尔南部', -6.2642851, 39.4450281),
(4184, 218, '15', 'Zanzibar West', '桑給巴爾西', '桑给巴尔西', -6.2298136, 39.2583293),
(4185, 219, '37', 'Amnat Charoen', '阿姆納特·查倫', '阿姆纳特·查伦', 15.8656783, 104.6257774),
(4186, 219, '15', 'Ang Thong', '安通', '安通', 14.5896054, 100.4550520),
(4187, 219, '10', 'Bangkok', '曼谷', '曼谷', 13.7563309, 100.5017651),
(4188, 219, '38', 'Bueng Kan', '邦坎', '简邦', 18.3609104, 103.6464463),
(4189, 219, '31', 'Buri Ram', '武里南', '武里南', 14.9951003, 103.1115915),
(4190, 219, '24', 'Chachoengsao', '北柳府', '北柳府', 13.6904194, 101.0779596),
(4191, 219, '18', 'Chai Nat', '柴納特', '柴纳特', 15.1851971, 100.1251250),
(4192, 219, '36', 'Chaiyaphum', '柴亞普姆', '柴亚普姆', 16.0074974, 101.6129172),
(4193, 219, '22', 'Chanthaburi', '尖竹汶府', '尖竹汶府', 12.6112485, 102.1037806),
(4194, 219, '50', 'Chiang Mai', '清邁', '清迈', 18.7883439, 98.9853008),
(4195, 219, '57', 'Chiang Rai', '清萊', '清莱', 19.9104798, 99.8405760),
(4196, 219, '20', 'Chon Buri', '春武里府', '春武里府', 13.3611431, 100.9846717),
(4197, 219, '86', 'Chumphon', '春蓬', '春蓬', 10.4930496, 99.1800199),
(4198, 219, '46', 'Kalasin', '卡拉辛', '卡拉辛', 16.4385080, 103.5060994),
(4199, 219, '62', 'Kamphaeng Phet', '甘烹碧', '甘烹碧', 16.4827798, 99.5226618),
(4200, 219, '71', 'Kanchanaburi', '北碧府', '北碧府', 14.1011393, 99.4179431),
(4201, 219, '40', 'Khon Kaen', '孔敬', '孔敬', 16.4321938, 102.8236214),
(4202, 219, '81', 'Krabi', '甲米', '甲米', 8.0862997, 98.9062835),
(4203, 219, '52', 'Lampang', '南邦', '南邦', 18.2855395, 99.5127895),
(4204, 219, '51', 'Lamphun', '南奔', '南奔', 18.5744606, 99.0087221),
(4205, 219, '42', 'Loei', '黎府', '乐府', 17.4860232, 101.7223002),
(4206, 219, '16', 'Lop Buri', '羅布武里府', '罗布武里府', 14.7995081, 100.6533706),
(4207, 219, '58', 'Mae Hong Son', '美宏孫', '梅洪孙', 19.3020296, 97.9654368),
(4208, 219, '44', 'Maha Sarakham', '瑪哈·薩拉卡姆', '玛哈·萨拉卡姆', 16.0132015, 103.1615169),
(4209, 219, '49', 'Mukdahan', '杜塞爾多夫', '杜塞尔多夫', 16.5435914, 104.7024121),
(4210, 219, '26', 'Nakhon Nayok', '那空那育', '那空那育', 14.2069466, 101.2130511),
(4211, 219, '73', 'Nakhon Pathom', '佛統府', '佛统府', 13.8140293, 100.0372929),
(4212, 219, '48', 'Nakhon Phanom', '呵空帕侬', '那空帕侬', 17.3920390, 104.7695508),
(4213, 219, '30', 'Nakhon Ratchasima', '呵叻府', '呵叻府', 14.9738493, 102.0836520),
(4214, 219, '60', 'Nakhon Sawan', '那空沙旺', '那空沙旺', 15.6987382, 100.1199600),
(4215, 219, '80', 'Nakhon Si Thammarat', '那空府', '呵空府', 8.4324831, 99.9599033),
(4216, 219, '55', 'Nan', '在', '在', 45.5222080, -122.9863281),
(4217, 219, '96', 'Narathiwat', '那拉提瓦', '那拉提瓦', 6.4254607, 101.8253143),
(4218, 219, '39', 'Nong Bua Lam Phu', 'Nong Bua Lam Phu', 'Nong Bua Lam Phu', 17.2218247, 102.4260368),
(4219, 219, '43', 'Nong Khai', '廊開', '廊开', 17.8782803, 102.7412638),
(4220, 219, '12', 'Nonthaburi', '暖武里府', '暖武里府', 13.8591084, 100.5216508),
(4221, 219, '13', 'Pathum Thani', '巴吞他尼府', '巴吞他尼', 14.0208391, 100.5250276),
(4222, 219, '94', 'Pattani', '北大年島', '北大年岛', 6.7618308, 101.3232549),
(4223, 219, 'S', 'Pattaya', '芭達雅', '芭堤雅', 12.9235557, 100.8824551),
(4224, 219, '82', 'Phangnga', '攀牙', '攀牙', 8.4501414, 98.5255317),
(4225, 219, '93', 'Phatthalung', '帕他隆', '帕他隆', 7.6166823, 100.0740231),
(4226, 219, '56', 'Phayao', '帕堯', '帕夭', 19.2154367, 100.2023692),
(4227, 219, '67', 'Phetchabun', '碧差汶', '碧差汶', 16.3016690, 101.1192804),
(4228, 219, '76', 'Phetchaburi', '碧武里府', '碧武里府', 12.9649215, 99.6425883),
(4229, 219, '66', 'Phichit', '披支', '披支', 16.2740876, 100.3346991),
(4230, 219, '65', 'Phitsanulok', '彭世洛', '彭世洛', 16.8211238, 100.2658516),
(4231, 219, '14', 'Phra Nakhon Si Ayutthaya', '帕那空大城府', '帕那空大城府', 14.3692325, 100.5876634),
(4232, 219, '54', 'Phrae', '帕府', '帕府', 18.1445774, 100.1402831),
(4233, 219, '83', 'Phuket', '普吉島', '普吉岛', 7.8804479, 98.3922504),
(4234, 219, '25', 'Prachin Buri', '巴真武里府', '巴真武里府', 14.0420699, 101.6600874),
(4235, 219, '77', 'Prachuap Khiri Khan', '巴蜀希里汗', '巴蜀基里汗', 11.7938389, 99.7957564),
(4236, 219, '85', 'Ranong', '拉廊府', '拉廊府', 9.9528702, 98.6084641),
(4237, 219, '70', 'Ratchaburi', '叻丕府', '叻丕府', 13.5282893, 99.8134211),
(4238, 219, '21', 'Rayong', '聖保羅', '圣保罗', 12.6813957, 101.2816261),
(4239, 219, '45', 'Roi Et', '國王和', 'King 和', 16.0538196, 103.6520036),
(4240, 219, '27', 'Sa Kaeo', '薩凱奧', '萨凯奥', 13.8240380, 102.0645839),
(4241, 219, '47', 'Sakon Nakhon', '左空那空', '左空那空', 17.1664211, 104.1486055),
(4242, 219, '11', 'Samut Prakan', '北欖府', '北榄府', 13.5990961, 100.5998319),
(4243, 219, '74', 'Samut Sakhon', '北欖沙空', '北榄府', 13.5475216, 100.2743956),
(4244, 219, '75', 'Samut Songkhram', '北功城', '北榄府宋卡兰', 13.4098217, 100.0022645),
(4245, 219, '19', 'Saraburi', '北武里府', '北武里府', 14.5289154, 100.9101421),
(4246, 219, '91', 'Satun', '緞', '缎', 6.6238158, 100.0673744),
(4247, 219, '33', 'Si Sa Ket', '四沙吉', '四沙吉', 15.1186009, 104.3220095),
(4248, 219, '17', 'Sing Buri', '新武里', '新武里', 14.8936253, 100.3967314),
(4249, 219, '90', 'Songkhla', '宋卡', '宋卡府', 7.1897659, 100.5953813),
(4250, 219, '64', 'Sukhothai', '素可泰', '素可泰', 43.6485556, -79.3746639),
(4251, 219, '72', 'Suphan Buri', '素攀武里府', '素攀武里府', 14.4744892, 100.1177128),
(4252, 219, '84', 'Surat Thani', '素叻他尼', '素叻他尼', 9.1341949, 99.3334198),
(4253, 219, '32', 'Surin', '蘇林', '苏林', 37.0358271, -95.6276367),
(4254, 219, '63', 'Tak', '是', '是的', 45.0299646, -93.1049815),
(4255, 219, '92', 'Trang', '頁', '页', 7.5644833, 99.6239334),
(4256, 219, '23', 'Trat', '被踢', '踢', 12.2427563, 102.5174734),
(4257, 219, '34', 'Ubon Ratchathani', '烏汶叻府', '乌汶叻府', 15.2448453, 104.8472995),
(4258, 219, '41', 'Udon Thani', '烏隆他尼', '乌隆他尼', 17.3646969, 102.8158924),
(4259, 219, '61', 'Uthai Thani', '烏泰他尼', '乌泰他尼', 15.3835001, 100.0245527),
(4260, 219, '53', 'Uttaradit', '北拉迪特', '北拉迪特', 17.6200886, 100.0992942),
(4261, 219, '95', 'Yala', '雅拉', '雅拉', 44.0579117, -123.1653848),
(4262, 219, '35', 'Yasothon', '亞索通', '亚索通', 15.7926410, 104.1452827),
(4263, 17, 'AK', 'Acklins', '阿克林斯', '阿克林斯', 22.3657708, -74.0535126),
(4264, 17, 'AC', 'Acklins and Crooked Islands', '阿克林斯和彎曲群島', '阿克林斯和弯曲群岛', 22.3657708, -74.0535126),
(4265, 17, 'BY', 'Berry Islands', '貝里群島', '贝里群岛', 25.6250042, -77.8252203),
(4266, 17, 'BI', 'Bimini', '比米尼島', '比米尼岛', 24.6415325, -79.8506226),
(4267, 17, 'BP', 'Black Point', '黑點', '黑点', 41.3951024, -71.4650556),
(4268, 17, 'CI', 'Cat Island', '貓島', '猫岛', 30.2280136, -89.1014933);
INSERT INTO `location_states` (`state_id`, `country_id`, `state_code`, `state_name_en`, `state_name_zh_tw`, `state_name_zh_cn`, `state_center_latitude`, `state_center_longitude`) VALUES
(4269, 17, 'CO', 'Central Abaco', '阿巴科中部', '阿巴科中部', 26.3555029, -77.1485163),
(4270, 17, 'CS', 'Central Andros', '安德羅斯島中部', '安德罗斯岛中部', 24.4688482, -77.9738650),
(4271, 17, 'CE', 'Central Eleuthera', '中伊柳塞拉島', '中伊柳塞拉', 25.1362037, -76.1435915),
(4272, 17, 'CK', 'Crooked Island', '彎曲島', '弯曲岛', 22.6390982, -74.0065090),
(4273, 17, 'EG', 'East Grand Bahama', '東大巴哈馬', '东大巴哈马', 26.6582823, -78.2248291),
(4274, 17, 'EX', 'Exuma', '埃克蘇馬', '埃克苏马', 23.6192598, -75.9695465),
(4275, 17, 'FP', 'Freeport', '自由港', '自由港', 42.2966861, -89.6212271),
(4276, 17, 'FC', 'Fresh Creek', '新鮮溪', '新鲜溪', 40.6543756, -73.8947939),
(4277, 17, 'GH', 'Governor\'s Harbour', '統治者', '总督', 25.1948096, -76.2439622),
(4278, 17, 'GC', 'Grand Cay', '大島', '大岛', 27.2162615, -78.3230559),
(4279, 17, 'GT', 'Green Turtle Cay', '綠海龜礁', '绿海龟礁', 26.7747107, -77.3295708),
(4280, 17, 'HI', 'Harbour Island', '海港島', '海港岛', 25.5001100, -76.6340511),
(4281, 17, 'HR', 'High Rock', '高岩', '高岩', 46.6843415, -121.9017461),
(4282, 17, 'HT', 'Hope Town', '希望小鎮', '希望小镇', 26.5009504, -76.9959872),
(4283, 17, 'IN', 'Inagua', '伊納瓜', '伊纳瓜', 21.0656066, -73.3237080),
(4284, 17, 'KB', 'Kemps Bay', '坎普斯灣', '坎普斯湾', 24.0236400, -77.5453490),
(4285, 17, 'LI', 'Long Island', '長島', '长岛', 40.7891420, -73.1349610),
(4286, 17, 'MC', 'Mangrove Cay', '紅樹林島', '红树林岛', 24.1481425, -77.7680952),
(4287, 17, 'MH', 'Marsh Harbour', '馬什港', '马什港', 26.5241653, -77.0909809),
(4288, 17, 'MG', 'Mayaguana', '瑪雅瓜納', '玛雅瓜纳', 22.4017714, -73.0641396),
(4289, 17, 'NP', 'New Providence', '新普羅維登斯', '新普罗维登斯', 40.6984348, -74.4015405),
(4290, 17, 'NB', 'Nichollstown and Berry Islands', '尼科爾斯敦和貝里群島', '尼科尔斯敦和贝里群岛', 25.7236234, -77.8310104),
(4291, 17, 'NO', 'North Abaco', '北阿巴科', '北阿巴科', 26.7871697, -77.4357739),
(4292, 17, 'NS', 'North Andros', '北安德羅斯島', '北安德罗斯岛', 24.7063805, -78.0195387),
(4293, 17, 'NE', 'North Eleuthera', '北伊柳塞拉島', '北伊柳塞拉', 25.4647517, -76.6759220),
(4294, 17, 'RI', 'Ragged Island', '衣衫襤褸島', '衣衫褴褛的岛屿', 41.5974310, -71.2602020),
(4295, 17, 'RS', 'Rock Sound', '搖滾之聲', '摇滚之声', 39.0142443, -95.6708989),
(4296, 17, 'RC', 'Rum Cay', '朗姆島', '朗姆岛', 23.6854676, -74.8390162),
(4297, 17, 'SR', 'San Salvador and Rum Cay', '聖薩爾瓦多和蘭姆島', '圣萨尔瓦多和朗姆岛', 23.6854676, -74.8390162),
(4298, 17, 'SS', 'San Salvador Island', '聖薩爾瓦多島', '圣萨尔瓦多岛', 24.0775546, -74.4760088),
(4299, 17, 'SP', 'Sandy Point', '桑迪角', '桑迪角', 39.0145464, -76.3998925),
(4300, 17, 'SO', 'South Abaco', '南阿巴科', '南阿巴科', 26.0640591, -77.2635038),
(4301, 17, 'SA', 'South Andros', '南安德羅斯島', '南安德罗斯岛', 23.9713556, -77.6077865),
(4302, 17, 'SE', 'South Eleuthera', '南伊柳塞拉島', '南伊柳塞拉', 24.7708562, -76.2131474),
(4303, 17, 'SW', 'Spanish Wells', '西班牙維爾斯', '西班牙维尔斯', 26.3250599, -81.7980328),
(4304, 17, 'WG', 'West Grand Bahama', '西大巴哈馬', '西大巴哈马', 26.6594470, -78.5206500),
(4305, 80, 'B', 'Banjul', '班珠爾', '班珠尔', 13.4548761, -16.5790323),
(4306, 80, 'M', 'Central River', '中央河', '中央河', 13.5994469, -14.8921668),
(4307, 80, 'L', 'Lower River', '下河', '下河', 13.3553306, -15.9229900),
(4308, 80, 'N', 'North Bank', '北岸', '北岸', 13.5285436, -16.0169971),
(4309, 80, 'U', 'Upper River', '上河', '上河', 13.4257366, -14.0072348),
(4310, 80, 'W', 'West Coast', '西海岸', '西海岸', 5.9772798, 116.0754288),
(4311, 63, 'AL', 'Aileu', '艾勒', '艾鲁', -8.7043994, 125.6095474),
(4312, 63, 'AN', 'Ainaro', '愛納羅', '艾纳罗', -9.0113171, 125.5220012),
(4313, 63, 'BA', 'Baucau', '包考', '包考', -8.4714308, 126.4575991),
(4314, 63, 'BO', 'Bobonaro', '波波納羅', '波波纳罗', -8.9655406, 125.2587964),
(4315, 63, 'CO', 'Cova Lima', '科瓦利馬', '科瓦利马', -9.2650375, 125.2587964),
(4316, 63, 'DI', 'Dili', '語言', '语言', -8.2449613, 125.5876697),
(4317, 63, 'ER', 'Ermera', '埃爾梅拉', '埃尔梅拉', -8.7524802, 125.3987294),
(4318, 63, 'LA', 'Lautém', '勞特姆', '劳特姆', -8.3642307, 126.9043845),
(4319, 63, 'LI', 'Liquiçá', '液曲', '液曲', -8.6674095, 125.2587964),
(4320, 63, 'MT', 'Manatuto', '馬納圖托', '马纳图托', -8.5155608, 126.0159255),
(4321, 63, 'MF', 'Manufahi', '馬努法希', '马努法希', -9.0145495, 125.8279959),
(4322, 63, 'VI', 'Viqueque', '維克克', '维克克', -8.8597918, 126.3633516),
(4323, 220, 'C', 'Centrale', '中', '中央', 8.6586029, 1.0586135),
(4324, 220, 'K', 'Kara', '卡拉', '卡拉', 9.7216393, 1.0586135),
(4325, 220, 'M', 'Maritime', '海', '海事', 41.6551493, -83.5278467),
(4326, 220, 'P', 'Plateaux', '托盤', '托盘', 7.6101378, 1.0586135),
(4327, 220, 'S', 'Savanes', '薩瓦內斯', '萨瓦内斯', 10.5291781, 0.5257823),
(4328, 222, '02', 'Haʻapai', '哈派', '哈派', -19.7500000, -174.3666670),
(4329, 222, '01', 'ʻEua', '烏亞', '尤亚', 37.0902400, -95.7128910),
(4330, 222, '03', 'Niuas', '牛', '纽阿斯', -15.9594000, -173.7830000),
(4331, 222, '04', 'Tongatapu', '湯加塔普', '汤加塔普', -21.1465968, -175.2515482),
(4332, 222, '05', 'Vavaʻu', '瓦瓦烏', '瓦瓦乌', -18.6227560, -173.9902982),
(4333, 223, 'ARI', 'Arima', '有馬', '有马', 46.7931604, -71.2584311),
(4334, 223, 'CHA', 'Chaguanas', '查瓜納斯', '查瓜纳斯', 10.5168387, -61.4114482),
(4335, 223, 'CTT', 'Couva-Tabaquite-Talparo', '庫瓦-塔巴基特-塔爾帕羅', '库瓦-塔巴基特-塔尔帕罗', 10.4297145, -61.3735210),
(4336, 223, 'DMN', 'Diego Martin', '迭戈·馬丁', '迭戈·马丁', 10.7362286, -61.5544836),
(4337, 223, 'ETO', 'Eastern Tobago', '東多巴哥', '东多巴哥', 11.2979348, -60.5588524),
(4338, 223, 'PED', 'Penal-Debe', '刑事必須', '刑事必须', 10.1337402, -61.4435474),
(4339, 223, 'PTF', 'Point Fortin', '福廷角', '福廷角', 10.1702737, -61.6713386),
(4340, 223, 'POS', 'Port of Spain', '西班牙港', '西班牙港', 10.6603196, -61.5085625),
(4341, 223, 'PRT', 'Princes Town', '王子鎮', '王子镇', 10.1786746, -61.2801996),
(4342, 223, 'MRC', 'Rio Claro-Mayaro', '克拉羅-馬亞羅河', '克拉罗-马亚罗河', 10.2412832, -61.0937206),
(4343, 223, 'SFO', 'San Fernando', '聖費爾南多', '圣费尔南多', 34.2819461, -118.4389719),
(4344, 223, 'SJL', 'San Juan-Laventille', '聖胡安-拉文蒂爾', '圣胡安-拉文蒂尔', 10.6908578, -61.4552213),
(4345, 223, 'SGE', 'Sangre Grande', '大血', '大血', 10.5852939, -61.1315813),
(4346, 223, 'SIP', 'Siparia', '幕', '窗帘', 10.1245626, -61.5603244),
(4347, 223, 'TUP', 'Tunapuna-Piarco', '圖納普納-皮亞爾科', '图纳普纳-皮亚尔科', 10.6859096, -61.3035248),
(4348, 223, 'WTO', 'Western Tobago', '多巴哥西部', '西多巴哥', 11.1897072, -60.7795452),
(4349, 224, '12', 'Ariana', '阿麗亞娜', '艾丽安娜', 36.9922751, 10.1255164),
(4350, 224, '31', 'Béja', '貝賈', '贝扎语', 35.1722716, 8.8307626),
(4351, 224, '13', 'Ben Arous', '本·阿魯斯', '本·阿鲁斯', 36.6435606, 10.2151578),
(4352, 224, '23', 'Bizerte', '比塞大', '比塞大', 37.1609397, 9.6341350),
(4353, 224, '81', 'Gabès', '加布斯', '加布斯', 33.9459648, 9.7232673),
(4354, 224, '71', 'Gafsa', '加夫薩', '加夫萨', 34.3788505, 8.6600586),
(4355, 224, '32', 'Jendouba', '詹杜巴', '詹杜巴', 36.7181862, 8.7481167),
(4356, 224, '41', 'Kairouan', '凱魯萬', '凯鲁万', 35.6711663, 10.1005469),
(4357, 224, '42', 'Kasserine', '卡色林', '卡色林', 35.0809148, 8.6600586),
(4358, 224, '73', 'Kebili', '凱比利', '凯比利', 33.7071551, 8.9714623),
(4359, 224, '33', 'Kef', '凱夫', '凯夫', 36.1230512, 8.6600586),
(4360, 224, '53', 'Mahdia', '馬赫迪亞', '马赫迪亚', 35.3352558, 10.8903099),
(4361, 224, '14', 'Manouba', '馬努巴', '马努巴', 36.8446504, 9.8571416),
(4362, 224, '82', 'Medenine', '甲地寧', '甲地嘌呤', 33.2280565, 10.8903099),
(4363, 224, '52', 'Monastir', '莫納斯提爾', '莫纳斯提尔', 35.7642515, 10.8112885),
(4364, 224, '21', 'Nabeul', '納布爾', '纳布尔', 36.4524591, 10.6803222),
(4365, 224, '61', 'Sfax', '斯法克斯', '斯法克斯', 34.8606581, 10.3497895),
(4366, 224, '43', 'Sidi Bouzid', '西迪·布齊德', '西迪·布齐德', 35.0354386, 9.4839392),
(4367, 224, '34', 'Siliana', '西莉安娜', '西利亚纳', 36.0887208, 9.3645335),
(4368, 224, '51', 'Sousse', '蘇斯', '苏斯', 35.9022267, 10.3497895),
(4369, 224, '83', 'Tataouine', '塔塔萬', '塔塔因', 32.1344122, 10.0807298),
(4370, 224, '72', 'Tozeur', '托澤爾', '托泽尔', 33.9789491, 8.0465185),
(4371, 224, '11', 'Tunis', '突尼斯', '突尼斯', 36.8374946, 10.1927389),
(4372, 224, '22', 'Zaghouan', '扎古安', '扎古安', 36.4091188, 10.1423172),
(4373, 225, '01', 'Adana', '阿達納', '阿达纳', 37.2612315, 35.3905046),
(4374, 225, '02', 'Adıyaman', '阿迪亞曼', '阿迪亚曼', 37.9078291, 38.4849923),
(4375, 225, '03', 'Afyonkarahisar', '阿菲永卡拉希薩爾', '阿菲永卡拉希萨尔', 38.7391099, 30.7120023),
(4376, 225, '04', 'Ağrı', '疼痛', '疼痛', 39.6269218, 43.0215965),
(4377, 225, '68', 'Aksaray', '阿克薩賴', '阿克萨赖', 38.3352043, 33.9750018),
(4378, 225, '05', 'Amasya', '阿瑪西亞', '阿玛西亚', 40.6516608, 35.9037966),
(4379, 225, '06', 'Ankara', '安卡拉', '安卡拉', 39.7805245, 32.7181375),
(4380, 225, '07', 'Antalya', '安塔利亞', '安塔利亚', 37.0951672, 31.0793705),
(4381, 225, '75', 'Ardahan', '阿爾達漢', '阿尔达汉', 41.1112964, 42.7831674),
(4382, 225, '08', 'Artvin', '阿爾特文', '阿尔特文', 41.0786640, 41.7628223),
(4383, 225, '09', 'Aydın', '開明', '开明', 37.8117033, 28.4863963),
(4384, 225, '10', 'Balıkesir', '巴勒克西爾', 'Balıkesir', 39.7616782, 28.1122679),
(4385, 225, '74', 'Bartın', '巴廷', '巴廷', 41.5810509, 32.4609794),
(4386, 225, '72', 'Batman', '蝙蝠俠', '蝙蝠 侠', 37.8362496, 41.3605739),
(4387, 225, '69', 'Bayburt', '貝克', '面包师傅', 40.2603200, 40.2280480),
(4388, 225, '11', 'Bilecik', '比萊西克', '比莱西克', 40.0566555, 30.0665236),
(4389, 225, '12', 'Bingöl', '賓戈爾', '宾戈尔', 39.0626354, 40.7696095),
(4390, 225, '13', 'Bitlis', '比特利斯', '比特利斯', 38.6523133, 42.4202028),
(4391, 225, '14', 'Bolu', '博魯', '博卢', 40.5759766, 31.5788086),
(4392, 225, '15', 'Burdur', '伯杜爾', '伯杜尔', 37.4612669, 30.0665236),
(4393, 225, '16', 'Bursa', '布爾薩', '囊', 40.0655459, 29.2320784),
(4394, 225, '17', 'Çanakkale', '恰納卡萊', '恰纳卡莱', 40.0510104, 26.9852422),
(4395, 225, '18', 'Çankırı', 'Çankırı', 'Çankırı', 40.5369073, 33.5883893),
(4396, 225, '19', 'Çorum', '科魯姆', '科鲁姆', 40.4998211, 34.5986263),
(4397, 225, '20', 'Denizli', '代尼茲利', '代尼兹利', 37.6128395, 29.2320784),
(4398, 225, '21', 'Diyarbakır', '迪亞巴克爾', '迪亚巴克尔', 38.1066372, 40.5426896),
(4399, 225, '81', 'Düzce', '杜茲斯', '杜兹斯', 40.8770531, 31.3192713),
(4400, 225, '22', 'Edirne', '埃迪爾內', '埃迪尔内', 41.1517222, 26.5137964),
(4401, 225, '23', 'Elazığ', '埃拉齊格', '埃拉齐格', 38.4964804, 39.2199029),
(4402, 225, '24', 'Erzincan', '埃爾津坎', '埃尔津坎', 39.7681914, 39.0501306),
(4403, 225, '25', 'Erzurum', '埃爾祖魯姆', '埃尔祖鲁姆', 40.0746799, 41.6694562),
(4404, 225, '26', 'Eskişehir', '埃斯基謝希爾', '埃斯基谢希尔', 39.6329657, 31.2626366),
(4405, 225, '27', 'Gaziantep', '加濟安泰普', '加济安泰普', 37.0763882, 37.3827234),
(4406, 225, '28', 'Giresun', '吉雷松', '吉雷松', 40.6461672, 38.5935511),
(4407, 225, '29', 'Gümüşhane', '古穆沙內', '古穆沙内', 40.2803673, 39.3143253),
(4408, 225, '30', 'Hakkâri', '八卡里', '八卡里', 37.4459319, 43.7449841),
(4409, 225, '31', 'Hatay', '哈塔伊', '哈塔伊', 36.4018488, 36.3498097),
(4410, 225, '76', 'Iğdır', 'Iğdır', 'Iğdır', 39.8879841, 44.0048365),
(4411, 225, '32', 'Isparta', '伊斯帕爾塔', '伊斯帕尔塔', 38.0211464, 31.0793705),
(4412, 225, '34', 'İstanbul', '伊斯坦堡', '伊斯坦布尔', 41.1634302, 28.7664408),
(4413, 225, '35', 'İzmir', '伊茲密爾', '伊兹密尔', 38.3591693, 27.2676116),
(4414, 225, '46', 'Kahramanmaraş', '卡赫拉曼馬拉什', '卡赫拉曼马拉什', 37.7503036, 36.9541070),
(4415, 225, '78', 'Karabük', '卡拉布克', '卡拉布克', 41.1874890, 32.7417419),
(4416, 225, '70', 'Karaman', '卡拉曼', '卡拉曼', 37.2436336, 33.6175770),
(4417, 225, '36', 'Kars', '卡爾斯', '卡尔斯', 40.2807636, 42.9919527),
(4418, 225, '37', 'Kastamonu', '卡斯塔莫努', '卡斯塔莫努', 41.4103863, 33.6998334),
(4419, 225, '38', 'Kayseri', '開塞利', '开塞利', 38.6256854, 35.7406882),
(4420, 225, '79', 'Kilis', '基利斯', '基利斯', 36.8204775, 37.1687339),
(4421, 225, '71', 'Kırıkkale', 'Kırıkkale', 'Kırıkkale', 39.8876878, 33.7555248),
(4422, 225, '39', 'Kırklareli', 'Kırklareli', 'Kırklareli', 41.7259795, 27.4838390),
(4423, 225, '40', 'Kırşehir', 'Kırşehir', '克尔谢希尔', 39.2268905, 33.9750018),
(4424, 225, '41', 'Kocaeli', '科賈埃利', '科贾埃利', 40.8532704, 29.8815203),
(4425, 225, '42', 'Konya', '科尼亞', '科尼亚', 37.9838134, 32.7181375),
(4426, 225, '43', 'Kütahya', '庫塔希亞', '库塔希亚', 39.3581370, 29.6035495),
(4427, 225, '44', 'Malatya', '馬拉蒂亞', '马拉蒂亚', 38.4015057, 37.9536298),
(4428, 225, '45', 'Manisa', '馬尼薩', '马尼萨', 38.8419373, 28.1122679),
(4429, 225, '47', 'Mardin', '馬爾丁', '马尔丁', 37.3442929, 40.6196487),
(4430, 225, '33', 'Mersin', '梅爾辛', '梅尔辛', 36.8120858, 34.6414750),
(4431, 225, '48', 'Muğla', '穆拉', '穆拉', 37.1835819, 28.4863963),
(4432, 225, '49', 'Muş', '穆斯', '小家', 38.9461888, 41.7538931),
(4433, 225, '50', 'Nevşehir', '內夫謝希爾', '内夫谢希尔', 38.6939399, 34.6856509),
(4434, 225, '51', 'Niğde', 'Niğde', '尼德', 38.0993086, 34.6856509),
(4435, 225, '52', 'Ordu', '軍', '军队', 40.7990580, 37.3899005),
(4436, 225, '80', 'Osmaniye', '奧斯曼尼耶', '奥斯曼尼耶', 37.2130258, 36.1762615),
(4437, 225, '53', 'Rize', '里澤', '日泽', 40.9581497, 40.9226985),
(4438, 225, '54', 'Sakarya', '薩卡里亞', '萨卡里亚', 40.7888550, 30.4059540),
(4439, 225, '55', 'Samsun', '薩姆松', '萨姆松', 41.1864859, 36.1322678),
(4440, 225, '63', 'Şanlıurfa', 'Şanlıurfa', 'Şanlıurfa', 37.3569102, 39.1543677),
(4441, 225, '56', 'Siirt', '西爾特', '锡尔特', 37.8658862, 42.1494523),
(4442, 225, '57', 'Sinop', '錫諾普', '锡诺普', 41.5594749, 34.8580532),
(4443, 225, '58', 'Sivas', '西瓦斯', '西瓦斯', 39.4488039, 37.1294497),
(4444, 225, '73', 'Şırnak', '西爾納克', '锡尔纳克', 37.4187481, 42.4918338),
(4445, 225, '59', 'Tekirdağ', 'Tekirdag', '特基尔达格', 41.1121227, 27.2676116),
(4446, 225, '60', 'Tokat', '摑', '打', 40.3902713, 36.6251863),
(4447, 225, '61', 'Trabzon', '特拉布宗', '特拉布宗', 40.7992410, 39.5847944),
(4448, 225, '62', 'Tunceli', '通塞利', '通塞利', 39.3073554, 39.4387778),
(4449, 225, '64', 'Uşak', '追隨者', '心腹', 38.5431319, 29.2320784),
(4450, 225, '65', 'Van', '從', '从', 38.3679417, 43.7182787),
(4451, 225, '77', 'Yalova', '亞洛娃', '亚洛娃', 40.5775986, 29.2088303),
(4452, 225, '66', 'Yozgat', '約茲加特', '约兹加特', 39.7271979, 35.1077858),
(4453, 225, '67', 'Zonguldak', '宗古爾達克', '宗古尔达克', 41.3124917, 31.8598251),
(4454, 226, 'A', 'Ahal', '力', '权力', 38.6399398, 59.4720904),
(4455, 226, 'S', 'Ashgabat', '阿什哈巴德', '阿什哈巴德', 37.9600766, 58.3260629),
(4456, 226, 'B', 'Balkan', '巴爾幹半島', '巴尔干半岛', 41.8101472, 21.0937311),
(4457, 226, 'D', 'Daşoguz', 'Daşoguz', '达索古兹', 41.8368737, 59.9651904),
(4458, 226, 'L', 'Lebap', '勒巴普', '勒巴普', 38.1272462, 64.7162415),
(4459, 226, 'M', 'Mary', '瑪麗', '玛丽', 36.9481623, 62.4504154),
(4460, 227, '05', 'Grand Turk', '大特克', '大特克', 21.4680866, -71.1810258),
(4461, 227, '03', 'Middle Caicos', '中凱科斯群島', '中凯科斯群岛', 21.7785056, -71.9379770),
(4462, 227, '02', 'North Caicos', '北凱科斯群島', '北凯科斯群岛', 21.8759162, -72.0382028),
(4463, 227, '01', 'Providenciales', '天意的', '天赐', 21.8015618, -72.4083292),
(4464, 227, '06', 'Salt Cay', '鹽礁', '盐礁', 21.3242536, -71.2207606),
(4465, 227, '04', 'South Caicos', '南凱科斯群島', '南凯科斯群岛', 21.5302487, -71.5604486),
(4466, 228, 'FUN', 'Funafuti', '富納富提', '富纳富提', -8.5211471, 179.1961926),
(4467, 228, 'NMG', 'Nanumanga', '納努曼加', '纳努曼加', -6.2858019, 176.3199280),
(4468, 228, 'NMA', 'Nanumea', '納努梅亞', '纳努梅亚', -5.6881617, 176.1370148),
(4469, 228, 'NIT', 'Niutao Island Council', '牛濤島議會', '牛涛岛议会', -6.1064258, 177.3438429),
(4470, 228, 'NUI', 'Nui', '大', '大', -7.2388768, 177.1485232),
(4471, 228, 'NKF', 'Nukufetau', '努庫費托', '努库费陶', -8.0000000, 178.5000000),
(4472, 228, 'NKL', 'Nukulaelae', '努庫拉埃拉', '努库莱莱亚 Nukulaelae', -9.3811110, 179.8522220),
(4473, 228, 'VAI', 'Vaitupu', '泉', '喷泉', -7.4767327, 178.6747675),
(4474, 229, '314', 'Abim', '我的兄弟', '我的兄弟', 2.7066980, 33.6595337),
(4475, 229, '301', 'Adjumani', '阿朱馬尼', '阿朱马尼', 3.2548527, 31.7195459),
(4476, 229, '322', 'Agago', '阿戈格', '阿戈格', 2.9250820, 33.3486147),
(4477, 229, '323', 'Alebtong', '阿列通', '阿勒通', 2.2545773, 33.3486147),
(4478, 229, '315', 'Amolatar', '阿莫拉塔爾', '阿莫拉塔尔', 1.6054402, 32.8084496),
(4479, 229, '324', 'Amudat', '阿穆達特', '阿穆达特', 1.7916224, 34.9065510),
(4480, 229, '216', 'Amuria', '阿穆里亞', '阿穆里亚', 2.0301700, 33.6427533),
(4481, 229, '316', 'Amuru', '阿穆魯', '阿穆鲁', 2.9667878, 32.0837445),
(4482, 229, '302', 'Apac', '亞太地區', '亚太地区', 1.8730263, 32.6277455),
(4483, 229, '303', 'Arua', '阿魯阿', '阿鲁阿', 2.9959846, 31.1710389),
(4484, 229, '217', 'Budaka', '布達卡', '布达卡', 1.1016277, 33.9303991),
(4485, 229, '218', 'Bududa', '布杜達', '布杜达', 1.0029693, 34.3338123),
(4486, 229, '201', 'Bugiri', '布吉里', '布吉里', 0.5316127, 33.7517723),
(4487, 229, '235', 'Bugweri', '布格韋里', '布格韦里', 0.6222229, 33.4480547),
(4488, 229, '420', 'Buhweju', '布韋朱', '布韦朱', -0.2911359, 30.2974199),
(4489, 229, '117', 'Buikwe', '布伊奎', '布伊奎', 0.3144046, 32.9888319),
(4490, 229, '219', 'Bukedea', '布克迪亞', '布克迪亚', 1.3556898, 34.1086793),
(4491, 229, '118', 'Bukomansimbi', '布科曼辛比', '布科曼辛比', -0.1432752, 31.6054893),
(4492, 229, '220', 'Bukwo', '布克沃', '布克沃', 1.2818651, 34.7298765),
(4493, 229, '225', 'Bulambuli', '布蘭布利', '布兰布里', 1.4798846, 34.3754414),
(4494, 229, '416', 'Buliisa', '黨父', '党父', 2.0299607, 31.5370003),
(4495, 229, '401', 'Bundibugyo', '本迪布焦', '本迪布焦', 0.6851763, 30.0202964),
(4496, 229, '430', 'Bunyangabu', '布尼揚加布', '文扬加布', 0.4870918, 30.2051096),
(4497, 229, '402', 'Bushenyi', '布申尼', '布申义', -0.4870918, 30.2051096),
(4498, 229, '202', 'Busia', '布西亞', '布西亚', 0.4044731, 34.0195827),
(4499, 229, '221', 'Butaleja', '布塔萊哈', '布塔莱哈', 0.8474922, 33.8411288),
(4500, 229, '119', 'Butambala', '布坦巴拉', '布坦巴拉', 0.1742500, 32.1064668),
(4501, 229, '233', 'Butebo', '布特博', '布特博', 1.2141124, 33.9080896),
(4502, 229, '120', 'Buvuma', '出席', '存在', -0.3764912, 33.2587930),
(4503, 229, '226', 'Buyende', '買', '买', 1.2413682, 33.1239049),
(4504, 229, 'C', 'Central', '中', '中央', 44.2968750, -94.7401733),
(4505, 229, '317', 'Dokolo', '到處', '周围', 1.9636421, 33.0338767),
(4506, 229, 'E', 'Eastern', '東', '东部', 6.2374036, -0.4502368),
(4507, 229, '121', 'Gomba', '蘑菇', '蘑菇', 0.2229791, 31.6739371),
(4508, 229, '304', 'Gulu', '古魯', '古鲁', 2.8185776, 32.4467238),
(4509, 229, '403', 'Hoima', '霍伊瑪', '霍伊马', 1.5602343, 30.5204345),
(4510, 229, '417', 'Ibanda', '伊班達', '伊班达', -0.0964890, 30.5739579),
(4511, 229, '203', 'Iganga', '甘甘加', '甘甘加', 0.6600137, 33.4831906),
(4512, 229, '418', 'Isingiro', '結論', '结论', -0.8435430, 30.8039474),
(4513, 229, '204', 'Jinja', '金賈', '金贾', 0.5343743, 33.3037143),
(4514, 229, '318', 'Kaabong', '卡邦', '卡邦', 3.5126215, 33.9750018),
(4515, 229, '404', 'Kabale', '陰謀集團', '小集团', -1.2493084, 30.0665236),
(4516, 229, '405', 'Kabarole', '卡巴羅爾', '卡巴罗尔', 0.5850791, 30.2512728),
(4517, 229, '213', 'Kaberamaido', '卡貝拉邁道', '卡贝拉迈道', 1.6963322, 33.2138510),
(4518, 229, '427', 'Kagadi', '卡加迪', '卡加迪', 0.9400761, 30.8125638),
(4519, 229, '428', 'Kakumiro', '卡庫米羅', '卡库米罗', 0.7808035, 31.3241389),
(4520, 229, '237', 'Kalaki', '緋', '猩红', 1.8295680, 33.3293051),
(4521, 229, '101', 'Kalangala', '卡蘭加拉', '卡兰加拉', -0.6350578, 32.5372741),
(4522, 229, '222', 'Kaliro', '卡利羅', '卡利罗', 1.0431107, 33.4831906),
(4523, 229, '122', 'Kalungu', '卡倫古', '卡伦古', -0.0952831, 31.7651362),
(4524, 229, '102', 'Kampala', '坎帕拉', '坎帕拉', 0.3475964, 32.5825197),
(4525, 229, '205', 'Kamuli', '卡穆利', '卡穆利', 0.9187107, 33.1239049),
(4526, 229, '413', 'Kamwenge', '卡姆溫格', '卡姆文格', 0.2257930, 30.4818446),
(4527, 229, '414', 'Kanungu', '卡農古', '卡农古', -0.8195253, 29.7426040),
(4528, 229, '206', 'Kapchorwa', '卡普喬瓦', '卡普乔瓦', 1.3350205, 34.3976356),
(4529, 229, '236', 'Kapelebyong', '卡佩勒平', '卡佩勒平', 2.1959736, 33.3721383),
(4530, 229, '335', 'Karenga', '卡倫加', '卡伦加', 3.5877048, 33.5571129),
(4531, 229, '126', 'Kasanda', '卡桑達', '卡桑达', 0.5279491, 31.6477485),
(4532, 229, '406', 'Kasese', '卡塞塞', '加塞塞', 0.0646285, 30.0665236),
(4533, 229, '207', 'Katakwi', '卡塔克維', '卡塔克维', 1.9731030, 34.0641419),
(4534, 229, '112', 'Kayunga', '卡雲加', '卡云加', 0.9860182, 32.8535755),
(4535, 229, '433', 'Kazo', '卡佐', '加藏', -0.0513160, 30.7517088),
(4536, 229, '407', 'Kibaale', '基巴萊', '基巴莱', 0.9066802, 31.0793705),
(4537, 229, '103', 'Kiboga', '基博加', '基博加', 0.9657590, 31.7195459),
(4538, 229, '227', 'Kibuku', '基布庫', '基布库', 1.0452874, 33.7992536),
(4539, 229, '432', 'Kikuube', '菊酲部', '菊酎部', 1.3102190, 30.3235634),
(4540, 229, '419', 'Kiruhura', '基魯胡拉', '基鲁胡拉', -0.1927998, 30.8039474),
(4541, 229, '421', 'Kiryandongo', '基里揚東戈', '基里扬东戈', 2.0179907, 32.0837445),
(4542, 229, '408', 'Kisoro', '木索羅', '木索罗', -1.2209430, 29.6499162),
(4543, 229, '434', 'Kitagwenda', '基塔格文達', '基塔格文达', 0.0143297, 30.1805894),
(4544, 229, '305', 'Kitgum', '基特古姆', '基特古姆', 3.3396829, 33.1688883),
(4545, 229, '319', 'Koboko', '手', '手', 3.5237058, 31.0335100),
(4546, 229, '325', 'Kole', '求', '请求', 2.3701097, 32.7633036),
(4547, 229, '306', 'Kotido', '科蒂多', '科蒂多', 3.0415679, 33.8857747),
(4548, 229, '208', 'Kumi', '尋', '搜索', 1.4876999, 33.9303991),
(4549, 229, '333', 'Kwania', '打哈欠', '打 哈欠', 1.9011971, 32.4126492),
(4550, 229, '228', 'Kween', '權', '权', 1.4438790, 34.5971320),
(4551, 229, '123', 'Kyankwanzi', 'Kyankwanzi', '宽宽子', 1.0966037, 31.7195459),
(4552, 229, '422', 'Kyegegwa', '凱格瓜', '凯格瓜', 0.4818193, 31.0550093),
(4553, 229, '415', 'Kyenjojo', NULL, NULL, 0.6092923, 30.6401231),
(4554, 229, '125', 'Kyotera', '京寺', '京寺', -0.6358988, 31.5455637),
(4555, 229, '326', 'Lamwo', '蘭沃', '兰沃', 3.5707568, 32.5372741),
(4556, 229, '307', 'Lira', '里拉', '里拉', 2.2316169, 32.9437667),
(4557, 229, '229', 'Luuka', '路加福音', '卢克', 0.7250599, 33.3037143),
(4558, 229, '104', 'Luwero', '盧韋羅', '卢韦罗', 0.8271118, 32.6277455),
(4559, 229, '124', 'Lwengo', '盧文戈', 'Lwengo', -0.4165288, 31.3998995),
(4560, 229, '114', 'Lyantonde', '利安通德', '利安通德', -0.2240696, 31.2168466),
(4561, 229, '336', 'Madi-Okollo', '馬迪-奧科洛', '马迪-奥科洛', 2.8677307, 30.9275269),
(4562, 229, '223', 'Manafwa', '馬納夫瓦', '马纳夫瓦', 0.9063599, 34.2866091),
(4563, 229, '320', 'Maracha', '殺戮', '杀戮', 3.2873127, 30.9403023),
(4564, 229, '105', 'Masaka', '噴出', '喷', -0.4463691, 31.9017954),
(4565, 229, '409', 'Masindi', '馬辛迪', '马辛迪', 1.4920363, 31.7195459),
(4566, 229, '214', 'Mayuge', '馬尤格', '马尤格', -0.2182982, 33.5728027),
(4567, 229, '209', 'Mbale', '姆巴萊', '姆巴莱', 1.0344274, 34.1976882),
(4568, 229, '410', 'Mbarara', '聖保羅，聖保羅', '圣保罗，圣保罗', -0.6071596, 30.6545022),
(4569, 229, '423', 'Mitooma', '三戶馬', '三户间', -0.6193276, 30.0202964),
(4570, 229, '115', 'Mityana', '米蒂亞納', '米蒂亚纳', 0.4454845, 32.0837445),
(4571, 229, '308', 'Moroto', '莫羅托', '莫罗托', 2.6168545, 34.5971320),
(4572, 229, '309', 'Moyo', '莫約', '莫约', 3.5696464, 31.6739371),
(4573, 229, '106', 'Mpigi', '姆皮吉', '姆皮吉', 0.2273528, 32.3249236),
(4574, 229, '107', 'Mubende', '穆本德', '穆本德', 0.5772758, 31.5370003),
(4575, 229, '108', 'Mukono', '手', '手', 0.2835476, 32.7633036),
(4576, 229, '334', 'Nabilatuk', '納比拉圖克', '纳比拉图克', 2.0387033, 34.1775023),
(4577, 229, '311', 'Nakapiripirit', '納卡皮里皮里特', '纳卡皮里皮里特', 1.9606173, 34.5971320),
(4578, 229, '116', 'Nakaseke', '中瀨', '中关', 1.2230848, 32.0837445),
(4579, 229, '109', 'Nakasongola', '納卡松戈拉', '纳卡松戈拉', 1.3489721, 32.4467238),
(4580, 229, '230', 'Namayingo', '納馬因戈', '纳马因戈', -0.2803575, 33.7517723),
(4581, 229, '234', 'Namisindwa', '納米辛德瓦', '纳米辛德瓦', 0.9071010, 34.3574037),
(4582, 229, '224', 'Namutumba', '納穆通巴', '纳穆通巴', 0.8492610, 33.6623301),
(4583, 229, '327', 'Napak', '納帕克', '纳帕克', 2.3629945, 34.2421597),
(4584, 229, '310', 'Nebbi', '霧', '雾', 2.4409392, 31.3541631),
(4585, 229, '231', 'Ngora', '恩戈拉', '恩戈拉', 1.4908115, 33.7517723),
(4586, 229, 'N', 'Northern', '北', '北方', 9.5439269, -0.9056623),
(4587, 229, '424', 'Ntoroko', '恩托羅科', '恩托罗科', 1.0788178, 30.3896651),
(4588, 229, '411', 'Ntungamo', '結論', 'Ntungamo', -0.9807341, 30.2512728),
(4589, 229, '328', 'Nwoya', '恩沃亞', '恩沃亚', 2.5624440, 31.9017954),
(4590, 229, '337', 'Obongi', '奧邦吉', '奥邦吉', 3.3639361, 31.4331646),
(4591, 229, '331', 'Omoro', '奧莫羅', '奥莫罗', 2.7152230, 32.4920088),
(4592, 229, '329', 'Otuke', '奧圖克', '奥图克', 2.5214059, 33.3486147),
(4593, 229, '321', 'Oyam', '奧亞姆', '奥亚姆', 2.2776281, 32.4467238),
(4594, 229, '312', 'Pader', '頁片', '填子', 2.9430682, 32.8084496),
(4595, 229, '332', 'Pakwach', '帕克瓦奇', '帕克瓦奇', 2.4607141, 31.4941738),
(4596, 229, '210', 'Pallisa', '帕利薩', '帕利萨', 1.2324206, 33.7517723),
(4597, 229, '110', 'Rakai', '拉凱', '拉凯', -0.7069135, 31.5370003),
(4598, 229, '429', 'Rubanda', '魯班達', '鲁班达', -1.1861190, 29.8453576),
(4599, 229, '425', 'Rubirizi', '魯比里茲', '鲁比里齐', -0.2642410, 30.1084033),
(4600, 229, '431', 'Rukiga', '配黑麥', '用黑麦', -1.1326337, 30.0434120),
(4601, 229, '412', 'Rukungiri', '魯昆吉里', '鲁昆吉里', -0.7518490, 29.9277947),
(4602, 229, '435', 'Rwampara', '盧萬帕拉', '卢万帕拉', -0.7345601, 30.3201932),
(4603, 229, '111', 'Sembabule', '森巴布勒', '森巴布勒', 0.0637715, 31.3541631),
(4604, 229, '232', 'Serere', '溫室', '温室', 1.4994033, 33.5490078),
(4605, 229, '426', 'Sheema', '希瑪', '希玛', -0.5515298, 30.3896651),
(4606, 229, '215', 'Sironko', '西隆科', '西龙科', 1.2302274, 34.2491064),
(4607, 229, '211', 'Soroti', '索羅蒂', '索罗蒂', 1.7229117, 33.5280072),
(4608, 229, '212', 'Tororo', '托羅羅', '托罗罗', 0.6870994, 34.0641419),
(4609, 229, '113', 'Wakiso', '脇曾', '胁曾', 0.0630190, 32.4467238),
(4610, 229, 'W', 'Western', '西方的', '西方', 40.7667215, -111.8877203),
(4611, 229, '313', 'Yumbe', '尤姆貝', '云贝', 3.4698023, 31.2483291),
(4612, 229, '330', 'Zombo', '殭屍', '僵尸', 2.5544293, 30.9417368),
(4613, 230, '43', 'Autonomous Republic of Crimea', '克里米亞自治共和國', '克里米亚自治共和国', 44.9521170, 34.1024170),
(4614, 230, '71', 'Cherkaska', '切爾卡斯卡', '切尔卡斯卡', 49.4444330, 32.0597670),
(4615, 230, '74', 'Chernihivska', '切爾尼戈夫斯卡', '切尔尼戈夫斯卡', 51.4982000, 31.2893499),
(4616, 230, '77', 'Chernivetska', '切爾尼維茨卡', '切尔尼维茨卡', 48.2916830, 25.9352170),
(4617, 230, '12', 'Dnipropetrovska', '第聶伯羅彼得羅夫斯卡', '第聂伯罗彼得罗夫斯卡', 48.4647170, 35.0461830),
(4618, 230, '14', 'Donetska', '頓涅茨克', '顿涅茨克', 48.0158830, 37.8028500),
(4619, 230, '26', 'Ivano-Frankivska', '伊万諾-弗蘭科夫斯卡', '伊万诺-弗兰科夫斯卡', 48.9226330, 24.7111170),
(4620, 230, '63', 'Kharkivska', '哈爾科夫斯卡', '哈尔科夫斯卡', 49.9935000, 36.2303830),
(4621, 230, '65', 'Khersonska', '赫爾松斯卡', '赫尔松斯卡', 46.6354170, 32.6168670),
(4622, 230, '68', 'Khmelnytska', '赫梅利尼茨卡', '赫梅利尼茨卡', 49.4229830, 26.9871331),
(4623, 230, '35', 'Kirovohradska', '基洛沃赫拉茲卡', '基洛沃赫拉茨卡', 48.5079330, 32.2623170),
(4624, 230, '30', 'Kyiv', '基輔', '基辅', 50.4501000, 30.5234000),
(4625, 230, '32', 'Kyivska', '基輔', '基辅', 50.0529506, 30.7667134),
(4626, 230, '09', 'Luhanska', '盧甘斯卡', '卢甘斯卡', 48.5740410, 39.3078150),
(4627, 230, '46', 'Lvivska', '利沃夫斯卡', '利沃夫斯卡', 49.8396830, 24.0297170),
(4628, 230, '48', 'Mykolaivska', '尼古拉耶夫斯卡', '尼古拉耶夫斯卡', 46.9750330, 31.9945829),
(4629, 230, '51', 'Odeska', '敖德薩', '敖德萨', 46.4845830, 30.7326000),
(4630, 230, '53', 'Poltavska', '波爾塔瓦', '波尔塔瓦', 49.6429196, 32.6675339),
(4631, 230, '56', 'Rivnenska', '里夫嫩斯卡', '里夫年斯卡', 50.6199000, 26.2516170),
(4632, 230, '40', 'Sevastopol', '塞瓦斯托波爾', '塞瓦斯托波尔', 44.6166500, 33.5253671),
(4633, 230, '59', 'Sumska', '舒姆斯卡', '舒姆斯卡', 50.9077000, 34.7981000),
(4634, 230, '61', 'Ternopilska', '特爾諾皮爾斯卡', '捷尔诺皮尔斯卡', 49.5535170, 25.5947670),
(4635, 230, '05', 'Vinnytska', '文尼茨卡', '文尼茨卡', 49.2330830, 28.4682169),
(4636, 230, '07', 'Volynska', '沃林斯卡', '沃林斯卡', 50.7472330, 25.3253830),
(4637, 230, '21', 'Zakarpatska', '外喀爾巴阡', '外喀尔巴阡', 48.6208000, 22.2878830),
(4638, 230, '23', 'Zaporizka', '扎波羅熱', '扎波罗热', 47.8388000, 35.1395670),
(4639, 230, '18', 'Zhytomyrska', '日托米爾斯卡', '日托米尔斯卡', 50.2546500, 28.6586669),
(4640, 231, 'AZ', 'Abu Dhabi', '阿布達比', '阿布扎比', 24.4538840, 54.3773438),
(4641, 231, 'AJ', 'Ajman', '阿治曼', '阿治曼', 25.4052165, 55.5136433),
(4642, 231, 'DU', 'Dubai', '杜拜', '迪拜', 25.2048493, 55.2707828),
(4643, 231, 'FU', 'Fujairah', '富查伊拉', '富查伊拉', 25.1288099, 56.3264849),
(4644, 231, 'RK', 'Ras Al Khaimah', '哈伊馬角', '哈伊马角', 25.6741343, 55.9804173),
(4645, 231, 'SH', 'Sharjah', '沙迦', '沙迦', 25.0753974, 55.7578403),
(4646, 231, 'UQ', 'Umm Al Quwain', '烏姆蓋萬', '乌姆盖万', 25.5426324, 55.5475348),
(4647, 232, 'ABE', 'Aberdeen', '香港仔', '阿伯丁', 57.1497170, -2.0942780),
(4648, 232, 'ABD', 'Aberdeenshire', '阿伯丁郡', '阿伯丁郡', 57.2868723, -2.3815684),
(4649, 232, 'ANS', 'Angus', '安格斯', '安格斯', 37.2757886, -95.6501033),
(4650, 232, 'ANT', 'Antrim', '安特里姆', '安特里姆', 54.7195338, -6.2072498),
(4651, 232, 'ANN', 'Antrim and Newtownabbey', '安特里姆和紐敦阿比', '安特里姆和纽敦修道院', 54.6956887, -5.9481069),
(4652, 232, 'ARD', 'Ards', '阿茲', '阿兹', 42.1391851, -87.8614972),
(4653, 232, 'AND', 'Ards and North Down', '阿茲和北唐', '阿兹和北唐', 54.5899645, -5.5984972),
(4654, 232, 'AGB', 'Argyll and Bute', '阿蓋爾和比特', '阿盖尔和比特', 56.4006214, -5.4807480),
(4655, 232, 'ARM', 'Armagh', '阿馬', '阿马', 54.3932592, -6.4563401),
(4656, 232, 'ABC', 'Armagh, Banbridge and Craigavon', '阿馬、班布里奇和克雷加文', '阿马、班布里奇和克雷加文', 54.3932592, -6.4563401),
(4657, 232, 'SH-AC', 'Ascension Island', '阿森松島', '阿森松岛', -7.9467166, -14.3559158),
(4658, 232, 'BLA', 'Ballymena', '巴利米納', '巴利米纳', 54.8642600, -6.2791074),
(4659, 232, 'BLY', 'Ballymoney', '巴利莫尼', '巴利钱', 55.0704888, -6.5173708),
(4660, 232, 'BNB', 'Banbridge', '班布里奇', '班布里奇', 54.3487290, -6.2704803),
(4661, 232, 'BDG', 'Barking and Dagenham', '巴金和達格納姆', '巴金和达格纳姆', 51.5540666, 0.1340170),
(4662, 232, 'BNE', 'Barnet', '孩子', '孩子', 51.6049673, -0.2076295),
(4663, 232, 'BNS', 'Barnsley', '巴恩斯利', '巴恩斯利', 34.2994956, -84.9845809),
(4664, 232, 'BAS', 'Bath and North East Somerset', '巴斯和東北薩默塞特', '巴斯和东北萨默塞特', 51.3250102, -2.4766241),
(4665, 232, 'BDF', 'Bedford', '貝德福德', '贝德福德', 32.8440170, -97.1430671),
(4666, 232, 'BFS', 'Belfast', '貝爾法斯特', '贝尔法斯特', 54.6170366, -5.9531861),
(4667, 232, 'BEX', 'Bexley', '貝克斯利', '贝克斯利', 51.4519021, 0.1171786),
(4668, 232, 'BIR', 'Birmingham', '伯明翰', '伯明翰', 33.5185892, -86.8103567),
(4669, 232, 'BBD', 'Blackburn with Darwen', '布萊克本與達爾文', '布莱克本与达尔文', 53.6957522, -2.4682985),
(4670, 232, 'BPL', 'Blackpool', '布萊克浦', '布莱克浦', 53.8175053, -3.0356748),
(4671, 232, 'BGW', 'Blaenau Gwent', '布萊瑙·格溫特', '布莱瑙·格温特', 51.7875779, -3.2043931),
(4672, 232, 'BOL', 'Bolton', '博爾頓', '博尔顿', 44.3726476, -72.8787625),
(4673, 232, 'BMH', 'Bournemouth', '伯恩茅斯', '伯恩茅斯', 50.7191640, -1.8807690),
(4674, 232, 'BRC', 'Bracknell Forest', '布拉克內爾森林', '布拉克内尔森林', 51.4153828, -0.7536495),
(4675, 232, 'BRD', 'Bradford', '布拉德福德', '布拉德福德', 53.7959840, -1.7593980),
(4676, 232, 'BEN', 'Brent', '布倫特原油', '布伦特', 51.5672808, -0.2710568),
(4677, 232, 'BGE', 'Bridgend', '布里真德', '布里真德', 51.5083199, -3.5812075),
(4678, 232, 'BNH', 'Brighton and Hove', '布萊頓和霍夫', '布莱顿和霍夫', 50.8226288, -0.1370470),
(4679, 232, 'BST', 'Bristol', '布里斯托爾', '布里斯托尔', 41.6735220, -72.9465375),
(4680, 232, 'BRY', 'Bromley', '布羅姆利', '布罗姆利', 51.3679705, 0.0700620),
(4681, 232, 'BKM', 'Buckinghamshire', '白金漢郡', '白金汉郡', 51.8072204, -0.8127664),
(4682, 232, 'BUR', 'Bury', '葬', '埋葬', 53.5933498, -2.2966054),
(4683, 232, 'CAY', 'Caerphilly', '卡菲利', '卡菲利', 51.6604465, -3.2178724),
(4684, 232, 'CLD', 'Calderdale', '卡爾德代爾', '卡尔德代尔', 53.7247845, -1.8658357),
(4685, 232, 'CAM', 'Cambridgeshire', '劍橋郡', '剑桥', 52.2052973, 0.1218195),
(4686, 232, 'CMD', 'Camden', '卡姆登', '卡 姆 登', 51.5454736, -0.1627902),
(4687, 232, 'CRF', 'Cardiff', '卡迪夫', '加的夫', 51.4815810, -3.1790900),
(4688, 232, 'CMN', 'Carmarthenshire', '卡馬森郡', '卡马森郡', 51.8572309, -4.3115959),
(4689, 232, 'CKF', 'Carrickfergus', '卡里克弗格斯', '卡里克弗格斯', 54.7256843, -5.8093719),
(4690, 232, 'CSR', 'Castlereagh', '卡斯爾雷', '卡斯尔雷', 54.5756790, -5.8884028),
(4691, 232, 'CCG', 'Causeway Coast and Glens', '銅鑼海岸和格倫斯', '铜锣海岸和格伦斯', 55.0431830, -6.6741288),
(4692, 232, 'CBF', 'Central Bedfordshire', '貝德福德郡中部', '贝德福德郡中部', 52.0029744, -0.4651389),
(4693, 232, 'CGN', 'Ceredigion', '塞雷迪吉翁', 'Ceredigion', 52.2191429, -3.9321256),
(4694, 232, 'CHE', 'Cheshire East', '柴郡東', '柴郡东', 53.1610446, -2.2185932),
(4695, 232, 'CHW', 'Cheshire West and Chester', '西柴郡和切斯特', '西柴郡和切斯特', 53.2302974, -2.7151117),
(4696, 232, 'KHL', 'City of Kingston upon Hull', '赫爾河畔金斯頓市', '赫尔河畔金斯顿市', 53.7676236, -0.3274198),
(4697, 232, 'STH', 'City of Southampton', '南安普敦市', '南安普敦市', 50.9097004, -1.4043509),
(4698, 232, 'CLK', 'Clackmannanshire', '克拉克曼南郡', '克拉克曼南郡', 56.1075351, -3.7529409),
(4699, 232, 'CLR', 'Coleraine', '科爾雷恩', '科尔雷恩', 55.1451570, -6.6759814),
(4700, 232, 'CWY', 'Conwy', '康威', '康威', 53.2935013, -3.7265161),
(4701, 232, 'CKT', 'Cookstown', '庫克斯敦', '库克斯敦', 54.6418158, -6.7443895),
(4702, 232, 'CON', 'Cornwall', '康沃爾郡', '康沃尔', 50.2660471, -5.0527125),
(4703, 232, 'COV', 'Coventry', '考文垂', '考文垂', 52.4068220, -1.5196930),
(4704, 232, 'CGV', 'Craigavon', '克雷加文', '克雷加文', 54.3932592, -6.4563401),
(4705, 232, 'CRY', 'Croydon', '克羅伊登', '克罗伊登', 51.3827446, -0.0985163),
(4706, 232, 'CMA', 'Cumbria', '坎布里亞郡', '坎布里亚郡', 54.5772323, -2.7974835),
(4707, 232, 'DAL', 'Darlington', '達靈頓', '达林顿', 34.2998762, -79.8761741),
(4708, 232, 'DEN', 'Denbighshire', '登比郡', '登比郡', 53.1842288, -3.4224985),
(4709, 232, 'DER', 'Derby', '德比郡', '德比', 37.5483755, -97.2485191),
(4710, 232, 'DBY', 'Derbyshire', '德比郡', '德比郡', 53.1046782, -1.5623885),
(4711, 232, 'DRY', 'Derry', '德里', '德里', 54.9690778, -7.1958351),
(4712, 232, 'DRS', 'Derry City and Strabane', '德里城和斯特拉班', '德里城和斯特拉班', 55.0047443, -7.3209222),
(4713, 232, 'DEV', 'Devon', '德文郡', '德文', 50.7155591, -3.5308750),
(4714, 232, 'DNC', 'Doncaster', '唐卡斯特', '唐卡斯特', 53.5228200, -1.1284620),
(4715, 232, 'DOR', 'Dorset', '多塞特郡', '赛特', 50.7487635, -2.3444786),
(4716, 232, 'DOW', 'Down District Council', '唐區議會', '唐区议会', 54.2434287, -5.9577959),
(4717, 232, 'DUD', 'Dudley', '達德利', '达德利', 42.0433661, -71.9276033),
(4718, 232, 'DGY', 'Dumfries and Galloway', '鄧弗里斯和加洛韋', '邓弗里斯和加洛韦', 55.0701073, -3.6052581),
(4719, 232, 'DND', 'Dundee', '鄧迪', '邓迪', 56.4620180, -2.9707210),
(4720, 232, 'DGN', 'Dungannon and South Tyrone', '鄧甘農和南蒂龍', '邓甘农和南蒂龙', 54.5082684, -6.7665891),
(4721, 232, 'DUR', 'Durham', '達勒姆', '达勒姆', 54.7294099, -1.8811598),
(4722, 232, 'EAL', 'Ealing', '伊靈', '伊灵', 51.5250366, -0.3413965),
(4723, 232, 'EAY', 'East Ayrshire', '東艾爾郡', '东艾尔郡', 55.4518496, -4.2644478),
(4724, 232, 'EDU', 'East Dunbartonshire', '東鄧巴頓郡', '东邓巴顿郡', 55.9743162, -4.2022980),
(4725, 232, 'ELN', 'East Lothian', '東洛錫安', '东洛锡安', 55.9493383, -2.7704464),
(4726, 232, 'ERW', 'East Renfrewshire', '東倫弗魯郡', '东伦弗鲁郡', 55.7704735, -4.3359821),
(4727, 232, 'ERY', 'East Riding of Yorkshire', '約克郡東區', '约克郡东区', 53.8416168, -0.4344106),
(4728, 232, 'ESX', 'East Sussex', '東薩塞克斯郡', '东萨塞克斯郡', 50.9085955, 0.2494166),
(4729, 232, 'EDH', 'Edinburgh', '愛丁堡', '爱丁堡', 55.9532520, -3.1882670),
(4730, 232, 'ENF', 'Enfield', '恩菲爾德', '恩菲尔德', 51.6622909, -0.1180651),
(4731, 232, 'ENG', 'England', '英格蘭', '英国', 52.3555177, -1.1743197),
(4732, 232, 'ESS', 'Essex', '埃塞克斯郡', '艾塞克斯', 51.5742447, 0.4856781),
(4733, 232, 'FAL', 'Falkirk', '福爾柯克', '福尔柯克', 56.0018775, -3.7839131),
(4734, 232, 'FER', 'Fermanagh', '費爾馬納', '费尔马纳', 54.3447978, -7.6384218),
(4735, 232, 'FMO', 'Fermanagh and Omagh', '費爾馬納和奧馬', '费尔马纳和奥马', 54.4513524, -7.7125018),
(4736, 232, 'FIF', 'Fife', '法夫', '横笛', 56.2082078, -3.1495175),
(4737, 232, 'FLN', 'Flintshire', '弗林特郡', '弗林特郡', 53.1668658, -3.1418908),
(4738, 232, 'GAT', 'Gateshead', '蓋茨黑德', '盖茨黑德', 54.9526800, -1.6034110),
(4739, 232, 'GLG', 'Glasgow', '格拉斯哥', '格拉斯哥', 55.8642370, -4.2518060),
(4740, 232, 'GLS', 'Gloucestershire', '格洛斯特郡', '格洛斯特郡', 51.8642112, -2.2380335),
(4741, 232, 'GRE', 'Greenwich', '格林威治', '格林威治', 51.4834627, 0.0586202),
(4742, 232, 'GWN', 'Gwynedd', '格溫內斯', '格温内斯', 52.9277266, -4.1334836),
(4743, 232, 'HCK', 'Hackney', '哈克尼', '哈克尼', 51.5734450, -0.0724376),
(4744, 232, 'HAL', 'Halton', '荷頓', '荷顿', 43.5325372, -79.8744836),
(4745, 232, 'HMF', 'Hammersmith and Fulham', '哈默史密斯和富勒姆', '哈默史密斯和富勒姆', 51.4990156, -0.2291500),
(4746, 232, 'HAM', 'Hampshire', '漢普郡', '新罕布什尔州', 51.0576948, -1.3080629),
(4747, 232, 'HRY', 'Haringey', '哈林蓋', '哈林盖', 51.5906113, -0.1109709),
(4748, 232, 'HRW', 'Harrow', '耙', '耙', 51.5881627, -0.3422851),
(4749, 232, 'HPL', 'Hartlepool', '哈特爾普爾', '哈特尔普尔', 54.6917450, -1.2129260),
(4750, 232, 'HAV', 'Havering', '哈夫林', '哈夫林', 51.5779240, 0.2120829),
(4751, 232, 'HEF', 'Herefordshire', '赫里福德郡', '赫里福德郡', 52.0765164, -2.6544182),
(4752, 232, 'HRT', 'Hertfordshire', '赫特福德郡', '赫特福德', 51.8097823, -0.2376744),
(4753, 232, 'HLD', 'Highland', '高地', '高地', 36.2967508, -95.8380366),
(4754, 232, 'HIL', 'Hillingdon', '希靈登', '希灵登', 51.5351832, -0.4481378),
(4755, 232, 'HNS', 'Hounslow', '豪恩斯洛', '豪恩斯洛', 51.4828358, -0.3882062),
(4756, 232, 'IVC', 'Inverclyde', '因弗克萊德', '因弗克莱德', 55.9316569, -4.6800158),
(4757, 232, 'IOW', 'Isle of Wight', '懷特島', '怀特岛', 50.6938479, -1.3047340),
(4758, 232, 'IOS', 'Isles of Scilly', '錫利群島', '锡利群岛', 49.9277261, -6.3274966),
(4759, 232, 'ISL', 'Islington', '伊斯靈頓', '伊斯灵顿', 51.5465063, -0.1058058),
(4760, 232, 'KEC', 'Kensington and Chelsea', '肯辛頓和切爾西', '肯辛顿和切尔西', 51.4990805, -0.1938253),
(4761, 232, 'KEN', 'Kent', '肯特郡', '肯特', 41.1536674, -81.3578859),
(4762, 232, 'KTT', 'Kingston upon Thames', '泰晤士河畔京斯頓', '泰晤士河畔金斯敦', 51.3781170, -0.2927090),
(4763, 232, 'KIR', 'Kirklees', '柯克利斯', '柯克利斯', 53.5933432, -1.8009509),
(4764, 232, 'KWL', 'Knowsley', '諾斯利', '诺斯利', 53.4545940, -2.8529070),
(4765, 232, 'LBH', 'Lambeth', '蘭貝斯', '兰贝斯', 51.4571477, -0.1230681),
(4766, 232, 'LAN', 'Lancashire', '蘭開夏郡', '兰开夏', 53.7632254, -2.7044052),
(4767, 232, 'LRN', 'Larne', '拉恩', '拉恩', 54.8578003, -5.8236224),
(4768, 232, 'LDS', 'Leeds', '利茲聯', '利兹', 53.8007554, -1.5490774),
(4769, 232, 'LCE', 'Leicester', '萊斯特城', '莱斯特', 52.6368778, -1.1397592),
(4770, 232, 'LEC', 'Leicestershire', '萊斯特郡', '莱斯特', 52.7725710, -1.2052126),
(4771, 232, 'LEW', 'Lewisham', '劉易舍姆', '刘易舍姆', 51.4414579, -0.0117006),
(4772, 232, 'LMV', 'Limavady', '利馬瓦迪', '利马瓦迪', 55.0516820, -6.9491944),
(4773, 232, 'LIN', 'Lincolnshire', '林肯郡', '林肯 郡', 52.9451889, -0.1601246),
(4774, 232, 'LSB', 'Lisburn', '利斯本', '利斯本', 54.4981584, -6.1306791),
(4775, 232, 'LBC', 'Lisburn and Castlereagh', '利斯本和卡斯爾雷', '利斯本和卡斯尔雷', 54.4981584, -6.1306791),
(4776, 232, 'LIV', 'Liverpool', '利物浦', '利物浦', 32.6564981, -115.4763241),
(4777, 232, 'LND', 'London', '倫敦', '伦敦', 51.5123443, -0.0909852),
(4778, 232, 'MFT', 'Magherafelt', '馬蓋拉費爾特', '马盖拉费尔特', 54.7553279, -6.6077487),
(4779, 232, 'MAN', 'Manchester', '曼徹斯特', '曼彻斯特', 53.4807593, -2.2426305),
(4780, 232, 'MDW', 'Medway', '梅德韋', '梅德韦', 42.1417641, -71.3967256),
(4781, 232, 'MTY', 'Merthyr Tydfil', '梅瑟·蒂德菲爾', '梅瑟·蒂德菲尔', 51.7467474, -3.3813275),
(4782, 232, 'MRT', 'Merton', '默頓', '默顿', 51.4097742, -0.2108084),
(4783, 232, 'MEA', 'Mid and East Antrim', '中安特里姆和東安特里姆', '中安特里姆和东安特里姆', 54.9399341, -6.1137423),
(4784, 232, 'MUL', 'Mid Ulster', '中阿爾斯特', '中阿尔斯特', 54.6411301, -6.7522549),
(4785, 232, 'MDB', 'Middlesbrough', '米德爾斯堡', '米德尔斯堡', 54.5742270, -1.2349560),
(4786, 232, 'MLN', 'Midlothian', '中洛錫安', '中洛锡安', 32.4753350, -97.0103181),
(4787, 232, 'MIK', 'Milton Keynes', '米爾頓凱恩斯', '米尔顿凯恩斯', 52.0852038, -0.7333133),
(4788, 232, 'MON', 'Monmouthshire', '蒙茅斯郡', '蒙茅斯郡', 51.8116100, -2.7163417),
(4789, 232, 'MRY', 'Moray', '海鰻', '马里', 57.6498476, -3.3168039),
(4790, 232, 'MYL', 'Moyle', '莫伊爾', '莫伊尔', 55.2047327, -6.2531740),
(4791, 232, 'NTL', 'Neath Port Talbot', '尼思港塔爾博特', '尼思港塔尔博特', 51.5978519, -3.7839668),
(4792, 232, 'NET', 'Newcastle upon Tyne', '泰恩河畔紐卡斯爾', '泰恩河畔纽卡斯尔', 54.9782520, -1.6177800),
(4793, 232, 'NWM', 'Newham', '紐漢', '纽汉姆', 51.5255162, 0.0352163),
(4794, 232, 'NWP', 'Newport', '紐波特', '纽波特', 37.5278234, -94.1043876),
(4795, 232, 'NYM', 'Newry and Mourne', '紐里和莫恩', '纽里和莫恩', 54.1742505, -6.3391992),
(4796, 232, 'NMD', 'Newry, Mourne and Down', '紐里、莫恩和唐', '纽里、莫恩和唐', 54.2434287, -5.9577959),
(4797, 232, 'NTA', 'Newtownabbey', '紐敦修道院', '纽敦修道院', 54.6792422, -5.9591102),
(4798, 232, 'NFK', 'Norfolk', '諾福克', '诺福克', 36.8507689, -76.2858726),
(4799, 232, 'NAY', 'North Ayrshire', '北艾爾郡', '北艾尔郡', 55.6416731, -4.7594600),
(4800, 232, 'NDN', 'North Down', '北下', '北下', 54.6536297, -5.6724925),
(4801, 232, 'NEL', 'North East Lincolnshire', '林肯郡東北部', '东北林肯郡', 53.5668201, -0.0815066),
(4802, 232, 'NLK', 'North Lanarkshire', '北拉納克郡', '北拉纳克郡', 55.8662432, -3.9613144),
(4803, 232, 'NLN', 'North Lincolnshire', '北林肯郡', '北林肯郡', 53.6055592, -0.5596582),
(4804, 232, 'NSM', 'North Somerset', '北薩默塞特', '北萨默塞特', 51.3879028, -2.7781091),
(4805, 232, 'NTY', 'North Tyneside', '北泰恩賽德', '北泰恩赛德', 55.0182399, -1.4858436),
(4806, 232, 'NYK', 'North Yorkshire', '北約克郡', '北约克郡', 53.9915028, -1.5412015),
(4807, 232, 'NTH', 'Northamptonshire', '北安普敦郡', '北安普敦郡', 52.2729944, -0.8755515),
(4808, 232, 'NIR', 'Northern Ireland', '北愛爾蘭', '北爱尔兰', 54.7877149, -6.4923145),
(4809, 232, 'NBL', 'Northumberland', '諾森伯蘭郡', '诺森伯兰', 55.2082542, -2.0784138),
(4810, 232, 'NGM', 'Nottingham', '諾丁漢', '诺 丁 汉', 52.9547832, -1.1581086),
(4811, 232, 'NTT', 'Nottinghamshire', '諾丁漢郡', '诺 丁 汉', 53.1003190, -0.9936306),
(4812, 232, 'OLD', 'Oldham', '奧爾德姆', '奥尔德姆', 42.2040598, -71.2048119),
(4813, 232, 'OMH', 'Omagh', '奧馬', '奥马', 54.4513524, -7.7125018),
(4814, 232, 'ORK', 'Orkney Islands', '奧克尼群島', '奥克尼群岛', 58.9809401, -2.9605206),
(4815, 232, 'ELS', 'Outer Hebrides', '外赫布里底群島', '外赫布里底群岛', 57.7598918, -7.0194034),
(4816, 232, 'OXF', 'Oxfordshire', '牛津郡', '牛津郡', 51.7612056, -1.2464674),
(4817, 232, 'PEM', 'Pembrokeshire', '彭布羅克郡', '彭布罗克郡', 51.6740780, -4.9088785),
(4818, 232, 'PKN', 'Perth and Kinross', '珀斯和金羅斯', '珀斯和金罗斯', 56.3953817, -3.4283547),
(4819, 232, 'PTE', 'Peterborough', '彼得伯勒', '彼得伯勒', 44.3093636, -78.3201530),
(4820, 232, 'PLY', 'Plymouth', '普利茅斯', '普利茅斯', 42.3708941, -83.4697141),
(4821, 232, 'POL', 'Poole', '普爾', '普尔', 50.7150500, -1.9872480),
(4822, 232, 'POR', 'Portsmouth', '朴茨茅斯', '朴茨茅斯', 36.8329150, -76.2975549),
(4823, 232, 'POW', 'Powys', '波伊斯', '波伊斯', 52.6464249, -3.3260904),
(4824, 232, 'RDG', 'Reading', '閱讀', '读数', 36.1486659, -95.9840012),
(4825, 232, 'RDB', 'Redbridge', '紅橋', '红桥', 51.5886121, 0.0823982),
(4826, 232, 'RCC', 'Redcar and Cleveland', '雷德卡和克利夫蘭', '雷德卡和克利夫兰', 54.5971344, -1.0775997),
(4827, 232, 'RFW', 'Renfrewshire', '倫弗魯郡', '伦弗鲁郡', 55.8466540, -4.5331259),
(4828, 232, 'RCT', 'Rhondda Cynon Taf', '朗達·西農·塔夫', '朗达·西农·塔夫', 51.6490207, -3.4288692),
(4829, 232, 'RIC', 'Richmond upon Thames', '泰晤士河畔里士滿', '泰晤士河畔里士满', 51.4613054, -0.3037709),
(4830, 232, 'RCH', 'Rochdale', '羅奇代爾', '罗奇代尔', 53.6097136, -2.1561000),
(4831, 232, 'ROT', 'Rotherham', '羅瑟勒姆', '罗瑟勒姆', 53.4326035, -1.3635009),
(4832, 232, 'RUT', 'Rutland', '拉特蘭', '拉特兰', 43.6106237, -72.9726065),
(4833, 232, 'SH-HL', 'Saint Helena', '聖赫勒拿島', '圣赫勒拿', -15.9650104, -5.7089241),
(4834, 232, 'SLF', 'Salford', '索爾福德', '索尔福德', 53.4875235, -2.2901264),
(4835, 232, 'SAW', 'Sandwell', '桑德韋爾', '桑德韦尔', 52.5361674, -2.0107930),
(4836, 232, 'SCT', 'Scotland', '蘇格蘭', '苏格兰', 56.4906712, -4.2026458),
(4837, 232, 'SCB', 'Scottish Borders', '蘇格蘭邊境', '苏格兰边境', 55.5485697, -2.7861388),
(4838, 232, 'SFT', 'Sefton', '塞夫頓', '塞夫顿', 53.5034449, -2.9703590),
(4839, 232, 'SHF', 'Sheffield', '謝菲爾德', '谢菲尔德', 36.0950743, -80.2788466),
(4840, 232, 'ZET', 'Shetland Islands', '設得蘭群島', '设得兰群岛', 60.5296507, -1.2659409),
(4841, 232, 'SHR', 'Shropshire', '什羅普郡', '什罗普', 52.7063657, -2.7417849),
(4842, 232, 'SLG', 'Slough', '斯勞', '腐肉', 51.5105384, -0.5950406),
(4843, 232, 'SOL', 'Solihull', '索利哈爾', '索利哈尔', 52.4118110, -1.7776100),
(4844, 232, 'SOM', 'Somerset', '薩默塞特', '萨默塞特', 51.1050970, -2.9262307),
(4845, 232, 'SAY', 'South Ayrshire', '南艾爾郡', '南艾尔郡', 55.4588988, -4.6291994),
(4846, 232, 'SGC', 'South Gloucestershire', '南格洛斯特郡', '南格洛斯特郡', 51.5264361, -2.4728487),
(4847, 232, 'SLK', 'South Lanarkshire', '南拉納克郡', '南拉纳克郡', 55.6735909, -3.7819661),
(4848, 232, 'STY', 'South Tyneside', '南泰恩賽德', '南泰恩赛德', 54.9636693, -1.4418634),
(4849, 232, 'SOS', 'Southend-on-Sea', '濱海紹森德', '滨海绍森德', 51.5459269, 0.7077123),
(4850, 232, 'SWK', 'Southwark', '南華克', '南华克', 51.4880572, -0.0762838),
(4851, 232, 'SHN', 'St Helens', '聖海倫斯', '圣海伦斯', 45.8589610, -122.8212356),
(4852, 232, 'STS', 'Staffordshire', '斯塔福德郡', '斯塔福德郡', 52.8792745, -2.0571868),
(4853, 232, 'STG', 'Stirling', '斯特靈', '斯特林', 56.1165227, -3.9369029),
(4854, 232, 'SKP', 'Stockport', '斯托克波特', '斯托克波特', 53.4106316, -2.1575332),
(4855, 232, 'STT', 'Stockton-on-Tees', '蒂斯河畔斯托克頓', '蒂斯河畔斯托克顿', 54.5704551, -1.3289821),
(4856, 232, 'STE', 'Stoke-on-Trent', '特倫特河畔斯托克', '特伦特河畔斯托克', 53.0026680, -2.1794040),
(4857, 232, 'STB', 'Strabane', '斯特拉班', '斯特拉班', 54.8273865, -7.4633103),
(4858, 232, 'SFK', 'Suffolk', '薩福克郡', '萨 福 克', 52.1872472, 0.9707801),
(4859, 232, 'SND', 'Sunderland', '桑德蘭', '桑德兰', 54.8861489, -1.4785797),
(4860, 232, 'SRY', 'Surrey', '薩里', '萨里', 51.3147593, -0.5599501),
(4861, 232, 'STN', 'Sutton', '薩頓', '萨顿', 51.3573762, -0.1752796),
(4862, 232, 'SWA', 'Swansea', '斯旺西', '斯旺西', 51.6214400, -3.9436460),
(4863, 232, 'SWD', 'Swindon', '斯溫頓', '斯文顿', 51.5557739, -1.7797176),
(4864, 232, 'TAM', 'Tameside', '坦姆賽德', '坦姆赛德', 53.4805828, -2.0809891),
(4865, 232, 'TFW', 'Telford and Wrekin', '特爾福德和雷金', '特尔福德和雷金', 52.7409916, -2.4868586),
(4866, 232, 'THR', 'Thurrock', '瑟羅克', '瑟罗克', 51.4934557, 0.3529197),
(4867, 232, 'TOB', 'Torbay', '托貝', '托贝', 50.4392329, -3.5369899),
(4868, 232, 'TOF', 'Torfaen', '托爾芬', '托尔芬', 51.7002253, -3.0446015),
(4869, 232, 'TWH', 'Tower Hamlets', '塔哈姆雷特', '塔哈姆雷特', 51.5202607, -0.0293396),
(4870, 232, 'TRF', 'Trafford', '特拉福德', '特拉福德', 40.3856246, -79.7589347),
(4871, 232, 'UKM', 'United Kingdom', '英國', '英国', 55.3780510, -3.4359730),
(4872, 232, 'VGL', 'Vale of Glamorgan', '格拉摩根谷', '格拉摩根谷', 51.4095958, -3.4848167),
(4873, 232, 'WKF', 'Wakefield', '韋克菲爾德', '维克菲尔德', 42.5039395, -71.0723391),
(4874, 232, 'WLS', 'Wales', '威爾斯', '威尔士', 52.1306607, -3.7837117),
(4875, 232, 'WLL', 'Walsall', '沃爾索爾', '沃尔索尔', 52.5862140, -1.9829190),
(4876, 232, 'WFT', 'Waltham Forest', '沃爾瑟姆森林', '沃尔瑟姆森林', 51.5886383, -0.0117625),
(4877, 232, 'WND', 'Wandsworth', '旺茲沃思', '旺兹沃思', 51.4568274, -0.1896638),
(4878, 232, 'WRT', 'Warrington', '沃靈頓', '沃灵顿', 40.2492741, -75.1340604),
(4879, 232, 'WAR', 'Warwickshire', '沃里克郡', '沃里克郡', 52.2671353, -1.4675216),
(4880, 232, 'WBK', 'West Berkshire', '西伯克郡', '西伯克郡', 51.4308255, -1.1444927),
(4881, 232, 'WDU', 'West Dunbartonshire', '西鄧巴頓郡', '西邓巴顿郡', 55.9450925, -4.5646259),
(4882, 232, 'WLN', 'West Lothian', '西洛錫安', '西洛锡安', 55.9070198, -3.5517167),
(4883, 232, 'WSX', 'West Sussex', '西薩塞克斯郡', '西萨塞克斯郡', 50.9280143, -0.4617075),
(4884, 232, 'WSM', 'Westminster', '威斯敏斯特', '西敏寺', 39.5765977, -76.9972126),
(4885, 232, 'WGN', 'Wigan', '維岡', '维冈', 53.5134812, -2.6106999),
(4886, 232, 'WIL', 'Wiltshire', '威爾特郡', '威尔特郡', 51.3491996, -1.9927105),
(4887, 232, 'WNM', 'Windsor and Maidenhead', '溫莎和梅登黑德', '温莎和梅登黑德', 51.4799712, -0.6242565),
(4888, 232, 'WRL', 'Wirral', '威勒爾', '威勒尔', 53.3727181, -3.0737540),
(4889, 232, 'WOK', 'Wokingham', '沃金厄姆', '沃金厄姆', 51.4104570, -0.8338610),
(4890, 232, 'WLV', 'Wolverhampton', '伍爾弗漢普頓', '伍尔弗汉普顿', 52.5889120, -2.1564630),
(4891, 232, 'WOR', 'Worcestershire', '伍斯特郡', '伍斯特郡', 52.2545225, -2.2668382),
(4892, 232, 'WRX', 'Wrexham', '雷克瑟姆', '雷克瑟姆', 53.0301378, -3.0261487),
(4893, 232, 'YOR', 'York', '約克', '约克', 53.9599651, -1.0872979),
(4894, 233, 'AL', 'Alabama', '阿拉巴馬州', '阿拉巴马州', 32.3182314, -86.9022980),
(4895, 233, 'AK', 'Alaska', '阿拉斯加', '阿拉斯加州', 64.2008413, -149.4936733),
(4896, 233, 'AS', 'American Samoa', '美屬薩摩亞', '美属萨摩亚', -14.2709720, -170.1322170),
(4897, 233, 'AZ', 'Arizona', '亞利桑那州', '亚利桑那州', 34.0489281, -111.0937311),
(4898, 233, 'AR', 'Arkansas', '阿肯色州', '阿肯色州', 35.2010500, -91.8318334),
(4899, 233, 'UM-81', 'Baker Island', '貝克島', '贝克岛', 0.1936266, -176.4769080),
(4900, 233, 'CA', 'California', '加利福尼亞', '加州', 36.7782610, -119.4179324),
(4901, 233, 'CO', 'Colorado', '科羅拉多州', '科罗拉多州', 39.5500507, -105.7820674),
(4902, 233, 'CT', 'Connecticut', '康涅狄格州', '康涅狄格州', 41.6032207, -73.0877490),
(4903, 233, 'DE', 'Delaware', '特拉華州', '特拉华州', 38.9108325, -75.5276699),
(4904, 233, 'DC', 'District of Columbia', '哥倫比亞特區', '哥伦比亚特区', 38.9071923, -77.0368707),
(4905, 233, 'FL', 'Florida', '佛羅里達州', '佛罗里达州', 27.6648274, -81.5157535),
(4906, 233, 'GA', 'Georgia', '喬治亞', '格鲁吉亚', 32.1656221, -82.9000751),
(4907, 233, 'GU', 'Guam', '關島', '关岛', 13.4443040, 144.7937310),
(4908, 233, 'HI', 'Hawaii', '夏威夷', '夏威夷', 19.8967662, -155.5827818),
(4909, 233, 'UM-84', 'Howland Island', '豪蘭島', '豪兰岛', 0.8113219, -176.6182736),
(4910, 233, 'ID', 'Idaho', '愛達荷州', '爱达荷州', 44.0682019, -114.7420408),
(4911, 233, 'IL', 'Illinois', '伊利諾伊州', '伊利诺伊州', 40.6331249, -89.3985283),
(4912, 233, 'IN', 'Indiana', '印第安納州', '印第安纳州', 40.2671941, -86.1349019),
(4913, 233, 'IA', 'Iowa', '愛荷華州', '爱荷华州', 41.8780025, -93.0977020),
(4914, 233, 'UM-86', 'Jarvis Island', '賈維斯島', '贾维斯岛', -0.3743503, -159.9967206),
(4915, 233, 'UM-67', 'Johnston Atoll', '約翰斯頓環礁', 'Johnston Atoll', 16.7295035, -169.5336477),
(4916, 233, 'KS', 'Kansas', '堪薩斯州', '堪萨斯州', 39.0119020, -98.4842465),
(4917, 233, 'KY', 'Kentucky', '肯塔基州', '肯塔基州', 37.8393332, -84.2700179),
(4918, 233, 'UM-89', 'Kingman Reef', '金曼礁', '金曼礁', 6.3833330, -162.4166670),
(4919, 233, 'LA', 'Louisiana', '路易斯安那州', '路易斯安那州', 30.9842977, -91.9623327),
(4920, 233, 'ME', 'Maine', '緬因州', '缅因州', 45.2537830, -69.4454689),
(4921, 233, 'MD', 'Maryland', '馬里蘭州', '马里兰', 39.0457549, -76.6412712),
(4922, 233, 'MA', 'Massachusetts', '麻薩諸塞州', '麻萨诸塞州', 42.4072107, -71.3824374),
(4923, 233, 'MI', 'Michigan', '密西根州', '密歇根州', 44.3148443, -85.6023643),
(4924, 233, 'UM-71', 'Midway Atoll', '中途島環礁', '中途岛环礁', 28.2072168, -177.3734926),
(4925, 233, 'MN', 'Minnesota', '明尼蘇達州', '明尼苏达州', 46.7295530, -94.6858998),
(4926, 233, 'MS', 'Mississippi', '密西西比州', '密西西比州', 32.3546679, -89.3985283),
(4927, 233, 'MO', 'Missouri', '密蘇里州', '密苏里州', 37.9642529, -91.8318334),
(4928, 233, 'MT', 'Montana', '蒙大拿州', '蒙大拿州', 46.8796822, -110.3625658),
(4929, 233, 'UM-76', 'Navassa Island', '納瓦薩島', '纳瓦萨岛', 18.4100689, -75.0114612),
(4930, 233, 'NE', 'Nebraska', '內布拉斯加州', '内布拉斯加州', 41.4925374, -99.9018131),
(4931, 233, 'NV', 'Nevada', '內華達州', '内华达州', 38.8026097, -116.4193890),
(4932, 233, 'NH', 'New Hampshire', '新罕布什爾州', '新罕布什尔州', 43.1938516, -71.5723953),
(4933, 233, 'NJ', 'New Jersey', '新澤西州', '新泽西州', 40.0583238, -74.4056612),
(4934, 233, 'NM', 'New Mexico', '新墨西哥州', '新墨西哥州', 34.5199402, -105.8700901),
(4935, 233, 'NY', 'New York', '紐約', '纽约', 40.7127753, -74.0059728),
(4936, 233, 'NC', 'North Carolina', '北卡羅來納州', '北卡罗来纳州', 35.7595731, -79.0192997),
(4937, 233, 'ND', 'North Dakota', '北達科他州', '北达科他州', 47.5514926, -101.0020119),
(4938, 233, 'MP', 'Northern Mariana Islands', '北馬里亞納群島', '北马里亚纳群岛', 15.0979000, 145.6739000),
(4939, 233, 'OH', 'Ohio', '俄亥俄州', '俄亥俄州', 40.4172871, -82.9071230),
(4940, 233, 'OK', 'Oklahoma', '俄克拉荷馬州', '俄克拉何马州', 35.4675602, -97.5164276),
(4941, 233, 'OR', 'Oregon', '俄勒岡州', '俄勒冈州', 43.8041334, -120.5542012),
(4942, 233, 'UM-95', 'Palmyra Atoll', '巴爾米拉環礁', '巴尔米拉环礁', 5.8885026, -162.0786656),
(4943, 233, 'PA', 'Pennsylvania', '賓夕法尼亞州', '宾夕法尼亚州', 41.2033216, -77.1945247),
(4944, 233, 'PR', 'Puerto Rico', '波多黎各', '波多黎各', 18.2208330, -66.5901490),
(4945, 233, 'RI', 'Rhode Island', '羅德島州', '罗得岛州', 41.5800945, -71.4774291),
(4946, 233, 'SC', 'South Carolina', '南卡羅來納州', '南卡罗来纳州', 33.8360810, -81.1637245),
(4947, 233, 'SD', 'South Dakota', '南達科他州', '南达科他州', 43.9695148, -99.9018131),
(4948, 233, 'TN', 'Tennessee', '田納西州', '田纳西州', 35.5174913, -86.5804473),
(4949, 233, 'TX', 'Texas', '德克薩斯州', '得克萨斯州', 31.9685988, -99.9018131),
(4950, 233, 'UM', 'United States Minor Outlying Islands', '美國離島小島', '美国离岛小岛屿', 19.2823192, 166.6470470),
(4951, 233, 'VI', 'United States Virgin Islands', '美屬維爾京群島', '美属维尔京群岛', 18.3357650, -64.8963350),
(4952, 233, 'UT', 'Utah', '猶他州', '犹他州', 39.3209801, -111.0937311),
(4953, 233, 'VT', 'Vermont', '佛蒙特州', '佛蒙特州', 44.5588028, -72.5778415),
(4954, 233, 'VA', 'Virginia', '維吉尼亞州', '弗吉尼亚州', 37.4315734, -78.6568942),
(4955, 233, 'UM-79', 'Wake Island', '威克島', '威克岛', 19.2796190, 166.6499348),
(4956, 233, 'WA', 'Washington', '華盛頓', '华盛顿', 47.7510741, -120.7401385),
(4957, 233, 'WV', 'West Virginia', '西維吉尼亞州', '西弗吉尼亚州', 38.5976262, -80.4549026),
(4958, 233, 'WI', 'Wisconsin', '威斯康辛州', '威斯康星州', 43.7844397, -88.7878678),
(4959, 233, 'WY', 'Wyoming', '懷俄明州', '怀俄明州', 43.0759678, -107.2902839),
(4960, 234, '81', 'Baker Island', '貝克島', '贝克岛', 0.1936266, -176.4769080),
(4961, 234, '84', 'Howland Island', '豪蘭島', '豪兰岛', 0.8113219, -176.6182736),
(4962, 234, '86', 'Jarvis Island', '賈維斯島', '贾维斯岛', -0.3743503, -159.9967206),
(4963, 234, '67', 'Johnston Atoll', '約翰斯頓環礁', 'Johnston Atoll', 16.7295035, -169.5336477),
(4964, 234, '89', 'Kingman Reef', '金曼礁', '金曼礁', 6.3833330, -162.4166670),
(4965, 234, '71', 'Midway Islands', '中途島群島', '中途岛群岛', 28.2072168, -177.3734926),
(4966, 234, '76', 'Navassa Island', '納瓦薩島', '纳瓦萨岛', 18.4100689, -75.0114612),
(4967, 234, '95', 'Palmyra Atoll', '巴爾米拉環礁', '巴尔米拉环礁', 5.8885026, -162.0786656),
(4968, 234, '79', 'Wake Island', '威克島', '威克岛', 19.2796190, 166.6499348);
INSERT INTO `location_states` (`state_id`, `country_id`, `state_code`, `state_name_en`, `state_name_zh_tw`, `state_name_zh_cn`, `state_center_latitude`, `state_center_longitude`) VALUES
(4969, 235, 'AR', 'Artigas', '阿蒂加斯', '阿蒂加斯', -30.6175112, -56.9594559),
(4970, 235, 'CA', 'Canelones', '卡內羅尼', '卡内罗尼', -34.5408717, -55.9307600),
(4971, 235, 'CL', 'Cerro Largo', '拉戈山', '拉戈山', -32.4411032, -54.3521753),
(4972, 235, 'CO', 'Colonia', '殖民地', '殖民地', -34.1294678, -57.6605184),
(4973, 235, 'DU', 'Durazno', '桃', '桃', -33.0232454, -56.0284644),
(4974, 235, 'FS', 'Flores', '花', '花', -33.5733753, -56.8945028),
(4975, 235, 'FD', 'Florida', '佛羅里達州', '佛罗里达州', 28.0359495, -82.4579289),
(4976, 235, 'LA', 'Lavalleja', '拉瓦萊哈', '拉瓦莱哈', -33.9226175, -54.9765794),
(4977, 235, 'MA', 'Maldonado', '馬爾多納多', '马尔多纳多', -34.5597932, -54.8628552),
(4978, 235, 'MO', 'Montevideo', '蒙得維的亞', '蒙得维的亚', -34.8181587, -56.2138256),
(4979, 235, 'PA', 'Paysandú', 'Paysandú', 'Paysandú', -32.0667366, -57.3364789),
(4980, 235, 'RN', 'Río Negro', '里奧內格羅', '里约内格罗', -32.7676356, -57.4295207),
(4981, 235, 'RV', 'Rivera', '河', '流', -31.4817421, -55.2435759),
(4982, 235, 'RO', 'Rocha', '石', '岩石', -33.9690081, -54.0214850),
(4983, 235, 'SA', 'Salto', '跳', '跳', -31.3880280, -57.9612455),
(4984, 235, 'SJ', 'San José', '聖荷西', '圣何塞', 37.3492968, -121.9056049),
(4985, 235, 'SO', 'Soriano', '索里亞諾', '索里亚诺', -33.5102792, -57.7498103),
(4986, 235, 'TA', 'Tacuarembó', 'Tacuarembó', 'Tacuarembó', -31.7206837, -55.9859887),
(4987, 235, 'TT', 'Treinta y Tres', '三十三', '三十三', -33.0685086, -54.2858627),
(4988, 236, 'AN', 'Andijan', '安集延', '安集延', 40.7685941, 72.2363790),
(4989, 236, 'BU', 'Bukhara', '布哈拉', '布哈拉', 40.2504162, 63.2032151),
(4990, 236, 'FA', 'Fergana', '渡輪', '渡轮', 40.4568081, 71.2874209),
(4991, 236, 'JI', 'Jizzakh', '吉扎赫', '吉扎赫', 40.4706415, 67.5708536),
(4992, 236, 'QR', 'Karakalpakstan', '卡拉卡爾帕克斯坦', '卡拉卡尔帕克斯坦', 43.8041334, 59.4457988),
(4993, 236, 'NG', 'Namangan', '納曼根', '纳曼甘', 41.0510037, 71.0973170),
(4994, 236, 'NW', 'Navoiy', '納沃伊', '纳沃伊', 42.6988575, 64.6337685),
(4995, 236, 'QA', 'Qashqadaryo', '卡什卡達里亞', '卡什卡达里亚', 38.8986231, 66.0463534),
(4996, 236, 'SA', 'Samarqand', '撒馬爾罕', '撒马尔罕', 39.6270120, 66.9749731),
(4997, 236, 'SI', 'Sirdaryo', '西爾達里亞', '锡尔达里亚', 40.3863808, 68.7154975),
(4998, 236, 'SU', 'Surxondaryo', '蘇爾坎達里亞', '苏尔坎达里亚', 37.9409005, 67.5708536),
(4999, 236, 'TK', 'Tashkent', '塔什幹', '塔什干', 41.2994958, 69.2400734),
(5000, 236, 'TO', 'Tashkent', '塔什幹', '塔什干', 41.2213234, 69.8597406),
(5001, 236, 'XO', 'Xorazm', '花剌子模', '花剌子模', 41.3565336, 60.8566686),
(5002, 237, 'MAP', 'Malampa', '馬蘭帕', '马兰帕', -16.4011405, 167.6077865),
(5003, 237, 'PAM', 'Penama', '佩納馬', '佩纳马', -15.3795758, 167.9053182),
(5004, 237, 'SAM', 'Sanma', '不要', '不要', -15.4840017, 166.9182097),
(5005, 237, 'SEE', 'Shefa', '謝法', '舍法', 32.8057650, 35.1699710),
(5006, 237, 'TAE', 'Tafea', '塔菲亞', '塔菲亚', -18.7237827, 169.0645056),
(5007, 237, 'TOB', 'Torba', '袋', '袋', 37.0765300, 27.4565730),
(5008, 239, 'Z', 'Amazonas', '亞馬遜河', '亚马逊河', -3.4168427, -65.8560646),
(5009, 239, 'B', 'Anzoátegui', 'Anzoátegui', 'Anzoátegui', 8.5913073, -63.9586111),
(5010, 239, 'C', 'Apure', '阿普爾', '阿普尔', 6.9269483, -68.5247149),
(5011, 239, 'D', 'Aragua', '阿拉瓜', '阿拉瓜', 10.0635758, -67.2847875),
(5012, 239, 'E', 'Barinas', '巴里納斯', '巴里纳斯州', 8.6231498, -70.2371045),
(5013, 239, 'F', 'Bolívar', '玻利瓦爾', '玻利瓦尔', 37.6144838, -93.4104749),
(5014, 239, 'G', 'Carabobo', '卡拉沃沃', '卡拉沃沃', 10.1176433, -68.0477509),
(5015, 239, 'H', 'Cojedes', '科赫德斯', '科赫德斯', 9.3816682, -68.3339275),
(5016, 239, 'Y', 'Delta Amacuro', '三角洲阿馬庫羅', '三角洲阿马库罗', 8.8499307, -61.1403196),
(5017, 239, 'A', 'Distrito Capital', '首都區', '首都区', 41.2614846, -95.9310807),
(5018, 239, 'I', 'Falcón', '鷹', '隼', 11.1810674, -69.8597406),
(5019, 239, 'J', 'Guárico', '瓜里科', '瓜里科', 8.7489309, -66.2367172),
(5020, 239, 'X', 'La Guaira', '拉瓜伊拉', '拉瓜伊拉', 29.3052268, -94.7913854),
(5021, 239, 'K', 'Lara', '勞拉', '拉腊', 33.9822165, -118.1322747),
(5022, 239, 'L', 'Mérida', '梅里達', '美利达', 20.9673702, -89.5925857),
(5023, 239, 'M', 'Miranda', '米蘭達', '米兰达', 42.3519383, -71.5290766),
(5024, 239, 'N', 'Monagas', '莫納加斯', '莫纳加斯', 9.3241652, -63.0147578),
(5025, 239, 'O', 'Nueva Esparta', '新埃斯巴達', '新埃斯巴达', 10.9970723, -63.9113296),
(5026, 239, 'P', 'Portuguesa', '葡萄牙人', '葡萄牙语', 9.0943999, -69.0970230),
(5027, 239, 'R', 'Sucre', '糖', '糖', -19.0353450, -65.2592128),
(5028, 239, 'S', 'Táchira', '塔奇拉', '塔奇拉', 7.9137001, -72.1416132),
(5029, 239, 'T', 'Trujillo', '特魯希略', '特鲁希略', 36.6734343, -121.6287588),
(5030, 239, 'W', 'Venezuela', '委內瑞拉', '委内瑞拉', 10.9377053, -65.3569573),
(5031, 239, 'U', 'Yaracuy', '亞拉庫伊', '亚拉库伊', 10.3393890, -68.8108849),
(5032, 239, 'V', 'Zulia', '祖利亞', '祖利亚', 10.2910237, -72.1416132),
(5033, 240, '44', 'An Giang', '安江', '安江', 10.5215836, 105.1258955),
(5034, 240, '43', 'Bà Rịa-Vũng Tàu', 'Bà Rịa-Vũng Tàu', 'Bà Rịa-Vũng Tàu', 10.5417397, 107.2429976),
(5035, 240, '54', 'Bắc Giang', '北江', '北江', 21.2819921, 106.1974769),
(5036, 240, '53', 'Bắc Kạn', '北幹', '北干', 22.3032923, 105.8760040),
(5037, 240, '55', 'Bạc Liêu', '北遼', '北柳', 9.2940027, 105.7215663),
(5038, 240, '56', 'Bắc Ninh', '北寧', '北宁', 21.1214440, 106.1110501),
(5039, 240, '50', 'Bến Tre', '檳椥', '槟椥', 10.2433556, 106.3755510),
(5040, 240, '57', 'Bình Dương', '平陽', '平阳', 11.3254024, 106.4770170),
(5041, 240, '31', 'Bình Định', '平定', '平定', 14.1665324, 108.9026830),
(5042, 240, '58', 'Bình Phước', '平福', '平福', 11.7511894, 106.7234639),
(5043, 240, '40', 'Bình Thuận', '平順', '平顺', 11.0903703, 108.0720781),
(5044, 240, '59', 'Cà Mau', '金甌', '金甌', 9.1526728, 105.1960795),
(5045, 240, 'CT', 'Cần Thơ', '芹苴', '芹苴', 10.0341851, 105.7225507),
(5046, 240, '04', 'Cao Bằng', '高平', '曹邦', 22.6356890, 106.2522143),
(5047, 240, 'DN', 'Đà Nẵng', '峴港', '岘港', 16.0544068, 108.2021667),
(5048, 240, '33', 'Đắk Lắk', '達樂', '达乐', 12.7100116, 108.2377519),
(5049, 240, '72', 'Đắk Nông', '達農', '达农', 12.2646476, 107.6098060),
(5050, 240, '71', 'Điện Biên', '奠邊', '奠边', 21.8042309, 103.1076525),
(5051, 240, '39', 'Đồng Nai', '同奈', '同奈', 11.0686305, 107.1675976),
(5052, 240, '45', 'Đồng Tháp', '東塔', '同塔', 10.4937989, 105.6881788),
(5053, 240, '30', 'Gia Lai', '嘉萊', '嘉丽', 13.8078943, 108.1093750),
(5054, 240, '03', 'Hà Giang', '河江', '河江', 22.8025588, 104.9784494),
(5055, 240, '63', 'Hà Nam', '河南', '河南', 20.5835196, 105.9229900),
(5056, 240, 'HN', 'Hà Nội', '河內', '河内', 21.0277644, 105.8341598),
(5057, 240, '23', 'Hà Tĩnh', '河靜', '河静', 18.3559537, 105.8877494),
(5058, 240, '61', 'Hải Dương', '海陽', '海阳', 20.9373413, 106.3145542),
(5059, 240, 'HP', 'Hải Phòng', '海防', '海防', 20.8449115, 106.6880841),
(5060, 240, '73', 'Hậu Giang', '後江', '后江', 9.7578980, 105.6412527),
(5061, 240, 'SG', 'Hồ Chí Minh', '胡志明市', '胡志明市', 10.8230989, 106.6296638),
(5062, 240, '14', 'Hòa Bình', '和平', '和平', 20.6861265, 105.3131185),
(5063, 240, '66', 'Hưng Yên', '洪彥', '洪安', 20.8525711, 106.0169971),
(5064, 240, '34', 'Khánh Hòa', '慶和', '庆和', 12.2585098, 109.0526076),
(5065, 240, '47', 'Kiên Giang', '堅江', '坚江', 9.8249587, 105.1258955),
(5066, 240, '28', 'Kon Tum', '昆圖姆', '昆图姆', 14.3497403, 108.0004606),
(5067, 240, '01', 'Lai Châu', '麗洲', '莱洲', 22.3862227, 103.4702631),
(5068, 240, '35', 'Lâm Đồng', '林東', '林东', 11.5752791, 108.1428669),
(5069, 240, '09', 'Lạng Sơn', '諒山', '郎山', 21.8537080, 106.7615190),
(5070, 240, '02', 'Lào Cai', '老街', '老街', 22.4809431, 103.9754959),
(5071, 240, '41', 'Long An', '龍安', '龙安', 10.5607168, 106.6497623),
(5072, 240, '67', 'Nam Định', '南定', '南廷', 20.4388225, 106.1621053),
(5073, 240, '22', 'Nghệ An', '義安', '义安', 19.2342489, 104.9200365),
(5074, 240, '18', 'Ninh Bình', '寧平', '宁平', 20.2506149, 105.9744536),
(5075, 240, '36', 'Ninh Thuận', '寧順', '宁顺', 11.6738767, 108.8629572),
(5076, 240, '68', 'Phú Thọ', '富壽', '富寿', 21.2684430, 105.2045573),
(5077, 240, '32', 'Phú Yên', '富安', '富安', 13.0881861, 109.0928764),
(5078, 240, '24', 'Quảng Bình', '廣平', '广平', 17.6102715, 106.3487474),
(5079, 240, '27', 'Quảng Nam', '廣南', '广南', 15.5393538, 108.0191020),
(5080, 240, '29', 'Quảng Ngãi', '廣毅', '广毅', 15.1213873, 108.8044145),
(5081, 240, '13', 'Quảng Ninh', '廣寧省', '广宁省', 21.0063820, 107.2925144),
(5082, 240, '25', 'Quảng Trị', '廣治', '广治', 16.7403074, 107.1854679),
(5083, 240, '52', 'Sóc Trăng', '朔莊', '朔庄', 9.6025210, 105.9739049),
(5084, 240, '05', 'Sơn La', '孫拉', '孙腊', 21.1022284, 103.7289167),
(5085, 240, '37', 'Tây Ninh', '西寧', '西宁', 11.3351554, 106.1098854),
(5086, 240, '20', 'Thái Bình', '和平', '和平', 20.4463471, 106.3365828),
(5087, 240, '69', 'Thái Nguyên', '太阮', '太阮', 21.5671559, 105.8252038),
(5088, 240, '21', 'Thanh Hóa', '清化', '清化', 19.8066920, 105.7851816),
(5089, 240, '26', 'Thừa Thiên-Huế', 'Thừa 天化', 'Thừa 天顺', 16.4673970, 107.5905326),
(5090, 240, '46', 'Tiền Giang', '天江', '天江', 10.4493324, 106.3420504),
(5091, 240, '51', 'Trà Vinh', '茶榮', '茶荣', 9.8127410, 106.2992912),
(5092, 240, '07', 'Tuyên Quang', '宣光', '荃光', 21.7767246, 105.2280196),
(5093, 240, '49', 'Vĩnh Long', '永隆', '永隆', 10.2395740, 105.9571928),
(5094, 240, '70', 'Vĩnh Phúc', '永福', '永福', 21.3608805, 105.5474373),
(5095, 240, '06', 'Yên Bái', '安柏', '安柏', 21.7167689, 104.8985878),
(5096, 242, 'SC', 'Saint Croix', '聖十字', '圣十字', 17.7293520, -64.7343705),
(5097, 242, 'SJ', 'Saint John', '聖約翰', '圣约翰', 18.3356169, -64.8002800),
(5098, 242, 'ST', 'Saint Thomas', '聖托馬斯', '圣托马斯', 18.3428459, -65.0770180),
(5099, 245, 'AD', '\'Adan', '亞丁', '亚丁', 12.8257481, 44.7943804),
(5100, 245, 'AM', '\'Amran', '阿姆蘭', '阿姆兰', 16.2569214, 43.9436788),
(5101, 245, 'AB', 'Abyan', '阿比揚', '阿比扬', 13.6343413, 46.0563212),
(5102, 245, 'BA', 'Al Bayda\'', '阿爾貝達', '阿尔贝达', 14.3588662, 45.4498065),
(5103, 245, 'HU', 'Al Hudaydah', '荷台達', '荷台达', 15.3053072, 43.0194897),
(5104, 245, 'JA', 'Al Jawf', '阿爾賈夫', '阿尔·贾夫', 16.7901819, 45.2993862),
(5105, 245, 'MR', 'Al Mahrah', '阿爾馬赫拉', '阿尔马赫拉', 16.5238423, 51.6834275),
(5106, 245, 'MW', 'Al Mahwit', '阿爾·馬赫維特', '阿尔·马赫维特', 15.3963229, 43.5606946),
(5107, 245, 'SA', 'Amanat Al Asimah', '阿馬納特·阿西瑪', '阿马纳特·阿西玛', 15.3694451, 44.1910066),
(5108, 245, 'DH', 'Dhamar', '達馬爾', '达马尔', 14.7195344, 44.2479015),
(5109, 245, 'HD', 'Hadhramaut', '哈德拉莫特', '哈德拉莫特', 16.9304135, 49.3653149),
(5110, 245, 'HJ', 'Hajjah', '朝覲', '朝觐', 16.1180631, 43.3294660),
(5111, 245, 'IB', 'Ibb', '伊布', '伊布', 14.1415717, 44.2479015),
(5112, 245, 'LA', 'Lahij', '拉希吉', '拉希吉', 13.1489588, 44.8505495),
(5113, 245, 'MA', 'Ma\'rib', '卻', '但', 15.5158880, 45.4498065),
(5114, 245, 'RA', 'Raymah', '雷瑪', '雷玛', 14.6277682, 43.7142484),
(5115, 245, 'SD', 'Saada', '得', '获取', 16.8476528, 43.9436788),
(5116, 245, 'SN', 'Sana\'a', '你', '你', 15.3168913, 44.4748018),
(5117, 245, 'SH', 'Shabwah', '安息日', '安息日', 14.7546303, 46.5162620),
(5118, 245, 'SU', 'Socotra', '索科特拉島', '索科特拉岛', 12.4634205, 53.8237385),
(5119, 245, 'TA', 'Ta\'izz', 'Ta', 'Ta', 13.5775886, 44.0177989),
(5120, 246, '02', 'Central', '中', '中央', 7.2564996, 80.7214417),
(5121, 246, '08', 'Copperbelt', '銅帶', '铜带', -13.0570073, 27.5495846),
(5122, 246, '03', 'Eastern', '東', '东部', 23.1669688, 49.3653149),
(5123, 246, '04', 'Luapula', '盧阿普拉', '卢阿普拉', -11.5648310, 29.0459927),
(5124, 246, '09', 'Lusaka', '盧薩卡', '卢萨卡', -15.3657129, 29.2320784),
(5125, 246, '10', 'Muchinga', '蘇格蘭。', '苏格兰。', -15.3821930, 28.2615800),
(5126, 246, '05', 'Northern', '北', '北方', 8.8855027, 80.2767327),
(5127, 246, '06', 'Northwestern', '西北大學', '西北', -13.0050258, 24.9042208),
(5128, 246, '07', 'Southern', '南方的', '南部', 6.2373750, 80.5438450),
(5129, 246, '01', 'Western', '西方的', '西方', 6.9016086, 80.0087746),
(5130, 247, 'BU', 'Bulawayo', '布拉瓦約', '布拉瓦约', -20.1489505, 28.5331038),
(5131, 247, 'HA', 'Harare', '哈拉雷', '哈拉雷', -17.8216288, 31.0492259),
(5132, 247, 'MA', 'Manicaland', '馬尼卡蘭', '马尼卡兰', -18.9216386, 32.1746050),
(5133, 247, 'MC', 'Mashonaland Central', '馬紹納蘭中央', '马绍纳兰中央', -16.7644295, 31.0793705),
(5134, 247, 'ME', 'Mashonaland East', '馬紹納蘭東', '东马绍纳兰', -18.5871642, 31.2626366),
(5135, 247, 'MW', 'Mashonaland West', '馬紹納蘭西', '马绍纳兰西', -17.4851029, 29.7889248),
(5136, 247, 'MV', 'Masvingo', '牆壁', '墙壁', -20.6241509, 31.2626366),
(5137, 247, 'MN', 'Matabeleland North', '北馬塔貝萊蘭', '北马塔贝莱兰', -18.5331566, 27.5495846),
(5138, 247, 'MS', 'Matabeleland South', '馬塔貝萊蘭南', '马塔贝莱兰南', -21.0523370, 29.0459927),
(5139, 247, 'MI', 'Midlands', '中部', '中部', -19.0552009, 29.6035495);

-- --------------------------------------------------------

--
-- 資料表結構 `multipleperspectives_data`
--

CREATE TABLE `multipleperspectives_data` (
  `multipleperspectives_id` bigint(20) UNSIGNED NOT NULL,
  `multipleperspectives_title` varchar(50) DEFAULT NULL,
  `multipleperspectives_url` varchar(100) DEFAULT NULL,
  `total_view` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_recent_view` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_share` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_recent_share` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_bookmark` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_recent_bookmark` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_comment` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_recent_comment` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_score` float NOT NULL DEFAULT 0,
  `total_rater` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_recent_score` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_heat` float NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 觸發器 `multipleperspectives_data`
--
DELIMITER $$
CREATE TRIGGER `caculate_heat (bi_multipleperspectives_data)` BEFORE INSERT ON `multipleperspectives_data` FOR EACH ROW BEGIN
    -- 定義參數
    DECLARE v_view, v_comment, v_bookmark, v_share, v_score FLOAT DEFAULT 1.0;
    DECLARE v_recent_view, v_recent_comment, v_recent_bookmark, v_recent_share FLOAT DEFAULT 1.0;
    
    -- 獲取參數係數
    SELECT adjust_value INTO v_view 			FROM value_adjust WHERE adjust_type = 'view' 	 			LIMIT 1;
    SELECT adjust_value INTO v_comment 			FROM value_adjust WHERE adjust_type = 'comment'  			LIMIT 1;
    SELECT adjust_value INTO v_bookmark 		FROM value_adjust WHERE adjust_type = 'bookmark' 			LIMIT 1;
    SELECT adjust_value INTO v_share 			FROM value_adjust WHERE adjust_type = 'share' 	 			LIMIT 1;
    SELECT adjust_value INTO v_recent_view		FROM value_adjust WHERE adjust_type = 'recent_view'			LIMIT 1;
    SELECT adjust_value INTO v_recent_comment	FROM value_adjust WHERE adjust_type = 'recent_comment'		LIMIT 1;
    SELECT adjust_value INTO v_recent_bookmark	FROM value_adjust WHERE adjust_type = 'recent_bookmark'		LIMIT 1;
    SELECT adjust_value INTO v_recent_share		FROM value_adjust WHERE adjust_type = 'recent_share'		LIMIT 1;
    SELECT adjust_value INTO v_score 			FROM value_adjust WHERE adjust_type = 'score' 	 			LIMIT 1;
    
    -- 計算 favorite
    SET NEW.total_heat = 
    COALESCE(NEW.total_view, 0) * v_view + 
    COALESCE(NEW.total_comment, 0) * v_comment + 
    COALESCE(NEW.total_bookmark, 0) * v_bookmark + 
    COALESCE(NEW.total_share, 0) * v_share + 
    COALESCE(NEW.total_recent_view, 0) * v_recent_view + 
    COALESCE(NEW.total_recent_comment, 0) * v_recent_comment + 
    COALESCE(NEW.total_recent_bookmark, 0) * v_recent_bookmark + 
    COALESCE(NEW.total_recent_share, 0) * v_recent_share + 
    COALESCE(NEW.total_score, 0) * COALESCE (NEW.total_rater, 0) * v_score;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `caculate_heat (bu_multipleperspectives_data)` BEFORE UPDATE ON `multipleperspectives_data` FOR EACH ROW BEGIN
	-- 定義參數
    DECLARE v_view, v_comment, v_bookmark, v_share, v_score FLOAT DEFAULT 1.0;
    DECLARE v_recent_view, v_recent_comment, v_recent_bookmark, v_recent_share FLOAT DEFAULT 1.0;
    
    IF NOT (
        (NEW.total_view <=> OLD.total_view) AND 
        (NEW.total_comment <=> OLD.total_comment) AND
        (NEW.total_bookmark <=> OLD.total_bookmark) AND
        (NEW.total_share <=> OLD.total_share) AND
        (NEW.total_score <=> OLD.total_score) AND
        (NEW.total_recent_view <=> OLD.total_recent_view) AND
        (NEW.total_recent_comment <=> OLD.total_recent_comment) AND
        (NEW.total_recent_bookmark <=> OLD.total_recent_bookmark) AND
        (NEW.total_recent_share <=> OLD.total_recent_share) AND
        (NEW.total_heat <=> OLD.total_heat)
    )
    THEN
        -- 獲取參數係數
        SELECT adjust_value INTO v_view 			FROM value_adjust WHERE adjust_type = 'view' 	 			LIMIT 1;
        SELECT adjust_value INTO v_comment 			FROM value_adjust WHERE adjust_type = 'comment'  			LIMIT 1;
        SELECT adjust_value INTO v_bookmark 		FROM value_adjust WHERE adjust_type = 'bookmark' 			LIMIT 1;
        SELECT adjust_value INTO v_share 			FROM value_adjust WHERE adjust_type = 'share' 	 			LIMIT 1;
        SELECT adjust_value INTO v_recent_view		FROM value_adjust WHERE adjust_type = 'recent_view'			LIMIT 1;
        SELECT adjust_value INTO v_recent_comment	FROM value_adjust WHERE adjust_type = 'recent_comment'		LIMIT 1;
        SELECT adjust_value INTO v_recent_bookmark	FROM value_adjust WHERE adjust_type = 'recent_bookmark'		LIMIT 1;
        SELECT adjust_value INTO v_recent_share		FROM value_adjust WHERE adjust_type = 'recent_share'		LIMIT 1;
        SELECT adjust_value INTO v_score 			FROM value_adjust WHERE adjust_type = 'score' 	 			LIMIT 1;

        -- 計算 favorite
        SET NEW.total_heat = 
        COALESCE(NEW.total_view, 0) * v_view + 
        COALESCE(NEW.total_comment, 0) * v_comment + 
        COALESCE(NEW.total_bookmark, 0) * v_bookmark + 
        COALESCE(NEW.total_share, 0) * v_share + 
        COALESCE(NEW.total_recent_view, 0) * v_recent_view + 
        COALESCE(NEW.total_recent_comment, 0) * v_recent_comment + 
        COALESCE(NEW.total_recent_bookmark, 0) * v_recent_bookmark + 
        COALESCE(NEW.total_recent_share, 0) * v_recent_share + 
        COALESCE(NEW.total_score, 0) * COALESCE (NEW.total_rater, 0) * v_score;
	END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `reset_timestamp (bu_multupleperspectives_data)` BEFORE UPDATE ON `multipleperspectives_data` FOR EACH ROW IF NOT(
	NEW.multipleperspectives_title <=> OLD.multipleperspectives_title
)
THEN
	SET NEW.updated_at = NOW();
END IF
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `update_relation_heat (ai_multipleperspectives_data)` AFTER INSERT ON `multipleperspectives_data` FOR EACH ROW IF NOT (
    NEW.total_heat <=> 0
)
THEN
	UPDATE relation_data
    SET total_multipleperspectives_heat = NEW.total_heat
    WHERE relation_id = NEW.multipleperspectives_id;
END IF
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `update_relation_heat (au_multipleperspectives_data)` AFTER UPDATE ON `multipleperspectives_data` FOR EACH ROW IF NOT (
    NEW.total_heat <=> OLD.total_heat
)
THEN
	UPDATE relation_data
    SET total_multipleperspectives_heat = NEW.total_heat
    WHERE relation_id = NEW.multipleperspectives_id;
END IF
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- 資料表結構 `multipleperspectives_discuss`
--

CREATE TABLE `multipleperspectives_discuss` (
  `multipleperspectives_id` bigint(20) UNSIGNED NOT NULL,
  `discuss` longtext NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 觸發器 `multipleperspectives_discuss`
--
DELIMITER $$
CREATE TRIGGER `reset_timestamp (ai_multupleperspectives_discuss)` AFTER INSERT ON `multipleperspectives_discuss` FOR EACH ROW UPDATE multipleperspectives_data
SET updated_at = CURRENT_TIMESTAMP
WHERE multipleperspectives_id = NEW.multipleperspectives_id
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `reset_timestamp (au_multupleperspectives_discuss)` AFTER UPDATE ON `multipleperspectives_discuss` FOR EACH ROW UPDATE multipleperspectives_data
SET updated_at = CURRENT_TIMESTAMP
WHERE multipleperspectives_id = NEW.multipleperspectives_id
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- 資料表結構 `multipleperspectives_integrate`
--

CREATE TABLE `multipleperspectives_integrate` (
  `multipleperspectives_id` bigint(20) UNSIGNED NOT NULL,
  `integrate_id` int(10) UNSIGNED NOT NULL,
  `integrate_title` varchar(50) NOT NULL,
  `integrate_content` longtext NOT NULL,
  `integrate_percent` decimal(5,4) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 觸發器 `multipleperspectives_integrate`
--
DELIMITER $$
CREATE TRIGGER `reset_timestamp (ai_multupleperspectives_integrate)` AFTER INSERT ON `multipleperspectives_integrate` FOR EACH ROW UPDATE multipleperspectives_data
SET updated_at = CURRENT_TIMESTAMP
WHERE multipleperspectives_id = NEW.multipleperspectives_id
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `reset_timestamp (au_multupleperspectives_integrate)` AFTER UPDATE ON `multipleperspectives_integrate` FOR EACH ROW UPDATE multipleperspectives_data
SET updated_at = CURRENT_TIMESTAMP
WHERE multipleperspectives_id = NEW.multipleperspectives_id
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- 資料表結構 `news_body`
--

CREATE TABLE `news_body` (
  `news_body_id` bigint(20) UNSIGNED NOT NULL,
  `news_id` bigint(20) UNSIGNED NOT NULL,
  `body_type` enum('text','image') NOT NULL,
  `body_text` text DEFAULT NULL,
  `body_image` bigint(20) UNSIGNED DEFAULT NULL,
  `body_order` bigint(20) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 觸發器 `news_body`
--
DELIMITER $$
CREATE TRIGGER `check_null (bi_news_body)` BEFORE INSERT ON `news_body` FOR EACH ROW IF (
    ( (NEW.body_text IS NOT NULL) + 
      (NEW.body_image IS NOT NULL)
    ) != 1
) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Exactly one of body_text, body_image must be NOT NULL';
END IF
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `check_null (bu_news_body)` BEFORE UPDATE ON `news_body` FOR EACH ROW IF NOT (
    (NEW.body_text <=> OLD.body_text) AND 
    (NEW.body_image <=> OLD.body_image)
)
THEN
    IF (
        ((NEW.body_text IS NOT NULL) + 
         (NEW.body_image IS NOT NULL)
        ) != 1
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Exactly one of body_text, body_image must be NOT NULL';
    END IF;
END IF
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `reset_timestamp (ai_news_body)` AFTER INSERT ON `news_body` FOR EACH ROW UPDATE news_data
SET updated_at = CURRENT_TIMESTAMP
WHERE news_id = NEW.news_id
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `reset_timestamp (au_news_body)` AFTER UPDATE ON `news_body` FOR EACH ROW UPDATE news_data
SET updated_at = CURRENT_TIMESTAMP
WHERE news_id = NEW.news_id
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- 資料表結構 `news_data`
--

CREATE TABLE `news_data` (
  `news_id` bigint(20) UNSIGNED NOT NULL,
  `origin_url` varchar(100) NOT NULL,
  `channel_id` bigint(20) UNSIGNED DEFAULT NULL,
  `relation_id` bigint(20) UNSIGNED DEFAULT NULL,
  `cover_image` bigint(20) UNSIGNED DEFAULT NULL,
  `news_title` varchar(100) NOT NULL,
  `news_date` datetime NOT NULL,
  `news_url` varchar(300) DEFAULT NULL,
  `total_view` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_recent_view` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_share` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_recent_share` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_bookmark` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_recent_bookmark` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_comment` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_recent_comment` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_score` float NOT NULL DEFAULT 0,
  `total_rater` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_recent_score` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_heat` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 觸發器 `news_data`
--
DELIMITER $$
CREATE TRIGGER `caculate_heat (bi_news_data)` BEFORE INSERT ON `news_data` FOR EACH ROW BEGIN
    -- 定義參數
    DECLARE v_view, v_comment, v_bookmark, v_share, v_score FLOAT DEFAULT 1.0;
    DECLARE v_recent_view, v_recent_comment, v_recent_bookmark, v_recent_share FLOAT DEFAULT 1.0;
    
    -- 獲取參數係數
    SELECT adjust_value INTO v_view 			FROM value_adjust WHERE adjust_type = 'view' 	 			LIMIT 1;
    SELECT adjust_value INTO v_comment 			FROM value_adjust WHERE adjust_type = 'comment'  			LIMIT 1;
    SELECT adjust_value INTO v_bookmark 		FROM value_adjust WHERE adjust_type = 'bookmark' 			LIMIT 1;
    SELECT adjust_value INTO v_share 			FROM value_adjust WHERE adjust_type = 'share' 	 			LIMIT 1;
    SELECT adjust_value INTO v_recent_view		FROM value_adjust WHERE adjust_type = 'recent_view'			LIMIT 1;
    SELECT adjust_value INTO v_recent_comment	FROM value_adjust WHERE adjust_type = 'recent_comment'		LIMIT 1;
    SELECT adjust_value INTO v_recent_bookmark	FROM value_adjust WHERE adjust_type = 'recent_bookmark'		LIMIT 1;
    SELECT adjust_value INTO v_recent_share		FROM value_adjust WHERE adjust_type = 'recent_share'		LIMIT 1;
    SELECT adjust_value INTO v_score 			FROM value_adjust WHERE adjust_type = 'score' 	 			LIMIT 1;
    
    -- 計算 favorite
    SET NEW.total_heat = 
    COALESCE(NEW.total_view, 0) * v_view + 
    COALESCE(NEW.total_comment, 0) * v_comment + 
    COALESCE(NEW.total_bookmark, 0) * v_bookmark + 
    COALESCE(NEW.total_share, 0) * v_share + 
    COALESCE(NEW.total_recent_view, 0) * v_recent_view + 
    COALESCE(NEW.total_recent_comment, 0) * v_recent_comment + 
    COALESCE(NEW.total_recent_bookmark, 0) * v_recent_bookmark + 
    COALESCE(NEW.total_recent_share, 0) * v_recent_share + 
    COALESCE(NEW.total_score, 0) * COALESCE (NEW.total_rater, 0) * v_score;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `caculate_heat (bu_news_data)` BEFORE UPDATE ON `news_data` FOR EACH ROW BEGIN
	-- 定義參數
    DECLARE v_view, v_comment, v_bookmark, v_share, v_score FLOAT DEFAULT 1.0;
    DECLARE v_recent_view, v_recent_comment, v_recent_bookmark, v_recent_share FLOAT DEFAULT 1.0;
    
    IF NOT (
        (NEW.total_view <=> OLD.total_view) AND 
        (NEW.total_comment <=> OLD.total_comment) AND
        (NEW.total_bookmark <=> OLD.total_bookmark) AND
        (NEW.total_share <=> OLD.total_share) AND
        (NEW.total_score <=> OLD.total_score) AND
        (NEW.total_recent_view <=> OLD.total_recent_view) AND
        (NEW.total_recent_comment <=> OLD.total_recent_comment) AND
        (NEW.total_recent_bookmark <=> OLD.total_recent_bookmark) AND
        (NEW.total_recent_share <=> OLD.total_recent_share) AND
        (NEW.total_heat <=> OLD.total_heat)
    )
    THEN
        -- 獲取參數係數
        SELECT adjust_value INTO v_view 			FROM value_adjust WHERE adjust_type = 'view' 	 			LIMIT 1;
        SELECT adjust_value INTO v_comment 			FROM value_adjust WHERE adjust_type = 'comment'  			LIMIT 1;
        SELECT adjust_value INTO v_bookmark 		FROM value_adjust WHERE adjust_type = 'bookmark' 			LIMIT 1;
        SELECT adjust_value INTO v_share 			FROM value_adjust WHERE adjust_type = 'share' 	 			LIMIT 1;
        SELECT adjust_value INTO v_recent_view		FROM value_adjust WHERE adjust_type = 'recent_view'			LIMIT 1;
        SELECT adjust_value INTO v_recent_comment	FROM value_adjust WHERE adjust_type = 'recent_comment'		LIMIT 1;
        SELECT adjust_value INTO v_recent_bookmark	FROM value_adjust WHERE adjust_type = 'recent_bookmark'		LIMIT 1;
        SELECT adjust_value INTO v_recent_share		FROM value_adjust WHERE adjust_type = 'recent_share'		LIMIT 1;
        SELECT adjust_value INTO v_score 			FROM value_adjust WHERE adjust_type = 'score' 	 			LIMIT 1;

        -- 計算 favorite
        SET NEW.total_heat = 
        COALESCE(NEW.total_view, 0) * v_view + 
        COALESCE(NEW.total_comment, 0) * v_comment + 
        COALESCE(NEW.total_bookmark, 0) * v_bookmark + 
        COALESCE(NEW.total_share, 0) * v_share + 
        COALESCE(NEW.total_recent_view, 0) * v_recent_view + 
        COALESCE(NEW.total_recent_comment, 0) * v_recent_comment + 
        COALESCE(NEW.total_recent_bookmark, 0) * v_recent_bookmark + 
        COALESCE(NEW.total_recent_share, 0) * v_recent_share + 
        COALESCE(NEW.total_score, 0) * COALESCE (NEW.total_rater, 0) * v_score;
	END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `change_relation (bu_news_data)` BEFORE UPDATE ON `news_data` FOR EACH ROW IF NOT (
    NEW.relation_id <=> OLD.relation_id
)
THEN
	-- OLD relation_id 減掉
    UPDATE relation_data
    SET total_news_heat =  total_news_heat - NEW.total_heat
    WHERE relation_id = OLD.relation_id;
    
    -- NEW relation_id 新增
    UPDATE relation_data
    SET total_news_heat = total_news_heat + NEW.total_heat
    WHERE relation_id = NEW.relation_id;
END IF
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `reset_timestamp (bu_news_data)` BEFORE UPDATE ON `news_data` FOR EACH ROW IF NOT(
	NEW.channel_id <=> OLD.channel_id AND
	NEW.relation_id <=> OLD.relation_id AND
	NEW.cover_image  <=> OLD.cover_image AND
	NEW.news_title <=> OLD.news_title AND
	NEW.news_date <=> OLD.news_date
)
THEN
	SET NEW.updated_at = NOW();
END IF
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `update_relation_heat (ai_news_data)` AFTER INSERT ON `news_data` FOR EACH ROW IF NOT (
    NEW.total_heat <=> 0
)
THEN
    UPDATE relation_data
    SET total_news_heat = total_news_heat + NEW.total_heat
    WHERE relation_id = NEW.relation_id;
END IF
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `update_relation_heat (au_news_data)` AFTER UPDATE ON `news_data` FOR EACH ROW IF NOT (
    NEW.total_heat <=> OLD.total_heat
)
THEN
    UPDATE relation_data
    SET total_news_heat = total_news_heat + ( NEW.total_heat - OLD.total_heat )
    WHERE relation_id = NEW.relation_id;
END IF
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `update_relation_news` AFTER INSERT ON `news_data` FOR EACH ROW UPDATE relation_data
SET total_news = total_news + 1
WHERE relation_id = NEW.relation_id
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- 資料表結構 `news_group`
--

CREATE TABLE `news_group` (
  `news_group_id` bigint(20) NOT NULL,
  `news_id` bigint(20) UNSIGNED NOT NULL,
  `group_data_id` int(10) UNSIGNED DEFAULT NULL,
  `group_detail_id` int(10) UNSIGNED DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 觸發器 `news_group`
--
DELIMITER $$
CREATE TRIGGER `check_null (bi_news_group)` BEFORE INSERT ON `news_group` FOR EACH ROW IF (
    ( (NEW.group_data_id IS NOT NULL) + 
      (NEW.group_detail_id IS NOT NULL)
    ) != 1
) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Exactly one of group_data_id, group_detail_id must be NOT NULL';
END IF
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `check_null (bu_news_group)` BEFORE UPDATE ON `news_group` FOR EACH ROW IF NOT (
    (NEW.group_data_id <=> OLD.group_data_id) AND 
    (NEW.group_detail_id <=> OLD.group_detail_id)
)
THEN
	IF (
        ((NEW.group_data_id IS NOT NULL) + 
         (NEW.group_detail_id IS NOT NULL)
        ) != 1
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Exactly one of group_data_id, group_detail_id must be NOT NULL';
	END IF;
END IF
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `reset_timestamp (ai_news_group)` AFTER INSERT ON `news_group` FOR EACH ROW UPDATE news_data
SET updated_at = CURRENT_TIMESTAMP
WHERE news_id = NEW.news_id
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `reset_timestamp (au_news_group)` AFTER UPDATE ON `news_group` FOR EACH ROW UPDATE news_data
SET updated_at = CURRENT_TIMESTAMP
WHERE news_id = NEW.news_id
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- 資料表結構 `news_location`
--

CREATE TABLE `news_location` (
  `news_location_id` bigint(20) UNSIGNED NOT NULL,
  `news_id` bigint(20) UNSIGNED NOT NULL,
  `location_region_id` int(11) DEFAULT NULL,
  `location_country_id` int(11) DEFAULT NULL,
  `location_state_id` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 觸發器 `news_location`
--
DELIMITER $$
CREATE TRIGGER `check_null (bi_news_location)` BEFORE INSERT ON `news_location` FOR EACH ROW IF (
    ( (NEW.location_region_id IS NOT NULL) + 
      (NEW.location_country_id IS NOT NULL) + 
      (NEW.location_state_id IS NOT NULL)
    ) != 1
) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Exactly one of location_region_id, location_country_id, location_state_id must be NOT NULL';
END IF
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `check_null (bu_news_location)` BEFORE UPDATE ON `news_location` FOR EACH ROW IF NOT (
    (NEW.location_region_id <=> OLD.location_region_id) AND 
    (NEW.location_country_id <=> OLD.location_country_id) AND
    (NEW.location_state_id <=> OLD.location_state_id)
)
THEN
    IF (
		((NEW.location_region_id IS NOT NULL) + 
         (NEW.location_country_id IS NOT NULL) + 
         (NEW.location_state_id IS NOT NULL)
        ) != 1
    ) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = 'Exactly one of location_region_id, location_country_id, location_state_id must be NOT NULL';
	END IF;
END IF
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `reset_timestamp (ai_news_location)` AFTER INSERT ON `news_location` FOR EACH ROW UPDATE news_data
SET updated_at = CURRENT_TIMESTAMP
WHERE news_id = NEW.news_id
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `reset_timestamp (au_news_location)` AFTER UPDATE ON `news_location` FOR EACH ROW UPDATE news_data
SET updated_at = CURRENT_TIMESTAMP
WHERE news_id = NEW.news_id
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- 資料表結構 `permission_level`
--

CREATE TABLE `permission_level` (
  `level_id` tinyint(4) NOT NULL DEFAULT 0,
  `level_name` varchar(30) NOT NULL,
  `manage_data` tinyint(4) NOT NULL DEFAULT 0,
  `add_manager` tinyint(4) NOT NULL DEFAULT 0,
  `inherited_position` tinyint(4) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `relation_data`
--

CREATE TABLE `relation_data` (
  `relation_id` bigint(20) UNSIGNED NOT NULL,
  `relation_summary` varchar(200) DEFAULT NULL,
  `total_news` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_recent_news` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_news_heat` float NOT NULL DEFAULT 0,
  `total_eventsorting_heat` float NOT NULL DEFAULT 0,
  `total_multipleperspectives_heat` float NOT NULL DEFAULT 0,
  `total_heat` float NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 觸發器 `relation_data`
--
DELIMITER $$
CREATE TRIGGER `caculate_heat (bi_relation_data)` BEFORE INSERT ON `relation_data` FOR EACH ROW BEGIN
	-- 定義參數
    DECLARE v_news, v_recent_news, v_news_heat, v_eventsorting_heat, v_multipleperspectives_heat FLOAT DEFAULT 1.0;
    
    -- 獲取參數係數
	SELECT adjust_value INTO v_news 					 FROM value_adjust WHERE adjust_type = 'news' 	 					LIMIT 1;
	SELECT adjust_value INTO v_recent_news 				 FROM value_adjust WHERE adjust_type = 'recent_news'				LIMIT 1;
	SELECT adjust_value INTO v_news_heat 				 FROM value_adjust WHERE adjust_type = 'news_heat'					LIMIT 1;
	SELECT adjust_value INTO v_eventsorting_heat		 FROM value_adjust WHERE adjust_type = 'eventsorting_heat'			LIMIT 1;
	SELECT adjust_value INTO v_multipleperspectives_heat FROM value_adjust WHERE adjust_type = 'multipleperspectives_heat'	LIMIT 1;

	-- 計算 favorite
	SET NEW.total_heat = 
	COALESCE (NEW.total_news, 0) * v_news + 
	COALESCE (NEW.total_recent_news, 0) * v_recent_news + 
    COALESCE (NEW.total_news_heat, 0) * v_news_heat + 
    COALESCE (NEW.total_eventsorting_heat, 0) * v_eventsorting_heat + 
    COALESCE (NEW.total_multipleperspectives_heat, 0) * v_multipleperspectives_heat;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `caculate_heat (bu_relation_data)` BEFORE UPDATE ON `relation_data` FOR EACH ROW BEGIN
	-- 定義參數
    DECLARE v_news, v_recent_news, v_news_heat, v_eventsorting_heat, v_multipleperspectives_heat FLOAT DEFAULT 1.0;
    
    IF NOT (
        (NEW.total_news <=> OLD.total_news) AND 
        (NEW.total_recent_news <=> OLD.total_recent_news) AND 
        (NEW.total_news_heat <=> OLD.total_news_heat) AND 
        (NEW.total_eventsorting_heat <=> OLD.total_eventsorting_heat) AND 
        (NEW.total_multipleperspectives_heat <=> OLD.total_multipleperspectives_heat) AND 
        (NEW.total_heat <=> OLD.total_heat)
    )
    THEN
        -- 獲取參數係數
        SELECT adjust_value INTO v_news 					 FROM value_adjust WHERE adjust_type = 'news' 	 					LIMIT 1;
        SELECT adjust_value INTO v_recent_news 				 FROM value_adjust WHERE adjust_type = 'recent_news'				LIMIT 1;
        SELECT adjust_value INTO v_news_heat 				 FROM value_adjust WHERE adjust_type = 'news_heat'					LIMIT 1;
        SELECT adjust_value INTO v_eventsorting_heat		 FROM value_adjust WHERE adjust_type = 'eventsorting_heat'			LIMIT 1;
        SELECT adjust_value INTO v_multipleperspectives_heat FROM value_adjust WHERE adjust_type = 'multipleperspectives_heat'	LIMIT 1;

        -- 計算 favorite
        SET NEW.total_heat = 
        COALESCE (NEW.total_news, 0) * v_news + 
        COALESCE (NEW.total_recent_news, 0) * v_recent_news + 
        COALESCE (NEW.total_news_heat, 0) * v_news_heat + 
        COALESCE (NEW.total_eventsorting_heat, 0) * v_eventsorting_heat + 
        COALESCE (NEW.total_multipleperspectives_heat, 0) * v_multipleperspectives_heat;
	END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `reset_timestamp (au_relation_data)` BEFORE UPDATE ON `relation_data` FOR EACH ROW IF NOT (
	NEW.relation_summary <=> OLD.relation_summary
)
THEN
	SET NEW.updated_at = NOW();
END IF
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- 資料表結構 `relation_keyword`
--

CREATE TABLE `relation_keyword` (
  `relation_id` bigint(20) UNSIGNED NOT NULL,
  `keyword_id` bigint(20) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 觸發器 `relation_keyword`
--
DELIMITER $$
CREATE TRIGGER `reset_timestamp (ai_relation_keyword)` AFTER INSERT ON `relation_keyword` FOR EACH ROW UPDATE relation_data
SET updated_at = CURRENT_TIMESTAMP
WHERE relation_id = NEW.relation_id
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `reset_timestamp (au_relation_keyword)` AFTER UPDATE ON `relation_keyword` FOR EACH ROW UPDATE relation_data
SET updated_at = CURRENT_TIMESTAMP
WHERE relation_id = NEW.relation_id
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- 資料表結構 `user_anonymous`
--

CREATE TABLE `user_anonymous` (
  `user_id` int(10) UNSIGNED NOT NULL,
  `anonymous_id` int(10) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `user_bookmark`
--

CREATE TABLE `user_bookmark` (
  `bookmark_id` int(10) UNSIGNED NOT NULL,
  `user_id` int(10) UNSIGNED NOT NULL,
  `news_id` bigint(20) UNSIGNED DEFAULT NULL,
  `channel_id` bigint(20) UNSIGNED DEFAULT NULL,
  `eventsorting_id` bigint(20) UNSIGNED DEFAULT NULL,
  `multipleperspectives_id` bigint(20) UNSIGNED DEFAULT NULL,
  `groupcustomize_id` bigint(20) UNSIGNED DEFAULT NULL,
  `recent_count` tinyint(4) NOT NULL DEFAULT 0,
  `ceated_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 觸發器 `user_bookmark`
--
DELIMITER $$
CREATE TRIGGER `check_null (bi_user_bookmark)` BEFORE INSERT ON `user_bookmark` FOR EACH ROW IF (
    ( (NEW.news_id IS NOT NULL) + 
      (NEW.channel_id IS NOT NULL) + 
      (NEW.eventsorting_id IS NOT NULL) + 
      (NEW.multipleperspectives_id IS NOT NULL)
    ) != 1
) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Exactly one of news_id, channel_id, eventsorting_id, multipleperspectives_id must be NOT NULL';
END IF
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `check_null (bu_user_bookmark)` BEFORE UPDATE ON `user_bookmark` FOR EACH ROW IF NOT (
    (NEW.news_id <=> OLD.news_id) AND 
    (NEW.channel_id <=> OLD.channel_id) AND
    (NEW.eventsorting_id <=> OLD.eventsorting_id) AND
    (NEW.multipleperspectives_id <=> OLD.multipleperspectives_id)
)
THEN
    IF (
        ( (NEW.news_id IS NOT NULL) + 
          (NEW.channel_id IS NOT NULL) + 
          (NEW.eventsorting_id IS NOT NULL) + 
          (NEW.multipleperspectives_id IS NOT NULL)
        ) != 1
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Exactly one of news_id, channel_id, eventsorting_id, multipleperspectives_id must be NOT NULL';
    END IF;
END IF
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `delete_action (ad_user_bookmark)` AFTER DELETE ON `user_bookmark` FOR EACH ROW BEGIN
    -- news
    IF OLD.news_id IS NOT NULL
    THEN
        UPDATE news_data
        SET total_bookmark = GREATEST(total_bookmark - 1, 0)
        WHERE news_id = OLD.news_id;
    END IF;
    
	-- channel
    IF OLD.channel_id IS NOT NULL
    THEN
        UPDATE channel_data
        SET total_bookmark = GREATEST(total_bookmark - 1, 0)
        WHERE channel_id = OLD.channel_id;
    END IF;
    
    -- eventsorting
    IF OLD.eventsorting_id IS NOT NULL
    THEN
        UPDATE eventsorting_data
        SET total_bookmark = GREATEST(total_bookmark - 1, 0)
        WHERE eventsorting_id = OLD.eventsorting_id;
    END IF;
    
	-- multipleperspectives
    IF OLD.multipleperspectives_id IS NOT NULL
    THEN
        UPDATE multipleperspectives_data
        SET total_bookmark = GREATEST(total_bookmark - 1, 0)
        WHERE multipleperspectives_id = OLD.multipleperspectives_id;
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `insert_action (ai_user_bookmark)` AFTER INSERT ON `user_bookmark` FOR EACH ROW BEGIN
    -- news
    IF NOT(
        NEW.news_id <=> NULL
    ) THEN
        UPDATE news_data
        SET total_bookmaek = total_bookmaek + 1
        WHERE news_id = NEW.news_id;
    END IF;
    
	-- channel
    IF NOT(
        NEW.channel_id <=> NULL
    ) THEN
        UPDATE channel_data
        SET total_bookmaek = total_bookmaek + 1
        WHERE channel_id = NEW.channel_id;
    END IF;
    
    -- eventsorting
    IF NOT(
        NEW.eventsorting_id <=> NULL
    ) THEN
        UPDATE eventsorting_data
        SET total_bookmaek = total_bookmaek + 1
        WHERE eventsorting_id = NEW.eventsorting_id;
    END IF;
    
	-- multipleperspectives
    IF NOT(
        NEW.multipleperspectives_id <=> NULL
    ) THEN
        UPDATE multipleperspectives_data
        SET total_bookmaek = total_bookmaek + 1
        WHERE multipleperspectives_id = NEW.multipleperspectives_id;
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- 資料表結構 `user_comment`
--

CREATE TABLE `user_comment` (
  `comment_id` int(10) UNSIGNED NOT NULL,
  `user_id` int(10) UNSIGNED NOT NULL,
  `anonymous_id` int(10) UNSIGNED DEFAULT NULL,
  `news_id` bigint(20) UNSIGNED DEFAULT NULL,
  `channel_id` bigint(20) UNSIGNED DEFAULT NULL,
  `eventsorting_id` bigint(20) UNSIGNED DEFAULT NULL,
  `multipleperspectives_id` bigint(20) UNSIGNED DEFAULT NULL,
  `comment_text` varchar(500) NOT NULL,
  `recent_count` tinyint(4) NOT NULL DEFAULT 0,
  `ceated_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 觸發器 `user_comment`
--
DELIMITER $$
CREATE TRIGGER `check_null (bi_user_comment)` BEFORE INSERT ON `user_comment` FOR EACH ROW IF (
    ( (NEW.news_id IS NOT NULL) + 
      (NEW.channel_id IS NOT NULL) + 
      (NEW.eventsorting_id IS NOT NULL) + 
      (NEW.multipleperspectives_id IS NOT NULL)
    ) != 1
) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Exactly one of news_id, channel_id, eventsorting_id, multipleperspectives_id must be NOT NULL';
END IF
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `check_null (bu_user_comment)` BEFORE UPDATE ON `user_comment` FOR EACH ROW IF NOT (
    (NEW.news_id <=> OLD.news_id) AND 
    (NEW.channel_id <=> OLD.channel_id) AND
    (NEW.eventsorting_id <=> OLD.eventsorting_id) AND
    (NEW.multipleperspectives_id <=> OLD.multipleperspectives_id)
)
THEN
    IF (
        ( (NEW.news_id IS NOT NULL) + 
          (NEW.channel_id IS NOT NULL) + 
          (NEW.eventsorting_id IS NOT NULL) + 
          (NEW.multipleperspectives_id IS NOT NULL)
        ) != 1
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Exactly one of news_id, channel_id, eventsorting_id, multipleperspectives_id must be NOT NULL';
    END IF;
END IF
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `delete_action (ad_user_comment)` AFTER DELETE ON `user_comment` FOR EACH ROW BEGIN
    -- news
    IF OLD.news_id IS NOT NULL
    THEN
        UPDATE news_data
        SET total_comment = GREATEST(total_comment - 1, 0)
        WHERE news_id = OLD.news_id;
    END IF;
    
	-- channel
    IF OLD.channel_id IS NOT NULL
    THEN
        UPDATE channel_data
        SET total_comment = GREATEST(total_comment - 1, 0)
        WHERE channel_id = OLD.channel_id;
    END IF;
    
    -- eventsorting
    IF OLD.eventsorting_id IS NOT NULL
    THEN
        UPDATE eventsorting_data
        SET total_comment = GREATEST(total_comment - 1, 0)
        WHERE eventsorting_id = OLD.eventsorting_id;
    END IF;
    
	-- multipleperspectives
    IF OLD.multipleperspectives_id IS NOT NULL
    THEN
        UPDATE multipleperspectives_data
        SET total_comment = GREATEST(total_comment - 1, 0)
        WHERE multipleperspectives_id = OLD.multipleperspectives_id;
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `insert_action (ai_user_comment)` AFTER INSERT ON `user_comment` FOR EACH ROW BEGIN
    -- news
    IF NOT(
        NEW.news_id <=> NULL
    ) THEN
        UPDATE news_data
        SET total_comment = total_comment + 1
        WHERE news_id = NEW.news_id;
    END IF;
    
	-- channel
    IF NOT(
        NEW.channel_id <=> NULL
    ) THEN
        UPDATE channel_data
        SET total_comment = total_comment + 1
        WHERE channel_id = NEW.channel_id;
    END IF;
    
    -- eventsorting
    IF NOT(
        NEW.eventsorting_id <=> NULL
    ) THEN
        UPDATE eventsorting_data
        SET total_comment = total_comment + 1
        WHERE eventsorting_id = NEW.eventsorting_id;
    END IF;
    
	-- multipleperspectives
    IF NOT(
        NEW.multipleperspectives_id <=> NULL
    ) THEN
        UPDATE multipleperspectives_data
        SET total_comment = total_comment + 1
        WHERE multipleperspectives_id = NEW.multipleperspectives_id;
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- 資料表結構 `user_favorite`
--

CREATE TABLE `user_favorite` (
  `user_id` int(10) UNSIGNED NOT NULL,
  `group_data_id` int(10) UNSIGNED DEFAULT NULL,
  `group_detail_id` int(10) UNSIGNED DEFAULT NULL,
  `total_views` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_recent_views` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `total_favorite` float NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 觸發器 `user_favorite`
--
DELIMITER $$
CREATE TRIGGER `caculate_heat (bi_user_favorite)` BEFORE INSERT ON `user_favorite` FOR EACH ROW BEGIN
	-- 定義參數
    DECLARE v_views, v_recent_views FLOAT DEFAULT 1.0;
    
    -- 獲取參數係數
    SELECT adjust_value INTO v_views FROM value_adjust WHERE adjust_type = 'views' LIMIT 1;
    SELECT adjust_value INTO v_recent_views FROM value_adjust WHERE adjust_type = 'recent_views' LIMIT 1;
    
    -- 計算 favorite
    SET NEW.total_favorite = 
    COALESCE(NEW.total_views, 0) * v_views + 
    COALESCE(NEW.total_recent_views, 0) * v_recent_views;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `caculate_heat (bu_user_favorite)` BEFORE UPDATE ON `user_favorite` FOR EACH ROW BEGIN
    -- 定義參數
    DECLARE v_views, v_recent_views FLOAT DEFAULT 1.0;

    IF NOT (
        (NEW.total_views <=> OLD.total_views) AND 
        (NEW.total_recent_views <=> OLD.total_recent_views)
    )
    THEN
        -- 獲取參數係數
        SELECT adjust_value INTO v_views FROM value_adjust WHERE adjust_type = 'views' LIMIT 1;
        SELECT adjust_value INTO v_recent_views FROM value_adjust WHERE adjust_type = 'recent_views' LIMIT 1;

        -- 計算 favorite
        SET NEW.total_favorite = 
        COALESCE(NEW.total_views, 0) * v_views + 
        COALESCE(NEW.total_recent_views, 0) * v_recent_views;
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `check_null (bi_user_favorite)` BEFORE INSERT ON `user_favorite` FOR EACH ROW IF (
    ( (NEW.group_data_id IS NOT NULL) + 
      (NEW.group_detail_id IS NOT NULL)
    ) != 1
) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Exactly one of group_data_id, group_detail_id must be NOT NULL';
END IF
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `check_null (bu_user_favorite)` BEFORE UPDATE ON `user_favorite` FOR EACH ROW IF NOT(
    (NEW.group_data_id <=> OLD.group_data_id) AND 
    (NEW.group_detail_id <=> OLD.group_detail_id)
)
THEN
	IF (
        ((NEW.group_data_id IS NOT NULL) + 
         (NEW.group_detail_id IS NOT NULL)
        ) != 1
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Exactly one of group_data_id, group_detail_id must be NOT NULL';
	END IF;
END IF
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- 資料表結構 `user_location`
--

CREATE TABLE `user_location` (
  `user_id` int(11) NOT NULL,
  `region_id` int(11) NOT NULL,
  `country_id` int(11) NOT NULL,
  `state_id` int(11) NOT NULL,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 觸發器 `user_location`
--
DELIMITER $$
CREATE TRIGGER `check_null (bi_user_location)` BEFORE INSERT ON `user_location` FOR EACH ROW IF (
    ( (NEW.region_id IS NOT NULL) + 
      (NEW.country_id IS NOT NULL) + 
      (NEW.state_id IS NOT NULL)
    ) != 1
) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Exactly one of region_id, country_id, state_id must be NOT NULL';
END IF
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `check_null (bu_user_location)` BEFORE UPDATE ON `user_location` FOR EACH ROW IF NOT (
    (NEW.region_id <=> OLD.region_id) AND
    (NEW.country_id <=> OLD.country_id) AND
    (NEW.state_id <=> OLD.state_id)
)
THEN
    IF (
		((NEW.region_id IS NOT NULL) + 
         (NEW.country_id IS NOT NULL) + 
         (NEW.state_id IS NOT NULL)
        ) != 1
    ) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = 'Exactly one of region_id, country_id, state_id must be NOT NULL';
	END IF;
END IF
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- 資料表結構 `user_profile`
--

CREATE TABLE `user_profile` (
  `user_id` int(10) UNSIGNED NOT NULL,
  `user_account` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `user_password` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `user_name` varchar(50) NOT NULL,
  `user_birthday` date DEFAULT NULL,
  `user_email` varchar(254) DEFAULT NULL,
  `user_phone` varchar(20) DEFAULT NULL,
  `user_notification` tinyint(1) NOT NULL DEFAULT 0,
  `user_ai_mode` tinyint(4) NOT NULL DEFAULT 0,
  `user_ai_sound` tinyint(4) NOT NULL DEFAULT 0,
  `location_region_id` int(11) DEFAULT NULL,
  `location_country_id` int(11) DEFAULT 216,
  `location_state_id` int(11) DEFAULT NULL,
  `user_level` tinyint(4) NOT NULL DEFAULT 0,
  `ceated_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 觸發器 `user_profile`
--
DELIMITER $$
CREATE TRIGGER `check_null (bi_user_profile)` BEFORE INSERT ON `user_profile` FOR EACH ROW IF (
    ( (NEW.location_region_id IS NOT NULL) + 
      (NEW.location_country_id IS NOT NULL) + 
      (NEW.location_state_id IS NOT NULL)
    ) != 1
) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Exactly one of location_region_id, location_country_id, location_state_id must be NOT NULL';
END IF
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `check_null (bu_user_profile)` BEFORE UPDATE ON `user_profile` FOR EACH ROW IF NOT (
    (NEW.location_region_id <=> OLD.location_region_id) AND
    (NEW.location_country_id <=> OLD.location_country_id) AND
    (NEW.location_state_id <=> OLD.location_state_id)
)
THEN
    IF (
		((NEW.location_region_id IS NOT NULL) + 
         (NEW.location_country_id IS NOT NULL) + 
         (NEW.location_state_id IS NOT NULL)
        ) != 1
    ) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = 'Exactly one of location_region_id, location_country_id, location_state_id must be NOT NULL';
	END IF;
END IF
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- 資料表結構 `user_score`
--

CREATE TABLE `user_score` (
  `score_id` int(10) UNSIGNED NOT NULL,
  `user_id` int(10) UNSIGNED NOT NULL,
  `news_id` bigint(20) UNSIGNED DEFAULT NULL,
  `channel_id` bigint(20) UNSIGNED DEFAULT NULL,
  `eventsorting_id` bigint(20) UNSIGNED DEFAULT NULL,
  `multipleperspectives_id` bigint(20) UNSIGNED DEFAULT NULL,
  `target_score` tinyint(4) NOT NULL,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 觸發器 `user_score`
--
DELIMITER $$
CREATE TRIGGER `check_null (bi_user_score)` BEFORE INSERT ON `user_score` FOR EACH ROW IF (
    ( (NEW.news_id IS NOT NULL) + 
      (NEW.channel_id IS NOT NULL) + 
      (NEW.eventsorting_id IS NOT NULL) + 
      (NEW.multipleperspectives_id IS NOT NULL)
    ) != 1
) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Exactly one of news_id, channel_id, eventsorting_id, multipleperspectives_id must be NOT NULL';
END IF
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `check_null (bu_user_score)` BEFORE UPDATE ON `user_score` FOR EACH ROW IF NOT (
    (NEW.news_id <=> OLD.news_id) AND 
    (NEW.channel_id <=> OLD.channel_id) AND
    (NEW.eventsorting_id <=> OLD.eventsorting_id) AND
    (NEW.multipleperspectives_id <=> OLD.multipleperspectives_id)
)
THEN
    IF (
        ( (NEW.news_id IS NOT NULL) + 
          (NEW.channel_id IS NOT NULL) + 
          (NEW.eventsorting_id IS NOT NULL) + 
          (NEW.multipleperspectives_id IS NOT NULL)
        ) != 1
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Exactly one of news_id, channel_id, eventsorting_id, multipleperspectives_id must be NOT NULL';
    END IF;
END IF
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- 資料表結構 `user_search`
--

CREATE TABLE `user_search` (
  `search_id` int(11) NOT NULL,
  `user_id` int(10) UNSIGNED DEFAULT NULL,
  `user_ip` varchar(45) DEFAULT NULL,
  `keyword_id` bigint(20) UNSIGNED NOT NULL,
  `type` enum('news','channel','eventsorting','multipleperspectives') NOT NULL,
  `update_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 觸發器 `user_search`
--
DELIMITER $$
CREATE TRIGGER `check_null (bi_user_search)` BEFORE INSERT ON `user_search` FOR EACH ROW IF (
    ( (NEW.news_id IS NOT NULL) + 
      (NEW.channel_id IS NOT NULL) + 
      (NEW.eventsorting_id IS NOT NULL) + 
      (NEW.multipleperspectives_id IS NOT NULL)
    ) != 1
) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Exactly one of news_id, channel_id, eventsorting_id, multipleperspectives_id must be NOT NULL';
END IF
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `check_null (bu_user_search)` BEFORE UPDATE ON `user_search` FOR EACH ROW IF NOT (
    (NEW.news_id <=> OLD.news_id) AND 
    (NEW.channel_id <=> OLD.channel_id) AND
    (NEW.eventsorting_id <=> OLD.eventsorting_id) AND
    (NEW.multipleperspectives_id <=> OLD.multipleperspectives_id)
)
THEN
    IF (
        ( (NEW.news_id IS NOT NULL) + 
          (NEW.channel_id IS NOT NULL) + 
          (NEW.eventsorting_id IS NOT NULL) + 
          (NEW.multipleperspectives_id IS NOT NULL)
        ) != 1
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Exactly one of news_id, channel_id, eventsorting_id, multipleperspectives_id must be NOT NULL';
    END IF;
END IF
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `insert_action (ai_user_search)` AFTER INSERT ON `user_search` FOR EACH ROW BEGIN
    -- news
    IF NOT(
        NEW.news_id <=> NULL
    ) THEN
        UPDATE news_data
        SET total_view = total_view + 1
        WHERE news_id = NEW.news_id;
    END IF;
    
	-- channel
    IF NOT(
        NEW.channel_id <=> NULL
    ) THEN
        UPDATE channel_data
        SET total_view = total_view + 1
        WHERE channel_id = NEW.channel_id;
    END IF;
    
    -- eventsorting
    IF NOT(
        NEW.eventsorting_id <=> NULL
    ) THEN
        UPDATE eventsorting_data
        SET total_view = total_view + 1
        WHERE eventsorting_id = NEW.eventsorting_id;
    END IF;
    
	-- multipleperspectives
    IF NOT(
        NEW.multipleperspectives_id <=> NULL
    ) THEN
        UPDATE multipleperspectives_data
        SET total_view = total_view + 1
        WHERE multipleperspectives_id = NEW.multipleperspectives_id;
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- 資料表結構 `user_share`
--

CREATE TABLE `user_share` (
  `view_id` bigint(20) UNSIGNED NOT NULL,
  `user_id` int(10) UNSIGNED DEFAULT NULL,
  `user_ip` varchar(45) DEFAULT NULL,
  `news_id` bigint(20) UNSIGNED DEFAULT NULL,
  `channel_id` bigint(20) UNSIGNED DEFAULT NULL,
  `eventsorting_id` bigint(20) UNSIGNED DEFAULT NULL,
  `multipleperspectives_id` bigint(20) UNSIGNED DEFAULT NULL,
  `recent_count` tinyint(4) NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 觸發器 `user_share`
--
DELIMITER $$
CREATE TRIGGER `check_null (bi_user_share)` BEFORE INSERT ON `user_share` FOR EACH ROW IF (
    ( (NEW.news_id IS NOT NULL) + 
      (NEW.channel_id IS NOT NULL) + 
      (NEW.eventsorting_id IS NOT NULL) + 
      (NEW.multipleperspectives_id IS NOT NULL)
    ) != 1
) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Exactly one of news_id, channel_id, eventsorting_id, multipleperspectives_id must be NOT NULL';
END IF
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `check_null (bu_user_share)` BEFORE UPDATE ON `user_share` FOR EACH ROW IF NOT (
    (NEW.news_id <=> OLD.news_id) AND 
    (NEW.channel_id <=> OLD.channel_id) AND
    (NEW.eventsorting_id <=> OLD.eventsorting_id) AND
    (NEW.multipleperspectives_id <=> OLD.multipleperspectives_id)
)
THEN
    IF (
        ( (NEW.news_id IS NOT NULL) + 
          (NEW.channel_id IS NOT NULL) + 
          (NEW.eventsorting_id IS NOT NULL) + 
          (NEW.multipleperspectives_id IS NOT NULL)
        ) != 1
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Exactly one of news_id, channel_id, eventsorting_id, multipleperspectives_id must be NOT NULL';
    END IF;
END IF
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `insert_action (ai_user_share)` AFTER INSERT ON `user_share` FOR EACH ROW BEGIN
    -- news
    IF NOT(
        NEW.news_id <=> NULL
    ) THEN
        UPDATE news_data
        SET total_share = total_share + 1
        WHERE news_id = NEW.news_id;
    END IF;
    
	-- channel
    IF NOT(
        NEW.channel_id <=> NULL
    ) THEN
        UPDATE channel_data
        SET total_share = total_share + 1
        WHERE channel_id = NEW.channel_id;
    END IF;
    
    -- eventsorting
    IF NOT(
        NEW.eventsorting_id <=> NULL
    ) THEN
        UPDATE eventsorting_data
        SET total_share = total_share + 1
        WHERE eventsorting_id = NEW.eventsorting_id;
    END IF;
    
	-- multipleperspectives
    IF NOT(
        NEW.multipleperspectives_id <=> NULL
    ) THEN
        UPDATE multipleperspectives_data
        SET total_share = total_share + 1
        WHERE multipleperspectives_id = NEW.multipleperspectives_id;
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- 資料表結構 `user_view`
--

CREATE TABLE `user_view` (
  `view_id` bigint(20) UNSIGNED NOT NULL,
  `user_id` int(10) UNSIGNED DEFAULT NULL,
  `user_ip` varchar(45) DEFAULT NULL,
  `news_id` bigint(20) UNSIGNED DEFAULT NULL,
  `channel_id` bigint(20) UNSIGNED DEFAULT NULL,
  `eventsorting_id` bigint(20) UNSIGNED DEFAULT NULL,
  `multipleperspectives_id` bigint(20) UNSIGNED DEFAULT NULL,
  `recent_count` tinyint(4) NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 觸發器 `user_view`
--
DELIMITER $$
CREATE TRIGGER `check_null (bi_user_view)` BEFORE INSERT ON `user_view` FOR EACH ROW IF (
    ( (NEW.news_id IS NOT NULL) + 
      (NEW.channel_id IS NOT NULL) + 
      (NEW.eventsorting_id IS NOT NULL) + 
      (NEW.multipleperspectives_id IS NOT NULL)
    ) != 1
) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Exactly one of news_id, channel_id, eventsorting_id, multipleperspectives_id must be NOT NULL';
END IF
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `check_null (bu_user_view)` BEFORE UPDATE ON `user_view` FOR EACH ROW IF NOT (
    (NEW.news_id <=> OLD.news_id) AND 
    (NEW.channel_id <=> OLD.channel_id) AND
    (NEW.eventsorting_id <=> OLD.eventsorting_id) AND
    (NEW.multipleperspectives_id <=> OLD.multipleperspectives_id)
)
THEN
    IF (
        ( (NEW.news_id IS NOT NULL) + 
          (NEW.channel_id IS NOT NULL) + 
          (NEW.eventsorting_id IS NOT NULL) + 
          (NEW.multipleperspectives_id IS NOT NULL)
        ) != 1
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Exactly one of news_id, channel_id, eventsorting_id, multipleperspectives_id must be NOT NULL';
    END IF;
END IF
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `insert_action (ai_user_view)` AFTER INSERT ON `user_view` FOR EACH ROW BEGIN
    -- news
    IF NOT(
        NEW.news_id <=> NULL
    ) THEN
        UPDATE news_data
        SET total_view = total_view + 1
        WHERE news_id = NEW.news_id;
    END IF;
    
	-- channel
    IF NOT(
        NEW.channel_id <=> NULL
    ) THEN
        UPDATE channel_data
        SET total_view = total_view + 1
        WHERE channel_id = NEW.channel_id;
    END IF;
    
    -- eventsorting
    IF NOT(
        NEW.eventsorting_id <=> NULL
    ) THEN
        UPDATE eventsorting_data
        SET total_view = total_view + 1
        WHERE eventsorting_id = NEW.eventsorting_id;
    END IF;
    
	-- multipleperspectives
    IF NOT(
        NEW.multipleperspectives_id <=> NULL
    ) THEN
        UPDATE multipleperspectives_data
        SET total_view = total_view + 1
        WHERE multipleperspectives_id = NEW.multipleperspectives_id;
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- 資料表結構 `value_adjust`
--

CREATE TABLE `value_adjust` (
  `adjust_type` varchar(50) NOT NULL,
  `adjust_value` float NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 傾印資料表的資料 `value_adjust`
--

INSERT INTO `value_adjust` (`adjust_type`, `adjust_value`) VALUES
('bookmark', 3),
('comment', 2),
('eventsorting_heat', 2),
('multipleperspectives_heat', 2),
('news', 0.5),
('news_heat', 1),
('recent_bookmark', 2),
('recent_comment', 2),
('recent_news', 1.5),
('recent_search', 2),
('recent_share', 2),
('recent_view', 1.5),
('score', 1.5),
('search', 2),
('share', 2),
('view', 1);

--
-- 已傾印資料表的索引
--

--
-- 資料表索引 `anonymous_data`
--
ALTER TABLE `anonymous_data`
  ADD PRIMARY KEY (`anonymous_id`);

--
-- 資料表索引 `channel_data`
--
ALTER TABLE `channel_data`
  ADD PRIMARY KEY (`channel_id`),
  ADD UNIQUE KEY `channel_name` (`channel_name`),
  ADD UNIQUE KEY `channel_url` (`origin_url`),
  ADD KEY `image_id` (`image_id`);

--
-- 資料表索引 `error_logs`
--
ALTER TABLE `error_logs`
  ADD PRIMARY KEY (`error_id`);

--
-- 資料表索引 `eventsorting_data`
--
ALTER TABLE `eventsorting_data`
  ADD PRIMARY KEY (`eventsorting_id`),
  ADD KEY `image_id` (`eventsorting_image`);

--
-- 資料表索引 `eventsorting_horizontal`
--
ALTER TABLE `eventsorting_horizontal`
  ADD PRIMARY KEY (`eventsorting_id`,`horizontal_id`),
  ADD KEY `eventsorting_horizontal_id` (`horizontal_id`);

--
-- 資料表索引 `eventsorting_vertical`
--
ALTER TABLE `eventsorting_vertical`
  ADD PRIMARY KEY (`eventsorting_id`,`news_id`),
  ADD KEY `news_id` (`news_id`);

--
-- 資料表索引 `groupcustomize_bookmark`
--
ALTER TABLE `groupcustomize_bookmark`
  ADD PRIMARY KEY (`groupcustomize_id`),
  ADD UNIQUE KEY `user_id_2` (`user_id`,`groupcustomize_type`,`groupcustomize_name`),
  ADD UNIQUE KEY `user_id_3` (`user_id`,`groupcustomize_type`,`groupcustomize_name`,`groupcustomize_order`),
  ADD KEY `user_id` (`user_id`,`groupcustomize_type`);

--
-- 資料表索引 `groupcustomize_general`
--
ALTER TABLE `groupcustomize_general`
  ADD PRIMARY KEY (`user_id`,`group_id`),
  ADD UNIQUE KEY `user_id` (`user_id`,`group_id`,`group_order`),
  ADD KEY `group_id` (`group_id`);

--
-- 資料表索引 `group_data`
--
ALTER TABLE `group_data`
  ADD PRIMARY KEY (`group_id`),
  ADD UNIQUE KEY `group_name` (`group_name`);

--
-- 資料表索引 `group_detail`
--
ALTER TABLE `group_detail`
  ADD PRIMARY KEY (`group_detail_id`),
  ADD KEY `group_id` (`group_id`);

--
-- 資料表索引 `image_data`
--
ALTER TABLE `image_data`
  ADD PRIMARY KEY (`image_id`),
  ADD UNIQUE KEY `image_text` (`image_text`,`image_origin_url`) USING HASH;

--
-- 資料表索引 `keyword_data`
--
ALTER TABLE `keyword_data`
  ADD PRIMARY KEY (`keyword_id`),
  ADD UNIQUE KEY `keyword_text` (`keyword_text`),
  ADD KEY `keyword_relation_id` (`keyword_relation_id`);

--
-- 資料表索引 `keyword_relation`
--
ALTER TABLE `keyword_relation`
  ADD PRIMARY KEY (`keyword_relation_id`);

--
-- 資料表索引 `location_countries`
--
ALTER TABLE `location_countries`
  ADD PRIMARY KEY (`country_id`),
  ADD UNIQUE KEY `country_numeric_code` (`country_numeric_code`),
  ADD UNIQUE KEY `country_iso2` (`country_iso2`),
  ADD UNIQUE KEY `country_iso3` (`country_iso3`),
  ADD UNIQUE KEY `country_name_en` (`country_name_en`),
  ADD KEY `region_id` (`region_id`);

--
-- 資料表索引 `location_regions`
--
ALTER TABLE `location_regions`
  ADD PRIMARY KEY (`region_id`),
  ADD UNIQUE KEY `region_name_en` (`region_name_en`),
  ADD UNIQUE KEY `region_name_zh_tw` (`region_name_zh_tw`),
  ADD UNIQUE KEY `region_name_zh_cn` (`region_name_zh_cn`);

--
-- 資料表索引 `location_states`
--
ALTER TABLE `location_states`
  ADD PRIMARY KEY (`state_id`),
  ADD KEY `country_id` (`country_id`),
  ADD KEY `state_name_en` (`state_name_en`),
  ADD KEY `state_name_zh_tw` (`state_name_zh_tw`),
  ADD KEY `state_name_zh_cn` (`state_name_zh_cn`);

--
-- 資料表索引 `multipleperspectives_data`
--
ALTER TABLE `multipleperspectives_data`
  ADD PRIMARY KEY (`multipleperspectives_id`);

--
-- 資料表索引 `multipleperspectives_discuss`
--
ALTER TABLE `multipleperspectives_discuss`
  ADD KEY `multipleperspectives_id` (`multipleperspectives_id`);

--
-- 資料表索引 `multipleperspectives_integrate`
--
ALTER TABLE `multipleperspectives_integrate`
  ADD PRIMARY KEY (`multipleperspectives_id`,`integrate_id`);

--
-- 資料表索引 `news_body`
--
ALTER TABLE `news_body`
  ADD PRIMARY KEY (`news_body_id`),
  ADD KEY `news_id` (`news_id`),
  ADD KEY `body_image` (`body_image`);

--
-- 資料表索引 `news_data`
--
ALTER TABLE `news_data`
  ADD PRIMARY KEY (`news_id`),
  ADD UNIQUE KEY `news_url` (`origin_url`),
  ADD KEY `relation_id` (`relation_id`),
  ADD KEY `news_data_ibfk_1` (`channel_id`),
  ADD KEY `news_data_ibfk_3` (`cover_image`);

--
-- 資料表索引 `news_group`
--
ALTER TABLE `news_group`
  ADD PRIMARY KEY (`news_group_id`),
  ADD UNIQUE KEY `news_id` (`news_id`,`group_data_id`,`group_detail_id`),
  ADD KEY `group_data_id` (`group_data_id`),
  ADD KEY `group_detail_id` (`group_detail_id`);

--
-- 資料表索引 `news_location`
--
ALTER TABLE `news_location`
  ADD PRIMARY KEY (`news_location_id`),
  ADD UNIQUE KEY `news_id` (`news_id`,`location_region_id`,`location_country_id`,`location_state_id`),
  ADD KEY `location_region_id` (`location_region_id`),
  ADD KEY `location_country_id` (`location_country_id`),
  ADD KEY `location_state_id` (`location_state_id`);

--
-- 資料表索引 `relation_data`
--
ALTER TABLE `relation_data`
  ADD PRIMARY KEY (`relation_id`);

--
-- 資料表索引 `relation_keyword`
--
ALTER TABLE `relation_keyword`
  ADD PRIMARY KEY (`relation_id`,`keyword_id`),
  ADD KEY `keyword_id` (`keyword_id`);

--
-- 資料表索引 `user_anonymous`
--
ALTER TABLE `user_anonymous`
  ADD PRIMARY KEY (`user_id`,`anonymous_id`),
  ADD KEY `anonymous_id` (`anonymous_id`);

--
-- 資料表索引 `user_bookmark`
--
ALTER TABLE `user_bookmark`
  ADD PRIMARY KEY (`bookmark_id`),
  ADD UNIQUE KEY `user_id` (`user_id`,`news_id`),
  ADD UNIQUE KEY `user_id_2` (`user_id`,`channel_id`),
  ADD UNIQUE KEY `user_id_3` (`user_id`,`eventsorting_id`),
  ADD UNIQUE KEY `user_id_4` (`user_id`,`multipleperspectives_id`),
  ADD KEY `news_id` (`news_id`),
  ADD KEY `channel_id` (`channel_id`),
  ADD KEY `eventsorting_id` (`eventsorting_id`),
  ADD KEY `multipleperspectives_id` (`multipleperspectives_id`);

--
-- 資料表索引 `user_comment`
--
ALTER TABLE `user_comment`
  ADD PRIMARY KEY (`comment_id`),
  ADD KEY `user_id` (`user_id`),
  ADD KEY `news_id` (`news_id`),
  ADD KEY `channel_id` (`channel_id`),
  ADD KEY `eventsorting_id` (`eventsorting_id`),
  ADD KEY `multiperspectives_id` (`multipleperspectives_id`),
  ADD KEY `anonymous_id` (`anonymous_id`);

--
-- 資料表索引 `user_favorite`
--
ALTER TABLE `user_favorite`
  ADD UNIQUE KEY `user_id_2` (`user_id`,`group_data_id`,`group_detail_id`),
  ADD KEY `user_id` (`user_id`),
  ADD KEY `user_favorite_ibfk_2` (`group_data_id`),
  ADD KEY `group_detail_id` (`group_detail_id`);

--
-- 資料表索引 `user_location`
--
ALTER TABLE `user_location`
  ADD PRIMARY KEY (`user_id`,`region_id`,`country_id`,`state_id`);

--
-- 資料表索引 `user_profile`
--
ALTER TABLE `user_profile`
  ADD PRIMARY KEY (`user_id`),
  ADD UNIQUE KEY `user_account` (`user_account`),
  ADD KEY `user_email` (`user_email`),
  ADD KEY `user_phone` (`user_phone`),
  ADD KEY `user_name` (`user_name`) USING BTREE;

--
-- 資料表索引 `user_score`
--
ALTER TABLE `user_score`
  ADD PRIMARY KEY (`score_id`),
  ADD UNIQUE KEY `user_id_2` (`user_id`,`news_id`),
  ADD UNIQUE KEY `user_id_3` (`user_id`,`channel_id`),
  ADD UNIQUE KEY `user_id_4` (`user_id`,`eventsorting_id`),
  ADD UNIQUE KEY `user_id_5` (`user_id`,`multipleperspectives_id`),
  ADD KEY `user_id` (`user_id`),
  ADD KEY `news_id` (`news_id`),
  ADD KEY `channel_id` (`channel_id`),
  ADD KEY `eventsorting_id` (`eventsorting_id`),
  ADD KEY `multipleperspectives_id` (`multipleperspectives_id`);

--
-- 資料表索引 `user_search`
--
ALTER TABLE `user_search`
  ADD PRIMARY KEY (`search_id`),
  ADD UNIQUE KEY `user_id` (`user_id`,`keyword_id`,`type`),
  ADD KEY `keyword_id` (`keyword_id`);

--
-- 資料表索引 `user_share`
--
ALTER TABLE `user_share`
  ADD PRIMARY KEY (`view_id`),
  ADD KEY `user_id` (`user_id`),
  ADD KEY `news_id` (`news_id`),
  ADD KEY `channel_id` (`channel_id`),
  ADD KEY `eventsorting_id` (`eventsorting_id`),
  ADD KEY `multipleperspectives_id` (`multipleperspectives_id`);

--
-- 資料表索引 `user_view`
--
ALTER TABLE `user_view`
  ADD PRIMARY KEY (`view_id`),
  ADD KEY `user_id` (`user_id`),
  ADD KEY `news_id` (`news_id`),
  ADD KEY `channel_id` (`channel_id`),
  ADD KEY `eventsorting_id` (`eventsorting_id`),
  ADD KEY `multipleperspectives_id` (`multipleperspectives_id`);

--
-- 資料表索引 `value_adjust`
--
ALTER TABLE `value_adjust`
  ADD PRIMARY KEY (`adjust_type`);

--
-- 在傾印的資料表使用自動遞增(AUTO_INCREMENT)
--

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `anonymous_data`
--
ALTER TABLE `anonymous_data`
  MODIFY `anonymous_id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `channel_data`
--
ALTER TABLE `channel_data`
  MODIFY `channel_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `error_logs`
--
ALTER TABLE `error_logs`
  MODIFY `error_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `groupcustomize_bookmark`
--
ALTER TABLE `groupcustomize_bookmark`
  MODIFY `groupcustomize_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `group_data`
--
ALTER TABLE `group_data`
  MODIFY `group_id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=16;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `group_detail`
--
ALTER TABLE `group_detail`
  MODIFY `group_detail_id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=67;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `image_data`
--
ALTER TABLE `image_data`
  MODIFY `image_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `keyword_data`
--
ALTER TABLE `keyword_data`
  MODIFY `keyword_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `keyword_relation`
--
ALTER TABLE `keyword_relation`
  MODIFY `keyword_relation_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `location_countries`
--
ALTER TABLE `location_countries`
  MODIFY `country_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=251;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `location_regions`
--
ALTER TABLE `location_regions`
  MODIFY `region_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `location_states`
--
ALTER TABLE `location_states`
  MODIFY `state_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5140;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `news_body`
--
ALTER TABLE `news_body`
  MODIFY `news_body_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `news_data`
--
ALTER TABLE `news_data`
  MODIFY `news_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `news_group`
--
ALTER TABLE `news_group`
  MODIFY `news_group_id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `news_location`
--
ALTER TABLE `news_location`
  MODIFY `news_location_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `relation_data`
--
ALTER TABLE `relation_data`
  MODIFY `relation_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `user_bookmark`
--
ALTER TABLE `user_bookmark`
  MODIFY `bookmark_id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `user_comment`
--
ALTER TABLE `user_comment`
  MODIFY `comment_id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `user_profile`
--
ALTER TABLE `user_profile`
  MODIFY `user_id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `user_score`
--
ALTER TABLE `user_score`
  MODIFY `score_id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `user_share`
--
ALTER TABLE `user_share`
  MODIFY `view_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `user_view`
--
ALTER TABLE `user_view`
  MODIFY `view_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 已傾印資料表的限制式
--

--
-- 資料表的限制式 `channel_data`
--
ALTER TABLE `channel_data`
  ADD CONSTRAINT `channel_data_ibfk_1` FOREIGN KEY (`image_id`) REFERENCES `image_data` (`image_id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- 資料表的限制式 `eventsorting_data`
--
ALTER TABLE `eventsorting_data`
  ADD CONSTRAINT `eventsorting_data_ibfk_1` FOREIGN KEY (`eventsorting_id`) REFERENCES `relation_data` (`relation_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `eventsorting_data_ibfk_2` FOREIGN KEY (`eventsorting_image`) REFERENCES `image_data` (`image_id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- 資料表的限制式 `eventsorting_horizontal`
--
ALTER TABLE `eventsorting_horizontal`
  ADD CONSTRAINT `eventsorting_horizontal_ibfk_1` FOREIGN KEY (`eventsorting_id`) REFERENCES `eventsorting_data` (`eventsorting_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `eventsorting_horizontal_ibfk_2` FOREIGN KEY (`horizontal_id`) REFERENCES `eventsorting_data` (`eventsorting_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- 資料表的限制式 `eventsorting_vertical`
--
ALTER TABLE `eventsorting_vertical`
  ADD CONSTRAINT `eventsorting_vertical_ibfk_1` FOREIGN KEY (`eventsorting_id`) REFERENCES `eventsorting_data` (`eventsorting_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `eventsorting_vertical_ibfk_2` FOREIGN KEY (`news_id`) REFERENCES `news_data` (`news_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- 資料表的限制式 `groupcustomize_bookmark`
--
ALTER TABLE `groupcustomize_bookmark`
  ADD CONSTRAINT `groupcustomize_bookmark_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `user_profile` (`user_id`);

--
-- 資料表的限制式 `groupcustomize_general`
--
ALTER TABLE `groupcustomize_general`
  ADD CONSTRAINT `groupcustomize_general_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `user_profile` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `groupcustomize_general_ibfk_2` FOREIGN KEY (`group_id`) REFERENCES `group_data` (`group_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- 資料表的限制式 `group_detail`
--
ALTER TABLE `group_detail`
  ADD CONSTRAINT `group_detail_ibfk_1` FOREIGN KEY (`group_id`) REFERENCES `group_data` (`group_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- 資料表的限制式 `keyword_data`
--
ALTER TABLE `keyword_data`
  ADD CONSTRAINT `keyword_data_ibfk_1` FOREIGN KEY (`keyword_relation_id`) REFERENCES `keyword_relation` (`keyword_relation_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- 資料表的限制式 `location_countries`
--
ALTER TABLE `location_countries`
  ADD CONSTRAINT `location_countries_ibfk_1` FOREIGN KEY (`region_id`) REFERENCES `location_regions` (`region_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- 資料表的限制式 `location_states`
--
ALTER TABLE `location_states`
  ADD CONSTRAINT `location_states_ibfk_1` FOREIGN KEY (`country_id`) REFERENCES `location_countries` (`country_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- 資料表的限制式 `multipleperspectives_data`
--
ALTER TABLE `multipleperspectives_data`
  ADD CONSTRAINT `multipleperspectives_data_ibfk_1` FOREIGN KEY (`multipleperspectives_id`) REFERENCES `relation_data` (`relation_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- 資料表的限制式 `multipleperspectives_discuss`
--
ALTER TABLE `multipleperspectives_discuss`
  ADD CONSTRAINT `multipleperspectives_discuss_ibfk_1` FOREIGN KEY (`multipleperspectives_id`) REFERENCES `multipleperspectives_data` (`multipleperspectives_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- 資料表的限制式 `multipleperspectives_integrate`
--
ALTER TABLE `multipleperspectives_integrate`
  ADD CONSTRAINT `multipleperspectives_integrate_ibfk_1` FOREIGN KEY (`multipleperspectives_id`) REFERENCES `multipleperspectives_data` (`multipleperspectives_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- 資料表的限制式 `news_body`
--
ALTER TABLE `news_body`
  ADD CONSTRAINT `news_body_ibfk_1` FOREIGN KEY (`news_id`) REFERENCES `news_data` (`news_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `news_body_ibfk_2` FOREIGN KEY (`body_image`) REFERENCES `image_data` (`image_id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- 資料表的限制式 `news_data`
--
ALTER TABLE `news_data`
  ADD CONSTRAINT `news_data_ibfk_1` FOREIGN KEY (`channel_id`) REFERENCES `channel_data` (`channel_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `news_data_ibfk_2` FOREIGN KEY (`relation_id`) REFERENCES `relation_data` (`relation_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `news_data_ibfk_3` FOREIGN KEY (`cover_image`) REFERENCES `image_data` (`image_id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- 資料表的限制式 `news_group`
--
ALTER TABLE `news_group`
  ADD CONSTRAINT `news_group_ibfk_1` FOREIGN KEY (`news_id`) REFERENCES `news_data` (`news_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `news_group_ibfk_2` FOREIGN KEY (`group_data_id`) REFERENCES `group_data` (`group_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `news_group_ibfk_3` FOREIGN KEY (`group_detail_id`) REFERENCES `group_detail` (`group_detail_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- 資料表的限制式 `news_location`
--
ALTER TABLE `news_location`
  ADD CONSTRAINT `news_location_ibfk_1` FOREIGN KEY (`news_id`) REFERENCES `news_data` (`news_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `news_location_ibfk_2` FOREIGN KEY (`location_region_id`) REFERENCES `location_regions` (`region_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `news_location_ibfk_3` FOREIGN KEY (`location_country_id`) REFERENCES `location_countries` (`country_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `news_location_ibfk_4` FOREIGN KEY (`location_state_id`) REFERENCES `location_states` (`state_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- 資料表的限制式 `relation_keyword`
--
ALTER TABLE `relation_keyword`
  ADD CONSTRAINT `relation_keyword_ibfk_1` FOREIGN KEY (`relation_id`) REFERENCES `relation_data` (`relation_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `relation_keyword_ibfk_2` FOREIGN KEY (`keyword_id`) REFERENCES `keyword_data` (`keyword_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- 資料表的限制式 `user_anonymous`
--
ALTER TABLE `user_anonymous`
  ADD CONSTRAINT `user_anonymous_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `user_profile` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `user_anonymous_ibfk_2` FOREIGN KEY (`anonymous_id`) REFERENCES `anonymous_data` (`anonymous_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- 資料表的限制式 `user_bookmark`
--
ALTER TABLE `user_bookmark`
  ADD CONSTRAINT `user_bookmark_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `user_profile` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `user_bookmark_ibfk_2` FOREIGN KEY (`news_id`) REFERENCES `news_data` (`news_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `user_bookmark_ibfk_3` FOREIGN KEY (`channel_id`) REFERENCES `channel_data` (`channel_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `user_bookmark_ibfk_4` FOREIGN KEY (`eventsorting_id`) REFERENCES `eventsorting_data` (`eventsorting_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `user_bookmark_ibfk_5` FOREIGN KEY (`multipleperspectives_id`) REFERENCES `multipleperspectives_data` (`multipleperspectives_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- 資料表的限制式 `user_comment`
--
ALTER TABLE `user_comment`
  ADD CONSTRAINT `user_comment_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `user_profile` (`user_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `user_comment_ibfk_2` FOREIGN KEY (`news_id`) REFERENCES `news_data` (`news_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `user_comment_ibfk_3` FOREIGN KEY (`channel_id`) REFERENCES `channel_data` (`channel_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `user_comment_ibfk_4` FOREIGN KEY (`eventsorting_id`) REFERENCES `eventsorting_data` (`eventsorting_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `user_comment_ibfk_5` FOREIGN KEY (`multipleperspectives_id`) REFERENCES `multipleperspectives_data` (`multipleperspectives_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `user_comment_ibfk_6` FOREIGN KEY (`anonymous_id`) REFERENCES `anonymous_data` (`anonymous_id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- 資料表的限制式 `user_favorite`
--
ALTER TABLE `user_favorite`
  ADD CONSTRAINT `user_favorite_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `user_profile` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `user_favorite_ibfk_2` FOREIGN KEY (`group_data_id`) REFERENCES `group_data` (`group_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `user_favorite_ibfk_3` FOREIGN KEY (`group_detail_id`) REFERENCES `group_detail` (`group_detail_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- 資料表的限制式 `user_score`
--
ALTER TABLE `user_score`
  ADD CONSTRAINT `user_score_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `user_profile` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `user_score_ibfk_2` FOREIGN KEY (`news_id`) REFERENCES `news_data` (`news_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `user_score_ibfk_3` FOREIGN KEY (`channel_id`) REFERENCES `channel_data` (`channel_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `user_score_ibfk_4` FOREIGN KEY (`eventsorting_id`) REFERENCES `eventsorting_data` (`eventsorting_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `user_score_ibfk_5` FOREIGN KEY (`multipleperspectives_id`) REFERENCES `multipleperspectives_data` (`multipleperspectives_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- 資料表的限制式 `user_search`
--
ALTER TABLE `user_search`
  ADD CONSTRAINT `user_search_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `user_profile` (`user_id`) ON DELETE SET NULL ON UPDATE SET NULL,
  ADD CONSTRAINT `user_search_ibfk_2` FOREIGN KEY (`keyword_id`) REFERENCES `keyword_data` (`keyword_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- 資料表的限制式 `user_share`
--
ALTER TABLE `user_share`
  ADD CONSTRAINT `user_share_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `user_profile` (`user_id`) ON DELETE SET NULL ON UPDATE SET NULL,
  ADD CONSTRAINT `user_share_ibfk_2` FOREIGN KEY (`news_id`) REFERENCES `news_data` (`news_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `user_share_ibfk_3` FOREIGN KEY (`channel_id`) REFERENCES `channel_data` (`channel_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `user_share_ibfk_4` FOREIGN KEY (`eventsorting_id`) REFERENCES `eventsorting_data` (`eventsorting_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `user_share_ibfk_5` FOREIGN KEY (`multipleperspectives_id`) REFERENCES `multipleperspectives_data` (`multipleperspectives_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- 資料表的限制式 `user_view`
--
ALTER TABLE `user_view`
  ADD CONSTRAINT `user_view_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `user_profile` (`user_id`) ON DELETE SET NULL ON UPDATE SET NULL,
  ADD CONSTRAINT `user_view_ibfk_2` FOREIGN KEY (`news_id`) REFERENCES `news_data` (`news_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `user_view_ibfk_3` FOREIGN KEY (`channel_id`) REFERENCES `channel_data` (`channel_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `user_view_ibfk_4` FOREIGN KEY (`eventsorting_id`) REFERENCES `eventsorting_data` (`eventsorting_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `user_view_ibfk_5` FOREIGN KEY (`multipleperspectives_id`) REFERENCES `multipleperspectives_data` (`multipleperspectives_id`) ON DELETE CASCADE ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
