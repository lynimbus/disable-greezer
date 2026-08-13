#!/bin/bash
# disable-greezer 本机端到端测试
# 1. 语法检查所有 shell 脚本 (纯 POSIX)
# 2. mock Android 命令, 跑 service.sh / post-fs-data.sh 逻辑, 验证行为
set -u
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"
PASS=0; FAIL=0

ok()   { PASS=$((PASS+1)); echo "  ✓ $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  ✗ $1"; }

echo "== 1. 语法检查 =="
for f in post-fs-data.sh service.sh action.sh customize.sh; do
    if sh -n "$f" 2>/dev/null; then ok "$f"; else bad "$f 语法错误"; fi
done

echo "== 2. mock 环境跑 service.sh =="

# 参数: 场景名 dumpsys 输出(多行) getprop 输出
run_scenario() {
    local name="$1" dumpsys_out="$2" getprop_out="$3"
    local workdir; workdir=$(mktemp -d)
    local bin; bin=$(mktemp -d)
    # 复制 service.sh + module.prop 到隔离目录跑, 避免 MODDIR 解析污染仓库文件
    cp "$SCRIPT_DIR/service.sh" "$workdir/service.sh"
    cp "$SCRIPT_DIR/module.prop" "$workdir/module.prop"

    cat > "$bin/getprop" <<EOF
#!/bin/bash
echo "$getprop_out"
EOF
    cat > "$bin/setprop" <<EOF
#!/bin/bash
exit 0
EOF
    cat > "$bin/dumpsys" <<EOF
#!/bin/bash
printf '%s\n' "$dumpsys_out"
EOF
    cat > "$bin/command" <<EOF
#!/bin/bash
exit 0
EOF
    cat > "$bin/ksud" <<EOF
#!/bin/bash
echo "ksud: \$*" >> "$bin/ksud.log"
exit 0
EOF
    chmod +x "$bin"/*

    # 用 mock PATH 跑 service.sh (绝对路径, 不依赖 OLDPWD)
    ( cd "$workdir" && PATH="$bin:$PATH" sh "$workdir/service.sh" ) >/dev/null 2>&1
    local desc; desc=$(grep '^description=' "$workdir/module.prop")
    local ksudlog=""
    [ -f "$bin/ksud.log" ] && ksudlog=$(cat "$bin/ksud.log")

    case "$name" in
        "greezer已禁用")
            echo "$desc" | grep -q "本次开机生效" && ok "描述=$desc" || bad "场景1 描述错误: $desc"
            [ -n "$ksudlog" ] && ok "ksud 双写: $ksudlog" || bad "场景1 ksud 未调用"
            ;;
        "需重启生效")
            echo "$desc" | grep -q "需重启一次生效" && ok "描述=$desc" || bad "场景2 描述错误: $desc"
            ;;
        "禁用失败")
            echo "$desc" | grep -q "禁用失败" && ok "描述=$desc" || bad "场景3 描述错误: $desc"
            ;;
    esac
    rm -rf "$workdir" "$bin"
}

echo "  场景1: greezer 已禁用 (dumpsys 显示 enable=false)"
run_scenario "greezer已禁用" $'Settings:\n  enable=false (persist.sys.powmillet.enable)' "false"

echo "  场景2: 属性已写但当前会话 greezer 缓存 true (需重启)"
run_scenario "需重启生效" $'Settings:\n  enable=true (persist.sys.powmillet.enable)' "false"

echo "  场景3: 属性写入失败"
run_scenario "禁用失败" $'Settings:\n  enable=true (persist.sys.powmillet.enable)' "true"

echo "== 3. post-fs-data.sh 逻辑 =="
bin=$(mktemp -d)
cat > "$bin/setprop" <<EOF
#!/bin/bash
echo "setprop: \$*" >> "$bin/setprop.log"
[ "\$1" = "persist.sys.powmillet.enable" ] && [ "\$2" = "false" ]
EOF
chmod +x "$bin/setprop"
PATH="$bin:$PATH" sh post-fs-data.sh >/dev/null 2>&1
if grep -q "persist.sys.powmillet.enable false" "$bin/setprop.log"; then
    ok "post-fs-data 写入 persist.sys.powmillet.enable false"
else
    bad "post-fs-data 未正确调用 setprop: $(cat "$bin/setprop.log" 2>/dev/null)"
fi
rm -rf "$bin"

echo ""
echo "结果: $PASS 通过, $FAIL 失败"
[ "$FAIL" -eq 0 ]
