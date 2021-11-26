#!/bin/bash
# AutoBuild Module by Hyy2001 <https://github.com/Hyy2001X/AutoBuild-Actions>
# AutoUpdate for Openwrt
# Dependences: bash wget-ssl/wget/uclient-fetch curl openssl jsonfilter expr

Version=V6.7.7

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
	-f			跳过版本号校验,并强制刷写固件 (不推荐) *
	-F, --force-write	强制刷写固件 *
	-P, --proxy		优先开启镜像加速下载固件 *
	-D <Downloader>		使用指定的下载器 <wget-ssl | wget | curl | uclient-fetch> *
	--decompress		解压 img.gz 固件后再更新固件 *
	--skip-verify		跳过固件 SHA256 校验 *
	--path <PATH>		固件下载路径替换为提供的绝对路径 <PATH> *

更新脚本:
	-x			更新 AutoUpdate.sh 脚本
	-x --path <PATH>	更新 AutoUpdate.sh 脚本 (保存脚本到提供的绝对路径 <PATH>) *
	-x --url <URL>		更新 AutoUpdate.sh 脚本 (使用提供的地址 <URL> 更新脚本) *

其他参数:
	-B, --boot-mode <TYPE>		指定 x86 设备下载 <TYPE> 引导的固件 (e.g. UEFI BIOS)
	-C <Github URL>			更改 Github 地址为提供的 <Github URL>
	--help				打印 AutoUpdate 帮助信息
	--log < | del>			<打印 | 删除> AutoUpdate 历史运行日志
	--log --path <PATH>		更改 AutoUpdate 运行日志路径为提供的绝对路径 <PATH>
	-P <F | G>			使用 <FastGit | Ghproxy> 镜像加速 *
	--backup --path <PATH>		备份当前系统配置文件并移动到提供的绝对路径 <PATH> (可选)
	--env-list < | 1 | 2>		打印 <完整 | 第一列 | 第二列> 环境变量列表
	--check				检查 AutoUpdate 运行环境
	--clean				清理 AutoUpdate 缓存
	--fw-log < | *>	打印 <当前 | 指定> 版本的固件更新日志
	--fw-list			打印所有云端固件名称
	--list				打印当前系统信息
	--var <VARIABLE>		打印用户指定的环境变量 <VARIABLE>
	--verbose			打印详细下载信息 *
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
固件版本:		${OP_VERSION}
内核版本:		$(uname -r)
运行内存:		Mem: $(MEMINFO 1)M | Swap: $(MEMINFO 2)M | Total: $(MEMINFO 3)M
其他参数:		${TARGET_BOARD} / ${TARGET_SUBTARGET}
固件作者:		${Author}
作者仓库:		${Github}
Github Release:		${Github_Release}
Github API:		${Github_API}
Github Raw：		${Github_Raw}
OpenWrt Source:		https://github.com/${OP_AUTHOR}/${OP_REPO}:${OP_BRANCH}
API 路径:		${API_File}
脚本运行路径:		${Tmp_Path}
脚本日志路径:		${Log_Path}/AutoUpdate.log
下载器:			${DOWNLOADERS}
EOF
	[[ ${TARGET_BOARD} == x86 ]] && {
		echo "固件引导模式:		${x86_Boot_Method}"
	}
	echo
}

function MEMINFO() {
	local Mem Swap All Result
	Mem=$(free | grep Mem: | awk '{Mem=$7/1024} {printf("%.0f\n",Mem)}' 2> /dev/null)
	Swap=$(free | grep Swap: | awk '{Swap=$4/1024} {printf("%.0f\n",Swap)}' 2> /dev/null)
	All=$(expr ${Mem} + ${Swap} 2> /dev/null)
	case $1 in
	1)
		Result=${Mem}
	;;
	2)
		Result=${Swap}
	;;
	3)
		Result=${All}
	;;
	esac
	if [[ -n ${Result} ]]
	then
		LOGGER "[MEMINFO] [$1] 运行内存: ${Result}M"
		echo ${Result}
		return 0
	else
		LOGGER "[MEMINFO] [$1] 可用运行内存获取失败!"
		return 1
	fi
}

SPACEINFO() {
	local Result Path
	Path=$(echo $1 | awk -F '/' '{print $2}')
	Result=$(df -m /${Path} 2> /dev/null | grep -v Filesystem | awk '{print $4}')
	if [[ -n ${Result} ]]
	then
		LOGGER "[SPACEINFO] /${Path} 可用空间: ${Result}M"
		echo "${Result}"
		return 0
	else
		LOGGER "[SPACEINFO] /${Path} 可用空间获取失败!"
		return 1
	fi
}

function RM() {
	[[ -z $* ]] && return 1
	rm -rf "$*" 2> /dev/null
	LOGGER "已删除文件: [$1]"
	return 0
}

function LIST_ENV() {
	local X
	cat ${Default_Variable} ${Custom_Variable} | grep -v '#' | while read X;do
		case $1 in
		1 | 2)
			[[ -n ${X} ]] && eval echo ${X} | awk -F '=' '{print $"'$1'"}'
		;;
		*)
			[[ -n ${X} ]] && eval echo ${X}
		;;
		esac
		
	done
}

function CHECK_ENV() {
	while [[ $1 ]];do
		if [[ -n $(GET_VARIABLE $1 ${Default_Variable} 2> /dev/null) ]]
		then
			LOGGER "[CHECK_ENV] 检查环境变量 [$1] ... 正常"
		else
			ECHO r "[CHECK_ENV] 检查环境变量 [$1] ... 错误"
		fi
		shift
	done
}

function CHECK_PKG() {
	local Result="$(command -v $1 2> /dev/null)"
	if [[ -n ${Result} && $? == 0 ]]
	then
		LOGGER "[CHECK_PKG] 检查软件包: [$1] ... 正常"
		echo true
		return 0
	else
		LOGGER "[CHECK_PKG] 检查软件包: [$1] ... 错误"
		echo false
		return 1
	fi
}

function EXIT() {
	case "$1" in
	2)
		REMOVE_CACHE
	;;
	esac
	exit $1
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
	[[ -z ${Log_Path} ]] && return 0
	if [[ ! $* =~ (--help|--log) ]]
	then
		[[ ! -d ${Log_Path} ]] && mkdir -p ${Log_Path}
		[[ ! -f ${Log_Path}/AutoUpdate.log ]] && touch ${Log_Path}/AutoUpdate.log
		echo "[$(date "+%H:%M:%S")] [$$] $*" >> ${Log_Path}/AutoUpdate.log
	fi
}

function RANDOM() {
	local Result="$(openssl rand -base64 $1 | md5sum | cut -c 1-$1)"
	if [[ -n ${Result} ]]
	then
		LOGGER "[RANDOM] $1 Bit 计算结果: [${Result}]"
		echo "${Result}"
		return 0
	else
		return 1
	fi
}

function GET_SHA256SUM() {
	local Result="$(sha256sum $1 | cut -c1-$2)"
	if [[ -n ${Result} ]]
	then
		LOGGER "[GET_SHA256SUM] 计算结果: [${Result}]"
		echo "${Result}"
		return 0
	else
		return 1
	fi
}

function GET_VARIABLE() {
	local Result="$(grep "$1=" "$2" | grep -v "#" | awk -F '=' '{print $2}')"
	if [[ -n ${Result} ]]
	then
		eval echo "${Result}"
		return 0
	else
		return 1
	fi
}

function EDIT_VARIABLE() {
	local Mode="$1"
	shift
	[[ ! -s $1 ]] && ECHO r "未检测到环境变量文件: [$1] !" && return 1
	case "${Mode}" in
	edit)
		if [[ -z $(GET_VARIABLE $2 $1) ]]
		then
			LOGGER "[EDIT_VARIABLE] 新增环境变量 [$2 = $3]"
			echo -e "\n$2=$3" >> $1
			return 0
		else
			sed -i "s?$(GET_VARIABLE $2 $1)?$3?g" $1 2> /dev/null
			if [[ $? == 0 ]]
			then
				LOGGER "[EDIT_VARIABLE] 环境变量 [$2 > $3] 修改成功!"
				return 0
			else
				LOGGER "[EDIT_VARIABLE] 环境变量 [$2 > $3] 修改失败!"
				return 1
			fi
		fi
	;;
	rm)
		sed -i "/$2/d" $1
		if [[ $? == 0 ]]
		then
			LOGGER "[EDIT_VARIABLE] 从 $1 删除环境变量 [$2] ... 成功"
			return 0
		else
			LOGGER "[EDIT_VARIABLE] 从 $1 删除环境变量 [$2] ... 失败"
			return 1
		fi
	;;
	esac
}

function LOAD_VARIABLE() {
	while [[ $1 ]];do
		[[ -s $1 ]] && {
			chmod 777 $1
			source $1
		} || LOGGER "[LOAD_VARIABLE] 未检测到环境变量列表: [$1]"
		shift
	done
	[[ -z ${TARGET_PROFILE} ]] && TARGET_PROFILE="$(jsonfilter -i /etc/board.json -e '@.model.id' | tr ',' '_')"
	[[ -z ${TARGET_PROFILE} ]] && ECHO r "获取设备名称失败!" && EXIT 1
	[[ -z ${Github} ]] && ECHO r "Github 地址获取失败!" && EXIT 1
	[[ -z ${OP_VERSION} ]] && OP_VERSION="未知"
	Firmware_Author="${Github##*com/}"
	Github_Release="${Github}/releases/download/AutoUpdate"
	Github_Raw="https://raw.githubusercontent.com/${Firmware_Author}/master"
	Github_API="https://api.github.com/repos/${Firmware_Author}/releases/latest"
	case "${TARGET_BOARD}" in
	x86)
		[[ -z ${x86_Boot_Method} ]] && {
			[ -d /sys/firmware/efi ] && {
				x86_Boot_Method=UEFI
			} || x86_Boot_Method=BIOS
		}
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
		if [[ $? == 0 ]]
		then
			ECHO y "Github 地址已修改为: $1"
		else
			ECHO y "Github 地址修改失败!"
		fi
		REMOVE_CACHE
	}
	EXIT 0
}

function CHANGE_BOOT() {
	[[ -z $1 ]] && SHELL_HELP
	case "$1" in
	UEFI | BIOS)
		EDIT_VARIABLE edit ${Custom_Variable} x86_Boot_Method $1
		ECHO r "警告: 更换引导方式后更新固件后可能导致设备无法正常启动!"
		ECHO y "固件引导格式已指定为: [$1]"
		EXIT 0
	;;
	*)
		ECHO r "错误的参数: [$1],支持的启动方式: [UEFI/BIOS]"
		EXIT 1
	;;
	esac
}

function UPDATE_SCRIPT() {
	if [[ ! -d $1 ]];then
		mkdir -p $1 2> /dev/null || {
			ECHO r "脚本保存路径 [$1] 创建失败!"
			EXIT 1
		}
	fi
	ECHO "脚本保存路径: [$1]"
	DOWNLOADER --file-name AutoUpdate.sh --no-url-name --dl ${DOWNLOADERS} --url $2 --path ${Tmp_Path} --timeout 5 --type 脚本
	if [[ -s ${Tmp_Path}/AutoUpdate.sh ]];then
		chmod +x ${Tmp_Path}/AutoUpdate.sh
		Script_Version=$(awk -F '=' '/Version/{print $2}' ${Tmp_Path}/AutoUpdate.sh | awk 'NR==1')
		Banner_Version=$(egrep -o "V[0-9.]+" /etc/banner)
		mv -f ${Tmp_Path}/AutoUpdate.sh $1 2> /dev/null
		[[ $? == 0 ]] && {
			[[ -n ${Banner_Version} && $1 == /bin ]] && sed -i "s?${Banner_Version}?${Script_Version}?g" /etc/banner
			ECHO y "[${Banner_Version} > ${Script_Version}] AutoUpdate 脚本更新成功!"
			REMOVE_CACHE
			EXIT 0
		} || {
			ECHO r "无法移动 AutoUpdate 脚本到指定的路径!"
			EXIT 1
		}
	else
		ECHO r "AutoUpdate 脚本下载失败!"
		EXIT 1
	fi
}

function CHECK_DEPENDS() {
	TITLE
	local PKG
	printf "\n%-28s %-5s\n" 软件包 检测结果
	while [[ $1 ]];do
		if [[ $1 =~ : ]];then
			[[ $(echo $1 | cut -d ":" -f1) == ${TARGET_BOARD} ]] && {
				PKG="$(echo "$1" | cut -d ":" -f2)"
				printf "%-25s %-5s\n" ${PKG} $(CHECK_PKG ${PKG})
			}
		else
			printf "%-25s %-5s\n" $1 $(CHECK_PKG $1)
		fi
		shift
	done
	ECHO y "AutoUpdate 依赖检测结束,请尝试手动安装测结果为 [false] 的项目!"
}

function CHECK_TIME() {
	[[ -s $1 && -n $(find $1 -type f -mmin -$2) ]] && {
		echo true
		return 0
	} || {
		RM $1
		echo false
		return 1
	}
}

function ANALYZE_API() {
	local API_Cache=${Tmp_Path}/API_Cache
	if [[ $(CHECK_TIME ${API_File} 1) == false ]]
	then
		DOWNLOADER --path ${Tmp_Path} --file-name API_Cache --dl ${DOWNLOADERS} --url "$(URL_X ${Github_Release}/API G@@1 F@@1) ${Github_API}@@1 " --no-url-name --timeout 5 --type "API" --quiet
		[[ ! $? == 0 || -z $(cat ${API_Cache} 2> /dev/null) ]] && {
			ECHO r "Github API 请求错误,请检查网络后重试!"
			EXIT 2
		}
		RM ${API_File} && touch -a ${API_File}
		LOGGER "开始解析 Github API ..."
		for i in $(seq 0 500);do
			name=$(jsonfilter -i ${API_Cache} -e '@["assets"]' | jsonfilter -e '@['""$i""'].name' 2> /dev/null)
			[[ ! $? == 0 ]] && break
			if [[ ${name} =~ "AutoBuild-${OP_REPO}-${TARGET_PROFILE}" || ${name} =~ Update_Logs.json ]]
			then
				local format=$(echo ${name} | egrep -o "\-[0-9a-z]{5}.[a-z].+" | egrep -o "\..+" | cut -c2-10)
				local version=$(echo ${name} | egrep -o "R[0-9.]+-[0-9]+")
				local url=$(jsonfilter -i ${API_Cache} -e '@["assets"]' | jsonfilter -e '@['""$i""'].browser_download_url' 2> /dev/null)
				local size=$(jsonfilter -i ${API_Cache} -e '@["assets"]' | jsonfilter -e '@['""$i""'].size' 2> /dev/null | awk '{a=$1/1048576} {printf("%.2f\n",a)}')
				local date=$(jsonfilter -i ${API_Cache} -e '@["assets"]' | jsonfilter -e '@['""$i""'].updated_at' 2> /dev/null | sed 's/[-:TZ]//g')
				local count=$(jsonfilter -i ${API_Cache} -e '@["assets"]' | jsonfilter -e '@['""$i""'].download_count' 2> /dev/null)
				local sha256=$(echo ${name} | egrep -o "\-[a-z0-9]+" | cut -c2-6 | awk 'END{print}')
				[[ -z ${name} ]] && name="-"
				[[ -z ${format} ]] && format="-"
				[[ -z ${version} ]] && version="-"
				[[ -z ${url} ]] && url="-"
				[[ -z ${size} ]] && size="-" || size="${size}MB"
				[[ -z ${date} ]] && date="-"
				[[ -z ${count} ]] && count="-"
				[[ -z ${sha256} ]] && sha256="-"
				printf "%-75s %-15s %-5s %-8s %-20s %-10s %-15s %s\n" ${name} ${format} ${count} ${sha256} ${version} ${date} ${size} ${url} | egrep -v "${REGEX_Format}" >> ${API_File}
			fi
		done
		unset i
	fi
	[[ ! -s ${API_File} ]] && {
		ECHO r "Github API 解析内容为空,请稍候再试!"
		return 1
	} || return 0
}

function GET_CLOUD_LOG() {
	local Result Version
	[[ ! $(cat ${API_File} 2> /dev/null) =~ Update_Logs.json ]] && {
		LOGGER "未检测到已部署的云端日志!"
		return 1
	}
	case "$1" in
	[Ll]ocal)
		Version="${OP_VERSION}"
	;;
	[Cc]loud)
		Version="$(GET_FW_INFO 5)"
	;;
	-v)
		shift
		Version="$1"
	;;
	esac
	[[ $(CHECK_TIME ${Tmp_Path}/Update_Logs.json 1) == false ]] && {
		DOWNLOADER --path ${Tmp_Path} --file-name Update_Logs.json --dl ${DOWNLOADERS} --url "$(URL_X ${Github_Release} G@@1)" --timeout 5 --type 固件更新日志 --quiet
	}
	[[ -s ${Tmp_Path}/Update_Logs.json ]] && {
		Result="$(jsonfilter -i ${Tmp_Path}/Update_Logs.json -e '@["'""${TARGET_PROFILE}""'"]["'""${Version}""'"]' 2> /dev/null)"
		[[ -n ${Result} ]] && {
			echo -e "\n${Grey}${Version} 固件更新日志:"
			echo -e "\n${Green}${Result}${White}"
		} || LOGGER "未获取到当前固件的日志信息!"
	}
}

function GET_FW_INFO() {
	local Info Type Result
	[[ ! -s ${API_File} ]] && {
		LOGGER "[GET_FW_INFO] 未检测到 API 文件!"
		return 1
	}
	if [[ $1 == "-a" ]];then
		Info=$(grep "AutoBuild-${OP_REPO}-${TARGET_PROFILE}" ${API_File} | grep "${x86_Boot_Method}" | uniq)
		shift
	else
		Info=$(grep "AutoBuild-${OP_REPO}-${TARGET_PROFILE}" ${API_File} | grep "${x86_Boot_Method}" | awk 'BEGIN {MAX = 0} {if ($6+0 > MAX+0) {MAX=$6 ;content=$0} } END {print content}')
	fi
	Result="$(echo "${Info}" | awk '{print $"'${1}'"}' 2> /dev/null)"
	case $1 in
	1) Type="固件名称";;
	2) Type="固件格式";;
	3) Type="下载次数";;
	4) Type="校验信息";;
	5) Type="固件版本";;
	6) Type="发布日期";;
	7) Type="固件体积";;
	8) Type="固件链接";;
	*) Type="未定义信息";;
	esac
	[[ ! ${Result} == "-" ]] && {
		LOGGER "获取${Type}: ${Result}"
		echo -e "${Result}"
	} || {
		LOGGER "[GET_FW_INFO] ${Type}获取失败!"
		return 1
	}
}

function UPGRADE() {
	TITLE
	[[ $* =~ -f && $* =~ -F ]] && SHELL_HELP
	[[ $(NETWORK_CHECK 223.5.5.5 2) == false ]] && {
		ECHO r "网络连接错误,请稍后再试!"
		EXIT 1
	}
	Firmware_Path="${Tmp_Path}"
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
			ECHO g "固件保存路径: [${Firmware_Path} | $(SPACEINFO ${Firmware_Path})M]"
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
	if [[ -z ${Proxy_Type} ]];then
		[[ $(GOOGLE_CHECK) != true ]] && {
			ECHO r "Google 连接测试失败,优先使用镜像加速下载!"
			Proxy_Type="All"
		}
	else
		LOGGER "跳过 Google 连接测试 ..."
	fi
	ECHO "正在检查固件版本更新 ..."
	ANALYZE_API
	CLOUD_FW_Name=$(GET_FW_INFO 1)
	CLOUD_FW_Format=$(GET_FW_INFO 2)
	CLOUD_FW_Count=$(GET_FW_INFO 3)
	CLOUD_FW_SHA256=$(GET_FW_INFO 4)
	CLOUD_FW_Version=$(GET_FW_INFO 5)
	CLOUD_FW_Date=$(GET_FW_INFO 6)
	CLOUD_FW_Size=$(GET_FW_INFO 7)
	CLOUD_FW_Url=$(GET_FW_INFO 8)
	[[ -z ${CLOUD_FW_Name} || -z ${CLOUD_FW_Url} ]] && {
		ECHO r "云端固件信息获取失败!"
		EXIT 2
	}
	[[ ${CLOUD_FW_Version} == ${OP_VERSION} ]] && {
		CURRENT_Type="${Yellow} [已是最新]${White}"
		Upgrade_Stopped=1
	} || {
		[[ $(echo ${CLOUD_FW_Version} | cut -d "-" -f2) -gt $(echo ${OP_VERSION} | cut -d "-" -f2) ]] && CURRENT_Type="${Green} [可更新]${White}"
		[[ $(echo ${CLOUD_FW_Version} | cut -d "-" -f2) -lt $(echo ${OP_VERSION} | cut -d "-" -f2) ]] && {
			CHECKED_Type="${Red} [旧版本]${White}"
			Upgrade_Stopped=2
		}
	}
	cat <<EOF

设备名称: ${TARGET_PROFILE}
内核版本: $(uname -sr)
$([[ ${TARGET_BOARD} == x86 ]] && echo "固件格式: ${CLOUD_FW_Format} / ${x86_Boot_Method}" || echo "固件格式: ${CLOUD_FW_Format}")

$(echo -e "当前固件版本: ${OP_VERSION}${CURRENT_Type}")
$(echo -e "云端固件版本: ${CLOUD_FW_Version}${CHECKED_Type}")

云端固件名称: ${CLOUD_FW_Name}
云端固件体积: ${CLOUD_FW_Size}
固件下载次数: ${CLOUD_FW_Count}
EOF
	if [[ ${Force_Mode} != 1 ]]
	then
		if [[ $(MEMINFO 3) -lt $(echo ${CLOUD_FW_Size} | awk -F '.' '{print $1}') ]]
		then
			ECHO r "内存空间不足 [${CLOUD_FW_Size}],请尝试设置 Swap 交换分区或重启设备后再试!"
			EXIT
		fi
		if [[ $(SPACEINFO ${Firmware_Path}) -lt $(echo ${CLOUD_FW_Size} | awk -F '.' '{print $1}') ]]
		then
			ECHO r "设备空间不足 [${CLOUD_FW_Size}],请尝试更换固件保存路径后再试!"
			EXIT
		fi
	else
		LOGGER "[Force Mode] 跳过可用资源测试"
	fi
	GET_CLOUD_LOG -v ${CLOUD_FW_Version}
	case "${Upgrade_Stopped}" in
	1 | 2)
		[[ ${AutoUpdate_Mode} == 1 ]] && ECHO y "当前固件 [${OP_VERSION}] 已是最新版本,无需更新!" && EXIT 0
		[[ ${Upgrade_Stopped} == 1 ]] && err_MSG="当前固件 [${OP_VERSION}] 已是最新版本" || err_MSG="云端固件版本为旧版"
		[[ ! ${Force_Mode} == 1 ]] && {
			ECHO && read -p "${err_MSG},是否继续更新固件?[Y/n]:" Choose
		} || Choose=Y
		[[ ! ${Choose} =~ [Yy] ]] && {
			EXIT 0
		}
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
	DOWNLOADER --file-name ${CLOUD_FW_Name} --no-url-name --dl ${DOWNLOADERS} --url ${URL} --path ${Firmware_Path} --timeout 15 --type 固件
	[[ ! -s ${Firmware_Path}/${CLOUD_FW_Name} ]] && EXIT 1
	if [[ ! ${Skip_Verify} == 1 ]];then
		[[ $(GET_SHA256SUM ${Firmware_Path}/${CLOUD_FW_Name} 5) != ${CLOUD_FW_SHA256} ]] && {
			ECHO r "SHA256 校验失败,请检查网络后重试!"
			EXIT 2
		}
		LOGGER "固件 SHA256 比对通过!"
	else
		LOGGER "跳过 SHA256 校验 ..."
	fi
	case "${CLOUD_FW_Format}" in
	img.gz)
		if [[ ${Decompress_Mode} == 1 ]];then
			ECHO "正在解压 [${CLOUD_FW_Format}] 固件 ..."
			gzip -d -q -f -c ${Firmware_Path}/${CLOUD_FW_Name} > ${Firmware_Path}/$(echo ${CLOUD_FW_Name} | sed -r 's/(.*).gz/\1/')
			[[ ! $? == 0 ]] && {
				ECHO r "固件解压失败!"
				EXIT 2
			} || {
				CLOUD_FW_Name="$(echo ${CLOUD_FW_Name} | sed -r 's/(.*).gz/\1/')"
				LOGGER "固件解压成功,固件已解压到: [${Firmware_Path}/${CLOUD_FW_Name}]"
			}
		else
			[[ $(CHECK_PKG gzip) == true ]] && {
				LOGGER "卸载软件包 [gzip] ..."
				opkg remove gzip > /dev/null 2>&1
			}
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

function DO_UPGRADE() {
	ECHO r "警告: 固件更新期间请不要断开电源或进行其他操作!"
	sleep 3
	ECHO g "正在更新固件,请耐心等待 ..."
	$*
	if [[ $? != 0 ]]
	then
		ECHO r "固件更新失败,请尝试使用 [autoupdate -F] 指令更新固件!"
		EXIT 1
	else
		ECHO y "固件更新成功,即将重启设备 ..."
		sleep 3
		reboot
	fi
	EXIT
}

function DOWNLOADER() {
	local u E DL_Downloader DL_Name DL_URL DL_Path DL_Retries DL_Timeout DL_Type DL_Final Quiet_Mode No_URL_Name Print_Mode DL_Retires_All DL_URL_Final
	while [[ $1 ]];do
		case "$1" in
		--dl)
			shift
			while [[ $1 ]];do	
				case "$1" in
				*wget-ssl* | *curl | *uclient-fetch)
					[[ $(CHECK_PKG $1) == true ]] && {
						DL_Downloader="$1"
						break
					}
					shift
				;;
				*)
					LOGGER "[DOWNLOADER] 跳过未知下载器: [$1] ..."
					shift
				;;
				esac
			done
			while [[ $1 ]];do
				[[ $1 =~ '--' ]] && break
				[[ ! $1 =~ '--' ]] && shift
			done
			[[ -z ${DL_Downloader} ]] && {
				ECHO r "没有可用的下载器!"
				EXIT 1
			}
		;;
		--file-name)
			shift
			DL_Name="$1"
			while [[ $1 ]];do
				[[ $1 =~ '--' ]] && break
				[[ ! $1 =~ '--' ]] && shift
			done
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
			while [[ $1 ]];do
				[[ $1 =~ '--' ]] && break
				[[ ! $1 =~ '--' ]] && shift
			done
		;;
		--no-url-name)
			shift
			LOGGER "[DOWNLOADER] Enabled No-Url-Filename Mode"
			No_URL_Name=1
		;;
		--path)
			shift
			DL_Path="$1"
			if [[ ! -d ${DL_Path} ]];then
				mkdir -p ${DL_Path} 2> /dev/null || {
					ECHO r "目标下载路径 [${DL_Path}] 创建失败!"
					return 1
				}
			fi
			while [[ $1 ]];do
				[[ $1 =~ '--' ]] && break
				[[ ! $1 =~ '--' ]] && shift
			done
		;;
		--timeout)
			shift
			[[ ! $1 =~ [1-9] ]] && {
				LOGGER "[DOWNLOADER] [$1] 不是正确的数字!"
				shift
			} || {
				DL_Timeout="$1"
				while [[ $1 ]];do
					[[ $1 =~ '--' ]] && break
					[[ ! $1 =~ '--' ]] && shift
				done
			}
		;;
		--type)
			shift
			DL_Type="$1"
			while [[ $1 ]];do
				[[ $1 =~ '--' ]] && break
				[[ ! $1 =~ '--' ]] && shift
			done
		;;
		--quiet)
			shift
			Quiet_Mode=quiet
		;;
		--print)
			shift
			Print_Mode=1
			Quiet_Mode=quiet
		;;
		*)
			shift
		;;
		esac
	done
	case "${DL_Downloader}" in
	*wget*)
		DL_Template="$(command -v wget) --quiet --no-check-certificate -x -4 --tries 1 --timeout 10 -O"
	;;
	*curl)
		DL_Template="$(command -v curl) --silent --insecure -L -k --connect-timeout 10 --retry 1 -o"
	;;
	*uclient-fetch)
		DL_Template="$(command -v uclient-fetch) --quiet --no-check-certificate -4 --timeout 10 -O"
	;;
	esac
	[[ ${Test_Mode} == 1  || ${Verbose_Mode} == 1 ]] && {
		DL_Template="${DL_Template/ --quiet / }"
		DL_Template="${DL_Template/ --silent / }"
	}
	[[ -n ${DL_Timeout} ]] && DL_Template="${DL_Template/-timeout 10/-timeout ${DL_Timeout}}"
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
			[[ -s ${DL_Path}/${DL_Name} ]] && {
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

function REMOVE_CACHE() {
	rm -rf ${Tmp_Path}/API \
		/tmp/AutoUpdate.sh \
		${Tmp_Path}/Update_Logs.json \
		${Tmp_Path}/API_Cache 2> /dev/null
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
				EDIT_VARIABLE rm ${Custom_Variable} Log_Path
				EDIT_VARIABLE edit ${Custom_Variable} Log_Path $2
				[[ ! -d $2 ]] && mkdir -p $2
				[[ -s $2/AutoUpdate.log ]] && mv ${Log_Path}/AutoUpdate.log $2
				Log_Path="$2"
				ECHO y "AutoUpdate 日志保存路径已修改为: [$2]!"
				EXIT 0
			;;
			del | rm | clean)
				RM ${Log_Path}/AutoUpdate.log
				EXIT 0
			;;
			*)
				SHELL_HELP
			;;
			esac
		done
	}
}

URL_X() {
	# URL_X https://raw.githubusercontent.com/Hyy2001X/AutoBuild-Actions/master/Scripts/AutoUpdate.sh F@@1 G@@1 X@@1
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
		}
		unset URL_Final
		shift
	done
}

function NETWORK_CHECK() {
	ping $1 -c 1 -W $2 > /dev/null 2>&1
	[[ $? == 0 ]] && echo true || echo false
}

function GOOGLE_CHECK() {
	if [[ $(CHECK_PKG curl) == true ]]
	then
		local Result=$(curl -I -s --connect-timeout 3 google.com -w %{http_code} 2> /dev/null | tail -n1)
		LOGGER "Google 连接检查结果: [${Result}]"
		if [[ ${Result} == 301 ]]
		then
			echo true
			return 0
		else
			echo false
			return 1
		fi
	else
		return 1
	fi
}

function AutoUpdate_Main() {
	if [[ ! $1 =~ (-H|--help) ]];then
		[[ ! -f ${Default_Variable} ]] && {
			ECHO r "脚本运行环境检测失败,无法正常运行脚本!"
			EXIT 1
		}
		[[ ! -f ${Custom_Variable} ]] && touch ${Custom_Variable}
		LOAD_VARIABLE ${Default_Variable} ${Custom_Variable}
		[[ ! -d ${Tmp_Path} ]] && mkdir -p ${Tmp_Path}
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
			EXIT
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
						ECHO r "备份存放路径 [$1] 创建失败!"
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
			REMOVE_CACHE
			EXIT
		;;
		--check)
			shift
			CHECK_DEPENDS bash uclient-fetch curl wget openssl jsonfilter expr
			[[ $(NETWORK_CHECK www.baidu.com 2) == false ]] && {
				ECHO r "基础网络连接错误!"
			} || ECHO y "基础网络连接正常!"
			[[ $(GOOGLE_CHECK) == false ]] && {
				ECHO r "Google 连接错误!"
			} || ECHO y "Google 连接正常!"
			CHECK_ENV ${ENV_DEPENDS[@]}
			EXIT
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
			EXIT
		;;
		-V)
			shift
			[[ -z $* ]] && echo "${OP_VERSION}" && EXIT 0
			case "$1" in
			[Cc]loud)
				shift
				ANALYZE_API > /dev/null 2>&1
				GET_FW_INFO $* 5
			;;
			*)
				SHELL_HELP
			;;
			esac
			EXIT
		;;
		--fw-log)
			shift
			ANALYZE_API
			if [[ -z $* ]]
			then
				GET_CLOUD_LOG local
			else
				GET_CLOUD_LOG -v $*
			fi
			EXIT
		;;
		--list)
			shift
			SHOW_VARIABLE
			EXIT
		;;
		--var)
			local Result
			shift
			[[ $# != 1 ]] && SHELL_HELP
			Result="$(GET_VARIABLE $1 ${Custom_Variable})"
			[[ -z ${Result} ]] && Result="$(GET_VARIABLE $1 ${Default_Variable})"
			[[ -n ${Result} ]] && echo "${Result}"
			EXIT
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
			EXIT
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
			EXIT
		;;
		-B | --boot-mode)
			shift
			[[ ${TARGET_BOARD} != x86 ]] && EXIT 1
			CHANGE_BOOT $1
			EXIT
		;;
		-C)
			shift
			CHANGE_GITHUB $*
			EXIT
		;;
		--help)
			SHELL_HELP
			EXIT
		;;
		--log)
			shift
			LOG $*
			EXIT
		;;
		--fw-list)
			ANALYZE_API
			GET_FW_INFO -a 1
			EXIT
		;;
		*)
			SHELL_HELP
			EXIT
		;;
		esac
	done
}

KILL_PROCESS() {
	local i;for i in $(ps | grep -v grep | grep $1 | grep -v $$ | awk '{print $1}');do
		kill -9 ${i} 2> /dev/null &
	done
}

KILL_PROCESS AutoUpdate.sh

Tmp_Path=/tmp/AutoUpdate
Log_Path=/tmp
API_File=${Tmp_Path}/API
Default_Variable=/etc/AutoBuild/Default_Variable
Custom_Variable=/etc/AutoBuild/Custom_Variable
ENV_DEPENDS=(	
	Author
	Github
	TARGET_PROFILE
	TARGET_BOARD
	TARGET_SUBTARGET
	OP_VERSION
	OP_AUTHOR
	OP_BRANCH
	OP_REPO
)
DOWNLOADERS="$(command -v wget-ssl) $(command -v curl) $(command -v wget) $(command -v uclient-fetch)"
REGEX_Format=".vdi|.vhdx|.vmdk|kernel|rootfs|factory"

White="\e[0m"
Yellow="\e[33m"
Red="\e[31m"
Blue="\e[34m"
Grey="\e[36m"
Green="\e[32m"

[[ -n $* ]] && COMMAND="$0 $*" || COMMAND="$0"
AutoUpdate_Main $*
