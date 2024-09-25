#!/usr/bin/env sh
############################################################################
# nuttxspace/install_tools_arm64.sh
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.  The
# ASF licenses this file to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance with the
# License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations
# under the License.
#
############################################################################

# MSYS2
# (Always use the MSYS2 shell launcher ->  C:\msys64\msys2.exe)

set -e
set -o xtrace

CIWORKSPACE=$(cd "$(dirname "$0")" && pwd)
NUTTXTOOLS=${CIWORKSPACE}/tools

add_path() {
  PATH=$1:${PATH}
}

arm64_gcc_toolchain() {
  add_path "${NUTTXTOOLS}"/gcc-aarch64-none-elf/bin

  if [ ! -f "${NUTTXTOOLS}/gcc-aarch64-none-elf/bin/aarch64-none-elf-gcc" ]; then
    local basefile
    basefile=arm-gnu-toolchain-13.2.rel1-mingw-w64-i686-aarch64-none-elf
    cd "${NUTTXTOOLS}"
    # Download the latest ARM64 GCC toolchain prebuilt by ARM
    curl -O -L https://developer.arm.com/-/media/Files/downloads/gnu/13.2.Rel1/binrel/${basefile}.zip
    unzip -qo ${basefile}.zip
    mv ${basefile} gcc-aarch64-none-elf
    rm ${basefile}.zip
  fi

  command aarch64-none-elf-gcc --version
}

gen_romfs() {
  add_path "${NUTTXTOOLS}"/genromfs/usr/bin

  if ! type genromfs > /dev/null 2>&1; then
    git clone --depth 1 https://bitbucket.org/nuttx/tools.git "${NUTTXTOOLS}"/nuttx-tools
    cd "${NUTTXTOOLS}"/nuttx-tools
    tar zxf genromfs-0.5.2.tar.gz
    cd genromfs-0.5.2
    make install PREFIX="${NUTTXTOOLS}"/genromfs
    cd "${NUTTXTOOLS}"
    rm -rf nuttx-tools
  fi
}

kconfig_frontends() {
  add_path "${NUTTXTOOLS}"/kconfig-frontends/bin

  if [ ! -f "${NUTTXTOOLS}/kconfig-frontends/bin/kconfig-conf" ]; then
    git clone --depth 1 https://bitbucket.org/nuttx/tools.git "${NUTTXTOOLS}"/nuttx-tools
    cd "${NUTTXTOOLS}"/nuttx-tools/kconfig-frontends
    ./configure --prefix="${NUTTXTOOLS}"/kconfig-frontends \
      --enable-mconf --disable-kconfig --disable-nconf --disable-qconf \
      --disable-gconf --disable-static \
      --disable-shared --disable-L10n
    # Avoid "aclocal/automake missing" errors
    touch aclocal.m4 Makefile.in
    make install
    cd "${NUTTXTOOLS}"
    rm -rf nuttx-tools
  fi
}

rust() {
  add_path "${NUTTXTOOLS}"/rust/cargo/bin
  # Configuring the PATH environment variable
  export CARGO_HOME=${NUTTXTOOLS}/rust/cargo
  export RUSTUP_HOME=${NUTTXTOOLS}/rust/rustup
  echo "export CARGO_HOME=${NUTTXTOOLS}/rust/cargo" >> "${NUTTXTOOLS}"/env.sh
  echo "export RUSTUP_HOME=${NUTTXTOOLS}/rust/rustup" >> "${NUTTXTOOLS}"/env.sh
  if ! type rustc > /dev/null 2>&1; then
    local basefile
    basefile=x86_64-pc-windows-gnu
    mkdir -p "${NUTTXTOOLS}"/rust
    cd "${NUTTXTOOLS}"
    # Download tool rustup-init.exe
    curl -O -L -s https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-gnu/rustup-init.exe
    # Install Rust target x86_64-pc-windows-gnu
    ./rustup-init.exe -y --default-host ${basefile} --no-modify-path
    # Install targets supported from NuttX
    "$CARGO_HOME"/bin/rustup target add thumbv6m-none-eabi
    "$CARGO_HOME"/bin/rustup target add thumbv7m-none-eabi
    rm rustup-init.exe
  fi
  command rustc --version
}

install_build_tools() {
  mkdir -p "${NUTTXTOOLS}"
  echo "#!/usr/bin/env sh" > "${NUTTXTOOLS}"/env.sh

  install="gen_romfs kconfig_frontends arm64_gcc_toolchain"

  oldpath=$(cd . && pwd -P)
  for func in ${install}; do
    ${func}
  done
  cd "${oldpath}"

  echo "PATH=${PATH}" >> "${NUTTXTOOLS}"/env.sh
  echo "export PATH" >> "${NUTTXTOOLS}"/env.sh
}

mkdir -p "${NUTTXTOOLS}"

install_build_tools
