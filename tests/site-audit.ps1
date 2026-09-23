$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = [System.Collections.Generic.List[string]]::new()

function Read-RepoFile([string]$RelativePath) {
    return Get-Content -Raw -LiteralPath (Join-Path $repoRoot $RelativePath)
}

function Assert-True([string]$Name, [bool]$Condition) {
    if (-not $Condition) {
        $failures.Add("FAIL: $Name")
    }
}

function Assert-Matches([string]$Name, [string]$Content, [string]$Pattern) {
    Assert-True $Name ($Content -match $Pattern)
}

function Assert-NotMatches([string]$Name, [string]$Content, [string]$Pattern) {
    Assert-True $Name ($Content -notmatch $Pattern)
}

$config = Read-RepoFile 'config/_default/hugo.toml'
$params = Read-RepoFile 'config/_default/params.toml'
$search = Read-RepoFile 'content/page/search/index.md'
$categories = Read-RepoFile 'content/categories/_index.md'
$tags = Read-RepoFile 'content/tags/_index.md'
$workflow = Read-RepoFile '.github/workflows/deploy.yml'
$gitmodules = Read-RepoFile '.gitmodules'
$customScript = Read-RepoFile 'assets/ts/custom.ts'
$customStyle = Read-RepoFile 'assets/scss/custom.scss'
$customHead = Read-RepoFile 'layouts/_partials/head/custom.html'
$articleContentPartial = Read-RepoFile 'layouts/_partials/article/components/content.html'
$relayPost = Read-RepoFile 'content/post/2026-08-09-AI中转站清单2026年8月9日.md'
$archive = Read-RepoFile 'content/post/2019-12-23-早期学习记录归档.md'
$posts = @(Get-ChildItem (Join-Path $repoRoot 'content/post') -File -Filter '*.md')
$archiveAliases = @(
    '/2019/09/23/first-github-blog/'
    '/2019/10/14/学习计划/'
    '/2019/10/16/Android高级01/'
    '/2019/12/21/Android性能优化-一/'
    '/2019/12/23/模板/'
    '/2019/12/23/JVM指令手册/'
)

Assert-Matches '站点地址应指向 GitHub Pages 根域名' $config '(?m)^baseURL\s*=\s*"https://javakam\.github\.io/"'
Assert-Matches '站点语言应使用 Hugo 新版 locale 配置' $config '(?m)^locale\s*=\s*"zh-cn"'
Assert-Matches '站点应启用中文内容语言' $config '(?m)^defaultContentLanguage\s*=\s*"zh"'
Assert-Matches '中文摘要应启用 CJK 处理' $config '(?m)^hasCJKLanguage\s*=\s*true'
Assert-Matches '站点应使用 Stack 主题' $config '(?m)^theme\s*=\s*"hugo-theme-stack"'
Assert-Matches '文章路径应保留旧站大小写' $config '(?m)^disablePathToLower\s*=\s*true'
Assert-Matches '文章 URL 应兼容旧站日期路径' $config 'post\s*=\s*"/:year/:month/:day/:slug/"'
Assert-Matches 'RSS 应继续输出到 feed.xml' $config '(?s)\[outputFormats\.RSS\].*?baseName\s*=\s*"feed"'
Assert-Matches '首页应显示搜索组件' $params '(?s)\[widgets\].*?\{\s*type\s*=\s*"search"\s*\}'
Assert-Matches '评论应默认关闭' $params '(?s)\[comments\].*?enabled\s*=\s*false'
Assert-Matches '搜索页应生成 JSON 索引' $search '(?s)layout:\s*search.*?outputs:.*?-\s*json'
Assert-Matches '分类页应兼容旧 category 路径' $categories '(?m)^\s*- /category/$'
Assert-Matches '标签页应兼容旧 tag 路径' $tags '(?m)^\s*- /tag/$'
Assert-Matches '部署工作流应构建 Hugo' $workflow '(?m)^\s*hugo\s*$'
Assert-Matches '部署工作流应固定兼容 Stack 的 Hugo 版本' $workflow '(?m)^\s*HUGO_VERSION:\s*0\.164\.0$'
Assert-Matches '部署工作流应发布 Pages artifact' $workflow 'actions/upload-pages-artifact@v5'
Assert-Matches '主题应来自官方仓库' $gitmodules 'https://github\.com/CaiJimmy/hugo-theme-stack\.git'
Assert-Matches '搜索摘要应清理截断产生的异常字符' $customScript 'removeUnpairedSurrogates'
Assert-Matches '首屏应恢复用户选择的视觉主题' $customHead 'StackVisualTheme'
Assert-Matches '侧栏应提供按钮式视觉主题选择器' $customScript 'visual-theme-toggle'
Assert-Matches '视觉主题应使用独立弹出面板' $customScript 'visual-theme-panel'
Assert-Matches '视觉主题面板应支持键盘关闭' $customScript "event\.key === 'Escape'"
Assert-NotMatches '视觉主题不应继续使用原生下拉框' $customScript "createElement\('select'\)|visual-theme-select"
Assert-Matches '视觉主题默认项应为 Stack 原版' $customScript "\{ value: 'stack', label: 'Stack 原版'"
Assert-Matches '视觉主题应提供海风蓝方案' $customStyle ':root\[data-visual-theme="ocean"\]\[data-scheme="light"\]'
Assert-Matches '视觉主题应提供松石绿方案' $customStyle ':root\[data-visual-theme="forest"\]\[data-scheme="light"\]'
Assert-Matches '视觉主题应提供极简石墨方案' $customStyle ':root\[data-visual-theme="graphite"\]\[data-scheme="light"\]'
Assert-Matches '视觉主题应提供 GitHub Primer 方案' $customScript "\{ value: 'primer', label: 'GitHub Primer'"
Assert-Matches 'GitHub Primer 方案应同时支持明暗模式' $customStyle ':root\[data-visual-theme="primer"\]\[data-scheme="(?:light|dark)"\]'
Assert-Matches '视觉主题应提供 Catppuccin 方案' $customScript "\{ value: 'catppuccin', label: 'Catppuccin'"
Assert-Matches 'Catppuccin 方案应同时支持明暗模式' $customStyle ':root\[data-visual-theme="catppuccin"\]\[data-scheme="(?:light|dark)"\]'
Assert-Matches '首屏主题恢复应识别新增视觉主题' $customHead '"primer", "catppuccin"'
Assert-NotMatches 'Stack 原版不应被自定义变量覆盖' $customStyle 'data-visual-theme="stack"'
Assert-Matches '中转站文章应启用专属内容样式' $relayPost '(?m)^content_class:\s*"relay-directory"$'
Assert-Matches '中转站文章应记录持续更新源' $relayPost '(?m)^source_url:\s*"https://docs\.qq\.com/markdown/DQkthRnRnc2dNRGVo"$'
Assert-Matches '中转站文章应同步最新文档标题日期' $relayPost '(?m)^title:\s*"AI中转站清单（2026年9月25日）"$'
Assert-NotMatches '中转站正文不应重复显示文档标题' $relayPost '(?m)^# AI中转站清单（2026年9月25日）$'
Assert-Matches '中转站表格应显示完整可见链接' $relayPost '(?m)^\|[^|]+\|[^|]+\|\s*<https://[^>]+>\s*\|$'
Assert-Matches '文章内容局部应读取页面专属样式类' $articleContentPartial '\.Params\.content_class'
Assert-Matches '文章内容局部应保留响应式表格包装' $articleContentPartial 'class=\\"table-wrapper\\"'
Assert-Matches '中转站加宽规则应限定到专属内容类' $customHead '\.container\.extended:has\(\.article-content\.relay-directory\)'
Assert-Matches '中转站强调色应跟随当前视觉主题' $customHead '--relay-accent:\s*var\(--accent-color\)'
Assert-Matches '中转站表头应跟随当前视觉主题' $customHead '--relay-table-heading:\s*var\(--card-background-selected\)'
Assert-NotMatches '中转站样式不应继续固定为蓝色' $customHead '--relay-accent:\s*#228be6'
Assert-NotMatches '自定义样式不应直接覆盖所有扩展布局' $customHead '(?m)^\s*\.container\.extended\s*\{'
Assert-True '清理后应保留 9 篇 Markdown 文章' ($posts.Count -eq 9)

foreach ($alias in $archiveAliases) {
    Assert-True "归档文章应接管旧地址 $alias" ($archive.Contains('"' + $alias + '"'))
}

$legacyPaths = @('_config.yml', '_includes', '_layouts', '_sass', 'page', 'index.html', 'feed.xml')
foreach ($path in $legacyPaths) {
    Assert-True "不应保留 Jekyll 路径 $path" (-not (Test-Path (Join-Path $repoRoot $path)))
}

$sourceFiles = @(
    Get-ChildItem (Join-Path $repoRoot 'config') -Recurse -File
    Get-ChildItem (Join-Path $repoRoot 'assets') -Recurse -File |
        Where-Object { $_.Extension -in '.ts', '.js', '.scss', '.css' }
    Get-ChildItem (Join-Path $repoRoot 'content') -Recurse -File
    Get-ChildItem (Join-Path $repoRoot 'layouts') -Recurse -File
    Get-ChildItem (Join-Path $repoRoot '.github') -Recurse -File
)
$allSource = ($sourceFiles | ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName }) -join "`n"
Assert-NotMatches '公开源码不应包含 OAuth clientSecret' $allSource '(?i)clientSecret\s*[:=]'
Assert-NotMatches '公开内容不应包含公网 root 数据库连接' $allSource '(?i)mysqli_connect\(\s*[''"](?:\d{1,3}\.){3}\d{1,3}(?::\d+)?[''"]\s*,\s*[''"]root[''"]'
Assert-NotMatches '公开内容不应硬编码 Docker root 密码' $allSource '(?i)MYSQL_ROOT_PASSWORD=(?!\$\{|\$)[^\s`"'']+'
Assert-NotMatches 'Hugo 内容不应包含 Jekyll Liquid 标签' $allSource '\{%|\{\{\s*(?:site|page|post)\.'
Assert-NotMatches '内容不应引用 Windows 本地图片路径' $allSource '(?i)(?:src=["''][A-Z]:\\|\]\([A-Z]:\\)'
Assert-NotMatches '内容不应使用 Kramdown 属性语法' $allSource '\{:[^}]+\}'

foreach ($post in $posts) {
    $text = Get-Content -Raw -LiteralPath $post.FullName
    Assert-Matches "$($post.Name) 应包含有效 Front Matter" $text '\A---\r?\n(?s:.*?)\r?\n---\r?\n'
    Assert-Matches "$($post.Name) 应包含日期" $text '(?m)^date:\s*\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\+08:00$'
    Assert-Matches "$($post.Name) 应包含固定 slug" $text '(?m)^slug:\s*".+"$'
    Assert-Matches "$($post.Name) 应包含固定旧站 URL" $text '(?m)^url:\s*"/.+/"$'
    Assert-Matches "$($post.Name) 应包含分类数组" $text '(?m)^categories:\s*\[.+\]$'
    Assert-Matches "$($post.Name) 应包含标签数组" $text '(?m)^tags:\s*\[.+\]$'

    $dateMatch = [regex]::Match($text, '(?m)^date:\s*(?<date>\d{4}-\d{2}-\d{2})T')
    $urlMatch = [regex]::Match($text, '(?m)^url:\s*"(?<url>/.+/)"$')
    if ($dateMatch.Success -and $urlMatch.Success) {
        $legacySlug = $post.BaseName -replace '^\d{4}-\d{2}-\d{2}-', ''
        $legacySlug = ($legacySlug -replace '[（）]', '-').Trim('-')
        $expectedUrl = "/$($dateMatch.Groups['date'].Value.Replace('-', '/'))/$legacySlug/"
        Assert-True "$($post.Name) 应保留 Jekyll 旧链接" ($urlMatch.Groups['url'].Value -ceq $expectedUrl)
    }

    foreach ($match in [regex]::Matches($text, '(?m)(?:!\[[^\]]*\]\(|src=["''])/files/(?<path>[^)"''\r\n]+)')) {
        $relativePath = [Uri]::UnescapeDataString($match.Groups['path'].Value)
        Assert-True "$($post.Name) 引用的资源应存在: $relativePath" (Test-Path -LiteralPath (Join-Path $repoRoot "static/files/$relativePath"))
    }
}

if (Test-Path (Join-Path $repoRoot 'public')) {
    $homeOutput = Read-RepoFile 'public/index.html'
    Assert-NotMatches '构建产物不应依赖 Google Fonts' $homeOutput 'fonts\.googleapis\.com'

    $requiredOutput = @(
        'index.html',
        'feed.xml',
        'archives/index.html',
        'categories/index.html',
        'tags/index.html',
        'search/index.html',
        'search/index.json',
        'archive/index.html',
        'category/index.html',
        'tag/index.html',
        '2019/09/23/markdown-toc-demo/index.html',
        '2019/12/23/早期学习记录归档/index.html'
    )
    $requiredOutput += $archiveAliases | ForEach-Object { $_.Trim('/') + '/index.html' }
    foreach ($path in $requiredOutput) {
        Assert-True "构建产物应包含 $path" (Test-Path -LiteralPath (Join-Path $repoRoot "public/$path"))
    }

    $outputFiles = @(Get-ChildItem (Join-Path $repoRoot 'public') -Recurse -File | ForEach-Object {
        $_.FullName.Substring((Join-Path $repoRoot 'public').Length + 1).Replace('\', '/')
    })
    foreach ($post in $posts) {
        $text = Get-Content -Raw -LiteralPath $post.FullName
        $urlMatch = [regex]::Match($text, '(?m)^url:\s*"(?<url>/.+/)"$')
        if ($urlMatch.Success) {
            $expectedOutput = $urlMatch.Groups['url'].Value.Trim('/') + '/index.html'
            Assert-True "$($post.Name) 应按旧链接精确输出" ($outputFiles -ccontains $expectedOutput)
        }
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ -ErrorAction Continue }
    exit 1
}

Write-Host 'PASS: Hugo Stack migration audit'
