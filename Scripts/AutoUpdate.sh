#!/bin/bash
# AutoBuild Module by Hyy2001 <https://github.com/Hyy2001X/AutoBuild-Actions>
# AutoUpdate for Openwrt
# Depends on: bash wget-ssl/wget/uclient-fetch curl x86:gzip openssl

Version=V6.5.2
ENV_DEPENDS="Author Github TARGET_PROFILE TARGET_BOARD TARGET_SUBTARGET Firmware_Type CURRENT_Version OP_Maintainer OP_BRANCH OP_REPO_NAME REGEX_Firmware"

TITLE() {
	clear && echo "Openwrt-AutoUpdate Script by Hyy2001 ${Version} [${DL}]"
}

SHELL_HELP() {
	TITLE
	cat <<EOF

使用方法:	bash $0 [-n] [-f] [-u] [-F] [-P] [path=<PATH>] 
		bash $0 [-x] [path=<PATH>] [url=<URL>]

更新固件:
	-n			不保留配置更新固件 *
	-u			适用于定时更新 LUCI 的参数 *
	-f			跳过版本号、SHA256 校验,并强制刷写固件 (危险) *
	-F, --force-write	强制刷写固件 *
	-P, --proxy		优先开启镜像加速下载固件 *
	--skip			跳过固件 SHA256 校验 (危险) *
	path=<PATH>		保存固件到提供的绝对路径 <PATH> *

更新脚本:
	-x			更新 AutoUpdate.sh 脚本
	-x path=<PATH>		更新 AutoUpdate.sh 脚本 (保存脚本到提供的绝对路径 <PATH>) *
	-x url=<URL>		更新 AutoUpdate.sh 脚本 (使用提供的地址 <URL> 更新脚本) *

其他参数:
	-B, --boot-mode <TYPE>		指定 x86 设备下载 <TYPE> 引导的固件 (e.g. UEFI Legacy)
	-C, --change <Github URL>	更改 Github 地址为提供的 <Github URL>
	-H, --help			打印 AutoUpdate 帮助信息
	-L, --log < | del>		<打印 | 删除> AutoUpdate 历史运行日志
	    --log path=<PATH>		更改 AutoUpdate 运行日志路径为提供的绝对路径 <PATH>
	--backup path=<PATH>		备份当前系统配置文件到提供的绝对路径 <PATH>
	--check-depends			检查 AutoUpdate 运行环境
	--clean				清理 AutoUpdate 缓存
	--env-list < | 1 | 2>		打印 AutoUpdate 环境变量 <全部 | 变量名称 | 值>
	--fw-log < | cloud | *>		打印 <当前 | 云端 | 指定版本> 版本的固件更新日志
	--fw-version < | cloud>		打印 <当前 | 云端> 固件版本
	--fw-version cloud -a		打印所有云端固件版本
	--list				打印当前系统信息
	--random <Number>		打印一个 0-30 位的随机数字字母组合
	--var <VARIABLE>		打印用户指定的变量 <VARIABLE>
	--verbose			打印更详细的下载信息
	--version < | cloud>		打印 <当前 | 云端> AutoUpdate.sh 版本
	
脚本、固件更新问题反馈请前往 ${Github}, 并附上 AutoUpdate 运行日志与系统信息 (见上方)

EOF
	EXIT
}

SHOW_VARIABLE() {
	TITLE
	cat <<EOF

设备名称:		$(uname -n) / ${TARGET_PROFILE}
固件版本:		${CURRENT_Version}
内核版本:		$(uname -r)
其他参数:		${TARGET_BOARD} / ${TARGET_SUBTARGET}
固件作者:		${Author}
固件作者 URL:		${Github}
Release URL:		${Github_Release_URL}
Release API:		${Github_API}
OpenWrt 源码 URL:	https://github.com/${OP_Maintainer}/${OP_REPO_NAME}:${OP_BRANCH}
固件匹配框架:		$(GET_VARIABLE REGEX_Firmware ${Default_Variable})
固件格式:		${Firmware_Type}
固件保存路径:		${Run_Path}
运行日志路径:		${Log_Path}/AutoUpdate.log
Downloader:		${Downloader}
EOF
	[[ ${TARGET_BOARD} == x86 ]] && {
		echo "固件引导模式:		${x86_Boot}"
	}
	echo
	LIST_ENV 0
	echo
	EXIT 0
}

GET_PID() {
	local PID
	while [[ $1 ]];do
		PID=$(busybox ps | grep "$1" | grep -v "grep" | awk '{print $1}' | awk 'NR==1')
		[[ -n ${PID} ]] && echo "${PID}"
	shift
	done
}

LIST_ENV() {
	local X
	cat /etc/AutoBuild/*_Variable | grep -v '#' | while read X;do
	[[ ${X} =~ "=" ]] && {
		case "$1" in
		1 | 2)
			[[ -n $(echo "${X}" | cut -d "=" -f1) ]] && echo "${X}" | cut -d "=" -f$1
		;;
		0)
			echo "${X}"
		;;
		esac
	}
	done
}

CHECK_ENV() {
	while [[ $1 ]];do
		[[ $(LIST_ENV 1) =~ $1 ]] && ECHO y "Checking env $1 ... true" || ECHO r "Checking env $1 ... Not found"
		shift
	done
}

EXIT() {
	LOGGER "[${Run_Command}] Finished $1"
	exit
}

ECHO() {
	local Color
	[[ -z $1 ]] && {
		echo -ne "\n${Grey}[$(date "+%H:%M:%S")]${White} "
	} || {
	case "$1" in
		r) Color="${Red}";;
		g) Color="${Green}";;
		b) Color="${Blue}";;
		y) Color="${Yellow}";;
		x) Color="${Grey}";;
	esac
		[[ $# -lt 2 ]] && {
			echo -e "\n${Grey}[$(date "+%H:%M:%S")]${White} $1"
			LOGGER $1
		} || {
			echo -e "\n${Grey}[$(date "+%H:%M:%S")]${White} ${Color}$2${White}"
			LOGGER $2
		}
	}
}

LOGGER() {
	[[ ! -d ${Log_Path} ]] && mkdir -p ${Log_Path}
	[[ ! -f ${Log_Path}/AutoUpdate.log ]] && touch ${Log_Path}/AutoUpdate.log
	echo "[$(date "+%Y-%m-%d-%H:%M:%S")] [$(GET_PID AutoUpdate.sh)] $*" >> ${Log_Path}/AutoUpdate.log
}

CHECK_PKG() {
	which $1 > /dev/null 2>&1
	[[ $? == 0 ]] && echo "true" || echo "false"
}

RANDOM() {
	local Result=$(openssl rand -base64 $1 | md5sum | cut -c 1-$1)
	[[ -n ${Result} ]] && echo "${Result}"
	LOGGER "[RANDOM] $1-bit random-number : ${Result}"
}

GET_SHA256SUM() {
	[[ ! -f $1 && ! -s $1 ]] && {
		ECHO r "未检测到文件: [$1] 或该文件为空,无法计算 SHA256 值!"
		EXIT 1
	}
	LOGGER "[GET_SHA256SUM] Target File: $1"
	local Result=$(sha256sum $1 | cut -c1-$2)
	[[ -n ${Result} ]] && echo "${Result}"
	LOGGER "[GET_SHA256SUM] $1: ${Result}"
}

GET_VARIABLE() {
	[[ $# != 2 ]] && SHELL_HELP
	[[ ! -f $2 ]] && ECHO "未检测到定义文件: [$2] !" && EXIT 1
	local Result="$(grep "$1=" $2 | grep -v "#" | awk 'NR==1' | sed -r "s/$1=(.*)/\1/")"
	[[ -n ${Result} ]] && echo "${Result}"
	LOGGER "[GET_VARIABLE] $1: ${Result}"
}

LOAD_VARIABLE() {
	while [[ $1 ]];do
		[[ -f $1 ]] && {
			chmod 777 $1
			source $1
		}
		shift
	done
	[[ -z ${TARGET_PROFILE} ]] && TARGET_PROFILE="$(jsonfilter -e '@.model.id' < /etc/board.json | tr ',' '_')"
	[[ -z ${TARGET_PROFILE} ]] && ECHO r "获取设备名称失败,无法执行更新!" && EXIT 1
	[[ -z ${CURRENT_Version} ]] && CURRENT_Version="未知"
	Github_Release_URL="${Github}/releases/download/AutoUpdate"
	FW_Author="${Github##*com/}"
	Github_API="https://api.github.com/repos/${FW_Author}/releases/latest"
	Release_URL="https://github.com/${FW_Author}/releases/download/AutoUpdate"
	Release_FastGit_URL="https://download.fastgit.org/${FW_Author}/releases/download/AutoUpdate"
	Release_Goproxy_URL="https://ghproxy.com/${Release_URL}"
	case "${TARGET_BOARD}" in
	x86)
		case "${Firmware_Type}" in
		img.gz | img)
			[[ -z ${x86_Boot} ]] && {
				[ -d /sys/firmware/efi ] && {
					x86_Boot=UEFI
				} || x86_Boot=Legacy
			}
		;;
		*)
			ECHO r "[${TARGET_PROFILE}] 设备暂不支持当前固件格式!"
			EXIT 1
		;;
		esac
	;;
	*)
		[[ -z ${Firmware_Type} ]] && Firmware_Type=bin
	esac
}

EDIT_VARIABLE() {
	local Mode="$1"
	shift
	[[ ! -f $1 ]] && ECHO r "未检测到定义文件: [$1] !" && EXIT 1
	case "${Mode}" in
	edit)
    	[[ $# != 3 ]] && SHELL_HELP
		[[ -z $(GET_VARIABLE $2 $1) ]] && {
			LOGGER "[EDIT_VARIABLE] Appending [$2=$3] to $1 ..."
			echo -e "\n$2=$3" >> $1
		} || {
			sed -i "s?$(GET_VARIABLE $2 $1)?$3?g" $1
		}
	;;
	rm)
		[[ $# != 2 ]] && SHELL_HELP
		LOGGER "[EDIT_VARIABLE] Removing $2 from $1 ..."
		sed -i "/$2/d" $1
	;;
	esac
}

CHANGE_GITHUB() {
	[[ ! $1 =~ https://github.com/ ]] && {
		ECHO r "Github 地址输入有误,示例: https://github.com/Hyy2001X/AutoBuild-Actions"
		EXIT 1
	}
	UCI_Github_URL=$(uci get autoupdate.@common[0].github 2>/dev/null)
	[[ -n ${UCI_Github_URL} && ! ${UCI_Github_URL} == $1 ]] && {
		uci set autoupdate.@common[0].github=$1 2>/dev/null
		LOGGER "[CHANGE_GITHUB] UCI setting to $1"
	}
	[[ ! ${Github} == $1 ]] && {
		EDIT_VARIABLE edit ${Custom_Variable} Github $1
		ECHO y "Github 地址已修改为: $1"
	}
	EXIT 0
}

CHANGE_BOOT() {
	[[ -z $1 ]] && SHELL_HELP
	case "$1" in
	UEFI | Legacy)
		EDIT_VARIABLE edit ${Custom_Variable} x86_Boot $1
		ECHO r "警告: 更换引导方式后更新固件后可能导致设备无法正常启动!"
		ECHO y "固件引导格式已指定为: [$1]"
		EXIT 0
	;;
	*)
		ECHO r "错误的参数: [$1],支持的启动方式: [UEFI/Legacy]"
		EXIT 1
	;;
	esac
}

UPDATE_SCRIPT() {
	ECHO g "下载地址: $2"
	ECHO g "保存路径: $1"
	[[ -f $1 ]] && {
		ECHO r "AutoUpdate 脚本保存路径有误,请重新输入!"
		EXIT 1
	}
	ECHO "开始更新 AutoUpdate 脚本,请耐心等待 ..."
	[[ ! -d $1 ]] && mkdir -p $1
	DOWNLOADER /tmp/AutoUpdate.sh $2
	if [[ $? == 0 ]];then
		mv -f /tmp/AutoUpdate.sh $1
		chmod +x $1/AutoUpdate.sh
		Script_Version=$(bash $1/AutoUpdate.sh --version)
		Banner_Version=$(egrep -o "V[0-9]+.[0-9].+" /etc/banner)
		[[ -n ${Banner_Version} && $1 == /bin ]] && sed -i "s?${Banner_Version}?${Script_Version}?g" /etc/banner
		ECHO y "[${Script_Version}] AutoUpdate 脚本更新成功!"
		EXIT 0
	else
		ECHO r "AutoUpdate 脚本更新失败,请检查网络后重试!"
		EXIT 1
	fi
}

CHECK_DEPENDS() {
	TITLE
	local PKG Tab
	echo -e "\n软件包			检测结果"
	while [[ $1 ]];do
		if [[ $1 =~ : ]];then
			[[ $(echo $1 | cut -d ":" -f1) == ${TARGET_BOARD} ]] && {
				PKG="$(echo "$1" | cut -d ":" -f2)"
				[[ $(echo "${PKG}" | wc -c) -gt 8 ]] && Tab="		" || Tab="			"
				echo -e "${PKG}${Tab}$(CHECK_PKG ${PKG})"
				LOGGER "[CHECK_DEPENDS] Checking ${PKG} ... $(CHECK_PKG ${PKG})"
			}
		else
			[[ $(echo "$1" | wc -c) -gt 8 ]] && Tab="		" || Tab="			"
			echo -e "$1${Tab}$(CHECK_PKG $1)"
			LOGGER "[CHECK_DEPENDS] Checking $1 ... $(CHECK_PKG $1)"
		fi
		shift
	done
	ECHO y "AutoUpdate 依赖检测结束,若某项检测结果为 [false],请尝试手动安装!"
}

FW_VERSION_CHECK() {
	[[ $# -gt 1 ]] && echo "false" && return
	[[ $1 =~ R[1-9.]{2}.+-[0-9]{8} ]] && {
		echo "true"
		LOGGER "[FW_VERSION_CHECK] Checking [$1] ... true"
	} || {
		echo "false"
		LOGGER "[FW_VERSION_CHECK] Checking [$1] ... false"
	}
}

GET_FW_LOG() {
	local Result
	case "$1" in
	[Ll]ocal)
		FW_Version="${CURRENT_Version}"
	;;
	[Cc]loud)
		FW_Version="$(GET_CLOUD_VERSION)"
	;;
	-v)
		shift
		FW_Version="$1"
	;;
	esac
	if [[ -z $(find ${Run_Path} -type f -mmin -1 -name Update_Logs.json) || ! -s ${Run_Path}/Update_Logs.json ]];then
		rm -f ${Run_Path}/Update_Logs.json
		DOWNLOADER ${Run_Path}/Update_Logs.json ${Release_URL}/Update_Logs.json
		[[ $? == 0 || -s ${Run_Path}/Update_Logs.json ]] && {
			touch -a ${Run_Path}/Update_Logs.json
		} || rm -f ${Run_Path}/Update_Logs.json
	fi
	[[ -f ${Run_Path}/Update_Logs.json ]] && {
		Result=$(jsonfilter -e '@["'"""${TARGET_PROFILE}"""'"]["'"""${FW_Version}"""'"]' < ${Run_Path}/Update_Logs.json)
		[[ -n ${Result} ]] && {
			echo -e "\n${Grey}${FW_Version} for ${TARGET_PROFILE} 更新日志:"
			echo -e "\n${Green}${Result}${White}"
		}
	}
}

GET_CLOUD_INFO() {
	if [[ -z $(find ${Run_Path} -type f -mmin -1 -name Github_Tags) || ! -s ${Run_Path}/Github_Tags ]];then
		[[ -f ${Run_Path}/Github_Tags ]] && rm -f ${Run_Path}/Github_Tags
		DOWNLOADER ${Run_Path}/Github_Tags ${Github_API}
		[[ $? != 0 || ! -s ${Run_Path}/Github_Tags ]] && echo "false" || {
			touch -a ${Run_Path}/Github_Tags
			echo "true"
		}
	else
		LOGGER "[GET_CLOUD_INFO] Skip downloading [Github_Tags] ..."
		echo "true"
	fi
}

GET_CLOUD_FW() {
	local X Y
	[[ $(GET_CLOUD_INFO) == false ]] && {
		ECHO r "检查更新失败,请检查网络后重试!"
		EXIT 1
	}
	eval X=$(GET_VARIABLE REGEX_Firmware ${Default_Variable})
	case $1 in
	-a)
		Y=$(egrep -o "${X}" ${Run_Path}/Github_Tags | sort | uniq)
	;;
	*)
		Y=$(egrep -o "${X}" ${Run_Path}/Github_Tags | awk 'END {print}')
	;;
	esac
	[[ -n ${Y} ]] && echo "${Y}"
}

GET_CLOUD_VERSION() {
	local Z
	Z=$(GET_CLOUD_FW $1 | egrep -o "R[0-9].*202[1-2][0-9]+")
	[[ -n ${Z} ]] && echo "$Z"
}

CHECK_UPDATES() {
	local A
	ECHO "正在检查版本更新 ..."
	A=$(GET_CLOUD_VERSION)
	[[ ! $(FW_VERSION_CHECK $A ) == true ]] && {
		ECHO r "固件版本合法性校验失败!"
		EXIT 1
	}
	[[ ${A} == ${CURRENT_Version} ]] && {
		CURRENT_Type="${Yellow} [已是最新]${White}"
		Upgrade_Stopped=1
	} || {
		[[ $(echo ${A} | cut -d "-" -f2) -gt $(echo ${CURRENT_Version} | cut -d "-" -f2) ]] && CURRENT_Type="${Green} [可更新]${White}"
		[[ $(echo ${A} | cut -d "-" -f2) -lt $(echo ${CURRENT_Version} | cut -d "-" -f2) ]] && {
			CHECKED_Type="${Red} [旧版本]${White}"
			Upgrade_Stopped=2
		}
	}
}

DOWNLOADER() {
	LOGGER "[DOWNLOADER] ${Downloader} $1 $2"
	${Downloader} $1 $2
	[[ $? == 0 ]] && {
		LOGGER "[DOWNLOADER] returned 0"
		return 0
	} || {
		LOGGER "[DOWNLOADER] returned $?"
		return $?
	}
}

PREPARE_UPGRADES() {
	TITLE
	[[ $* =~ -f && $* =~ -F ]] && SHELL_HELP
	Upgrade_Option="sysupgrade -q"
	MSG="更新固件"
	while [[ $1 ]];do
		case "$1" in
		-T | --test)
			Test_Mode=1
			Special_Commands="${Special_Commands} [测试模式]"
		;;
		-P | --proxy)
			Proxy_Mode=1
			Special_Commands="${Special_Commands} [镜像加速]"
		;;
		-F | --force-write)
			[[ -n ${Force_Mode} ]] && SHELL_HELP
			Only_Force_Write=1
			Special_Commands="${Special_Commands} [强制刷写]"
			Upgrade_Option="${Upgrade_Option} -F"
		;;
		--skip)
			Skip_Verify=1
			Special_Commands="${Special_Commands} [跳过 SHA256 验证]"
		;;
		-f)
			[[ -n ${Only_Force_Write} ]] && SHELL_HELP
			Force_Mode=1
			Special_Commands="${Special_Commands} [强制模式]"
			Upgrade_Option="${Upgrade_Option} -F"
		;;
		-n)
			Upgrade_Option="${Upgrade_Option} -n"
			Special_MSG=" (不保留配置)"
		;;
		-u)
			AutoUpdate_Mode=1
			Special_Commands="${Special_Commands} [定时更新]"
		;;
		path=/*)
			[[ -z $(echo "$1" | cut -d "=" -f2) ]] && ECHO r "固件保存路径不能为空!" && EXIT 1
			Run_Path=$(echo "$1" | cut -d "=" -f2)
			ECHO g "使用自定义固件保存路径: ${Run_Path}"
		;;
		--verbose)
			Special_Commands="${Special_Commands} [详细信息]"
		;;
		*)
			SHELL_HELP
		esac
	shift
	done
	LOGGER "Upgrade Options: ${Upgrade_Option}"
	[[ -n "${Special_Commands}" ]] && ECHO g "特殊指令:${Special_Commands} / ${Upgrade_Option}"
	ECHO g "执行: ${MSG}${Special_MSG}"
	CLOUD_FW_Version=$(GET_CLOUD_VERSION)
	CLOUD_FW_Name=$(GET_CLOUD_FW)
	[[ -z ${CLOUD_FW_Version} || -z ${CLOUD_FW_Name} ]] && {
		ECHO r "云端固件信息获取失败,请检查网络后重试!"
		EXIT 1
	}
	if [[ $(CHECK_PKG curl) == true && ${Proxy_Mode} != 1 ]];then
		Google_Check=$(curl -I -s --connect-timeout 3 google.com -w %{http_code} | tail -n1)
		LOGGER "Google_Check: ${Google_Check}"
		[[ ${Google_Check} != 301 ]] && {
			ECHO r "网络连接不佳,优先使用镜像加速!"
			Proxy_Mode=1
		}
	fi
	CHECK_UPDATES
	[[ ${Proxy_Mode} == 1 ]] && {
		CLOUD_FW_URL="${Release_Goproxy_URL}"
	} || CLOUD_FW_URL="${Release_URL}"
	cat <<EOF

设备名称: ${TARGET_PROFILE}
内核版本: $(uname -r)
$([[ ${TARGET_BOARD} == x86 ]] && echo "固件格式: ${Firmware_Type} / ${x86_Boot}" || echo "固件格式: ${Firmware_Type}")

$(echo -e "当前固件版本: ${CURRENT_Version}${CURRENT_Type}")
$(echo -e "云端固件版本: ${CLOUD_FW_Version}${CHECKED_Type}")

云端固件名称: ${CLOUD_FW_Name}
固件下载地址: ${CLOUD_FW_URL}
EOF
	GET_FW_LOG -v ${CLOUD_FW_Version}
	case "${Upgrade_Stopped}" in
	1 | 2)
		[[ ${AutoUpdate_Mode} == 1 ]] && ECHO y "已是最新版本,无需更新!" && EXIT 0
		[[ ${Upgrade_Stopped} == 1 ]] && MSG="已是最新版本" || MSG="云端固件版本为旧版"
		[[ ! ${Force_Mode} == 1 ]] && {
			ECHO && read -p "${MSG},是否继续更新固件?[Y/n]:" Choose
		} || Choose=Y
		[[ ! ${Choose} =~ [Yy] ]] && EXIT 0
	;;
	esac
	Retry_Times=5
	ECHO "${Proxy_Echo}正在下载固件,请耐心等待 ..."
	while [[ ${Retry_Times} -ge 0 ]];do
		if [[ ! ${PROXY_Mode} == 1 && ${Retry_Times} == 4 ]];then
			ECHO g "尝试使用 [FastGit] 镜像加速下载固件!"
			CLOUD_FW_URL="${Release_FastGit_URL}"
		fi
		[[ ${Retry_Times} == 3 ]] && {
			ECHO g "尝试使用 [Github Proxy] 镜像加速下载固件!"
			CLOUD_FW_URL="${Release_Goproxy_URL}"
		}
		[[ ${Retry_Times} == 2 ]] && CLOUD_FW_URL="${Github_Release_URL}"
		if [[ ${Retry_Times} == 0 ]];then
			ECHO r "固件下载失败,请检查网络后重试!"
			EXIT 1
		else
			DOWNLOADER ${Run_Path}/${CLOUD_FW_Name} "${CLOUD_FW_URL}/${CLOUD_FW_Name}"
			[[ $? == 0 && -s ${Run_Path}/${CLOUD_FW_Name} ]] && ECHO y "固件下载成功!" && break
		fi
		Retry_Times=$((${Retry_Times} - 1))
		ECHO r "固件下载失败,剩余尝试次数: ${Retry_Times} 次"
	done
	if [[ ! ${Skip_Verify} == 1 || ! Force_Mode == 1 ]];then
		LOCAL_SHA256=$(GET_SHA256SUM ${Run_Path}/${CLOUD_FW_Name} 5)
		CLOUD_SHA256=$(echo "${CLOUD_FW_Name}" | egrep -o "[0-9a-z]+.${Firmware_Type}" | sed -r "s/(.*).${Firmware_Type}/\1/")
		[[ ${LOCAL_SHA256} != ${CLOUD_SHA256} ]] && {
			ECHO r "本地固件 SHA256 与云端比对校验失败 [${LOCAL_SHA256}],请检查网络后重试!"
			EXIT 1
		} || LOGGER "固件 SHA256 比对通过!"
	fi
	case "${Firmware_Type}" in
	img.gz)
		ECHO "正在解压固件,请耐心等待 ..."
		gzip -d -q -f -c ${Run_Path}/${CLOUD_FW_Name} > ${Run_Path}/$(echo "${CLOUD_FW_Name}" | sed -r 's/(.*).gz/\1/')
		[[ $? != 0 ]] && {
			ECHO r "固件解压失败,请检查网络稳定性或更换固件保存路径!"
			EXIT 1
		} || {
			CLOUD_FW_Name="$(echo "${CLOUD_FW_Name}" | sed -r 's/(.*).gz/\1/')"
			ECHO "固件解压成功,固件已解压到: ${Run_Path}/${CLOUD_FW_Name}"
		}
	;;
	esac
	[[ ${Test_Mode} != 1 ]] && {
		chmod 777 ${Run_Path}/${CLOUD_FW_Name}
		DO_UPGRADE ${Upgrade_Option} ${Run_Path}/${CLOUD_FW_Name}
	} || {
		ECHO x "[测试模式] ${Upgrade_Option} ${Run_Path}/${CLOUD_FW_Name}"
		EXIT 0
	}
}

DO_UPGRADE() {
	ECHO r "准备更新固件,更新期间请不要断开电源或重启设备 ..."
	sleep 3
	ECHO g "正在更新固件,请耐心等待 ..."
	$*
	[[ $? -ne 0 ]] && {
		ECHO r "固件刷写失败,请尝试手动更新固件或使用 autoupdate -F 指令强制更新固件!"
		ECHO r "脚本、固件更新问题反馈请前往 ${Github}, 并附上 AutoUpdate 运行日志与系统信息"
		EXIT 1
	} || EXIT 0
}

REMOVE_CACHE() {
	rm -rf ${Run_Path}/*
	LOGGER "AutoUpdate 缓存清理完成!"
	EXIT 0
}

AutoUpdate_LOG() {
	[[ -z $1 ]] && {
		[[ -s ${Log_Path}/AutoUpdate.log ]] && {
			TITLE && echo
			cat ${Log_Path}/AutoUpdate.log
		}
	} || {
		while [[ $1 ]];do
			case "$1" in
			path=/* | rm | del)
				:
			;;
			*)
				SHELL_HELP
			;;
			esac
			if [[ $1 =~ path= ]];then
				LOG_PATH="$(echo "$1" | cut -d "=" -f2)"
				[[ ${LOG_PATH} == ${Log_Path} ]] && {
					ECHO y "AutoUpdate 日志保存路径相同,无需修改!"
					EXIT 0
				}
				[[ -f ${LOG_PATH} ]] && {
					ECHO r "错误的参数: [${LOG_PATH}]"
					ECHO r "AutoUpdate 日志保存路径有误,请重新输入!"
					EXIT 1
				}
				EDIT_VARIABLE rm ${Custom_Variable} Log_Path
				EDIT_VARIABLE edit ${Custom_Variable} Log_Path ${LOG_PATH}
				[[ ! -d ${LOG_PATH} ]] && mkdir -p ${LOG_PATH}
				[[ -f ${Log_Path}/AutoUpdate.log ]] && mv ${Log_Path}/AutoUpdate.log ${LOG_PATH}
				Log_Path=${LOG_PATH}
				ECHO y "AutoUpdate 日志保存路径已修改为: ${LOG_PATH}"
				EXIT 0
			fi
			[[ $1 == rm || $1 == del ]] && {
				[[ -f ${Log_Path}/AutoUpdate.log ]] && rm ${Log_Path}/AutoUpdate.log
			}
			EXIT 0
		done
	}
}

AutoUpdate_Main() {
	[[ ! -f ${Default_Variable} ]] && {
		LOGGER "Unable to access default variable file ..."
		ECHO r "脚本运行环境检测失败,请手动更新固件!"
		EXIT 1
	}
	[[ ! -f ${Custom_Variable} ]] && touch ${Custom_Variable}
	LOAD_VARIABLE ${Default_Variable} ${Custom_Variable}
	[[ ! -d ${Run_Path} ]] && {
		mkdir -p ${Run_Path}
		[[ ! $? == 0 ]] && {
			ECHO r "脚本运行目录创建失败!"
			EXIT 1
		}
	}

	if [[ $(CHECK_PKG wget-ssl) == true ]];then
		Downloader="wget-ssl --quiet --no-check-certificate --tries 1 -T 5 --no-dns-cache -x -4 -O"
		DL="wget-ssl"
	elif [[ $(CHECK_PKG curl) == true ]];then
		Downloader="curl --insecure -L -k --connect-timeout 5 --retry 1 --silent -o"
		DL="curl"
	else
		Downloader="uclient-fetch --quiet --no-check-certificate -T 5 -4 -O"
		DL="uclient-fetch"
	fi

	[[ -z $* ]] && PREPARE_UPGRADES $*
	[[ $1 =~ path=/ && ! $* =~ -x ]] && PREPARE_UPGRADES $*
	[[ $1 =~ --skip ]] && PREPARE_UPGRADES $*
	
	[[ $* =~ -T || $* =~ --verbose ]] && {
		Downloader="${Downloader/ --quiet / }"
		Downloader="${Downloader/ --silent / }"
	}

	case "$1" in
	-n | -f | -u | -T | -P | --proxy | -F | --force-write | --verbose)
		LOGGER "Downloader: ${DL} / ${Downloader}"
		PREPARE_UPGRADES $*
	;;
	--backup)
		local FILE="backup-$(uname -n)-$(date +%Y-%m-%d)-$(RANDOM 5).tar.gz"
		shift
		[[ $# -gt 1 ]] && SHELL_HELP
		[[ -z $* ]] && {
			FILE=$(pwd)/${FILE}
		}
		[[ $1 =~ path=/ ]] && {
			[[ ! -d $1 ]] && {
				mkdir -p $1
				[[ ! $? == 0 ]] && ECHO r "文件夹创建失败,请更换保存路径!" && EXIT 1
			}
			FILE="$(echo "$1" | cut -d "=" -f2)/${FILE}"
		}
		ECHO "Saving config files to [${FILE}] ..."
		sysupgrade -b "${FILE}" >/dev/null 2>&1
		[[ $? == 0 ]] && {
			ECHO y "备份文件创建成功!"
			EXIT 0
		} || {
			ECHO r "备份文件创建失败,请更换保存路径!"
			EXIT 1
		}
	;;
	--clean)
		shift && [[ -n $* ]] && SHELL_HELP
		REMOVE_CACHE
	;;
	--check-depends)
		shift && [[ -n $* ]] && SHELL_HELP
		CHECK_DEPENDS bash x86:gzip uclient-fetch curl wget openssl
		CHECK_ENV ${ENV_DEPENDS}
	;;
	--env-list)
		shift
		[[ -z $* ]] && LIST_ENV 0 && EXIT 0
		case "$1" in
		1 | 2)
			LIST_ENV $1
		;;
		*)
			SHELL_HELP
		;;
		esac
		EXIT 0
	;;
	--fw-version)
		shift
		case "$1" in
		[Cc]loud)
			GET_CLOUD_VERSION $2
		;;
		*)
			echo "${CURRENT_Version}"
		;;
		esac
		EXIT 0
	;;
	--fw-log)
		shift
		[[ -z $* ]] && GET_FW_LOG local
		case "$1" in
		[Cc]loud)
			GET_FW_LOG $1
		;;
		*)
			[[ -z $* ]] && EXIT 0
			[[ ! $(FW_VERSION_CHECK $1) == true ]] && {
				ECHO r "固件版本号合法性检查失败!"
				EXIT 1
			} || {
				GET_FW_LOG -v $1
			}
		;;
		esac
		EXIT 0
	;;
	--list)
		shift && [[ -n $* ]] && SHELL_HELP
		SHOW_VARIABLE
	;;
	--random)
		shift
		[[ $# != 1 || ! $1 =~ [0-9] || $1 == 0 || $1 -gt 30 ]] && SHELL_HELP || {
			RANDOM $1
			EXIT 0
		}
	;;
	--var)
		local Result
		shift
		[[ $# != 1 ]] && SHELL_HELP
		Result=$(GET_VARIABLE "$1" ${Custom_Variable})
		[[ -z ${Result} ]] && Result=$(GET_VARIABLE "$1" ${Default_Variable})
		[[ -n ${Result} ]] && echo "${Result}"
	;;
	--version)
		local Result
		shift
		case "$1" in
		[Cc]loud)
			Result="$(DOWNLOADER - ${Script_URL} | egrep -o "V[0-9].+")"
		;;
		*)
				Result=${Version}
		esac
		[[ -z ${Result} ]] && echo "未知" || {
			echo "${Result}"
			EXIT 0
		}
	;;
	-x)
		shift
		while [[ $1 ]];do
			case "$1" in
			url=https://*)
				[[ -z $(echo "$1" | cut -d "=" -f2) ]] && ECHO r "脚本地址不能为空!" && EXIT 1
				Script_URL="$(echo "$1" | cut -d "=" -f2)"
			;;
			path=/*)
				[[ -z $(echo "$1" | cut -d "=" -f2) ]] && ECHO r "保存路径不能为空!" && EXIT 1
				Script_Path="$(echo "$1" | cut -d "=" -f2)"
			;;
			--verbose)
				:
			;;
			*)
				SHELL_HELP
			;;
			esac
			shift
		done
		[[ -z ${Script_Path} ]] && Script_Path=/bin
		UPDATE_SCRIPT ${Script_Path} ${Script_URL}
	;;
	-B | --boot-mode)
		shift
		[[ ${TARGET_BOARD} != x86 ]] && EXIT 1
		CHANGE_BOOT $1
	;;
	-C | --change)
		shift
		CHANGE_GITHUB $1
	;;
	-H | --help)
		SHELL_HELP
	;;
	-L | --log)
		shift
		AutoUpdate_LOG $*
	;;
	*)
		SHELL_HELP
	;;
	esac
}

Run_Path=/tmp/AutoUpdate
Log_Path=/tmp
Script_URL=https://ghproxy.com/https://raw.githubusercontent.com/Hyy2001X/AutoBuild-Actions/master/Scripts/AutoUpdate.sh
Default_Variable=/etc/AutoBuild/Default_Variable
Custom_Variable=/etc/AutoBuild/Custom_Variable
[[ -n $* ]] && Run_Command="$0 $*" || Run_Command="$0"

White="\e[0m"
Yellow="\e[33m"
Red="\e[31m"
Blue="\e[34m"
Grey="\e[36m"
Green="\e[32m"

AutoUpdate_Main $*