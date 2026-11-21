#!/bin/bash
set -e # Exit on error
if [ -z "$YatCC_PYBIND11_DIR" ]; then
  cd "$(dirname "$0")" 
else
  mkdir -p "$YatCC_PYBIND11_DIR"
  cd "$YatCC_PYBIND11_DIR"
fi

if [ -d install ]; then
  echo "ALREADY SETUP! - please remove the install directory to reinstall:"
  echo "  rm -rf $(realpath install)"
  exit 0
fi
rm -rf source build install

if [ ! -f pybind11.zip ]; then
  wget -O  pybind11.zip https://github.com/pybind/pybind11/archive/refs/tags/v2.13.6.zip
fi

unzip pybind11.zip
mv pybind11-2.13.6 source 
mkdir build install
cmake source -B build -G Ninja \
  -DCMAKE_INSTALL_PREFIX="$(realpath install)" \
  -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF
# pybind11 2.13.6's own pytest suite has a case that asserts on the exact
# "unhashable type:" message prefix, which Python 3.14 changed. The suite is
# irrelevant to consumers, so allow skipping it (used in CI).
if [ "${YATCC_PYBIND11_SKIP_TESTS:-0}" = "1" ]; then
  echo "skipping pybind11 self-tests (YATCC_PYBIND11_SKIP_TESTS=1)"
else
  cmake --build build --target check
fi
cmake --build build --target install
