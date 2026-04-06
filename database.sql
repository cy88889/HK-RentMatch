-- HK Postgrad Rent‑Match 初始化脚本（完整表结构）
-- 一键导入：创建数据库、users / posts / favorites / applications 及少量示例数据
-- 与当前代码版本一致；队友克隆仓库后执行本文件即可本地跑通，无需再执行 migrate.sql
--
-- 若你已有旧库且不能删表，请改用 migrate.sql 做增量升级，勿重复执行本文件整段 DROP。

-- 如需修改库名，可全文替换 hk_rentmatch
CREATE DATABASE IF NOT EXISTS `hk_rentmatch`
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE `hk_rentmatch`;

-- 外键依赖顺序：先删子表
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS `favorites`;
DROP TABLE IF EXISTS `applications`;
DROP TABLE IF EXISTS `posts`;
DROP TABLE IF EXISTS `users`;
SET FOREIGN_KEY_CHECKS = 1;

-- =========================
-- users 表：用户账号信息
-- =========================
CREATE TABLE `users` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `username` VARCHAR(50) NOT NULL COMMENT '昵称 / 显示名称',
  `email` VARCHAR(120) NOT NULL COMMENT '登录邮箱',
  `password` VARCHAR(255) NOT NULL COMMENT '密码哈希（password_hash）',
  `phone` VARCHAR(30) DEFAULT NULL COMMENT '手机号 / 联系方式',
  `gender` ENUM('male','female','other') DEFAULT 'other' COMMENT '性别',
  `role` ENUM('student','landlord','admin') NOT NULL DEFAULT 'student' COMMENT '角色：学生/房东/管理员',
  `school` VARCHAR(120) DEFAULT NULL COMMENT '所属学校，例如 CityU, HKU',
  `status` ENUM('active','banned') NOT NULL DEFAULT 'active' COMMENT '账号状态',
  `banned_until` DATETIME NULL DEFAULT NULL COMMENT '临时封禁到期时间；NULL 且 status=banned 表示永久封禁',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================
-- posts 表：租房 / 找室友 / 转租
-- =========================
CREATE TABLE `posts` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` INT UNSIGNED NOT NULL COMMENT '发布者 ID，对应 users.id',
  `type` ENUM('rent','roommate-source','roommate-nosource','sublet') NOT NULL DEFAULT 'rent' COMMENT '帖子类型',
  `title` VARCHAR(150) NOT NULL COMMENT '标题',
  `content` TEXT NOT NULL COMMENT '详细描述',
  `price` DECIMAL(10,2) NOT NULL COMMENT '月租金（HKD）',
  `floor` VARCHAR(20) DEFAULT NULL COMMENT '楼层信息，例如 3/F, 高层',
  `rent_period` ENUM('short','medium','long') NOT NULL COMMENT '租期：short/medium/long',
  `region` VARCHAR(80) NOT NULL COMMENT '区域，例如 九龙, 新界',
  `school_scope` VARCHAR(150) DEFAULT NULL COMMENT '适合学校范围，例如 CityU / PolyU 附近',
  `metro_stations` VARCHAR(255) DEFAULT NULL COMMENT '地铁站名称，逗号分隔',
  `gender_requirement` ENUM('male','female','any') DEFAULT NULL COMMENT '性别要求，找室友类型使用',
  `need_count` TINYINT UNSIGNED DEFAULT NULL COMMENT '需求室友人数，有房找室友使用',
  `remaining_months` TINYINT UNSIGNED DEFAULT NULL COMMENT '剩余租期（月），转租使用',
  `move_in_date` DATE DEFAULT NULL COMMENT '最早入住日期，转租使用',
  `renewable` ENUM('yes','no') DEFAULT NULL COMMENT '是否可续租，转租使用',
  `images` TEXT DEFAULT NULL COMMENT '图片 JSON 或逗号分隔路径，第一版可为空',
  `status` ENUM('active','hidden','deleted') NOT NULL DEFAULT 'active' COMMENT '帖子状态',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_region` (`region`),
  KEY `idx_school_scope` (`school_scope`),
  KEY `idx_price` (`price`),
  KEY `idx_rent_period` (`rent_period`),
  KEY `idx_status` (`status`),
  CONSTRAINT `fk_posts_user` FOREIGN KEY (`user_id`)
    REFERENCES `users`(`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================
-- favorites 表：用户收藏帖子
-- =========================
CREATE TABLE `favorites` (
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

-- =========================
-- applications 表：帖子申请
-- =========================
CREATE TABLE `applications` (
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

-- =========================
-- 示例数据：方便开发调试
-- 密码均为占位哈希，请在实际环境中用 PHP 的 password_hash 重新生成
-- =========================

INSERT INTO `users` (`username`, `email`, `password`, `phone`, `gender`, `role`, `school`, `status`, `banned_until`)
VALUES
  ('Alice', 'alice@example.com', '$2y$10$exampleexampleexampleexampleexampleexampl', '5123-4567', 'female', 'student', 'CityU', 'active', NULL),
  ('Bob', 'bob@example.com', '$2y$10$exampleexampleexampleexampleexampleexampl', '5123-8888', 'male', 'landlord', 'HKU', 'active', NULL);

INSERT INTO `posts` (
  `user_id`, `type`, `title`, `content`, `price`, `floor`,
  `rent_period`, `region`, `school_scope`, `metro_stations`,
  `images`, `status`
) VALUES
  (
    1,
    'rent',
    '九龙塘近 CityU 带家具单间',
    '步行 8 分钟到 CityU，包基本家具，水电网平摊，适合女生合租。',
    6500.00,
    '8/F',
    'medium',
    '九龙',
    'CityU',
    'Kowloon Tong',
    NULL,
    'active'
  ),
  (
    2,
    'rent',
    '港岛线地铁旁开间',
    '距离地铁站 2 分钟，适合港岛区学院学生，周边生活方便。',
    9000.00,
    '15/F',
    'long',
    '港岛',
    'HKU, PolyU',
    'Sai Ying Pun, HKU',
    NULL,
    'active'
  );

-- =========================
-- 导入说明
-- =========================
-- 【全新本地环境】在 phpMyAdmin、MySQL Workbench、DBeaver 或命令行执行本文件即可：
--   mysql -u root -p < database.sql
--
-- 【从旧版本仓库升级已有数据库】若表已存在且含数据，请勿直接执行本文件（会 DROP 表）；
--   请使用 migrate.sql 做增量变更。
--
-- 【与 migrate.sql 的关系】migrate.sql 面向「已有旧表结构」的升级；全新安装以本文件为准，无需再跑 migrate.sql。
