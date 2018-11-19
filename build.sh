#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (C) 2018 Yaroslav Furman (YaroST12)

# Fucking folders
kernel_dir="${PWD}"
objdir="${kernel_dir}/out"
builddir="${kernel_dir}/build"
# Fucking versioning
branch_name=$(git rev-parse --abbrev-ref HEAD)
last_commit=$(git rev-parse --verify --short=10 HEAD)
cpus=$(nproc --all)
export LOCALVERSION="-${branch_name}/${last_commit}"
export KBUILD_BUILD_USER="ST12"
# Fucking arch and clang triple
export ARCH="arm64"
export CLANG_TRIPLE="aarch64-linux-gnu-"
# Fucking toolchains
CC="${TTHD}/toolchains/gcc-linaro-7.3.1-aarch64/bin/aarch64-linux-gnu-"
CC_32="${TTHD}/toolchains/gcc-linaro-7.3.1-arm/bin/arm-linux-gnueabi-"
CT="${TTHD}/toolchains/clang-8.x/bin/clang"

# Colors
NC='\033[0m'
RED='\033[0;31m'
LRD='\033[1;31m'
LGR='\033[1;32m'
YEL='\033[1;33m'

# Separator
SEP="########################################"
function die() {
	echo -e ${RED} ${SEP}
	echo -e ${RED} "${1}"
	echo -e ${RED} ${SEP}
	exit
}

function parse_parameters() {
	PARAMS="${*}"
	# Default params
	BUILD_GCC=false
	CONFIG_FILE="z2_row_defconfig"
	DEVICE="row"
	TC="${YEL}Flash-Clang${LGR}"

	while [[ ${#} -ge 1 ]]; do
		case ${1} in
			"-p"|"--plus")
				SEP+="#"
				DEVICE="plus"
				CONFIG_FILE="z2_plus_defconfig" ;;

			"-g"|"--gcc")
				TC="GCC"
				BUILD_GCC=true ;;

            *) die "Invalid parameter specified!" ;;
		esac

		shift
	done
	if [ ${BUILD_GCC} == false ]; then
		# Separator needs to be longer
		SEP+="#######"
	fi
	echo -e ${LGR} ${SEP}
	echo -e ${LGR} "Compilation started for Z2_${DEVICE} with ${TC} ${NC}"
}

# Formats the time for the end
function format_time() {
	MINS=$(((${2} - ${1}) / 60))
	SECS=$(((${2} - ${1}) % 60))

	TIME_STRING+="${MINS}:${SECS}"

	echo "${TIME_STRING}"
}

function make_image()
{
	# Needed to make sure we get dtb built and added to kernel image properly
	rm -rf ${objdir}/arch/arm64/boot/
	START=$(date +%s)
	echo -e ${LGR} "Generating Defconfig ${NC}"
	make -s ARCH=${ARCH} O=${objdir} ${CONFIG_FILE}

	echo -e ${LGR} "Building image ${NC}"
	if [ ${BUILD_GCC} == true ]; then
		cd ${kernel_dir}
		make -s -j${cpus} CROSS_COMPILE=${CC} CROSS_COMPILE_ARM32=${CC_32} \
		O=${objdir} Image.gz-dtb
	else
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
		make -s -j${cpus} CC="${CT} ${POLLY}" CROSS_COMPILE=${CC} \
		CROSS_COMPILE_ARM32=${CC_32} O=${objdir} Image.gz-dtb
	fi
	END=$(date +%s)
}
function completion()
{
	cd ${objdir}
	COMPILED_IMAGE=arch/arm64/boot/Image.gz-dtb
	if [[ -f ${COMPILED_IMAGE} ]]; then
		if [ ${DEVICE} == "plus" ]; then
			mv -f ${COMPILED_IMAGE} ${builddir}/Image.gz-dtb_plus
		else
			mv -f ${COMPILED_IMAGE} ${builddir}/Image.gz-dtb_row
		fi
		echo -e ${LGR} "Build for Z2_$DEVICE competed in" \
			"$(format_time "${START}" "${END}")!${NC}"
		echo -e ${LGR} ${SEP}
	fi
}
parse_parameters "${@}"
make_image
completion
cd ${kernel_dir}
