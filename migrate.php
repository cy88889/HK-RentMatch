<?php
require_once __DIR__ . '/includes/config.php';

$sqls = [
    "ALTER TABLE `posts` MODIFY `type` ENUM('rent','roommate-source','roommate-nosource') NOT NULL DEFAULT 'rent'",
    "ALTER TABLE `posts` ADD COLUMN `gender_requirement` ENUM('male','female','any') DEFAULT NULL AFTER `images`",
    "ALTER TABLE `posts` ADD COLUMN `need_count` TINYINT UNSIGNED DEFAULT NULL AFTER `gender_requirement`",
];

foreach ($sqls as $sql) {
    try {
        $pdo->exec($sql);
        echo '<p style="color:green">✓ ' . htmlspecialchars($sql) . '</p>';
    } catch (PDOException $e) {
        echo '<p style="color:orange">⚠ ' . htmlspecialchars($e->getMessage()) . '</p>';
    }
}
echo '<p><strong>迁移完成，请删除此文件。</strong></p>';
