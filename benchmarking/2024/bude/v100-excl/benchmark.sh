#!/bin/bash

set -eu

function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run [COMPILER] [MODEL]"
  echo
  echo "Valid compilers:"
  echo "  chapel-1.33"
  echo "  nvhpc-23.11"
  echo "  clang-17.0.6"
  echo
  echo "Valid models:"
  echo "  chapel"
  echo "  kokkos"
  echo "  cuda"
  echo "  omp"
  echo "  std-indices"
  echo "  std-ranges"
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

handle_cmd "${1}" "${2}" "${3}" "miniBUDE" "v100"

export USE_MAKE=false

case "$COMPILER" in
chapel-1.33)
  load_nvhpc 23.11 # Chapel GPU also requires CUDA libraries
  export CC=`which gcc` # the nvhpc module sets CC=nvc, which confuses Chapel
  export CXX=`which g++` # the nvhpc module sets CXX=nvc++
  export CUDA_PATH=/opt/nvidia/hpc_sdk/Linux_x86_64/23.11/cuda/11.8
  export PATH=${CUDA_PATH}/bin:$PATH
  export CHPL_CUDA_PATH=$CUDA_PATH
  source /noback/46x/chapel-1.33/util/setchplenv.bash
  USE_MAKE=true
  ;;
nvhpc-23.11)
  load_nvhpc 23.11
  append_opts "-DCMAKE_C_COMPILER=$NVHPC_ROOT/compilers/bin/nvc"
  append_opts "-DCMAKE_CXX_COMPILER=$NVHPC_ROOT/compilers/bin/nvc++"
  ;;
clang-17.0.6)
  load_nvhpc 23.11 # ExCL OpenMP offload also requires CUDA libraries
  module load llvm/17.0.6-mpoffload
  append_opts "-DCMAKE_CXX_COMPILER=/usr/local/llvm/17.0.6/bin/clang++"
  ;;
*) unknown_compiler ;;
esac

if [ "$USE_MAKE" = false ]; then
  append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON -DUSE_CPU_FEATURES=OFF"
fi

fetch_src

case "$MODEL" in
chapel)
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$CUDA_PATH/lib64
  append_opts "CHPL_LOCALE_MODEL=gpu"
  append_opts "CHPL_GPU=nvidia"
  append_opts "CHPL_GPU_ARCH=sm_70"
  append_opts "PPWI=4"
  BENCHMARK_EXE="chapel-bude"
  ;;
kokkos)
  prime_kokkos
  export CUDA_ROOT="$NVHPC_ROOT/cuda"
  append_opts "-DMODEL=kokkos"
  append_opts "-DKOKKOS_IN_TREE=$KOKKOS_DIR -DKokkos_ENABLE_CUDA=ON -DKokkos_ENABLE_CUDA_LAMBDA=ON"
  append_opts "-DKokkos_ARCH_VOLTA70=ON"
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=$KOKKOS_DIR/bin/nvcc_wrapper"
  append_opts "-DCMAKE_CXX_FLAGS=-arch=sm_70"
  append_opts "-DKOKKOS_INTERNAL_CUDA_ARCH_FLAG=sm_70"
  append_opts "-DCXX_EXTRA_FLAGS=-O3;--use_fast_math"
  BENCHMARK_EXE="kokkos-bude"
  ;;
cuda)
  append_opts "-DMODEL=cuda"
  append_opts "-DCMAKE_CUDA_COMPILER=$NVHPC_ROOT/compilers/bin/nvcc"
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=g++" 
  # fastmath enabled by default
  append_opts "-DCUDA_ARCH=sm_70"
  append_opts "-DCMAKE_CUDA_ARCHITECTURES=70"
  append_opts "-DCMAKE_CUDA_FLAGS=-allow-unsupported-compiler"
  BENCHMARK_EXE="cuda-bude"
  ;;
omp)
  append_opts "-DMODEL=omp"
  append_opts "-DOFFLOAD=NVIDIA:sm_70"
  BENCHMARK_EXE="omp-bude"
  ;;
std-indices)
  append_opts "-DMODEL=std-indices"
  append_opts "-DNVHPC_OFFLOAD=cc70"
  BENCHMARK_EXE="std-indices-bude"
  ;;
std-ranges)
  append_opts "-DMODEL=std-ranges"
  append_opts "-DNVHPC_OFFLOAD=cc70"
  BENCHMARK_EXE="std-ranges-bude"
  ;;
*) unknown_model ;;
esac

handle_exec
