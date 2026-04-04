-- favorites / applications 迁移验证脚本
-- 使用方式：
-- 1) 先执行 migrate.sql
-- 2) 再执行本脚本，观察每个 SELECT 的结果是否符合注释中的预期
-- 3) 脚本最后会 ROLLBACK，不会污染正式数据
--
-- 手工回归（浏览器，用户 A=申请人 / B=房主）：
-- 1) B 发帖，A 登录对该帖提交申请 → B 侧导航/头像应有「收到申请」未读；A 侧不应有「申请结果」未读。
-- 2) B 打开个人中心「收到申请」(profile.php?section=received) → 房主未读清零，红点按当前逻辑消失（若仅列表内处理而未进入分区，以产品为准）。
-- 3) B 同意或拒绝该申请 → A 侧「我的申请」与头像汇总未读应出现。
-- 4) A 打开「我的申请」(profile.php?section=applications) → 申请结果未读清零。

USE `hk_rentmatch`;

START TRANSACTION;

-- 生成唯一后缀，避免与现有数据冲突
SET @suffix = DATE_FORMAT(NOW(), '%Y%m%d%H%i%s');

-- 1) 创建测试用户（房东 + 申请人）
INSERT INTO `users` (`username`, `email`, `password`, `phone`, `gender`, `role`, `school`, `status`)
VALUES
  (CONCAT('verify_owner_', @suffix), CONCAT('verify_owner_', @suffix, '@example.com'), '$2y$10$abcdefghijklmnopqrstuv', '91234567', 'other', 'landlord', 'HKU', 'active');
SET @owner_user_id = LAST_INSERT_ID();

INSERT INTO `users` (`username`, `email`, `password`, `phone`, `gender`, `role`, `school`, `status`)
VALUES
  (CONCAT('verify_applicant_', @suffix), CONCAT('verify_applicant_', @suffix, '@example.com'), '$2y$10$abcdefghijklmnopqrstuv', '92345678', 'other', 'student', 'CityU', 'active');
SET @applicant_user_id = LAST_INSERT_ID();

-- 2) 创建测试帖子
INSERT INTO `posts`
  (`user_id`, `type`, `title`, `content`, `price`, `floor`, `rent_period`, `region`, `school_scope`, `metro_stations`, `status`)
VALUES
  (@owner_user_id, 'rent', CONCAT('verify_post_', @suffix), 'migration verify post', 9800.00, '8/F', 'medium', '沙田区', 'HKU, CityU', 'Kowloon Tong', 'active');
SET @post_id = LAST_INSERT_ID();

-- 3) favorites 唯一约束验证（同一 user + post 只能收藏一次）
INSERT INTO `favorites` (`user_id`, `post_id`) VALUES (@applicant_user_id, @post_id);
INSERT IGNORE INTO `favorites` (`user_id`, `post_id`) VALUES (@applicant_user_id, @post_id);

SELECT
  ROW_COUNT() AS duplicate_favorite_insert_affected_rows_expect_0;

SELECT
  COUNT(*) AS favorite_count_expect_1
FROM `favorites`
WHERE `user_id` = @applicant_user_id AND `post_id` = @post_id;

-- 4) applications 基本插入与状态验证（与 post/interact.php、post/detail.php 一致：新申请房主未读）
INSERT INTO `applications` (`post_id`, `applicant_user_id`, `message`, `status`, `owner_unread`, `applicant_result_unread`)
VALUES (@post_id, @applicant_user_id, 'verify application message', 'pending', 1, 0);
SET @application_id = LAST_INSERT_ID();

SELECT
  `id`,
  `status`,
  `owner_unread`,
  `applicant_result_unread`,
  `created_at`,
  `updated_at`
FROM `applications`
WHERE `id` = @application_id;
-- 预期：status = pending，owner_unread = 1，applicant_result_unread = 0，且 created_at/updated_at 有值

-- 4b) 申请未读标记与 profile.php 清零 / received_process 语义（与 header 统计子查询一致）
SELECT
  COUNT(*) AS owner_unread_count_expect_1
FROM `applications` a
INNER JOIN `posts` p ON p.`id` = a.`post_id`
WHERE p.`user_id` = @owner_user_id AND a.`owner_unread` = 1;

SELECT
  COUNT(*) AS applicant_result_unread_count_expect_0
FROM `applications`
WHERE `applicant_user_id` = @applicant_user_id AND `applicant_result_unread` = 1;

-- 模拟 GET profile section=received：仅清零房主未读，不改变 pending
UPDATE `applications` a
INNER JOIN `posts` p ON p.`id` = a.`post_id`
SET a.`owner_unread` = 0
WHERE p.`user_id` = @owner_user_id AND a.`owner_unread` = 1;

SELECT
  ROW_COUNT() AS clear_owner_unread_rows_expect_1;

SELECT
  `status` AS status_still_pending,
  `owner_unread` AS owner_unread_after_received_section_expect_0
FROM `applications`
WHERE `id` = @application_id;
-- 预期：status 仍为 pending，owner_unread = 0

SELECT
  COUNT(*) AS owner_unread_count_after_clear_expect_0
FROM `applications` a
INNER JOIN `posts` p ON p.`id` = a.`post_id`
WHERE p.`user_id` = @owner_user_id AND a.`owner_unread` = 1;

-- 模拟 profile.php received_process：pending → accepted，申请人结果未读；房主侧 owner_unread=0（MVP）
UPDATE `applications` a
INNER JOIN `posts` p ON p.`id` = a.`post_id`
SET a.`status` = 'accepted',
    a.`applicant_result_unread` = 1,
    a.`owner_unread` = 0
WHERE a.`id` = @application_id
  AND p.`user_id` = @owner_user_id
  AND a.`status` = 'pending';

SELECT
  ROW_COUNT() AS received_process_rows_expect_1;

SELECT
  `status`,
  `owner_unread` AS owner_unread_after_process_expect_0,
  `applicant_result_unread` AS applicant_result_unread_after_process_expect_1
FROM `applications`
WHERE `id` = @application_id;

SELECT
  COUNT(*) AS applicant_result_unread_count_after_process_expect_1
FROM `applications`
WHERE `applicant_user_id` = @applicant_user_id AND `applicant_result_unread` = 1;

-- 模拟 GET profile section=applications：清零申请人结果未读
UPDATE `applications`
SET `applicant_result_unread` = 0
WHERE `applicant_user_id` = @applicant_user_id AND `applicant_result_unread` = 1;

SELECT
  ROW_COUNT() AS clear_applicant_unread_rows_expect_1;

SELECT
  `applicant_result_unread` AS applicant_result_unread_after_applications_section_expect_0
FROM `applications`
WHERE `id` = @application_id;

SELECT
  COUNT(*) AS applicant_result_unread_count_final_expect_0
FROM `applications`
WHERE `applicant_user_id` = @applicant_user_id AND `applicant_result_unread` = 1;

-- 5) 级联删除验证 A：删除申请人后，favorites / applications 应被级联删除
DELETE FROM `users` WHERE `id` = @applicant_user_id;

SELECT
  COUNT(*) AS favorites_after_delete_applicant_expect_0
FROM `favorites`
WHERE `post_id` = @post_id;

SELECT
  COUNT(*) AS applications_after_delete_applicant_expect_0
FROM `applications`
WHERE `post_id` = @post_id;

-- 6) 重新创建申请人 + 收藏 + 申请，用于验证删除帖子级联
INSERT INTO `users` (`username`, `email`, `password`, `phone`, `gender`, `role`, `school`, `status`)
VALUES
  (CONCAT('verify_applicant2_', @suffix), CONCAT('verify_applicant2_', @suffix, '@example.com'), '$2y$10$abcdefghijklmnopqrstuv', '93456789', 'other', 'student', 'CityU', 'active');
SET @applicant2_user_id = LAST_INSERT_ID();

INSERT INTO `favorites` (`user_id`, `post_id`) VALUES (@applicant2_user_id, @post_id);
INSERT INTO `applications` (`post_id`, `applicant_user_id`, `message`, `status`, `owner_unread`, `applicant_result_unread`)
VALUES (@post_id, @applicant2_user_id, 'verify application message 2', 'pending', 1, 0);

-- 删除帖子，预期 favorites / applications 级联删除
DELETE FROM `posts` WHERE `id` = @post_id;

SELECT
  COUNT(*) AS favorites_after_delete_post_expect_0
FROM `favorites`
WHERE `user_id` = @applicant2_user_id;

SELECT
  COUNT(*) AS applications_after_delete_post_expect_0
FROM `applications`
WHERE `applicant_user_id` = @applicant2_user_id;

-- 7) 回滚测试数据
ROLLBACK;
