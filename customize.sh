#!/system/bin/sh
# disable-greezer 安装脚本
# 由模块安装器 (KernelSU/Magisk) source 执行, 提供 ui_print 函数
# 用途: 立即写入禁用属性, 并提示重启

ui_print "[disable-greezer] 开始安装..."

# zip 解压可能丢 +x, 确保脚本可执行 (KernelSU 直接执行 service.sh/post-fs-data.sh)
chmod 0755 "$MODPATH"/*.sh 2>/dev/null

setprop persist.sys.powmillet.enable false
if getprop persist.sys.powmillet.enable 2>/dev/null | grep -q false; then
    ui_print "[disable-greezer] 已写入 persist.sys.powmillet.enable=false"
else
    ui_print "[disable-greezer] 警告: 属性写入失败"
fi

ui_print "[disable-greezer] 安装完成"
ui_print "[disable-greezer] 当前会话需重启一次生效; 之后每次开机自动生效"
