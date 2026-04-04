<?php
// 复制此文件为 config.php 并填写本地数据库信息（config.php 已被 .gitignore 忽略）
$dbHost = 'localhost';
$dbName = 'hk_rentmatch';
$dbUser = 'root';
$dbPass = '';

$dsn = "mysql:host={$dbHost};dbname={$dbName};charset=utf8mb4";

try {
    $pdo = new PDO($dsn, $dbUser, $dbPass, [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES   => false,
    ]);
} catch (PDOException $e) {
    http_response_code(500);
    echo '数据库连接失败，请检查配置。';
    exit;
}
