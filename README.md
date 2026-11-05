# z-biz-resource-image · 公共图床

> 图片入 Git，通过 `raw.githubusercontent.com` / jsDelivr 拿到**永久不变的公开 URL**。
> 仓库：`z-biz-resource/z-biz-resource-image`（**public**，默认分支 `main`）
> ⚠️ 部分网络下主分发域名不可达，复制 URL 前先看下面「网络可达性」一节。

## ⚠️ 上传前必读

**这是公开仓库，全世界可读，且 Git 历史不可撤销。** 上传即视为发布：

- 只能放**有权公开**的图片（自有素材、已授权素材）。第三方版权图、未公开的产品截图不要放。
- 不要放含密钥、token、内部 IP、个人信息的截图。
- **删掉文件不等于删掉内容** —— 旧版本仍留在 Git 历史与 CDN 缓存里。误传了要立刻改名/撤下并通知使用者，不要指望 `git rm` 能收回。

图片是**源资产**，不是构建产物，所以这里不套用「Git 只装源码、产物不入库」那条规则；`.gitignore` 里刻意没有排除图片。但代价是仓库只增不减，见下面「限制」。

## 快速使用

```bash
# 单张上传：自动按内容哈希命名、提交、推送，并打印 URL
./bin/add-image.sh ~/Desktop/diagram.png

# 自定义可读前缀（只影响文件名，URL 后缀仍是哈希）
./bin/add-image.sh ~/Desktop/未命名.png --slug arch-overview

# 批量上传时先攒着，最后一次性 push
./bin/add-image.sh a.png --no-push
./bin/add-image.sh b.png --no-push
git push origin main

# 体检：命名、哈希一致性、重复图、体积上限
python3 bin/verify.py
```

若本机走 SOCKS 代理导致 SSH 22 端口不通，push 前先：

```bash
export GIT_SSH_COMMAND='ssh -o ProxyCommand=none -o StrictHostKeyChecking=no'
```

## URL 规则

文件落在 `images/YYYY/MM/<slug>-<sha256 前 12 位>.<ext>`，例如
`images/2026/11/arch-overview-3f9a1c0d5b27.png`，对应两个地址：

```
https://cdn.jsdelivr.net/gh/z-biz-resource/z-biz-resource-image@main/images/2026/11/arch-overview-3f9a1c0d5b27.png
https://raw.githubusercontent.com/z-biz-resource/z-biz-resource-image/main/images/2026/11/arch-overview-3f9a1c0d5b27.png
```

Markdown：

```markdown
![架构总览](https://cdn.jsdelivr.net/gh/z-biz-resource/z-biz-resource-image@main/images/2026/11/arch-overview-3f9a1c0d5b27.png)
```

**优先用 jsDelivr**（有 CDN 缓存），`raw.githubusercontent.com` 作为兜底。URL 里的 host 可以直接替换，路径部分不变。

### 网络可达性（换网络务必重验）

jsDelivr 有多个等价节点域名，只换 host、路径不动：

| host | 说明 |
|---|---|
| `cdn.jsdelivr.net` | 官方主域名（`add-image.sh` 默认） |
| `fastly.jsdelivr.net` | 备用节点 |
| `gcore.jsdelivr.net` | 备用节点 |
| `testingcf.jsdelivr.net` | 备用节点 |

自检命令：

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  https://cdn.jsdelivr.net/gh/z-biz-resource/z-biz-resource-image@main/README.md
```

**2026-11-05 建仓当天本机实测**：`cdn.jsdelivr.net`、`raw.githubusercontent.com`、`fastly.jsdelivr.net`（301 跳到 raw）、`github.com/.../raw/...`（302 跳到 raw）**全部 TLS 连接被重置**（curl 35 / HTTP 000）；只有 `gcore.jsdelivr.net` 返回 200 且内容正确。`api.github.com` 与 SSH push 都正常 —— 所以这是分发域名的网络问题，不是仓库没建好。

在本机上传时切到可达节点：

```bash
IMAGE_CDN_HOST=gcore.jsdelivr.net ./bin/add-image.sh ~/Desktop/diagram.png
```

⚠️ 如果目标读者所在网络连所有 jsDelivr 节点和 raw 都通不了，**GitHub 图床这个形态就不成立**，应改成「对象存储 + 自有域名 + CDN」，本仓退化为只放索引与上传脚本。别靠反复换域名硬扛。

### 为什么文件名必须带内容哈希

jsDelivr 对 `@main` 这类分支引用有缓存（约 12 小时），`raw` 也有 CDN 缓存 —— **同名文件覆盖后，URL 不变但内容不会立刻更新**。

内容哈希命名从根上绕开：改一个字节 → 哈希变 → 生成新文件 → 拿到新 URL，旧 URL 永远指向旧内容。所以：

- ✅ 改图 = 重新跑一次 `add-image.sh`，拿**新 URL**
- ❌ 不要直接覆盖 `images/` 里的已有文件（`verify.py` 会报「哈希不符」）
- ❌ 不要重命名/移动已发布的图片，会打碎别人文档里的链接

如果确实需要「一个固定 URL 指向最新图」，另开一个不带哈希的别名文件并接受缓存延迟，不要动哈希文件。

## 限制（GitHub 图床的硬边界）

| 项 | 值 | 说明 |
|---|---|---|
| 单文件 | 100 MB 硬上限 | 超过 GitHub 直接拒绝推送；>50 MB 会警告 |
| 单文件建议 | < 20 MB | jsDelivr `/gh/` 对大文件有限制，超了改用 `raw` 或对象存储 |
| 仓库总量建议 | < 1 GB | 超过后 clone 变慢，且历史不可压缩 |
| 支持格式 | png / jpg / jpeg / gif / webp / avif / svg / ico / bmp | `add-image.sh` 白名单 |

图床只适合**文档配图、图标、截图这类小图**。视频、设计源文件、原始照片请走对象存储，别塞进 Git。仓库接近 1 GB 时应当迁移，而不是继续加图。

## 目录

```
bin/add-image.sh   上传一张图（内容哈希命名 + 提交 + 可选 push + 打印 URL）
bin/verify.py      体检：命名规范 / 哈希一致 / 重复图 / 体积上限
images/YYYY/MM/    图片实体，按月分目录，永不覆盖
```

## 可选：PicGo 对接

本仓按内容哈希命名，PicGo 默认的「时间戳命名」会破坏这个约定（同名不同内容、缓存不刷新）。
如果用 PicGo，请配置自定义文件名格式为 `<slug>-<sha12>` 的等价实现，或直接用 `bin/add-image.sh`。
仓库 token 不要写进任何配置文件 —— 本仓 `.gitignore` 已排除 `.env*` 与密钥文件。
