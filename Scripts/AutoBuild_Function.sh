#!/bin/bash
# https://github.com/Hyy2001X/AutoBuild-Actions
# AutoBuild Module by Hyy2001
# AutoBuild Functions

GET_TARGET_INFO() {
	Diy_Core
	Home=${GITHUB_WORKSPACE}/openwrt
	[ -f ${GITHUB_WORKSPACE}/Openwrt.info ] && . ${GITHUB_WORKSPACE}/Openwrt.info
	Owner_Repo="$(grep "https://github.com/[a-zA-Z0-9]" ${GITHUB_WORKSPACE}/.git/config | cut -c8-100)"
	Source_Repo="$(grep "https://github.com/[a-zA-Z0-9]" ${Home}/.git/config | cut -c8-100)"
	Source_Owner="$(echo "${Source_Repo}" | egrep -o "[a-z]+" | awk 'NR==4')"
	AB_Firmware_Info=package/base-files/files/etc/openwrt_info
	case ${Source_Owner} in
	coolsnowwolf)
		Version_File="package/lean/default-settings/files/zzz-default-settings"
		Old_Version="$(egrep -o "R[0-9]+\.[0-9]+\.[0-9]+" ${Version_File})"
		Openwrt_Version="${Old_Version}-${Compile_Date}"
	;;
	immortalwrt)
		Version_File="package/base-files/files/etc/openwrt_release"
		Openwrt_Version="${Compile_Date}"
	;;
	*)
		Openwrt_Version="${Compile_Date}"
	;;
	esac
	x86_Test="$(egrep -o "CONFIG_TARGET.*DEVICE.*=y" .config | sed -r 's/CONFIG_TARGET_(.*)_DEVICE_(.*)=y/\1/')"
	if [[ "${x86_Test}" == "x86_64" ]];then
		TARGET_PROFILE="x86_64"
	else
		TARGET_PROFILE="$(egrep -o "CONFIG_TARGET.*DEVICE.*=y" .config | sed -r 's/.*DEVICE_(.*)=y/\1/')"
	fi
	[[ -z "${TARGET_PROFILE}" ]] && TARGET_PROFILE="${Default_Device}"
	case ${TARGET_PROFILE} in
	x86_64)
		grep "CONFIG_TARGET_IMAGES_GZIP=y" ${Home}/.config > /dev/null 2>&1
		if [[ ! "$?" -ne 0 ]];then
			Firmware_Type="img.gz"
		else
			Firmware_Type="img"
		fi
	;;
	*)
		Firmware_Type="bin"
	;;
	esac
	TARGET_BOARD="$(awk -F '[="]+' '/TARGET_BOARD/{print $2}' .config)"
	TARGET_SUBTARGET="$(awk -F '[="]+' '/TARGET_SUBTARGET/{print $2}' .config)"
}

Firmware-Diy_Base() {
	GET_TARGET_INFO
	Auto_ExtraPackages
	chmod +x -R ${GITHUB_WORKSPACE}/Scripts
	chmod +x -R ${GITHUB_WORKSPACE}/CustomFiles
	if [[ "${INCLUDE_AutoBuild_Tools}" == "true" ]];then
		Replace_File Scripts/AutoBuild_Tools.sh package/base-files/files/bin
	fi
	if [[ "${INCLUDE_AutoUpdate}" == "true" ]];then
		ExtraPackages git lean luci-app-autoupdate https://github.com/Hyy2001X main
		Replace_File Scripts/AutoUpdate.sh package/base-files/files/bin
	fi
	if [ -f package/base-files/files/bin/AutoUpdate.sh ];then
		AutoUpdate_Version=$(awk 'NR==6' package/base-files/files/bin/AutoUpdate.sh | awk -F '[="]+' '/Version/{print $2}')
	else
		AutoUpdate_Version=OFF
	fi

	case ${Source_Owner} in
	coolsnowwolf)
		Replace_File CustomFiles/Depends/coremark_lede.sh package/lean/coremark coremark.sh
		Replace_File CustomFiles/Depends/profile_lede package/base-files/files/etc profile
		Replace_File CustomFiles/Depends/cpuinfo_x86 package/lean/autocore/files/x86/sbin cpuinfo

		ExtraPackages git lean luci-theme-argon https://github.com/jerrykuku 18.06
		ExtraPackages git lean helloworld https://github.com/fw876 master
		Update_Makefile xray-core package/lean/helloworld/xray-core
		sed -i 's/143/143,8080/' package/lean/helloworld/luci-app-ssr-plus/root/etc/init.d/shadowsocksr
		sed -i "s?iptables?#iptables?g" ${Version_File} > /dev/null 2>&1
		sed -i "s?${Old_Version}?${Old_Version} Compiled by ${Author} [${Display_Date}]?g" $Version_File

		[[ "${INCLUDE_DRM_I915}" == "true" ]] && Replace_File CustomFiles/Depends/config-5.4 target/linux/x86
	;;
	immortalwrt)
		sed -i 's/143/143,8080/' package/lean/luci-app-ssr-plus/root/etc/init.d/shadowsocksr
		Replace_File CustomFiles/Depends/coremark_ImmortalWrt.sh package/base-files/files/etc coremark.sh
		Replace_File CustomFiles/Depends/ImmortalWrt package/base-files/files/etc openwrt_release
		sed -i "s?Template?Compiled by ${Author} [${Display_Date}]?g" $Version_File
	;;
	openwrt)
		ExtraPackages git other luci-theme-argon https://github.com/jerrykuku
	;;
	esac
	
	case ${Source_Owner} in
	immortalwrt)
		Replace_File CustomFiles/Depends/banner package/lean/default-settings/files openwrt_banner
		sed -i "s?By?By ${Author}?g" package/lean/default-settings/files/openwrt_banner
		sed -i "s?Openwrt?ImmortalWrt ${Openwrt_Version} / AutoUpdate ${AutoUpdate_Version}?g" package/lean/default-settings/files/openwrt_banner
	;;
	*)
		Replace_File CustomFiles/Depends/banner package/base-files/files/etc
		sed -i "s?By?By ${Author}?g" package/base-files/files/etc/banner
		sed -i "s?Openwrt?Openwrt ${Openwrt_Version} / AutoUpdate ${AutoUpdate_Version}?g" package/base-files/files/etc/banner
	;;
	esac

	if [[ "${INCLUDE_Obsolete_PKG_Compatible}" == "true" ]];then
		echo "[$(date "+%H:%M:%S")] Start to run Obsolete_Package_Compatible Scripts ..."
		Current_Branch="$(git branch | sed 's/* //g')"
		case ${Current_Branch} in
		openwrt-19.07 | openwrt-21.02)
			Replace_File CustomFiles/Patches/0003-upx-ucl-${Current_Branch}.patch ./
			cat 0003-upx-ucl-${Current_Branch}.patch | patch -p1 > /dev/null 2>&1
			ExtraPackages svn ../feeds/packages/lang golang https://github.com/coolsnowwolf/packages/trunk/lang
		
			echo "[$(date "+%H:%M:%S")] Start to convert zh-cn translation files to zh_Hans ..."
			Replace_File Scripts/Convert_Translation.sh package
			cd ./package
			bash ./Convert_Translation.sh
			cd ..
		;;
		*)
			echo "[ERROR] Current branch: [${Current_Branch}] is not supported !"
		;;
		esac
	fi

	echo "${Openwrt_Version}" > ${AB_Firmware_Info}
	echo "${Owner_Repo}" >> ${AB_Firmware_Info}
	echo "${TARGET_PROFILE}" >> ${AB_Firmware_Info}
	echo "${Firmware_Type}" >> ${AB_Firmware_Info}

	echo "Author: ${Author}"
	echo "Github: ${Owner_Repo}"
	echo "Router: ${TARGET_PROFILE}"
	echo "Firmware Version: ${Openwrt_Version}"
	echo "Firmware Type: ${Firmware_Type}"
	echo "Source Github: ${Source_Repo}"
}

PS_Firmware() {
	GET_TARGET_INFO
	case ${Source_Owner} in
	immortalwrt)
		_Firmware=immortalwrt
		_Legacy_Firmware=combined-squashfs
		_EFI_Firmware=uefi-gpt-squashfs
	;;
	*)
		_Firmware=openwrt
		_Legacy_Firmware=generic-squashfs-combined
		_EFI_Firmware=generic-squashfs-combined-efi
	;;
	esac
	Firmware_Path="bin/targets/${TARGET_BOARD}/${TARGET_SUBTARGET}"
	Mkdir bin/Firmware
	case "${TARGET_PROFILE}" in
	x86_64)
		cd ${Firmware_Path}
		Legacy_Firmware=${_Firmware}-${TARGET_BOARD}-${TARGET_SUBTARGET}-${_Legacy_Firmware}.${Firmware_Type}
		EFI_Firmware=${_Firmware}-${TARGET_BOARD}-${TARGET_SUBTARGET}-${_EFI_Firmware}.${Firmware_Type}
		AutoBuild_Firmware="AutoBuild-${TARGET_PROFILE}-${Openwrt_Version}"
		if [ -f "${Legacy_Firmware}" ];then
			_MD5=$(md5sum ${Legacy_Firmware} | cut -d ' ' -f1)
			_SHA256=$(sha256sum ${Legacy_Firmware} | cut -d ' ' -f1)
			touch ${Home}/bin/Firmware/${AutoBuild_Firmware}.detail
			echo -e "\nMD5:${_MD5}\nSHA256:${_SHA256}" > ${Home}/bin/Firmware/${AutoBuild_Firmware}-Legacy.detail
			mv -f ${Legacy_Firmware} ${Home}/bin/Firmware/${AutoBuild_Firmware}-Legacy.${Firmware_Type}
			echo "[$(date "+%H:%M:%S")] Legacy Firmware is detected !"
		fi
		if [ -f "${EFI_Firmware}" ];then
			_MD5=$(md5sum ${EFI_Firmware} | cut -d ' ' -f1)
			_SHA256=$(sha256sum ${EFI_Firmware} | cut -d ' ' -f1)
			touch ${Home}/bin/Firmware/${AutoBuild_Firmware}-UEFI.detail
			echo -e "\nMD5:${_MD5}\nSHA256:${_SHA256}" > ${Home}/bin/Firmware/${AutoBuild_Firmware}-UEFI.detail
			cp ${EFI_Firmware} ${Home}/bin/Firmware/${AutoBuild_Firmware}-UEFI.${Firmware_Type}
			echo "[$(date "+%H:%M:%S")] UEFI Firmware is detected !"
		fi
	;;
	*)
		cd ${Home}
		Default_Firmware="${_Firmware}-${TARGET_BOARD}-${TARGET_SUBTARGET}-${TARGET_PROFILE}-squashfs-sysupgrade.${Firmware_Type}"
		AutoBuild_Firmware="AutoBuild-${TARGET_PROFILE}-${Openwrt_Version}.${Firmware_Type}"
		AutoBuild_Detail="AutoBuild-${TARGET_PROFILE}-${Openwrt_Version}.detail"
		echo "Firmware: ${AutoBuild_Firmware}"
		mv -f ${Firmware_Path}/${Default_Firmware} bin/Firmware/${AutoBuild_Firmware}
		_MD5=$(md5sum bin/Firmware/${AutoBuild_Firmware} | cut -d ' ' -f1)
		_SHA256=$(sha256sum bin/Firmware/${AutoBuild_Firmware} | cut -d ' ' -f1)
		echo -e "\nMD5:${_MD5}\nSHA256:${_SHA256}" > bin/Firmware/${AutoBuild_Detail}
	;;
	esac
	cd ${Home}
	echo "[$(date "+%H:%M:%S")] Actions Avaliable: $(df -h | grep "/dev/root" | awk '{printf $4}')"
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

Auto_ExtraPackages() {
	[[ ! -f "${GITHUB_WORKSPACE}/CustomPackages/${TARGET_PROFILE}" ]] && return
	echo "[$(date "+%H:%M:%S")] Loading Custom Packages list: [${TARGET_PROFILE}] ..."
	echo "" >> ${GITHUB_WORKSPACE}/CustomPackages/${TARGET_PROFILE}
	cat ${GITHUB_WORKSPACE}/CustomPackages/${TARGET_PROFILE} | while read X
	do
		ExtraPackages ${X}
	done
	echo "[$(date "+%H:%M:%S")] [CustomPackages] All done !"
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
	echo "[$(date "+%H:%M:%S")] Checking out package [${PKG_NAME}] to package/${PKG_DIR} ..."
	case "${PKG_PROTO}" in
	git)
		[[ -z "${REPO_BRANCH}" ]] && REPO_BRANCH=master
		git clone -b ${REPO_BRANCH} ${REPO_URL}/${PKG_NAME} ${PKG_NAME} > /dev/null 2>&1
	;;
	svn)
		svn checkout ${REPO_URL}/${PKG_NAME} ${PKG_NAME} > /dev/null 2>&1
	;;
	*)
		echo "[$(date "+%H:%M:%S")] Error option: ${PKG_PROTO} !" && return
	;;
	esac
	if [ -f ${PKG_NAME}/Makefile ] || [ -f ${PKG_NAME}/README* ] || [ ! "$(ls -A ${PKG_NAME})" = "" ];then
		echo "[$(date "+%H:%M:%S")] Package [${PKG_NAME}] is detected!"
		mv -f ${PKG_NAME} package/${PKG_DIR}
	fi
	unset PKG_PROTO PKG_DIR PKG_NAME REPO_URL REPO_BRANCH
}

Replace_File() {
	FILE_NAME=${1}
	PATCH_DIR=${GITHUB_WORKSPACE}/openwrt/${2}
	FILE_RENAME=${3}
	
	Mkdir ${PATCH_DIR}
	[ -f "${GITHUB_WORKSPACE}/${FILE_NAME}" ] && _TYPE1="f" && _TYPE2="File"
	[ -d "${GITHUB_WORKSPACE}/${FILE_NAME}" ] && _TYPE1="d" && _TYPE2="Folder"
	if [ -${_TYPE1} "${GITHUB_WORKSPACE}/${FILE_NAME}" ];then
		[[ ! -z "${FILE_RENAME}" ]] && _RENAME="${FILE_RENAME}" || _RENAME=""
		if [ -${_TYPE1} "${GITHUB_WORKSPACE}/${FILE_NAME}" ];then
			echo "[$(date "+%H:%M:%S")] Moving [${_TYPE2}] ${FILE_NAME} to ${2}/${FILE_RENAME} ..."
			mv -f ${GITHUB_WORKSPACE}/${FILE_NAME} ${PATCH_DIR}/${_RENAME}
		else
			echo "[$(date "+%H:%M:%S")] CustomFiles ${_TYPE2} [${FILE_NAME}] is not detected,skip move ..."
		fi
	fi
	unset FILE_NAME PATCH_DIR FILE_RENAME
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
			echo "[ERROR] Failed to obtain the Offical version of [${PKG_NAME}],skip update ..."
			return
		fi
		Source_Version="$(grep "PKG_VERSION:=" ${Makefile} | cut -c14-20)"
		Source_HASH="$(grep "PKG_HASH:=" ${Makefile} | cut -c11-100)"
		if [[ -z "${Source_Version}" ]] || [[ -z "${Source_HASH}" ]];then
			echo "[ERROR] Failed to obtain the Source version or HASH,skip update ..."
			return
		fi
		echo -e "Current ${PKG_NAME} version: ${Source_Version}\nOffical ${PKG_NAME} version: ${Offical_Version}"
		if [[ ! "${Source_Version}" == "${Offical_Version}" ]];then
			echo -e "[$(date "+%H:%M:%S")] Updating package ${PKG_NAME} [${Source_Version}] to [${Offical_Version}] ..."
			sed -i "s?PKG_VERSION:=${Source_Version}?PKG_VERSION:=${Offical_Version}?g" ${Makefile}
			wget -q "${PKG_DL_URL}${Offical_Version}?" -O /tmp/tmp_file
			if [[ "$?" -eq 0 ]];then
				Offical_HASH="$(sha256sum /tmp/tmp_file | cut -d ' ' -f1)"
				sed -i "s?PKG_HASH:=${Source_HASH}?PKG_HASH:=${Offical_HASH}?g" ${Makefile}
			else
				echo "[ERROR] Failed to update the package [${PKG_NAME}],skip update ..."
			fi
		fi
	else
		echo "[$(date "+%H:%M:%S")] Package ${PKG_NAME} is not detected,skip update ..."
	fi
	unset _process1 _process2 Offical_Version Source_Version
}
