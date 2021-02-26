#!/bin/bash
# https://github.com/Hyy2001X/AutoBuild-Actions
# AutoBuild Module by Hyy2001
# AutoBuild Functions

GET_TARGET_INFO() {
	Home=${GITHUB_WORKSPACE}/openwrt
	echo "Home Path: ${Home}"
	[ -f ${GITHUB_WORKSPACE}/Openwrt.info ] && . ${GITHUB_WORKSPACE}/Openwrt.info
	Default_File="package/lean/default-settings/files/zzz-default-settings"
	[ -f ${Default_File} ] && Lede_Version="$(egrep -o "R[0-9]+\.[0-9]+\.[0-9]+" ${Default_File})"
	[[ -z ${Lede_Version} ]] && Lede_Version="Openwrt"
	Openwrt_Version="${Lede_Version}-${Compile_Date}"
	x86_Test="$(egrep -o "CONFIG_TARGET.*DEVICE.*=y" .config | sed -r 's/CONFIG_TARGET_(.*)_DEVICE_(.*)=y/\1/')"
	if [[ "${x86_Test}" == "x86_64" ]];then
		TARGET_PROFILE="x86_64"
	else
		TARGET_PROFILE="$(egrep -o "CONFIG_TARGET.*DEVICE.*=y" .config | sed -r 's/.*DEVICE_(.*)=y/\1/')"
	fi
	[[ -z "${TARGET_PROFILE}" ]] && TARGET_PROFILE="${Default_Device}"
	case "${TARGET_PROFILE}" in
	x86_64)
		grep "CONFIG_TARGET_IMAGES_GZIP=y" ${Home}/.config
		if [[ ! $? -ne 0 ]];then
			Firmware_sfx="img.gz"
		else
			Firmware_sfx="img"
		fi
	;;
	*)
		Firmware_sfx="bin"
	;;
	esac
	TARGET_BOARD="$(awk -F '[="]+' '/TARGET_BOARD/{print $2}' .config)"
	TARGET_SUBTARGET="$(awk -F '[="]+' '/TARGET_SUBTARGET/{print $2}' .config)"
	Github_Repo="$(grep "https://github.com/[a-zA-Z0-9]" ${GITHUB_WORKSPACE}/.git/config | cut -c8-100)"
	AutoBuild_Info=${GITHUB_WORKSPACE}/openwrt/package/base-files/files/etc/openwrt_info
}

Diy_Part1_Base() {
	Diy_Core
	Mkdir package/lean
	Replace_File Customize/banner package/base-files/files/etc
	if [[ "${INCLUDE_SSR_Plus}" == "true" ]];then
		ExtraPackages git lean helloworld https://github.com/fw876 master
		sed -i 's/143/143,25,5222/' package/lean/helloworld/luci-app-ssr-plus/root/etc/init.d/shadowsocksr
	fi
	if [[ "${INCLUDE_HelloWorld}" == "true" ]];then
		ExtraPackages git lean luci-app-vssr https://github.com/jerrykuku master
		ExtraPackages git lean lua-maxminddb https://github.com/jerrykuku master
		PKG_Finder d package xray-core
		[[ -z "${PKG_RESULT}" ]] && ExtraPackages svn other xray-core https://github.com/fw876/helloworld/trunk
	fi
	if [[ "${INCLUDE_Bypass}" == "true" ]];then
		ExtraPackages git other luci-app-bypass https://github.com/garypang13 main
		find package/*/ feeds/*/ -maxdepth 2 -path "*luci-app-bypass/Makefile" | xargs -i sed -i 's/shadowsocksr-libev-ssr-redir/shadowsocksr-libev-alt/g' {}
		find package/*/ feeds/*/ -maxdepth 2 -path "*luci-app-bypass/Makefile" | xargs -i sed -i 's/shadowsocksr-libev-ssr-server/shadowsocksr-libev-server/g' {}
	fi
	if [[ "${INCLUDE_OpenClash}" == "true" ]];then
		ExtraPackages git other OpenClash https://github.com/vernesong master
	fi
	if [[ "${INCLUDE_AutoBuild_Tools}" == "true" ]];then
		Replace_File Scripts/AutoBuild_Tools.sh package/base-files/files/bin
	fi
	if [[ "${INCLUDE_Passwall}" == "true" ]];then
		ExtraPackages git lienol openwrt-passwall https://github.com/xiaorouji main
	fi
	if [[ "${INCLUDE_mt7621_OC1000MHz}" == "true" ]];then
		Replace_File Customize/102-mt7621-fix-cpu-clk-add-clkdev.patch target/linux/ramips/patches-5.4
	fi
	if [[ "${INCLUDE_OAF}" == "true" ]];then
		echo "Warning: OpenAppFilter may conflict with FLowoffload/SFE !"
		ExtraPackages git other OpenAppFilter https://github.com/destan19
	fi
	Update_Makefile xray-core package/lean/helloworld/xray-core
	Update_Makefile exfat package/kernel/exfat
	# ExtraPackages svn kernel mt76 https://github.com/openwrt/openwrt/trunk/package/kernel
}

Diy_Part2_Base() {
	Diy_Core
	GET_TARGET_INFO
	Replace_File Customize/uhttpd.po feeds/luci/applications/luci-app-uhttpd/po/zh-cn
	Replace_File Customize/webadmin.po package/lean/luci-app-webadmin/po/zh-cn
	Replace_File Customize/mwan3.config package/feeds/packages/mwan3/files/etc/config mwan3
	if [[ "${INCLUDE_DRM_I915}" == "true" ]];then
		Replace_File Customize/config-5.4 target/linux/x86
	fi
	case ${TARGET_PROFILE} in
	d-team_newifi-d2)
		Replace_File Customize/system_newifi-d2 package/base-files/files/etc/config system
	;;
	*)
		Replace_File Customize/system_common package/base-files/files/etc/config system
	;;
	esac
	[ -f "${Default_File}" ] && sed -i "s?iptables?#iptables?g" ${Default_File} > /dev/null 2>&1
	if [[ "${INCLUDE_AutoUpdate}" == "true" ]];then
		ExtraPackages git lean luci-app-autoupdate https://github.com/Hyy2001X main
		sed -i '/luci-app-autoupdate/d' .config > /dev/null 2>&1
		echo -e "\nCONFIG_PACKAGE_luci-app-autoupdate=y" >> .config
		Replace_File Scripts/AutoUpdate.sh package/base-files/files/bin
		AutoUpdate_Version=$(awk 'NR==6' package/base-files/files/bin/AutoUpdate.sh | awk -F '[="]+' '/Version/{print $2}')
		[[ -z "${AutoUpdate_Version}" ]] && AutoUpdate_Version="Unknown"
		sed -i "s?Openwrt?Openwrt ${Openwrt_Version} / AutoUpdate ${AutoUpdate_Version}?g" package/base-files/files/etc/banner
		echo "AutoUpdate Version: ${AutoUpdate_Version}"
	else
		sed -i "s?Openwrt?Openwrt ${Openwrt_Version}?g" package/base-files/files/etc/banner
	fi
	[[ -z "${Author}" ]] && Author="Unknown"
	echo "Author: ${Author}"
	echo "Openwrt Version: ${Openwrt_Version}"
	echo "Router: ${TARGET_PROFILE}"
	echo "Github: ${Github_Repo}"
	[ -f "$Default_File" ] && sed -i "s?${Lede_Version}?${Lede_Version} Compiled by ${Author} [${Display_Date}]?g" $Default_File
	echo "${Openwrt_Version}" > ${AutoBuild_Info}
	echo "${Github_Repo}" >> ${AutoBuild_Info}
	echo "${TARGET_PROFILE}" >> ${AutoBuild_Info}
	echo "Firmware Type: ${Firmware_sfx}"
	echo "Writting Type: ${Firmware_sfx} to ${AutoBuild_Info} ..."
	echo "${Firmware_sfx}" >> ${AutoBuild_Info}
	
}

Diy_Part3_Base() {
	Diy_Core
	GET_TARGET_INFO
	Firmware_Path="bin/targets/${TARGET_BOARD}/${TARGET_SUBTARGET}"
	Mkdir bin/Firmware
	case "${TARGET_PROFILE}" in
	x86_64)
		cd ${Firmware_Path}
		Legacy_Firmware=openwrt-${TARGET_BOARD}-${TARGET_SUBTARGET}-generic-squashfs-combined.${Firmware_sfx}
		EFI_Firmware=openwrt-${TARGET_BOARD}-${TARGET_SUBTARGET}-generic-squashfs-combined-efi.${Firmware_sfx}
		AutoBuild_Firmware="AutoBuild-${TARGET_PROFILE}-${Openwrt_Version}"
		if [ -f "${Legacy_Firmware}" ];then
			_MD5=$(md5sum ${Legacy_Firmware} | cut -d ' ' -f1)
			_SHA256=$(sha256sum ${Legacy_Firmware} | cut -d ' ' -f1)
			touch ${Home}/bin/Firmware/${AutoBuild_Firmware}.detail
			echo -e "\nMD5:${_MD5}\nSHA256:${_SHA256}" > ${Home}/bin/Firmware/${AutoBuild_Firmware}-Legacy.detail
			mv -f ${Legacy_Firmware} ${Home}/bin/Firmware/${AutoBuild_Firmware}-Legacy.${Firmware_sfx}
			echo "Legacy Firmware is detected !"
		fi
		if [ -f "${EFI_Firmware}" ];then
			_MD5=$(md5sum ${EFI_Firmware} | cut -d ' ' -f1)
			_SHA256=$(sha256sum ${EFI_Firmware} | cut -d ' ' -f1)
			touch ${Home}/bin/Firmware/${AutoBuild_Firmware}-UEFI.detail
			echo -e "\nMD5:${_MD5}\nSHA256:${_SHA256}" > ${Home}/bin/Firmware/${AutoBuild_Firmware}-UEFI.detail
			cp ${EFI_Firmware} ${Home}/bin/Firmware/${AutoBuild_Firmware}-UEFI.${Firmware_sfx}
			echo "UEFI Firmware is detected !"
		fi
	;;
	*)
		cd ${Home}
		Default_Firmware="openwrt-${TARGET_BOARD}-${TARGET_SUBTARGET}-${TARGET_PROFILE}-squashfs-sysupgrade.${Firmware_sfx}"
		AutoBuild_Firmware="AutoBuild-${TARGET_PROFILE}-${Openwrt_Version}.${Firmware_sfx}"
		AutoBuild_Detail="AutoBuild-${TARGET_PROFILE}-${Openwrt_Version}.detail"
		echo "Firmware: ${AutoBuild_Firmware}"
		mv -f ${Firmware_Path}/${Default_Firmware} bin/Firmware/${AutoBuild_Firmware}
		_MD5=$(md5sum bin/Firmware/${AutoBuild_Firmware} | cut -d ' ' -f1)
		_SHA256=$(sha256sum bin/Firmware/${AutoBuild_Firmware} | cut -d ' ' -f1)
		echo -e "\nMD5:${_MD5}\nSHA256:${_SHA256}" > bin/Firmware/${AutoBuild_Detail}
	;;
	esac
	cd ${Home}
	echo "Actions Avaliable: $(df -h | grep "/dev/root" | awk '{printf $4}')"
}

Mkdir() {
	_DIR=${1}
	if [ ! -d "${_DIR}" ];then
		echo "[$(date "+%H:%M:%S")] Creating new folder [${_DIR}] ..."
		mkdir -p ${_DIR}
	fi
	unset _DIR
}

PKG_Finder() {
	unset PKG_RESULT
	PKG_TYPE=${1}
	PKG_DIR=${2}
	PKG_NAME=${3}
	[[ -z ${PKG_TYPE} ]] && [[ -z ${PKG_NAME} ]] || [[ -z ${PKG_DIR} ]] && return
	PKG_RESULT=$(find -name ${PKG_DIR}/${PKG_NAME} -type ${PKG_TYPE} -exec echo {} \;)
	if [[ ! -z "${PKG_RESULT}" ]];then
		echo "[${PKG_NAME}] is detected,Dir: ${PKG_RESULT}"
	fi
}

ExtraPackages() {
	PKG_PROTO=${1}
	PKG_DIR=${2}
	PKG_NAME=${3}
	REPO_URL=${4}
	REPO_BRANCH=${5}

	Mkdir package/${PKG_DIR}
	if [ -d "package/${PKG_DIR}/${PKG_NAME}" ];then
		echo "[$(date "+%H:%M:%S")] Removing old package [${PKG_NAME}] ..."
		rm -rf package/${PKG_DIR}/${PKG_NAME}
	fi
	[ -d "${PKG_NAME}" ] && rm -rf ${PKG_NAME}
	Retry_Times=3
	while [ ! -f "${PKG_NAME}/Makefile" ]
	do
		echo "[$(date "+%H:%M:%S")] Checking out package [${PKG_NAME}] to package/${PKG_DIR} ..."
		case "${PKG_PROTO}" in
		git)
		
			if [[ -z "${REPO_BRANCH}" ]];then
				REPO_BRANCH="master"
			fi
			git clone -b ${REPO_BRANCH} ${REPO_URL}/${PKG_NAME} ${PKG_NAME} > /dev/null 2>&1
		;;
		svn)
			svn checkout ${REPO_URL}/${PKG_NAME} ${PKG_NAME} > /dev/null 2>&1
		;;
		*)
			echo "[$(date "+%H:%M:%S")] Wrong option: ${PKG_PROTO} (Can only use git and svn),skip check out..."
			break
		;;
		esac
		if [ "$?" -eq 0 ] || [ -f ${PKG_NAME}/Makefile ] || [ -f ${PKG_NAME}/README* ] || [ ! "$(ls -A ${PKG_NAME})" = "" ];then
			echo "[$(date "+%H:%M:%S")] Package [${PKG_NAME}] is detected!"
			mv -f ${PKG_NAME} package/${PKG_DIR}
			break
		else
			[ ${Retry_Times} -lt 1 ] && echo "[$(date "+%H:%M:%S")] Skip check out package [${PKG_NAME}] ..." && break
			echo "[$(date "+%H:%M:%S")] [Error] [${Retry_Times}] Checkout failed,retry in 3s ..."
			Retry_Times=$(($Retry_Times - 1))
			rm -rf ${PKG_NAME}
			sleep 3
		fi
	done
	unset PKG_PROTO PKG_DIR PKG_NAME REPO_URL REPO_BRANCH
}

Replace_File() {
	FILE_NAME=${1}
	PATCH_DIR=${GITHUB_WORKSPACE}/openwrt/${2}
	FILE_RENAME=${3}
	
	Mkdir "${PATCH_DIR}"
	[ -f "${GITHUB_WORKSPACE}/${FILE_NAME}" ] && _TYPE1="f" && _TYPE2="File"
	[ -d "${GITHUB_WORKSPACE}/${FILE_NAME}" ] && _TYPE1="d" && _TYPE2="Folder"
	if [ -e "${GITHUB_WORKSPACE}/${FILE_NAME}" ];then
		[[ ! -z "${FILE_RENAME}" ]] && _RENAME="${FILE_RENAME}" || _RENAME=""
		if [ -${_TYPE1} "${GITHUB_WORKSPACE}/${FILE_NAME}" ];then
			echo "[$(date "+%H:%M:%S")] Moving [${_TYPE2}] ${FILE_NAME} to ${2}/${FILE_RENAME} ..."
			mv -f ${GITHUB_WORKSPACE}/${FILE_NAME} ${PATCH_DIR}/${_RENAME}
		else
			echo "[$(date "+%H:%M:%S")] Customize ${_TYPE2} [${FILE_NAME}] is not detected,skip move ..."
		fi
	fi
	unset FILE_NAME PATCH_DIR FILE_RENAME _RENAME _TYPE1 _TYPE2
}

Update_Makefile() {
	PKG_NAME=${1}
	Makefile=${2}/Makefile
	[ -f "/tmp/tmp_file" ] && rm -f /tmp/tmp_file
	if [ -f "${Makefile}" ];then
		PKG_URL_MAIN="$(grep "PKG_SOURCE_URL:=" ${Makefile} | cut -c17-100)"
		_process1=${PKG_URL_MAIN##*com/}
		_process2=${_process1%%/tar*}
		api_URL="https://api.github.com/repos/${_process2}/releases"
		PKG_SOURCE_URL="$(grep "PKG_SOURCE_URL:=" ${Makefile} | cut -c17-100)"
		PKG_DL_URL="${PKG_SOURCE_URL%\$(\PKG_VERSION*}"
		Offical_Version="$(curl -s ${api_URL} 2>/dev/null | grep 'tag_name' | egrep -o '[0-9].+[0-9.]+' | awk 'NR==1')"
		if [[ -z "${Offical_Version}" ]];then
			echo "Failed to obtain the Offical version of [${PKG_NAME}],skip update ..."
			return
		fi
		Source_Version="$(grep "PKG_VERSION:=" ${Makefile} | cut -c14-20)"
		Source_HASH="$(grep "PKG_HASH:=" ${Makefile} | cut -c11-100)"
		if [[ -z "${Source_Version}" ]] || [[ -z "${Source_HASH}" ]];then
			echo "Failed to obtain the Source version or HASH,skip update ..."
			return
		fi
		echo -e "Current ${PKG_NAME} version: ${Source_Version}\nOffical ${PKG_NAME} version: ${Offical_Version}"
		if [[ ! "${Source_Version}" == "${Offical_Version}" ]];then
			echo -e "Updating package ${PKG_NAME} [${Source_Version}] to [${Offical_Version}] ..."
			sed -i "s?PKG_VERSION:=${Source_Version}?PKG_VERSION:=${Offical_Version}?g" ${Makefile}
			wget -q "${PKG_DL_URL}${Offical_Version}?" -O /tmp/tmp_file
			if [[ "$?" -eq 0 ]];then
				Offical_HASH="$(sha256sum /tmp/tmp_file | cut -d ' ' -f1)"
				sed -i "s?PKG_HASH:=${Source_HASH}?PKG_HASH:=${Offical_HASH}?g" ${Makefile}
			else
				echo "Failed to update the package [${PKG_NAME}],skip update ..."
			fi
		fi
	else
		echo "Package ${PKG_NAME} is not detected,skip update ..."
	fi
	unset _process1 _process2 Offical_Version Source_Version
}
