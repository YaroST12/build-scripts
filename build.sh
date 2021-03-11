#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (C) 2018-2021 Yaroslav Furman (YaroST12)

# Fucking folders
kernel_dir="${PWD}"
builddir="${kernel_dir}/build"

# Fucking versioning (unused)
# branch_name=$(git rev-parse --abbrev-ref HEAD)
# last_commit=$(git rev-parse --verify --short=10 HEAD)
# version="-${branch_name}/${last_commit}"
export KBUILD_BUILD_USER="yaro"

# Fucking arch and clang triple
export ARCH="arm64"

# Which image type to build
TARGET_IMAGE="Image.gz-dtb"

# Fucking toolchains
GCC_32="${TTHD}/toolchains/arm32-gcc/bin/arm-eabi-"
CLANG="${TTHD}/toolchains/clang/"
#CLANG="${TTHD}/toolchains/aosp-clang/clang-r399163b/"
CT_BIN="${CLANG}/bin/"
CT="${CT_BIN}/clang"
objdir="${kernel_dir}/out"
export THINLTO_CACHE=${PWD}/../thinlto_cache

# Dank gcc flags haha
FUNNY_FLAGS_PRESET_GCC=" \
	--param max-inline-insns-single=600 \
	--param max-inline-insns-auto=750 \
	--param large-stack-frame=12288 \
	--param inline-min-speedup=5 \
	--param inline-unit-growth=60"

FUNNY_FLAGS_PRESET_CLANG=" \
	-mllvm -inline-threshold=600 \
	-mllvm -inlinehint-threshold=750"

# Colors
NC='\033[0m'
RED='\033[0;31m'
LRD='\033[1;31m'
LGR='\033[1;32m'
YEL='\033[1;33m'

# CPUs
cpus=`expr $(nproc --all)`

# Separator
SEP="######################################"

# Print
function print()
{
	echo -e ${1} "${2}${NC}"
}

# Fucking die
function die()
{
	print ${RED} ${SEP}
	print ${RED} "${1}"
	print ${RED} ${SEP}
	exit
}

function parse_parameters()
{
	PARAMS="${*}"
	# Default params
	BUILD_GCC=true
	BUILD_CLEAN=false
	BUILD_LTO=false
	#CONFIG_FILE="vendor/neutrino_defconfig"
	#CONFIG_FILE="raphael_defconfig"
	#CONFIG_FILE="vendor/sdmsteppe_defconfig"
	CONFIG_FILE="surya_defconfig"
	VERBOSE=true
	RELEASE=false
	# Cleanup strings
	VERSION=""
	REVISION=""
	COMPILER_NAME=""
	FUNNY_FLAGS_HEH=""

	while [[ ${#} -ge 1 ]]; do
		case ${1} in
			"-g"|"--gcc")
				BUILD_GCC=true ;;
			"-c"|"--clean")
				BUILD_CLEAN=true ;;
			"-v"|"--verbose")
				VERBOSE=true ;;
			"-l"|"--lto")
				BUILD_LTO=true
				BUILD_GCC=false 
				FUNNY_FLAGS_HEH=${FUNNY_FLAGS_PRESET_CLANG} ;;
			"-gl"|"--glto")
				BUILD_LTO=true
				BUILD_GCC=true 
				FUNNY_FLAGS_HEH=${FUNNY_FLAGS_PRESET_GCC} ;;
			"-dn"|"--donot")
				FUNNY_FLAGS_HEH="" ;;
			"-r")
				RELEASE=true ;;
            *) die "Invalid parameter specified!" ;;
		esac

		shift
	done
	print ${LGR} ${SEP}
	print ${LGR} "Compilation started"
}

# Formats the time for the end
function format_time()
{
	MINS=$(((${2} - ${1}) / 60))
	SECS=$(((${2} - ${1}) % 60))

	TIME_STRING+="${MINS}:${SECS}"

	echo "${TIME_STRING}"
}

function make_image()
{
	# After we run savedefconfig in sources folder
	if [[ -f ${kernel_dir}/.config && ${BUILD_CLEAN} == false ]]; then
		print ${LGR} "Removing misplaced defconfig... "
		make -s -j${cpus} mrproper
	fi
	# Needed to make sure we get dtb built and added to kernel image properly
	# Cleanup existing build files
	if [ ${BUILD_CLEAN} == true ]; then
		print ${LGR} "Cleaning up mess... "
		# Warning avoidance, duh
		# mkdir -p "${objdir}/arch/arm64/boot/dts/" > /dev/null 2>&1
		make -s -j${cpus} mrproper O=${objdir}
	fi

	# Ensure that we regenerate dtb EVERY BLOODY TIME
	# rm -rf "${objdir}/arch/arm64/boot/dts/qcom"

	# Warning avoidance, duh
	# mkdir -p "${objdir}/arch/arm64/boot/dts/" > /dev/null 2>&1

	START=$(date +%s)
	print ${LGR} "Generating Defconfig "
	make -s -j${cpus} ARCH=${ARCH} O=${objdir} ${CONFIG_FILE}

	if [ ! $? -eq 0 ]; then
		die "Defconfig generation failed"
	fi

# LEAVE IT HERE FOR KERNELS THAT DON'T DO IT AUTOMATICALLY
#	if [ ${BUILD_GCC} == true ]; then
#		print ${LGR} "Killing Clang specific crap"
#		for i in LTO_CLANG CFI_CLANG SHADOW_CALL_STACK RELR LD_LLD; do
#			./scripts/config --file ${objdir}/.config -d $i
#		done
#		make -s -j${cpus} ARCH=${ARCH} O=${objdir} olddefconfig
#	fi

	if [[ ${BUILD_LTO} == true && ${BUILD_GCC} == true ]]; then
		print ${LGR} "Enabling GCC LTO"
		# Check if LDFINAL is present in Makefile
		# a bit naive but oh well, good enough
		SUPPORTS_LTO_GCC=$(grep LDFINAL ${kernel_dir}/Makefile)
		if [[ ${SUPPORTS_LTO_GCC} ]]; then
			# Enable LTO and ThinLTO
			for i in LTO LTO_MENU LD_DEAD_CODE_DATA_ELIMINATION; do
				./scripts/config --file ${objdir}/.config -e $i
			done
			if [ ${RELEASE} == false ]; then
				for i in KALLSYMS; do
					./scripts/config --file ${objdir}/.config -d $i
				done
			fi
			# Regen defconfig with all our changes (again)
			make -s -j${cpus} ARCH=${ARCH} O=${objdir} olddefconfig
		else
			print ${RED} "GCC LTO support not present"
		fi		
	elif [ ${BUILD_LTO} == true ]; then
		print ${LGR} "Enabling ThinLTO"
		# Check if ThinLTO support is present in defconfig
		# a bit naive but oh well, good enough
		SUPPORTS_CLANG=$(grep CONFIG_ARCH_SUPPORTS_THINLTO ${objdir}/.config)
		if [[ ${SUPPORTS_CLANG} ]]; then
			# Enable LTO and ThinLTO
			for i in THINLTO LTO_CLANG LD_LLD; do
				./scripts/config --file ${objdir}/.config -e $i
			done
			for i in LTO_NONE LD_GOLD LD_BFD; do
				./scripts/config --file ${objdir}/.config -d $i
			done
			# Regen defconfig with all our changes (again)
			make -s -j${cpus} ARCH=${ARCH} O=${objdir} olddefconfig
		else
			print ${RED} "ThinLTO support not present"
		fi
	fi

	if [ ${BUILD_GCC} == true ]; then
		cd ${kernel_dir}
		VERSION=$(gcc --version | grep -wom 1 "[0-99][0-99].[0-99].[0-99]")
		COMPILER_NAME="GCC-${VERSION}"
		if [ ${BUILD_LTO} == true ]; then
			COMPILER_NAME+="+LTO"
		fi
		print ${LGR} "Compiling with ${YEL}${COMPILER_NAME}"
		make -s -j${cpus} \
		AR="${CROSS_COMPILE}gcc-ar" \
		NM="${CROSS_COMPILE}gcc-nm" \
		STRIP="${CROSS_COMPILE}gcc-strip" \
		OBJCOPY="aarch64-linux-gnu-objcopy" \
		OBJDUMP="aarch64-linux-gnu-objdump" \
		LD="aarch64-linux-gnu-ld" \
		CC="aarch64-linux-gnu-gcc ${FUNNY_FLAGS_HEH}" \
		CROSS_COMPILE="aarch64-linux-gnu-" \
		CROSS_COMPILE_ARM32=${GCC_32} \
		KBUILD_COMPILER_STRING="${COMPILER_NAME}" \
		O=${objdir} ${TARGET_IMAGE}
	else
		# major version, usually 3 numbers (8.0.5 or 6.0.1)
		VERSION=$($CT --version | grep -wom 1 "[0-99][0-99].[0-99].[0-99]")
		# revision, usually 6 numbers with 'r' before them.
		# can also have a letter at the end.
		REVISION=$($CT --version | grep -wom 1 "r[0-99]*[a-zA-Z0-9]")
		if [[ ${REVISION} ]]; then
			COMPILER_NAME="Clang-${VERSION}-${REVISION}"
		else
			COMPILER_NAME="Clang-${VERSION}"
		fi
		if [ ${BUILD_LTO} == true ]; then
			COMPILER_NAME+="+LTO"
		fi
		print ${LGR} "Compiling with ${YEL}${COMPILER_NAME}"
		cd ${kernel_dir}
		PATH=${CT_BIN}:${PATH} \
		make -s -j${cpus} \
		AR="llvm-ar" \
		NM="llvm-nm" \
		STRIP="llvm-strip" \
		OBJCOPY="llvm-objcopy" \
		OBJDUMP="llvm-objdump" \
		LD="ld.lld" \
		CC="clang ${FUNNY_FLAGS_HEH}" \
		CROSS_COMPILE="aarch64-linux-gnu-" \
		CROSS_COMPILE_ARM32="arm-linux-gnueabi-" \
		KBUILD_COMPILER_STRING="${COMPILER_NAME}" \
		O=${objdir} ${TARGET_IMAGE}
	fi

	completion "${START}" "$(date +%s)"
}

function completion()
{
	cd ${objdir}
	COMPILED_IMAGE=arch/arm64/boot/${TARGET_IMAGE}
	TIME=$(format_time "${1}" "${2}")
	if [[ -f ${COMPILED_IMAGE} ]]; then
		mv -f ${COMPILED_IMAGE} ${builddir}/${TARGET_IMAGE}
		print ${LGR} "Build competed in ${TIME}!"
		SIZE=$(ls -s ${builddir}/${TARGET_IMAGE} | sed 's/ .*//')
		if [ ${VERBOSE} == true ]; then
			print ${LGR} "Version: ${YEL}F1xy${version}"
			print ${LGR} "Img size: ${YEL}${SIZE}K"
		fi
		print ${LGR} ${SEP}
	else
		print ${RED} ${SEP}
		print ${RED} "Something went wrong"
		print ${RED} ${SEP}
	fi
}
parse_parameters "${@}"
make_image
cd ${kernel_dir}
