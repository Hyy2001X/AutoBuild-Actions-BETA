#!/bin/bash
# AutoBuild Module by Hyy2001 <https://github.com/Hyy2001X/AutoBuild-Actions>
# AutoBuild Functions

Firmware_Diy_Before() {
	ECHO "[Firmware_Diy_Before] Starting ..."
	Home="${GITHUB_WORKSPACE}/openwrt"
	CONFIG_TEMP="${GITHUB_WORKSPACE}/openwrt/.config"
	CD ${Home}
	Firmware_Diy_Core
	[[ ${Short_Firmware_Date} == true ]] && Compile_Date="$(echo ${Compile_Date} | cut -c1-8)"
	Github="$(grep "https://github.com/[a-zA-Z0-9]" ${GITHUB_WORKSPACE}/.git/config | cut -c8-100 | sed 's/^[ \t]*//g')"
	[[ -z ${Author} || ${Author} == AUTO ]] && Author="$(echo "${Github}" | cut -d "/" -f4)"
	OP_AUTHOR="$(echo "${REPO_URL}" | cut -d "/" -f4)"
	OP_REPO="$(echo "${REPO_URL}" | cut -d "/" -f5)"
	OP_BRANCH="$(GET_Branch)"
	if [[ ${OP_BRANCH} =~ (master|main) ]]
	then
		OP_VERSION_HEAD="R$(date +%y.%m)-"
	else
		OP_BRANCH="$(echo ${OP_BRANCH} | egrep -o "[0-9]+.[0-9]+")"
		OP_VERSION_HEAD="R${OP_BRANCH}-"
	fi
	case "${OP_AUTHOR}/${OP_REPO}" in
	coolsnowwolf/lede)
		Version_File="package/lean/default-settings/files/zzz-default-settings"
		zzz_Default_Version="$(egrep -o "R[0-9]+\.[0-9]+\.[0-9]+" ${Version_File})"
		OP_VERSION="${zzz_Default_Version}-${Compile_Date}"
	;;
	immortalwrt/immortalwrt)
		Version_File=${BASE_FILES}/etc/openwrt_release
		OP_VERSION="${OP_VERSION_HEAD}${Compile_Date}"
	;;
	*)
		OP_VERSION="${OP_VERSION_HEAD}${Compile_Date}"
	;;
	esac
	while [[ -z ${x86_Test} ]];do
		x86_Test="$(egrep -o "CONFIG_TARGET.*DEVICE.*=y" ${CONFIG_TEMP} | sed -r 's/CONFIG_TARGET_(.*)_DEVICE_(.*)=y/\1/')"
		[[ -n ${x86_Test} ]] && break
		x86_Test="$(egrep -o "CONFIG_TARGET.*Generic=y" ${CONFIG_TEMP} | sed -r 's/CONFIG_TARGET_(.*)_Generic=y/\1/')"
		[[ -z ${x86_Test} ]] && break
	done
	[[ ${x86_Test} == x86_64 ]] && {
		TARGET_PROFILE=x86_64
	} || {
		TARGET_PROFILE="$(egrep -o "CONFIG_TARGET.*DEVICE.*=y" ${CONFIG_TEMP} | sed -r 's/.*DEVICE_(.*)=y/\1/')"
	}
	[[ -z ${TARGET_PROFILE} ]] && ECHO "Unable to get [TARGET_PROFILE] !"
	TARGET_BOARD="$(awk -F '[="]+' '/TARGET_BOARD/{print $2}' ${CONFIG_TEMP})"
	TARGET_SUBTARGET="$(awk -F '[="]+' '/TARGET_SUBTARGET/{print $2}' ${CONFIG_TEMP})"
	[[ -z ${Firmware_Format} || ${Firmware_Format} =~ (false|AUTO) ]] && {
		case "${TARGET_BOARD}" in
		ramips | reltek | ipq40xx | ath79 | ipq807x)
			Firmware_Format=bin
		;;
		rockchip | x86)
			[[ $(cat ${CONFIG_TEMP}) =~ CONFIG_TARGET_IMAGES_GZIP=y ]] && {
				Firmware_Format=img.gz
			} || Firmware_Format=img
		;;
		esac
	}
	case "${TARGET_BOARD}" in
	x86)
		AutoBuild_Firmware="AutoBuild-${OP_REPO}-${TARGET_PROFILE}-${OP_VERSION}-BOOT-SHA256.FORMAT"
	;;
	*)
		AutoBuild_Firmware="AutoBuild-${OP_REPO}-${TARGET_PROFILE}-${OP_VERSION}-SHA256.FORMAT"
	;;
	esac

	cat >> ${GITHUB_ENV} <<EOF
Home=${Home}
CONFIG_TEMP=${CONFIG_TEMP}
INCLUDE_AutoBuild_Features=${INCLUDE_AutoBuild_Features}
INCLUDE_Original_OpenWrt_Compatible=${INCLUDE_Original_OpenWrt_Compatible}
INCLUDE_DRM_I915=${INCLUDE_DRM_I915}
Checkout_Virtual_Images=${Checkout_Virtual_Images}
AutoBuild_Firmware=${AutoBuild_Firmware}
CustomFiles=${GITHUB_WORKSPACE}/CustomFiles
Scripts=${GITHUB_WORKSPACE}/Scripts
FEEDS_LUCI=${GITHUB_WORKSPACE}/openwrt/package/feeds/luci
FEEDS_PKG=${GITHUB_WORKSPACE}/openwrt/package/feeds/packages
BASE_FILES=${GITHUB_WORKSPACE}/openwrt/package/base-files/files
Banner_Message="${Banner_Message}"
REGEX_Skip_Checkout="${REGEX_Skip_Checkout}"
Version_File=${Version_File}
Firmware_Format=${Firmware_Format}
FEEDS_CONF=${Home}/feeds.conf.default
Author_URL=${Author_URL}
ENV_FILE=${GITHUB_ENV}

EOF
	source ${GITHUB_ENV}
	echo -e "### VARIABLE LIST ###\n$(cat ${GITHUB_ENV})\n"
	ECHO "[Firmware_Diy_Before] Done"
}

Firmware_Diy_Main() {
	ECHO "[Firmware_Diy_Main] Starting ..."
	CD ${Home}
	chmod +x -R ${Scripts}
	chmod 777 -R ${CustomFiles}
	if [[ ${INCLUDE_AutoBuild_Features} == true ]]
	then
		MKDIR ${BASE_FILES}/etc/AutoBuild
		touch ${BASE_FILES}/etc/AutoBuild/Default_Variable ${BASE_FILES}/etc/AutoBuild/Custom_Variable
		cat >> ${BASE_FILES}/etc/AutoBuild/Default_Variable <<EOF
## 请不要修改此文件中的内容, 自定义变量请在 Custom_Variable 中添加或修改
## 该文件将在运行 AutoUpdate.sh 时被读取, 该文件中的变量优先级低于 Custom_Variable

EOF
		for i in ${BASE_FILES}/etc/AutoBuild/Default_Variable ${GITHUB_ENV}
		do
			cat >> ${i} <<EOF
Author=${Author}
Github=${Github}
TARGET_PROFILE=${TARGET_PROFILE}
TARGET_BOARD=${TARGET_BOARD}
TARGET_SUBTARGET=${TARGET_SUBTARGET}
OP_VERSION=${OP_VERSION}
OP_AUTHOR=${OP_AUTHOR}
OP_REPO=${OP_REPO}
OP_BRANCH=${OP_BRANCH}

EOF
		done
		unset i
		cat >> ${BASE_FILES}/etc/AutoBuild/Custom_Variable <<EOF
## 请在下方输入你的自定义变量,一行只能填写一个变量
## 该文件将在运行 AutoUpdate.sh 时被读取, 该文件中的变量优先级高于 Default_Variable
## 示例:
# Author=Hyy2001
# TARGET_PROFILE=x86_64
# Github=https://github.com/Hyy2001X/AutoBuild-Actions
# Tmp_Path=/tmp/AutoUpdate
# Log_Path=/tmp

EOF
		Copy ${Scripts}/AutoBuild_Tools.sh ${BASE_FILES}/bin
		Copy ${Scripts}/AutoUpdate.sh ${BASE_FILES}/bin
		AutoUpdate_Version=$(awk -F '=' '/Version/{print $2}' ${BASE_FILES}/bin/AutoUpdate.sh | awk 'NR==1')
		AddPackage svn lean luci-app-autoupdate Hyy2001X/AutoBuild-Packages/trunk
		Copy ${CustomFiles}/Depends/profile ${BASE_FILES}/etc
		Copy ${CustomFiles}/Depends/base-files-essential ${BASE_FILES}/lib/upgrade/keep.d
		case "${OP_AUTHOR}/${OP_REPO}" in
		coolsnowwolf/lede)
			Copy ${CustomFiles}/Depends/coremark.sh ${Home}/$(PKG_Finder d "package feeds" coremark)
			sed -i '\/etc\/firewall.user/d;/exit 0/d' ${Version_File}
			cat >> ${Version_File} <<EOF

sed -i '/check_signature/d' /etc/opkg.conf
# sed -i 's#mirrors.cloud.tencent.com/lede#downloads.immortalwrt.cnsztl.eu.org#g' /etc/opkg/distfeeds.conf
# sed -i 's#18.06.9/##g' /etc/opkg/distfeeds.conf
# sed -i 's#releases/#snapshots/#g' /etc/opkg/distfeeds.conf

sed -i 's/\"services\"/\"nas\"/g' /usr/lib/lua/luci/controller/aliyundrive-webdav.lua
sed -i 's/services/nas/g' /usr/lib/lua/luci/view/aliyundrive-webdav/aliyundrive-webdav_log.htm
sed -i 's/services/nas/g' /usr/lib/lua/luci/view/aliyundrive-webdav/aliyundrive-webdav_status.htm

sed -i 's/\"services\"/\"vpn\"/g' /usr/lib/lua/luci/controller/v2ray_server.lua
sed -i 's/\"services\"/\"vpn\"/g' /usr/lib/lua/luci/model/cbi/v2ray_server/index.lua
sed -i 's/\"services\"/\"vpn\"/g' /usr/lib/lua/luci/model/cbi/v2ray_server/user.lua
sed -i 's/services/vpn/g' /usr/lib/lua/luci/view/v2ray_server/log.htm
sed -i 's/services/vpn/g' /usr/lib/lua/luci/view/v2ray_server/users_list_status.htm
sed -i 's/services/vpn/g' /usr/lib/lua/luci/view/v2ray_server/users_list_status.htm
sed -i 's/services/vpn/g' /usr/lib/lua/luci/view/v2ray_server/v2ray.htm

if [ -z "\$(grep "REDIRECT --to-ports 53" /etc/firewall.user 2> /dev/null)" ]
then
	echo '#iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 53' >> /etc/firewall.user
	echo '#iptables -t nat -A PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports 53' >> /etc/firewall.user
	echo '#[ -n "\$(command -v ip6tables)" ] && ip6tables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 53' >> /etc/firewall.user
	echo '#[ -n "\$(command -v ip6tables)" ] && ip6tables -t nat -A PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports 53' >> /etc/firewall.user
fi
exit 0
EOF
			sed -i "s?${zzz_Default_Version}?${zzz_Default_Version} @ ${Author} [${Display_Date}]?g" ${Version_File}
			ECHO "Downloading [ShadowSocksR Plus+] for coolsnowwolf/lede ..."
			AddPackage git other helloworld fw876 master
			sed -i 's/143/143,8080,8443/' $(PKG_Finder d package luci-app-ssr-plus)/root/etc/init.d/shadowsocksr
		;;
		immortalwrt/immortalwrt)
			Copy ${CustomFiles}/Depends/openwrt_release_${OP_AUTHOR} ${BASE_FILES}/etc openwrt_release
			sed -i "s?ImmortalWrt?ImmortalWrt @ ${Author} [${Display_Date}]?g" ${Version_File}
		;;
		esac
		sed -i "s?By?By ${Author}?g" ${CustomFiles}/Depends/banner
		sed -i "s?Openwrt?Openwrt ${OP_VERSION} / AutoUpdate ${AutoUpdate_Version}?g" ${CustomFiles}/Depends/banner
		[[ -n ${Banner_Message} ]] && sed -i "s?Powered by AutoBuild-Actions?${Banner_Message}?g" ${CustomFiles}/Depends/banner
		case "${OP_AUTHOR}/${OP_REPO}" in
		immortalwrt/immortalwrt)
			Copy ${CustomFiles}/Depends/banner ${Home}/$(PKG_Finder d package default-settings)/files openwrt_banner
		;;
		*)
			Copy ${CustomFiles}/Depends/banner ${BASE_FILES}/etc
		;;
		esac
	fi
	[[ -n ${Tempoary_IP} ]] && {
		ECHO "Using Tempoary IP Address: ${Tempoary_IP} ..."
		Default_IP="${Tempoary_IP}"
	}
	[[ -n ${Default_IP} && ${Default_IP} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && {
		Old_IP=$(awk -F '[="]+' '/ipaddr:-/{print $3}' ${BASE_FILES}/bin/config_generate | awk 'NR==1')
		if [[ ! ${Default_IP} == ${Old_IP} ]]
		then
			ECHO "Setting default IP Address to ${Default_IP} ..."
			sed -i "s/${Old_IP}/${Default_IP}/g" ${BASE_FILES}/bin/config_generate
		fi
	}
	[[ ${INCLUDE_DRM_I915} == true && ${TARGET_BOARD} == x86 ]] && {
		for X in $(ls -1 target/linux/x86 | grep "config-")
		do
			cat >> ${Home}/target/linux/x86/${X} <<EOF

CONFIG_64BIT=y
CONFIG_DRM=y
CONFIG_DRM_I915=y
CONFIG_DRM_I915_GVT=y
CONFIG_DUMMY_CONSOLE=y
EOF
		done
		unset X
	}
	ECHO "[Firmware_Diy_Main] Done"
}

Firmware_Diy_Other() {
	ECHO "[Firmware_Diy_Other] Starting ..."
	CD ${Home}
	case "${INCLUDE_Original_OpenWrt_Compatible}" in
	19.07)
		OP_BRANCH=19.07
		Force_mode=1
		INCLUDE_Original_OpenWrt_Compatible=true
	;;
	21.02)
		OP_BRANCH=21.02
		Force_mode=1
		INCLUDE_Original_OpenWrt_Compatible=true
	;;
	esac
	if [[ ${INCLUDE_Original_OpenWrt_Compatible} == true ]]
	then
		if [[ ${OP_AUTHOR} =~ (openwrt|[Ll]ienol) || ${Force_mode} == 1 ]]
		then
			ECHO "Starting to run [Obsolete_Package_Compatible] Script ..."
			case "${OP_BRANCH}" in
			19.07 | 21.02 | main)
				[[ ${OP_BRANCH} == main ]] && OP_BRANCH=21.02
				cat >> ${CONFIG_TEMP} <<EOF

# CONFIG_PACKAGE_dnsmasq is not set
CONFIG_PACKAGE_dnsmasq-full=y
# CONFIG_PACKAGE_wpad-wolfssl is not set
CONFIG_PACKAGE_wpad-openssl=y
EOF
				Copy ${CustomFiles}/Patches/0003-upx-ucl-${OP_BRANCH}.patch ${Home}
				cat 0003-upx-ucl-${OP_BRANCH}.patch | patch -p1 > /dev/null 2>&1
				AddPackage svn feeds/packages golang coolsnowwolf/packages/trunk/lang
				ECHO "Starting to convert zh-cn translation files to zh_Hans ..."
				cd package && bash ${Scripts}/Convert_Translation.sh && cd -
			;;
			*)
				ECHO "[${OP_BRANCH}]: Current OP_BRANCH is not supported !"
			;;
			esac
		else
			ECHO "[${OP_AUTHOR}]: Current OP_AUTHOR is not supported !"
		fi
	fi
	if [[ ${Author_URL} != false ]]
	then
		[[ ${Author_URL} == AUTO ]] && Author_URL=${Github}
			cat >> ${CONFIG_TEMP} <<EOF

CONFIG_KERNEL_BUILD_USER="${Author}"
CONFIG_KERNEL_BUILD_DOMAIN="${Author_URL}"
EOF
	fi
	ECHO "[Firmware_Diy_Other] Done"
}

Firmware_Diy_End() {
	ECHO "[Firmware_Diy_End] Starting ..."
	cd ${Home}
	MKDIR ${Home}/bin/Firmware
	Firmware_Path="${Home}/bin/targets/${TARGET_BOARD}/${TARGET_SUBTARGET}"
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
	[[ $(ls) =~ 'AutoBuild-' ]] && {
		cd -
		cp -a ${Firmware_Path}/AutoBuild-* bin/Firmware
	}
	echo "[$(date "+%H:%M:%S")] Actions Avaliable: $(df -h | grep "/dev/root" | awk '{printf $4}')"
	ECHO "[Firmware_Diy_End] Done"
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
		AutoBuild_Firmware=$(Get_Variable AutoBuild_Firmware)
		case "${TARGET_BOARD}" in
		x86)
			[[ $1 =~ efi ]] && {
				FW_Boot_Method=UEFI
			} || FW_Boot_Method=BIOS
			AutoBuild_Firmware=${AutoBuild_Firmware/BOOT/${FW_Boot_Method}}
		;;
		esac
		AutoBuild_Firmware=${AutoBuild_Firmware/SHA256/$(Get_SHA256 $1)}
		AutoBuild_Firmware=${AutoBuild_Firmware/FORMAT/${Firmware_Format_Defined}}
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
			echo ${X} | cut -d "*" -f2
		done
	} || {
		while [[ $1 ]];do
			for X in $(echo $(List_REGEX));do
				[[ ${X} == *$1 ]] && echo "${X}" | cut -d "*" -f2
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
	local Result="$(grep "$1" ${ENV_FILE} | grep -v "#" | awk -F '=' '{print $2}')"
	if [[ -n ${Result} ]]
	then
		eval echo "${Result}"
		return 0
	else
		return 1
	fi
}

GET_Branch() {
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
	[[ ! $? == 0 ]] && ECHO "Unable to enter target directory $1 ..." || ECHO "Entering directory: $(pwd) ..."
}

MKDIR() {
	while [[ $1 ]];do
		if [[ ! -d $1 ]]
		then
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
	[[ ${REPO_URL} =~ "${OP_AUTHOR}/${OP_REPO}" ]] && return 0

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
		[[ $? == 0 ]] && ECHO "Done"
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
	if [[ -z $3 ]]
	then
		ECHO "Copying $1 to $2 ..."
		cp -a $1 $2
	else
		ECHO "Copying and renaming $1 to $2/$3 ..."
		cp -a $1 $2/$3
	fi
	[[ $? == 0 ]] && ECHO "Done" || ECHO "Failed"
}
