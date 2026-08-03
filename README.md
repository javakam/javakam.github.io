# 风之旅人

个人技术博客，使用 [Hugo](https://gohugo.io/) 和
[Hugo Theme Stack](https://github.com/CaiJimmy/hugo-theme-stack) 构建。

## 本地预览

需要 Hugo Extended `0.164.0` 或更高版本，以及 Dart Sass。

```bash
git clone --recurse-submodules https://github.com/javakam/javakam.github.io.git
cd javakam.github.io
hugo server
```

文章位于 `content/post`，静态图片和附件位于 `static/files`。推送到
`master` 后，GitHub Actions 会自动构建并部署到
[javakam.github.io](https://javakam.github.io/)。
