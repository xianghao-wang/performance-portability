#!/usr/bin/env bash

set -eu

function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run [COMPILER] [MODEL]"
  echo
  echo "Valid compilers:"
  echo "  chapel-1.33"
  echo "  rocm-5.4.3"
  echo "  aomp-18.0.0"
  echo
  echo "Valid models:"
  echo "  chapel"
  echo "  kokkos"
  echo "  hip"
  echo "  omp"
  echo
}

# Process arguments
if [ $# -lt 3 ]; then
  usage
  exit 1
fi

SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

module load cmake/3.26.3
module load rocm/5.4.3
export ROCM_PATH="/opt/rocm-5.4.3"

handle_cmd "${1}" "${2}" "${3}" "miniBUDE" "mi60"

export USE_MAKE=false

case "$COMPILER" in
chapel-1.33)
  source /noback/46x/chapel-1.33/util/setchplenv.bash
  USE_MAKE=true
  ;;
rocm-5.4.3)
  export PATH="/opt/rocm-5.4.3/bin:${PATH:-}"
  ;;
aomp-18.0.0)
  export AOMP=$HOME/usr/lib/aomp_18.0-0
  export PATH="$AOMP/bin:${PATH:-}"
  export LD_LIBRARY_PATH="$AOMP/lib64:${LD_LIBRARY_PATH:-}"
  export LIBRARY_PATH="$AOMP/lib64:${LIBRARY_PATH:-}"
  export C_INCLUDE_PATH="$AOMP/include:${C_INCLUDE_PATH:-}"
  export CPLUS_INCLUDE_PATH="$AOMP/include:${CPLUS_INCLUDE_PATH:-}"
  ;;
*) unknown_compiler ;;
esac

if [ "$USE_MAKE" = false ]; then
  append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON"
fi

fetch_src

case "$MODEL" in
chapel)
  append_opts "CHPL_LOCALE_MODEL=gpu"
  append_opts "CHPL_GPU=amd"
  append_opts "CHPL_GPU_ARCH=gfx908"
  append_opts "PPWI=1"
  BENCHMARK_EXE="chapel-bude"
  ;;
kokkos)
  prime_kokkos
  append_opts "-DMODEL=kokkos"
  append_opts "-DKOKKOS_IN_TREE=$KOKKOS_DIR -DKokkos_ENABLE_HIP=ON"
  append_opts "-DKokkos_ARCH_VEGA908=ON"
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=hipcc"
  append_opts "-DCXX_EXTRA_FLAGS=-march=znver3;-Ofast"
  BENCHMARK_EXE="kokkos-bude"
  ;;
hip)
  append_opts "-DMODEL=hip"
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=hipcc" # auto detected
  append_opts "-DCXX_EXTRA_FLAGS=--offload-arch=gfx908;-march=znver3;-Ofast"
  BENCHMARK_EXE="hip-bude"
  ;;
omp)
  append_opts "-DCMAKE_CXX_COMPILER=$(which clang++)"
  append_opts "-DMODEL=omp"
  append_opts "-DOFFLOAD=AMD:gfx908"
  append_opts "-DCXX_EXTRA_FLAGS=-march=znver3;-Ofast;-fopenmp-target-fast"
  BENCHMARK_EXE="omp-bude"
  ;;
*) unknown_model ;;
esac

handle_exec
