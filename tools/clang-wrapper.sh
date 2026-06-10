#!/bin/bash
# Clang wrapper for CMSIS-Build + LLVM-ET-Arm 19.x
#
# Fixes picolibc multilib mismatch for Cortex-M3:
# - CMSIS-Build sets --target=armv7m-*, picolibc uses thumbv7m-*
# - -march flag blocks multilib lookup
# - Explicitly provides picolibc library paths

REAL_CLANG="/home/yuan/local/LLVM-ET-Arm-19.1.5-Linux-x86_64/bin/clang"

RUNTIME_LIB="/home/yuan/local/LLVM-ET-Arm-19.1.5-Linux-x86_64/lib/clang-runtimes/arm-none-eabi/armv7m_soft_nofp_exn_rtti/lib"

# Check if this is a linking invocation (not -c and not -E)
IS_LINK=true
for arg in "$@"; do
    [[ "$arg" == -c || "$arg" == -E ]] && { IS_LINK=false; break; }
done

ARGS=()
for arg in "$@"; do
    case "$arg" in
        --target=armv7m-*) ARGS+=("${arg/armv7m/thumbv7m}") ;;
        -march=armv7m*|-march=thumbv7m*) ;;
        *) ARGS+=("$arg") ;;
    esac
done

if $IS_LINK && [[ -d "$RUNTIME_LIB" ]]; then
    ARGS+=("-L$RUNTIME_LIB" "$RUNTIME_LIB/crt0.o")
fi

exec "$REAL_CLANG" "${ARGS[@]}"