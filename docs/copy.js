document.querySelectorAll('.copy-btn').forEach(function (btn) {
    var label = btn.querySelector('.copy-btn__text');
    btn.addEventListener('click', function () {
        var code = btn.closest('.code-block').querySelector('.install-code');
        if (!code || !navigator.clipboard) { return; }
        navigator.clipboard.writeText(code.textContent).then(function () {
            label.textContent = 'Copied!';
            btn.classList.add('copied');
            setTimeout(function () {
                label.textContent = 'Copy';
                btn.classList.remove('copied');
            }, 2000);
        }).catch(function () {});
    });
});
