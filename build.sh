#!/bin/bash
# disable-greezer 打包脚本: 生成 KernelSU/Magisk 可刷入的 zip
set -eu
cd "$(dirname "$0")"

VERSION=$(grep '^version=' module.prop | cut -d= -f2)
ZIP="disable-greezer-v${VERSION}.zip"

rm -f "$ZIP"
zip -q -9 "$ZIP" module.prop customize.sh post-fs-data.sh service.sh action.sh

echo "已生成: $ZIP"
unzip -l "$ZIP" | tail -8
