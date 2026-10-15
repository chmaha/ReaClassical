var COPY_ICON = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/></svg>';
var CHECK_ICON = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>';

document.querySelectorAll('.copy-btn').forEach(function (btn) {
    btn.addEventListener('click', function () {
        var code = btn.closest('.code-block').querySelector('.install-code');
        if (!code || !navigator.clipboard) { return; }
        navigator.clipboard.writeText(code.textContent).then(function () {
            btn.innerHTML = CHECK_ICON;
            btn.setAttribute('aria-label', 'Copied');
            setTimeout(function () {
                btn.innerHTML = COPY_ICON;
                btn.setAttribute('aria-label', 'Copy command');
            }, 2000);
        }).catch(function () {});
    });
});
