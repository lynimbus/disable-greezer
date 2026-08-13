#!/system/bin/sh
# disable-greezer: 开机早期禁用小米 Greezer 后台冻结
# 时机: KernelSU/Magisk 在 Zygote 启动前执行 post-fs-data.sh,
#       此时写入的属性会被稍后启动的 system_server 读取,
#       Greezer 服务 (system_server 内) 启动时即读到 enable=false, 本次开机生效
# 机制: dumpsys greezer 的 Settings.enable 读 persist.sys.powmillet.enable (persist 属性, 重启保留)
# 副作用: 全局关闭 Greezer 冻结, 后台应用不再被冻结 (省电略降, 换取推送可靠)

setprop persist.sys.powmillet.enable false

exit 0
