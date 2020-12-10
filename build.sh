#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (C) 2018-2020 Yaroslav Furman (YaroST12)

# Fucking folders
kernel_dir="${PWD}"
builddir="${kernel_dir}/build"

# Fucking versioning
branch_name=$(git rev-parse --abbrev-ref HEAD)
last_commit=$(git rev-parse --verify --short=10 HEAD)
version="-${branch_name}/${last_commit}"
export KBUILD_BUILD_USER="yaro"

# Fucking arch and clang triple
export ARCH="arm64"
export CLANG_TRIPLE="aarch64-linux-gnu-"

# Fucking toolchains
GCC_32="${TTHD}/toolchains/arm-linux-gnueabi/bin/arm-linux-gnueabi-"
CLANG="${TTHD}/toolchains/clang/clang-r399163b/"
CT_BIN="${CLANG}/bin/"
CT="${CT_BIN}/clang"
objdir="${kernel_dir}/out"
export LD_LIBRARY_PATH=${CLANG}/lib64:$LD_LIBRARY_PATH
export THINLTO_CACHE=${PWD}/../thinlto_cache

# Dank gcc flags haha
FUNNY_FLAGS_HEH=" -finline-functions \
		-finline-small-functions \
		-findirect-inlining \
		-finline-limit=90 \
		--param=inline-min-speedup=5 \
		--param=inline-unit-growth=100"

# Which image type to build
TARGET_IMAGE="Image.gz"

# Colors
NC='\033[0m'
RED='\033[0;31m'
LRD='\033[1;31m'
LGR='\033[1;32m'
YEL='\033[1;33m'

# CPUs
cpus=`expr $(nproc --all) - 1`

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
	BUILD_GCC=false
	BUILD_CLEAN=false
	BUILD_LTO=false
	#CONFIG_FILE="vendor/neutrino_defconfig"
	#CONFIG_FILE="raphael_defconfig"
	#CONFIG_FILE="vendor/sdmsteppe_defconfig"
	CONFIG_FILE="surya_defconfig"
	VERBOSE=true
	# Cleanup strings
	VERSION=""
	REVISION=""
	COMPILER_NAME=""

	while [[ ${#} -ge 1 ]]; do
		case ${1} in
			"-g"|"--gcc")
				BUILD_GCC=true ;;
			"-c"|"--clean")
				BUILD_CLEAN=true ;;
			"-v"|"--verbose")
				VERBOSE=true ;;
			"-dn"|"--donot")
				FUNNY_FLAGS_HEH="" ;;
			"-l"|"--lto")
				BUILD_LTO=true ;;
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
		rm -rf ${objdir}/*
	fi

	rm -rf "${objdir}/arch/arm64/boot/dts/*"
	# Warning avoidance, duh
	mkdir -p "${objdir}/arch/arm64/boot/dts/" > /dev/null 2>&1

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

	if [ ${BUILD_LTO} == true ]; then
		print ${LGR} "Enabling ThinLTO"
		# Check if ThinLTO support is present in defconfig
		# a bit naive but oh well, good enough
		SUPPORTS_CLANG=$(grep CONFIG_ARCH_SUPPORTS_THINLTO ${objdir}/.config)
		if [[ ${SUPPORTS_CLANG} ]]; then
			# Enable LTO and ThinLTO
			for i in THINLTO LTO_CLANG; do
				./scripts/config --file ${objdir}/.config -e $i
			done
			# Disable LTO_NONE to avoid a warning message
			./scripts/config --file ${objdir}/.config -d LTO_NONE
			# Regen defconfig with all our changes (again)
			make -s -j${cpus} ARCH=${ARCH} O=${objdir} olddefconfig
		else
			print ${RED} "ThinLTO support not present"
		fi
	fi

	if [ ${BUILD_GCC} == true ]; then
		cd ${kernel_dir}
		print ${LGR} "Compiling with GCC"
		make -s -j${cpus} \
		AR="aarch64-linux-gnu-ar" \
		NM="aarch64-linux-gnu-nm" \
		OBJCOPY="aarch64-linux-gnu-objcopy" \
		OBJDUMP="aarch64-linux-gnu-objdump" \
		STRIP="aarch64-linux-gnu-strip" \
		LD="aarch64-linux-gnu-ld" \
		CC="aarch64-linux-gnu-gcc ${FUNNY_FLAGS_HEH}" \
		CROSS_COMPILE_ARM32=${GCC_32} \
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
			COMPILER_NAME="Clang"
		fi
		print ${LGR} "Compiling with ${YEL}${COMPILER_NAME}"
		cd ${kernel_dir}
		PATH=${CT_BIN}:${PATH} \
		make -s -j${cpus} CC="clang -ferror-limit=1 -g" \
		AR="llvm-ar" \
		NM="llvm-nm" \
		OBJCOPY="llvm-objcopy" \
		OBJDUMP="llvm-objdump" \
		STRIP="llvm-strip" \
		LD="ld.lld" \
		CROSS_COMPILE="aarch64-linux-gnu-" \
		CROSS_COMPILE_ARM32=${GCC_32} \
		KBUILD_COMPILER_STRING="${COMPILER_NAME}" \
		O=${objdir} ${TARGET_IMAGE}
	fi
#make -s -j${cpus} CC="clang -ferror-limit=1 -g" \
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
#		if [ "${SIZE}" -gt "12556" ]; then
#			print ${YEL} "Image size too big, it might not boot"
#		fi
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
