<?php

declare(strict_types=1);

require_admin();

$action = trim((string) ($_POST['admin_action'] ?? ''));

$redirectSection = trim((string) ($_POST['redirect_section'] ?? 'dashboard'));
if (!in_array($redirectSection, ['dashboard', 'posts', 'users'], true)) {
    $redirectSection = 'dashboard';
}

function admin_build_redirect_url(string $section, array $extra = []): string
{
    $q = array_merge(['section' => $section], $extra);
    return project_base_url('admin.php?' . http_build_query($q));
}

function admin_redirect_flash(string $section, string $type, string $message, array $extra = []): void
{
    $_SESSION['admin_flash'] = ['type' => $type, 'message' => $message];
    header('Location: ' . admin_build_redirect_url($section, $extra));
    exit;
}

function admin_parse_post_redirect(): array
{
    $page = max(1, (int) ($_POST['redirect_page'] ?? 1));
    $postFilter = trim((string) ($_POST['redirect_post_filter'] ?? 'all'));
    if (!in_array($postFilter, ['all', 'active', 'hidden', 'deleted'], true)) {
        $postFilter = 'all';
    }
    $q = trim((string) ($_POST['redirect_q'] ?? ''));

    return [
        'page'         => $page,
        'post_filter'  => $postFilter,
        'q'            => $q,
    ];
}

function admin_parse_user_redirect(): array
{
    $page = max(1, (int) ($_POST['redirect_page'] ?? 1));
    $userFilter = trim((string) ($_POST['redirect_user_filter'] ?? 'all'));
    if (!in_array($userFilter, ['all', 'active', 'banned'], true)) {
        $userFilter = 'all';
    }
    $q = trim((string) ($_POST['redirect_user_q'] ?? ''));

    return [
        'page'         => $page,
        'user_filter'  => $userFilter,
        'q'            => $q,
    ];
}

function admin_collect_post_ids(): array
{
    $raw = $_POST['post_ids'] ?? [];
    if (!is_array($raw)) {
        return [];
    }
    $ids = [];
    foreach ($raw as $v) {
        $id = (int) $v;
        if ($id > 0) {
            $ids[$id] = true;
        }
    }
    return array_map('intval', array_keys($ids));
}

function admin_collect_user_ids(): array
{
    $raw = $_POST['user_ids'] ?? [];
    if (!is_array($raw)) {
        return [];
    }
    $ids = [];
    foreach ($raw as $v) {
        $id = (int) $v;
        if ($id > 0) {
            $ids[$id] = true;
        }
    }

    return array_map('intval', array_keys($ids));
}

switch ($action) {
    case 'post_hide':
        $postId = (int) ($_POST['post_id'] ?? 0);
        $extra = admin_parse_post_redirect();
        if ($postId <= 0) {
            admin_redirect_flash('posts', 'error', '无效的帖子。', $extra);
        }
        $stmt = $pdo->prepare('UPDATE posts SET status = :st WHERE id = :id AND status = :cur');
        $stmt->execute([
            ':st'  => 'hidden',
            ':id'  => $postId,
            ':cur' => 'active',
        ]);
        if ($stmt->rowCount() === 0) {
            admin_redirect_flash('posts', 'error', '仅能对「正常」状态的帖子执行下架。', $extra);
        }
        admin_redirect_flash('posts', 'success', '帖子已下架。', $extra);

    case 'post_restore':
        $postId = (int) ($_POST['post_id'] ?? 0);
        $extra = admin_parse_post_redirect();
        if ($postId <= 0) {
            admin_redirect_flash('posts', 'error', '无效的帖子。', $extra);
        }
        $stmt = $pdo->prepare(
            "UPDATE posts SET status = 'active' WHERE id = :id AND status IN ('hidden','deleted')"
        );
        $stmt->execute([':id' => $postId]);
        if ($stmt->rowCount() === 0) {
            admin_redirect_flash('posts', 'error', '仅能对已隐藏或已删除的帖子执行恢复。', $extra);
        }
        admin_redirect_flash('posts', 'success', '帖子已恢复为正常。', $extra);

    case 'posts_batch_hide':
        $extra = admin_parse_post_redirect();
        $ids = admin_collect_post_ids();
        if ($ids === []) {
            admin_redirect_flash('posts', 'error', '请先选择帖子。', $extra);
        }
        $placeholders = implode(',', array_fill(0, count($ids), '?'));
        $stmt = $pdo->prepare(
            "UPDATE posts SET status = 'hidden' WHERE id IN ($placeholders) AND status = 'active'"
        );
        $stmt->execute($ids);
        $n = $stmt->rowCount();
        admin_redirect_flash('posts', $n > 0 ? 'success' : 'error', $n > 0 ? "已下架 {$n} 条帖子。" : '没有可下架的帖子（仅「正常」可下架）。', $extra);

    case 'posts_batch_restore':
        $extra = admin_parse_post_redirect();
        $ids = admin_collect_post_ids();
        if ($ids === []) {
            admin_redirect_flash('posts', 'error', '请先选择帖子。', $extra);
        }
        $placeholders = implode(',', array_fill(0, count($ids), '?'));
        $stmt = $pdo->prepare(
            "UPDATE posts SET status = 'active' WHERE id IN ($placeholders) AND status IN ('hidden','deleted')"
        );
        $stmt->execute($ids);
        $n = $stmt->rowCount();
        admin_redirect_flash('posts', $n > 0 ? 'success' : 'error', $n > 0 ? "已恢复 {$n} 条帖子。" : '没有可恢复的帖子。', $extra);

    case 'user_ban':
        $extra = admin_parse_user_redirect();
        $userId = (int) ($_POST['user_id'] ?? 0);
        $duration = trim((string) ($_POST['ban_duration'] ?? ''));
        if ($userId <= 0) {
            admin_redirect_flash('users', 'error', '无效的用户。', $extra);
        }
        if (!in_array($duration, ['7', '30', 'permanent'], true)) {
            admin_redirect_flash('users', 'error', '请选择封禁时长。', $extra);
        }

        $stmt = $pdo->prepare('SELECT id, role FROM users WHERE id = :id LIMIT 1');
        $stmt->execute([':id' => $userId]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$row) {
            admin_redirect_flash('users', 'error', '用户不存在。', $extra);
        }
        if (($row['role'] ?? '') === 'admin') {
            admin_redirect_flash('users', 'error', '不能封禁管理员账号。', $extra);
        }

        $currentAdminId = (int) (current_user()['id'] ?? 0);
        if ($userId === $currentAdminId) {
            admin_redirect_flash('users', 'error', '不能封禁当前登录账号。', $extra);
        }

        if ($duration === 'permanent') {
            $upd = $pdo->prepare(
                'UPDATE users SET status = :st, banned_until = NULL WHERE id = :id AND role != :admin_role'
            );
            $upd->execute([
                ':st'         => 'banned',
                ':id'         => $userId,
                ':admin_role' => 'admin',
            ]);
        } else {
            $days = $duration === '7' ? 7 : 30;
            $upd = $pdo->prepare(
                'UPDATE users SET status = \'banned\', banned_until = DATE_ADD(NOW(), INTERVAL ' . $days . ' DAY) WHERE id = :id AND role != \'admin\''
            );
            $upd->execute([':id' => $userId]);
        }

        if ($upd->rowCount() === 0) {
            admin_redirect_flash('users', 'error', '封禁失败。', $extra);
        }
        $label = $duration === 'permanent' ? '永久' : ($duration === '7' ? '7 天' : '30 天');
        admin_redirect_flash('users', 'success', "已封禁用户（{$label}）。", $extra);

    case 'user_unban':
        $extra = admin_parse_user_redirect();
        $userId = (int) ($_POST['user_id'] ?? 0);
        if ($userId <= 0) {
            admin_redirect_flash('users', 'error', '无效的用户。', $extra);
        }

        $stmt = $pdo->prepare(
            "UPDATE users SET status = 'active', banned_until = NULL WHERE id = :id AND role != 'admin' AND status = 'banned'"
        );
        $stmt->execute([':id' => $userId]);
        if ($stmt->rowCount() === 0) {
            admin_redirect_flash('users', 'error', '解封失败（用户未处于封禁状态或为管理员）。', $extra);
        }
        admin_redirect_flash('users', 'success', '已解封用户。', $extra);

    case 'users_batch_ban':
        $extra = admin_parse_user_redirect();
        $ids = admin_collect_user_ids();
        if ($ids === []) {
            admin_redirect_flash('users', 'error', '请先选择用户。', $extra);
        }

        $duration = trim((string) ($_POST['ban_duration'] ?? ''));
        if (!in_array($duration, ['7', '30', 'permanent'], true)) {
            admin_redirect_flash('users', 'error', '请选择封禁时长。', $extra);
        }

        $currentAdminId = (int) (current_user()['id'] ?? 0);
        $placeholders = implode(',', array_fill(0, count($ids), '?'));
        $stmt = $pdo->prepare("SELECT id, role FROM users WHERE id IN ($placeholders)");
        $stmt->execute($ids);
        $eligible = [];
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            $uid = (int) $row['id'];
            if (($row['role'] ?? '') === 'admin' || $uid === $currentAdminId) {
                continue;
            }
            $eligible[] = $uid;
        }
        if ($eligible === []) {
            admin_redirect_flash('users', 'error', '没有可封禁的用户（不能选择管理员或自己）。', $extra);
        }

        $ph = implode(',', array_fill(0, count($eligible), '?'));
        if ($duration === 'permanent') {
            $upd = $pdo->prepare(
                "UPDATE users SET status = 'banned', banned_until = NULL
                 WHERE id IN ($ph) AND role != 'admin' AND status = 'active'"
            );
            $upd->execute($eligible);
        } else {
            $days = $duration === '7' ? 7 : 30;
            $upd = $pdo->prepare(
                'UPDATE users SET status = \'banned\', banned_until = DATE_ADD(NOW(), INTERVAL ' . $days
                . ' DAY) WHERE id IN (' . $ph . ") AND role != 'admin' AND status = 'active'"
            );
            $upd->execute($eligible);
        }

        $n = $upd->rowCount();
        $label = $duration === 'permanent' ? '永久' : ($duration === '7' ? '7 天' : '30 天');
        admin_redirect_flash(
            'users',
            $n > 0 ? 'success' : 'error',
            $n > 0 ? "已批量封禁 {$n} 个用户（{$label}）。" : '没有处于「正常」状态且可封禁的用户。',
            $extra
        );

    case 'users_batch_unban':
        $extra = admin_parse_user_redirect();
        $ids = admin_collect_user_ids();
        if ($ids === []) {
            admin_redirect_flash('users', 'error', '请先选择用户。', $extra);
        }

        $currentAdminId = (int) (current_user()['id'] ?? 0);
        $placeholders = implode(',', array_fill(0, count($ids), '?'));
        $stmt = $pdo->prepare("SELECT id, role FROM users WHERE id IN ($placeholders)");
        $stmt->execute($ids);
        $eligible = [];
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            $uid = (int) $row['id'];
            if (($row['role'] ?? '') === 'admin' || $uid === $currentAdminId) {
                continue;
            }
            $eligible[] = $uid;
        }
        if ($eligible === []) {
            admin_redirect_flash('users', 'error', '没有可解封的用户。', $extra);
        }

        $ph = implode(',', array_fill(0, count($eligible), '?'));
        $upd = $pdo->prepare(
            "UPDATE users SET status = 'active', banned_until = NULL
             WHERE id IN ($ph) AND role != 'admin' AND status = 'banned'"
        );
        $upd->execute($eligible);
        $n = $upd->rowCount();
        admin_redirect_flash(
            'users',
            $n > 0 ? 'success' : 'error',
            $n > 0 ? "已解封 {$n} 个用户。" : '所选用户中没有处于封禁状态且可解封的账号。',
            $extra
        );

    default:
        admin_redirect_flash($redirectSection, 'error', '未知操作。', []);
}
