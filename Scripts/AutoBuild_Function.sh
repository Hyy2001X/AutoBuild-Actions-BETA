#!/bin/bash
# AutoBuild Module by Hyy2001 <https://github.com/Hyy2001X/AutoBuild-Actions>
# AutoBuild Functions

Firmware_Diy_Before() {
	ECHO "[Firmware_Diy_Before] Starting ..."
	WORK="${GITHUB_WORKSPACE}/openwrt"
	CONFIG_TEMP="${GITHUB_WORKSPACE}/openwrt/.config"
	CD ${WORK}
	Firmware_Diy_Core
	[[ ${Short_Fw_Date} == true ]] && Compile_Date="$(echo ${Compile_Date} | cut -c1-8)"
	Github="$(grep "https://github.com/[a-zA-Z0-9]" ${GITHUB_WORKSPACE}/.git/config | cut -c8-100 | sed 's/^[ \t]*//g')"
	[[ -z ${Author} || ${Author} == AUTO ]] && Author="$(echo "${Github}" | cut -d "/" -f4)"
	OP_AUTHOR="$(echo "${REPO_URL}" | cut -d "/" -f4)"
	OP_REPO="$(echo "${REPO_URL}" | cut -d "/" -f5)"
	OP_BRANCH="$(Get_Branch)"
	if [[ ${OP_BRANCH} =~ (master|main) ]]
	then
		OP_VERSION_HEAD="R$(date +%y.%m)-"
	else
		OP_BRANCH="$(echo ${OP_BRANCH} | egrep -o "[0-9]+.[0-9]+" | awk 'NR==1')"
		OP_VERSION_HEAD="R${OP_BRANCH}-"
	fi
	case "${OP_AUTHOR}/${OP_REPO}" in
	coolsnowwolf/lede)
		Version_File=package/lean/default-settings/files/zzz-default-settings
		zzz_Default_Version="$(egrep -o "R[0-9]+\.[0-9]+\.[0-9]+" ${Version_File})"
		OP_VERSION="${zzz_Default_Version}-${Compile_Date}"
	;;
	immortalwrt/immortalwrt)
		Version_File=package/base-files/files/etc/openwrt_release
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
	if [[ ${x86_Test} == x86_64 ]]
	then
		TARGET_PROFILE=x86_64
	else
		TARGET_PROFILE="$(egrep -o "CONFIG_TARGET.*DEVICE.*=y" ${CONFIG_TEMP} | sed -r 's/.*DEVICE_(.*)=y/\1/')"
	fi
	[[ -z ${TARGET_PROFILE} ]] && ECHO "Unable to get [TARGET_PROFILE] !"
	TARGET_BOARD="$(awk -F '[="]+' '/TARGET_BOARD/{print $2}' ${CONFIG_TEMP})"
	TARGET_SUBTARGET="$(awk -F '[="]+' '/TARGET_SUBTARGET/{print $2}' ${CONFIG_TEMP})"
	if [[ -z ${Fw_MFormat} || ${Fw_MFormat} =~ (false|AUTO) ]]
	then
		case "${TARGET_BOARD}" in
		ramips | reltek | ath* | ipq* | bcm47xx | bmips | kirkwood | mediatek)
			Fw_MFormat=bin
		;;
		rockchip | x86 | bcm27xx | mxs | sunxi | zynq)
			Fw_MFormat="$(gz_Check)"
		;;
		mvebu)
			case "${TARGET_SUBTARGET}" in
			cortexa53 | cortexa72)
				Fw_MFormat="$(gz_Check)"
			;;
			esac
		;;
		octeon | oxnas | pistachio)
			Fw_MFormat=tar
		;;
		esac
	fi
	[[ ${Author_URL} != false && ${Author_URL} == AUTO ]] && Author_URL="${Github}"
	[[ ${Author_URL} == false ]] && unset Author_URL
	if [[ ${Default_Flag} == AUTO ]]
	then
		TARGET_FLAG=${CONFIG_FILE/${TARGET_PROFILE}-/}
		[[ ${TARGET_FLAG} =~ ${TARGET_PROFILE} || -z ${TARGET_FLAG} || ${TARGET_FLAG} == ${CONFIG_FILE} ]] && TARGET_FLAG=Full
	else
		if [[ ! ${Default_Flag} =~ (\"|=|-|_|\.|\#|\|) && ${Default_Flag} =~ [a-zA-Z0-9] ]]
		then
			TARGET_FLAG="${Default_Flag}"
		fi
	fi
	if [[ ! ${Tempoary_FLAG} =~ (\"|=|-|_|\.|\#|\|) && ${Tempoary_FLAG} =~ [a-zA-Z0-9] ]]
	then
		TARGET_FLAG="${Tempoary_FLAG}"
	fi
	case "${TARGET_BOARD}" in
	x86)
		AutoBuild_Fw="AutoBuild-${OP_REPO}-${TARGET_PROFILE}-${OP_VERSION}-BOOT-${TARGET_FLAG}-SHA256.FORMAT"
	;;
	*)
		AutoBuild_Fw="AutoBuild-${OP_REPO}-${TARGET_PROFILE}-${OP_VERSION}-${TARGET_FLAG}-SHA256.FORMAT"
	;;
	esac
	cat >> ${GITHUB_ENV} <<EOF
WORK=${WORK}
CONFIG_TEMP=${CONFIG_TEMP}
AutoBuild_Features=${AutoBuild_Features}
x86_Full_Images=${x86_Full_Images}
AutoBuild_Fw=${AutoBuild_Fw}
CustomFiles=${GITHUB_WORKSPACE}/CustomFiles
Scripts=${GITHUB_WORKSPACE}/Scripts
BASE_FILES=${GITHUB_WORKSPACE}/openwrt/package/base-files/files
FEEDS_LUCI=${GITHUB_WORKSPACE}/openwrt/package/feeds/luci
FEEDS_PKG=${GITHUB_WORKSPACE}/openwrt/package/feeds/packages
Default_Title="${Default_Title}"
Regex_Skip="${Regex_Skip}"
Version_File=${Version_File}
Fw_MFormat=${Fw_MFormat}
FEEDS_CONF=${WORK}/feeds.conf.default
Author_URL=${Author_URL}
ENV_FILE=${GITHUB_ENV}

EOF
	source ${GITHUB_ENV}
	echo -e "### VARIABLE LIST ###\n$(cat ${GITHUB_ENV})\n"
	ECHO "[Firmware_Diy_Before] Done"
}

Firmware_Diy_Main() {
	ECHO "[Firmware_Diy_Main] Starting ..."
	CD ${WORK}
	chmod 777 -R ${Scripts} ${CustomFiles}
	if [[ ${AutoBuild_Features} == true ]]
	then
		AddPackage git other AutoBuild-Packages Hyy2001X master
		for i in ${GITHUB_ENV} $(PKG_Finder d package AutoBuild-Packages)/autoupdate/files/etc/autoupdate/default
		do
			cat >> ${i} <<EOF
Author=${Author}
Github=${Github}
TARGET_PROFILE=${TARGET_PROFILE}
TARGET_BOARD=${TARGET_BOARD}
TARGET_SUBTARGET=${TARGET_SUBTARGET}
TARGET_FLAG=${TARGET_FLAG}
OP_VERSION=${OP_VERSION}
OP_AUTHOR=${OP_AUTHOR}
OP_REPO=${OP_REPO}
OP_BRANCH=${OP_BRANCH}

EOF
		done ; unset i
		AutoUpdate_Version=$(awk -F '=' '/Version/{print $2}' $(PKG_Finder d package AutoBuild-Packages)/autoupdate/files/bin/autoupdate | awk 'NR==1')
		Copy ${CustomFiles}/Depends/tools ${BASE_FILES}/bin
		Copy ${CustomFiles}/Depends/profile ${BASE_FILES}/etc
		Copy ${CustomFiles}/Depends/base-files-essential ${BASE_FILES}/lib/upgrade/keep.d
		case "${OP_AUTHOR}/${OP_REPO}" in
		coolsnowwolf/lede)
			Copy ${CustomFiles}/Depends/coremark.sh $(PKG_Finder d "package feeds" coremark)
			sed -i '\/etc\/firewall.user/d;/exit 0/d' ${Version_File}
			cat >> ${Version_File} <<EOF

sed -i '/check_signature/d' /etc/opkg.conf

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
			if [[ -n ${TARGET_FLAG} ]]
			then
				sed -i "s?${zzz_Default_Version}?${TARGET_FLAG} ${zzz_Default_Version} @ ${Author} [${Display_Date}]?g" ${Version_File}
			else
				sed -i "s?${zzz_Default_Version}?${zzz_Default_Version} @ ${Author} [${Display_Date}]?g" ${Version_File}
			fi
		;;
		immortalwrt/immortalwrt)
			Copy ${CustomFiles}/Depends/openwrt_release_${OP_AUTHOR} ${BASE_FILES}/etc openwrt_release
			if [[ -n ${TARGET_FLAG} ]]
			then
				sed -i "s?ImmortalWrt?ImmortalWrt ${TARGET_FLAG} @ ${Author} [${Display_Date}]?g" ${Version_File}
			else
				sed -i "s?ImmortalWrt?ImmortalWrt @ ${Author} [${Display_Date}]?g" ${Version_File}
			fi
		;;
		esac
		sed -i "s?By?By ${Author}?g" ${CustomFiles}/Depends/banner
		sed -i "s?Openwrt?Openwrt ${OP_VERSION} / AutoUpdate ${AutoUpdate_Version}?g" ${CustomFiles}/Depends/banner
		if [[ -n ${Default_Title} ]]
		then
			if [[ -n ${TARGET_FLAG} ]]
			then
				sed -i "s?Powered by AutoBuild-Actions?${Default_Title} @ ${TARGET_FLAG}?g" ${CustomFiles}/Depends/banner
			else
				sed -i "s?Powered by AutoBuild-Actions?${Default_Title}?g" ${CustomFiles}/Depends/banner
			fi
		fi
		case "${OP_AUTHOR}/${OP_REPO}" in
		immortalwrt/immortalwrt)
			Copy ${CustomFiles}/Depends/banner $(PKG_Finder d package default-settings)/files openwrt_banner
		;;
		*)
			Copy ${CustomFiles}/Depends/banner ${BASE_FILES}/etc
		;;
		esac
	fi
	if [[ -n ${Tempoary_IP} ]]
	then
		ECHO "Using Tempoary IP Address: ${Tempoary_IP} ..."
		Default_IP="${Tempoary_IP}"
	fi
	if [[ -n ${Default_IP} && ${Default_IP} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
	then
		Old_IP=$(awk -F '[="]+' '/ipaddr:-/{print $3}' ${BASE_FILES}/bin/config_generate | awk 'NR==1')
		if [[ ! ${Default_IP} == ${Old_IP} ]]
		then
			ECHO "Setting default IP Address to ${Default_IP} ..."
			sed -i "s/${Old_IP}/${Default_IP}/g" ${BASE_FILES}/bin/config_generate
		fi
	fi
	for X in $(ls -1 target/linux/generic | grep "config-")
	do
		sed -i '/CONFIG_FAT_DEFAULT_IOCHARSET/d' target/linux/generic/${X}
		echo -e '\nCONFIG_FAT_DEFAULT_IOCHARSET="utf8"' >> target/linux/generic/${X}
	done
	ECHO "[Firmware_Diy_Main] Done"
}

Firmware_Diy_Other() {
	ECHO "[Firmware_Diy_Other] Starting ..."
	CD ${WORK}
	if [[ -n ${Author_URL} ]]
	then
			cat >> ${CONFIG_TEMP} <<EOF

CONFIG_KERNEL_BUILD_USER="${Author}"
CONFIG_KERNEL_BUILD_DOMAIN="${Author_URL}"
EOF
	fi
	ECHO "[Firmware_Diy_Other] Done"
}

Firmware_Diy_End() {
	ECHO "[Firmware_Diy_End] Starting ..."
	cd ${WORK}
	MKDIR ${WORK}/bin/Firmware
	Fw_Path="${WORK}/bin/targets/${TARGET_BOARD}/${TARGET_SUBTARGET}"
	cd ${Fw_Path}
	echo -e "### FIRMWARE OUTPUT ###\n$(ls -1)\n"
	case "${TARGET_BOARD}" in
	x86)
		if [[ ${x86_Full_Images} == true ]]
		then
			Process_Fw $(List_MFormat)
		else
			Process_Fw ${Fw_MFormat}
		fi
	;;
	*)
		if [[ -n ${Fw_MFormat} ]]
		then
			Process_Fw ${Fw_MFormat}
		else
			Process_Fw $(List_MFormat)
		fi
	;;
	esac
	if [[ $(ls) =~ 'AutoBuild-' ]]
	then
		cd -
		cp -a ${Fw_Path}/AutoBuild-* bin/Firmware
	fi
	echo "[$(date "+%H:%M:%S")] Actions Avaliable: $(df -h | grep "/dev/root" | awk '{printf $4}')"
	ECHO "[Firmware_Diy_End] Done"
}

Process_Fw() {
	while [[ $1 ]];do
		Process_Fw_Core $1 $(List_Fw $1 | Regex)
		shift
	done
}

Process_Fw_Core() {
	Fw_Format=$1
	shift
	while [[ $1 ]];do
		Fw=${AutoBuild_Fw}
		case "${TARGET_BOARD}" in
		x86)
			[[ $1 =~ efi ]] && Fw_Boot=UEFI || Fw_Boot=BIOS
			Fw=${Fw/BOOT/${Fw_Boot}}
		;;
		esac
		Fw=${Fw/SHA256/$(Get_sha256 $1)}
		Fw=${Fw/FORMAT/${Fw_Format}}
		if [[ -f $1 ]]
		then
			ECHO "Copying [$1] to [${Fw}] ..."
			cp -a $1 ${Fw}
		else
			ECHO "Failed to copy [${Fw}] ..."
		fi
		shift
	done
}

List_Fw() {
	if [[ -z $* ]]
	then
		for X in $(List_sha256);do
			echo ${X} | cut -d "*" -f2
		done
	else
		while [[ $1 ]];do
			for X in $(List_sha256);do
				[[ ${X} == *$1 ]] && echo "${X}" | cut -d "*" -f2
			done
			shift
		done
	fi
}

Regex() {
	egrep -v "${Regex_Skip}"
}

List_sha256() {
	cat ${Fw_Path}/sha256sums 2> /dev/null | Regex | tr -s '\n'
}

List_MFormat() {
	echo "$(List_sha256 | cut -d "*" -f2 | cut -d "." -f2-3)" | sort | uniq
}

Get_sha256() {
	List_sha256 | grep $1 | awk '{print $1}' | cut -c1-5
}

Get_Branch() {
    git -C $(pwd) rev-parse --abbrev-ref HEAD | grep -v HEAD || \
    git -C $(pwd) describe --exact-match HEAD || \
    git -C $(pwd) rev-parse HEAD
}

gz_Check() {
	[[ $(cat ${CONFIG_TEMP}) =~ CONFIG_TARGET_IMAGES_GZIP=y ]] && {
		echo img.gz
	} || echo img
}

ECHO() {
	echo "[$(date "+%H:%M:%S")] $*"
}

PKG_Finder() {
	local Result
	if [[ $# -ne 3 ]]
	then
		ECHO "Usage: PKG_Finder <f | d> Search_Path Target_Name/Target_Path"
		return 0
	fi
	Result=$(find $2 -name $3 -type $1 -exec echo {} \; 2> /dev/null)
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
	if [[ $# -lt 4 ]]
	then
		ECHO "Syntax error: [$#] [$*]"
		return 0
	fi
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
	if [[ -d ${PKG_DIR}/${PKG_NAME} ]]
	then
		ECHO "Removing old package: [${PKG_NAME}] ..."
		rm -rf ${PKG_DIR}/${PKG_NAME}
	fi
	ECHO "Checking out package [${PKG_NAME}] to ${PKG_DIR} ..."
	case "${PKG_PROTO}" in
	git)
		if [[ -z ${REPO_BRANCH} ]]
		then
			ECHO "WARNING: Syntax missing <branch> ,using default branch: [master]"
			REPO_BRANCH=master
		fi
		PKG_URL="$(echo ${REPO_URL}/${PKG_NAME} | sed s/[[:space:]]//g)"
		git clone -b ${REPO_BRANCH} ${PKG_URL} ${PKG_NAME} > /dev/null 2>&1
	;;
	svn)
		svn checkout ${REPO_URL}/${PKG_NAME} ${PKG_NAME} > /dev/null 2>&1
	;;
	esac
	if [[ -f ${PKG_NAME}/Makefile || -n $(ls -A ${PKG_NAME}) ]]
	then
		mv -f "${PKG_NAME}" "${PKG_DIR}"
		[[ $? == 0 ]] && ECHO "Done"
	else
		ECHO "Failed to download package ${PKG_NAME} ..."
	fi
}

Copy() {
	if [[ ! $# =~ [23] ]]
	then
		ECHO "Syntax error: [$#] [$*]"
		return 0
	fi
	if [[ ! -f $1 && ! -d $1 ]]
	then
		ECHO "$1: No such file or directory ..."
		return 0
	fi
	MKDIR $2
	if [[ -z $3 ]]
	then
		ECHO "[C] Copying $1 to $2 ..."
		cp -a $1 $2
	else
		ECHO "[R] Copying $1 to $2/$3 ..."
		cp -a $1 $2/$3
	fi
	[[ $? == 0 ]] && ECHO "Done"
}
