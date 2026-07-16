$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = [System.Collections.Generic.List[string]]::new()

function Read-RepoFile([string]$RelativePath) {
    return Get-Content -Raw -LiteralPath (Join-Path $repoRoot $RelativePath)
}

function Assert-Matches([string]$Name, [string]$Content, [string]$Pattern) {
    if ($Content -notmatch $Pattern) {
        $failures.Add("FAIL: $Name")
    }
}

function Assert-NotMatches([string]$Name, [string]$Content, [string]$Pattern) {
    if ($Content -match $Pattern) {
        $failures.Add("FAIL: $Name")
    }
}

$config = Read-RepoFile '_config.yml'
$comments = Read-RepoFile '_includes/comments.html'
$defaultLayout = Read-RepoFile '_layouts/default.html'
$postLayout = Read-RepoFile '_layouts/post.html'
$header = Read-RepoFile '_includes/header.html'
$head = Read-RepoFile '_includes/head.html'
$index = Read-RepoFile 'index.html'
$feed = Read-RepoFile 'feed.xml'
$pageContent = Read-RepoFile 'js/pageContent.js'
$headerStyles = Read-RepoFile '_sass/_header.scss'
$listingPages = @(
    Read-RepoFile 'page/0archives.html'
    Read-RepoFile 'page/1category.html'
    Read-RepoFile 'page/2tags.html'
)
$sourcePaths = @('_includes', '_layouts', '_posts', 'js', 'page')
$sourceFiles = foreach ($sourcePath in $sourcePaths) {
    Get-ChildItem -LiteralPath (Join-Path $repoRoot $sourcePath) -Recurse -File
}
$sourceFiles += Get-ChildItem -LiteralPath $repoRoot -File |
    Where-Object { $_.Extension -in '.html', '.md', '.js', '.yml', '.xml' }
$allContent = $sourceFiles | ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName }
$allContent = $allContent -join "`n"

Assert-NotMatches '公开源码不应包含 OAuth clientSecret' $allContent '(?i)clientSecret\s*:'
Assert-NotMatches '公开源码不应包含注释中的 token' $comments '(?i)加一个\s+token'
Assert-NotMatches '页面不应继续引用已关闭的评论模板' $allContent '\{\%\s*include\s+comments\.html\s*\%\}'
Assert-NotMatches '文章不应引用 Windows 本地图片路径' $allContent '(?i)(?:src=["''][A-Z]:\\|\]\([A-Z]:\\)'
Assert-NotMatches '文章不应使用易失效的 images 相对路径' $allContent 'src=["'']images/'
Assert-NotMatches 'Markdown 图片路径中的圆括号应进行 URL 编码' $allContent '!\[[^\]]*\]\([^\r\n]*\([^\r\n]*\)'
Assert-NotMatches '文章页不应加载 jQuery 1.7.2' $postLayout 'jquery-1\.7\.2'
Assert-NotMatches '文章页不应加载 HTTP 脚本' $postLayout '<script[^>]+src=["'']http://'
Assert-NotMatches '首页注释不应渲染完整摘要' $index '<!--\s*\{\{\s*post\.excerpt'
Assert-Matches 'RSS 摘要应限制长度' $feed 'truncate:\s*300'
Assert-Matches '站点 baseurl 应为空字符串' $config '(?m)^baseurl:\s*["'']["'']'
Assert-Matches 'Jekyll 插件应使用 plugins 字段' $config '(?m)^plugins:'
Assert-NotMatches 'Jekyll 配置不应继续使用 gems 字段' $config '(?m)^gems:'
Assert-Matches '页面应声明中文语言' $defaultLayout '<html\s+lang=["'']zh-CN["'']>'
Assert-Matches '移动菜单应有可访问名称' $header 'aria-label=["'']打开导航菜单["'']'
foreach ($listingPage in $listingPages) {
    Assert-Matches '列表页目录按钮应有可访问名称' $listingPage 'class=["'']anchor["''][^>]+aria-label='
}
Assert-NotMatches '移动菜单按钮不应使用负层级' $headerStyles '\.menu\s*\{[\s\S]*?z-index:\s*-'
Assert-Matches '站内资源应使用 relative_url' $head '\|\s*relative_url'
Assert-Matches 'favicon 应使用 relative_url' $head "'/favicon\.ico'\s*\|\s*relative_url"
Assert-Matches '复制 Markdown 目录后应启用平滑滚动' $pageContent "contentList\.querySelectorAll\('a'\)"
Assert-Matches '文章目录应包含正文一级标题' $pageContent "document\.querySelectorAll\('article h1, article h2"
Assert-Matches '移动目录选择链接后应关闭' $pageContent "contentList\.addEventListener\('click'"
Assert-Matches '移动目录应支持 Escape 关闭' $pageContent "event\.key === 'Escape'"
Assert-NotMatches '微信浏览器检测不应引用未定义的 ua2' $pageContent '\bua2\b'

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ -ErrorAction Continue }
    exit 1
}

Write-Host 'PASS: current site source audit (Git history is not checked)'
