---
title: "Markdown目录生成"
date: 2019-09-23T15:04:45+08:00
slug: "markdown-toc-dom"
url: "/2019/09/23/markdown-toc-dom/"
categories: ["GitHub"]
tags: ["Markdown"]
---

# GitHub支持 Markdown 目录生成

## CSDN
<https://blog.csdn.net/JavaKam/article/details/101020144>

## 参考项目: <br>
[flexmark-java](https://github.com/vsch/flexmark-java) <br>
[i5ting_ztree_toc](https://github.com/i5ting/i5ting_ztree_toc) <br>
<https://github.com/YuraAAA/Markdown-Toc-Generator/> <br>
<https://github.com/zhang0peter/markdown2html>

## 效果图
![Image text](/files/markdown-toc/效果图1.png)<br>
![Image text](/files/markdown-toc/效果图2.png)<br>

## 使用方式
1.下载 [github-markdown-toc.jar](https://github.com/javakam/markdown-toc-dom/releases)
2.安装 Java 运行环境;
3.双击运行

## 可以用 **[TOC]** 或 **[toc]** 开头才会生成目录 , 不写也行...
```
[TOC]
# Heading **some bold**
## Heading 1.1 _some italic
### Heading 1.1.1
### Heading 1.1.2  **_some bold italic_**
#### Heading 1.1.2.1  **_some bold italic_666**
##### Heading 1.1.2.1.1  **_some bold 2222**
```
### 效果

<div class="toc">
<h1>目录</h1>
<ul>
<li><a href="#heading-some-bold">Heading <strong>some bold</strong></a>
<ul>
<li><a href="#heading-11--some-italic">Heading 1.1 _some italic</a>
<ul>
<li><a href="#heading-111">Heading 1.1.1</a></li>
<li><a href="#heading-112--some-bold-italic">Heading 1.1.2  <strong><em>some bold italic</em></strong></a>
<ul>
<li><a href="#heading-1121---some-bold-italic-666">Heading 1.1.2.1  <strong>_some bold italic_666</strong></a>
<ul>
<li><a href="#heading-11211---some-bold-2222">Heading 1.1.2.1.1  <strong>_some bold 2222</strong></a></li>
</ul>
</li>
</ul>
</li>
</ul>
</li>
</ul>
</li>
</ul>
</div>

---

## 支持html文件生成目录
[在线示例](/demos/markdown-toc.html)

### 项目源码
[README](https://github.com/javakam/markdown-toc-dom#readme)

<!-- https://blog.csdn.net/xudailong_blog/article/details/78762262 -->
<!--https://643435675.github.io/2015/02/15/create-my-blog-with-jekyll/-->
