#!/bin/bash
# AutoBuild Module by Hyy2001 <https://github.com/Hyy2001X/AutoBuild-Actions>
# AutoUpdate for Openwrt
# Dependences: bash wget-ssl/wget/uclient-fetch curl openssl jsonfilter

Version=V6.5.9

function TITLE() {
	clear && echo "Openwrt-AutoUpdate Script by Hyy2001 ${Version}"
}

function SHELL_HELP() {
	TITLE
	cat <<EOF

使用方法:	bash $0 [-n] [-f] [-u] [-F] [-P] [-D <Downloader>] [--path <PATH>] 
		bash $0 [-x] [--path <PATH>] [--url <URL>]

更新固件:
	-n			不保留配置更新固件 *
	-u			适用于定时更新 LUCI 的参数 *
	-f			跳过版本号、SHA256 校验,并强制刷写固件 (危险) *
	-F, --force-write	强制刷写固件 *
	-P, --proxy		优先开启镜像加速下载固件 *
	-D <Downloader>		使用指定的下载器 <wget-ssl | wget | curl | uclient-fetch> *
	--decompress		解压 img.gz 固件后再更新固件 *
	--skip-verify		跳过固件 SHA256 校验 (危险) *
	--path <PATH>		保存固件到提供的绝对路径 <PATH> *

更新脚本:
	-x			更新 AutoUpdate.sh 脚本
	-x --path <PATH>	更新 AutoUpdate.sh 脚本 (保存脚本到提供的绝对路径 <PATH>) *
	-x --url <URL>		更新 AutoUpdate.sh 脚本 (使用提供的地址 <URL> 更新脚本) *

其他参数:
	-B, --boot-mode <TYPE>		指定 x86 设备下载 <TYPE> 引导的固件 (e.g. UEFI Legacy)
	-C <Github URL>			更改 Github 地址为提供的 <Github URL>
	-H, --help			打印 AutoUpdate 帮助信息
	-L, --log < | del>		<打印 | 删除> AutoUpdate 历史运行日志
	    --log --path <PATH>		更改 AutoUpdate 运行日志路径为提供的绝对路径 <PATH>
	-O				打印云端可用固件名称
	-P <F | G>			使用 <FastGit | Ghproxy> 镜像加速 *
	--backup --path <PATH>		备份当前系统配置文件并移动到提供的绝对路径 <PATH> (可选)
	--check				检查 AutoUpdate 运行环境
	--clean				清理 AutoUpdate 缓存
	--fw-log < | [Cc]loud | *>	打印 <当前 | 云端 | 指定版本> 版本的固件更新日志
	--list				打印当前系统信息
	--var <VARIABLE>		打印用户指定的环境变量 <VARIABLE>
	--verbose			打印详细的下载信息 *
	-v < | [Cc]loud>		打印 <当前 | 云端> AutoUpdate.sh 版本
	-V < | [Cc]loud>		打印 <当前 | 云端> 固件版本

脚本、固件更新问题反馈请前往 ${Github}, 并附上 AutoUpdate 运行日志与系统信息 (见上方)

EOF
	EXIT
}

function SHOW_VARIABLE() {
	TITLE
	cat <<EOF

设备名称:		$(uname -n) / ${TARGET_PROFILE}
固件版本:		${CURRENT_Version}
内核版本:		$(uname -r)
其他参数:		${TARGET_BOARD} / ${TARGET_SUBTARGET}
固件作者:		${Author}
作者仓库:		${Github}
Github Release:		${Github_Release}
Github API:		${Github_API}
Github Raw：		${Github_Raw}
OpenWrt Source:		https://github.com/${OP_Maintainer}/${OP_REPO_NAME}:${OP_BRANCH}
固件格式:		${Firmware_Format}
运行路径:		${Running_Path}
日志路径:		${Log_Path}/AutoUpdate.log
EOF
	[[ ${TARGET_BOARD} == x86 ]] && {
		echo "固件引导模式:		${x86_Boot}"
	}
	echo
	LIST_ENV 0
	echo
}

function RM() {
	rm -f $1 2> /dev/null
	[[ $? == 0 ]] && LOGGER "已删除文件: [$1]" || LOGGER "文件: [$1] 不存在或删除失败!"
}

function LIST_ENV() {
	local X
	cat /etc/AutoBuild/*_Variable | grep -v '#' | while read X;do
	[[ ${X} =~ "=" ]] && {
		case "$1" in
		1 | 2)
			[[ -n $(echo ${X} | cut -d "=" -f1) ]] && echo "${X}" | cut -d "=" -f$1
		;;
		0)
			echo "${X}"
		;;
		esac
	}
	done
}

function CHECK_ENV() {
	while [[ $1 ]];do
		[[ $(LIST_ENV 1) =~ $1 ]] && LOGGER "Checking env $1 ... true" || ECHO r "Checking env $1 ... false"
		shift
	done
}

function EXIT() {
	case $1 in
	1 | 2)
		REMOVE_CACHE
	;;
	esac
	LOGGER "[${COMMAND}] 运行结束 $1"
	exit
}

function ECHO() {
	local Color Quiet_Mode
	[[ -z $1 ]] && {
		echo -ne "\n${Grey}[$(date "+%H:%M:%S")]${White} "
	} || {
		while [[ $1 ]];do
			case "$1" in
			r | g | b | y | x)
				case "$1" in
				r) Color="${Red}";;
				g) Color="${Green}";;
				b) Color="${Blue}";;
				y) Color="${Yellow}";;
				x) Color="${Grey}";;
				esac
				shift
			;;
			quiet)
				Quiet_Mode=1
				shift
			;;
			*)
				Message="$1"
				break
			;;
			esac
		done
		[[ ! ${Quiet_Mode} == 1 ]] && {
			echo -e "\n${Grey}[$(date "+%H:%M:%S")]${White}${Color} ${Message}${White}"
			LOGGER "${Message}"
		} || LOGGER "[Quiet Mode] ${Message}"
	}
}

function LOGGER() {
	if [[ ! $* =~ (-H|--help|-L|--log) ]];then
		[[ ! -d ${Log_Path} ]] && mkdir -p ${Log_Path}
		[[ ! -f ${Log_Path}/AutoUpdate.log ]] && touch ${Log_Path}/AutoUpdate.log
		echo "[$(date "+%Y-%m-%d-%H:%M:%S")] [$$] $*" >> ${Log_Path}/AutoUpdate.log
	fi
}

function CHECK_PKG() {
	which $1 > /dev/null 2>&1
	[[ $? == 0 ]] && echo true || echo false
}

function RANDOM() {
	local Result=$(openssl rand -base64 $1 | md5sum | cut -c 1-$1)
	[[ -n ${Result} ]] && echo "${Result}"
	LOGGER "[RANDOM] $1 Bit 计算结果: [${Result}]"
}

function GET_SHA256SUM() {
	[[ ! -f $1 && ! -s $1 ]] && {
		LOGGER "未检测到文件 [$1],无法计算 SHA256 值!"
		EXIT 1
	}
	LOGGER "[GET_SHA256SUM] 目标文件: [$1]"
	local Result=$(sha256sum $1 | cut -c1-$2)
	[[ -n ${Result} ]] && echo "${Result}"
	LOGGER "[GET_SHA256SUM] 计算结果: [${Result}]"
}

function GET_VARIABLE() {
	[[ $# != 2 ]] && SHELL_HELP
	[[ ! -f $2 ]] && ECHO "未检测到定义文件: [$2] !" && EXIT 1
	local Result="$(grep "$1=" $2 | grep -v "#" | awk 'NR==1' | sed -r "s/$1=(.*)/\1/")"
	[[ -n ${Result} ]] && {
		echo "${Result}"
		LOGGER "[GET_VARIABLE] 获取到环境变量 $1=[${Result}]"
	} || {
		LOGGER "[GET_VARIABLE] 环境变量 [$1] 获取失败!"
	}
}

function LOAD_VARIABLE() {
	while [[ $1 ]];do
		[[ -f $1 ]] && {
			chmod 777 $1
			source $1
		} || LOGGER "未检测到环境变量列表: [$1]"
		shift
	done
	[[ -z ${TARGET_PROFILE} ]] && TARGET_PROFILE="$(jsonfilter -e '@.model.id' < /etc/board.json | tr ',' '_')"
	[[ -z ${TARGET_PROFILE} ]] && ECHO r "获取设备名称失败!" && EXIT 1
	[[ -z ${Github} ]] && ECHO "Github URL 获取失败!" && EXIT 1
	[[ -z ${CURRENT_Version} ]] && CURRENT_Version="未知"
	Firmware_Author="${Github##*com/}"
	Github_Release="${Github}/releases/download/AutoUpdate"
	Github_Raw="https://raw.githubusercontent.com/${Firmware_Author}/master"
	Github_API="https://api.github.com/repos/${Firmware_Author}/releases/latest"
	case "${TARGET_BOARD}" in
	x86)
		case "${Firmware_Format}" in
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
		[[ -z ${Firmware_Format} ]] && Firmware_Format=bin
	esac
}

function EDIT_VARIABLE() {
	local Mode="$1"
	shift
	[[ ! -f $1 ]] && ECHO r "未检测到环境变量文件: [$1] !" && EXIT 1
	case "${Mode}" in
	edit)
    	[[ $# != 3 ]] && SHELL_HELP
		[[ -z $(GET_VARIABLE $2 $1) ]] && {
			LOGGER "[EDIT_VARIABLE] 新增环境变量 [$2=$3]"
			echo -e "\n$2=$3" >> $1
		} || {
			sed -i "s?$(GET_VARIABLE $2 $1)?$3?g" $1
		}
	;;
	rm)
		[[ $# != 2 ]] && SHELL_HELP
		LOGGER "[EDIT_VARIABLE] 从 $1 删除环境变量 [$2] ..."
		sed -i "/$2/d" $1
	;;
	esac
}

function CHANGE_GITHUB() {
	[[ ! $1 =~ https://github.com/ ]] && {
		ECHO r "Github 地址输入有误,正确示例: https://github.com/Hyy2001X/AutoBuild-Actions"
		EXIT 1
	}
	UCI_Github=$(uci get autoupdate.@common[0].github 2> /dev/null)
	[[ -n ${UCI_Github} && ! ${UCI_Github} == $1 ]] && {
		uci set autoupdate.@common[0].github=$1 2> /dev/null
		LOGGER "[CHANGE_GITHUB] UCI 配置已设定为 [$1]"
	}
	[[ ! ${Github} == $1 ]] && {
		EDIT_VARIABLE edit ${Custom_Variable} Github $1
		ECHO y "Github 地址已修改为: $1"
		REMOVE_CACHE
	}
	EXIT 0
}

function CHANGE_BOOT() {
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

function UPDATE_SCRIPT() {
	[[ -f $1 ]] && {
		ECHO r "AutoUpdate 脚本保存路径有误,请重新输入!"
		EXIT 1
	}
	if [[ ! -d $1 ]];then
		mkdir -p $1 2> /dev/null || {
			ECHO r "脚本存放目录 [$1] 创建失败!"
			EXIT 1
		}
	fi
	DOWNLOADER --file-name AutoUpdate.sh --no-url-name --dl ${DOWNLOADERS} --url "$2" --path /tmp --timeout 5 --type 脚本
	if [[ -s /tmp/AutoUpdate.sh ]];then
		chmod +x /tmp/AutoUpdate.sh
		Script_Version=$(egrep -o "V[0-9]+.[0-9].+" /tmp/AutoUpdate.sh | awk 'NR==1')
		Banner_Version=$(egrep -o "V[0-9]+.[0-9].+" /etc/banner)
		mv -f /tmp/AutoUpdate.sh $1
		ECHO "脚本保存路径: [$1]"
		[[ -n ${Banner_Version} && $1 == /bin ]] && sed -i "s?${Banner_Version}?${Script_Version}?g" /etc/banner
		ECHO y "[${Banner_Version} > ${Script_Version}] AutoUpdate 脚本更新成功!"
		REMOVE_CACHE
		EXIT 0
	else
		ECHO r "AutoUpdate 脚本更新失败!"
		EXIT 1
	fi
}

function CHECK_DEPENDS() {
	TITLE
	local PKG Tab
	echo -e "\n软件包			检测结果"
	while [[ $1 ]];do
		if [[ $1 =~ : ]];then
			[[ $(echo $1 | cut -d ":" -f1) == ${TARGET_BOARD} ]] && {
				PKG="$(echo "$1" | cut -d ":" -f2)"
				[[ $(echo "${PKG}" | wc -c) -gt 8 ]] && Tab="		" || Tab="			"
				echo -e "${PKG}${Tab}$(CHECK_PKG ${PKG})"
				LOGGER "[CHECK_DEPENDS] 检查软件包: [${PKG}] ... $(CHECK_PKG ${PKG})"
			}
		else
			[[ $(echo "$1" | wc -c) -gt 8 ]] && Tab="		" || Tab="			"
			echo -e "$1${Tab}$(CHECK_PKG $1)"
			LOGGER "[CHECK_DEPENDS] 检查软件包: [$1] ... $(CHECK_PKG $1)"
		fi
		shift
	done
	ECHO y "AutoUpdate 依赖检测结束,请尝试手动安装测结果为 [false] 的项目!"
}

function FW_VERSION_CHECK() {
	[[ $# -gt 1 ]] && echo false && return
	[[ $1 =~ R[1-9.]{2}.+-[0-9]{8} ]] && {
		echo true
		LOGGER "[FW_VERSION_CHECK] 检查固件版本号: [$1] ... true"
	} || {
		echo false
		LOGGER "[FW_VERSION_CHECK] 检查固件版本号: [$1] ... false"
	}
}

function GET_FW_LOG() {
	local Result
	[[ ! $(cat ${API_File}) =~ Update_Logs.json ]] && return 1
	case "$1" in
	[Ll]ocal)
		FW_Version="${CURRENT_Version}"
	;;
	[Cc]loud)
		FW_Version="$(GET_CLOUD_INFO version)"
	;;
	-v)
		shift
		FW_Version="$1"
	;;
	esac
	[[ $(CHECK_TIME ${Running_Path}/Update_Logs.json 2) == false ]] && {
		DOWNLOADER --path ${Running_Path} --file-name Update_Logs.json --dl ${DOWNLOADERS} --url "$(URL_X ${Github_Release} G@@1)" --timeout 3 --type 固件更新日志 --quiet
	}
	[[ -s ${Running_Path}/Update_Logs.json ]] && {
		Result=$(jsonfilter -e '@["'"""${TARGET_PROFILE}"""'"]["'"""${FW_Version}"""'"]' < ${Running_Path}/Update_Logs.json 2> /dev/null)
		[[ -n ${Result} ]] && {
			echo -e "\n${Grey}${FW_Version} for ${TARGET_PROFILE} 更新日志:"
			echo -e "\n${Green}${Result}${White}"
		}
	}
}

function CHECK_TIME() {
	[[ -s $1 && -n $(find $1 -type f -mmin -$2) ]] && {
		LOGGER "[CHECK_TIME] 文件: [$1] 距离修改时间小于 $2 分钟!"
		echo true
	} || {
		LOGGER "[CHECK_TIME] 文件: [$1] 验证失败!"
		RM $1
		echo false
	}
}

function GET_API() {
	local url name date size version
	local API_Dump=${Running_Path}/API_Dump
	[[ $(CHECK_TIME ${API_File} 1) == false ]] && {
		DOWNLOADER --path ${Running_Path} --file-name API_Dump --dl ${DOWNLOADERS} --url "$(URL_X ${Github_Release}/API G@@1 F@@1) ${Github_API}@@1 " --no-url-name --timeout 3 --type 固件信息 --quiet
		[[ ! $? == 0 || -z $(cat ${API_Dump} 2> /dev/null) ]] && {
			ECHO r "Github API 请求错误,请检查网络后重试!"
			RM ${API_Dump}
			EXIT 1
		}
		RM ${API_File} && touch -a ${API_File}
		local i=1;while :;do
			url=$(jsonfilter -e '@["assets"]' < ${API_Dump} | jsonfilter -e '@['"""$i"""'].browser_download_url' 2> /dev/null)
			[[ ! $? == 0 ]] && break
			if [[ ${url} =~ "AutoBuild" || ${url} =~ "${TARGET_PROFILE}" ]]
			then
				size=$(jsonfilter -e '@["assets"]' < ${API_Dump} | jsonfilter -e '@['"""$i"""'].size' 2> /dev/null)
				name=${url##*/}
				size=$(echo ${size} | awk '{a=$1/1048576} {printf("%.2f\n",a)}')
				version=$(echo ${name} | egrep -o "R[0-9.]+-[0-9]+")
				date=$(echo ${version} | cut -d '-' -f2)
				printf "%-75s %-20s %-10s %-15s %s\n" ${name} ${version} ${date} ${size}MB ${url} >> ${API_File}
			fi
			i=$(($i + 1))
		done
	}
	[[ -z $(cat ${API_File} 2> /dev/null) ]] && {
		ECHO r "Github API 解析失败,请尝试清理缓存后再试!"
		RM ${API_File}
		EXIT 1
	}
}

function GET_CLOUD_INFO() {
	local Info
	[[ ! -f ${API_File} ]] && return
	if [[ $1 =~ (All|all|-a) ]];then
		Info=$(grep "AutoBuild-${OP_REPO_NAME}-${TARGET_PROFILE}" ${API_File} | grep "${x86_Boot}" | uniq)
		shift
	else
		Info=$(grep "AutoBuild-${OP_REPO_NAME}-${TARGET_PROFILE}" ${API_File} | grep "${x86_Boot}" | awk 'BEGIN {MAX = 0} {if ($3+0 > MAX+0) {MAX=$3 ;content=$0} } END {print content}')
	fi
	case "$1" in
	name)
		echo "${Info}" | awk '{print $1}'
	;;
	version)
		echo "${Info}" | awk '{print $2}'
	;;
	date)
		echo "${Info}" | awk '{print $3}'
	;;
	size)
		echo "${Info}" | awk '{print $4}'
	;;
	url)
		echo "${Info}" | awk '{print $5}'
	;;
	esac
}

function CHECK_UPDATES() {
	local Version
	Version="$(GET_CLOUD_INFO version)"
	[[ $(FW_VERSION_CHECK ${Version}) == false ]] && {
		ECHO r "固件版本合法性校验失败!"
		EXIT 1
	}
	[[ ${Version} == ${CURRENT_Version} ]] && {
		CURRENT_Type="${Yellow} [已是最新]${White}"
		Upgrade_Stopped=1
	} || {
		[[ $(echo ${Version} | cut -d "-" -f2) -gt $(echo ${CURRENT_Version} | cut -d "-" -f2) ]] && CURRENT_Type="${Green} [可更新]${White}"
		[[ $(echo ${Version} | cut -d "-" -f2) -lt $(echo ${CURRENT_Version} | cut -d "-" -f2) ]] && {
			CHECKED_Type="${Red} [旧版本]${White}"
			Upgrade_Stopped=2
		}
	}
}

function UPGRADE() {
	TITLE
	[[ $* =~ -f && $* =~ -F ]] && SHELL_HELP
	[[ $(NETWORK_CHECK 223.5.5.5 2) == false ]] && {
		ECHO r "网络连接错误,请稍后再试!"
		EXIT 1
	}
	Firmware_Path="${Running_Path}"
	Upgrade_Option="sysupgrade -q"
	MSG="更新固件"
	while [[ $1 ]];do
		case "$1" in
		-T | --test)
			Test_Mode=1
			Special_Commands="${Special_Commands} [测试模式]"
		;;
		-P | --proxy)
			case "$2" in
			F | G)
				Proxy_Type="$2"
				shift
			;;
			*)
				Proxy_Type="All"
			;;
			esac
			Special_Commands="${Special_Commands} [镜像加速 ${Proxy_Type}]"
		;;
		-D)
			DOWNLOADERS="$2"
			Special_Commands="${Special_Commands} [${DOWNLOADERS}]"
			shift
		;;
		-F | --force-write)
			[[ -n ${Force_Mode} ]] && SHELL_HELP
			Only_Force_Write=1
			Special_Commands="${Special_Commands} [强制刷写]"
			Upgrade_Option="${Upgrade_Option} -F"
		;;
		--decompress)
			Special_Commands="${Special_Commands} [解压固件]"
			Decompress_Mode=1
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
		--path)
			Firmware_Path="$2"
			ECHO g "使用自定义固件保存路径: [${Firmware_Path}]"
			shift
		;;
		--skip-verify)
			Skip_Verify=1
			Special_Commands="${Special_Commands} [跳过 SHA256 验证]"
		;;
		-u)
			AutoUpdate_Mode=1
			Special_Commands="${Special_Commands} [定时更新]"
		;;
		--verbose)
			Special_Commands="${Special_Commands} [详细信息]"
		;;
		*)
			LOGGER "跳过未知参数: [$1] ..."
			shift
		esac
	shift
	done
	LOGGER "固件更新指令: [${Upgrade_Option}]"
	[[ -n "${Special_Commands}" ]] && ECHO g "特殊指令:${Special_Commands} / ${Upgrade_Option}"
	ECHO g "执行: ${MSG}${Special_MSG}"
	if [[ $(CHECK_PKG curl) == true && -z ${Proxy_Type} ]];then
		Google_Check=$(curl -I -s --connect-timeout 3 google.com -w %{http_code} | tail -n1)
		LOGGER "Google 连接检查结果: [${Google_Check}]"
		[[ ${Google_Check} != 301 ]] && {
			ECHO r "Google 连接失败,优先使用镜像加速下载"
			Proxy_Type="All"
		}
	fi
	ECHO "正在检查版本更新 ..."
	GET_API
	CHECK_UPDATES
	CLOUD_FW_Version="$(GET_CLOUD_INFO version)"
	CLOUD_FW_Name="$(GET_CLOUD_INFO name)"
	CLOUD_FW_Size="$(GET_CLOUD_INFO size)"
	CLOUD_FW_Url="$(GET_CLOUD_INFO url)"
	[[ -z ${CLOUD_FW_Name} ]] && {
		ECHO r "云端固件名称获取失败!"
		EXIT 1
	}
	[[ -z ${CLOUD_FW_Version} ]] && {
		ECHO r "云端固件版本获取失败!"
		EXIT 1
	}
	cat <<EOF

设备名称: ${TARGET_PROFILE}
内核版本: $(uname -r)
$([[ ${TARGET_BOARD} == x86 ]] && echo "固件格式: ${Firmware_Format} / ${x86_Boot}" || echo "固件格式: ${Firmware_Format}")

$(echo -e "当前固件版本: ${CURRENT_Version}${CURRENT_Type}")
$(echo -e "云端固件版本: ${CLOUD_FW_Version}${CHECKED_Type}")

云端固件名称: ${CLOUD_FW_Name}
云端固件体积: ${CLOUD_FW_Size}
EOF
	GET_FW_LOG -v ${CLOUD_FW_Version}
	case "${Upgrade_Stopped}" in
	1 | 2)
		[[ ${AutoUpdate_Mode} == 1 ]] && ECHO y "当前固件已是最新版本,无需更新!" && EXIT 0
		[[ ${Upgrade_Stopped} == 1 ]] && MSG="已是最新版本" || MSG="云端固件版本为旧版"
		[[ ! ${Force_Mode} == 1 ]] && {
			ECHO && read -p "${MSG},是否继续更新固件?[Y/n]:" Choose
		} || Choose=Y
		[[ ! ${Choose} =~ [Yy] ]] && EXIT 0
	;;
	esac
	local URL
	case "${Proxy_Type}" in
	F | G)
		URL="$(URL_X ${CLOUD_FW_Url} ${Proxy_Type}@@5)"
	;;
	All)
		URL="$(URL_X ${CLOUD_FW_Url} G@@2 F@@2 X@@1)"
	;;
	*)
		URL="$(URL_X ${CLOUD_FW_Url} X@@2 G@@2 F@@1)"
	;;
	esac
	DOWNLOADER --file-name ${CLOUD_FW_Name} --no-url-name --dl ${DOWNLOADERS} --url ${URL} --path ${Firmware_Path} --timeout 5 --type 固件
	[[ ! -s ${Firmware_Path}/${CLOUD_FW_Name} ]] && EXIT 1
	if [[ ! Force_Mode == 1 ]];then
		LOCAL_SHA256=$(GET_SHA256SUM ${Firmware_Path}/${CLOUD_FW_Name} 5)
		CLOUD_SHA256=$(echo ${CLOUD_FW_Name} | egrep -o "[0-9a-z]+.${Firmware_Format}" | sed -r "s/(.*).${Firmware_Format}/\1/")
		[[ ${LOCAL_SHA256} != ${CLOUD_SHA256} ]] && {
			ECHO r "SHA256 校验失败,请检查网络后重试!"
			REMOVE_CACHE
			EXIT 1
		}
		LOGGER "固件 SHA256 比对通过!"
	fi
	case "${Firmware_Format}" in
	img.gz)
		if [[ ${Decompress_Mode} == 1 ]];then
			ECHO "正在解压 [${Firmware_Format}] 固件 ..."
			gzip -d -q -f -c ${Firmware_Path}/${CLOUD_FW_Name} > ${Firmware_Path}/$(echo ${CLOUD_FW_Name} | sed -r 's/(.*).gz/\1/')
			[[ ! $? == 0 ]] && {
				ECHO r "固件解压失败!"
				EXIT 1
			} || {
				CLOUD_FW_Name="$(echo ${CLOUD_FW_Name} | sed -r 's/(.*).gz/\1/')"
				LOGGER "固件解压成功,固件已解压到: [${Firmware_Path}/${CLOUD_FW_Name}]"
			}
		else
			[[ $(CHECK_PKG gzip) == true ]] && opkg remove gzip > /dev/null 2>&1
		fi
	;;
	esac
	[[ ${Test_Mode} != 1 ]] && {
		DO_UPGRADE ${Upgrade_Option} ${Firmware_Path}/${CLOUD_FW_Name}
	} || {
		ECHO x "[测试模式] ${Upgrade_Option} ${Firmware_Path}/${CLOUD_FW_Name}"
		EXIT 0
	}
}

function DOWNLOADER() {
	local DL_Downloader DL_Name DL_URL DL_Path DL_Retries DL_Timeout DL_Type DL_Final Quiet_Mode No_URL_Name Print_Mode DL_Retires_All DL_URL_Final
	LOGGER "开始解析传入参数 ..."
	LOGGER "[$*]"
	# --dl 下载器 --file-name 文件名称 --no-url-name --url 下载地址1@@重试次数 下载地址2@@重试次数 --path 保存位置 --timeout 超时 --type 类型 --quiet --print
	while [[ $1 ]];do
		case "$1" in
		--dl)
			shift
			while [[ $1 ]];do	
				case "$1" in
				wget-ssl | curl | wget | uclient-fetch)
					[[ $(CHECK_PKG $1) == true ]] && {
						DL_Downloader="$1"
						break
					}
					shift
				;;
				*)
					LOGGER "跳过未知下载器: [$1] ..."
					shift
				;;
				esac
			done
			while [[ $1 ]];do
				[[ $1 =~ '--' ]] && break
				[[ ! $1 =~ '--' ]] && shift
			done
			[[ -z ${DL_Downloader} ]] && {
				ECHO r "没有可用的下载器,请尝试更换手动安装!"
				EXIT 1
			}
			LOGGER "[--D Finished] Downloader: [${DL_Downloader}]"
		;;
		--file-name)
			shift
			DL_Name="$1"
			while [[ $1 ]];do
				[[ $1 =~ '--' ]] && break
				[[ ! $1 =~ '--' ]] && shift
			done
			LOGGER "[--file-name Finished] 文件名称: [${DL_Name}]"
		;;
		--url)
			shift
			DL_URL=($(echo $@ | egrep -o "https://.*@@[0-9]+|https://.*@@[0-9]+|ftp://.*@@[0-9]+"))
			[[ -z ${DL_URL[*]} ]] && {
				DL_URL=($1)
				DL_URL_Count="${#DL_URL[@]}"
				DL_Retires_All="${DL_URL_Count}"
			} || {
				DL_Retires_All="$(echo ${DL_URL[*]} | egrep -o "@@[0-9]+" | egrep -o "[0-9]+" | awk '{Sum += $1};END {print Sum}')"
				DL_URL_Count="${#DL_URL[@]}"
			}
			LOGGER "URL 数量: [${DL_URL_Count}] 总重试次数: [${DL_Retires_All}]"
			while [[ $1 ]];do
				[[ $1 =~ '--' ]] && break
				[[ ! $1 =~ '--' ]] && shift
			done
			LOGGER "[--url Finished] DL_URL: ${DL_URL[*]}"
		;;
		--no-url-name)
			shift
			LOGGER "Enabled No-Url-Filename Mode"
			No_URL_Name=1
		;;
		--path)
			shift
			DL_Path="$1"
			if [[ ! -d ${DL_Path} ]];then
				mkdir -p ${DL_Path} 2> /dev/null || {
					ECHO r "下载目录 [${DL_Path}] 创建失败!"
					return 1
				}
			fi
			while [[ $1 ]];do
				[[ $1 =~ '--' ]] && break
				[[ ! $1 =~ '--' ]] && shift
			done
			LOGGER "[--DL_PATH Finished] 存放路径: ${DL_Path}"
		;;
		--timeout)
			shift
			[[ ! $1 =~ [1-9] ]] && {
				LOGGER "参数: [$1] 不是正确的数字"
				shift
			} || {
				DL_Timeout="$1"
				while [[ $1 ]];do
					[[ $1 =~ '--' ]] && break
					[[ ! $1 =~ '--' ]] && shift
				done
				LOGGER "[--T Finished] 超时: ${DL_Timeout}s"
			}
		;;
		--type)
			shift
			DL_Type="$1"
			while [[ $1 ]];do
				[[ $1 =~ '--' ]] && break
				[[ ! $1 =~ '--' ]] && shift
			done
			LOGGER "[--DL_Type Finished] 文件类型: ${DL_Type}"
		;;
		--quiet)
			shift
			LOGGER "Enabled Quiet Mode"
			Quiet_Mode=quiet
		;;
		--print)
			shift
			LOGGER "Enabled Print Mode && Quiet Mode"
			Print_Mode=1
			Quiet_Mode=quiet
		;;
		*)
			LOGGER "跳过未知参数: [$1] ..."
			shift
		;;
		esac
	done
	LOGGER "传入参数解析完成!"
	case "${DL_Downloader}" in
	wget | wget-ssl)
		DL_Template="wget-ssl --quiet --no-check-certificate --no-dns-cache -x -4 --tries 1 --timeout 5 -O"
	;;
	curl)
		DL_Template="curl --silent --insecure -L -k --connect-timeout 5 --retry 1 -o"
	;;
	uclient-fetch)
		DL_Template="uclient-fetch --quiet --no-check-certificate -4 --timeout 5 -O"
	;;
	esac
	[[ ${Test_Mode} == 1  || ${Verbose_Mode} == 1 ]] && {
		DL_Template="${DL_Template/ --quiet / }"
		DL_Template="${DL_Template/ --silent / }"
	}
	[[ -n ${DL_Timeout} ]] && DL_Template="${DL_Template/-timeout 5/-timeout ${DL_Timeout}}"
	local E=0 u;while [[ ${E} != ${DL_URL_Count} ]];do
		DL_URL_Cache="${DL_URL[$E]}"
		DL_Retries="${DL_URL_Cache##*@@}"
		[[ -z ${DL_Retries} || ! ${DL_Retries} == [0-9] ]] && DL_Retries=1
		DL_URL_Final="${DL_URL_Cache%*@@*}"
		LOGGER "当前 URL: [${DL_URL_Final}] URL 重试次数: [${DL_Retries}]"
		for u in $(seq ${DL_Retries});do
			sleep 1
			[[ -z ${Failed} ]] && {
				ECHO ${Quiet_Mode} "正在下载${DL_Type},请耐心等待 ..."
			} || {
				ECHO ${Quiet_Mode} "尝试重新下载${DL_Type},剩余重试次数: [${DL_Retires_All}]"
			}
			if [[ -z ${DL_Name} ]];then
				DL_Name="${DL_URL_Final##*/}"
				DL_Final="${DL_Template} ${DL_Path}/${DL_Name} ${DL_URL_Final}"
			else
				[[ ${No_URL_Name} == 1 ]] && {
					DL_Final="${DL_Template} ${DL_Path}/${DL_Name} ${DL_URL_Final}"
				} || DL_Final="${DL_Template} ${DL_Path}/${DL_Name} ${DL_URL_Final}/${DL_Name}"
			fi
			[[ -f ${DL_Path}/${DL_Name} ]] && {
				LOGGER "删除已存在的文件: [${DL_Path}/${DL_Name}] ..."
				RM ${DL_Path}/${DL_Name}
			}
			LOGGER "执行下载: [${DL_Final}]"
			${DL_Final}
			if [[ $? == 0 && -s ${DL_Path}/${DL_Name} ]];then
				ECHO y ${Quiet_Mode} "${DL_Type}下载成功!"
				[[ ${Print_Mode} == 1 ]] && {
					cat ${DL_Path}/${DL_Name} 2> /dev/null
					RM ${DL_Path}/${DL_Name}
				}
				touch -a ${DL_Path}/${DL_Name} 2> /dev/null
				return 0
			else
				[[ -z ${Failed} ]] && local Failed=1
				DL_Retires_All=$((${DL_Retires_All} - 1))
				if [[ ${u} == ${DL_Retries} ]];then
					break 1
				else
					ECHO r ${Quiet_Mode} "下载失败!"
					u=$((${u} + 1))
				fi
			fi
		done
		E=$((${E} + 1))
	done
	RM ${DL_Path}/${DL_Name}
	ECHO r ${Quiet_Mode} "${DL_Type}下载失败,请检查网络后重试!"
	return 1
}

function DO_UPGRADE() {
	ECHO r "警告: 固件更新期间请不要断开电源或尝试重启设备!"
	sleep 3
	ECHO g "正在更新固件,请耐心等待 ..."
	$*
	[[ $? -ne 0 ]] && {
		ECHO r "固件刷写失败,请尝试使用 autoupdate -F 指令再次更新固件!"
		ECHO r "脚本与固件更新问题请前往 [${Github}] 进行反馈, 请附上 AutoUpdate 运行日志与系统信息"
		EXIT 1
	} || EXIT 0
}

function REMOVE_CACHE() {
	rm -rf ${Running_Path}/API \
		${Running_Path}/Update_Logs \
		${Running_Path}/API_Dump 2> /dev/null
	LOGGER "AutoUpdate 缓存清理完成!"
}

function LOG() {
	[[ -z $1 ]] && {
		[[ -s ${Log_Path}/AutoUpdate.log ]] && {
			TITLE && echo
			cat ${Log_Path}/AutoUpdate.log
			EXIT 0
		}
	} || {
		while [[ $1 ]];do
			case "$1" in
			--path)
				[[ $2 == ${Log_Path} ]] && {
					ECHO y "AutoUpdate 日志保存路径相同,无需修改!"
					EXIT 0
				}
				[[ -f $2 ]] && {
					ECHO r "AutoUpdate 日志保存路径有误,请重新输入!"
					EXIT 1
				}
				EDIT_VARIABLE rm ${Custom_Variable} Log_Path
				EDIT_VARIABLE edit ${Custom_Variable} Log_Path $2
				[[ ! -d $2 ]] && mkdir -p $2
				[[ -f $2/AutoUpdate.log ]] && mv ${Log_Path}/AutoUpdate.log $2
				Log_Path="$2"
				ECHO y "AutoUpdate 日志保存路径已修改为: [$2]!"
			;;
			del | rm | clean)
				RM ${Log_Path}/AutoUpdate.log
			;;
			*)
				SHELL_HELP
			;;
			esac
			EXIT 0
		done
	}
}

URL_X() {
	#URL_X https://raw.githubusercontent.com/Hyy2001X/AutoBuild-Actions/master/Scripts/AutoUpdate.sh F@@1 G@@1 X@@1 
	local URL=$1 Type URL_Final
	[[ ${URL} =~ raw.githubusercontent.com ]] && Type=raw
	[[ ${URL} =~ releases/download ]] && Type=release
	[[ ${URL} =~ codeload.github.com ]] && Type=codeload
	
	case "${Type}" in
	raw)
		FastGit=https://raw.fastgit.org/$(echo ${URL##*com/})
		Ghproxy=https://ghproxy.com/${URL}
	;;
	release)
		FastGit=https://download.fastgit.org/$(echo ${URL##*com/})
		Ghproxy=https://ghproxy.com/${URL}
	;;
	codeload)
		FastGit=https://download.fastgit.org/$(echo ${URL##*com/})
		Ghproxy=https://ghproxy.com/${URL}
	;;
	esac
	while [[ $1 ]];do
		local URL_Cache=$1 URL_Final
		case "$1" in
		F@@*)
			URL_Final="${URL_Cache/F/${FastGit}}"
		;;
		G@@*)
			URL_Final="${URL_Cache/G/${Ghproxy}}"
		;;
		X@@*)
			URL_Final="${URL_Cache/X/${URL}}"
		;;
		esac
		[[ -n ${URL_Final} ]] && {
			echo "${URL_Final}"
			LOGGER "[URL_X] ${URL_Final}"
		}
		unset URL_Final
		shift
	done
}

function NETWORK_CHECK() {
	ping $1 -c 1 -W $2 > /dev/null 2>&1
	[[ $? == 0 ]] && echo true || echo false
}

function AutoUpdate_Main() {
	LOGGER "[${COMMAND}] 开始运行"
	if [[ ! $1 =~ (-H|--help) ]];then
		[[ ! -f ${Default_Variable} ]] && {
			ECHO r "脚本运行环境检测失败,无法正常运行脚本!"
			EXIT 1
		}
		[[ ! -f ${Custom_Variable} ]] && touch ${Custom_Variable}
		LOAD_VARIABLE ${Default_Variable} ${Custom_Variable}
		[[ ! -d ${Running_Path} ]] && {
			mkdir -p ${Running_Path}
			[[ ! $? == 0 ]] && {
				ECHO r "脚本运行目录 [${Running_Path}] 创建失败!"
				EXIT 1
			}
		}
	fi

	[[ -z $* ]] && UPGRADE $*

	local Input=($@) E=0 F Custom_Path Custom_URL
	while :;do
		F="${Input[${E}]}"
		case "${F}" in
		-T)
			Test_Mode=1
		;;
		--verbose)
			Verbose_Mode=1
		;;
		--path)
			Custom_Path="${Input[$((${E} + 1))]}"
			[[ -z ${Custom_Path} ]] && {
				ECHO r "请输入正确的路径!"
			}
		;;
		--url)
			Custom_URL="${Input[$((${E} + 1))]}"
			[[ -z ${Custom_URL} || ! ${Custom_URL} =~ (https://*|http://*|ftp://*) ]] && {
				ECHO r "链接格式错误,请输入正确的链接!"
				EXIT 1
			}
		;;
		-D)
			case "${Input[$((${E} + 1))]}" in
			wget | curl | wget-ssl | uclient-fetch)
				DOWNLOADERS=${Input[$((${E} + 1))]}
			;;
			*)
				ECHO r "暂不支持当前下载器: [${Input[$((${E} + 1))]}]"
				EXIT 1
			;;
			esac
		;;
		esac
		[[ ${E} == ${#Input[@]} ]] && break
		E=$((${E} + 1))
	done

	while [[ $1 ]];do
		case "$1" in
		-n | -f | -u | -T | -P | --proxy | -F | --force-write | --verbose | --decompress | --skip-verify | -D | --path)
			UPGRADE $*
			EXIT 2
		;;
		--backup)
			local FILE="backup-$(uname -n)-$(date +%Y-%m-%d)-$(RANDOM 5).tar.gz"
			shift
			[[ $# -gt 1 ]] && SHELL_HELP
			[[ -z $1 ]] && {
				FILE=$(pwd)/${FILE}
			} || {
				if [[ ! -d $1 ]];then
					mkdir -p $1 || {
						ECHO r "备份存放目录 [$1] 创建失败!"
						EXIT 1
					}
				fi
				FILE=$1/${FILE}
			}
			ECHO "正在备份系统文件到 [${FILE}] ..."
			sysupgrade -b "${FILE}" > /dev/null 2>&1
			[[ $? == 0 ]] && {
				ECHO y "备份文件创建成功!"
				EXIT 0
			} || {
				ECHO r "备份文件 [${FILE}] 创建失败!"
				EXIT 1
			}
		;;
		--clean)
			shift && [[ -n $* ]] && SHELL_HELP
			REMOVE_CACHE
			EXIT 0
		;;
		--check)
			shift && [[ -n $* ]] && SHELL_HELP
			CHECK_DEPENDS bash uclient-fetch curl wget openssl jsonfilter
			[[ $(NETWORK_CHECK 223.5.5.5 2) == false ]] && {
				ECHO r "网络连接错误!"
			} || ECHO y "网络连接正常!"
			CHECK_ENV ${ENV_DEPENDS}
			EXIT 0
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
			EXIT 2
		;;
		-V)
			shift
			[[ -z $* ]] && echo "${CURRENT_Version}" && EXIT 1
			case "$1" in
			[Cc]loud)
				shift
				GET_API
				GET_CLOUD_INFO $* version
			;;
			*)
				SHELL_HELP
			;;
			esac
			EXIT 2
		;;
		--fw-log)
			shift
			GET_API
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
			EXIT 2
		;;
		--list)
			shift
			SHOW_VARIABLE
			EXIT 0
		;;
		--var)
			local Result
			shift
			[[ $# != 1 ]] && SHELL_HELP
			Result=$(GET_VARIABLE "$1" ${Custom_Variable})
			[[ -z ${Result} ]] && Result=$(GET_VARIABLE "$1" ${Default_Variable})
			[[ -n ${Result} ]] && echo "${Result}"
			EXIT 2
		;;
		-v)
			shift
			[[ -z $* ]] && echo ${Version} && EXIT 0
			case "$1" in
			[Cc]loud)
				Script_URL="$(URL_X ${Github_Raw}/Scripts/AutoUpdate.sh G@@1)"
				DOWNLOADER --dl ${DOWNLOADERS} --url ${Script_URL} --path /tmp --print | egrep -o "V[0-9].+"
			;;
			*)
				SHELL_HELP
			esac
			EXIT 2
		;;
		-x)
			shift
			Script_URL="$(URL_X ${Github_Raw}/Scripts/AutoUpdate.sh G@@1 F@@1 X@@1)"
			[[ $(NETWORK_CHECK 223.5.5.5 2) == false ]] && {
				ECHO r "网络连接错误,请稍后再试!"
				EXIT 1
			}
			Script_Path=/bin
			[[ -n ${Custom_Path} ]] && Script_Path=${Custom_Path}
			[[ -n ${Custom_URL} ]] && Script_URL=${Custom_URL}
			UPDATE_SCRIPT ${Script_Path} ${Script_URL}
			EXIT 2
		;;
		-B | --boot-mode)
			shift
			[[ ${TARGET_BOARD} != x86 ]] && EXIT 1
			CHANGE_BOOT $1
			EXIT 2
		;;
		-C)
			shift
			CHANGE_GITHUB $1
			EXIT 2
		;;
		-H | --help)
			SHELL_HELP
			EXIT 2
		;;
		-L | --log)
			shift
			LOG $*
			EXIT 2
		;;
		-O)
			GET_API
			GET_CLOUD_INFO -a name
			EXIT 0
		;;
		*)
			SHELL_HELP
			EXIT 1
		;;
		esac
	done
}

Running_Path=/tmp/AutoUpdate
Log_Path=/tmp
API_File=${Running_Path}/API
Default_Variable=/etc/AutoBuild/Default_Variable
Custom_Variable=/etc/AutoBuild/Custom_Variable
ENV_DEPENDS="Author Github TARGET_PROFILE TARGET_BOARD TARGET_SUBTARGET Firmware_Format CURRENT_Version OP_Maintainer OP_BRANCH OP_REPO_NAME"
DOWNLOADERS="wget-ssl curl wget uclient-fetch"

White="\e[0m"
Yellow="\e[33m"
Red="\e[31m"
Blue="\e[34m"
Grey="\e[36m"
Green="\e[32m"

[[ -n $* ]] && COMMAND="$0 $*" || COMMAND="$0"
AutoUpdate_Main $*