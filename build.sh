#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (C) 2018 Yaroslav Furman (YaroST12)

# Fucking folders
kernel_dir="${PWD}"
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
GCC="${TTHD}/toolchains/aarch64-linux-gnu/bin/aarch64-linux-gnu-"
GCC_32="${TTHD}/toolchains/gcc-linaro-7.3.1-arm/bin/arm-linux-gnueabi-"
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
	BUILD_CLEAN=false
	CONFIG_FILE="z2_row_defconfig"
	DEVICE="row"
	TC="${YEL}Flash-Clang${LGR}"
	objdir="${kernel_dir}/out"

	while [[ ${#} -ge 1 ]]; do
		case ${1} in
			"-p"|"--plus")
				SEP+="#"
				DEVICE="plus"
				CONFIG_FILE="z2_plus_defconfig" ;;

			"-g"|"--gcc")
				objdir="${kernel_dir}/out_gcc"
				TC="GCC"
				BUILD_GCC=true ;;

			"-c"|"--clean")
				BUILD_CLEAN=true ;;

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
	# Cleanup existing build files
	if [ ${BUILD_CLEAN} == true ]; then
	    rm -rf ${objdir}
		echo -e ${LGR} "Cleaning up mess ${NC}"
	else
	    rm -rf ${objdir}/arch/arm64/boot/
	fi
	START=$(date +%s)
	echo -e ${LGR} "Generating Defconfig ${NC}"
	make -s ARCH=${ARCH} O=${objdir} ${CONFIG_FILE}

	echo -e ${LGR} "Building image ${NC}"
	if [ ${BUILD_GCC} == true ]; then
		cd ${kernel_dir}
		make -s -j${cpus} CROSS_COMPILE=${GCC} CROSS_COMPILE_ARM32=${GCC_32} \
		O=${objdir} Image.gz-dtb
	else
		POLLY="-mllvm -polly \
			-mllvm -polly-run-dce \
			-mllvm -polly-parallel \
			-mllvm -polly-run-inliner \
			-mllvm -polly-opt-fusion=max \
			-mllvm -polly-ast-use-context \
			-mllvm -polly-vectorizer=stripmine"

		# major version, usually 3 numbers (8.0.5 or 6.0.1)
		VERSION=$($CT --version | grep -wo "[0-9].[0-9].[0-9]")
		# revision (?), usually 6 numbers with 'r' before them
		REVISION=$($CT --version | grep -wo "r[0-9]*")
		COMPILER_NAME="Flash-Clang-$VERSION-$REVISION"

		cd ${kernel_dir}
		make -s -j${cpus} CC="${CT} ${POLLY}" CROSS_COMPILE=${GCC} \
		CROSS_COMPILE_ARM32=${GCC_32} KBUILD_COMPILER_STRING=${COMPILER_NAME} \
		O=${objdir} Image.gz-dtb
	fi
	END=$(date +%s)
}
function completion()
{
	cd ${objdir}
	COMPILED_IMAGE=arch/arm64/boot/Image.gz-dtb
	if [[ -f ${COMPILED_IMAGE} ]]; then
		mv -f ${COMPILED_IMAGE} ${builddir}/Image.gz-dtb_${DEVICE}
		echo -e ${LGR} "Build for Z2_$DEVICE competed in" \
			"$(format_time "${START}" "${END}")!${NC}"
		echo -e ${LGR} ${SEP}
	fi
}
parse_parameters "${@}"
make_image
completion
cd ${kernel_dir}
