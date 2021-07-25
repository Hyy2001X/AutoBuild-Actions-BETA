#!/bin/bash
# AutoBuild Module by Hyy2001 <https://github.com/Hyy2001X/AutoBuild-Actions>
# AutoBuild Functions

Firmware-Diy_Before() {
	TIME "[Firmware-Diy_Before]"
	Diy_Core
	Home="${GITHUB_WORKSPACE}/openwrt"
	[[ -f ${GITHUB_WORKSPACE}/Openwrt.info ]] && source ${GITHUB_WORKSPACE}/Openwrt.info
	[[ ${Short_Firmware_Date} == true ]] && Compile_Date="$(echo ${Compile_Date} | cut -c1-8)"
	Author_Repository="$(grep "https://github.com/[a-zA-Z0-9]" ${GITHUB_WORKSPACE}/.git/config | cut -c8-100 | sed 's/^[ \t]*//g')"
	[[ -z ${Author} ]] && Author="$(echo "${Author_Repository}" | cut -d "/" -f4)"
	OP_Maintainer="$(echo "${Openwrt_Repository}" | cut -d "/" -f4)"
	OP_REPO_NAME="$(echo "${Openwrt_Repository}" | cut -d "/" -f5)"
	OP_BRANCH="$(Get_Branches)"
	if [[ ${OP_BRANCH} == master || ${OP_BRANCH} == main ]];then
		Openwrt_Version_Head="R$(date +%y.%m)-"
	else
		OP_BRANCH="$(echo ${OP_BRANCH} | egrep -o "[0-9]+.[0-9]+")"
		Openwrt_Version_Head="R${OP_BRANCH}-"
	fi
	case "${OP_Maintainer}" in
	coolsnowwolf)
		Version_File=package/lean/default-settings/files/zzz-default-settings
		zzz_Default_Version="$(egrep -o "R[0-9]+\.[0-9]+\.[0-9]+" ${Version_File})"
		CURRENT_Version="${zzz_Default_Version}-${Compile_Date}"
	;;
	immortalwrt)
		Version_File=package/base-files/files/etc/openwrt_release
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
	[[ -z ${TARGET_PROFILE} ]] && TIME "Unable to obtain the [TARGET_PROFILE] !"
	TARGET_BOARD="$(awk -F '[="]+' '/TARGET_BOARD/{print $2}' .config)"
	TARGET_SUBTARGET="$(awk -F '[="]+' '/TARGET_SUBTARGET/{print $2}' .config)"
	case "${TARGET_BOARD}" in
	ramips | reltek | ipq40xx | ath79 | ipq807x)
		Firmware_Type=bin
	;;
	rockchip | x86)
		[[ $(cat ${Home}/.config) =~ CONFIG_TARGET_IMAGES_GZIP=y ]] && {
			Firmware_Type=img.gz || Firmware_Type=img
		}
	;;
	esac
	case "${TARGET_BOARD}" in
	x86)
		AutoBuild_Firmware='AutoBuild-${OP_REPO_NAME}-${TARGET_PROFILE}-${CURRENT_Version}-${FW_Boot_Type}-$(Get_sha256 $1).${Firmware_Type_Defined}'
		REGEX_Firmware='AutoBuild-${OP_REPO_NAME}-${TARGET_PROFILE}-R[0-9.]+-[0-9]+-${x86_Boot}.[0-9a-z]+.${Firmware_Type}'
	;;
	*)
		AutoBuild_Firmware='AutoBuild-${OP_REPO_NAME}-${TARGET_PROFILE}-${CURRENT_Version}-$(Get_sha256 $1).${Firmware_Type_Defined}'
		REGEX_Firmware='AutoBuild-${OP_REPO_NAME}-${TARGET_PROFILE}-R[0-9.]+-[0-9]+-[0-9a-z]+.${Firmware_Type}'
	;;
	esac
	cat >> VARIABLE_Main <<EOF
Author=${Author}
Github=${Author_Repository}
TARGET_PROFILE=${TARGET_PROFILE}
TARGET_BOARD=${TARGET_BOARD}
TARGET_SUBTARGET=${TARGET_SUBTARGET}
Firmware_Type=${Firmware_Type}
CURRENT_Version=${CURRENT_Version}
OP_Maintainer=${OP_Maintainer}
OP_BRANCH=${OP_BRANCH}
OP_REPO_NAME=${OP_REPO_NAME}
REGEX_Firmware=${REGEX_Firmware}
EOF
	cat >> VARIABLE_FILE <<EOF
Home=${Home}
PKG_Compatible=${INCLUDE_Obsolete_PKG_Compatible}
Checkout_Virtual_Images=${Checkout_Virtual_Images}
Firmware_Path=${Home}/bin/targets/${TARGET_BOARD}/${TARGET_SUBTARGET}
AutoBuild_Firmware=${AutoBuild_Firmware}
EOF
	echo "$(cat VARIABLE_Main)" >> VARIABLE_FILE
	echo -e "### SYS-VARIABLE LIST ###\n$(cat VARIABLE_FILE)\n"
}

Firmware-Diy_Main() {
	Firmware-Diy_Before
	TIME "[Firmware-Diy_Main]"
	mkdir -p package/base-files/files/etc/AutoBuild
	[ -f VARIABLE_Main ] && cp VARIABLE_Main package/base-files/files/etc/AutoBuild/Default_Variable
	Copy CustomFiles/Depends/Custom_Variable package/base-files/files/etc/AutoBuild
	chmod +x -R ${GITHUB_WORKSPACE}/Scripts
	chmod 777 -R ${GITHUB_WORKSPACE}/CustomFiles
	[[ ${Load_CustomPackages_List} == true ]] && {
		bash -n ${GITHUB_WORKSPACE}/Scripts/AutoBuild_ExtraPackages.sh
		[[ ! $? == 0 ]] && TIME "AutoBuild_ExtraPackages.sh syntax error,skip ..." || {
			. ${GITHUB_WORKSPACE}/Scripts/AutoBuild_ExtraPackages.sh
		}
	}
	[[ ${INCLUDE_AutoBuild_Features} == true ]] && {
		Copy Scripts/AutoBuild_Tools.sh package/base-files/files/bin
		Copy Scripts/AutoUpdate.sh package/base-files/files/bin
		AddPackage git lean luci-app-autoupdate Hyy2001X main
	}
	[[ ${INCLUDE_Argon} == true ]] && {
		case "${OP_Maintainer},${OP_BRANCH}" in
		coolsnowwolf,master)
			AddPackage git lean luci-theme-argon jerrykuku 18.06
		;;
		[Ll]ienol,main)
			AddPackage git other luci-theme-argon jerrykuku master
		;;
		[Ll]ienol,19.07)
			AddPackage git other luci-theme-argon jerrykuku v2.2.5
		;;
		*)
			[[ ${OP_Maintainer} != immortalwrt ]] && {
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
			} || :
		;;
		esac
		AddPackage git other luci-app-argon-config jerrykuku
	}
	[[ -n ${Before_IP_Address} ]] && Default_LAN_IP="${Before_IP_Address}"
	[[ -n ${Default_LAN_IP} && ${Default_LAN_IP} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && {
		Old_IP_Address=$(awk -F '[="]+' '/ipaddr:-/{print $3}' package/base-files/files/bin/config_generate | awk 'NR==1')
		if [[ ! ${Default_LAN_IP} == ${Old_IP_Address} ]];then
			TIME "Setting default IP Address to ${Default_LAN_IP} ..."
			sed -i "s/${Old_IP_Address}/${Default_LAN_IP}/g" package/base-files/files/bin/config_generate
		fi
	}
	[[ ${INCLUDE_DRM_I915} == true && ${TARGET_BOARD} == x86 ]] && {
		Copy CustomFiles/Depends/DRM-I915 target/linux/x86
		for X in $(ls -1 target/linux/x86 | grep "config-"); do echo -e "\n$(cat target/linux/x86/DRM-I915)" >> target/linux/x86/${X}; done
	}
	[ -f package/base-files/files/bin/AutoUpdate.sh ] && {
		AutoUpdate_Version=$(egrep -o "V[0-9].+" package/base-files/files/bin/AutoUpdate.sh | awk 'END{print}')
	} || AutoUpdate_Version=OFF
	Copy CustomFiles/Depends/profile package/base-files/files/etc
	Copy CustomFiles/Depends/base-files-essential package/base-files/files/lib/upgrade/keep.d
	case "${OP_Maintainer}" in
	coolsnowwolf)
		sed -i "/dns_caching_dns/d" $(PKG_Finder d package luci-app-turboacc)/root/etc/config/turboacc
		echo "	option dns_caching_dns '223.5.5.5,114.114.114.114'" >> $(PKG_Finder d package luci-app-turboacc)/root/etc/config/turboacc
		Copy CustomFiles/Depends/coremark.sh $(PKG_Finder d "package feeds" coremark)
		Copy CustomFiles/Depends/cpuinfo_x86 $(PKG_Finder d package autocore | awk 'NR==1')/files/x86/sbin cpuinfo
		AddPackage git other helloworld fw876 master
		sed -i 's/143/143,8080/' $(PKG_Finder d package luci-app-ssr-plus)/root/etc/init.d/shadowsocksr
		sed -i "s?iptables?#iptables?g" ${Version_File}
		sed -i "s?${zzz_Default_Version}?${zzz_Default_Version} @ ${Author} [${Display_Date}]?g" ${Version_File}
	;;
	immortalwrt)
		sed -i "/dns_caching_dns/d" $(PKG_Finder d "package feeds" luci-app-turboacc)/root/etc/config/turboacc
		echo "	option dns_caching_dns '223.5.5.5,114.114.114.114'" >> $(PKG_Finder d "package feeds" luci-app-turboacc)/root/etc/config/turboacc
		Copy CustomFiles/Depends/openwrt_release_${OP_Maintainer} package/base-files/files/etc openwrt_release
		Copy CustomFiles/Depends/cpuinfo_x86 $(PKG_Finder d package autocore | awk 'NR==1')/files/x86/sbin cpuinfo
		sed -i "s?ImmortalWrt?ImmortalWrt @ ${Author} [${Display_Date}]?g" ${Version_File}
	;;
	esac
	case "${OP_Maintainer}" in
	immortalwrt)
		Copy CustomFiles/Depends/banner $(PKG_Finder d package default-settings)/files openwrt_banner
		sed -i "s?By?By ${Author}?g" $(PKG_Finder d package default-settings)/files/openwrt_banner
		sed -i "s?Openwrt?Openwrt ${CURRENT_Version} / AutoUpdate ${AutoUpdate_Version}?g" $(PKG_Finder d package default-settings)/files/openwrt_banner
	;;
	*)
		Copy CustomFiles/Depends/banner package/base-files/files/etc
		sed -i "s?By?By ${Author}?g" package/base-files/files/etc/banner
		sed -i "s?Openwrt?Openwrt ${CURRENT_Version} / AutoUpdate ${AutoUpdate_Version}?g" package/base-files/files/etc/banner
	;;
	esac
	TIME "[Firmware-Diy_Main] All done !"
}

Firmware-Diy_Other() {
	TIME "[Firmware-Diy_Other]"
	source ./VARIABLE_FILE
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
			TIME "Starting to run Obsolete_Package_Compatible Scripts ..."
			case "${OP_BRANCH}" in
			19.07 | 21.02 | main)
				[[ ${OP_BRANCH} == main ]] && OP_BRANCH=21.02
				Copy CustomFiles/Patches/0003-upx-ucl-${OP_BRANCH}.patch ./
				cat 0003-upx-ucl-${OP_BRANCH}.patch | patch -p1 > /dev/null 2>&1
				# AddPackage svn feeds/packages golang coolsnowwolf/packages/trunk/lang
				TIME "Starting to convert zh-cn translation files to zh_Hans ..."
				Copy Scripts/Convert_Translation.sh package
				cd ./package && bash ./Convert_Translation.sh && cd ..
			;;
			*)
				TIME "Current branch: [${OP_BRANCH}] is not supported,skip..."
			;;
			esac
		else
			TIME "Current source: [${OP_Maintainer}] is not supported,skip..."
		fi
	fi
	if [[ -s $GITHUB_WORKSPACE/Configs/Common ]];then
		[[ ! "$(cat .config)" =~ "## TEST" ]] && {
			TIME "Merging [Configs/Common] to .config ..."
			echo -e "\n$(cat $GITHUB_WORKSPACE/Configs/Common)" >> .config
		} || {
			sed -i '/## TEST/d' .config >/dev/null 2>&1
		}
	fi
}

Firmware-Diy_End() {
	TIME "[Firmware-Diy_End]"
	source ./VARIABLE_FILE
	mkdir -p bin/Firmware
	sha256sums="${Firmware_Path}/sha256sums"
	cd ${Firmware_Path}
	echo -e "### FIRMWARE OUTPUT ###\n$(ls -1 | egrep -v "packages|buildinfo|sha256sums|manifest")\n"
	case "${TARGET_BOARD}" in
	x86)
		[[ ${Checkout_Virtual_Images} == true ]] && {
			Eval_Firmware $(List_Format)
		} || {
			Eval_Firmware ${Firmware_Type}
		}
	;;
	*)
		Eval_Firmware ${Firmware_Type}
	;;
	esac
	[[ $(ls) =~ AutoBuild ]] && mv -f AutoBuild-* ${Home}/bin/Firmware
	cd ${Home}
	echo "[$(date "+%H:%M:%S")] Actions Avaliable: $(df -h | grep "/dev/root" | awk '{printf $4}')"
}

Eval_Firmware() {
	while [[ $1 ]];do
		Eval_Firmware_Core $1 $(List_Firmware $1)
		shift
	done
}

Eval_Firmware_Core() {
	Firmware_Type_Defined=$1
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
			TIME "Copying [$1] to [${AutoBuild_Firmware}] ..."
			cp -a $1 ${AutoBuild_Firmware}
		} || TIME "Unable to access [${AutoBuild_Firmware}] ..."
		shift
	done
}

List_Firmware() {
	[[ -z $* ]] && {
		List_All | while read X;do
			echo $X | cut -d "*" -f2
		done
	} || {
		while [[ $1 ]];do
			for X in $(echo $(List_All));do
				[[ $X == *$1 ]] && echo "$X" | cut -d "*" -f2
			done
			shift
		done
	}
}

List_Format() {
	echo "$(List_All | cut -d "*" -f2 | cut -d "." -f2-3)" | sort | uniq
}

List_All() {
	egrep -v "packages|buildinfo|sha256sums|manifest|kernel|rootfs|factory" ${sha256sums} | tr -s '\n'
}

Get_sha256() {
	List_All | grep "$1" | cut -c1-5
}

Get_Variable() {
	grep "$1" ${Home}/VARIABLE_FILE | cut -c$(echo $1 | wc -c)-200 | cut -d ":" -f2
}

Get_Branches() {
    Folder="$(pwd)"
    [[ -n $1 ]] && Folder="$1"
    git -C "${Folder}" rev-parse --abbrev-ref HEAD | grep -v HEAD || \
    git -C "${Folder}" describe --exact-match HEAD || \
    git -C "${Folder}" rev-parse HEAD
}

TIME() {
	echo "[$(date "+%H:%M:%S")] $*"
}

PKG_Finder() {
	local Result
	[[ $# -ne 3 ]] && {
		TIME "Usage: PKG_Finder <f | d> Search_Path Target_Name/Target_Path"
		return 0
	}
	Result=$(find $2 -name $3 -type $1 -exec echo {} \;)
	[[ -n ${Result} ]] && echo "${Result}"
}

AddPackage() {
	[[ $# -lt 4 ]] && {
		TIME "Syntax error: [$#] [$*] !"
		return 0
	}
	PKG_PROTO=$1
	case "${PKG_PROTO}" in
	git | svn)
		:
	;;
	*)
		TIME "Unknown type: ${PKG_PROTO}"
	;;
	esac
	PKG_DIR=$2
	PKG_NAME=$3
	REPO_URL="https://github.com/$4"
	REPO_BRANCH=$5
	[[ ${REPO_URL} =~ "${OP_Maintainer}/${OP_REPO_NAME}" ]] && return 0

	mkdir -p package/${PKG_DIR} || {
		TIME "Can't create download dir: [package/${PKG_DIR}]"
		return 0
	}
	[[ -d package/${PKG_DIR}/${PKG_NAME} ]] && {
		TIME "Removing old package: [${PKG_NAME}] ..."
		rm -rf package/${PKG_DIR}/${PKG_NAME}
	}
	TIME "Checking out package [${PKG_NAME}] to package/${PKG_DIR} ..."
	case "${PKG_PROTO}" in
	git)
		[[ -z ${REPO_BRANCH} ]] && {
			TIME "WARNING: Missing <branch> ,using default branch: [master]"
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
		mv -f "${PKG_NAME}" "package/${PKG_DIR}"
	} || TIME "Package: ${PKG_NAME} failed to download"
}

Copy() {
	[[ $# -lt 2 ]] && {
		TIME "Error options: [$#] [$*] !"
		return 0
	}
	[[ ! -f ${GITHUB_WORKSPACE}/$1 ]] && [[ ! -d ${GITHUB_WORKSPACE}/$1 ]] && {
		TIME "Unable to access CustomFiles/$1,skip ..."
		return 0
	}
	[[ ! -d ${GITHUB_WORKSPACE}/openwrt/$2 ]] && mkdir -p "${GITHUB_WORKSPACE}/openwrt/$2"
	[[ -n $3 ]] && RENAME="$3" || RENAME=""
	TIME "Copying $1 to $2 ${RENAME} ..."
	cp -a "${GITHUB_WORKSPACE}/$1" "${GITHUB_WORKSPACE}/openwrt/$2/${RENAME}"
}