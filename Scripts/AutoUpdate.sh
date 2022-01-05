#!/bin/bash
# AutoBuild Module by Hyy2001 <https://github.com/Hyy2001X/AutoBuild-Actions>
# AutoUpdate for Openwrt
# Dependences: wget-ssl/wget/uclient-fetch curl jq expr sysupgrade

Version=V6.8.5

function TITLE() {
	clear && echo "Openwrt-AutoUpdate Script by Hyy2001 ${Version}"
}

function SHELL_HELP() {
	TITLE
	cat <<EOF

使用方法:	bash $0 [-n] [-f] [-u] [-F] [-P] [-D <Downloader>] [--path <PATH>] ...
		bash $0 [-x] [--path <PATH>] [--url <URL>] ...

更新固件:
	-n			不保留配置更新固件 *
	-u			适用于定时更新 LUCI 的参数 *
	-f			跳过版本号校验,并强制刷写固件 (不推荐) *
	-F, --force-flash	强制刷写固件 *
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
	--api				打印 Github API 内容
	--flag <FLAG>			更改固件标签为提供的 <FLAG>
	--flag reset			恢复默认的固件标签
	--help				打印 AutoUpdate 帮助信息
	--log < | del>			<打印 | 删除> AutoUpdate 历史运行日志
	--log --path <PATH>		更改 AutoUpdate 运行日志路径为提供的绝对路径 <PATH>
	-P <F | G>			使用 <FastGit | Ghproxy> 镜像加速 *
	--backup --path <PATH>		备份当前系统配置文件到提供的绝对路径 <PATH> (可选)
	--env-list < | 1 | 2>		打印 <完整 | 第一列 | 第二列> 环境变量列表
	--chk				检查 AutoUpdate 运行环境
	--clean				清理 AutoUpdate 缓存
	--fw-log < | *>			打印 <当前 | 指定> 版本的固件更新日志
	--list				打印当前系统信息
	--var <VARIABLE>		打印用户指定的环境变量 <VARIABLE>
	--verbose			打印详细下载信息 *
	-v < | [Cc]loud>		打印 <当前 | 云端> AutoUpdate.sh 版本
	-V < | [Cc]loud>		打印 <当前 | 云端> 固件版本

脚本、固件更新问题反馈请到 ${Github} 反馈, 并上脚本运行日志与系统信息

EOF
	EXIT
}

function SHOW_VARIABLE() {
	TITLE
	cat <<EOF

设备名称:		$(uname -n) / ${TARGET_PROFILE}
固件版本:		${OP_VERSION}
固件标签:		${TARGET_FLAG}
内核版本:		$(uname -r)
运行内存:		Mem: $(MEMINFO Mem)M | Swap: $(MEMINFO Swap)M | Total: $(MEMINFO All)M
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
可用下载器:		${DL_DEPENDS[@]}
EOF
	[[ ${TARGET_BOARD} == x86 ]] && {
		echo "固件引导模式:		${x86_Boot_Method}"
	}
	echo
}

function MEMINFO() {
	[[ ! $1 || ! $* =~ (All|Mem|Swap) ]] && return 1
	local Mem Swap All Result
	Mem=$(free | grep Mem: | awk '{Mem=$7/1024} {printf("%.0f\n",Mem)}' 2> /dev/null)
	Swap=$(free | grep Swap: | awk '{Swap=$4/1024} {printf("%.0f\n",Swap)}' 2> /dev/null)
	All=$(expr ${Mem} + ${Swap} 2> /dev/null)
	Result=$(eval echo '$'$1)
	if [[ ${Result} ]]
	then
		LOGGER "可用 $1 运行内存: ${Result}M"
		echo ${Result}
		return 0
	else
		LOGGER "[$1] 可用 $1 运行内存获取失败!"
		return 1
	fi
}

function SPACEINFO() {
	[[ ! $1 ]] && return 1
	local Result Path
	Path="$(echo $1 | awk -F '/' '{print $2}')"
	Result="$(df -m /${Path} 2> /dev/null | grep -v Filesystem | awk '{print $4}')"
	if [[ ${Result} ]]
	then
		LOGGER "/${Path} 可用存储空间: ${Result}M"
		echo "${Result}"
		return 0
	else
		LOGGER "/${Path} 可用存储空间获取失败!"
		return 1
	fi
}

function RM() {
	[[ ! $* ]] && return 1
	rm -rf "$*" 2> /dev/null
	LOGGER "删除文件: [$1]"
	return 0
}

function STRING() {
	[[ $# -gt 3 ]] && return
	case $1 in
	-f)
		shift
		[[ ! -r $1 ]] && return
		egrep -q "$2" $1 2> /dev/null && echo -n $2
	;;
	*)
		echo -n $1 | egrep -q $2 2> /dev/null && echo -n $2
	;;
	esac
	return
}

function LIST_ENV() {
	local X
	cat ${Default_Variable} ${Custom_Variable} | grep -v '#' | while read X;do
		case $1 in
		1 | 2)
			[[ ${X} ]] && eval echo ${X} | awk -F '=' '{print $"'$1'"}'
		;;
		*)
			[[ ${X} ]] && eval echo ${X}
		;;
		esac
		
	done
}

function CHECK_ENV() {
	while [[ $1 ]];do
		if [[ $(GET_VARIABLE $1 ${Default_Variable} 2> /dev/null) ]]
		then
			return 0
		else
			ECHO r "检查环境变量 [$1] ... 错误"
			return 1
		fi
		shift
	done
}

function CHECK_PKG() {
	local Result="$(command -v $1 2> /dev/null)"
	if [[ ${Result} && $? == 0 ]]
	then
		echo true
		return 0
	else
		LOGGER "检查软件包: [$1] ... 错误"
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
	local Color
	[[ ! $1 ]] && {
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
			*)
				Message="$1"
				break
			;;
			esac
		done
		echo -e "\n${Grey}[$(date "+%H:%M:%S")]${White}${Color} ${Message}${White}"
		LOGGER "${Message}"
	}
}

function LOGGER() {
	[[ ! ${Log_Path} ]] && return
	if [[ ! $* =~ (--help|--log) ]]
	then
		[[ ! -d ${Log_Path} ]] && mkdir -p ${Log_Path}
		[[ ! -f ${Log_Path}/AutoUpdate.log ]] && touch ${Log_Path}/AutoUpdate.log
		echo "[$(date "+%H:%M:%S")] [$$] $*" >> ${Log_Path}/AutoUpdate.log
	fi
}

function RANDOM() {
	head -n 5 /dev/urandom | md5sum | cut -c 1-$1
}

function GET_SHA256SUM() {
	local Result="$(sha256sum $1 2> /dev/null | cut -c1-$2)"
	if [[ ${Result} && $? == 0 ]]
	then
		echo "${Result}"
		return 0
	else
		return 1
	fi
}

function GET_VARIABLE() {
	local Result="$(grep "$1=" "$2" 2> /dev/null | grep -v "#" | awk -F '=' '{print $2}')"
	if [[ ${Result} && $? == 0 ]]
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
		if [[ ! $(GET_VARIABLE $2 $1) ]]
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
		sed -i "/$2=/d" $1
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
	CHECK_DEPENDS -f ${PKG_DEPENDS[@]}
	for i in ${ENV_DEPENDS[@]};do
		local if_ENV="$(GET_VARIABLE ${i} $1)"
		if [[ ! ${if_ENV} ]]
		then
			ECHO r "警告: 未检测到环境变量: ${i}"
		fi
		eval ${i}="${if_ENV}" 2> /dev/null
	done
	shift && unset i if_ENV
	if [[ -s $1 ]]
	then
		chmod 777 $1
		source $1
	else
		LOGGER "警告: 未检测到环境变量列表: $1"
	fi
	
	[[ ! ${TARGET_PROFILE} ]] && eval TARGET_PROFILE="$(jq .model.id /etc/board.json 2> /dev/null)"
	[[ ! ${TARGET_PROFILE} || ${TARGET_PROFILE} == null ]] && ECHO r "当前设备名称获取失败!" && EXIT 1
	[[ ! ${OP_VERSION} ]] && OP_VERSION="未知"
	if [[ $(LIST_ENV 1) =~ TARGET_FLAG ]]
	then
		[[ -z ${TARGET_FLAG} ]] && TARGET_FLAG="Full"
	else
		unset TARGET_FLAG
	fi
	DISTRIB_TARGET="$(GET_VARIABLE DISTRIB_TARGET /etc/openwrt_release)"
	TARGET_BOARD="$(echo ${DISTRIB_TARGET} | cut -d '/' -f1)"
	TARGET_SUBTARGET="$(echo ${DISTRIB_TARGET} | cut -d '/' -f2)"
	Firmware_Author="${Github##*com/}"
	Github_Release="${Github}/releases/download/AutoUpdate"
	Github_Raw="https://raw.githubusercontent.com/${Firmware_Author}/master"
	Github_API="https://api.github.com/repos/${Firmware_Author}/releases/latest"
	case "${TARGET_BOARD}" in
	x86)
		[[ ! ${x86_Boot_Method} ]] && {
			[ -d /sys/firmware/efi ] && {
				x86_Boot_Method="UEFI"
			} || x86_Boot_Method="BIOS"
		}
	;;
	esac
	[[ ! -d ${Tmp_Path} ]] && mkdir -p ${Tmp_Path}
}

function CHANGE_GITHUB() {
	if [[ ! $1 =~ https://github.com/ || $# != 1 ]]
	then
		ECHO r "Github 地址格式错误,正确地址示例: https://github.com/Hyy2001X/AutoBuild-Actions"
		EXIT 1
	fi
	UCI_Github="$(uci get autoupdate.@autoupdate[0].github 2> /dev/null)"
	if [[ ${UCI_Github} && ! ${UCI_Github} == $1 ]]
	then
		uci set autoupdate.@autoupdate[0].github="$1" 2> /dev/null
		uci commit autoupdate
		LOGGER "UCI Github 地址已修改为 [$1]"
	fi
	if [[ ! ${Github} == $1 ]]
	then
		EDIT_VARIABLE edit ${Custom_Variable} Github $1
		if [[ $? == 0 ]]
		then
			ECHO y "Github 地址已修改为: $1"
		else
			ECHO y "Github 地址修改失败!"
		fi
		REMOVE_CACHE
	else
		ECHO g "Github 地址未修改!"
	fi
	EXIT
}

function CHANGE_BOOT() {
	case "$1" in
	UEFI | BIOS)
		EDIT_VARIABLE edit ${Custom_Variable} x86_Boot_Method $1
		ECHO r "警告: 修改此设置后更新固件后可能导致设备无法启动!"
		ECHO y "固件引导格式已修改为: $1"
		EXIT 0
	;;
	*)
		ECHO r "错误的参数: [$1],当前支持的选项: [UEFI/BIOS]"
		EXIT 1
	;;
	esac
}

function CHANGE_FLAG() {
	case $1 in
	reset)
		EDIT_VARIABLE rm ${Custom_Variable} TARGET_FLAG
		uci set autoupdate.@autoupdate[0].flag="$(GET_VARIABLE TARGET_FLAG ${Default_Variable})" 2> /dev/null
		uci commit autoupdate
		ECHO y "固件标签已恢复为默认!"
		ECHO y "当前固件标签: $(GET_VARIABLE TARGET_FLAG ${Default_Variable})"
		EXIT 0
	;;
	*)
		if [[ ! $1 =~ (\"|=|-|_|\.|\#|\|) && $1 =~ [a-zA-Z0-9] ]]
		then
			UCI_Flag="$(uci get autoupdate.@autoupdate[0].flag 2> /dev/null)"
			if [[ ${UCI_Flag} && ! ${UCI_Flag} == $1 ]]
			then
				uci set autoupdate.@autoupdate[0].flag="$1" 2> /dev/null
				uci commit autoupdate
				LOGGER "UCI 固件标签已修改为: $1"
			fi
			if [[ ! ${TARGET_FLAG} == $1 ]]
			then
				EDIT_VARIABLE edit ${Custom_Variable} TARGET_FLAG $1
				ECHO r "警告: 修改此设置后可能导致无法检测到更新!"
				ECHO y "固件标签已修改为: $1"
			else
				ECHO g "固件标签未修改!"
			fi
			EXIT 0
		else
			ECHO r "错误的参数: [$1], 当前仅支持 [a-zA-Z0-9] 且不能包含 <\" = - _ # |> 等特殊字符!"
			EXIT 1
		fi
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
	DOWNLOADER --file-name AutoUpdate.sh --no-url-name --dl ${DL_DEPENDS[@]} --url $2 --path ${Tmp_Path} --timeout 5 --type 脚本
	if [[ $? == 0 && -s ${Tmp_Path}/AutoUpdate.sh ]];then
		chmod +x ${Tmp_Path}/AutoUpdate.sh
		Script_Version="$(awk -F '=' '/Version/{print $2}' ${Tmp_Path}/AutoUpdate.sh | awk 'NR==1')"
		Banner_Version="$(egrep -o "V[0-9.]+" /etc/banner)"
		mv -f ${Tmp_Path}/AutoUpdate.sh $1 2> /dev/null
		[[ $? == 0 ]] && {
			[[ ${Banner_Version} && $1 == /bin ]] && sed -i "s?${Banner_Version}?${Script_Version}?g" /etc/banner
			ECHO y "[${Banner_Version} > ${Script_Version}] AutoUpdate.sh 更新成功!"
			REMOVE_CACHE
			EXIT 0
		} || {
			ECHO r "移动 AutoUpdate.sh 到指定路径时发生错误 ..."
			EXIT 1
		}
	else
		ECHO r "AutoUpdate.sh 下载失败!"
		EXIT 1
	fi
}

function CHECK_DEPENDS() {
	case $1 in
	-e)
		shift
		TITLE
		printf "\n%-28s %-5s\n" 软件包 检测结果
		while [[ $1 ]];do
			printf "%-25s %-5s\n" $1 $(CHECK_PKG $1)
			shift
		done
		ECHO y "AutoUpdate 运行环境检测结束,请尝试手动安装测结果为 [false] 的软件包!"
	;;
	-f)
		shift
		while [[ $1 ]];do
			CHECK_PKG $1 > /dev/null 2>&1
			if [[ $? != 0 ]]
			then
				ECHO r "未安装软件包: $1"
				EXIT 1
			fi
			shift
		done
	;;
	esac
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
	[[ ! ${Github_Release} ]] && {
		ECHO r "Github API 地址为空!"
		EXIT 1
	}
	local API_Cache=${Tmp_Path}/API_Cache
	if [[ $(CHECK_TIME ${API_File} 1) == false ]]
	then
		DOWNLOADER --path ${Tmp_Path} --file-name API_Cache --dl ${DL_DEPENDS[@]} --url "$(URL_X ${Github_Release}/API G@@1 F@@1) ${Github_API}@@1 " --no-url-name --timeout 5
		[[ ! $? == 0 || -z $(cat ${API_Cache} 2> /dev/null) ]] && {
			ECHO r "Github API 请求错误,请检查网络后再试!"
			EXIT 2
		}
	fi
	[[ -f ${API_File} ]] && RM ${API_File}
	touch -a ${API_File}
	LOGGER "开始解析 Github API ..."
	for i in $(seq 0 $(jq ".assets | length" ${API_Cache} 2> /dev/null));do
		eval name=$(jq ".assets[${i}].name" ${API_Cache} 2> /dev/null)
		[[ ${name} == null ]] && continue
		case ${name} in
		AutoBuild-${OP_REPO}-${TARGET_PROFILE}-* | Update_Logs.json)
			LOGGER "可用固件/日志: ${name}"
			eval format=$(echo ${name} | egrep -o "\-[0-9a-z]{5}.[a-z].+" | egrep -o "\..+" | cut -c2-10)
			eval version=$(echo ${name} | egrep -o "R[0-9.]+-[0-9]+")
			eval sha256=$(echo ${name} | egrep -o "\-[a-z0-9]+" | cut -c2-6 | awk 'END{print}')
			eval browser_download_url=$(jq ".assets[${i}].browser_download_url" ${API_Cache} 2> /dev/null)
			eval size=$(jq ".assets[${i}].size" ${API_Cache} 2> /dev/null | awk '{a=$1/1048576} {printf("%.2f\n",a)}')
			eval updated_at=$(jq ".assets[${i}].updated_at" ${API_Cache} 2> /dev/null | sed 's/[-:TZ]//g')
			eval download_count=$(jq ".assets[${i}].download_count" ${API_Cache} 2> /dev/null)
			[[ ! ${version} || ${version} == null ]] && version="-"
			[[ ! ${browser_download_url} || ${browser_download_url} == null ]] && continue
			[[ ! ${size} || ${size} == null || ${size} == 0 ]] && size="-" || size="${size}MB"
			[[ ! ${updated_at} || ${updated_at} == null ]] && updated_at="-"
			[[ ! ${download_count} || ${download_count} == null ]] && download_count="-"
			[[ ! ${sha256} || ${sha256} == null ]] && sha256="-"
			printf "%-75s %-15s %-5s %-8s %-20s %-10s %-15s %s\n" ${name} ${format} ${download_count} ${sha256} ${version} ${updated_at} ${size} ${browser_download_url} | egrep -v "${REGEX_Skip_Format}" >> ${API_File}
		;;
		esac
	done
	unset i
	if [[ ! $(cat ${API_File} 2> /dev/null) ]]
	then
		ECHO r "Github API 解析内容为空!"
		EXIT 1
	else
		LOGGER "Github API 解析成功!"
		return 0
	fi
}

function GET_FW_INFO() {
	local Info Type Result
	[[ ! -s ${API_File} ]] && {
		ECHO r "未检测到 API 文件!"
		EXIT 1
	}
	Info=$(grep "AutoBuild-${OP_REPO}-${TARGET_PROFILE}" ${API_File} | grep "${x86_Boot_Method}" | grep "${TARGET_FLAG}" | awk 'BEGIN {MAX = 0} {if ($6+0 > MAX+0) {MAX=$6 ;content=$0} } END {print content}')
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
		LOGGER "${Type}: ${Result}"
		echo -e "${Result}"
	} || {
		LOGGER "${Type}获取失败!"
		return 1
	}
}

function GET_CLOUD_LOG() {
	local Version log_Test
	[[ ! $(cat ${API_File} 2> /dev/null) =~ Update_Logs.json ]] && {
		LOGGER "未检测到已部署的云端日志,跳过下载 ..."
		return 1
	}
	case "$1" in
	[Ll]ocal)
		Version="${OP_VERSION}"
	;;
	[Cc]loud)
		Version="$(GET_FW_INFO 5)"
	;;
	*)
		Version="$1"
	;;
	esac
	[[ $(CHECK_TIME ${Tmp_Path}/Update_Logs.json 1) == false ]] && {
		DOWNLOADER --path ${Tmp_Path} --file-name Update_Logs.json --dl ${DL_DEPENDS[@]} --url "$(URL_X ${Github_Release} G@@1)" --timeout 5
	}
	[[ ! -s ${Tmp_Path}/Update_Logs.json ]] && return 1
	log_Test="$(jq '."'"${TARGET_PROFILE}"'"."'"${Version}"'"' ${Tmp_Path}/Update_Logs.json 2> /dev/null)"
	if [[ ${log_Test} && ${log_Test} != null ]]
	then
		echo -e "\n${Grey}${Version} 固件更新日志:${Green}\n"
		jq '."'"${TARGET_PROFILE}"'"."'"${Version}"'"' ${Tmp_Path}/Update_Logs.json 2> /dev/null | egrep -v "\[|\]"
		echo -e "${White}"
	else
		LOGGER "未获取到 [${Version}] 固件的日志信息!"
	fi
}

function UPGRADE() {
	TITLE
	[[ $* =~ -f && $* =~ -F ]] && SHELL_HELP
	[[ $(NETWORK_CHECK 223.5.5.5 2) == false ]] && {
		ECHO r "网络连接错误,请稍后再试!"
		EXIT 1
	}
	Firmware_Path="${Tmp_Path}"
	Upgrade_Option="$(command -v sysupgrade) -q"
	MSG="更新固件"
	while [[ $1 ]];do
		case "$1" in
		-T)
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
			DL_DEPENDS=($2)
			Special_Commands="${Special_Commands} [$1 ${DL_DEPENDS[@]}]"
			shift
		;;
		-F | --force-flash)
			Force_Flash=1
			Special_Commands="${Special_Commands} [强制刷写]"
		;;
		--decompress)
			Special_Commands="${Special_Commands} [优先解压固件]"
			Decompress_Mode=1
		;;
		-f)
			Force_Mode=1
			Force_Flash=1
			Special_Commands="${Special_Commands} [强制模式]"
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
			Skip_Verify_Mode=1
			Special_Commands="${Special_Commands} [跳过 SHA256 验证]"
		;;
		-u)
			Nobody_Mode=1
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
	[[ ${Force_Flash} == 1 ]] && Upgrade_Option="${Upgrade_Option} -F"
	[[ ${Special_Commands} ]] && ECHO g "特殊指令:${Special_Commands} | ${Upgrade_Option}"
	ECHO g "执行: ${MSG}${Special_MSG}"
	if [[ ! ${Proxy_Type} ]]
	then
		[[ $(GOOGLE_CHECK) != true ]] && {
			ECHO r "Google 连接错误,优先使用镜像加速下载!"
			Proxy_Type="All"
		}
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
	[[ ! ${CLOUD_FW_Name} || -z ${CLOUD_FW_Url} ]] && {
		ECHO r "检查更新失败,请检查网络后再试!"
		EXIT 2
	}
	[[ ${CLOUD_FW_Version} == ${OP_VERSION} ]] && {
		CURRENT_Type="${Yellow} [已是最新]${White}"
		Stop_Code=1
	} || {
		[[ $(echo ${CLOUD_FW_Version} | cut -d - -f2) -gt $(echo ${OP_VERSION} | cut -d - -f2) ]] && CHECKED_Type="${Green} [可更新]${White}"
		[[ $(echo ${CLOUD_FW_Version} | cut -d - -f2) -lt $(echo ${OP_VERSION} | cut -d - -f2) ]] && {
			CHECKED_Type="${Red} [旧版本]${White}"
			Stop_Code=2
		}
	}
	echo -e "
${Grey}### 系统 & 云端固件详情 ###${White}

设备名称: ${TARGET_PROFILE}
固件标签: ${TARGET_FLAG}
内核版本: $(uname -sr)
$([[ ${TARGET_BOARD} == x86 ]] && echo "固件格式: ${CLOUD_FW_Format} / ${x86_Boot_Method}" || echo "固件格式: ${CLOUD_FW_Format}")

$(echo -e "当前固件版本: ${OP_VERSION}${CURRENT_Type}")
$(echo -e "云端固件版本: ${CLOUD_FW_Version}${CHECKED_Type}")

云端固件名称: ${CLOUD_FW_Name}
云端固件体积: ${CLOUD_FW_Size}
固件下载次数: ${CLOUD_FW_Count}"
	if [[ ${Force_Mode} != 1 ]]
	then
		(sync && echo 3 > /proc/sys/vm/drop_caches) 2> /dev/null
		if [[ $(MEMINFO All) -lt $(echo ${CLOUD_FW_Size} | awk -F '.' '{print $1}') ]]
		then
			ECHO r "内存空间不足 [${CLOUD_FW_Size}],请尝试设置 Swap 交换分区或重启设备后再试!"
			EXIT
		fi
		if [[ $(SPACEINFO ${Firmware_Path}) -lt $(echo ${CLOUD_FW_Size} | awk -F '.' '{print $1}') ]]
		then
			ECHO r "设备空间不足 [${CLOUD_FW_Size}],请尝试更换固件保存路径后再试!"
			EXIT
		fi
	fi
	GET_CLOUD_LOG ${CLOUD_FW_Version}
	case "${Stop_Code}" in
	1 | 2)
		[[ ${Nobody_Mode} == 1 ]] && ECHO y "当前固件 [${OP_VERSION}] 已是最新版本,无需更新!" && EXIT 0
		[[ ${Stop_Code} == 1 ]] && err_MSG="当前固件 [${OP_VERSION}] 已是最新版本" || err_MSG="云端固件版本为旧版"
		[[ ! ${Force_Mode} == 1 ]] && {
			ECHO && read -p "${err_MSG},是否继续更新固件?[Y/n]:" Choose
		} || Choose=Y
		[[ ! ${Choose} =~ [Yy] ]] && {
			ECHO x "已取消固件更新操作,即将退出更新程序 ..."
			sleep 1
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
	DOWNLOADER --file-name ${CLOUD_FW_Name} --no-url-name --dl ${DL_DEPENDS[@]} --url ${URL} --path ${Firmware_Path} --timeout 15 --type 固件
	[[ ! -s ${Firmware_Path}/${CLOUD_FW_Name} || $? != 0 ]] && {
		ECHO r "固件下载失败,请检查网络后再试!"
		EXIT 1
	}
	if [[ ! ${Skip_Verify_Mode} == 1 ]];then
		[[ $(GET_SHA256SUM ${Firmware_Path}/${CLOUD_FW_Name} 5) != ${CLOUD_FW_SHA256} ]] && {
			ECHO r "SHA256 校验失败!"
			EXIT 2
		}
		ECHO y "固件完整性校验通过,即将开始更新固件 ..."
	fi
	case "${CLOUD_FW_Format}" in
	img.gz)
		if [[ ${Decompress_Mode} == 1 ]]
		then
			ECHO "正在解压 gizp 格式固件  ..."
			gzip -d -q -f -c ${Firmware_Path}/${CLOUD_FW_Name} > ${Firmware_Path}/$(echo ${CLOUD_FW_Name} | sed -r 's/(.*).gz/\1/')
			[[ ! $? == 0 ]] && {
				ECHO r "固件解压失败!"
				EXIT 2
			} || {
				CLOUD_FW_Name="$(echo ${CLOUD_FW_Name} | sed -r 's/(.*).gz/\1/')"
				LOGGER "固件已解压到: [${Firmware_Path}/${CLOUD_FW_Name}]"
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
	local u E DL_Downloader DL_Name DL_URL DL_Path DL_Retries DL_Timeout DL_Type DL_Final No_URL_Name Print_Mode DL_Retires_All DL_URL_Final
	while [[ $1 ]];do
		case "$1" in
		--dl)
			shift
			while [[ $1 ]];do	
				case "$1" in
				wget* | curl | uclient-fetch)
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
			[[ ! ${DL_Downloader} ]] && {
				ECHO r "没有可用的下载器!"
				return 1
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
			[[ ! ${DL_URL[*]} ]] && {
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
		--print)
			shift
			Print_Mode=1
		;;
		*)
			shift
		;;
		esac
	done
	case "${DL_Downloader}" in
	wget*)
		DL_Template="${DL_Downloader} --quiet --no-check-certificate -x -4 --tries 1 --timeout 10 -O"
	;;
	curl)
		DL_Template="${DL_Downloader} --silent --insecure -L -k --connect-timeout 10 --retry 1 -o"
	;;
	uclient-fetch)
		DL_Template="${DL_Downloader} --quiet --no-check-certificate -4 --timeout 10 -O"
	;;
	esac
	[[ ${Test_Mode} == 1  || ${Verbose_Mode} == 1 ]] && {
		DL_Template="${DL_Template/ --quiet / }"
		DL_Template="${DL_Template/ --silent / }"
	}
	[[ ${DL_Timeout} ]] && DL_Template="${DL_Template/-timeout 10/-timeout ${DL_Timeout}}"
	local E=0 u;while [[ ${E} != ${DL_URL_Count} ]];do
		DL_URL_Cache="${DL_URL[$E]}"
		DL_Retries="${DL_URL_Cache##*@@}"
		[[ ! ${DL_Retries} || ! ${DL_Retries} == [0-9] ]] && DL_Retries=1
		DL_URL_Final="${DL_URL_Cache%*@@*}"
		LOGGER "当前 URL: [${DL_URL_Final}] URL 重试次数: [${DL_Retries}]"
		for u in $(seq ${DL_Retries});do
			sleep 1
			[[ ! ${Failed} ]] && {
				[[ ${DL_Type} ]] && ECHO "正在下载${DL_Type},请耐心等待 ..."
			} || {
				[[ ${DL_Type} ]] && ECHO "尝试重新下载,剩余重试次数: [${DL_Retires_All}]"
			}
			if [[ ! ${DL_Name} ]];then
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
			LOGGER "执行下载指令: [${DL_Final}]"
			${DL_Final}
			if [[ $? == 0 && -s ${DL_Path}/${DL_Name} ]];then
				touch -a ${DL_Path}/${DL_Name}
				[[ ${Print_Mode} == 1 ]] && {
					cat ${DL_Path}/${DL_Name} 2> /dev/null
					RM ${DL_Path}/${DL_Name}
					return 0
				} || [[ ${DL_Type} ]] && ECHO y "${DL_Type}下载成功!"
				return 0
			else
				[[ ! ${Failed} ]] && local Failed=1
				DL_Retires_All=$((${DL_Retires_All} - 1))
				if [[ ${u} == ${DL_Retries} ]];then
					break 1
				else
					[[ ${DL_Type} ]] && ECHO r "${DL_Type}下载失败!"
					u=$((${u} + 1))
				fi
			fi
		done
		E=$((${E} + 1))
	done
	RM ${DL_Path}/${DL_Name}
	[[ ${DL_Type} ]] && ECHO r "${DL_Type}下载失败!"
	return 1
}

function REMOVE_CACHE() {
	rm -rf ${Tmp_Path}/API \
		/tmp/AutoUpdate.sh \
		${Tmp_Path}/Update_Logs.json \
		${Tmp_Path}/API_Cache 2> /dev/null
}

function LOG() {
	[[ ! $1 ]] && {
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
		[[ ${URL_Final} ]] && {
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
	if [[ ! $1 =~ (-H|--help|--chk|--log) ]];then
		LOAD_VARIABLE ${Default_Variable} ${Custom_Variable}
	fi

	[[ ! $* ]] && UPGRADE $*

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
			[[ ! ${Custom_Path} ]] && {
				ECHO r "请输入正确的路径!"
			}
		;;
		--url)
			Custom_URL="${Input[$((${E} + 1))]}"
			[[ ! ${Custom_URL} || ! ${Custom_URL} =~ (https://*|http://*|ftp://*) ]] && {
				ECHO r "链接格式错误,请输入正确的链接!"
				EXIT 1
			}
		;;
		-D)
			case "${Input[$((${E} + 1))]}" in
			wget* | curl | uclient-fetch)
				DL_DEPENDS=(${Input[$((${E} + 1))]})
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
		-n | -f | -u | -T | -P | --proxy | -F | --force-flash | --verbose | --decompress | --skip-verify | -D | --path)
			UPGRADE $*
			EXIT
		;;
		--api)
			REMOVE_CACHE
			ANALYZE_API > /dev/null 2>&1
			[[ $? == 0 ]] && cat ${API_File}
			EXIT
		;;
		--backup)
			local FILE="backup-$(uname -n)-$(date +%Y-%m-%d)-$(RANDOM 5).tar.gz"
			shift
			[[ $# -gt 1 ]] && SHELL_HELP
			[[ ! $1 ]] && {
				FILE="$(pwd)/${FILE}"
			} || {
				if [[ ! -d $1 ]];then
					mkdir -p $1 || {
						ECHO r "备份存放路径 [$1] 创建失败!"
						EXIT 1
					}
				fi
				FILE="$1/${FILE}"
			}
			ECHO "正在备份系统文件到 [${FILE}] ..."
			$(command -v sysupgrade) -b "${FILE}" > /dev/null 2>&1
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
		--chk)
			shift
			CHECK_DEPENDS -e ${PKG_DEPENDS[@]} ${DL_DEPENDS[@]}
			[[ $(NETWORK_CHECK www.baidu.com 2) == false ]] && {
				ECHO r "网络连接错误!"
			}
			[[ $(GOOGLE_CHECK) == false ]] && {
				ECHO r "Google 连接错误!"
			}
			CHECK_ENV ${ENV_DEPENDS[@]}
			EXIT
		;;
		--env-list)
			shift
			case "$1" in
			1 | 2)
				LIST_ENV $1
			;;
			*)
				LIST_ENV 0
			;;
			esac
			EXIT
		;;
		--flag)
			shift
			[[ -z $* || $# != 1 ]] && SHELL_HELP
			CHANGE_FLAG $1
			EXIT
		;;
		-V)
			shift
			[[ ! $* ]] && echo "${OP_VERSION}" && EXIT 0
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
			if [[ ! $* ]]
			then
				GET_CLOUD_LOG local
			else
				GET_CLOUD_LOG $*
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
			[[ ! ${Result} ]] && Result="$(GET_VARIABLE $1 ${Default_Variable})"
			[[ ${Result} ]] && echo "${Result}"
			EXIT
		;;
		-v)
			shift
			[[ ! $* ]] && echo ${Version} && EXIT 0
			case "$1" in
			[Cc]loud)
				Script_URL="$(URL_X ${Github_Raw}/Scripts/AutoUpdate.sh G@@1)"
				DOWNLOADER --dl ${DL_DEPENDS[@]} --url ${Script_URL} --path /tmp --print --type 脚本 | egrep -o "V[0-9].+"
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
			[[ ${Custom_Path} ]] && Script_Path="${Custom_Path}"
			[[ ${Custom_URL} ]] && Script_URL="${Custom_URL}"
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
			[[ -z $* || $# != 1 ]] && SHELL_HELP
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

Tmp_Path="/tmp/AutoUpdate"
Log_Path="/tmp"
API_File="${Tmp_Path}/API"
Default_Variable="/etc/AutoBuild/Default_Variable"
Custom_Variable="/etc/AutoBuild/Custom_Variable"
ENV_DEPENDS=(	
	Author
	Github
	TARGET_PROFILE
	TARGET_FLAG
	OP_VERSION
	OP_AUTHOR
	OP_BRANCH
	OP_REPO
)
PKG_DEPENDS=(
	jq
	expr
	sysupgrade
)
DL_DEPENDS=(
	wget-ssl
	curl
	wget
	uclient-fetch
)
REGEX_Skip_Format=".vdi|.vhdx|.vmdk|kernel|rootfs|factory"

White="\e[0m"
Yellow="\e[33m"
Red="\e[31m"
Blue="\e[34m"
Grey="\e[36m"
Green="\e[32m"

[[ $* ]] && COMMAND="$0 $*" || COMMAND="$0"
AutoUpdate_Main $*
