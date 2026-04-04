<?php
require_once __DIR__ . '/includes/auth.php';

$errors = [];
$isAjax = $_SERVER['REQUEST_METHOD'] === 'POST'
    && (
        (isset($_GET['ajax']) && $_GET['ajax'] === '1')
        || strtolower($_SERVER['HTTP_X_REQUESTED_WITH'] ?? '') === 'xmlhttprequest'
    );

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $email    = trim($_POST['email'] ?? '');
    $password = $_POST['password'] ?? '';

    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        $errors['email'] = '请输入有效邮箱地址。';
    }

    if ($password === '') {
        $errors['password'] = '请输入密码。';
    }

    if (empty($errors)) {
        $stmt = $pdo->prepare('SELECT * FROM users WHERE email = :email LIMIT 1');
        $stmt->execute([':email' => $email]);
        $user = $stmt->fetch();

        if (!$user || !password_verify($password, $user['password'])) {
            $errors['general'] = '邮箱或密码错误。';
        } else {
            $bannedUntil = $user['banned_until'] ?? null;
            if ($bannedUntil !== null && $bannedUntil !== '') {
                $untilTs = strtotime((string) $bannedUntil);
                if ($untilTs !== false && $untilTs <= time()) {
                    $upd = $pdo->prepare(
                        'UPDATE users SET status = :status, banned_until = NULL WHERE id = :id'
                    );
                    $upd->execute([
                        ':status' => 'active',
                        ':id'     => (int) $user['id'],
                    ]);
                    $user['status']       = 'active';
                    $user['banned_until'] = null;
                }
            }

            if ($user['status'] === 'banned') {
                $errors['general'] = '该账号已被禁用，如有疑问请联系管理员。';
            } else {
                login_user($user);

                if ($isAjax) {
                    header('Content-Type: application/json; charset=utf-8');
                    echo json_encode([
                        'success'  => true,
                        'username' => $user['username'],
                        'initial'  => mb_substr($user['username'], 0, 1, 'UTF-8'),
                        'role'     => $user['role'],
                        'school'   => school_display_name($user['school'] ?? ''),
                    ], JSON_UNESCAPED_UNICODE);
                    exit;
                }

                header('Location: index.php');
                exit;
            }
        }
    }
}

if ($isAjax) {
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
        'success' => false,
        'errors'  => $errors,
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

include __DIR__ . '/includes/header.php';
?>

<main class="auth-page">
    <section class="auth-card">
        <h1 class="auth-title">欢迎回来</h1>
        <p class="auth-subtitle">使用注册邮箱登录，继续浏览与发布房源</p>

        <?php if (!empty($errors['general'])): ?>
            <div class="form-error form-error-general">
                <?php echo htmlspecialchars($errors['general']); ?>
            </div>
        <?php endif; ?>

        <form method="post" class="auth-form" novalidate>
            <div class="form-group">
                <label class="form-label">邮箱地址 <span class="required">*</span></label>
                <input type="email" class="form-input" name="email"
                       placeholder="请输入邮箱"
                       value="<?php echo htmlspecialchars($_POST['email'] ?? ''); ?>">
                <?php if (!empty($errors['email'])): ?>
                    <div class="form-error"><?php echo htmlspecialchars($errors['email']); ?></div>
                <?php endif; ?>
            </div>

            <div class="form-group">
                <label class="form-label">密码 <span class="required">*</span></label>
                <input type="password" class="form-input" name="password"
                       placeholder="请输入密码">
                <div class="form-hint">密码为8-20位，包含大小写字母和数字</div>
                <?php if (!empty($errors['password'])): ?>
                    <div class="form-error"><?php echo htmlspecialchars($errors['password']); ?></div>
                <?php endif; ?>
            </div>

            <button type="submit" class="btn btn-primary btn-block">登录</button>

            <p class="auth-switch">
                还没有账号？
                <a href="register.php">立即注册</a>
            </p>
        </form>
    </section>
</main>

<?php include __DIR__ . '/includes/footer.php'; ?>

