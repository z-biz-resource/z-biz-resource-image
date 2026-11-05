#!/usr/bin/env python3
"""图床体检：命名规范 / 内容哈希一致 / 重复图 / 体积上限。

规则与 bin/add-image.sh 保持一致：images/YYYY/MM/<slug>-<sha12>.<ext>
哈希不符通常意味着有人覆盖了已发布的图片 —— 这会打碎 CDN 缓存语义。
"""
from __future__ import annotations

import hashlib
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
IMAGES = ROOT / "images"
NAME_RE = re.compile(
    r"^[a-z0-9]+(?:-[a-z0-9]+)*-([0-9a-f]{12})\."
    r"(png|jpg|jpeg|gif|webp|avif|svg|ico|bmp)$"
)
PATH_RE = re.compile(r"^\d{4}/\d{2}/[^/]+$")
WARN_20MB = 20 * 1024 * 1024
HARD_100MB = 100 * 1024 * 1024


def main() -> int:
    if not IMAGES.is_dir():
        print("✗ 缺少 images/ 目录")
        return 1

    issues: list[str] = []
    by_hash: dict[str, list[str]] = defaultdict(list)
    count = 0
    total = 0

    for path in sorted(IMAGES.rglob("*")):
        if not path.is_file() or path.name == ".gitkeep":
            continue
        rel = path.relative_to(IMAGES).as_posix()
        count += 1
        size = path.stat().st_size
        total += size

        if not PATH_RE.match(rel):
            issues.append(f"目录不规范（应为 images/YYYY/MM/）: {rel}")

        m = NAME_RE.match(path.name)
        if not m:
            issues.append(f"命名不规范（应为 <slug>-<sha12>.<ext>）: {rel}")
        else:
            digest = hashlib.sha256(path.read_bytes()).hexdigest()[:12]
            if digest != m.group(1):
                issues.append(
                    f"哈希不符（文件被改动/覆盖过）: {rel} 期望 {m.group(1)} 实际 {digest}"
                )
            by_hash[digest].append(rel)

        if size > HARD_100MB:
            issues.append(f"超过 GitHub 100MB 硬上限: {rel} ({size / 1048576:.1f} MB)")
        elif size > WARN_20MB:
            issues.append(f"超过 20MB（jsDelivr 可能拒绝分发）: {rel} ({size / 1048576:.1f} MB)")

    for digest, paths in by_hash.items():
        if len(paths) > 1:
            issues.append(f"重复图片（内容相同 {digest}）: {', '.join(paths)}")

    print(f"图片 {count} 张，合计 {total / 1048576:.2f} MiB")
    if issues:
        print(f"\n发现 {len(issues)} 个问题：")
        for item in issues:
            print(f"  ✗ {item}")
        return 1
    print("✓ 全部可复现：命名、哈希、目录、体积均合规，无重复图")
    return 0


if __name__ == "__main__":
    sys.exit(main())
