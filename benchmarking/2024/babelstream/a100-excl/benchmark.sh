#!/usr/bin/env bash

set -eu

function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run [COMPILER] [MODEL]"
  echo
  echo "Valid compilers:"
  echo "  nvhpc-23.9"
  echo "  clang-17.0.6"
  echo
  echo "Valid models:"
  echo "  kokkos"
  echo "  cuda"
  echo "  omp"
  echo "  std-data"
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

handle_cmd "${1}" "${2}" "${3}" "babelstream" "a100"

export USE_MAKE=false

append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON"

case "$COMPILER" in
nvhpc-23.9)
  load_nvhpc
  append_opts "-DCMAKE_C_COMPILER=$NVHPC_ROOT/compilers/bin/nvc"
  append_opts "-DCMAKE_CXX_COMPILER=$NVHPC_ROOT/compilers/bin/nvc++"
  ;;
clang-17.0.6)
  module load llvm/17.0.6-mpoffload
  append_opts "-DCMAKE_CXX_COMPILER=/usr/local/llvm/17.0.6/bin/clang++"
  ;;
chapel-1.33)
  export CUDA_PATH=/opt/nvidia/hpc_sdk/Linux_x86_64/23.9/cuda/11.8
  export CHPL_CUDA_PATH=$CUDA_PATH
  ;;
*) unknown_compiler ;;
esac

fetch_src

case "$MODEL" in
chapel)
  append_opts "-DCHPL_GPU=nvidia"
  append_opts "-DCHPL_GPU_ARCH=sm_80"
  BENCHMARK_EXE="chapel-stream"
  ;;
kokkos)
  prime_kokkos
  export CUDA_ROOT="$NVHPC_ROOT/cuda"
  append_opts "-DMODEL=kokkos"
  append_opts "-DKOKKOS_IN_TREE=$KOKKOS_DIR -DKokkos_ENABLE_CUDA=ON -DKokkos_ENABLE_CUDA_LAMBDA=ON"
  append_opts "-DKokkos_ARCH_AMPERE80=ON"
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=$KOKKOS_DIR/bin/nvcc_wrapper"
  append_opts "-DCMAKE_CXX_FLAGS=-arch=sm_80"
  append_opts "-DKOKKOS_INTERNAL_CUDA_ARCH_FLAG=sm_80"
  BENCHMARK_EXE="kokkos-stream"
  ;;
cuda)
  append_opts "-DMODEL=cuda"
  append_opts "-DCMAKE_CUDA_COMPILER=$NVHPC_ROOT/compilers/bin/nvcc"
  append_opts "-DCMAKE_CXX_COMPILER=g++"
  append_opts "-DCUDA_ARCH=sm_80"
  append_opts "-DCMAKE_CUDA_ARCHITECTURES=80"
  append_opts "-DCMAKE_CUDA_FLAGS=-allow-unsupported-compiler"
  BENCHMARK_EXE="cuda-stream"
  ;;
omp)
  append_opts "-DMODEL=omp"
  append_opts "-DOFFLOAD=NVIDIA:sm_80"
  BENCHMARK_EXE="omp-stream"
  ;;
std-data)
  append_opts "-DMODEL=std-data"
  append_opts "-DNVHPC_OFFLOAD=cc80"
  BENCHMARK_EXE="std-data-stream"
  ;;
std-indices)
  append_opts "-DMODEL=std-indices"
  append_opts "-DNVHPC_OFFLOAD=cc80"
  BENCHMARK_EXE="std-indices-stream"
  ;;
std-ranges)
  append_opts "-DMODEL=std-ranges"
  append_opts "-DNVHPC_OFFLOAD=cc80"
  BENCHMARK_EXE="std-ranges-stream"
  ;;
*) unknown_model ;;
esac

handle_exec
