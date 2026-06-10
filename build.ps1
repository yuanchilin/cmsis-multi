#!/usr/bin/env pwsh
<#
.SYNOPSIS
    CMSIS-Build 编译脚本 - cmsis-bootbox
.DESCRIPTION
    使用 cbuild 编译 CMSIS 项目，支持 Debug/Release 构建类型
.PARAMETER Type
    构建类型: Debug, Release, All (默认: All)
.PARAMETER Clean
    是否清理之前的构建产物
.PARAMETER Rebuild
    是否重新构建 (Clean + Build)
.EXAMPLE
    .\build.ps1                   # 编译 Debug + Release
    .\build.ps1 -Type Debug       # 仅编译 Debug
    .\build.ps1 -Type Release     # 仅编译 Release
    .\build.ps1 -Rebuild          # 清理并重新编译
    .\build.ps1 -Clean            # 仅清理构建产物
#>

param(
    [ValidateSet('Debug', 'Release', 'All')]
    [string]$Type = 'All',

    [switch]$Clean,
    [switch]$Rebuild
)

# ============================================================================
# 配置
# ============================================================================
$ProjectDir = $PSScriptRoot
$SolutionFile = Join-Path $ProjectDir 'my_solution.csolution.yml'

# CMSIS Pack 根目录
$Env:CMSIS_PACK_ROOT = '/home/yuan/.cache/arm/packs'

# ARM GCC 工具链版本和路径
$Env:GCC_TOOLCHAIN_13_2_1 = '/usr/bin'

# cbuild 路径
$Cbuild = 'cbuild'
$Cpackget = 'cpackget'

# ============================================================================
# 辅助函数
# ============================================================================
function Write-Header {
    param([string]$Message)
    $line = '=' * 60
    Write-Host "`n$line" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Cyan
    Write-Host "$line`n" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[✓] $Message" -ForegroundColor Green
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "[✗] $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "[i] $Message" -ForegroundColor Yellow
}

# ============================================================================
# 检查依赖
# ============================================================================
function Test-Prerequisites {
    Write-Header '检查依赖工具'

    $tools = @(
        @{ Name = 'cbuild'; Command = 'cbuild' },
        @{ Name = 'cpackget'; Command = 'cpackget' },
        @{ Name = 'arm-none-eabi-gcc'; Command = 'arm-none-eabi-gcc' },
        @{ Name = 'cmake'; Command = 'cmake' },
        @{ Name = 'ninja'; Command = 'ninja' }
    )

    $allFound = $true
    foreach ($tool in $tools) {
        $path = (Get-Command $tool.Command -ErrorAction SilentlyContinue).Source
        if ($path) {
            # 获取版本信息
            $version = & $tool.Command --version 2>&1 | Select-Object -First 1
            Write-Success "$($tool.Name) → $path $($version -replace '.*(\d+\.\d+\.\d+).*', '$1')"
        }
        else {
            Write-ErrorMsg "$($tool.Name) 未找到，请先安装"
            $allFound = $false
        }
    }

    if (-not $allFound) {
        Write-ErrorMsg '缺少必要工具，请安装 CMSIS-Toolbox 和 ARM GCC'
        exit 1
    }

    # 检查 CMSIS Pack 是否已安装
    $packRoot = $Env:CMSIS_PACK_ROOT
    if (Test-Path (Join-Path $packRoot 'ARM/Cortex_DFP')) {
        Write-Success "CMSIS Pack 已安装 ($packRoot)"
    }
    else {
        Write-Info 'CMSIS Pack 未安装，尝试自动安装...'
        & $Cpackget init 'https://www.keil.com/pack/index.pidx' --pack-root $packRoot
        & $Cpackget add 'ARM::CMSIS' --pack-root $packRoot
        & $Cpackget add 'ARM::Cortex_DFP' --pack-root $packRoot
        Write-Success 'CMSIS Pack 安装完成'
    }
}

# ============================================================================
# 清理
# ============================================================================
function Invoke-Clean {
    Write-Header '清理构建产物'

    $cleanDirs = @(
        'tmp',
        'out'
    )

    $cleanFiles = @(
        'my_solution.cbuild-pack.yml',
        'my_project.Debug+MyBoard.cbuild.yml',
        'my_project.Release+MyBoard.cbuild.yml',
        'my_solution.cbuild-idx.yml'
    )

    foreach ($dir in $cleanDirs) {
        $path = Join-Path $ProjectDir $dir
        if (Test-Path $path) {
            Remove-Item -Path $path -Recurse -Force
            Write-Success "已删除: $path"
        }
    }

    foreach ($file in $cleanFiles) {
        $path = Join-Path $ProjectDir $file
        if (Test-Path $path) {
            Remove-Item -Path $path -Force
            Write-Success "已删除: $path"
        }
    }
}

# ============================================================================
# 构
# ============================================================================
function Invoke-Build {
    param([string]$BuildType)

    if ($BuildType -eq 'All') {
        Write-Header '编译 Debug + Release'
    }
    else {
        Write-Header "编译 $BuildType"
    }

    # 切换到项目目录
    Push-Location $ProjectDir

    try {
        if ($BuildType -eq 'All') {
            # 全量编译
            $process = Start-Process -NoNewWindow -PassThru -FilePath $Cbuild -ArgumentList @(
                $SolutionFile
            ) -RedirectStandardOutput "$ProjectDir/build.log" -RedirectStandardError "$ProjectDir/build.err.log"
            $process.WaitForExit()
            $exitCode = $process.ExitCode
        }
        else {
            # 指定构建类型
            $process = Start-Process -NoNewWindow -PassThru -FilePath $Cbuild -ArgumentList @(
                $SolutionFile,
                '--context-set',
                '-c', "my_project.$BuildType+MyBoard"
            ) -RedirectStandardOutput "$ProjectDir/build.log" -RedirectStandardError "$ProjectDir/build.err.log"
            $process.WaitForExit()
            $exitCode = $process.ExitCode
        }

        # 显示构建日志
        if (Test-Path "$ProjectDir/build.log") {
            $log = Get-Content "$ProjectDir/build.log" -Raw
            if ($log.Trim()) {
                Write-Host $log
            }
        }

        return $exitCode
    }
    finally {
        Pop-Location
    }
}

# ============================================================================
# 显示结果
# ============================================================================
function Show-Results {
    Write-Header '编译结果'

    $outDir = Join-Path $ProjectDir 'out'
    if (-not (Test-Path $outDir)) {
        Write-Info '未找到输出目录'
        return
    }

    $elfFiles = Get-ChildItem -Path $outDir -Recurse -Filter '*.elf'
    if ($elfFiles.Count -eq 0) {
        Write-ErrorMsg '未找到 ELF 文件，编译可能失败'
        return
    }

    foreach ($elf in $elfFiles) {
        $size = "{0:N0}" -f ((Get-Item $elf).Length / 1KB)
        $path = $elf.FullName.Replace($ProjectDir + '/', '')
        $type = if ($path -match 'Debug') { 'Debug' } else { 'Release' }

        Write-Host "  [${type}] $path  ($size KB)" -ForegroundColor Green
    }

    # 使用 arm-none-eabi-size 显示详细信息
    Write-Host ''
    Write-Info '各段大小 (arm-none-eabi-size):'
    foreach ($elf in $elfFiles) {
        & arm-none-eabi-size $elf.FullName 2>$null
    }
}

# ============================================================================
# 主流程
# ============================================================================
function Main {
    Write-Header 'CMSIS-BootBox 编译脚本'

    $startTime = Get-Date

    # 1. 检查依赖
    Test-Prerequisites

    # 2. 清理
    if ($Clean -or $Rebuild) {
        Invoke-Clean
        if ($Clean -and (-not $Rebuild)) {
            Write-Success '清理完成'
            return
        }
    }

    # 3. 编译
    $exitCode = Invoke-Build -BuildType $Type

    # 4. 结果
    $elapsed = (Get-Date) - $startTime
    $elapsedStr = '{0:mm}:{0:ss}' -f ([DateTime]$elapsed.Ticks)

    Write-Header '编译摘要'
    if ($exitCode -eq 0) {
        Write-Success "编译成功! (耗时: $elapsedStr)"
        Show-Results
    }
    else {
        Write-ErrorMsg "编译失败! (退出码: $exitCode, 耗时: $elapsedStr)"
        Write-Info '查看详细日志:'
        Write-Info "  Get-Content build.log"
        Write-Info "  Get-Content build.err.log"
        exit $exitCode
    }
}

# 执行
Main