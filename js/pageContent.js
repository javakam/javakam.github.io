/* jshint asi:true */

(function() {
  var sidebarWrap = document.querySelector('.right > .wrap')
  var contentList = document.querySelector('#content-side')
  var anchorBtn = document.querySelector('.anchor')
  var rightDiv = document.querySelector('.page > .right')

  if (!sidebarWrap || !contentList) return

  buildTableOfContents(contentList)

  if (window.innerWidth > 770) {
    setDesktopSidebarWidth(sidebarWrap)
    setContentMaxHeight(contentList, 137)
    window.addEventListener('scroll', function() {
      updateDesktopSidebar(sidebarWrap, contentList)
    })
    window.addEventListener('resize', function() {
      setDesktopSidebarWidth(sidebarWrap)
      setContentMaxHeight(contentList, 137)
    })
  } else if (anchorBtn && rightDiv) {
    setContentMaxHeight(contentList, 180)

    function closeMobileToc() {
      rightDiv.classList.remove('right-show')
      anchorBtn.classList.remove('anchor-hide')
      anchorBtn.setAttribute('aria-expanded', 'false')
    }

    anchorBtn.addEventListener('click', function(event) {
      event.stopPropagation()
      rightDiv.classList.add('right-show')
      anchorBtn.classList.add('anchor-hide')
      anchorBtn.setAttribute('aria-expanded', 'true')
    })

    rightDiv.addEventListener('click', function(event) {
      event.stopPropagation()
    })

    contentList.addEventListener('click', function(event) {
      if (event.target.closest('a')) closeMobileToc()
    })

    document.body.addEventListener('click', function() {
      closeMobileToc()
    })

    document.addEventListener('keydown', function(event) {
      if (event.key === 'Escape' && rightDiv.classList.contains('right-show')) {
        closeMobileToc()
        anchorBtn.focus()
      }
    })

    window.addEventListener('scroll', function() {
      var top = Math.max(document.documentElement.scrollTop, document.body.scrollTop)
      anchorBtn.style.top = top > 50 ? '20px' : '76px'
      rightDiv.style.top = top > 50 ? '20px' : '76px'
    })
  }
}())

function buildTableOfContents(contentList) {
  var markdownToc = document.querySelector('#markdown-toc')
  if (markdownToc) {
    contentList.innerHTML = markdownToc.innerHTML
  } else {
    var headings = document.querySelectorAll('article h1, article h2, article h3, article h4, article h5, article h6')
    for (var i = 0; i < headings.length; i++) {
      var heading = headings[i]
      if (!heading.id) heading.id = 'section-' + (i + 1)

      var item = document.createElement('li')
      var link = document.createElement('a')
      link.href = '#' + heading.id
      link.textContent = heading.textContent
      link.className = 'toc-' + heading.tagName.toLowerCase()
      link.setAttribute('data-scroll', '')
      item.appendChild(link)
      contentList.appendChild(item)
    }
  }

  var links = contentList.querySelectorAll('a')
  for (var j = 0; j < links.length; j++) {
    links[j].setAttribute('data-scroll', '')
  }

  if (!contentList.children.length) {
    var side = contentList.closest('.side')
    if (side) side.style.display = 'none'
  }
}

function setDesktopSidebarWidth(sidebarWrap) {
  sidebarWrap.style.width = ''
  sidebarWrap.style.width = sidebarWrap.offsetWidth + 'px'
}

function setContentMaxHeight(contentList, offset) {
  contentList.style.maxHeight = Math.max(160, window.innerHeight - offset) + 'px'
}

function updateDesktopSidebar(sidebarWrap, contentList) {
  var scrollTop = Math.max(document.documentElement.scrollTop, document.body.scrollTop)
  var documentHeight = Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)
  var scrollBottom = documentHeight - window.innerHeight - scrollTop

  if (scrollTop < 53) {
    sidebarWrap.classList.remove('fixed', 'scroll-bottom')
  } else if (scrollBottom >= 152) {
    sidebarWrap.classList.remove('scroll-bottom')
    sidebarWrap.classList.add('fixed')
  } else if (contentList.scrollHeight >= contentList.clientHeight) {
    sidebarWrap.classList.remove('fixed')
    sidebarWrap.classList.add('scroll-bottom')
  }
}
