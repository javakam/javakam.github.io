/**
 * some JavaScript code for this blog theme
 */
/* jshint asi:true */

/////////////////////////header////////////////////////////
/**
 * clickMenu
 */
(function() {
  var menuBtn = document.querySelector('#headerMenu')
  var nav = document.querySelector('#headerNav')
  if (!menuBtn || !nav) return

  function closeMenu() {
    nav.classList.remove('nav-show')
    menuBtn.classList.remove('active')
    menuBtn.setAttribute('aria-expanded', 'false')
  }

  menuBtn.addEventListener('click', function(e) {
    e.stopPropagation()
    var isOpen = menuBtn.classList.toggle('active')
    nav.classList.toggle('nav-show', isOpen)
    menuBtn.setAttribute('aria-expanded', String(isOpen))
  })

  document.body.addEventListener('click', closeMenu)
}());

//////////////////////////back to top////////////////////////////
(function() {
  var backToTop = document.querySelector('.back-to-top')
  if (!backToTop) return

  window.addEventListener('scroll', function() {

    // 页面顶部滚进去的距离
    var scrollTop = Math.max(document.documentElement.scrollTop, document.body.scrollTop)

    if (scrollTop > 200) {
      backToTop.classList.add('back-to-top-show')
    } else {
      backToTop.classList.remove('back-to-top-show')
    }
  })

}());
