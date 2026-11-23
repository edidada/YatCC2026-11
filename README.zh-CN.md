# YatCC 2026-11 官方快照（中文说明）

> 本仓库是 `arcsysu/YatCC` 官方最新版（2026-11 抓取，提交 `85af090`）的镜像，只新增了 GitHub Actions CI 与 LLVM 构建参数适配，**未改动实验代码本身**。

## 版本对齐

- 源语言：`SYsU`（YatCC 自定义 int-only C 子集，测例 `.sysu.c`）与 task5 的 `SysY2022` 官方文法并存；与 2026 年华为毕昇杯使用的 `SysY2026` 语言的关系见同目录 `sysu.md`（在 YatCC 实验仓库）。
- task5 后端已从早期的 ARM 改为 **RV64**：`llvm/setup.sh` 构建 `X86;RISCV` 双目标，`test/task5/CMakeLists.txt` 使用 `riscv64-linux-gnu-g++` + `qemu-riscv64-static`。
- `task5_setup.sh` 是校内专用脚本（写死内网代理 `12.8.3.207:3138`、清华 apt 源、要求 root），CI 里未使用；CI 单独执行它其中的 TableGen 步骤生成 `RISCVGen*.inc`。

## 构建方法

依赖：LLVM 18.1.8（含 clang 与 X86/RISCV 目标）、ANTLR 4.13.2 C++ runtime、pybind11 2.13.6、Python3、bison/flex、riscv64 工具链。

```bash
# 依赖（各 setup.sh 装到自己的 install/）
export YatCC_LLVM_DIR=$PWD/llvm YatCC_ANTLR_DIR=$PWD/antlr YatCC_PYBIND11_DIR=$PWD/pybind11
./antlr/setup.sh
YATCC_LLVM_BUILD_TYPE=Release YATCC_LLVM_JOBS=2 ./llvm/setup.sh   # CI 小内存设置
./pybind11/setup.sh

# TableGen（task5 需要的两个 .inc）
/usr/lib/llvm-18/bin/llvm-tblgen -gen-register-info \
  -I $YatCC_LLVM_DIR/llvm/include -I $YatCC_LLVM_DIR/install/include \
  -I $YatCC_LLVM_DIR/llvm/lib/Target -I $YatCC_LLVM_DIR/llvm/lib/Target/RISCV \
  -o $YatCC_LLVM_DIR/task5/include/RISCVGenRegisterInfo.inc \
  $YatCC_LLVM_DIR/llvm/lib/Target/RISCV/RISCV.td
# 同理 -gen-instr-info -> RISCVGenInstrInfo.inc

cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j4
```

`llvm/setup.sh` 新增两个环境变量（默认值保持上游行为）：`YATCC_LLVM_BUILD_TYPE`（默认 Debug）、`YATCC_LLVM_JOBS`（默认 32）。CI 用 `Release + 2`，避免 hosted runner（约 7 GB 内存）被 32 路 Debug 编译拖垮。

## CI 状态

- GitHub Actions：`.github/workflows/cmake-single-platform.yml`，install deps → Configure → Build → score → git status。
  - 已修复：`qemu-user-static` 无 apt candidate（改用 `qemu-user-binfmt` 并软链 `/usr/bin/qemu-riscv64-static`）、GCC 15 与 LLVM 18 头文件不兼容（固定 gcc-14）、runner OOM（Release + 2 jobs）。
  - 状态：见仓库 Actions 页（run `44905407253` 为重跑）。
- Gitee 镜像：`https://gitee.com/edidada/YatCC2026-11`（`main` 分支，与 GitHub 同步）。
- 本地：按实验要求**不编译**；构建全部交给 CI。
