#!/usr/bin/env pwsh
param(
    [ValidateSet('gcc', 'llvm', 'all')][string]$Type = 'all',
    [switch]$Clean,
    [switch]$Rebuild
)

$root = $PSScriptRoot
$sol  = Join-Path $root 'multi.csolution.yml'

# 清理
if ($Clean -or $Rebuild) {
    Write-Host '[Clean]' -ForegroundColor Cyan
    Remove-Item -Recurse -Force "$root/tmp", "$root/out", "$root/RTE" -ErrorAction SilentlyContinue
    Remove-Item -Force "$root/multi.cbuild-pack.yml", "$root/multi.cbuild-idx.yml" -ErrorAction SilentlyContinue
    Remove-Item -Force "$root/multi.Debug+Board.cbuild.yml", "$root/multi.Release+Board.cbuild.yml" -ErrorAction SilentlyContinue
    Remove-Item -Force "$root/multi.Debug-LLVM+Board.cbuild.yml", "$root/multi.Release-LLVM+Board.cbuild.yml" -ErrorAction SilentlyContinue
    Write-Host '  done' -ForegroundColor Green
    if ($Clean -and -not $Rebuild) { return }
}

# 环境变量
$Env:CMSIS_PACK_ROOT          = '/home/yuan/.cache/arm/packs'
$Env:GCC_TOOLCHAIN_13_2_1     = '/usr/bin'
$Env:CLANG_TOOLCHAIN_19_1_5   = '/home/yuan/local/LLVM-ET-Arm-19.1.5-Linux-x86_64/bin'

# 构建列表
$builds = @(
    @{ name='Debug';        ctx='multi.Debug+Board';        compiler='gcc' }
    @{ name='Release';      ctx='multi.Release+Board';      compiler='gcc' }
    @{ name='Debug-LLVM';   ctx='multi.Debug-LLVM+Board';   compiler='llvm' }
    @{ name='Release-LLVM'; ctx='multi.Release-LLVM+Board'; compiler='llvm' }
)
if ($Type -ne 'all') { $builds = $builds | Where-Object { $_.compiler -eq $Type } }

$exit = 0
foreach ($b in $builds) {
    Write-Host "[$($b.name)] update-rte ..." -ForegroundColor Yellow
    & csolution update-rte $sol -c $b.ctx
    if ($LASTEXITCODE -ne 0) { Write-Host "  RTE failed" -ForegroundColor Red; exit 1 }

    Write-Host "`n==> $($b.name) ..." -ForegroundColor Cyan
    if ($b.compiler -eq 'llvm') { $Env:CMSIS_COMPILER_ROOT = Join-Path $root 'tools' }
    else { Remove-Item Env:CMSIS_COMPILER_ROOT -ErrorAction SilentlyContinue }

    & cbuild $sol -c $b.ctx
    if ($LASTEXITCODE -ne 0) { $exit = $LASTEXITCODE; Write-Host "  FAILED ($($b.name))" -ForegroundColor Red; break }
}

if ($exit -eq 0) {
    Get-ChildItem -Recurse "$root/out/*.elf" | ForEach-Object {
        $sz = '{0:N0} KB' -f ($_.Length / 1KB)
        Write-Host "  [OK] $($_.FullName.Replace("$root/",'')) ($sz)" -ForegroundColor Green
    }
    Write-Host "`nAll done!" -ForegroundColor Green
} else {
    Write-Host "`nBuild failed!" -ForegroundColor Red
}
exit $exit