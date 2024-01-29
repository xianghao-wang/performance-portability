#!/usr/bin/env bash

set -eu

function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run [COMPILER] [MODEL]"
  echo
  echo "Valid compilers:"
  echo "  chapel-1.33"
  echo "  clang-17.0.6"
  echo
  echo "Valid models:"
  echo "  chapel"
  echo "  kokkos"
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

handle_cmd "${1}" "${2}" "${3}" "miniBUDE" "power9"

export USE_MAKE=false

case "$COMPILER" in
chapel-1.33)
  source /noback/46x/chapel-1.33_centos8/util/setchplenv.bash
  USE_MAKE=true
  ;;
gcc-10.2)
  module load gnu/10.2.0
  append_opts "-DCMAKE_CXX_COMPILER=g++"
  append_opts "-DRELEASE_FLAGS=-O3;-mcpu=native" # gcc 10.2 doesn't support -march
  ;;
xlc-16.1.1)
  export XLC_USR_CONFIG=/home/46x/xlc.cfg
  append_opts "-DCMAKE_CXX_COMPILER=xlc++"
  ;;
*) unknown_compiler ;;
esac

if [ "$USE_MAKE" = false ]; then
  append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON"
fi

fetch_src

case "$MODEL" in
chapel)
  BENCHMARK_EXE="chapel-bude"
  append_opts "CHPL_LOCALE_MODEL=flat"
  append_opts "PPWI=128"
  ;;
kokkos)
  prime_kokkos
  append_opts "-DMODEL=kokkos"
  append_opts "-DKOKKOS_IN_TREE=$KOKKOS_DIR -DKokkos_ENABLE_OPENMP=ON"
  append_opts "-DKokkos_ARCH_POWER9=ON"
  BENCHMARK_EXE="kokkos-bude"
  ;;
omp)
  append_opts "-DMODEL=omp"
  append_opts "DOMP_FLAGS_CPU_XLC=-qsmp=omp"
  BENCHMARK_EXE="omp-bude"
  ;;
std-data)
  append_opts "-DMODEL=std-data"
  BENCHMARK_EXE="std-data-bude"
  ;;
std-indices)
  append_opts "-DMODEL=std-indices"
  BENCHMARK_EXE="std-indices-bude"
  ;;
std-ranges)
  append_opts "-DMODEL=std-ranges"
  BENCHMARK_EXE="std-ranges-bude"
  ;;
*) unknown_model ;;
esac

handle_exec
