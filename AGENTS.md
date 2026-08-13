# AGENTS.md

KernelSU/Magisk 模块：禁用小米 HyperOS 的 Greezer 后台冻结，解决透明代理场景下应用收不到通知的问题。

## 背景（2026-08-13 真机诊断）

用户 sing-box-init 模块（ebpf 透明代理）下，NagramX 后台收不到通知，点开才刷新。诊断链条：

1. gms FCM 连接退化到 35.8h 退避（已单独修复：force-stop gms）
2. **根本问题**：小米 Greezer 冻结后台进程，且与透明代理不兼容：
   - 走代理的应用流量是本地回环（`127.x:38601`），Greezer 的 PACKET 唤醒只认公网包 → 消息堆积 Recv-Q 却不解冻
   - `Greezer Denial` 拒绝向冻结进程投递 FCM 广播（c2dm RECEIVE）
   - 解冻仅发生在 Activity Start/Front（用户点开 App）
3. `persist.sys.powmillet.enable` 是 Greezer 总开关（dumpsys greezer 的 Settings.enable）

## 架构

- `post-fs-data.sh` — **核心**：Zygote 启动前 `setprop persist.sys.powmillet.enable false`，system_server 启动时 Greezer 读到 false → 本次开机生效（persist 属性重启保留，无需每次设置）
- `service.sh` — boot_completed 后验证状态 + **双写描述**（ksud override.description + 改 module.prop description 行，ResukiSU 等 Manager 直接读文件）
- `action.sh` — Action 按钮：查看状态 + `cmd greezer thaw` 立即解冻（缓解安装后未重启的窗口期）
- `customize.sh` — 安装时立即写入属性 + 提示重启

## 关键事实（真机验证）

- **setprop 后 greezer 服务不实时重读属性**：enable 是启动时缓存，当前会话改不了，必须重启
- `powerkeeper` 数据库的 `bgControl=no_restrict`（"无限制"省电策略）**拦不住 Greezer**（21:02/21:05 实测仍被 LM FZ 冻结）——别走这条路
- `cmd greezer thuid <uid>` 语法在 HyperOS 上报 `Argument expected after <uid>`，不可用；`cmd greezer thaw` 可用
- Greezer 冻结原因分类：`quick freeze`（低内存快速冻）、`LM FZ`（低内存批量冻）、`IM Game FZ`（游戏模式批量冻）；解冻原因：`Activity Start/Front`、`PACKET`（公网数据包）、`Excute Service`
- `cached_apps_freezer=disabled`（标准 App Freezer 已关），`do_freezer_trap` 状态即 Greezer 冻结
- 非小米设备无 greezer 服务，setprop 无害

## 坑与速查

- 脚本由 KernelSU/Magisk 的 BusyBox ash 执行：纯 POSIX sh，无 bash 语法
- 取模块目录 `MODDIR=$(cd "${0%/*}" && pwd)` + module.prop 存在性兜底
- 描述双写顺序：先 sed 改 module.prop，再 `KSU_MODULE=disable-greezer ksud module config set override.description "$DESC"`（ksud 先 `command -v` 查 PATH）
- 卸载后属性残留 false：README 写清楚恢复命令 `setprop persist.sys.powmillet.enable true`
- 模块禁用（Manager 开关）后脚本不执行，属性保持上次值——恢复 Greezer 需手动 setprop

## 本机验证

```sh
sh -n *.sh                 # 语法检查（纯 POSIX）
sh test_local.sh           # mock 环境跑 service.sh 逻辑
```

真机验证：`adb shell "su -c 'dumpsys greezer | head -3'"` 看 enable=false；切后台发消息看通知。

## 构建

无需编译，直接 zip 打包 4 个脚本 + module.prop 即可（保持脚本无 +x 依赖，一律 `sh xxx.sh` 调用）。
