#!/system/bin/sh
# disable-greezer: 开机后验证 Greezer 状态并更新模块描述
# KernelSU/Magisk 在 late_start service 阶段执行, 无参数
# 描述双写: ksud override.description (KernelSU Manager) + 改 module.prop 的 description 行 (ResukiSU 等直接读文件)
# 注意: 一律用 sh 调用, 不依赖可执行位 (安装后脚本可能没有 +x)

MODDIR=$(cd "${0%/*}" && pwd)
[ -f "$MODDIR/module.prop" ] || MODDIR=/data/adb/modules/disable-greezer

# 再次确保属性为 false (模块开关关闭时本脚本不执行, 属性保持上次写入值)
setprop persist.sys.powmillet.enable false

# 检测 Greezer 实际状态: dumpsys greezer 输出 Settings: enable=true/false (读 persist.sys.powmillet.enable)
if dumpsys greezer 2>/dev/null | grep -q 'enable=false'; then
    DESC="已禁用 Greezer 后台冻结（本次开机生效）"
elif getprop persist.sys.powmillet.enable 2>/dev/null | grep -q false; then
    DESC="已禁用 Greezer 后台冻结（需重启一次生效）"
else
    DESC="Greezer 禁用失败（属性写入异常）"
fi

# 双写描述
sed -i "s/^description=.*/description=$DESC/" "$MODDIR/module.prop"
if command -v ksud >/dev/null 2>&1; then
    KSU_MODULE=disable-greezer ksud module config set override.description "$DESC" 2>/dev/null
fi

exit 0
