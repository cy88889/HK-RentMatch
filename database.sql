-- HK Postgrad Rent‑Match 初始化脚本
-- 一键导入：创建数据库、核心表（users, posts）及少量示例数据

-- 如果不存在则创建数据库（如需修改库名，可统一替换 hk_rentmatch）
CREATE DATABASE IF NOT EXISTS `hk_rentmatch`
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE `hk_rentmatch`;

-- =========================
-- users 表：用户账号信息
-- =========================
DROP TABLE IF EXISTS `users`;

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
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================
-- posts 表：租房帖子
-- 支持 rent / roommate / sublet
-- =========================
DROP TABLE IF EXISTS `posts`;

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
-- 示例数据：方便开发调试
-- 密码均为占位哈希，请在实际环境中用 PHP 的 password_hash 重新生成
-- =========================

-- 示例用户
INSERT INTO `users` (`username`, `email`, `password`, `phone`, `gender`, `role`, `school`, `status`)
VALUES
  ('Alice', 'alice@example.com', '$2y$10$exampleexampleexampleexampleexampleexampl', '5123-4567', 'female', 'student', 'CityU', 'active'),
  ('Bob', 'bob@example.com', '$2y$10$exampleexampleexampleexampleexampleexampl', '5123-8888', 'male', 'landlord', 'HKU', 'active');

-- 示例帖子（假设上面插入的 id 为 1, 2）
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
-- 【全新安装】直接在 phpMyAdmin 或命令行执行本文件即可，无需额外操作。
--
-- 【已有旧表升级】如果 posts 表的 `type` 仍只有 `rent`，
-- 或缺少 gender_requirement / need_count / remaining_months / move_in_date / renewable 字段，
-- 或需要 `favorites` / `applications` 表及申请未读字段（`owner_unread`、`applicant_result_unread`），
-- 请执行项目根目录下的 migrate.sql 文件完成升级补充（说明见该文件头部注释）。
