# CMSIS-Multi

基于 **CMSIS-Build** 的 ARM Cortex-M3 裸机示例项目，支持多编译器（GCC、Clang、ARMCC、IAR、GHS 等）。

## 项目结构

```
cmsis-multi/
├── main.c                        # 主程序
├── multi.csolution.yml           # 解决方案配置
├── multi.cproject.yml            # 项目配置
├── build.ps1                     # PowerShell 编译脚本
├── RTE/
│   ├── RTE_Components.h          # RTE 组件配置
│   └── Device/
│       └── ARMCM3/
│           ├── syscalls.c        # newlib syscall 桩函数
│           ├── gcc_linker_script.ld.src  # GCC 链接脚本模板
│           └── regions_ARMCM3.h  # 内存区域定义
├── out/                          # 编译产物目录
│   └── multi/
│       └── MyBoard/
│           ├── Debug/
│           │   └── multi.elf
│           └── Release/
│               └── multi.elf
└── tmp/                          # 临时构建文件
```

## 环境要求

| 工具 | 版本 | 说明 |
|------|------|------|
| [CMSIS-Toolbox](https://github.com/Open-CMSIS-Pack/cmsis-toolbox) | ≥ 2.0 | 包含 `cbuild`、`cpackget`、`csolution` |
| [ARM GCC](https://developer.arm.com/Tools%20and%20Software/GNU%20Toolchain) | ≥ 10.3 | `arm-none-eabi-gcc` 交叉编译器 |
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

**直接使用 cbuild：**

```bash
export CMSIS_PACK_ROOT=/home/yuan/.cache/arm/packs
export GCC_TOOLCHAIN_13_2_1=/usr/bin

# 编译 Debug + Release
cbuild multi.csolution.yml

# 仅编译 Debug
cbuild multi.csolution.yml --context-set -c "multi.Debug+MyBoard"

# 仅编译 Release
cbuild multi.csolution.yml --context-set -c "multi.Release+MyBoard"
```

## 编译产物

编译成功后，ELF 文件位于 `out/` 目录：

| 构建类型 | 输出文件 | 典型大小 |
|---------|---------|---------|
| **Debug** | `out/multi/MyBoard/Debug/multi.elf` | ~173 KB |
| **Release** | `out/multi/MyBoard/Release/multi.elf` | ~99 KB |

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

| 类型 | Debug | Release |
|------|-------|---------|
| **优化级别** | `-O0` (无优化) | `-O2` (平衡优化) |
| **调试信息** | `-g3` (完整调试信息) | `-g0` (无调试信息) |

### 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `CMSIS_PACK_ROOT` | `/home/yuan/.cache/arm/packs` | CMSIS Pack 安装目录 |
| `GCC_TOOLCHAIN_13_2_1` | `/usr/bin` | ARM GCC 工具链路径（版本号根据实际调整） |

## 关键文件说明

### `main.c`
主程序入口，包含一个简单的无限循环。

### `multi.csolution.yml`
解决方案级配置文件，定义目标设备、构建类型、pack 依赖和项目引用。

### `multi.cproject.yml`
项目级配置文件，定义源文件分组和组件依赖。

### `RTE/RTE_Components.h`
运行时环境组件配置头文件，定义设备头文件引用。

### `RTE/Device/ARMCM3/syscalls.c`
newlib 系统调用桩函数实现，提供裸机环境下必要的 syscall stub：
- `_exit()` — 退出程序
- `_sbrk()` — 堆内存管理
- `_write()` / `_read()` — I/O 操作
- `_close()` / `_lseek()` — 文件操作