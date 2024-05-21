#!/usr/bin/env bash

set -eu

function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run [COMPILER] [MODEL]"
  echo
  echo "Valid compilers:"
  echo "  chapel-2.1"
  echo
  echo "Valid models:"
  echo "  chapel"
  echo "  kokkos"
  echo "  omp"
  echo "  sycl"
  echo "  onedpl"
  echo "  raja"
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

# NOTE: not applicable on PC
# module load cmake/3.26.3 

handle_cmd "${1}" "${2}" "${3}" "everthingsreduced" "rtx3070ti"

export USE_MAKE=false

case "$COMPILER" in
chapel-2.1)
  export CC=`which gcc`
  export CXX=`which g++`
  export CUDA_PATH=/usr/local/cuda-12.4
  export PATH=${CUDA_PATH}/bin:$PATH
  export CHPL_CUDA_PATH=$CUDA_PATH
  source $HOME/libs/chapel/util/setchplenv.bash
  USE_MAKE=true
  ;;
*) unknown_compiler ;;
esac

if [ "$USE_MAKE" = false ]; then
  append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON"
fi

fetch_src

case "$MODEL" in
chapel)
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$CUDA_PATH/lib64
  append_opts "CHPL_LOCALE_MODEL=gpu"
  append_opts "CHPL_GPU=nvidia"
  append_opts "CHPL_GPU_ARCH=sm_70"
  BENCHMARK_EXE="chapel-reduced"
  ;;
*) unknown_model ;;
esac

handle_exec