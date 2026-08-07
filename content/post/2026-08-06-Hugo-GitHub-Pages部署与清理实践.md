---
title: "Hugo + GitHub Pages：部署、验证与清理"
date: 2026-08-06T10:00:00+08:00
slug: "Hugo-GitHub-Pages部署与清理实践"
url: "/2026/08/06/Hugo-GitHub-Pages部署与清理实践/"
categories: ["Hugo","GitHub"]
tags: ["Hugo","GitHub Pages","GitHub Actions","Codex"]
toc: true
---

把博客从 Jekyll 迁移到 Hugo Stack，真正麻烦的部分不只是“能构建”，还包括旧链接兼容、GitHub Pages 发布源、线上验证，以及完成后清理本地预览进程和临时文件。

这篇文章记录一套完整的发布闭环：开始前检查、构建、浏览器验证、部署、线上复验和最后清理。

## 127.0.0.1:4173 是什么

`127.0.0.1` 是本机回环地址，`4173` 是某个本地预览服务监听的端口。它只允许当前电脑访问，不会被上传到 GitHub。

例如下面的命令会把 Hugo 生成的 `public/` 目录暴露在 `4173` 端口：

```powershell
python -m http.server 4173 --bind 127.0.0.1 --directory public
```

如果终端异常中断，但子进程没有退出，这个地址就会继续可用。判断它是否仍在运行，不能只看浏览器标签页，而要检查监听端口和进程命令行：

```powershell
Get-NetTCPConnection -LocalPort 4173 -State Listen
Get-CimInstance Win32_Process |
  Where-Object CommandLine -Match 'http\.server|hugo server|vite'
```

停止进程前必须确认命令行确实指向当前仓库，避免误杀同端口的其他服务。

## 发布前检查

先确认工作树、远端分支和主题子模块状态：

```powershell
git status --short --branch
git remote -v
git submodule status
```

构建时应使用与 CI 一致的 Hugo Extended 版本。最好把临时产物放到系统临时目录，避免污染仓库：

```powershell
$releaseRoot = Join-Path $env:TEMP ("hugo-release-" + [guid]::NewGuid().ToString("N"))
$output = Join-Path $releaseRoot "public"
New-Item -ItemType Directory -Path $output -Force | Out-Null
hugo --gc --minify --cleanDestinationDir --destination $output
git diff --check
pwsh -NoProfile -File tests/site-audit.ps1
actionlint
```

如果审计脚本必须读取仓库内的 `public/`，就在审计时按默认目录构建，检查完成后立即清理。

需要重点验证：

- 首页、归档、分类、标签和搜索页。
- 桌面端与移动端是否溢出或错位。
- 搜索索引能否返回结果，摘要是否破坏 emoji。
- 文章图片、附件、RSS 和分页是否正常。
- 迁移前的历史 URL 是否全部保留。
- 浏览器控制台是否存在错误。

## GitHub Pages 发布源

仓库即使已经存在自定义 Hugo 工作流，Pages Source 仍可能停留在旧的 `Deploy from a branch`。这种情况下 GitHub 会继续用 Jekyll 处理仓库根目录，线上首页甚至可能只显示 README。

在仓库的 `Settings > Pages > Build and deployment` 中，应将 Source 设置为 `GitHub Actions`。

当前主流 Pages 工作流使用官方 Action：

```yaml
- uses: actions/checkout@v6
- uses: actions/configure-pages@v6
- uses: actions/upload-pages-artifact@v5
- uses: actions/deploy-pages@v5
```

发布时不能只看到 build 成功就结束。必须继续等待 deploy 作业完成，再请求公开域名确认返回的是 Hugo 页面，而不是旧 Jekyll 缓存。

## 完成后的清理

构建产物和测试工具都应被视为临时资源。常见的可再生成内容包括：

- `public/`
- `resources/`
- `.hugo_build.lock`
- `assets/jsconfig.json`
- `.playwright-cli/`
- 本次下载的 Hugo、actionlint 和 Playwright 临时目录

不要用 `git clean -fdx` 或删除整个系统临时目录。正确做法是记录本次任务创建的路径，逐个验证其绝对路径和 Git 跟踪状态后再删除。

这个仓库增加了 `hugo-pages-deploy-cleanup` Skill，清理脚本支持 `-WhatIf`：

```powershell
pwsh -NoProfile `
  -File .\skills\hugo-pages-deploy-cleanup\scripts\cleanup-hugo.ps1 `
  -RepoRoot (Get-Location).Path `
  -Ports 4173 `
  -TempPath $releaseRoot `
  -WhatIf
```

确认输出正确后移除 `-WhatIf`。如果本次任务下载了临时工具，再通过 `-TempPath` 显式传入对应目录。

## 最终检查清单

发布任务结束前至少确认以下事项：

- Hugo 构建、站点审计和 Actionlint 全部通过。
- GitHub Actions 的 build 与 deploy 作业成功。
- 线上首页、搜索、分类、标签、RSS 和代表性文章正常。
- 历史 URL 与关键静态资源返回预期状态码。
- 本地预览端口不再监听。
- 自动化浏览器和测试进程已经退出。
- 生成目录与本次临时工具已经删除。
- `git diff --check` 通过，工作树只包含计划提交的内容。

“部署成功”只代表代码已经上线；进程、缓存和临时文件都被正确收回，才算任务真正完成。
