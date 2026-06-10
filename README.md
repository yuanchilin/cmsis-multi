# CMSIS-Multi

基于 **CMSIS-Build** 的 ARM Cortex-M3 裸机示例项目，支持 GCC / LLVM 双编译器构建。

## 项目结构

```
cmsis-multi/
├── main.c                        # 主程序
├── multi.csolution.yml           # 解决方案配置
├── multi.cproject.yml            # 项目配置
├── build.ps1                     # 编译脚本
├── tools/
│   └── CLANG.19.1.5.cmake        # 自定义 Clang 工具链配置
├── src/
│   └── syscalls.c                # newlib syscall 桩函数（仅 GCC）
├── RTE/                          # csolution update-rte 自动生成
│   ├── RTE_Components.h
│   └── Device/ARMCM3/
│       ├── startup_ARMCM3.c
│       ├── system_ARMCM3.c
│       └── ARMCM3_gcc.ld
├── out/                          # 编译产物
├── tmp/                          # 临时构建文件
└── build.log                     # 构建日志
```

## 环境要求

| 工具 | 版本 | 说明 |
|------|------|------|
| [CMSIS-Toolbox](https://github.com/Open-CMSIS-Pack/cmsis-toolbox) | ≥ 2.0 | `cbuild`、`cpackget`、`csolution` |
| [ARM GCC](https://developer.arm.com/Tools%20and%20Software/GNU%20Toolchain) | ≥ 10.3 | `arm-none-eabi-gcc` |
| [LLVM Embedded Arm](https://github.com/ARM-software/LLVM-embedded-toolchain-for-Arm) | ≥ 19.0 | `clang`（可选） |
| CMake | ≥ 3.22 | 构建系统生成器 |
| Ninja | ≥ 1.10 | 构建执行引擎 |
| PowerShell | ≥ 7.0 | 编译脚本 |

## 快速开始

安装 CMSIS Pack：

```bash
cpackget init https://www.keil.com/pack/index.pidx
cpackget add ARM::CMSIS
cpackget add ARM::Cortex_DFP
```

编译全部 4 种配置：

```powershell
pwsh ./build.ps1
```

## 编译脚本用法

```powershell
pwsh ./build.ps1                # 编译全部 (GCC Debug/Release + LLVM Debug/Release)
pwsh ./build.ps1 -Type gcc      # 仅编译 GCC
pwsh ./build.ps1 -Type llvm     # 仅编译 LLVM
pwsh ./build.ps1 -Clean         # 仅清理产物
pwsh ./build.ps1 -Rebuild       # 清理并重新编译
```

## 编译产物

| 构建类型 | 编译器 | ELF | 典型大小 |
|---------|--------|-----|---------|
| Debug | GCC | `out/multi/Board/Debug/multi.elf` | ~173 KB |
| Release | GCC | `out/multi/Board/Release/multi.elf` | ~99 KB |
| Debug-LLVM | Clang | `out/multi/Board/Debug-LLVM/multi.elf` | ~140 KB |
| Release-LLVM | Clang | `out/multi/Board/Release-LLVM/multi.elf` | ~138 KB |

查看各段大小：

```bash
arm-none-eabi-size out/multi/Board/Debug/multi.elf
```

## 环境变量

在 `build.ps1` 中已预设，可按需修改：

| 变量 | 值 |
|------|-----|
| `CMSIS_PACK_ROOT` | `/home/yuan/.cache/arm/packs` |
| `GCC_TOOLCHAIN_13_2_1` | `/usr/bin` |
| `CLANG_TOOLCHAIN_19_1_5` | `/path/to/LLVM-ET-Arm-19.1.5-Linux-x86_64/bin` |

> CMSIS-Toolbox 通过 `GCC_TOOLCHAIN_xx_x_x` 格式的环境变量定位 GCC 工具链（文件名 `GCC.13.2.1.cmake` 对应 `GCC_TOOLCHAIN_13_2_1`）。

## 构建类型

| 类型 | 编译器 | 优化 | 调试信息 |
|------|--------|------|---------|
| Debug | GCC | `-O0` | `-g3` |
| Release | GCC | `-O2` | `-g0` |
| Debug-LLVM | Clang | `-O0` | `-g3` |
| Release-LLVM | Clang | `-O2` | `-g0` |

## 关键文件

### `tools/CLANG.19.1.5.cmake`

自定义 Clang 工具链配置，对 Cortex-M3 做了 picolibc multilib 兼容修复：

- 保留 `armv7m` target triple 以匹配 picolibc 运行时目录命名
- 显式添加 picolibc 运行时库路径和 `crt0.o`，绕过 CMSIS-Build 的 `-march=thumbv7m+...` 展开导致的自动查找失效

### `src/syscalls.c`

newlib 系统调用桩函数实现（仅 GCC）。Clang 使用 picolibc 内置实现，编译时通过 `#if !defined(__clang__)` 跳过。