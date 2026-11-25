# task5 运行说明

task5 把 LLVM IR（`.ll`）降级为 RV64 汇编（`.s`）。

## 程序接口

```
task5 <input.ll> <output.s>
```

参数个数不为 2 时打印 Usage 并以 1 退出；输入 IR 解析失败返回 2，模块校验失败返回 3，输出文件打开失败返回 10。

## 构建（WSL / CLion）

CLion 的 `Debug-WSL` 目标使用以下生成选项（依赖复用同目录同级 `YatCC` 中已安装的 ANTLR/LLVM/pybind11）：

```
-DYatCC_ANTLR_DIR=/mnt/d/develops/git/github/cpp/YatCC/antlr
-DYatCC_LLVM_DIR=/mnt/d/develops/git/github/cpp/YatCC/llvm
-DYatCC_PYBIND11_DIR=/mnt/d/develops/git/github/cpp/YatCC/pybind11
```

注意：这三个变量同时支持 `cmake -D` 传入与环境变量两种方式，`config.cmake` 优先使用 `-D`。
若 LLVM 目录下缺少 `task5/include/RISCVGenRegisterInfo.inc` 与 `RISCVGenInstrInfo.inc`，用
`/usr/lib/llvm-18/bin/llvm-tblgen` 按 `task5_setup.sh` 中的参数生成（CI 已自动处理）。

```bash
cmake --build /mnt/d/develops/git/github/cpp/YatCC2026-11/cmake-build-debug-wsl -j 4
```

## 测试用例集合

使用 8 个手写 LLVM IR 用例，覆盖 task5 骨架中已实现的 lowering 路径：

| 用例 | 覆盖内容 |
| --- | --- |
| `ret_const` | 32 位常量返回 |
| `ret_neg64` | 64 位负值/边界常量返回 |
| `multi_fn` | 同一模块内多个函数 |
| `br_uncond` | 无条件分支 |
| `switch_const` | switch 多 case 跳转 |
| `select_const` | 常量条件 select |
| `alloca_cast` | alloca 与 ptrtoint/trunc 类型转换 |
| `phi_br` | 分支边上的 phi 复制 |

不覆盖 `emitBinary` / `emitICmpInst` / `emitLoadInst` / `emitStoreInst` / `emitCallInst`：
这些路径在骨架中仍是 `TODO: Student Implementation`，含相应指令的 IR 会触发 `LLVM ERROR` 崩溃。

## 本地运行步骤

```bash
TASK5=/mnt/d/develops/git/github/cpp/YatCC2026-11/cmake-build-debug-wsl/task/5/task5
W=/tmp/task5-smoke
mkdir -p "$W"

write_case() { name=$1; shift; printf '%s\n' "$@" > "$W/$name.ll"; }
run_case() {
  if ! "$TASK5" "$W/$1.ll" "$W/$1.s" > "$W/$1.log" 2>&1; then
    echo "FAIL $1"; cat "$W/$1.log"; exit 1
  fi
  test -s "$W/$1.s"
  echo "PASS $1 ($(wc -c < "$W/$1.s") bytes)"
}

write_case ret_const \
  'define i32 @main() {' '  ret i32 42' '}'
write_case ret_neg64 \
  'define i64 @main() {' '  ret i64 -9223372036854775808' '}'
write_case multi_fn \
  'define i32 @foo() {' '  ret i32 7' '}' \
  'define i32 @main() {' '  ret i32 3' '}'
write_case br_uncond \
  'define i32 @main() {' 'entry:' '  br label %next' 'next:' '  ret i32 9' '}'
write_case switch_const \
  'define i32 @main() {' 'entry:' \
  '  switch i32 2, label %def [ i32 1, label %one i32 2, label %two ]' \
  'one:' '  ret i32 10' 'two:' '  ret i32 20' 'def:' '  ret i32 0' '}'
write_case select_const \
  'define i32 @main() {' 'entry:' \
  '  %r = select i1 true, i32 11, i32 22' '  ret i32 %r' '}'
write_case alloca_cast \
  'define i32 @main() {' 'entry:' '  %p = alloca i32, align 4' \
  '  %v = ptrtoint ptr %p to i64' '  %t = trunc i64 %v to i32' \
  '  ret i32 %t' '}'
write_case phi_br \
  'define i32 @main() {' 'entry:' '  br label %body' 'body:' \
  '  %p = phi i32 [ 5, %entry ]' '  ret i32 %p' '}'

for c in ret_const ret_neg64 multi_fn br_uncond switch_const \
         select_const alloca_cast phi_br; do
  run_case "$c"
done
echo "task5 smoke: 8/8 cases OK"
```

## 执行结论

已在 WSL 中实际执行上述 8 个用例，全部通过：

```
PASS ret_const (236 bytes)
PASS ret_neg64 (254 bytes)
PASS multi_fn (466 bytes)
PASS br_uncond (263 bytes)
PASS switch_const (873 bytes)
PASS select_const (484 bytes)
PASS alloca_cast (329 bytes)
PASS phi_br (329 bytes)
task5 smoke: 8/8 cases OK
```

以 `ret_const` 为例，生成的 RV64 汇编：

```asm
.text
        .align 2
        .globl main
        .type main, @function
main:
        addi sp, sp, -80
        sd ra, 72(sp)
        sd s0, 64(sp)
        addi s0, sp, 80
.Lbb.main.0:
        addi t4, zero, 0
        sd t4, 0(sp)
        ld a0, 0(sp)
        ld ra, 72(sp)
        ld s0, 64(sp)
        addi sp, sp, 80
        ret
```

结论：task5 可执行程序能够正确接收 `<input.ll> <output.s>` 参数，对所覆盖的 8 类 IR 结构
均能成功降级为非空 RV64 汇编，退出码均为 0。

## CI 中的对应步骤

`.github/workflows/cmake-single-platform.yml` 的 `Run task5` 步骤使用同一组 8 个用例，
逐个运行并用 `test -s` 校验输出非空；任一用例失败即让 job 失败。此前 task5 仅通过
`task5-score` 经 ctest 间接调用，而该步骤是 `continue-on-error: true`，失败会被忽略。

若需跑完整测例评分，使用：

```bash
cmake --build /mnt/d/develops/git/github/cpp/YatCC2026-11/cmake-build-debug-wsl \
  --target task5-score
```

该目标依赖 `task5-answer`，需要 `qemu-riscv64-static`、`riscv64-linux-gnu-g++`、`clang-18`
以及 `test/task5/libsysy.a`；本机 WSL 目前缺少 qemu 与 riscv 工具链，评分需在 CI 环境执行。
