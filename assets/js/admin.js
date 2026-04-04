(function () {
    function qs(sel, root) {
        return (root || document).querySelector(sel);
    }

    function qsa(sel, root) {
        return Array.prototype.slice.call((root || document).querySelectorAll(sel));
    }

    function openModal(el) {
        if (!el) return;
        el.classList.add('is-open');
        el.setAttribute('aria-hidden', 'false');
    }

    function closeModal(el) {
        if (!el) return;
        el.classList.remove('is-open');
        el.setAttribute('aria-hidden', 'true');
    }

    function closeAllModals() {
        qsa('.admin-modal').forEach(function (m) {
            closeModal(m);
        });
    }

    // 头像下拉复用全站逻辑：hover 展示（CSS 控制）

    qsa('[data-admin-close="1"]').forEach(function (btn) {
        btn.addEventListener('click', function () {
            closeAllModals();
        });
    });

    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') {
            closeAllModals();
        }
    });

    var postModal = qs('#adminPostModal');
    var postModalTitle = qs('#adminPostModalTitle');
    var postModalText = qs('#adminPostModalText');
    var postModalConfirm = qs('#adminPostModalConfirm');
    var postSingleForm = qs('#adminPostSingleForm');
    var postSingleAction = qs('#adminPostSingleAction');
    var postSingleId = qs('#adminPostSingleId');
    var batchBar = qs('#adminBatchBar');
    var batchCountEl = qs('#adminBatchCount');
    var batchActionInput = qs('#adminPostsBatchAction');
    var batchForm = qs('#adminPostsBatchForm');
    var checkAll = qs('#adminCheckAllPosts');

    var pendingPost = null;

    function getCheckedBoxes() {
        return batchForm ? qsa('.admin-row-check:checked', batchForm) : [];
    }

    function refreshBatchBar() {
        if (!batchBar || !batchCountEl) return;
        var n = getCheckedBoxes().length;
        batchBar.hidden = n === 0;
        batchCountEl.textContent = '已选 ' + n + ' 条';
    }

    if (batchForm) {
        batchForm.addEventListener('change', function (e) {
            if (e.target && e.target.classList && e.target.classList.contains('admin-row-check')) {
                refreshBatchBar();
            }
        });
    }

    if (checkAll && batchForm) {
        checkAll.addEventListener('change', function () {
            var on = checkAll.checked;
            qsa('.admin-row-check', batchForm).forEach(function (cb) {
                cb.checked = on;
            });
            refreshBatchBar();
        });
    }

    qsa('.js-admin-post-hide').forEach(function (btn) {
        btn.addEventListener('click', function () {
            var id = btn.getAttribute('data-post-id');
            if (!id || !postModalTitle || !postModalText) return;
            pendingPost = { mode: 'single', action: 'post_hide', id: id };
            postModalTitle.textContent = '下架帖子';
            postModalText.textContent = '确定将本条帖子下架？下架后首页将不再展示。';
            openModal(postModal);
        });
    });

    qsa('.js-admin-post-restore').forEach(function (btn) {
        btn.addEventListener('click', function () {
            var id = btn.getAttribute('data-post-id');
            if (!id || !postModalTitle || !postModalText) return;
            pendingPost = { mode: 'single', action: 'post_restore', id: id };
            postModalTitle.textContent = '恢复帖子';
            postModalText.textContent = '确定恢复该帖子为「正常」状态并在首页展示？';
            openModal(postModal);
        });
    });

    var batchHideBtn = qs('#adminBatchHideBtn');
    var batchRestoreBtn = qs('#adminBatchRestoreBtn');

    if (batchHideBtn && postModalTitle && postModalText) {
        batchHideBtn.addEventListener('click', function () {
            var n = getCheckedBoxes().length;
            if (n === 0) return;
            pendingPost = { mode: 'batch', action: 'posts_batch_hide' };
            postModalTitle.textContent = '批量下架';
            postModalText.textContent =
                '确定下架已选中的 ' + n + ' 条帖子？仅「正常」状态的帖子会被下架。';
            openModal(postModal);
        });
    }

    if (batchRestoreBtn && postModalTitle && postModalText) {
        batchRestoreBtn.addEventListener('click', function () {
            var n = getCheckedBoxes().length;
            if (n === 0) return;
            pendingPost = { mode: 'batch', action: 'posts_batch_restore' };
            postModalTitle.textContent = '批量恢复';
            postModalText.textContent =
                '确定将已选中的帖子恢复为「正常」？仅「已隐藏」或「已删除」的帖子会被恢复。';
            openModal(postModal);
        });
    }

    if (postModalConfirm) {
        postModalConfirm.addEventListener('click', function () {
            if (!pendingPost) {
                closeModal(postModal);
                return;
            }
            if (pendingPost.mode === 'batch') {
                var n = getCheckedBoxes().length;
                if (n === 0) {
                    closeModal(postModal);
                    pendingPost = null;
                    return;
                }
                if (batchActionInput) batchActionInput.value = pendingPost.action;
                if (batchForm) batchForm.submit();
                pendingPost = null;
                return;
            }
            if (pendingPost.mode === 'single' && postSingleForm && postSingleAction && postSingleId) {
                postSingleAction.value = pendingPost.action;
                postSingleId.value = String(pendingPost.id);
                postSingleForm.submit();
            }
        });
    }

    var banModal = qs('#adminBanModal');
    var banUserLine = qs('#adminBanModalUserLine');
    var banConfirm = qs('#adminBanModalConfirm');
    var banForm = qs('#adminUserBanForm');
    var banUserId = qs('#adminBanUserId');
    var banDuration = qs('#adminBanDuration');
    var pendingBanUserId = null;
    var pendingBanMode = null;

    var usersBatchForm = qs('#adminUsersBatchForm');
    var usersBatchActionInput = qs('#adminUsersBatchActionInput');
    var usersBatchBanDuration = qs('#adminUsersBatchBanDuration');
    var usersBatchBar = qs('#adminUsersBatchBar');
    var usersBatchCountEl = qs('#adminUsersBatchCount');
    var checkAllUsers = qs('#adminCheckAllUsers');
    var unbanForm = qs('#adminUserUnbanForm');
    var unbanUserIdInput = qs('#adminUnbanUserId');

    function getCheckedUserBoxes() {
        return usersBatchForm ? qsa('.admin-user-row-check:checked', usersBatchForm) : [];
    }

    function refreshUsersBatchBar() {
        if (!usersBatchBar || !usersBatchCountEl) return;
        var n = getCheckedUserBoxes().length;
        usersBatchBar.hidden = n === 0;
        usersBatchCountEl.textContent = '已选 ' + n + ' 人';
    }

    if (usersBatchForm) {
        usersBatchForm.addEventListener('change', function (e) {
            if (e.target && e.target.classList && e.target.classList.contains('admin-user-row-check')) {
                refreshUsersBatchBar();
            }
        });
    }

    if (checkAllUsers && usersBatchForm) {
        checkAllUsers.addEventListener('change', function () {
            var on = checkAllUsers.checked;
            qsa('.admin-user-row-check', usersBatchForm).forEach(function (cb) {
                cb.checked = on;
            });
            refreshUsersBatchBar();
        });
    }

    var usersBatchBanBtn = qs('#adminUsersBatchBanBtn');
    var usersBatchUnbanBtn = qs('#adminUsersBatchUnbanBtn');

    if (usersBatchBanBtn && banModal && banUserLine) {
        usersBatchBanBtn.addEventListener('click', function () {
            var n = getCheckedUserBoxes().length;
            if (n === 0) return;
            pendingBanMode = 'batch';
            pendingBanUserId = null;
            banUserLine.textContent = '将封禁选中的 ' + n + ' 个用户（不含管理员账号），被选中但已是「正常」以外状态的行将被跳过。';
            var firstRadio = qs('input[name="ban_duration_ui"][value="7"]', banModal);
            if (firstRadio) firstRadio.checked = true;
            openModal(banModal);
        });
    }

    if (usersBatchUnbanBtn && usersBatchForm && usersBatchActionInput) {
        usersBatchUnbanBtn.addEventListener('click', function () {
            var n = getCheckedUserBoxes().length;
            if (n === 0) return;
            if (
                !confirm(
                    '确定解封选中的用户？仅「已封禁」且非管理员的账号会被解封。'
                )
            ) {
                return;
            }
            usersBatchActionInput.value = 'users_batch_unban';
            if (usersBatchBanDuration) usersBatchBanDuration.value = '';
            usersBatchForm.submit();
        });
    }

    qsa('.js-admin-user-ban').forEach(function (btn) {
        btn.addEventListener('click', function () {
            var uid = btn.getAttribute('data-user-id');
            var name = btn.getAttribute('data-username') || '';
            pendingBanMode = 'single';
            pendingBanUserId = uid;
            if (banUserLine) {
                banUserLine.textContent = '用户「' + name + '」将被禁止登录。';
            }
            var firstRadio = qs('input[name="ban_duration_ui"][value="7"]', banModal);
            if (firstRadio) firstRadio.checked = true;
            openModal(banModal);
        });
    });

    qsa('.js-admin-user-unban').forEach(function (btn) {
        btn.addEventListener('click', function () {
            var uid = btn.getAttribute('data-user-id');
            if (!uid || !unbanForm || !unbanUserIdInput) return;
            if (!confirm('确定解封该用户？')) return;
            unbanUserIdInput.value = uid;
            unbanForm.submit();
        });
    });

    if (banConfirm && banForm && banUserId && banDuration) {
        banConfirm.addEventListener('click', function () {
            var selected = qs('input[name="ban_duration_ui"]:checked', banModal);
            var dur = selected ? selected.value : '7';

            if (pendingBanMode === 'batch') {
                if (!usersBatchForm || !usersBatchActionInput || !usersBatchBanDuration) {
                    closeModal(banModal);
                    return;
                }
                var n = getCheckedUserBoxes().length;
                if (n === 0) {
                    closeModal(banModal);
                    pendingBanMode = null;
                    return;
                }
                usersBatchActionInput.value = 'users_batch_ban';
                usersBatchBanDuration.value = dur;
                usersBatchForm.submit();
                pendingBanMode = null;
                return;
            }

            if (!pendingBanUserId) {
                closeModal(banModal);
                return;
            }
            banUserId.value = pendingBanUserId;
            banDuration.value = dur;
            banForm.submit();
        });
    }
})();
