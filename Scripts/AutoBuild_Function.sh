#!/bin/bash
# https://github.com/Hyy2001X/AutoBuild-Actions
# AutoBuild Module by Hyy2001
# AutoBuild Functions

GET_TARGET_INFO() {
	Diy_Core
	[ -f ${GITHUB_WORKSPACE}/Openwrt.info ] && . ${GITHUB_WORKSPACE}/Openwrt.info
	AutoUpdate_Version=$(awk 'NR==6' package/base-files/files/bin/AutoUpdate.sh | awk -F '[="]+' '/Version/{print $2}')
	[ -z ${AutoUpdate_Version} ] && AutoUpdate_Version="未知"
	Default_File="package/lean/default-settings/files/zzz-default-settings"
	[ -f ${Default_File} ] && Lede_Version=$(egrep -o "R[0-9]+\.[0-9]+\.[0-9]+" $Default_File)
	[ -z ${Lede_Version} ] && Lede_Version="AutoBuild"
	Openwrt_Version="${Lede_Version}-${Compile_Date}"
	TARGET_PROFILE=$(egrep -o "CONFIG_TARGET.*DEVICE.*=y" .config | sed -r 's/.*DEVICE_(.*)=y/\1/')
	[ -z "${TARGET_PROFILE}" ] && TARGET_PROFILE="${Default_Device}"
	TARGET_BOARD=$(awk -F '[="]+' '/TARGET_BOARD/{print $2}' .config)
	TARGET_SUBTARGET=$(awk -F '[="]+' '/TARGET_SUBTARGET/{print $2}' .config)
}

ExtraPackages() {
	PKG_PROTO=${1}
	PKG_DIR=${2}
	PKG_NAME=${3}
	REPO_URL=${4}
	REPO_BRANCH=${5}

	[ -d package/${PKG_DIR} ] && mkdir -p package/${PKG_DIR}
	[ -d package/${PKG_DIR}/${PKG_NAME} ] && rm -rf package/${PKG_DIR}/${PKG_NAME}
	[ -d ${PKG_NAME} ] && rm -rf ${PKG_NAME}
	Retry_Times=3
	while [ ! -f ${PKG_NAME}/Makefile ]
	do
		echo "[$(date "+%H:%M:%S")] Checking out package [${PKG_NAME}] to package/${PKG_DIR} ..."
		case ${PKG_PROTO} in
		git)
			git clone -b ${REPO_BRANCH} ${REPO_URL}/${PKG_NAME} ${PKG_NAME} > /dev/null 2>&1
		;;
		svn)
			svn checkout ${REPO_URL}/${PKG_NAME} ${PKG_NAME} > /dev/null 2>&1
		esac
		if [ -f ${PKG_NAME}/Makefile ] || [ -f ${PKG_NAME}/README* ];then
			echo "[$(date "+%H:%M:%S")] Package [${PKG_NAME}] is detected!"
			mv ${PKG_NAME} package/${PKG_DIR}
			break
		else
			[ ${Retry_Times} -lt 1 ] && echo "[$(date "+%H:%M:%S")] Skip check out package [${PKG_NAME}] ..." && break
			echo "[$(date "+%H:%M:%S")] [Error] [${Retry_Times}] Checkout failed,retry in 3s ..."
			Retry_Times=$(($Retry_Times - 1))
			rm -rf ${PKG_NAME} > /dev/null 2>&1
			sleep 3
		fi
	done
}

Replace_File() {
	FILE_NAME=${1}
	PATCH_DIR=${GITHUB_WORKSPACE}/openwrt/${2}
	FILE_RENAME=${3}
	[ ! -d "${PATCH_DIR}" ] && mkdir -p ${PATCH_DIR}

	[ -f "${GITHUB_WORKSPACE}/${FILE_NAME}" ] && _TYPE1="f" && _TYPE2="File"
	[ -d "${GITHUB_WORKSPACE}/${FILE_NAME}" ] && _TYPE1="d" && _TYPE2="Folder"
	
	if [ -e "${GITHUB_WORKSPACE}/${FILE_NAME}" ];then
		[ ! -z "${FILE_RENAME}" ] && _RENAME="${FILE_RENAME}" || _RENAME=""
		if [ -${_TYPE1} "${GITHUB_WORKSPACE}/${FILE_NAME}" ];then
			echo "[$(date "+%H:%M:%S")] Move ${FILE_NAME} to ${PATCH_DIR}/${FILE_RENAME} ..."
			mv -f ${GITHUB_WORKSPACE}/${FILE_NAME} ${PATCH_DIR}/${_RENAME}
		else
			echo "[$(date "+%H:%M:%S")] Customize ${_TYPE2} [${FILE_NAME}] is not detected,skip move ..."
		fi
	fi
	unset _RENAME
}