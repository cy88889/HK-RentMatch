-- =============================================================================
-- HK RentMatch 数据库升级脚本
-- =============================================================================
-- 作用：扩展 posts.type 与相关列；创建 favorites / applications；users.banned_until
--
-- 兼容：Oracle MySQL 5.7+ / 8.x、MariaDB；phpMyAdmin、DBeaver、命令行均可直接执行。
-- 本文件不使用 DELIMITER / 存储过程 / ADD COLUMN IF NOT EXISTS，避免图形工具拆句问题。
--
-- 重复执行：已存在的列会报 Duplicate column，属正常。
--   · 命令行：mysql -u 用户 -p hk_rentmatch -f < migrate.sql   （-f 遇错继续）
--   · DBeaver：执行 SQL 脚本时勾选「遇到错误继续」或在连接驱动属性中开启类似选项
--   · phpMyAdmin：SQL 页可勾选「出错时仍继续执行」（不同版本文案略有差异）；或分段执行、忽略重复列报错
--
-- 首次执行：建议从上到下整段执行一次；若 applications 已由本脚本 CREATE 建全，后面两条
--   给 applications 加列的语句可能报重复列，忽略即可。
-- =============================================================================

USE `hk_rentmatch`;

-- -----------------------------------------------------------------------------
-- posts：帖子类型枚举与扩展字段（每条 ALTER 单独一句，便于遇错继续）
-- -----------------------------------------------------------------------------

ALTER TABLE `posts`
  MODIFY COLUMN `type` ENUM('rent','roommate-source','roommate-nosource','sublet') NOT NULL DEFAULT 'rent'
    COMMENT '帖子类型';

ALTER TABLE `posts`
  ADD COLUMN `gender_requirement` ENUM('male','female','any') DEFAULT NULL
    COMMENT '性别要求，找室友类型使用'
    AFTER `metro_stations`;

ALTER TABLE `posts`
  ADD COLUMN `need_count` TINYINT UNSIGNED DEFAULT NULL
    COMMENT '需求室友人数，有房找室友使用'
    AFTER `gender_requirement`;

ALTER TABLE `posts`
  ADD COLUMN `remaining_months` TINYINT UNSIGNED DEFAULT NULL
    COMMENT '剩余租期（月），转租使用'
    AFTER `need_count`;

ALTER TABLE `posts`
  ADD COLUMN `move_in_date` DATE DEFAULT NULL
    COMMENT '最早入住日期，转租使用'
    AFTER `remaining_months`;

ALTER TABLE `posts`
  ADD COLUMN `renewable` ENUM('yes','no') DEFAULT NULL
    COMMENT '是否可续租，转租使用'
    AFTER `move_in_date`;

-- -----------------------------------------------------------------------------
-- favorites / applications（CREATE IF NOT EXISTS 各 MySQL 版本均支持）
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `favorites` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `user_id` INT UNSIGNED NOT NULL COMMENT '收藏用户 ID',
  `post_id` INT UNSIGNED NOT NULL COMMENT '被收藏帖子 ID',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '收藏时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_user_post` (`user_id`, `post_id`),
  KEY `idx_favorites_user_id` (`user_id`),
  KEY `idx_favorites_post_id` (`post_id`),
  CONSTRAINT `fk_favorites_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_favorites_post` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户收藏关系表';

CREATE TABLE IF NOT EXISTS `applications` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `post_id` INT UNSIGNED NOT NULL COMMENT '申请目标帖子 ID',
  `applicant_user_id` INT UNSIGNED NOT NULL COMMENT '申请人用户 ID',
  `message` VARCHAR(500) DEFAULT NULL COMMENT '申请留言',
  `status` ENUM('pending','accepted','rejected','withdrawn') NOT NULL DEFAULT 'pending' COMMENT '申请状态',
  `owner_unread` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '房主尚未在「收到申请」分区查看过本条新申请',
  `applicant_result_unread` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '申请人尚未看到同意/拒绝结果',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '申请创建时间',
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '状态更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_applications_post_id` (`post_id`),
  KEY `idx_applications_applicant_user_id` (`applicant_user_id`),
  KEY `idx_applications_status` (`status`),
  KEY `idx_applications_applicant_result_unread` (`applicant_user_id`, `applicant_result_unread`),
  CONSTRAINT `fk_applications_post` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_applications_applicant_user` FOREIGN KEY (`applicant_user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='帖子申请记录表';

-- 旧库若曾用无未读列的版本建过 applications，下面两句会补列；新库 CREATE 已含列则可能报重复列，可忽略
ALTER TABLE `applications`
  ADD COLUMN `owner_unread` TINYINT(1) NOT NULL DEFAULT 0
    COMMENT '房主尚未在「收到申请」分区查看过本条新申请'
    AFTER `status`;

ALTER TABLE `applications`
  ADD COLUMN `applicant_result_unread` TINYINT(1) NOT NULL DEFAULT 0
    COMMENT '申请人尚未看到同意/拒绝结果'
    AFTER `owner_unread`;

-- -----------------------------------------------------------------------------
-- users：临时封禁到期时间
-- -----------------------------------------------------------------------------

ALTER TABLE `users`
  ADD COLUMN `banned_until` DATETIME NULL DEFAULT NULL
    COMMENT '临时封禁到期时间；NULL 且 status=banned 表示永久封禁'
    AFTER `status`;

-- 已有表若由旧版 migrate 创建且无下列索引，可手工执行（重复执行会报错，可忽略）：
-- ALTER TABLE `applications` ADD INDEX `idx_applications_applicant_result_unread` (`applicant_user_id`, `applicant_result_unread`);
