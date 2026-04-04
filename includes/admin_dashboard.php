<?php

declare(strict_types=1);

/**
 * 后台「数据看板」数据层：汇总指标、近 7 日新帖趋势、帖子类型分布、收藏 Top 10。
 *
 * 约定：
 * - total_posts：posts 全表行数（含 deleted）。
 * - active_posts：status = active。
 * - 今日新帖/新用户：按服务器 CURDATE() 与 DATE(created_at) 比较。
 * - 近 7 日：含今日共 7 个自然日；无数据的日期在 PHP 侧补 0。
 * - 收藏 Top 10：按 favorites 聚合；favorites 表不存在时返回空列表。
 */

/**
 * @return array{
 *   stats: array{
 *     total_users: int,
 *     total_posts: int,
 *     active_posts: int,
 *     today_posts: int,
 *     today_users: int,
 *     today_activity: int,
 *     users_wow_pct: float|null,
 *     posts_wow_pct: float|null,
 *     activity_dod_pct: float|null
 *   },
 *   trend: list<array{date: string, count: int}>,
 *   types: array<string, int>,
 *   top_favorites: list<array{id: int|string, title: string, type: string, fav_count: int}>
 * }
 */
function admin_dashboard_fetch(PDO $pdo): array
{
    $stats = admin_dashboard_fetch_stats($pdo);
    $trend = admin_dashboard_fetch_trend($pdo);
    $types = admin_dashboard_fetch_type_distribution($pdo);
    $topFavorites = admin_dashboard_fetch_top_favorites($pdo);

    return [
        'stats'          => $stats,
        'trend'          => $trend,
        'types'          => $types,
        'top_favorites'  => $topFavorites,
    ];
}

/**
 * 汇总：用户/帖子总数、今日新帖与注册、今日活跃（新帖+新注册）；
 * 环比：近 7 日新增用户/帖子 vs 前 7 日；今日活跃 vs 昨日。
 */
function admin_dashboard_fetch_stats(PDO $pdo): array
{
    $sql = 'SELECT
        (SELECT COUNT(*) FROM users) AS total_users,
        (SELECT COUNT(*) FROM posts) AS total_posts,
        (SELECT COUNT(*) FROM posts WHERE status = \'active\') AS active_posts,
        (SELECT COUNT(*) FROM posts WHERE DATE(created_at) = CURDATE()) AS today_posts,
        (SELECT COUNT(*) FROM users WHERE DATE(created_at) = CURDATE()) AS today_users,
        (SELECT COUNT(*) FROM users WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL 6 DAY)) AS users_l7,
        (SELECT COUNT(*) FROM users WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL 13 DAY)
            AND created_at < DATE_SUB(CURDATE(), INTERVAL 6 DAY)) AS users_p7,
        (SELECT COUNT(*) FROM posts WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL 6 DAY)) AS posts_l7,
        (SELECT COUNT(*) FROM posts WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL 13 DAY)
            AND created_at < DATE_SUB(CURDATE(), INTERVAL 6 DAY)) AS posts_p7,
        (SELECT COUNT(*) FROM posts WHERE DATE(created_at) = DATE_SUB(CURDATE(), INTERVAL 1 DAY)) AS y_posts,
        (SELECT COUNT(*) FROM users WHERE DATE(created_at) = DATE_SUB(CURDATE(), INTERVAL 1 DAY)) AS y_users';

    $row = $pdo->query($sql)->fetch(PDO::FETCH_ASSOC) ?: [];

    $todayPosts  = (int) ($row['today_posts'] ?? 0);
    $todayUsers  = (int) ($row['today_users'] ?? 0);
    $yPosts      = (int) ($row['y_posts'] ?? 0);
    $yUsers      = (int) ($row['y_users'] ?? 0);
    $todayAct    = $todayPosts + $todayUsers;
    $yesterdayAct = $yPosts + $yUsers;

    $usersL7 = (int) ($row['users_l7'] ?? 0);
    $usersP7 = (int) ($row['users_p7'] ?? 0);
    $postsL7 = (int) ($row['posts_l7'] ?? 0);
    $postsP7 = (int) ($row['posts_p7'] ?? 0);

    $usersWow = admin_dashboard_pct_change($usersL7, $usersP7);
    $postsWow = admin_dashboard_pct_change($postsL7, $postsP7);
    $actDod   = admin_dashboard_pct_change($todayAct, $yesterdayAct);

    return [
        'total_users'       => (int) ($row['total_users'] ?? 0),
        'total_posts'       => (int) ($row['total_posts'] ?? 0),
        'active_posts'      => (int) ($row['active_posts'] ?? 0),
        'today_posts'       => $todayPosts,
        'today_users'       => $todayUsers,
        'today_activity'    => $todayAct,
        'users_wow_pct'     => $usersWow,
        'posts_wow_pct'     => $postsWow,
        'activity_dod_pct'  => $actDod,
    ];
}

/**
 * 环比百分比：(当前 − 对比期) / 对比期 × 100；对比期为 0 时返回 null（前端不展示）。
 */
function admin_dashboard_pct_change(int $current, int $baseline): ?float
{
    if ($baseline <= 0) {
        return null;
    }

    return round((($current - $baseline) / $baseline) * 100, 1);
}

/**
 * 近 7 日每日新帖数（按 DATE(created_at)），缺日由调用方补 0。
 *
 * @return list<array{date: string, count: int}>
 */
function admin_dashboard_fetch_trend(PDO $pdo): array
{
    $sql = 'SELECT DATE(created_at) AS d, COUNT(*) AS c
        FROM posts
        WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL 6 DAY)
        GROUP BY DATE(created_at)
        ORDER BY d ASC';

    $trendStmt = $pdo->query($sql);
    $trendMap = [];
    while ($row = $trendStmt->fetch(PDO::FETCH_ASSOC)) {
        $trendMap[$row['d']] = (int) $row['c'];
    }

    $out = [];
    for ($i = 6; $i >= 0; $i--) {
        $d = date('Y-m-d', strtotime('-' . $i . ' days'));
        $out[] = ['date' => $d, 'count' => $trendMap[$d] ?? 0];
    }

    return $out;
}

/**
 * 帖子类型分布：四枚举值各一行聚合。
 *
 * @return array<string, int> type => count
 */
function admin_dashboard_fetch_type_distribution(PDO $pdo): array
{
    $sql = 'SELECT type, COUNT(*) AS c FROM posts GROUP BY type';
    $stmt = $pdo->query($sql);
    $types = [];
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $types[(string) $row['type']] = (int) $row['c'];
    }

    return $types;
}

/**
 * 收藏量 Top 10：favorites JOIN posts，按收藏次数降序。
 *
 * @return list<array{id: int|string, title: string, type: string, fav_count: int}>
 */
function admin_dashboard_fetch_top_favorites(PDO $pdo): array
{
    $sql = 'SELECT p.id, p.title, p.type, COUNT(f.id) AS fav_count
        FROM favorites f
        INNER JOIN posts p ON p.id = f.post_id
        GROUP BY p.id, p.title, p.type
        ORDER BY fav_count DESC, p.id ASC
        LIMIT 10';

    try {
        $stmt = $pdo->query($sql);
    } catch (Throwable $e) {
        return [];
    }

    $rows = [];
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $rows[] = $row;
    }

    return $rows;
}
