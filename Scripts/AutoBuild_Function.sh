#!/bin/bash
# AutoBuild Module by Hyy2001 <https://github.com/Hyy2001X/AutoBuild-Actions>
# AutoBuild Functions

GET_INFO() {
	Diy_Core
	Home="${GITHUB_WORKSPACE}/openwrt"
	[[ -f ${GITHUB_WORKSPACE}/Openwrt.info ]] && source ${GITHUB_WORKSPACE}/Openwrt.info
	[[ ${Short_Firmware_Date} == true ]] && Compile_Date="$(echo ${Compile_Date} | cut -c1-8)"
	User_Repo="$(grep "https://github.com/[a-zA-Z0-9]" ${GITHUB_WORKSPACE}/.git/config | cut -c8-100 | sed 's/^[ \t]*//g')"
	[[ -z ${Author} ]] && Author="$(echo "${User_Repo}" | cut -d "/" -f4)"
	Openwrt_Author="$(echo "${Openwrt_Repo}" | cut -d "/" -f4)"
	Openwrt_Repo_Name="$(echo "${Openwrt_Repo}" | cut -d "/" -f5)"
	Openwrt_Branch="$(GET_BRANCH)"
	[[ ! ${Openwrt_Branch} == master ]] && {
		Openwrt_Branch="$(echo ${Openwrt_Branch} | egrep -o "[0-9]+.[0-9]+")"
		Openwrt_Version_="R${Openwrt_Branch}-"
	} || Openwrt_Version_="R$(date +%y.%m)-"
	case "${Openwrt_Author}" in
	coolsnowwolf)
		Version_File=package/lean/default-settings/files/zzz-default-settings
		Old_Version="$(egrep -o "R[0-9]+\.[0-9]+\.[0-9]+" ${Version_File})"
		CURRENT_Version="${Old_Version}-${Compile_Date}"
	;;
	immortalwrt)
		Version_File=package/base-files/files/etc/openwrt_release
		CURRENT_Version="${Openwrt_Version_}${Compile_Date}"
	;;
	*)
		CURRENT_Version="${Openwrt_Version_}${Compile_Date}"
	;;
	esac
	while [[ -z ${x86_Test} ]];do
		x86_Test="$(egrep -o "CONFIG_TARGET.*DEVICE.*=y" .config | sed -r 's/CONFIG_TARGET_(.*)_DEVICE_(.*)=y/\1/')"
		[[ -n ${x86_Test} ]] && break
		x86_Test="$(egrep -o "CONFIG_TARGET.*Generic=y" .config | sed -r 's/CONFIG_TARGET_(.*)_Generic=y/\1/')"
		[[ -z ${x86_Test} ]] && TIME "[ERROR] Can not obtain the TARGET_PROFILE !" && exit 1
	done
	[[ ${x86_Test} == x86_64 ]] && {
		TARGET_PROFILE=x86_64
	} || {
		TARGET_PROFILE="$(egrep -o "CONFIG_TARGET.*DEVICE.*=y" .config | sed -r 's/.*DEVICE_(.*)=y/\1/')"
	}
	[[ -z ${TARGET_PROFILE} ]] && TARGET_PROFILE="${Default_Device}"
	[[ -z ${Default_Device} ]] && Default_Device="${TARGET_PROFILE}"
	[[ ${TARGET_PROFILE} == x86_64 ]] && {
		[[ $(cat ${Home}/.config) =~ CONFIG_TARGET_IMAGES_GZIP=y ]] && Firmware_Type=img.gz || Firmware_Type=img 
	}
	TARGET_BOARD="$(awk -F '[="]+' '/TARGET_BOARD/{print $2}' .config)"
	case "${TARGET_BOARD}" in
	ramips | reltek | ipq40xx | ath79)
		Firmware_Type=bin
	;;
	rockchip)
		Firmware_Type=img.gz
	;;
	esac
	TARGET_SUBTARGET="$(awk -F '[="]+' '/TARGET_SUBTARGET/{print $2}' .config)"

	case "${Openwrt_Author}" in
	immortalwrt)
		Firmware_Head=immortalwrt
	;;
	*)
		Firmware_Head=openwrt
	;;
	esac
	case "${Openwrt_Branch}" in
	19.07 | 18.06)
		case "${Openwrt_Author}" in
		immortalwrt)
			Legacy_Tail=combined-squashfs
			UEFI_Tail=uefi-gpt-squashfs
		;;
		*)
			Legacy_Tail=combined-squashfs
			UEFI_Tail=combined-squashfs-efi
		;;
		esac
	;;
	*)
		Legacy_Tail=generic-squashfs-combined
		UEFI_Tail=generic-squashfs-combined-efi
	;;
	esac

	case "${TARGET_PROFILE}" in
	x86_64)
		Default_Legacy_Firmware="${Firmware_Head}-${TARGET_BOARD}-${TARGET_SUBTARGET}-${Legacy_Tail}.${Firmware_Type}"
		Default_UEFI_Firmware="${Firmware_Head}-${TARGET_BOARD}-${TARGET_SUBTARGET}-${UEFI_Tail}.${Firmware_Type}"
		AutoBuild_Firmware='AutoBuild-${Openwrt_Repo_Name}-${TARGET_PROFILE}-${CURRENT_Version}-${x86_64_Boot}-${SHA5BIT}.${Firmware_Type}'
		Egrep_Firmware='AutoBuild-${Openwrt_Repo_Name}-${TARGET_PROFILE}-R[0-9].+-[0-9]+-${x86_64_Boot}-[0-9a-z]+.${Firmware_Type}'
	;;
	*)
		Default_Firmware="${Firmware_Head}-${TARGET_BOARD}-${TARGET_SUBTARGET}-${TARGET_PROFILE}-squashfs-sysupgrade.${Firmware_Type}"
		AutoBuild_Firmware='AutoBuild-${Openwrt_Repo_Name}-${TARGET_PROFILE}-${CURRENT_Version}-${SHA5BIT}.${Firmware_Type}'
		Egrep_Firmware='AutoBuild-${Openwrt_Repo_Name}-${TARGET_PROFILE}-R[0-9].+-[0-9]+-[0-9a-z]+.${Firmware_Type}'
	;;
	esac
	Firmware_Path="bin/targets/${TARGET_BOARD}/${TARGET_SUBTARGET}"

	cat >> VARIABLE_FILE_Main <<EOF
Author=${Author}
Github=${User_Repo}
Default_Device=${Default_Device}
TARGET_PROFILE=${TARGET_PROFILE}
TARGET_BOARD=${TARGET_BOARD}
TARGET_SUBTARGET=${TARGET_SUBTARGET}
Firmware_Type=${Firmware_Type}
CURRENT_Version=${CURRENT_Version}
Openwrt_Author=${Openwrt_Author}
Openwrt_Branch=${Openwrt_Branch}
AutoBuild_Firmware=${AutoBuild_Firmware}
Openwrt_Repo_Name=${Openwrt_Repo_Name}
Egrep_Firmware=${Egrep_Firmware}
FW_SAVE_PATH=/tmp/Downloads
EOF
	cat >> VARIABLE_FILE_Sec <<EOF
INCLUDE_Obsolete_PKG_Compatible=${INCLUDE_Obsolete_PKG_Compatible}
Home=${Home}
Firmware_Path=${Firmware_Path}
EOF

	case "${TARGET_PROFILE}" in
	x86_64)
		cat >> VARIABLE_FILE_Sec <<EOF
Default_Legacy_Firmware=${Default_Legacy_Firmware}
Default_UEFI_Firmware=${Default_UEFI_Firmware}
Legacy_Tail=${Legacy_Tail}
UEFI_Tail=${UEFI_Tail}
EOF
	;;
	*)
		cat >> VARIABLE_FILE_Sec <<EOF
Default_Firmware=${Default_Firmware}
EOF
	;;
	esac
	echo "$(cat VARIABLE_FILE_Main)" >> VARIABLE_FILE_Sec
	echo -e "### Variable list ###\n$(cat VARIABLE_FILE_Sec)\n"
	TIME "[Load variable info] All done !"
}

Firmware-Diy_Base() {
	GET_INFO
	mkdir -p package/base-files/files/etc/AutoBuild
	[ -f VARIABLE_FILE_Main ] && cp VARIABLE_FILE_Main package/base-files/files/etc/AutoBuild/Default_Variable
	Copy CustomFiles/Depends/Custom_Variable package/base-files/files/etc/AutoBuild
	AddPackage_List ${GITHUB_WORKSPACE}/CustomPackages/Common
	AddPackage_List ${GITHUB_WORKSPACE}/CustomPackages/${TARGET_PROFILE}
	chmod +x -R ${GITHUB_WORKSPACE}/Scripts
	chmod 777 -R ${GITHUB_WORKSPACE}/CustomFiles
	chmod 777 -R ${GITHUB_WORKSPACE}/CustomPackages
	[[ ${INCLUDE_AutoBuild_Features} == true ]] && {
		Copy Scripts/AutoBuild_Tools.sh package/base-files/files/bin
		AddPackage git lean luci-app-autoupdate Hyy2001X main
		Copy Scripts/AutoUpdate.sh package/base-files/files/bin
	}
	[[ ${INCLUDE_Argon} == true ]] && {
		case "${Openwrt_Author}" in
		coolsnowwolf)
			AddPackage git lean luci-theme-argon jerrykuku 18.06
		;;
		*)
			case "${Openwrt_Branch}" in
			19.07)
				AddPackage git other luci-theme-argon jerrykuku v2.2.5
			;;
			21.02)
				AddPackage git other luci-theme-argon jerrykuku master
			;;
			18.06)
				AddPackage git other luci-theme-argon jerrykuku 18.06
			;;
			*)
				TIME "[ERROR] Unknown Openwrt branch: [${Openwrt_Branch}] !"
			;;
			esac
		;;
		esac
		AddPackage git other luci-app-argon-config jerrykuku
	}
	New_IP_Address="${Default_IP_Address}"
	[[ -n ${Defined_IP_Address} ]] && {
		TIME "Using defined IP Address [${Defined_IP_Address}] ..."
		New_IP_Address="${Defined_IP_Address}"
	}
	[[ -n ${New_IP_Address} && ${New_IP_Address} != false ]] && {
		if [[ ${New_IP_Address} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]];then
			Old_IP_Address=$(awk -F '[="]+' '/ipaddr:-/{print $3}' package/base-files/files/bin/config_generate | awk 'NR==1')
			if [[ ! ${New_IP_Address} == ${Old_IP_Address} ]];then
				TIME "Setting default IP Address to ${New_IP_Address} ..."
				sed -i "s/${Old_IP_Address}/${New_IP_Address}/g" package/base-files/files/bin/config_generate
				a=$(echo ${Old_IP_Address} | egrep -o "[0-9]+.[0-9]+." | awk 'NR==1')
				b=$(echo ${New_IP_Address} | egrep -o "[0-9]+.[0-9]+." | awk 'NR==1')
				c="$(egrep -o ")).[0-9]+" package/base-files/files/bin/config_generate)"
				d=")).$(echo ${New_IP_Address} | egrep -o "[0-9]+" | awk 'END {print}')"
				sed -i "s/${a}/${b}/g" package/base-files/files/bin/config_generate
				sed -i "s/${c}/${d}/g" package/base-files/files/bin/config_generate
			fi
		else
			TIME "[ERROR] ${New_IP_Address} is not an IP Address !"
		fi
	}
	[[ ${INCLUDE_DRM_I915} == true && ${TARGET_PROFILE} == x86_64 ]] && {
		Copy CustomFiles/Depends/DRM-I915 target/linux/x86
		for X in $(ls -1 target/linux/x86 | grep "config-"); do cat target/linux/x86/DRM-I915 >> target/linux/x86/${X}; done
	}
	[ -f package/base-files/files/bin/AutoUpdate.sh ] && {
		AutoUpdate_Version=$(egrep -o "V[0-9].+" package/base-files/files/bin/AutoUpdate.sh | awk 'END{print}')
	} || AutoUpdate_Version=OFF
	Copy CustomFiles/Depends/profile package/base-files/files/etc
	Copy CustomFiles/Depends/base-files-essential package/base-files/files/lib/upgrade/keep.d
	case "${Openwrt_Author}" in
	coolsnowwolf)
		Copy CustomFiles/Depends/coremark.sh package/feeds/packages/coremark
		Copy CustomFiles/Depends/cpuinfo_x86 package/lean/autocore/files/x86/sbin cpuinfo
		AddPackage git other helloworld fw876 master
		sed -i 's/143/143,8080/' $(PKG_Finder d package luci-app-ssr-plus)/root/etc/init.d/shadowsocksr
		sed -i "s?iptables?#iptables?g" ${Version_File}
		sed -i "s?${Old_Version}?${Old_Version} @ ${Author} [${Display_Date}]?g" ${Version_File}
	;;
	immortalwrt)
		Copy CustomFiles/Depends/ImmortalWrt package/base-files/files/etc openwrt_release
		Copy CustomFiles/Depends/cpuinfo_x86 package/lean/autocore/files/x86/sbin cpuinfo
		sed -i "s?Template?Compiled by ${Author} [${Display_Date}]?g" ${Version_File}
	;;
	esac
	case "${Openwrt_Author}" in
	immortalwrt)
		Copy CustomFiles/Depends/banner package/lean/default-settings/files openwrt_banner
		sed -i "s?By?By ${Author}?g" package/lean/default-settings/files/openwrt_banner
		sed -i "s?Openwrt?ImmortalWrt ${CURRENT_Version} / AutoUpdate ${AutoUpdate_Version}?g" package/lean/default-settings/files/openwrt_banner
	;;
	*)
		Copy CustomFiles/Depends/banner package/base-files/files/etc
		sed -i "s?By?By ${Author}?g" package/base-files/files/etc/banner
		sed -i "s?Openwrt?Openwrt ${CURRENT_Version} / AutoUpdate ${AutoUpdate_Version}?g" package/base-files/files/etc/banner
	;;
	esac
	TIME "[Firmware-Diy_Base] All done !"
}

Other_Scripts() {
	source ./VARIABLE_FILE_Sec
	case "${INCLUDE_Obsolete_PKG_Compatible}" in
	19.07)
		Openwrt_Branch=19.07
		Force_mode=1
		INCLUDE_Obsolete_PKG_Compatible=true
	;;
	21.02)
		Openwrt_Branch=21.02
		Force_mode=1
		INCLUDE_Obsolete_PKG_Compatible=true
	;;
	esac
	if [[ ${INCLUDE_Obsolete_PKG_Compatible} == true ]];then
		TIME "Start to run Obsolete_Package_Compatible Scripts ..."
		if [[ ${Openwrt_Author} == openwrt || ${Force_mode} == 1 ]];then
			case "${Openwrt_Branch}" in
			19.07 | 21.02)
				Copy CustomFiles/Patches/0003-upx-ucl-${Openwrt_Branch}.patch ./
				cat 0003-upx-ucl-${Openwrt_Branch}.patch | patch -p1 > /dev/null 2>&1
				# AddPackage svn feeds/packages golang coolsnowwolf/packages/trunk/lang
				TIME "Start to convert zh-cn translation files to zh_Hans ..."
				Copy Scripts/Convert_Translation.sh package
				cd ./package && bash ./Convert_Translation.sh && cd ..
			;;
			*)
				TIME "Current branch: [${Openwrt_Branch}] is not supported,skip..."
			;;
			esac
		else
			TIME "Current source: [${Openwrt_Author}] is not supported,skip..."
		fi
	fi
	if [[ -s $GITHUB_WORKSPACE/Configs/Common ]];then
		[[ ! "$(cat .config)" =~ "## DO NOT MERGE" ]] && {
			TIME "Merging [Configs/Common] to .config ..."
			cat $GITHUB_WORKSPACE/Configs/Common >> .config
		} || {
			TIME "Skip merge [Configs/Common] ..."
			sed -i '/## DO NOT MERGE/d' .config >/dev/null 2>&1
		}
	fi
}

PS_Firmware() {
	source ./VARIABLE_FILE_Sec
	mkdir -p bin/Firmware
	cd ${Firmware_Path}
	echo -e "### Firmware Output ###\n$(ls -1)\n"
	case "${TARGET_PROFILE}" in
	x86_64)
		[[ -f ${Default_Legacy_Firmware} ]] && {
			cp ${Default_Legacy_Firmware} $(EVAL_FW x86_64 Legacy ${Home}/VARIABLE_FILE_Sec)
			TIME "Legacy Firmware: [${Default_Legacy_Firmware}] is detected !"
		}
		[[ -f ${Default_UEFI_Firmware} ]] && {
			cp ${Default_UEFI_Firmware} $(EVAL_FW x86_64 UEFI ${Home}/VARIABLE_FILE_Sec)
			TIME "UEFI Firmware: [${Default_UEFI_Firmware}] is detected !"
		}
	;;
	*)
		[[ -f ${Default_Firmware} ]] && {
			cp ${Default_Firmware} $(EVAL_FW common ${Home}/VARIABLE_FILE_Sec)
			TIME "Firmware: [${Default_Firmware}] is detected !"
		} || {
			TIME "Firmware is not detected !"
			Error_Output=1
		}
	;;
	esac
	[[ ${Error_Output} != 1 ]] && mv -f AutoBuild-* ${Home}/bin/Firmware
	cd ${Home}
	echo "[$(date "+%H:%M:%S")] Actions Avaliable: $(df -h | grep "/dev/root" | awk '{printf $4}')"
}

EVAL_FW() {
	case "$1" in
	x86_64)
		x86_64_Boot=$2
		SHA5BIT=$(GET_SHA5BIT $(GET_VARIABLE Default_$2_Firmware= $3) 5)
		EVAL_VARIABLE $(GET_VARIABLE AutoBuild_Firmware= $3)
	;;
	common)
		SHA5BIT=$(GET_SHA5BIT $(GET_VARIABLE Default_Firmware= $2) 5)
		EVAL_VARIABLE $(GET_VARIABLE AutoBuild_Firmware= $2)
	;;
	esac
}

EVAL_VARIABLE() {
	eval OUTPUT=$1
	echo "${OUTPUT}"
}

GET_SHA5BIT() {
	grep "$1" sha256sums | cut -c1-$2
}

GET_BRANCH() {
    Folder="$(pwd)"
    [[ -n $1 ]] && Folder="$1"
    git -C "${Folder}" rev-parse --abbrev-ref HEAD | grep -v HEAD || \
    git -C "${Folder}" describe --exact-match HEAD || \
    git -C "${Folder}" rev-parse HEAD
}

GET_VARIABLE() {
	echo -e "$(grep "$1" $2 | cut -c$(echo $1 | wc -c)-200 | cut -d ":" -f2)"
}

TIME() {
	echo "[$(date "+%H:%M:%S")] $*"
}

PKG_Finder() {
	[[ $# -ne 3 ]] && {
		TIME "[ERROR] Error options: [$#] [$*] !"
		return 0
	}
	find $2 -name $3 -type $1 -depth -exec echo {} \;
}

AddPackage_List() {
	[[ $# != 1 ]] && {
		TIME "[ERROR] Error options: [$#] [$*] !"
		return 0
	}
	echo "" >> $1
	[[ -s $1 ]] && {
		TIME "Loading Custom Packages list: [$1]..."
		cat $1 | sed '/^$/d' | while read X;do
			[[ $* =~ "#" ]] && TIME "Skip check out: ${X}"
			[[ -n ${X} && ! $* =~ "#" ]] && AddPackage ${X}
		done
	}
}

AddPackage() {
	[[ $# -lt 4 ]] && {
		TIME "[ERROR] Error options: [$#] [$*] !"
		return 0
	}
	[[ $* =~ "#" ]] && return 0
	PKG_PROTO="$1"
	PKG_DIR="$2"
	PKG_NAME="$3"
	REPO_URL="https://github.com/$4"
	[[ -z $5 ]] && REPO_BRANCH=master || REPO_BRANCH="$5"

	mkdir -p package/${PKG_DIR}
	[[ -d package/${PKG_DIR}/${PKG_NAME} ]] && {
		TIME "Removing old package: [${PKG_NAME}] ..."
		rm -rf package/${PKG_DIR}/${PKG_NAME}
	}
	TIME "Checking out package [${PKG_NAME}] to package/${PKG_DIR} ..."
	case "${PKG_PROTO}" in
	git)
		
		PKG_URL="$(echo ${REPO_URL}/${PKG_NAME} | sed s/[[:space:]]//g)"
		git clone -b ${REPO_BRANCH} ${PKG_URL} ${PKG_NAME} > /dev/null 2>&1
	;;
	svn)
		svn checkout ${REPO_URL}/${PKG_NAME} ${PKG_NAME} > /dev/null 2>&1
	;;
	esac
	[[ -f ${PKG_NAME}/Makefile || -f ${PKG_NAME}/README* || -n $(ls -A ${PKG_NAME}) ]] && {
		mv -f "${PKG_NAME}" "package/${PKG_DIR}"
	}
}

Copy() {
	[[ $# -lt 2 ]] && {
		TIME "[ERROR] Error options: [$#] [$*] !"
		return 0
	}
	[[ ! -f ${GITHUB_WORKSPACE}/$1 ]] && [[ ! -d ${GITHUB_WORKSPACE}/$1 ]] && {
		TIME "CustomFiles/${FILE_NAME} is not detected !"
		return 0
	}
	[[ ! -d ${GITHUB_WORKSPACE}/openwrt/$2 ]] && mkdir -p ${GITHUB_WORKSPACE}/openwrt/$2
	[[ -n $3 ]] && RENAME="$3" || RENAME=""
	TIME "Copying $1 to $2 ${RENAME} ..."
	cp -a "${GITHUB_WORKSPACE}/$1" "${GITHUB_WORKSPACE}/openwrt/$2/${RENAME}"
}