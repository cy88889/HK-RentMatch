<?php
// 将 PHP 登录状态注入前端，供现有 JS 逻辑使用（收藏/申请等）
$isLoggedIn = isset($user) && !empty($user['id']);
?>
    <div class="toast" id="toast"></div>
    <script>
        window.isLoggedIn = <?php echo $isLoggedIn ? 'true' : 'false'; ?>;
        window.projectBaseUrl = <?php echo json_encode(rtrim(project_base_url(), '/')); ?>;
    </script>
    <script src="<?php echo htmlspecialchars(project_base_url('assets/js/main.js')); ?>?v=<?php echo filemtime(__DIR__ . '/../assets/js/main.js'); ?>"></script>
</body>
</html>

