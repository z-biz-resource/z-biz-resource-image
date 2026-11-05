#!/usr/bin/env bash
# 把一张图片加入图床：内容哈希命名 → 永不覆盖 → 绕开 CDN 缓存。
# 用法见 README.md 或 ./bin/add-image.sh --help
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# 分发域名可覆盖：某些网络下 cdn.jsdelivr.net / raw.githubusercontent.com 不可达，
# 换成可达的 jsDelivr 节点即可（路径不变）。例：
#   IMAGE_CDN_HOST=gcore.jsdelivr.net ./bin/add-image.sh foo.png
CDN_HOST="${IMAGE_CDN_HOST:-cdn.jsdelivr.net}"
CDN_BASE="https://${CDN_HOST}/gh/z-biz-resource/z-biz-resource-image@main"
RAW_BASE="https://raw.githubusercontent.com/z-biz-resource/z-biz-resource-image/main"

usage() {
  cat <<'USAGE'
用法: bin/add-image.sh <图片路径> [--slug 名称] [--no-push]

  --slug NAME   自定义可读前缀（小写字母/数字/连字符，默认取原文件名）
  --no-push     只提交到本地，不 push（适合批量上传后一次推送）
  -h, --help    显示本帮助

示例: bin/add-image.sh ~/Desktop/arch.png --slug arch-overview
USAGE
}

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    echo "缺少 shasum / sha256sum" >&2; return 1
  fi
}

file_size() {
  stat -f%z "$1" 2>/dev/null || stat -c%s "$1"
}

print_urls() {
  local rel="$1" label="$2"
  printf '\n  CDN : %s/%s\n' "$CDN_BASE" "$rel"
  printf '  raw : %s/%s\n' "$RAW_BASE" "$rel"
  printf '  MD  : ![%s](%s/%s)\n\n' "$label" "$CDN_BASE" "$rel"
}

SRC=""; SLUG=""; NO_PUSH=0
while [ $# -gt 0 ]; do
  case "$1" in
    --slug)
      [ $# -ge 2 ] || { echo "--slug 需要参数" >&2; exit 2; }
      SLUG="$2"; shift 2 ;;
    --no-push) NO_PUSH=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "未知参数: $1" >&2; usage >&2; exit 2 ;;
    *)
      [ -z "$SRC" ] || { echo "一次只处理一张图片" >&2; exit 2; }
      SRC="$1"; shift ;;
  esac
done

[ -n "$SRC" ] || { usage >&2; exit 2; }
[ -f "$SRC" ] || { echo "文件不存在: $SRC" >&2; exit 1; }

ext="${SRC##*.}"
ext="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"
case "$ext" in
  png|jpg|jpeg|gif|webp|avif|svg|ico|bmp) ;;
  *)
    echo "不支持的格式: .$ext" >&2
    echo "允许: png jpg jpeg gif webp avif svg ico bmp" >&2
    exit 1 ;;
esac

size="$(file_size "$SRC")"
if [ "$size" -gt $((100 * 1024 * 1024)) ]; then
  echo "✗ 超过 GitHub 100MB 硬上限，拒绝上传" >&2
  exit 1
fi
if [ "$size" -gt $((20 * 1024 * 1024)) ]; then
  echo "⚠ 超过 20MB：jsDelivr 可能拒绝分发，请改用 raw 地址或对象存储" >&2
fi

if [ -n "$SLUG" ]; then
  slug="$(printf '%s' "$SLUG" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//')"
else
  base="$(basename "$SRC")"
  base="${base%.*}"
  slug="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//')"
  [ -n "$slug" ] || slug="img"
fi
[ -n "$slug" ] || { echo "--slug 必须含字母或数字" >&2; exit 2; }
slug="${slug:0:40}"
slug="$(printf '%s' "$slug" | sed 's/-*$//')"
[ -n "$slug" ] || slug="img"

hash="$(sha256_file "$SRC")"
hash="${hash:0:12}"

# 同一份内容换个 slug 再传，不应产生第二个文件（否则 verify 会判为重复图）。
existing="$(find images -type f -name "*-${hash}.${ext}" -print -quit 2>/dev/null || true)"
if [ -n "$existing" ]; then
  label="$(basename "$existing")"
  label="${label%.*}"
  echo "✓ 内容已存在（同一份图不重复入库），直接复用：$existing"
  print_urls "$existing" "$label"
  exit 0
fi

year="$(date +%Y)"; month="$(date +%m)"
dir="images/$year/$month"
mkdir -p "$dir"
name="$slug-$hash.$ext"
dest="$dir/$name"

if [ -f "$dest" ]; then
  echo "✓ 已存在（内容相同），直接复用 URL：$dest"
  print_urls "$dest" "$slug"
  exit 0
fi

cp -- "$SRC" "$dest" 2>/dev/null || cp "$SRC" "$dest"
git add -- "$dest"
git commit -q -m "image: add $name (${size} bytes)"
echo "✓ 已提交 $dest"

if [ "$NO_PUSH" -eq 1 ]; then
  echo "  (--no-push：记得稍后 git push origin main，URL 才会生效)"
else
  git push origin main >/dev/null
  echo "  push 完成"
fi

print_urls "$dest" "$slug"
