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
	[ -z ${Lede_Version} ] && Lede_Version="Openwrt"
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

	[ -d "package/${PKG_DIR}" ] && mkdir -p package/${PKG_DIR}
	[ -d "package/${PKG_DIR}/${PKG_NAME}" ] && rm -rf package/${PKG_DIR}/${PKG_NAME}
	[ -d "${PKG_NAME}" ] && rm -rf ${PKG_NAME}
	Retry_Times=3
	while [ ! -f "${PKG_NAME}/Makefile" ]
	do
		echo "[$(date "+%H:%M:%S")] Checking out package [${PKG_NAME}] to package/${PKG_DIR} ..."
		case "${PKG_PROTO}" in
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
			rm -rf ${PKG_NAME}
			sleep 3
		fi
	done
}

Replace_File() {
	FILE_NAME=${1}
	PATCH_DIR=${GITHUB_WORKSPACE}/openwrt/${2}
	FILE_RENAME=${3}
	[ ! -d "${PATCH_DIR}" ] && mkdir -p "${PATCH_DIR}"

	[ -f "${GITHUB_WORKSPACE}/${FILE_NAME}" ] && _TYPE1="f" && _TYPE2="File"
	[ -d "${GITHUB_WORKSPACE}/${FILE_NAME}" ] && _TYPE1="d" && _TYPE2="Folder"
	
	if [ -e "${GITHUB_WORKSPACE}/${FILE_NAME}" ];then
		[[ ! -z "${FILE_RENAME}" ]] && _RENAME="${FILE_RENAME}" || _RENAME=""
		if [ -${_TYPE1} "${GITHUB_WORKSPACE}/${FILE_NAME}" ];then
			echo "[$(date "+%H:%M:%S")] Move ${FILE_NAME} to ${PATCH_DIR}/${FILE_RENAME} ..."
			mv -f ${GITHUB_WORKSPACE}/${FILE_NAME} ${PATCH_DIR}/${_RENAME}
		else
			echo "[$(date "+%H:%M:%S")] Customize ${_TYPE2} [${FILE_NAME}] is not detected,skip move ..."
		fi
	fi
	unset _RENAME _TYPE1 _TYPE2
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
			echo -e "Update package ${PKG_NAME} [${Source_Version}] to [${Offical_Version}] ..."
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
