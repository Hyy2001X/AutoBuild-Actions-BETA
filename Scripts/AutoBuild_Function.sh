#!/bin/bash
# AutoBuild Module by Hyy2001 <https://github.com/Hyy2001X/AutoBuild-Actions>
# AutoBuild Functions

Firmware-Diy_Before() {
	ECHO "[Firmware-Diy_Before] Start ..."
	CD ${GITHUB_WORKSPACE}/openwrt
	Diy_Core
	Home="${GITHUB_WORKSPACE}/openwrt"
	[[ -f ${GITHUB_WORKSPACE}/Openwrt.info ]] && source ${GITHUB_WORKSPACE}/Openwrt.info
	[[ ${Short_Firmware_Date} == true ]] && Compile_Date="$(echo ${Compile_Date} | cut -c1-8)"
	Author_Repository="$(grep "https://github.com/[a-zA-Z0-9]" ${GITHUB_WORKSPACE}/.git/config | cut -c8-100 | sed 's/^[ \t]*//g')"
	[[ -z ${Author} ]] && Author="$(echo "${Author_Repository}" | cut -d "/" -f4)"
	OP_Maintainer="$(echo "${Openwrt_Repository}" | cut -d "/" -f4)"
	OP_REPO_NAME="$(echo "${Openwrt_Repository}" | cut -d "/" -f5)"
	OP_BRANCH="$(Get_Branch)"
	if [[ ${OP_BRANCH} == master || ${OP_BRANCH} == main ]];then
		Openwrt_Version_Head="R$(date +%y.%m)-"
	else
		OP_BRANCH="$(echo ${OP_BRANCH} | egrep -o "[0-9]+.[0-9]+")"
		Openwrt_Version_Head="R${OP_BRANCH}-"
	fi
	case "${OP_Maintainer}/${OP_REPO_NAME}" in
	coolsnowwolf/lede)
		Version_File=package/lean/default-settings/files/zzz-default-settings
		zzz_Default_Version="$(egrep -o "R[0-9]+\.[0-9]+\.[0-9]+" ${Version_File})"
		CURRENT_Version="${zzz_Default_Version}-${Compile_Date}"
	;;
	immortalwrt/immortalwrt)
		Version_File=${base_files}/etc/openwrt_release
		CURRENT_Version="${Openwrt_Version_Head}${Compile_Date}"
	;;
	*)
		CURRENT_Version="${Openwrt_Version_Head}${Compile_Date}"
	;;
	esac
	while [[ -z ${x86_Test} ]];do
		x86_Test="$(egrep -o "CONFIG_TARGET.*DEVICE.*=y" .config | sed -r 's/CONFIG_TARGET_(.*)_DEVICE_(.*)=y/\1/')"
		[[ -n ${x86_Test} ]] && break
		x86_Test="$(egrep -o "CONFIG_TARGET.*Generic=y" .config | sed -r 's/CONFIG_TARGET_(.*)_Generic=y/\1/')"
		[[ -z ${x86_Test} ]] && break
	done
	[[ ${x86_Test} == x86_64 ]] && {
		TARGET_PROFILE=x86_64
	} || {
		TARGET_PROFILE="$(egrep -o "CONFIG_TARGET.*DEVICE.*=y" .config | sed -r 's/.*DEVICE_(.*)=y/\1/')"
	}
	[[ -z ${TARGET_PROFILE} ]] && ECHO "Unable to obtain the [TARGET_PROFILE] !"
	TARGET_BOARD="$(awk -F '[="]+' '/TARGET_BOARD/{print $2}' .config)"
	TARGET_SUBTARGET="$(awk -F '[="]+' '/TARGET_SUBTARGET/{print $2}' .config)"
	[[ -z ${Firmware_Format} || ${Firmware_Format} == false ]] && {
		case "${TARGET_BOARD}" in
		ramips | reltek | ipq40xx | ath79 | ipq807x)
			Firmware_Format=bin
		;;
		rockchip | x86)
			[[ $(cat ${Home}/.config) =~ CONFIG_TARGET_IMAGES_GZIP=y ]] && {
				Firmware_Format=img.gz || Firmware_Format=img
			}
		;;
		esac
	}
	case "${TARGET_BOARD}" in
	x86)
		AutoBuild_Firmware='AutoBuild-${OP_REPO_NAME}-${TARGET_PROFILE}-${CURRENT_Version}-${FW_Boot_Type}-$(Get_SHA256 $1).${Firmware_Format_Defined}'
	;;
	*)
		AutoBuild_Firmware='AutoBuild-${OP_REPO_NAME}-${TARGET_PROFILE}-${CURRENT_Version}-$(Get_SHA256 $1).${Firmware_Format_Defined}'
	;;
	esac
	cat >> ${Home}/VARIABLE_Main <<EOF
Author=${Author}
Github=${Author_Repository}
TARGET_PROFILE=${TARGET_PROFILE}
TARGET_BOARD=${TARGET_BOARD}
TARGET_SUBTARGET=${TARGET_SUBTARGET}
Firmware_Format=${Firmware_Format}
CURRENT_Version=${CURRENT_Version}
OP_Maintainer=${OP_Maintainer}
OP_BRANCH=${OP_BRANCH}
OP_REPO_NAME=${OP_REPO_NAME}
EOF
	cat >> ${Home}/VARIABLE_FILE <<EOF
Home=${Home}
Load_Common_Config=${Load_Common_Config}
PKG_Compatible="${INCLUDE_Obsolete_PKG_Compatible}"
Checkout_Virtual_Images="${Checkout_Virtual_Images}"
Firmware_Path=${Home}/bin/targets/${TARGET_BOARD}/${TARGET_SUBTARGET}
AutoBuild_Firmware=${AutoBuild_Firmware}
CustomFiles=${GITHUB_WORKSPACE}/CustomFiles
Scripts=${GITHUB_WORKSPACE}/Scripts
feeds_luci=${GITHUB_WORKSPACE}/openwrt/package/feeds/luci
feeds_pkgs=${GITHUB_WORKSPACE}/openwrt/package/feeds/packages
base_files=${GITHUB_WORKSPACE}/openwrt/package/base-files/files
Banner_Title="${Banner_Title}"
REGEX_Skip_Checkout="${REGEX_Skip_Checkout}"
EOF
	echo "$(cat ${Home}/VARIABLE_Main)" >> ${Home}/VARIABLE_FILE
	echo -e "### SYS-VARIABLE LIST ###\n$(cat ${Home}/VARIABLE_FILE)\n"
	ECHO "[Firmware-Diy_Before] Done."
}

Firmware-Diy_Main() {
	Firmware-Diy_Before
	ECHO "[Firmware-Diy_Main] Start ..."
	CD ${Home}
	source ${Home}/VARIABLE_FILE
	chmod +x -R ${Scripts}
	chmod 777 -R ${CustomFiles}
	[[ ${Load_CustomPackages_List} == true ]] && {
		bash -n ${Scripts}/AutoBuild_ExtraPackages.sh
		[[ ! $? == 0 ]] && ECHO "AutoBuild_ExtraPackages.sh syntax error,skip ..." || {
			. ${Scripts}/AutoBuild_ExtraPackages.sh
		}
	}
	if [[ ${INCLUDE_AutoBuild_Features} == true ]];then
		MKDIR ${base_files}/etc/AutoBuild
		cp ${Home}/VARIABLE_Main ${base_files}/etc/AutoBuild/Default_Variable
		Copy ${CustomFiles}/Depends/Custom_Variable ${base_files}/etc/AutoBuild
		Copy ${Scripts}/AutoBuild_Tools.sh ${base_files}/bin
		Copy ${Scripts}/AutoUpdate.sh ${base_files}/bin
		AddPackage svn lean luci-app-autoupdate Hyy2001X/AutoBuild-Packages/trunk
		Copy ${CustomFiles}/Depends/profile ${base_files}/etc
		Copy ${CustomFiles}/Depends/base-files-essential ${base_files}/lib/upgrade/keep.d
		AutoUpdate_Version=$(egrep -o "V[0-9].+" ${base_files}/bin/AutoUpdate.sh | awk 'NR==1')
		case "${OP_Maintainer}/${OP_REPO_NAME}" in
		coolsnowwolf/lede)
			Copy ${CustomFiles}/Depends/coremark.sh ${Home}/$(PKG_Finder d "package feeds" coremark)
			sed -i "s?iptables?#iptables?g" ${Version_File}
			sed -i "s?${zzz_Default_Version}?${zzz_Default_Version} @ ${Author} [${Display_Date}]?g" ${Version_File}
			sed -i "/dns_caching_dns/d" $(PKG_Finder d package luci-app-turboacc)/root/etc/config/turboacc
			echo "	option dns_caching_dns '223.5.5.5,114.114.114.114'" >> $(PKG_Finder d package luci-app-turboacc)/root/etc/config/turboacc
		;;
		immortalwrt/immortalwrt)
			Copy ${CustomFiles}/Depends/openwrt_release_${OP_Maintainer} ${base_files}/etc openwrt_release
			sed -i "s?ImmortalWrt?ImmortalWrt @ ${Author} [${Display_Date}]?g" ${Version_File}
		;;
		esac
		sed -i "s?By?By ${Author}?g" ${CustomFiles}/Depends/banner
		sed -i "s?Openwrt?Openwrt ${CURRENT_Version} / AutoUpdate ${AutoUpdate_Version}?g" ${CustomFiles}/Depends/banner
		[[ -n ${Banner_Title} ]] && sed -i "s?MSG?${Banner_Title}?g" ${CustomFiles}/Depends/banner
		case "${OP_Maintainer}/${OP_REPO_NAME}" in
		immortalwrt/immortalwrt)
			Copy ${CustomFiles}/Depends/banner ${Home}/$(PKG_Finder d package default-settings)/files openwrt_banner
		;;
		*)
			Copy ${CustomFiles}/Depends/banner ${base_files}/etc
		;;
		esac
	fi
	[[ ${INCLUDE_Argon} == true ]] && {
		case "${OP_Maintainer}/${OP_REPO_NAME}:${OP_BRANCH}" in
		coolsnowwolf/lede:master)
			AddPackage git lean luci-theme-argon jerrykuku 18.06
		;;
		[Ll]ienol/openwrt:main)
			AddPackage git other luci-theme-argon jerrykuku master
		;;
		[Ll]ienol/openwrt:19.07)
			AddPackage git other luci-theme-argon jerrykuku v2.2.5
		;;
		*)
			[[ ! ${OP_Maintainer}/${OP_REPO_NAME} = immortalwrt/immortalwrt ]] && {
				case "${OP_BRANCH}" in
				19.07)
					AddPackage git other luci-theme-argon jerrykuku v2.2.5
				;;
				21.02)
					AddPackage git other luci-theme-argon jerrykuku master
				;;
				18.06)
					AddPackage git other luci-theme-argon jerrykuku 18.06
				;;
				esac
			} || {
				ECHO "[${OP_Maintainer}/${OP_REPO_NAME}:${OP_BRANCH}]: Current Source is not supported ..."
				Argon_Skip=1
			}
		;;
		esac
		[[ ! ${Argon_Skip} == 1 ]] && AddPackage git other luci-app-argon-config jerrykuku master
	}
	[[ -n ${Before_IP_Address} ]] && Default_LAN_IP="${Before_IP_Address}"
	[[ -n ${Default_LAN_IP} && ${Default_LAN_IP} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && {
		Old_IP_Address=$(awk -F '[="]+' '/ipaddr:-/{print $3}' ${base_files}/bin/config_generate | awk 'NR==1')
		if [[ ! ${Default_LAN_IP} == ${Old_IP_Address} ]];then
			ECHO "Setting default IP Address to ${Default_LAN_IP} ..."
			sed -i "s/${Old_IP_Address}/${Default_LAN_IP}/g" ${base_files}/bin/config_generate
		fi
	}
	[[ ${INCLUDE_DRM_I915} == true && ${TARGET_BOARD} == x86 ]] && {
		Copy ${CustomFiles}/Depends/DRM-I915 ${Home}/target/linux/x86
		for X in $(ls -1 target/linux/x86 | grep "config-"); do echo -e "\n$(cat target/linux/x86/DRM-I915)" >> target/linux/x86/${X}; done
	}
	case "${OP_Maintainer}/${OP_REPO_NAME}" in
	coolsnowwolf/lede)
		ECHO "Downloading [ShadowSocksR Plus+] for coolsnowwolf/lede ..."
		AddPackage git other helloworld fw876 master
		sed -i 's/143/143,8080,8443/' $(PKG_Finder d package luci-app-ssr-plus)/root/etc/init.d/shadowsocksr
	;;
	immortalwrt/immortalwrt)
		:
	;;
	openwrt/openwrt)
		:
	;;
	[Ll]ienol/openwrt)
		:
	;;
	esac
	ECHO "[Firmware-Diy_Main] Done."
}

Firmware-Diy_Other() {
	ECHO "[Firmware-Diy_Other] Start ..."
	CD ${GITHUB_WORKSPACE}/openwrt
	source ${GITHUB_WORKSPACE}/openwrt/VARIABLE_FILE
	case "${PKG_Compatible}" in
	19.07)
		OP_BRANCH=19.07
		Force_mode=1
		PKG_Compatible=true
	;;
	21.02)
		OP_BRANCH=21.02
		Force_mode=1
		PKG_Compatible=true
	;;
	esac
	if [[ ${PKG_Compatible} == true ]];then
		if [[ ${OP_Maintainer} == openwrt || ${OP_Maintainer} == [Ll]ienol || ${Force_mode} == 1 ]];then
			ECHO "Start running Obsolete_Package_Compatible Script ..."
			case "${OP_BRANCH}" in
			19.07 | 21.02 | main)
				[[ ${OP_BRANCH} == main ]] && OP_BRANCH=21.02
				cat >> .config <<EOF

# CONFIG_PACKAGE_dnsmasq is not set
CONFIG_PACKAGE_dnsmasq-full=y
# CONFIG_PACKAGE_wpad-wolfssl is not set
CONFIG_PACKAGE_wpad-openssl=y
EOF
				Copy ${CustomFiles}/Patches/0003-upx-ucl-${OP_BRANCH}.patch ${Home}
				cat 0003-upx-ucl-${OP_BRANCH}.patch | patch -p1 > /dev/null 2>&1
				AddPackage svn feeds/packages golang coolsnowwolf/packages/trunk/lang
				ECHO "Starting to convert zh-cn translation files to zh_Hans ..."
				cd package && ${Scripts}/Convert_Translation.sh && cd -
			;;
			*)
				ECHO "[${OP_BRANCH}]: Current Branch is not supported ..."
			;;
			esac
		else
			ECHO "[${OP_Maintainer}]: Current Source_Maintainer is not supported ..."
		fi
	fi
	if [[ ${Load_Common_Config} == true ]];then
		if [[ -s $GITHUB_WORKSPACE/Configs/Common || ! "$(cat .config)" =~ "## TEST" ]];then
			ECHO "Merging [Configs/Common] to .config ..."
			echo -e "\n$(cat $GITHUB_WORKSPACE/Configs/Common)" >> .config
		fi
		sed -i '/## TEST/d' .config >/dev/null 2>&1
	fi
	ECHO "[Firmware-Diy_Other] Done."
}

Firmware-Diy_End() {
	ECHO "[Firmware-Diy_End] Start ..."
	CD ${GITHUB_WORKSPACE}/openwrt
	source ${GITHUB_WORKSPACE}/openwrt/VARIABLE_FILE
	MKDIR bin/Firmware
	SHA256_File="${Firmware_Path}/sha256sums"
	cd ${Firmware_Path}
	echo -e "### FIRMWARE OUTPUT ###\n$(ls -1 | egrep -v "packages|buildinfo|sha256sums|manifest")\n"
	case "${TARGET_BOARD}" in
	x86)
		[[ ${Checkout_Virtual_Images} == true ]] && {
			Process_Firmware $(List_Format)
		} || {
			Process_Firmware ${Firmware_Format}
		}
	;;
	*)
		Process_Firmware ${Firmware_Format}
	;;
	esac
	[[ $(ls) =~ 'AutoBuild-' ]] && cp -a AutoBuild-* ${Home}/bin/Firmware
	cd -
	echo "[$(date "+%H:%M:%S")] Actions Avaliable: $(df -h | grep "/dev/root" | awk '{printf $4}')"
	ECHO "[Firmware-Diy_End] Done."
}

Process_Firmware() {
	while [[ $1 ]];do
		Process_Firmware_Core $1 $(List_Firmware $1)
		shift
	done
}

Process_Firmware_Core() {
	Firmware_Format_Defined=$1
	shift
	while [[ $1 ]];do
		case "${TARGET_BOARD}" in
		x86)
			[[ $1 =~ efi ]] && {
				FW_Boot_Type=UEFI
			} || {
				FW_Boot_Type=Legacy
			}
		;;
		esac
		eval AutoBuild_Firmware=$(Get_Variable AutoBuild_Firmware=)
		[[ -f $1 ]] && {
			ECHO "Copying [$1] to [${AutoBuild_Firmware}] ..."
			cp -a $1 ${AutoBuild_Firmware}
		} || ECHO "Unable to access [${AutoBuild_Firmware}] ..."
		shift
	done
}

List_Firmware() {
	[[ -z $* ]] && {
		List_REGEX | while read X;do
			echo $X | cut -d "*" -f2
		done
	} || {
		while [[ $1 ]];do
			for X in $(echo $(List_REGEX));do
				[[ $X == *$1 ]] && echo "$X" | cut -d "*" -f2
			done
			shift
		done
	}
}

List_Format() {
	echo "$(List_REGEX | cut -d "*" -f2 | cut -d "." -f2-3)" | sort | uniq
}

List_REGEX() {
	[[ -n ${REGEX_Skip_Checkout} ]] && {
		egrep -v "${REGEX_Skip_Checkout}" ${SHA256_File} | tr -s '\n'
	} || egrep -v "packages|buildinfo|sha256sums|manifest|kernel|rootfs|factory" ${SHA256_File} | tr -s '\n'
}

Get_SHA256() {
	List_REGEX | grep "$1" | cut -c1-5
}

Get_Variable() {
	grep "$1" ${GITHUB_WORKSPACE}/openwrt/VARIABLE_FILE | cut -c$(echo $1 | wc -c)-200 | cut -d ":" -f2
}

Get_Branch() {
    git -C $(pwd) rev-parse --abbrev-ref HEAD | grep -v HEAD || \
    git -C $(pwd) describe --exact-match HEAD || \
    git -C $(pwd) rev-parse HEAD
}

ECHO() {
	echo "[$(date "+%H:%M:%S")] $*"
}

PKG_Finder() {
	local Result
	[[ $# -ne 3 ]] && {
		ECHO "Usage: PKG_Finder <f | d> Search_Path Target_Name/Target_Path"
		return 0
	}
	Result=$(find $2 -name $3 -type $1 -exec echo {} \;)
	[[ -n ${Result} ]] && echo "${Result}"
}

CD() {
	cd $1
	[[ ! $? == 0 ]] && ECHO "Unable to enter target directory $1 ..." || ECHO "Current runnning directory: $(pwd)"
}

MKDIR() {
	while [[ $1 ]];do
		if [[ ! -d $1 ]];then
			mkdir -p $1 || ECHO "Failed to create target directory: [$1] ..."
		fi
		shift
	done
}

AddPackage() {
	[[ $# -lt 4 ]] && {
		ECHO "Syntax error: [$#] [$*]"
		return 0
	}
	PKG_PROTO=$1
	case "${PKG_PROTO}" in
	git | svn)
		:
	;;
	*)
		ECHO "Unknown content: ${PKG_PROTO}"
		return 0
	;;
	esac
	PKG_DIR=$2
	[[ ! ${PKG_DIR} =~ ${GITHUB_WORKSPACE} ]] && PKG_DIR=package/${PKG_DIR}
	PKG_NAME=$3
	REPO_URL="https://github.com/$4"
	REPO_BRANCH=$5
	[[ ${REPO_URL} =~ "${OP_Maintainer}/${OP_REPO_NAME}" ]] && return 0

	MKDIR ${PKG_DIR}
	[[ -d ${PKG_DIR}/${PKG_NAME} ]] && {
		ECHO "Removing old package: [${PKG_NAME}] ..."
		rm -rf ${PKG_DIR}/${PKG_NAME}
	}
	ECHO "Checking out package [${PKG_NAME}] to ${PKG_DIR} ..."
	case "${PKG_PROTO}" in
	git)
		[[ -z ${REPO_BRANCH} ]] && {
			ECHO "WARNING: Syntax missing <branch> ,using default branch: [master]"
			REPO_BRANCH=master
		}
		PKG_URL="$(echo ${REPO_URL}/${PKG_NAME} | sed s/[[:space:]]//g)"
		git clone -b ${REPO_BRANCH} ${PKG_URL} ${PKG_NAME} > /dev/null 2>&1
	;;
	svn)
		svn checkout ${REPO_URL}/${PKG_NAME} ${PKG_NAME} > /dev/null 2>&1
	;;
	esac
	[[ -f ${PKG_NAME}/Makefile || -n $(ls -A ${PKG_NAME}) ]] && {
		mv -f "${PKG_NAME}" "${PKG_DIR}"
		[[ $? == 0 ]] && ECHO "Done."
	} || ECHO "Failed to download package ${PKG_NAME} ..."
}

Copy() {
	[[ ! $# =~ [23] ]] && {
		ECHO "Syntax error: [$#] [$*]"
		return 0
	}
	[[ ! -f $1 ]] && [[ ! -d $1 ]] && {
		ECHO "$1: No such file or directory ..."
		return 0
	}
	MKDIR $2
	if [[ -z $3 ]];then
		ECHO "Copying $1 to $2 ..."
		cp -a $1 $2
	else
		ECHO "Copy and renaming $1 to $2/$3 ..."
		cp -a $1 $2/$3
	fi
	[[ $? == 0 ]] && ECHO "Done." || ECHO "Failed."
}