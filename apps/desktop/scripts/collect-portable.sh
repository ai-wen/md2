#!/usr/bin/env bash
# Collects the md2 desktop .app bundle (built with `tauri build --bundles app`)
# into a portable ("green") macOS zip for offline distribution - no installer:
# unzip, drag md2.app anywhere (e.g. /Applications) and run. The frontend is
# embedded in the binary. The only caveat is Gatekeeper on first open (the
# README.txt shipped in the zip explains right-click -> Open / xattr -cr).
#
# Usage: collect-portable.sh [rust-target-triple]
#   (omit the argument for a native build; e.g. universal-apple-darwin for a
#    Universal 2 binary covering both Apple Silicon and Intel)
#
# Output: portable/md2/  and  portable/md2-portable-macos-<arch>.zip
set -euo pipefail

target="${1:-}"
desktop_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
release_dir="$desktop_root/src-tauri/target${target:+/$target}/release"
out_root="$desktop_root/portable"
app_dir="$out_root/md2"

app="$(find "$release_dir/bundle/macos" -maxdepth 1 -type d -name '*.app' 2>/dev/null | head -n 1 || true)"
if [ -z "$app" ]; then
    echo "error: .app bundle not found in $release_dir/bundle/macos" >&2
    echo "       run 'pnpm --filter @md2/desktop portable:mac' (or 'tauri build --bundles app') first." >&2
    exit 1
fi

# Zip suffix: mirror the Windows portable naming (md2-portable-win-x64.zip).
case "$target" in
    "")                      arch="$(case "$(uname -m)" in arm64) echo arm64 ;; *) echo x64 ;; esac)" ;;
    aarch64-apple-darwin)    arch="arm64" ;;
    x86_64-apple-darwin)     arch="x64" ;;
    universal-apple-darwin)  arch="universal" ;;
    *)                       arch="$target" ;;
esac

if [ -d "$app_dir" ]; then rm -rf "$app_dir"; fi
mkdir -p "$app_dir"

# ditto (not cp -R) to preserve xattrs, permissions and the ad-hoc signature.
ditto "$app" "$app_dir/md2.app"

cat > "$app_dir/README.txt" <<'EOF'
md2 便携版 (macOS)
=====================

运行: 解压后将 md2.app 拖入「应用程序」文件夹（或直接双击运行）
要求: macOS 11 及以上（universal 版同时支持 Apple Silicon 与 Intel 芯片）

首次打开:
应用未做公证，首次打开可能被 Gatekeeper 拦截，任选其一解决:
1. 右键点击 md2.app -> 「打开」; 或在「系统设置 -> 隐私与安全性」中点击「仍要打开」
2. 终端执行: xattr -cr /path/to/md2.app

说明:
- 前端资源已内嵌于应用内, 无需安装, 解压即用
- 所有 Markdown 渲染均在本地完成
EOF

zip_path="$out_root/md2-portable-macos-$arch.zip"
if [ -f "$zip_path" ]; then rm -f "$zip_path"; fi
# --keepParent so the zip unpacks to md2/md2.app, mirroring the Windows zip.
# ditto -c -k is the Finder-equivalent zip that keeps macOS metadata intact.
(cd "$out_root" && ditto -c -k --keepParent md2 "md2-portable-macos-$arch.zip")

app_size="$(du -sm "$app_dir" | cut -f1)"
zip_size="$(( $(stat -f%z "$zip_path") / 1024 / 1024 ))"
echo "Portable folder : $app_dir  (${app_size} MB)"
echo "Offline zip     : $zip_path  (${zip_size} MB)"
