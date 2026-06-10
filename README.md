# CMSIS-Multi

基于 **CMSIS-Build** 的 ARM Cortex-M3 裸机示例项目，支持多编译器（GCC、Clang、ARMCC、IAR、GHS 等）。

## 项目结构

```
cmsis-multi/
├── main.c                        # 主程序
├── multi.csolution.yml           # 解决方案配置
├── multi.cproject.yml            # 项目配置
├── build.ps1                     # PowerShell 编译脚本
├── src/
│   └── syscalls.c                # newlib syscall 桩函数（仅 GCC）
├── tools/
│   ├── clang-wrapper.sh          # Clang 包装脚本（修复 LLVM picolibc multilib 兼容性）
│   └── clang-bin/                # 指向 clang-wrapper.sh 的符号链接
├── RTE/                          # csolution update-rte 自动生成（编译时）
│   ├── RTE_Components.h          # RTE 组件配置
│   └── Device/ARMCM3/
│       ├── startup_ARMCM3.c      # 启动文件（向量表 + Reset_Handler）
│       ├── system_ARMCM3.c       # 系统初始化
│       ├── ARMCM3_gcc.ld         # GCC 链接脚本
│       ├── clang_linker_script.ld.src  # LLVM 链接脚本模板
│       └── regions_ARMCM3.h      # 内存区域定义
├── out/                          # 编译产物目录
│   └── multi/MyBoard/
│       ├── Debug/                # GCC Debug
│       │   └── multi.elf
│       ├── Release/              # GCC Release
│       │   └── multi.elf
│       ├── Debug-LLVM/           # Clang Debug
│       │   └── multi.elf
│       └── Release-LLVM/         # Clang Release
│           └── multi.elf
└── tmp/                          # 临时构建文件
```

## 环境要求

| 工具 | 版本 | 说明 |
|------|------|------|
| [CMSIS-Toolbox](https://github.com/Open-CMSIS-Pack/cmsis-toolbox) | ≥ 2.0 | 包含 `cbuild`、`cpackget`、`csolution` |
| [ARM GCC](https://developer.arm.com/Tools%20and%20Software/GNU%20Toolchain) | ≥ 10.3 | `arm-none-eabi-gcc` 交叉编译器 |
| [LLVM Embedded Arm](https://github.com/ARM-software/LLVM-embedded-toolchain-for-Arm) | ≥ 19.0 | `clang` 交叉编译器（可选） |
| CMake | ≥ 3.22 | 构建系统生成器 |
| Ninja | ≥ 1.10 | 构建执行引擎 |
| PowerShell | ≥ 7.0 | 编译脚本运行环境 |

### 安装 CMSIS-Toolbox

```bash
# 方式一：apt 安装 (Ubuntu/Debian)
sudo apt install cmsis-toolbox

# 方式二：手动下载安装
# https://github.com/Open-CMSIS-Pack/cmsis-toolbox/releases
```

### 安装 ARM GCC

```bash
# Ubuntu/Debian
sudo apt install gcc-arm-none-eabi

# 或从 ARM 官网下载：
# https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads
```

### 安装 LLVM/Clang（可选）

```bash
# 下载 ARM LLVM Embedded Toolchain
# https://github.com/ARM-software/LLVM-embedded-toolchain-for-Arm/releases

# 解压后设置环境变量 (在 build.ps1 中已配置)
export CLANG_TOOLCHAIN_19_1_5=/path/to/LLVM-ET-Arm-19.1.5-Linux-x86_64/bin
```

## 快速开始

### 1. 安装 CMSIS Pack

```bash
# 初始化 Pack 根目录并安装所需包
cpackget init https://www.keil.com/pack/index.pidx
cpackget add ARM::CMSIS
cpackget add ARM::Cortex_DFP
```

### 2. 编译项目

**使用 PowerShell 脚本（推荐）：**

```powershell
# 编译 Debug + Release
.\build.ps1

# 仅编译 Debug
.\build.ps1 -Type Debug

# 仅编译 Release
.\build.ps1 -Type Release

# 清理并重新编译
.\build.ps1 -Rebuild

# 仅清理
.\build.ps1 -Clean
```

**使用 LLVM/Clang 编译：**

```powershell
# 仅编译 LLVM Debug
.\build.ps1 -Type Debug-LLVM

# 仅编译 LLVM Release
.\build.ps1 -Type Release-LLVM
```

**直接使用 cbuild（LLVM 需要先执行 `csolution update-rte`）：**

```bash
export CMSIS_PACK_ROOT=/home/yuan/.cache/arm/packs
export GCC_TOOLCHAIN_13_2_1=/usr/bin
export CLANG_TOOLCHAIN_19_1_5=/home/yuan/Agent/cmsis-multi/tools/clang-bin

# 先更新 RTE（删除 RTE 后恢复）
csolution update-rte multi.csolution.yml -c multi.Debug+MyBoard

# 编译 Debug (GCC)
cbuild multi.csolution.yml --context-set -c "multi.Debug+MyBoard"

# 编译 LLVM Debug
csolution update-rte multi.csolution.yml -c multi.Debug-LLVM+MyBoard
cbuild multi.csolution.yml --context-set -c "multi.Debug-LLVM+MyBoard"
```

## 编译产物

编译成功后，ELF 文件位于 `out/` 目录：

| 构建类型 | 编译器 | 输出文件 | 典型大小 |
|---------|--------|---------|---------|
| **Debug** | GCC | `out/multi/MyBoard/Debug/multi.elf` | ~173 KB |
| **Release** | GCC | `out/multi/MyBoard/Release/multi.elf` | ~99 KB |
| **Debug-LLVM** | Clang | `out/multi/MyBoard/Debug-LLVM/multi.elf` | ~175 KB |
| **Release-LLVM** | Clang | `out/multi/MyBoard/Release-LLVM/multi.elf` | ~100 KB |

查看各段大小：

```bash
arm-none-eabi-size out/multi/MyBoard/Debug/multi.elf
```

## 配置说明

### 目标设备

- **MCU**: ARM Cortex-M3 (ARMCM3)
- **ROM**: 0x00000000 - 0x00040000 (256 KB)
- **RAM**: 0x20000000 - 0x00020000 (128 KB)

### 构建类型

| 类型 | 编译器 | 优化级别 | 调试信息 |
|------|--------|---------|---------|
| **Debug** | GCC | `-O0` (无优化) | `-g3` (完整调试信息) |
| **Release** | GCC | `-O2` (平衡优化) | `-g0` (无调试信息) |
| **Debug-LLVM** | Clang | `-O0` (无优化) | `-g3` (完整调试信息) |
| **Release-LLVM** | Clang | `-O2` (平衡优化) | `-g0` (无调试信息) |

### 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `CMSIS_PACK_ROOT` | `/home/yuan/.cache/arm/packs` | CMSIS Pack 安装目录 |
| `GCC_TOOLCHAIN_13_2_1` | `/usr/bin` | ARM GCC 工具链路径（版本号根据实际调整） |
| `CLANG_TOOLCHAIN_19_1_5` | `/home/yuan/Agent/cmsis-multi/tools/clang-bin` | LLVM/Clang 工具链包装路径（用于修复 picolibc multilib 兼容性） |




## 关键文件说明

### `main.c`
主程序入口，包含一个简单的无限循环。

### `multi.csolution.yml`
解决方案级配置文件，定义目标设备、构建类型、pack 依赖和项目引用。

### `multi.cproject.yml`
项目级配置文件，定义源文件分组和组件依赖。

### `RTE/RTE_Components.h`
运行时环境组件配置头文件，定义设备头文件引用。

### `startup_ARMCM3.c`
启动文件，包含向量表和复位处理程序。已添加 GCC 和 Clang 编译器的诊断抑制兼容代码。

### `src/syscalls.c`
newlib 系统调用桩函数实现（仅 GCC），提供裸机环境下必要的 syscall stub：
- `_exit()` — 退出程序
- `_sbrk()` — 堆内存管理
- `_write()` / `_read()` — I/O 操作
- `_close()` / `_lseek()` — 文件操作

Clang/LLVM (picolibc) 使用其内置 syscall 实现，编译时通过 `#if !defined(__clang__)` 跳过此文件。

## 支持的编译器

| 编译器 | 环境变量 | 构建类型 |
|--------|---------|---------|
| ARM GCC | `GCC_TOOLCHAIN_xx_x_x` | `Debug`, `Release` |
| LLVM/Clang | `CLANG_TOOLCHAIN_xx_x_x` | `Debug-LLVM`, `Release-LLVM` |

CMSIS-Build 支持更多编译器（ARMCC、IAR、GHS），可通过添加相应的 `build-types` 配置和工具链环境变量来扩展。
