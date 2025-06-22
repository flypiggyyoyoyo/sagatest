document.addEventListener('DOMContentLoaded', function() {
    const menuToggle = document.getElementById('menuToggle');
    const sideMenu = document.getElementById('sideMenu');
    const overlay = document.getElementById('overlay');
    const closeBtn = document.getElementById('closeBtn');

    // 打开菜单
    function openMenu() {
        menuToggle.classList.add('active');
        sideMenu.classList.add('active');
        overlay.classList.add('active');
        document.body.style.overflow = 'hidden';
    }

    // 关闭菜单
    function closeMenu() {
        menuToggle.classList.remove('active');
        sideMenu.classList.remove('active');
        overlay.classList.remove('active');
        document.body.style.overflow = 'auto';
    }

    // 事件监听
    menuToggle.addEventListener('click', function() {
        if (sideMenu.classList.contains('active')) {
            closeMenu();
        } else {
            openMenu();
        }
    });

    closeBtn.addEventListener('click', closeMenu);
    overlay.addEventListener('click', closeMenu);

    // ESC键关闭菜单
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape' && sideMenu.classList.contains('active')) {
            closeMenu();
        }
    });

    // 防止菜单内容滚动时影响背景
    sideMenu.addEventListener('touchmove', function(e) {
        e.stopPropagation();
    });
});