#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (C) 2018 Yaroslav Furman (YaroST12)

# Export fucking folders
kernel_dir="${PWD}"
objdir="${kernel_dir}/out"
builddir="${kernel_dir}/build"
# Export fucking fucks
branch_name=$(git rev-parse --abbrev-ref HEAD)
last_commit=$(git rev-parse --verify --short=10 HEAD)
export CONFIG_FILE="mata_defconfig"
export ARCH="arm64"
export LOCALVERSION="-${branch_name}/${last_commit}"
export KBUILD_BUILD_USER="ST12"
export CLANG_TRIPLE="aarch64-linux-gnu-"

# Home PC
CC="${TTHD}/toolchains/aarch64-linux-gnu/bin/aarch64-linux-gnu-"
CC_32="${TTHD}/toolchains/arm-linux-gnueabi/bin/arm-linux-gnueabi-"
CT="${TTHD}/toolchains/clang-8.x/bin/clang"

# Colors
NC='\033[0m'
RED='\033[0;31m'
LRD='\033[1;31m'
LGR='\033[1;32m'
YEL='\033[1;33m'
check_everything()
{
	if [[ ! -d ${TTHD}/toolchains/ ]] || [[ ! -s ${CT} ]]; then
		completion "toolchains"
		exit
	fi
}
make_defconfig()
{
	# Needed to make sure we get dtb built and added to kernel image properly
	rm -rf ${objdir}/arch/arm64/boot/dts/
	echo -e ${LGR} "\r########### Generating Defconfig ############${NC}"
	make -s ARCH=${ARCH} O=${objdir} ${CONFIG_FILE}
}
compile()
{
	POLLY="-mllvm -polly \
		-mllvm -polly-run-dce \
		-mllvm -polly-parallel \
		-mllvm -polly-run-inliner \
		-mllvm -polly-opt-fusion=max \
		-mllvm -polly-ast-use-context \
		-mllvm -polly-vectorizer=stripmine"

	export KBUILD_COMPILER_STRING="clang-$($CT --version | \
	grep "clang version" | cut -c 15-24 | sed -e 's/ //')"

	cd ${kernel_dir}
	echo -e ${LGR} "\r##### Compiling kernel with ${YEL}Flash-Clang${LGR} #####${NC}"
	make -s -j8 CC="${CT} ${POLLY}" CROSS_COMPILE=${CC} CROSS_COMPILE_ARM32=${CC_32} \
	O=${objdir} Image.gz-dtb
}
compile_gcc()
{
	cd ${kernel_dir}
	echo -e ${LGR} "\r######### Compiling kernel with GCC #########${NC}"
	make -s -j8 CROSS_COMPILE=${CC} CROSS_COMPILE_ARM32=${CC_32} \
	O=${objdir} Image.gz-dtb
}
completion() 
{
	cd ${objdir}
	NO_IMAGE="### Build fuckedup, check warnings/errors ###"
	NO_TC="### Build fuckedup, toolchains are missing ##"
	COMPILED_IMAGE=arch/arm64/boot/Image.gz-dtb
	if [[ -f ${COMPILED_IMAGE} ]]; then
		mv -f ${COMPILED_IMAGE} ${builddir}/Image.gz-dtb
		echo -e ${LGR} "\r#############################################"
		echo -e ${LGR} "\r############## Build competed! ##############"
		echo -e ${LGR} "\r#############################################${NC}"
	else
		echo -e ${RED} "\r#############################################"
		if [ "$1" == toolchains ]; then
			echo -e ${RED} ${NO_TC}
		else
			echo -e ${RED} ${NO_IMAGE}
		fi
		echo -e ${RED} "\r#############################################${NC}"
	fi
}
check_everything
make_defconfig
if [ "$1" == gcc ]; then
compile_gcc
else
compile
fi
completion
cd ${kernel_dir}

