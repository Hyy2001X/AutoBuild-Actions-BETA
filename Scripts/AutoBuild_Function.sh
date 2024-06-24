#!/bin/bash
# AutoBuild Module by Hyy2001 <https://github.com/Hyy2001X/AutoBuild-Actions-BETA>
# AutoBuild Functions

Firmware_Diy_Start() {
	ECHO "[Firmware_Diy_Start] Starting ..."
	WORK="${GITHUB_WORKSPACE}/openwrt"
	CONFIG_TEMP="${WORK}/.config"
	CD ${WORK}
	OP_REPO="$(basename $(cut -d ':' -f1 <<< ${DEFAULT_SOURCE}))"
	OP_AUTHOR="$(cut -d '/' -f1 <<< ${DEFAULT_SOURCE})"
	OP_BRANCH="$(cut -d ':' -f2 <<< ${DEFAULT_SOURCE})"
	Firmware_Diy_Core
	[[ ${Short_Fw_Date} == true ]] && Compile_Date="$(cut -c1-8 <<< ${Compile_Date})"
	Github="$(egrep -o 'https://github.com/.+' ${GITHUB_WORKSPACE}/.git/config | awk 'NR==1')"
	[[ -z ${Author} || ${Author} == AUTO ]] && Author="$(cut -d "/" -f4 <<< ${Github} | awk 'NR==1')"
	if [[ ${OP_BRANCH} =~ (master|main) ]]
	then
		OP_VERSION_HEAD="R$(date +%y.%m)-"
	else
		OP_VERSION_HEAD="R$(egrep -o "[0-9]+.[0-9]+" <<< ${OP_BRANCH} | awk 'NR==1')-"
	fi
	case "${OP_AUTHOR}/${OP_REPO}" in
	coolsnowwolf/lede)
		Version_File=package/lean/default-settings/files/zzz-default-settings
		zzz_Default_Version="$(egrep -o "R[0-9]+\.[0-9]+\.[0-9]+" ${Version_File})"
		OP_VERSION="${zzz_Default_Version}-${Compile_Date}"
	;;
	immortalwrt/immortalwrt | padavanonly/immortalwrtARM | hanwckf/immortalwrt-mt798x)
		Version_File=package/base-files/files/etc/openwrt_release
		OP_VERSION="${OP_VERSION_HEAD}${Compile_Date}"
	;;
	*)
		OP_VERSION="${OP_VERSION_HEAD}${Compile_Date}"
	;;
	esac
	while [[ -z ${x86_Test} ]]
	do
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
	TARGET_BOARD="$(awk -F '[="]+' '/TARGET_BOARD/{print $2}' ${CONFIG_TEMP})"
	TARGET_SUBTARGET="$(awk -F '[="]+' '/TARGET_SUBTARGET/{print $2}' ${CONFIG_TEMP})"
	if [[ -z ${Fw_MFormat} || ${Fw_MFormat} == AUTO ]]
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
	if [[ ! ${Tempoary_FLAG} =~ (\"|=|-|_|\.|\#|\|) && ${Tempoary_FLAG} =~ [a-zA-Z0-9] && ${Tempoary_FLAG} != AUTO ]]
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
CONFIG_FILE=${CONFIG_FILE}
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
Compile_Date=${Compile_Date}

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
	echo -e "### VARIABLE LIST ###\n$(cat ${GITHUB_ENV})\n"
	source ${GITHUB_ENV}
	ECHO "[Firmware_Diy_Start] Done"
}

Firmware_Diy_Main() {
	ECHO "[Firmware_Diy_Main] Starting ..."
	CD ${WORK}
	chmod 777 -R ${Scripts} ${CustomFiles}
	if [[ ${AutoBuild_Features} == true ]]
	then
		AddPackage other Hyy2001X AutoBuild-Packages master
		echo -e "\nCONFIG_PACKAGE_luci-app-autoupdate=y" >> ${CONFIG_FILE}
		AutoUpdate_Version=$(awk -F '=' '/Version/{print $2}' $(PKG_Finder d package AutoBuild-Packages)/autoupdate/files/bin/autoupdate | awk 'NR==1')
		cat >> $(PKG_Finder d package AutoBuild-Packages)/autoupdate/files/etc/autoupdate/default <<EOF
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
		Copy ${CustomFiles}/Depends/tools ${BASE_FILES}/bin
		Copy ${CustomFiles}/Depends/profile ${BASE_FILES}/etc
		Copy ${CustomFiles}/Depends/base-files-essential ${BASE_FILES}/lib/upgrade/keep.d
		case "${OP_AUTHOR}/${OP_REPO}" in
		coolsnowwolf/lede)
			Copy ${CustomFiles}/Depends/coremark.sh $(PKG_Finder d "package feeds" coremark)
			sed -i '\/etc\/firewall.user/d;/exit 0/d' ${Version_File}
			if [[ -n ${TARGET_FLAG} ]]
			then
				sed -i "s?${zzz_Default_Version}?${TARGET_FLAG} ${zzz_Default_Version} @ ${Author} [${Display_Date}]?g" ${Version_File}
			else
				sed -i "s?${zzz_Default_Version}?${zzz_Default_Version} @ ${Author} [${Display_Date}]?g" ${Version_File}
			fi
		;;
		immortalwrt/immortalwrt | padavanonly/immortalwrtARM | hanwckf/immortalwrt-mt798x)
			Copy ${CustomFiles}/Depends/openwrt_release_immortalwrt ${BASE_FILES}/etc openwrt_release
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
 	echo -e "### VARIABLE LIST ###\n$(cat ${GITHUB_ENV})\n"
	ECHO "[Firmware_Diy_Main] Done"
}

Firmware_Diy_Other() {
	ECHO "[Firmware_Diy_Other] Starting ..."
	CD ${WORK}
	if [[ ${AutoBuild_Features} == true ]]
	then
		if [[ -n ${Author_URL} ]]
		then
			cat >> ${CONFIG_TEMP} <<EOF

CONFIG_KERNEL_BUILD_USER="${Author}"
CONFIG_KERNEL_BUILD_DOMAIN="${Author_URL}"
EOF
		fi
		if [[ ${AutoBuild_Features_Patch} == true ]]
		then
			case "${OP_AUTHOR}/${OP_REPO}:${OP_BRANCH}" in
			coolsnowwolf/lede:master)
				Patch_Path=${CustomFiles}/Patches/coolsnowwolf-lede
			;;
			immortalwrt/immortalwrt*)
				Patch_Path=${CustomFiles}/Patches/immortalwrt-immortalwrt
			;;
			lienol/openwrt*)
				Patch_Path=${CustomFiles}/Patches/lienol-openwrt
			;;
			openwrt/openwrt*)
				Patch_Path=${CustomFiles}/Patches/openwrt-openwrt
			;;
			padavanonly/immortalwrtARM*)
				Patch_Path=${CustomFiles}/Patches/padavanonly-immortalwrtARM
			;;
			hanwckf/immortalwrt-mt798x*)
				Patch_Path=${CustomFiles}/Patches/immortalwrt-mt798x
			;;
			esac
			if [[ -d ${Patch_Path} ]]
			then
				for i in $(du -ah ${Patch_Path} | awk '{print $2}' | sort | uniq)
				do
					if [[ -f $i ]]
					then
						if [[ $i =~ "-generic.patch" ]]
						then
							ECHO "Found generic patch file: $i"
							patch < $i -p1 -d ${WORK}
						elif [[ $i =~ "-${TARGET_BOARD}.patch" ]]
						then
							ECHO "Found board ${TARGET_BOARD} patch file: $i"
							patch < $i -p1 -d ${WORK}
						elif [[ $i =~ "-${TARGET_PROFILE}.patch" ]]
						then
							ECHO "Found profile ${TARGET_PROFILE} patch file: $i"
							patch < $i -p1 -d ${WORK}
						fi
					fi
				done ; unset i
			fi
		fi
		if [[ ${AutoBuild_Features_Kconfig} == true ]]
		then
			Kconfig_Path=${CustomFiles}/Kconfig
			Tree=${WORK}/target/linux
			if [[ -d ${Kconfig_Path} ]]
			then
				cd ${Kconfig_Path}
				for i in $(du -a | awk '{print $2}' | busybox sed -r 's/.\//\1/' | grep -wv '^.' | sort | uniq)
				do
					if [[ -d $i && $(ls -1 $i 2> /dev/null) ]]
					then
						:
					elif [[ -e $i ]]
					then
						_Kconfig=$(dirname $i)
						__Kconfig=$(basename $i)
						ECHO " - Found Kconfig_file: ${__Kconfig} at ${_Kconfig}"
						if [[ -e ${Tree}/$i && ${__Kconfig} != config-generic ]]
						then
							ECHO " -- Found Tree: ${Tree}/$i, refreshing ${Tree}/$i ..."
							echo >> ${Tree}/$i
							if [[ $? == 0 ]]
							then
								cat $i >> ${Tree}/$i
								ECHO " --- Done"
							else
								ECHO " --- Failed to write new content ..."
							fi
						elif [[ ${__Kconfig} == config-generic ]]
						then
							for j in $(ls -1 ${Tree}/${_Kconfig} | egrep "config-[0-9]+")
							do
								ECHO " -- Generic Kconfig_file, refreshing ${Tree}/${_Kconfig}/$j ..."
								echo >> ${Tree}/${_Kconfig}/$j
								if [[ $? == 0 ]]
								then
									cat $i >> ${Tree}/${_Kconfig}/$j
									ECHO " --- Done"
								else
									ECHO " --- Failed to write new content ..."
								fi
							done
						fi
					fi
				done ; unset i
			fi
		fi
	fi
	CD ${WORK}
	ECHO "[Firmware_Diy_Other] Done"
}

Firmware_Diy_End() {
	ECHO "[Firmware_Diy_End] Starting ..."
	source ${GITHUB_ENV}
	ECHO "[$(date "+%H:%M:%S")] Actions Avaliable: $(df -h | grep "/dev/root" | awk '{printf $4}')"
	cd ${WORK}
	echo -e "### FIRMWARE OUTPUT ###"
	du -ah bin/targets | egrep -v "${Regex_Skip}"
	MKDIR ${WORK}/bin/Firmware
	Fw_Path="${WORK}/bin/targets/${TARGET_BOARD}/${TARGET_SUBTARGET}"
	cd "${Fw_Path}"
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
		mv -f ${Fw_Path}/AutoBuild-* bin/Firmware
	fi
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
			ECHO "Copy [$1] to [${Fw}] ..."
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
			cut -d "*" -f2 <<< "${X}"
		done
	else
		while [[ $1 ]];do
			for X in $(List_sha256);do
				[[ ${X} == *$1 ]] && cut -d "*" -f2 <<< "${X}"
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
	List_sha256 | cut -d "*" -f2 | cut -d "." -f2-3 | sort | uniq
}

Get_sha256() {
	List_sha256 | grep $1 | awk '{print $1}' | cut -c1-5
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
		ECHO "Syntax error: [$#] [$*]"
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
	while [[ $1 ]]
	do
		if [[ ! -d $(dirname $1) ]]
		then
			mkdir -p $(dirname $1)
			if [[ $? != 0 ]]
			then
				ECHO "Failed to create parent directory: [$(dirname $1)] ..."
				return 0
			fi
		fi
		if [[ ! -d $1 ]]
		then
			mkdir -p $1 || ECHO "Failed to create sub directory: [$1] ..."
		else
			ECHO "Create directory: [$(dirname $1)] ..."
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
	PKG_DIR=$1
	[[ ! ${PKG_DIR} =~ ${GITHUB_WORKSPACE} ]] && PKG_DIR=package/${PKG_DIR}
	REPO_URL="https://github.com/$2/$3"
	PKG_NAME=$3
	REPO_BRANCH=$4

	MKDIR ${PKG_DIR}
	if [[ -d ${PKG_DIR}/${PKG_NAME} ]]
	then
		ECHO "Removing old package: [${PKG_NAME}] ..."
		rm -rf "${PKG_DIR}/${PKG_NAME}"
	fi

	if [[ -z ${REPO_BRANCH} ]]
	then
		REPO_BRANCH=main
	fi
	ECHO "Downloading package [${PKG_NAME}] to ${PKG_DIR} ..."
	git clone --depth 1 -b ${REPO_BRANCH} ${REPO_URL} ${PKG_DIR}/${PKG_NAME}/ > /dev/null 2>&1
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
		ECHO "[C] Copying $(basename $1) to $2 ..."
		cp -a $1 $2
	else
		ECHO "[R] Copying $(basename $1) to $2 [$3] ..."
		cp -a $1 $2/$3
	fi
	[[ $? == 0 ]] && ECHO "Done"
}

ReleaseDL() {
	if [[ $# -lt 3 ]]
	then
		ECHO "Syntax error: [$#] [$*]"
		return 0
	fi
	
	API_URL=$1
	FILE_NAME=$2
	TARGET_FILE_PATH=$3
	TARGET_FILE_RENAME=$4
	API_FILE=/tmp/API.json
	
	if [[ ! -d ${TARGET_FILE_PATH} ]]
	then
		MKDIR "${TARGET_FILE_PATH}"
	fi
	
	rm -f ${API_FILE}
	wget --quiet --no-check-certificate --tries 5 --timeout 20 $1 -O ${API_FILE}
	if [[ $? != 0 || ! -f ${API_FILE} ]]
	then
		ECHO "Failed to download API ${PKG_NAME} ..."
	fi
	for i in $(seq 0 $(cat ${API_FILE} | jq ".assets | length" 2> /dev/null))
	do
		eval name=$(cat ${API_FILE} | jq ".assets[${i}].name" 2> /dev/null)
		[[ ${name} == null ]] && continue
		case "$name" in
		"${FILE_NAME}")
			eval browser_download_url=$(cat ${API_FILE} | jq ".assets[${i}].browser_download_url" 2> /dev/null)
			if [[ ${browser_download_url} || ${browser_download_url} != null ]]
			then
				# echo $browser_download_url
				[[ ${TARGET_FILE_RENAME} ]] && _FILE=${TARGET_FILE_RENAME} || _FILE=${FILE_NAME}
    				ECHO "Downloading link ${browser_download_url} ..."
				wget --quiet --no-check-certificate \
					--tries 5 --timeout 20 \
					${browser_download_url} \
					-O ${TARGET_FILE_PATH}/${_FILE}
				if [[ $? != 0 || ! -f ${TARGET_FILE_PATH}/${_FILE} ]]
				then
					ECHO "Failed to download ${PKG_NAME} ..."
				else
					ECHO "API: ${API_URL} ; ${FILE_NAME} ; ${_FILE} ; $(du -h ${TARGET_FILE_PATH}/${_FILE})"
					chmod 777 ${TARGET_FILE_PATH}/${_FILE}
				fi
			fi
		;;
		esac
	done
	rm -f ${API_FILE}
}

ClashDL() {
	TMP_PATH=/opt/OpenClash
	
	PLATFORM=$1
	CORE_TYPE=$2
	
	if [[ ! -n $(ls -1 $TMP_PATH 2> /dev/null) ]]
	then
		git clone -b core --depth=1 https://github.com/vernesong/OpenClash $TMP_PATH
	fi
	
	case $CORE_TYPE in
	dev | meta)
		CORE_PATH=$TMP_PATH/dev/$CORE_TYPE
	;;
	premium | tun)
		CORE_PATH=$TMP_PATH/dev/premium
	;;
	esac
	
	CORE=(
		$(ls -1 $CORE_PATH | grep "clash-linux-$PLATFORM" | tr '\n' ' ')
	)
	
	case $CORE_TYPE in
	dev | meta)
		IS_CORE="clash-linux-${PLATFORM}.tar.gz"
		if [[ -f ${CORE_PATH}/${IS_CORE} ]]
		then
			TARGET_CORE=${IS_CORE}
		fi
	;;
	*)
		IS_CORE=$(ls -1 $CORE_PATH | egrep -o "clash-linux-${PLATFORM}-[0-9]{4}\.[0-9]{2}\.[0-9]{2}-[0-9]{2}-[A-Za-z0-9]+\.gz")
		if [[ ${IS_CORE} && -f ${CORE_PATH}/${IS_CORE} ]]
		then
			TARGET_CORE=${IS_CORE}
		fi
	esac
	
	if [[ ! $TARGET_CORE ]]
	then
		ECHO "$PLATFORM $CORE_TYPE Not found"
		for i in meta
		do
			cd $TMP_PATH/dev/$i
			SUP_PLATDORM=$(ls -1 2> /dev/null | sed -r 's/clash-linux-(.*).tar.gz/\1/')
			ECHO "CORE Supported platform: \n$SUP_PLATDORM"
			cd - > /dev/null
		done
		return
	else
		ECHO "TARGET_CORE: $TARGET_CORE"
	fi
	MKDIR ${BASE_FILES}/etc/openclash/core
	case $CORE_TYPE in
	dev | meta)
		tar -xvzf $CORE_PATH/$TARGET_CORE -C ${TMP_PATH}
		if [[ $CORE_TYPE == dev ]]
		then
			chmod 777 ${TMP_PATH}/clash
			mv -f ${TMP_PATH}/clash ${BASE_FILES}/etc/openclash/core/clash
			ECHO "CORE Size: $(du -h ${BASE_FILES}/etc/openclash/core/clash)"
		fi
		if [[ $CORE_TYPE == meta ]]
		then
			chmod 777 ${TMP_PATH}/clash
			mv -f ${TMP_PATH}/clash ${BASE_FILES}/etc/openclash/core/clash_meta
			ECHO "CORE Size: $(du -h ${BASE_FILES}/etc/openclash/core/clash_meta)"
		fi
	;;
	premium | tun)
		gzip -dk -c $CORE_PATH/$TARGET_CORE > ${TMP_PATH}/clash_tun
		chmod 777 ${TMP_PATH}/clash_tun
		mv -f ${TMP_PATH}/clash_tun ${BASE_FILES}/etc/openclash/core/clash_tun
		ECHO "CORE Size: $(du -h ${BASE_FILES}/etc/openclash/core/clash_tun)"
	;;
	esac
}
