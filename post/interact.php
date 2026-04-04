<?php
require_once __DIR__ . '/../includes/auth.php';

header('Content-Type: application/json; charset=utf-8');

function json_response(bool $success, string $message, array $data = [], int $status = 200): void
{
    http_response_code($status);
    echo json_encode([
        'success' => $success,
        'message' => $message,
        'data' => $data,
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    json_response(false, '请求方法不支持。', [], 405);
}

$user = current_user();
if (!$user) {
    json_response(false, '请先登录。', ['require_login' => true], 401);
}

$action = trim((string) ($_POST['action'] ?? ''));
$postId = (int) ($_POST['post_id'] ?? 0);
if ($postId <= 0) {
    json_response(false, '帖子参数无效。', [], 422);
}

$postStmt = $pdo->prepare(
    'SELECT id, user_id, status
     FROM posts
     WHERE id = :id
     LIMIT 1'
);
$postStmt->execute([':id' => $postId]);
$post = $postStmt->fetch();
$role = (string) ($user['role'] ?? '');
$canStudentActions = in_array($role, ['student', 'admin'], true);

if (!$post || ($post['status'] ?? '') !== 'active') {
    json_response(false, '帖子不存在或已下架。', [], 404);
}

if ($action === 'toggle_favorite') {
    if (!$canStudentActions) {
        json_response(false, '仅港硕学生或管理员可收藏帖子。', [], 403);
    }

    $checkStmt = $pdo->prepare(
        'SELECT id
         FROM favorites
         WHERE user_id = :uid AND post_id = :pid
         LIMIT 1'
    );
    $checkStmt->execute([
        ':uid' => (int) $user['id'],
        ':pid' => $postId,
    ]);
    $existingFavoriteId = $checkStmt->fetchColumn();

    if ($existingFavoriteId) {
        $deleteStmt = $pdo->prepare(
            'DELETE FROM favorites
             WHERE user_id = :uid AND post_id = :pid'
        );
        $deleteStmt->execute([
            ':uid' => (int) $user['id'],
            ':pid' => $postId,
        ]);
        json_response(true, '已取消收藏。', ['favorited' => false]);
    }

    $insertStmt = $pdo->prepare(
        'INSERT INTO favorites (user_id, post_id)
         VALUES (:uid, :pid)'
    );
    $insertStmt->execute([
        ':uid' => (int) $user['id'],
        ':pid' => $postId,
    ]);
    json_response(true, '收藏成功！', ['favorited' => true]);
}

if ($action === 'send_application') {
    if (!$canStudentActions) {
        json_response(false, '仅港硕学生或管理员可发送申请。', [], 403);
    }
    if ((int) $post['user_id'] === (int) $user['id']) {
        json_response(false, '不能申请自己的帖子。', [], 422);
    }

    $message = trim((string) ($_POST['message'] ?? ''));
    if ($message === '' || mb_strlen($message, 'UTF-8') > 500) {
        json_response(false, '申请留言需为 1-500 字。', [], 422);
    }

    $pendingStmt = $pdo->prepare(
        "SELECT id
         FROM applications
         WHERE post_id = :pid AND applicant_user_id = :uid AND status = 'pending'
         LIMIT 1"
    );
    $pendingStmt->execute([
        ':pid' => $postId,
        ':uid' => (int) $user['id'],
    ]);
    if ($pendingStmt->fetchColumn()) {
        json_response(false, '你已有待处理申请，请勿重复提交。', [], 409);
    }

    $insertStmt = $pdo->prepare(
        'INSERT INTO applications (post_id, applicant_user_id, message, status, owner_unread, applicant_result_unread)
         VALUES (:pid, :uid, :message, :status, 1, 0)'
    );
    $insertStmt->execute([
        ':pid' => $postId,
        ':uid' => (int) $user['id'],
        ':message' => $message,
        ':status' => 'pending',
    ]);

    json_response(true, '申请已发送。');
}

json_response(false, '无效操作。', [], 422);
