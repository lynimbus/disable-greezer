# disable-greezer

KernelSU/Magisk 模块：禁用小米 HyperOS 的 **Greezer**（内存冻结器）后台冻结机制。

## 为什么需要

小米 HyperOS 的 Greezer 会冻结后台进程以省电，但它与透明代理（sing-box/tproxy）存在两个不兼容行为：

1. **回环数据包不触发唤醒**：走代理的应用，网络流量是本地回环（`127.x:38601`），Greezer 的"收到网络包自动解冻"（`PACKET caller:1000`）**只认公网数据包** → 消息到达后堆积在 socket 缓冲却不解冻进程 → 通知永不弹出
2. **拒绝向冻结进程投递广播**：FCM 推送（`com.google.android.c2dm.intent.RECEIVE`）也会被 `Greezer Denial` 拦截

**表现**：Telegram 等应用后台收不到通知，打开 App 才刷新（进程被 Activity Start 解冻后处理堆积消息）。

**真机验证**（Redmi K70 Pro / HyperOS）：走代理的 `fork.risin42.nagramx` 的 Greezer 解冻原因只有 `Activity Start/Front`，无任何 `PACKET` 解冻；gms 投递 c2dm 广播被 `Greezer Denial` 拒绝。

## 原理

`persist.sys.powmillet.enable` 是 Greezer 总开关（`dumpsys greezer` 的 `Settings.enable` 读取它）。

| 文件 | 时机 | 作用 |
|---|---|---|
| `post-fs-data.sh` | Zygote 启动前 | 写入 `persist.sys.powmillet.enable=false`，system_server 启动时 Greezer 读到 false → **本次开机即生效** |
| `service.sh` | boot_completed 后 | 再次确保属性 + 验证状态，双写模块描述（ksud override.description + module.prop） |
| `action.sh` | Action 按钮 | 查看状态 + `cmd greezer thaw` 立即解冻当前已冻结进程（缓解安装后未重启的窗口期） |
| `customize.sh` | 安装时 | 立即写入属性 + 提示重启 |

`persist.` 属性写入 persist 分区，**重启后保留**。

## 安装

刷入 zip 后**重启一次**（当前会话的 system_server 已缓存旧值，post-fs-data 只影响下次开机）。

## 验证

```sh
adb shell "su -c 'dumpsys greezer | head -3'"   # Settings: enable=false
```

NagramX/Telegram 切后台，从另一账号发消息 → 通知应立即弹出。

## 卸载 / 恢复

卸载模块后属性仍是 `false`（persist 保留）。需要恢复 Greezer：

```sh
adb shell "su -c 'setprop persist.sys.powmillet.enable true'"
```

## 影响

- 全局关闭 Greezer 冻结：后台应用不再被冻结（省电略降），换取推送/后台任务可靠
- 内存管理仍由 Android 标准机制（lmkd）负责，不会失控
- 非小米设备无 greezer 服务，脚本无害（setprop 空属性）

## 兼容性

- KernelSU / Magisk / APatch 均支持（标准 `post-fs-data.sh` + `service.sh`）
- 纯 POSIX sh（busybox ash），无 bash 依赖
