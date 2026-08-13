#!/system/bin/sh
# disable-greezer action.sh: Action 按钮 = 查看状态 + 立即解冻已冻结进程
# KernelSU Manager 每次点击 Action 执行本脚本, stdout 输出显示在模块日志
# 注意: 一律用 sh 调用, 不依赖可执行位

MODDIR=$(cd "${0%/*}" && pwd)
[ -f "$MODDIR/module.prop" ] || MODDIR=/data/adb/modules/disable-greezer

# 确保属性 (安装后未重启的窗口期内, post-fs-data 尚未生效)
setprop persist.sys.powmillet.enable false

# 立即解冻当前会话已冻结的进程, 缓解安装后未重启的窗口期
if command -v cmd >/dev/null 2>&1; then
    cmd greezer thaw 2>/dev/null
fi

# 输出状态
if dumpsys greezer 2>/dev/null | grep -q 'enable=false'; then
    echo "[disable-greezer] Greezer 已禁用 (enable=false)"
else
    echo "[disable-greezer] Greezer 仍启用, 属性已写入, 重启后生效"
fi

exit 0
