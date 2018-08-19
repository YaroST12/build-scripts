#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (C) 2018 Yaroslav Furman (YaroST12)

# Export fucking folders
kernel_dir="${PWD}"
objdir="${kernel_dir}/out_gcc"
builddir="${kernel_dir}/build"
# Export fucking fucks
branch_name=$(git rev-parse --abbrev-ref HEAD)
last_commit=$(git rev-parse --verify --short=10 HEAD)
# Legacy code XD
# branch_name=$(cat $kernel_dir/.git/HEAD | cut -c 17-)
# last_commit=$(cat $kernel_dir/.git/refs/heads/${branch_name} | cut -c -12)
export CONFIG_FILE="mata_user_defconfig"
export ARCH="arm64"
export LOCALVERSION="-${branch_name}/${last_commit}/GCC-9.0-experimental"
export KBUILD_BUILD_USER="ST12"
export CLANG_TRIPLE="aarch64-linux-gnu-"
# Home PC
CROSS_COMPILE="${TTHD}/toolchains/aarch64-linux-gnu/bin/aarch64-linux-gnu-"
# Colors
NC='\033[0m'
RED='\033[0;31m'
LRD='\033[1;31m'
LGR='\033[1;32m'
YEL='\033[1;33m'

make_defconfig()
{
	# Needed to make sure we get dtb built and added to kernel image properly
	rm -rf ${objdir}/arch/arm64/boot/dts/essential/
	echo -e ${LGR} "########### Generating Defconfig ############${NC}"
	make -s ARCH=${ARCH} O=${objdir} ${CONFIG_FILE}
}
compile()
{
	cd ${kernel_dir}
	echo -e ${LGR} "######### Compiling kernel with GCC #########${NC}"
	make -s CROSS_COMPILE=${CROSS_COMPILE} O=${objdir} Image.gz-dtb -j8
}
completion() 
{
	cd ${objdir}
	COMPILED_IMAGE=arch/arm64/boot/Image.gz-dtb
	if [[ -f ${COMPILED_IMAGE} ]]; then
		mv -f ${COMPILED_IMAGE} ${builddir}/Image.gz-dtb
		echo -e ${LGR} "############################################"
		echo -e ${LGR} "############# Build competed! ##############"
		echo -e ${LGR} "############################################${NC}"
	else
		echo -e ${RED} "############################################"
		echo -e ${RED} "## Build fuckedup, check warnings/errors ###"
		echo -e ${RED} "############################################${NC}"
	fi
}
make_defconfig
compile 
completion
cd ${kernel_dir}
