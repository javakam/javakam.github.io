---
title: "Hugo + GitHub Pages 部署闭环：验证、清理与故障处理"
date: 2026-08-06T10:00:00+08:00
lastmod: 2026-08-09T18:00:00+08:00
slug: "Hugo-GitHub-Pages部署与清理实践"
url: "/2026/08/06/Hugo-GitHub-Pages部署与清理实践/"
categories: ["Hugo","GitHub"]
tags: ["Hugo","GitHub Pages","GitHub Actions","部署","清理"]
toc: true
---

把博客从 Jekyll 迁移到 Hugo Stack 后，发布工作不应停在“本地能构建”。旧链接是否还能访问，Pages 是否真的使用了 Actions，搜索和 RSS 是否生成，以及本地预览进程和临时文件是否被收回，都需要在一次发布中确认。

本文以 Hugo Stack 和 GitHub Pages 为例，整理一套可重复执行的流程。命令以 Windows PowerShell 为主，Linux 或 macOS 只需替换路径和进程检查命令。

## 1. 发布前预检

先确认当前目录就是仓库根目录，并检查是否有未提交的改动：

```powershell
Get-Location
git status --short --branch
git remote -v
git submodule status
```

工作树中已有的改动不应被构建或清理命令覆盖。主题使用 Git 子模块时，CI 必须递归检出，否则本地正常、Actions 缺主题文件的情况很难排查。

还要检查预览端口。不要因为浏览器里关掉了页面，就认定服务已经结束：

```powershell
Get-NetTCPConnection -LocalPort 4173 -State Listen -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process |
  Where-Object CommandLine -Match 'http\.server|hugo server|vite'
```

如果端口被占用，先查看命令行和工作目录，再决定是否停止。不能按端口直接结束未知进程。

## 2. 使用固定版本构建

本地的 Hugo Extended 与 Dart Sass 应和工作流保持一致。本仓库的工作流固定 Hugo Extended `0.164.0` 和 Dart Sass `1.97.1`；本文使用 Actionlint `1.7.12` 检查 Actions YAML。版本发生变化时，应先更新工作流和本地验证记录，再发布文章或站点。

先做一次临时目录构建，避免把生成物写进仓库：

```powershell
$releaseRoot = Join-Path $env:TEMP ("hugo-release-" + [guid]::NewGuid().ToString("N"))
$output = Join-Path $releaseRoot "public"
New-Item -ItemType Directory -Path $output -Force | Out-Null

hugo --gc --minify --cleanDestinationDir --destination $output
```

然后运行静态检查：

```powershell
git diff --check
pwsh -NoProfile -File .\tests\site-audit.ps1
actionlint
```

如果审计脚本需要检查仓库内的 `public/`，可以按脚本要求构建一次默认输出，检查完成后立即执行清理。不要把 `public/`、`resources/`、`.hugo_build.lock` 或 `assets/jsconfig.json` 提交进 Git。

生成目录至少应检查以下内容：

- 首页、归档、分类、标签和搜索页。
- `/search/index.json`、`/feed.xml` 和一篇带代码或图片的文章。
- 迁移前保留的旧 URL，尤其是大小写和中文路径。
- 桌面端和移动端的溢出、错位，以及浏览器控制台错误。

## 3. 配置 GitHub Pages

工作流需要完成三件事：检出主题子模块、用固定版本构建 Hugo、上传并部署 Pages artifact。当前使用的 Action 组合如下：

```yaml
- uses: actions/checkout@v6
  with:
    submodules: recursive
- uses: actions/configure-pages@v6
- uses: actions/upload-pages-artifact@v5
- uses: actions/deploy-pages@v5
```

同时确认工作流权限包含：

```yaml
permissions:
  contents: read
  pages: write
  id-token: write
```

仓库设置中的 `Settings > Pages > Build and deployment > Source` 必须选择 `GitHub Actions`。如果这里仍是 `Deploy from a branch`，GitHub 可能继续按 Jekyll 处理根目录，线上看到的就不是 Hugo 构建结果。

相关文档：

- [Hugo 官方 GitHub Pages 指南](https://gohugo.io/host-and-deploy/host-on-github-pages/)
- [GitHub Pages 自定义工作流](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)
- [Hugo Theme Stack](https://github.com/CaiJimmy/hugo-theme-stack)

## 4. 管理本地预览

`127.0.0.1` 是本机回环地址，`4173` 只是某个本地预览服务使用的端口。它们与 GitHub Pages 无关，也不会被上传到远端。下面的命令常用于临时查看已经生成的 `public/`：

```powershell
python -m http.server 4173 --bind 127.0.0.1 --directory public
```

脚本或终端异常中断时，Python 子进程可能继续监听端口。清理前记录服务 PID、端口和临时目录，只处理能确认属于当前仓库的进程。

仓库中的 `hugo-pages-deploy-cleanup` Skill 封装了这套检查。先预览删除范围：

```powershell
pwsh -NoProfile `
  -File .\skills\hugo-pages-deploy-cleanup\scripts\cleanup-hugo.ps1 `
  -RepoRoot (Get-Location).Path `
  -Ports 4173 `
  -TempPath $releaseRoot `
  -WhatIf
```

确认输出后移除 `-WhatIf`。脚本只会删除仓库中已知且未跟踪的 Hugo 生成物，以及显式传入的系统临时目录；遇到无法确认归属的监听进程会保留并发出警告。

不要使用 `git clean -fdx`，也不要删除整个系统临时目录。构建、预览、浏览器测试和下载工具都应使用本次任务专属的目录，并在结束时逐项回收。

## 5. 发布与线上验证

推送后要同时关注 `build` 和 `deploy` 两个作业。只有 `deploy` 成功，Pages 才完成发布：

1. 在 Actions 页面确认运行对应本次提交。
2. 等待 `build` 和 `deploy` 都显示成功。
3. 请求公开域名和代表性路径，确认返回 Hugo 页面，而不是 README 或旧 Jekyll 页面。

建议检查：

```text
/
/search/index.json
/feed.xml
/archives/
/categories/
/tags/
一篇文章页面
一张文章图片
```

旧 URL 返回 404 时，先比较原 URL 的大小写、中文编码和尾部斜杠，再在文章 Front Matter 中添加明确的 `url` 或 `aliases`。不要用一个宽泛的重定向掩盖路径错误。

如果本地网络访问公开域名时出现 TLS 重置，应把它记录为验证环境问题，改用 GitHub Actions、页面源文件和其他网络环境复验，不能仅凭一次连接失败判定站点内容损坏。

## 6. 常见故障

### 线上显示 README 或旧 Jekyll 页面

先检查 Pages Source 是否为 `GitHub Actions`，再检查最新运行的 `deploy` 作业。不要先改模板或删除内容。

### 本地构建成功，Actions 构建失败

对比 Hugo Extended、Dart Sass、主题子模块和工作流参数。工作流中的版本应明确写出，避免使用本机 PATH 中偶然存在的版本。

### 搜索页打开但没有结果

确认搜索页输出了 `JSON`，并检查 `/search/index.json` 是否能访问。摘要经过截断时，还要检查自定义脚本是否清理了异常的 Unicode 字符。

### 4173 端口在任务结束后仍然可用

重新查看端口所属 PID 和命令行，只停止命令行明确指向当前仓库的 `http.server`、`hugo server` 或 `vite` 进程。清理脚本无法确认归属时会保留进程，需人工处理。

### 文章或脚本中出现真实凭据

先从当前内容和构建产物中移除，再立即轮换已经使用过的密码、Token 或密钥。删除文件不会清除 Git 历史；是否重写历史应单独评估，不能在一次普通发布中强制推送。

## 7. 发布结束检查

发布任务完成前，逐项确认：

- Hugo 构建、站点审计和 Actionlint 通过。
- Actions 的 `build` 与 `deploy` 均成功。
- 首页、搜索、分类、标签、RSS、代表性文章和旧 URL 可访问。
- 预览端口不再监听，任务创建的浏览器和测试进程已经退出。
- `public/`、`resources/`、Hugo 锁文件和临时工具目录已经删除。
- `git diff --check` 通过，工作树只包含计划提交的内容。

部署成功不等于任务结束。只有线上内容、旧链接、本地进程和临时产物都得到确认，下一次发布才不会从一堆遗留状态开始。
