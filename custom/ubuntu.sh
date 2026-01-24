#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
PWD_DIR="$(pwd)"

function install_mustrelyon(){
echo -e "\033[36m开始升级ubuntu插件和安装依赖.....\033[0m"

echo "::group::使用apt安装必要软件包"
# 更新ubuntu源
apt update -y

# 升级ubuntu
apt full-upgrade -y

# 安装编译openwrt的依赖
apt install -y ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \
  bzip2 ccache clang cmake cpio curl device-tree-compiler ecj fastjar flex gawk gettext gcc-multilib \
  g++-multilib git gnutls-dev gperf haveged help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev \
  libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses-dev libpython3-dev \
  libreadline-dev libssl-dev libtool libyaml-dev libz-dev lld llvm lrzsz mkisofs msmtp nano \
  ninja-build p7zip p7zip-full patch pkgconf python3 python3-pip python3-ply python3-docutils \
  python3-pyelftools qemu-utils re2c rsync scons squashfs-tools subversion swig texinfo uglifyjs \
  upx-ucl unzip vim wget xmlto xxd zlib1g-dev zstd
echo "::endgroup::"

cd $PWD_DIR

curl -fL "https://build-scripts.immortalwrt.org/modify-firmware.sh" -o "/usr/bin/modify-firmware"
chmod 0755 "/usr/bin/modify-firmware"
}

function update_apt_source(){
apt-get autoremove -y --purge
apt-get clean -y

python3 --version
gcc --version
g++ --version
clang --version
echo "GitHub CLI：$(gh --version)"
echo -e "\033[32m全部依赖安装完毕!\033[0m"
}

function main(){
	if [[ -n "${BENDI_VERSION}" ]]; then
		export BENDI_VERSION="1"
		install_mustrelyon
		update_apt_source
	else
		install_mustrelyon
		update_apt_source
	fi
}

main
