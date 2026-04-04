-- 数据库升级脚本：为 posts 表补齐 type 枚举与缺失字段；补充 favorites / applications 及申请未读标记
--
-- 【全新安装】若仅执行了 database.sql（无 favorites/applications），请执行本文件以创建收藏与申请相关表。
--
-- 【已有库升级】按需执行；其中 `applications` 的 `owner_unread`、`applicant_result_unread` 用于
-- 「收到新申请 / 申请结果被处理」的未读提醒：新列默认 0，升级后历史行不会误报未读。
-- 若表由本文件较早版本的 CREATE 创建且缺少上述两列，执行本文件中的 ALTER 即可幂等补齐。
--
-- 环境要求：MariaDB 10.3.3+（支持 ADD COLUMN IF NOT EXISTS，与上文 posts 字段一致）。

USE `hk_rentmatch`;

-- 修改 type 枚举以支持找室友与转租类型（兼容旧表 ENUM 仅有 'rent' 的情况）
ALTER TABLE `posts`
  MODIFY COLUMN `type` ENUM('rent','roommate-source','roommate-nosource','sublet') NOT NULL DEFAULT 'rent'
    COMMENT '帖子类型';

-- 添加 gender_requirement 字段（性别要求，找室友类型使用）
ALTER TABLE `posts`
  ADD COLUMN IF NOT EXISTS `gender_requirement` ENUM('male','female','any') DEFAULT NULL
    COMMENT '性别要求，找室友类型使用'
    AFTER `metro_stations`;

-- 添加 need_count 字段（需求室友人数）
ALTER TABLE `posts`
  ADD COLUMN IF NOT EXISTS `need_count` TINYINT UNSIGNED DEFAULT NULL
    COMMENT '需求室友人数，有房找室友使用'
    AFTER `gender_requirement`;

-- 添加转租字段：remaining_months / move_in_date / renewable
ALTER TABLE `posts`
  ADD COLUMN IF NOT EXISTS `remaining_months` TINYINT UNSIGNED DEFAULT NULL
    COMMENT '剩余租期（月），转租使用'
    AFTER `need_count`,
  ADD COLUMN IF NOT EXISTS `move_in_date` DATE DEFAULT NULL
    COMMENT '最早入住日期，转租使用'
    AFTER `remaining_months`,
  ADD COLUMN IF NOT EXISTS `renewable` ENUM('yes','no') DEFAULT NULL
    COMMENT '是否可续租，转租使用'
    AFTER `move_in_date`;

-- 新增 favorites 表（用户收藏帖子）
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

-- 新增 applications 表（用户申请帖子）
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

-- 已有 applications 表时补齐未读标记列（全新 CREATE 已含列则此处跳过）
ALTER TABLE `applications`
  ADD COLUMN IF NOT EXISTS `owner_unread` TINYINT(1) NOT NULL DEFAULT 0
    COMMENT '房主尚未在「收到申请」分区查看过本条新申请'
    AFTER `status`,
  ADD COLUMN IF NOT EXISTS `applicant_result_unread` TINYINT(1) NOT NULL DEFAULT 0
    COMMENT '申请人尚未看到同意/拒绝结果'
    AFTER `owner_unread`;

-- 已有表若由旧版 migrate 创建且无下列索引，可手工执行（重复执行会报错，可忽略）：
-- ALTER TABLE `applications` ADD INDEX `idx_applications_applicant_result_unread` (`applicant_user_id`, `applicant_result_unread`);

-- 用户临时封禁到期时间：`status='banned'` 且本字段非空表示封禁至该时刻；到期后登录流程会自动解封。
-- 永久封禁约定：`status='banned'` 且 `banned_until` 为 NULL（无自动解封）。
ALTER TABLE `users`
  ADD COLUMN IF NOT EXISTS `banned_until` DATETIME NULL DEFAULT NULL
    COMMENT '临时封禁到期时间；NULL 且 status=banned 表示永久封禁'
    AFTER `status`;
