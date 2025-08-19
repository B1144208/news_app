-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- 主機： 127.0.0.1
-- 產生時間： 2025-07-18 04:04:08
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
-- 資料表結構 `search_data`
--

CREATE TABLE `search_data` (
  `search_id` bigint(20) UNSIGNED NOT NULL,
  `search_relation_id` bigint(20) UNSIGNED DEFAULT NULL,
  `search_keyword_id` bigint(20) UNSIGNED NOT NULL,
  `search_amount` bigint(20) UNSIGNED NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- 已傾印資料表的索引
--

--
-- 資料表索引 `search_data`
--
ALTER TABLE `search_data`
  ADD PRIMARY KEY (`search_id`),
  ADD KEY `search_relation_id` (`search_relation_id`),
  ADD KEY `search_keyword_id` (`search_keyword_id`);

--
-- 在傾印的資料表使用自動遞增(AUTO_INCREMENT)
--

--
-- 使用資料表自動遞增(AUTO_INCREMENT) `search_data`
--
ALTER TABLE `search_data`
  MODIFY `search_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 已傾印資料表的限制式
--

--
-- 資料表的限制式 `search_data`
--
ALTER TABLE `search_data`
  ADD CONSTRAINT `search_data_ibfk_1` FOREIGN KEY (`search_relation_id`) REFERENCES `search_relation` (`search_relation_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `search_data_ibfk_2` FOREIGN KEY (`search_keyword_id`) REFERENCES `keyword_data` (`keyword_id`) ON DELETE CASCADE ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
