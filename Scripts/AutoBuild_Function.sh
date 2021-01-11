#!/bin/bash
# https://github.com/Hyy2001X/AutoBuild-Actions
# AutoBuild Module by Hyy2001
# AutoBuild Functions

GET_TARGET_INFO() {
	[ -f ${GITHUB_WORKSPACE}/Openwrt.info ] && . ${GITHUB_WORKSPACE}/Openwrt.info
	Default_File="package/lean/default-settings/files/zzz-default-settings"
	[ -f ${Default_File} ] && Lede_Version=$(egrep -o "R[0-9]+\.[0-9]+\.[0-9]+" $Default_File)
	[ -z ${Lede_Version} ] && Lede_Version="Openwrt"
	Openwrt_Version="${Lede_Version}-${Compile_Date}"
	TARGET_PROFILE=$(egrep -o "CONFIG_TARGET.*DEVICE.*=y" .config | sed -r 's/.*DEVICE_(.*)=y/\1/')
	[ -z "${TARGET_PROFILE}" ] && TARGET_PROFILE="${Default_Device}"
	TARGET_BOARD=$(awk -F '[="]+' '/TARGET_BOARD/{print $2}' .config)
	TARGET_SUBTARGET=$(awk -F '[="]+' '/TARGET_SUBTARGET/{print $2}' .config)
	Github_Repo="$(grep "https://github.com/[a-zA-Z0-9]" ${GITHUB_WORKSPACE}/.git/config | cut -c8-100)"
}

Diy_Part1_Base() {
	Diy_Core
	Mkdir package/lean
	if [ "${INCLUDE_Latest_Ray}" == "true" ];then
		Update_Makefile xray package/lean/xray
		Update_Makefile v2ray package/lean/v2ray
		Update_Makefile v2ray-plugin package/lean/v2ray-plugin
	fi
	if [ "${INCLUDE_SSR_Plus}" == "true" ];then
		ExtraPackages git lean helloworld https://github.com/fw876 master
		sed -i 's/143/143,25,5222/' package/lean/helloworld/luci-app-ssr-plus/root/etc/init.d/shadowsocksr
	fi
	Replace_File Scripts/AutoBuild_Tools.sh package/base-files/files/bin
}

Diy_Part2_Base() {
	Diy_Core
	GET_TARGET_INFO
	if [ "${INCLUDE_AutoUpdate}" == "true" ];then
		Replace_File Scripts/AutoUpdate.sh package/base-files/files/bin
		ExtraPackages git lean luci-app-autoupdate https://github.com/Hyy2001X main
		sed -i '/luci-app-autoupdate/d' .config > /dev/null 2>&1
		echo "CONFIG_PACKAGE_luci-app-autoupdate=y" >> .config
	fi
	AutoUpdate_Version=$(awk 'NR==6' package/base-files/files/bin/AutoUpdate.sh | awk -F '[="]+' '/Version/{print $2}')
	[[ -z "${AutoUpdate_Version}" ]] && AutoUpdate_Version="Unknown version"
	echo "Author: ${Author}"
	echo "Openwrt Version: ${Openwrt_Version}"
	echo "AutoUpdate Version: ${AutoUpdate_Version}"
	echo "Router: ${TARGET_PROFILE}"
	echo "Github: ${Github_Repo}"
	[ -f $Default_File ] && sed -i "s?${Lede_Version}?${Lede_Version} Compiled by ${Author} [${Display_Date}]?g" $Default_File
	echo "${Openwrt_Version}" > package/base-files/files/etc/openwrt_info
	echo "${Github_Repo}" >> package/base-files/files/etc/openwrt_info
	echo "${TARGET_PROFILE}" >> package/base-files/files/etc/openwrt_info
	sed -i "s?Openwrt?Openwrt ${Openwrt_Version} / AutoUpdate ${AutoUpdate_Version}?g" package/base-files/files/etc/banner
}

Diy_Part3_Base() {
	Diy_Core
	GET_TARGET_INFO
	Default_Firmware="openwrt-${TARGET_BOARD}-${TARGET_SUBTARGET}-${TARGET_PROFILE}-squashfs-sysupgrade.bin"
	AutoBuild_Firmware="AutoBuild-${TARGET_PROFILE}-${Openwrt_Version}.bin"
	AutoBuild_Detail="AutoBuild-${TARGET_PROFILE}-${Openwrt_Version}.detail"
	Mkdir bin/Firmware
	echo "Firmware: ${AutoBuild_Firmware}"
	mv -f bin/targets/"${TARGET_BOARD}/${TARGET_SUBTARGET}/${Default_Firmware}" bin/Firmware/"${AutoBuild_Firmware}"
	_MD5=$(md5sum bin/Firmware/${AutoBuild_Firmware} | cut -d ' ' -f1)
	_SHA256=$(sha256sum bin/Firmware/${AutoBuild_Firmware} | cut -d ' ' -f1)
	echo -e "\nMD5:${_MD5}\nSHA256:${_SHA256}" > bin/Firmware/"${AutoBuild_Detail}"
}

Mkdir() {
	_DIR=${1}
	if [ ! -d "${_DIR}" ];then
		echo "[$(date "+%H:%M:%S")] Creating new folder [${_DIR}] ..."
		mkdir -p ${_DIR}
	fi
	unset _DIR
}

ExtraPackages() {
	PKG_PROTO=${1}
	PKG_DIR=${2}
	PKG_NAME=${3}
	REPO_URL=${4}
	REPO_BRANCH=${5}

	Mkdir package/${PKG_DIR}
	[ -d "package/${PKG_DIR}/${PKG_NAME}" ] && rm -rf package/${PKG_DIR}/${PKG_NAME}
	[ -d "${PKG_NAME}" ] && rm -rf ${PKG_NAME}
	Retry_Times=3
	while [ ! -f "${PKG_NAME}/Makefile" ]
	do
		echo "[$(date "+%H:%M:%S")] Checking out package [${PKG_NAME}] to package/${PKG_DIR} ..."
		case "${PKG_PROTO}" in
		git)
		
			if [[ -z "${REPO_BRANCH}" ]];then
				echo "[$(date "+%H:%M:%S")] Missing important options,skip check out..."
				break
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
		if [ -f ${PKG_NAME}/Makefile ] || [ -f ${PKG_NAME}/README* ];then
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
	PKG_NAME="$1"
	Makefile="$2/Makefile"
	if [ -f "${Makefile}" ];then
		PKG_URL_MAIN="$(grep "PKG_SOURCE_URL:=" ${Makefile} | cut -c17-100)"
		_process1=${PKG_URL_MAIN##*com/}
		_process2=${_process1%%/tar*}
		api_URL="https://api.github.com/repos/${_process2}/releases"
		PKG_DL_URL="https://codeload.github.com/${_process2}/tar.gz/v"
		Offical_Version="$(curl -s ${api_URL} 2>/dev/null | grep 'tag_name' | egrep -o '[0-9].+[0-9.]+' | awk 'NR==1')"
		Source_Version="$(grep "PKG_VERSION:=" ${Makefile} | cut -c14-20)"
		Source_HASH="$(grep "PKG_HASH:=" ${Makefile} | cut -c11-100)"
		echo -e "Current ${PKG_NAME} version: ${Source_Version}\nOffical ${PKG_NAME} version: ${Offical_Version}"
		if [[ ! "${Source_Version}" == "${Offical_Version}" ]];then
			echo -e "Updating package ${PKG_NAME} [${Source_Version}] to [${Offical_Version}] ..."
			sed -i "s?PKG_VERSION:=${Source_Version}?PKG_VERSION:=${Offical_Version}?g" ${Makefile}
			wget -q "${PKG_DL_URL}${Offical_Version}?" -O /tmp/tmp_file
			if [[ $? == 0 ]];then
				Offical_HASH=$(sha256sum /tmp/tmp_file | cut -d ' ' -f1)
				sed -i "s?PKG_HASH:=${Source_HASH}?PKG_HASH:=${Offical_HASH}?g" ${Makefile}
			else
				echo "Update package [${PKG_NAME}] error,skip update ..."
			fi
		fi
	else
		echo "Package ${PKG_NAME} is not detected,skip update ..."
	fi
	unset _process1 _process2 Offical_Version
}
