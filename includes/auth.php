<?php
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

require_once __DIR__ . '/config.php';

function current_user(): ?array
{
    return $_SESSION['user'] ?? null;
}

function school_options_map(): array
{
    return [
        'HKU' => '香港大学 HKU',
        'CUHK' => '香港中文大学 CUHK',
        'HKUST' => '香港科技大学 HKUST',
        'CityU' => '香港城市大学 CityU',
        'PolyU' => '香港理工大学 PolyU',
        'HKBU' => '香港浸会大学 HKBU',
        'LU' => '岭南大学 LU',
        'EdUHK' => '香港教育大学 EdUHK',
    ];
}

function normalize_school_code(?string $school): ?string
{
    $value = trim((string) $school);
    if ($value === '') {
        return null;
    }

    $map = school_options_map();
    foreach (array_keys($map) as $code) {
        if (strcasecmp($value, $code) === 0) {
            return $code;
        }
    }

    return $value;
}

function school_display_name(?string $school): string
{
    $code = normalize_school_code($school);
    if ($code === null) {
        return '';
    }

    $map = school_options_map();
    return $map[$code] ?? $code;
}

function is_logged_in(): bool
{
    return isset($_SESSION['user']['id']);
}

function login_user(array $user): void
{
    $normalizedSchool = normalize_school_code($user['school'] ?? null);
    $_SESSION['user'] = [
        'id'       => $user['id'],
        'username' => $user['username'],
        'email'    => $user['email'],
        'role'     => $user['role'],
        'school'   => $normalizedSchool,
        'gender'   => $user['gender'],
        'status'   => $user['status'],
    ];
}

function logout_user(): void
{
    $_SESSION['user'] = [];

    if (ini_get('session.use_cookies')) {
        $params = session_get_cookie_params();
        setcookie(
            session_name(),
            '',
            time() - 42000,
            $params['path'],
            $params['domain'],
            $params['secure'],
            $params['httponly']
        );
    }

    session_destroy();
}

function require_login(): void
{
    if (!is_logged_in()) {
        header('Location: ' . project_base_url('index.php') . '?login=1');
        exit;
    }
}

function is_admin(): bool
{
    $user = current_user();
    return $user !== null && ($user['role'] ?? '') === 'admin';
}

function require_admin(): void
{
    if (!is_logged_in()) {
        header('Location: ' . project_base_url('index.php') . '?login=1');
        exit;
    }
    if (!is_admin()) {
        header('Location: ' . project_base_url('index.php') . '?admin=forbidden');
        exit;
    }
}

function project_base_url(string $path = ''): string
{
    static $baseUrl = null;

    if ($baseUrl === null) {
        $projectRoot = realpath(__DIR__ . '/..') ?: dirname(__DIR__);
        $docRoot     = isset($_SERVER['DOCUMENT_ROOT']) ? realpath($_SERVER['DOCUMENT_ROOT']) : false;

        $projectRoot = str_replace('\\', '/', $projectRoot);
        $docRoot     = $docRoot ? str_replace('\\', '/', $docRoot) : '';

        if ($docRoot !== '' && strpos($projectRoot, $docRoot) === 0) {
            $relative = trim(substr($projectRoot, strlen($docRoot)), '/');
            $baseUrl  = $relative === '' ? '' : '/' . $relative;
        } else {
            // Fallback: 当无法从 DOCUMENT_ROOT 推导时，使用项目目录名。
            $baseUrl = '/' . basename($projectRoot);
        }
    }

    $path = ltrim($path, '/');
    if ($path === '') {
        return $baseUrl === '' ? '/' : $baseUrl;
    }

    return ($baseUrl === '' ? '' : $baseUrl) . '/' . $path;
}

function parse_post_images(?string $imagesRaw): array
{
    if ($imagesRaw === null) {
        return [];
    }

    $raw = trim($imagesRaw);
    if ($raw === '') {
        return [];
    }

    $images = [];
    $decoded = json_decode($raw, true);

    if (json_last_error() === JSON_ERROR_NONE) {
        if (is_array($decoded)) {
            foreach ($decoded as $item) {
                if (is_string($item) && trim($item) !== '') {
                    $images[] = trim($item);
                }
            }
        } elseif (is_string($decoded) && trim($decoded) !== '') {
            $images[] = trim($decoded);
        }
    }

    if (empty($images)) {
        $parts = preg_split('/[\r\n,]+/', $raw) ?: [];
        foreach ($parts as $part) {
            $part = trim($part);
            if ($part !== '') {
                $images[] = $part;
            }
        }
    }

    return array_values(array_unique($images));
}

function resolve_post_image_url(string $path): string
{
    $path = trim($path);
    if ($path === '') {
        return '';
    }

    if (preg_match('#^(https?:)?//#i', $path) === 1 || stripos($path, 'data:image/') === 0) {
        return $path;
    }

    if ($path[0] === '/') {
        return $path;
    }

    return project_base_url($path);
}

