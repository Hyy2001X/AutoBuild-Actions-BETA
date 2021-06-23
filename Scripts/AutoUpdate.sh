#!/bin/bash
# AutoBuild Module by Hyy2001 <https://github.com/Hyy2001X/AutoBuild-Actions>
# AutoUpdate for Openwrt
# Depends on bash wget curl x86:gzip

TITLE() {
	clear && echo "Openwrt-AutoUpdate Script by Hyy2001 ${Version}"
}

SHELL_HELP() {
	TITLE
	cat <<EOF

使用方法:	$0 [<path=>] [-P] [-n] [-f] [-u]
		$0 [<更新脚本>] [-x/-x path=<>/-x url=<>]

更新固件:
	-n		更新固件 [不保留配置]
	-f		跳过版本号验证,并强制刷写固件 [保留配置]
	-u		适用于定时更新 LUCI 的参数 [保留配置]
	-? path=<>	更新固件 (保存固件到用户指定的目录)

更新脚本:
	-x		更新 AutoUpdate.sh 脚本
	-x path=<>	更新 AutoUpdate.sh 脚本 (保存脚本到用户指定的目录)
	-x url=<>	更新 AutoUpdate.sh 脚本 (使用用户提供的脚本地址更新)

其他参数:
	-F,--force		强制刷写固件 (可附加)
	-T,--test		测试模式 (可附加)
	-P,--proxy		强制使用 [FastGit] 加速 (可附加)
	-C <Github URL>		更改 Github 地址
	-B <UEFI | Legacy>	指定 x86_64 设备下载 <UEFI | Legacy> 引导的固件 (危险)
	-V <local | cloud>	打印 <当前 | 云端> AutoUpdate.sh 版本
	-X <local | cloud>	打印 <当前 | 云端> 版本固件更新日志
	-X <Version>		打印 <指定版本> 固件更新日志
	-H,--help		打印 AutoUpdate 帮助信息
	-L,--list		打印当前系统信息
	-U			仅检查版本更新
	--corn-rm		删除所有 AutoUpdate 定时任务
	--bak <Path> <Name>	备份 Openwrt 配置文件到用户指定的目录
	--clean			清理固件下载缓存
	--check			检查 AutoUpdate 依赖软件包
	--var <Variable>	打印用户指定的 <variable>
	--var-rm <Variable>	删除用户指定的 <variable>
	--log			打印 AutoUpdate 历史运行日志
	--log-path <Path>	更改 AutoUpdate 运行日志保存目录
	--random <Number>	打印一个随机数字与字母组合 (0-31)

EOF
	EXIT 1
}

SHOW_VARIABLE() {
	TITLE
	cat <<EOF

设备名称:		$(uname -n) / ${TARGET_PROFILE}
固件版本:		${CURRENT_Version}
固件作者:		${Author}
软件架构:		${TARGET_SUBTARGET}
作者仓库:		${Github}
OpenWrt 源码:		https://github.com/${Openwrt_Author}/${Openwrt_Repo_Name}:${Openwrt_Branch}	
Release API:		${Github_API}
固件格式-框架:		$(GET_VARIABLE AutoBuild_Firmware ${Default_Variable})
固件名称-框架:		$(GET_VARIABLE Egrep_Firmware ${Default_Variable})
固件格式:		${Firmware_Type}
Release URL:		${Github_Release_URL}
FastGit URL:		${Release_FastGit_URL}
Github Proxy URL:	${Release_Goproxy_URL}
固件保存位置:           ${FW_SAVE_PATH}
log 文件:		${log_Path}/AutoUpdate.log
EOF
	[[ ${TARGET_PROFILE} == x86_64 ]] && {
		echo "x86_64 引导模式:	${x86_64_Boot}"
	}
	EXIT 0
}

EXIT() {
	local RUN_TYPE
	case $1 in
	0)
		RUN_TYPE="[OK] "
	;;
	1)
		RUN_TYPE="[ERROR] "
	;;
	*)
		RUN_TYPE="[UNKNOWN] "
	;;
	esac
	echo "[$(date "+%Y-%m-%d-%H:%M:%S")] ${RUN_TYPE}AutoUpdate 运行结束 ..." >> ${log_Path}/AutoUpdate.log
	exit
}

TIME() {
	[[ ! -d ${log_Path} ]] && mkdir -p "${log_Path}"
	[[ ! -f ${log_Path}/AutoUpdate.log ]] && touch "${log_Path}/AutoUpdate.log"
	[[ -z $1 ]] && {
		echo -ne "\n${Grey}[$(date "+%H:%M:%S")]${White} "
	} || {
	case $1 in
		r) Color="${Red}";;
		g) Color="${Green}";;
		b) Color="${Blue}";;
		y) Color="${Yellow}";;
		x) Color="${Grey}";;
	esac
		[[ $# -lt 2 ]] && {
			echo -e "\n${Grey}[$(date "+%H:%M:%S")]${White} $1"
			echo "[$(date "+%Y-%m-%d-%H:%M:%S")] $1" >> ${log_Path}/AutoUpdate.log
		} || {
			echo -e "\n${Grey}[$(date "+%H:%M:%S")]${White} ${Color}$2${White}"
			echo "[$(date "+%Y-%m-%d-%H:%M:%S")] $2" >> ${log_Path}/AutoUpdate.log
		}
	}
}

CHECK_PKG() {
	which $1 > /dev/null 2>&1
	[[ $? == 0 ]] && echo true || echo false
}

RANDOM() {
	openssl rand -base64 $1 | md5sum | cut -c 1-$1
}

GET_VARIABLE() {
	[[ $# != 2 ]] && SHELL_HELP
	[[ ! -f $2 ]] && TIME "未检测到定义文件: [$2] !" && EXIT 1
	echo -e "$(grep "$1=" $2 | grep -v "#" | awk 'NR==1' | sed -r "s/$1=(.*)/\1/")"
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
	[[ -z ${TARGET_PROFILE} ]] && TIME r "获取设备名称失败,无法执行更新!" && EXIT 1
	[[ -z ${CURRENT_Version} ]] && CURRENT_Version=未知
	[[ -z ${FW_SAVE_PATH} ]] && FW_SAVE_PATH=/tmp/Downloads
	Github_Release_URL="${Github}/releases/download/AutoUpdate"
	FW_Author="${Github##*com/}"
	Github_API="https://api.github.com/repos/${FW_Author}/releases/latest"
	Release_URL="https://github.com/${FW_Author}/releases/download/AutoUpdate"
	Release_FastGit_URL="https://download.fastgit.org/${FW_Author}/releases/download/AutoUpdate"
	Release_Goproxy_URL="https://ghproxy.com/${Release_URL}"
	case ${TARGET_PROFILE} in
	x86_64)
		case ${Firmware_Type} in
		img.gz | img)
			[[ -z ${x86_64_Boot} ]] && {
				[ -d /sys/firmware/efi ] && {
					x86_64_Boot=UEFI
				} || x86_64_Boot=Legacy
			}
		;;
		*)
			TIME r "暂不支持当前固件格式!"
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
	[[ ! -f $1 ]] && TIME r "未检测到定义文件: [$1] !" && EXIT 1
	case "${Mode}" in
	edit)
    	[[ $# != 3 ]] && SHELL_HELP
		if [[ -z $(GET_VARIABLE $2 $1) ]];then
			echo -e "\n$2=$3" >> $1
		else
			sed -i "s?$(GET_VARIABLE $2 $1)?$3?g" $1
		fi
	;;
	rm)
		[[ $# != 2 ]] && SHELL_HELP
		sed -i "/$2/d" $1
	;;
	esac
}

CHANGE_GITHUB() {
	[[ ! $1 =~ https://github.com/ ]] && {
		TIME r "ERROR Github URL: $1"
		TIME r "错误的 Github 地址,示例: https://github.com/Hyy2001X/AutoBuild-Actions"
		EXIT 1
	}
	UCI_Github_URL=$(uci get autoupdate.@common[0].github 2>/dev/null)
	[[ -n ${UCI_Github_URL} && ! ${UCI_Github_URL} == $1 ]] && {
		uci set autoupdate.@common[0].github=$1
		uci commit autoupdate
		TIME y "UCI 设置已更新!"
	}
	[[ ! ${Github} == $1 ]] && {
		EDIT_VARIABLE edit ${Custom_Variable} Github $1
		TIME y "Github 地址已修改为: $1"
	} || {
		TIME y "当前输入的地址与原地址相同,无需修改!"
	}
	EXIT 0
}

CHANGE_BOOT() {
	[[ -z $1 ]] && SHELL_HELP
	case "$1" in
	UEFI | Legacy)
		EDIT_VARIABLE edit ${Custom_Variable} x86_64_Boot $1
		echo "ON" > /force_dump
		TIME r "警告: 更换引导方式后更新固件后可能导致设备无法正常启动!"
		TIME y "已创建临时文件 /force_dump"
		TIME y "固件引导格式已指定为: [$1],AutoUpdate 将在下一次更新时执行强制刷写固件!"
	;;
	*)
		TIME r "错误的参数: [$1],当前支持的选项: [UEFI/Legacy] !"
		EXIT 1
	;;
	esac
	EXIT 0
}

UPDATE_SCRIPT() {
	[[ $# != 2 ]] && SHELL_HELP
	TIME b "脚本保存目录: $1"
	TIME b "下载地址: $2"
	TIME "开始更新 AutoUpdate 脚本,请耐心等待..."
	[[ ! -d $1 ]] && mkdir -p $1
	wget -q --timeout 5 $2 -O /tmp/AutoUpdate.sh
	if [[ $? == 0 ]];then
		mv -f /tmp/AutoUpdate.sh $1
		[[ ! $? == 0 ]] && TIME r "AutoUpdate 脚本更新失败!" && EXIT 1
		chmod +x $1/AutoUpdate.sh
		NEW_Version=$(egrep -o "V[0-9].+" $1/AutoUpdate.sh | awk 'END{print}')
		Banner_Version=$(egrep -o "V[0-9]+.[0-9].+" /etc/banner)
		[[ -n ${Banner_Version} ]] && sed -i "s?${Banner_Version}?${NEW_Version}?g" /etc/banner
		TIME y "[${Version}] > [${NEW_Version}] AutoUpdate 脚本更新成功!"
		EXIT 0
	else
		TIME r "AutoUpdate 脚本更新失败,请检查网络后重试!"
		EXIT 1
	fi
}

CHECK_DEPENDS() {
	TITLE
	local PKG
	echo -e "\n软件包		状态"
	while [[ $1 ]];do
		if [[ $1 =~ : ]];then
			[[ $(echo $1 | cut -d ":" -f1) == ${TARGET_BOARD} ]] && {
				PKG="$(echo $1 | cut -d ":" -f2)"
				echo -e "${PKG}		$(CHECK_PKG ${PKG})"
			}
		else
			echo -e "$1		$(CHECK_PKG $1)"
		fi
		shift
	done
	TIME y "测试结束,若某项测试结果为 [false],请手动 [opkg install] 安装该软件包!"
	EXIT 0
}

FW_LOGGER() {
	local FW_Version
	case "$1" in
	local)
		FW_Version="${CURRENT_Version}"
	;;
	cloud)
		[[ -z ${CLOUD_Firmware_Version} ]] && GET_CLOUD_VERSION
		FW_Version="${CLOUD_Firmware_Version}"
	;;
	-v)
		shift
		FW_Version="$1"
	;;
	esac
	${Downloader} ${Release_URL}/Update_Logs.json -O ${Update_Logs_Path}/Update_Logs.json
	[[ $? == 0 ]] && {
		Update_Log=$(jsonfilter -e '@["'"""${TARGET_PROFILE}"""'"]["'"""${FW_Version}"""'"]' < ${Update_Logs_Path}/Update_Logs.json)
		rm -f ${Update_Logs_Path}/Update_Logs.json
	}
	case "$2" in
	show)
		if [[ -n ${Update_Log} ]];then
			echo -e "\n${Grey}${FW_Version} 更新日志:"
			echo -e "\n${Green}${Update_Log}${White}\n"
		else
			TIME r "未查询到版本: [${FW_Version}] 的日志信息!"
		fi
	;;
	esac
}

GET_CLOUD_VERSION() {
	[[ ! -d ${FW_SAVE_PATH} ]] && mkdir -p ${FW_SAVE_PATH}
	rm -f ${FW_SAVE_PATH}/Github_Tags
	${Downloader} ${Github_API} -O ${FW_SAVE_PATH}/Github_Tags
	[[ ! $? == 0 || ! -f ${FW_SAVE_PATH}/Github_Tags ]] && {
		[[ $1 == check ]] && echo "获取失败" > /tmp/Cloud_Version
		TIME r "检查更新失败,请稍后重试!"
		EXIT 1
	}
	eval X=$(GET_VARIABLE Egrep_Firmware ${Default_Variable})
	FW_Name=$(egrep -o "${X}" ${FW_SAVE_PATH}/Github_Tags | awk 'END {print}')
	[[ -z ${FW_Name} ]] && TIME "云端固件名称获取失败!" && EXIT 1
	CLOUD_Firmware_Version=$(echo ${FW_Name} | egrep -o "R[0-9].*20[0-9]+")
}

CHECK_UPDATES() {
	TIME "正在获取版本更新..."
	GET_CLOUD_VERSION
	[[ ${CLOUD_Firmware_Version} == ${CURRENT_Version} ]] && {
		CURRENT_Type="${Yellow} [已是最新]${White}"
		Upgrade_Stopped=1
	} || {
		[[ $(echo ${CLOUD_Firmware_Version} | cut -d "-" -f2) -gt $(echo ${CURRENT_Version} | cut -d "-" -f2) ]] && CURRENT_Type="${Green} [可更新]${White}"
		[[ $(echo ${CLOUD_Firmware_Version} | cut -d "-" -f2) -lt $(echo ${CURRENT_Version} | cut -d "-" -f2) ]] && {
			CLOUD_Type="${Red} [旧版本]${White}"
			Upgrade_Stopped=2
		}
	}
	SHA5BIT=$(echo ${FW_Name} | egrep -o "[a-zA-Z0-9]+.${Firmware_Type}" | sed -r "s/(.*).${Firmware_Type}/\1/")
	[[ $1 == check ]] && {
		echo -e "\n当前固件版本: ${CURRENT_Version}${CURRENT_Type}"
		echo -e "云端固件版本: ${CLOUD_Firmware_Version}${CLOUD_Type}"
		FW_LOGGER cloud show
		echo "${CLOUD_Firmware_Version} /${x86_64_Boot}${CURRENT_Type}" > /tmp/Cloud_Version
	} || FW_LOGGER cloud
}

PREPARE_UPGRADES() {
	TITLE
	while [[ $1 ]];do
		[[ $1 == -T || $1 == --test ]] && {
			Test_Mode=1
			TAIL_MSG=" [测试模式]"
		}
		[[ $1 == -P || $1 == --proxy ]] && {
			Proxy_Mode=1
			Proxy_Echo="[Proxy] "
		}
		[[ $1 =~ path= ]] && {
			[[ -z $(echo $1 | cut -d "=" -f2) ]] && TIME r "固件保存目录不能为空!" && EXIT 1
			FW_SAVE_PATH=$(echo $1 | cut -d "=" -f2)
			TIME g "自定义固件保存目录: ${FW_SAVE_PATH}"
		}
		[[ $1 == -F || $1 == --force ]] && Force_Write=1
		case "$1" in
		-n | -f | -u)
			Option="$1"
		;;
		esac
	shift
	done
	REMOVE_CACHE quiet ${FW_SAVE_PATH}
	Upgrade_Option="${Upgrade_Command} -q"
	case ${Option} in
	-n)
		Upgrade_Option="${Upgrade_Command} -q -n"
		MSG="更新固件 (不保留配置)"
	;;
	-f)
		Force_Mode=1
		Upgrade_Option="${Upgrade_Command} -q -F"
		MSG="强制更新固件 (保留配置)"
	;;
	-u)
		AutoUpdate_Mode=1
		MSG="LUCI 定时更新 (保留配置)"
	;;
	*)
		Upgrade_Option="${Upgrade_Command} -q"
		MSG="更新固件 (保留配置)"
	esac
	[ -f /force_dump ] && Force_Write=1
	[[ ${Force_Write} == 1 && ! ${Force_Mode} == 1 ]] && {
		MSG_2=" [强制刷写]"
		Upgrade_Option="${Upgrade_Option} -F"
	}
	[[ ${Test_Mode} == 1 ]] && Downloader="wget --no-check-certificate --timeout 5"
	TIME g "执行: ${Proxy_Echo}${MSG}${TAIL_MSG}${MSG_2}"
	if [[ $(CHECK_PKG curl) == true && ${Proxy_Mode} == 0 ]];then
		Google_Check=$(curl -I -s --connect-timeout 3 google.com -w %{http_code} | tail -n1)
		[[ ! ${Google_Check} == 301 ]] && {
			TIME r "Google 连接失败,尝试使用 [FastGit] 镜像加速!"
			Proxy_Mode=1
		}
	fi
	CHECK_UPDATES continue
	[[ -z ${CLOUD_Firmware_Version} ]] && {
		TIME r "云端固件信息获取失败!"
		EXIT 1
	}
	[[ ${Proxy_Mode} == 1 ]] && {
		FW_URL="${Release_FastGit_URL}"
	} || FW_URL="${Release_URL}"
	cat <<EOF

固件作者: ${FW_Author%/*}
设备名称: $(uname -n) / ${TARGET_PROFILE}
$([[ ${TARGET_PROFILE} == x86_64 ]] && echo "固件格式: ${Firmware_Type} / ${x86_64_Boot}" || echo "固件格式: ${Firmware_Type}")

$(echo -e "当前固件版本: ${CURRENT_Version}${CURRENT_Type}")
$(echo -e "云端固件版本: ${CLOUD_Firmware_Version}${CLOUD_Type}")

云端固件名称: ${FW_Name}
固件下载地址: ${FW_URL}
EOF
	if [[ -n ${Update_Log} ]];then
			echo -e "\n${Grey}${CLOUD_Firmware_Version} 更新日志:"
			echo -e "\n${Green}${Update_Log}${White}"
	fi
	case "${Upgrade_Stopped}" in
	1 | 2)
		[[ ${AutoUpdate_Mode} == 1 ]] && TIME y "已是最新版本,无需更新!" && EXIT 0
		[[ ${Upgrade_Stopped} == 1 ]] && MSG="已是最新版本" || MSG="云端固件版本为旧版"
		[[ ! ${Force_Mode} == 1 ]] && {
			TIME && read -p "${MSG},是否继续更新固件?[Y/n]:" Choose
		} || Choose=Y
		[[ ! ${Choose} =~ [Yy] ]] && EXIT 0
	;;
	esac
	Retry_Times=5
	TIME "${Proxy_Echo}正在下载固件,请耐心等待..."
	while [[ ${Retry_Times} -ge 0 ]];do
		if [[ ! ${PROXY_Mode} == 1 && ${Retry_Times} == 4 ]];then
			TIME g "尝试使用 [FastGit] 镜像加速下载固件!"
			FW_URL="${Release_FastGit_URL}"
		fi
		[[ ${Retry_Times} == 3 ]] && {
				TIME g "尝试使用 [Github Proxy] 镜像加速下载固件!"
				FW_URL="${Release_Goproxy_URL}"
		}
		[[ ${Retry_Times} == 2 ]] && FW_URL="${Github_Release_URL}"
		if [[ ${Retry_Times} == 0 ]];then
			TIME r "固件下载失败,请检查网络后重试!"
			EXIT 1
		else
			${Downloader} "${FW_URL}/${FW_Name}" -O ${FW_SAVE_PATH}/${FW_Name}
			[[ $? == 0 && -f ${FW_SAVE_PATH}/${FW_Name} ]] && TIME y "固件下载成功!" && break
		fi
		Retry_Times=$((${Retry_Times} - 1))
		TIME r "下载失败,剩余尝试次数: ${Retry_Times} 次"
	done
	case "${Firmware_Type}" in
	img.gz)
		gzip -d -q -f -c ${FW_SAVE_PATH}/${FW_Name} > ${FW_SAVE_PATH}/$(echo ${FW_Name} | sed -r 's/(.*).gz/\1/')
		FW_Name="$(echo ${FW_Name} | sed -r 's/(.*).gz/\1/')"
		[[ $? == 0 ]] && {
			TIME y "解压成功,固件已解压到: ${FW_SAVE_PATH}/${FW_Name}!"
		} || {
			TIME r "固件解压失败,请检查相关依赖或更换固件保存目录!"
			EXIT 1
		}
	;;
	esac
	[[ ! ${Test_Mode} == 1 ]] && {
		sleep 3
		chmod 777 ${FW_SAVE_PATH}/${FW_Name}
		DO_UPGRADE ${Upgrade_Option} ${FW_SAVE_PATH}/${FW_Name}
	} || {
		TIME x "[测试模式] 执行: ${Upgrade_Option} ${FW_SAVE_PATH}/${FW_Name}"
		TIME x "[测试模式] 测试模式运行完毕!"
		EXIT 0
	}
}

DO_UPGRADE() {
	TIME g "正在更新固件,更新期间请耐心等待..."
	sleep 3
	$*
	[[ $? -ne 0 ]] && {
		TIME r "固件刷写失败,请尝试手动更新固件!"
		EXIT 1
	} || EXIT 0
}

REMOVE_CACHE() {
	local RM_PATH
	[[ -z $2 ]] && RM_PATH=${FW_SAVE_PATH}
	rm -rf ${RM_PATH}/AutoBuild-${TARGET_PROFILE}-* \
		${RM_PATH}/Github_Tags
	case "$1" in
	quiet)
		:
	;;
	normal)
		TIME y "固件下载缓存清理完成!"
		EXIT 0
	;;
	esac
}


AutoUpdate_Main() {
	[[ ! -f ${Custom_Variable} ]] && touch ${Custom_Variable}
	LOAD_VARIABLE ${Default_Variable} ${Custom_Variable}

	[[ -z $* ]] && PREPARE_UPGRADES $*
	[[ $1 =~ path= && ! $* =~ -x && ! $* =~ -U ]] && PREPARE_UPGRADES $*

	while [[ $1 ]];do
		case "$1" in
		-V)
			shift
			case "$1" in
			local)
				[[ -n ${Version} ]] && echo "${Version}" || echo "未知"
			;;
			cloud)
				Cloud_Script_Version="$(wget -q --timeout 5 https://raw.fastgit.org/Hyy2001X/AutoBuild-Actions/master/Scripts/AutoUpdate.sh -O - | egrep -o "V[0-9].+")"
				[[ -n ${Cloud_Script_Version} ]] && echo "${Cloud_Script_Version}" || echo "未知"
			;;
			*)
			    SHELL_HELP
			esac
			EXIT 0
		;;
		--random)
			shift
			[[ $# != 1 || ! $1 =~ [0-9] || $1 == 0 || $1 -gt 30 ]] && SHELL_HELP || RANDOM $1
		;;
		--clean)
			REMOVE_CACHE normal $*
		;;
		--check)
		    shift && [[ -n $* ]] && SHELL_HELP
			CHECK_DEPENDS x86:gzip curl wget openssl
		;;
		-H | --help)
			SHELL_HELP
		;;
		-L | --list)
		    shift && [[ -n $* ]] && SHELL_HELP
			SHOW_VARIABLE
		;;
		-C)
		    shift
			CHANGE_GITHUB $1
		;;
		-B)
		    shift
			[[ ! ${TARGET_PROFILE} == x86_64 ]] && SHELL_HELP
			CHANGE_BOOT $1
		;;
		-x)
			while [[ $1 ]];do
				[[ $1 == -P || $1 == --proxy ]] && Proxy_Mode=1
				if [[ ${Proxy_Mode} == 1 && $1 =~ url= ]];then
					TIME r "参数冲突: [$0 $*],[-P,--proxy] 与 [url=] 不能同时存在!"
					EXIT 1
				fi
				if [[ ! $1 =~ url= ]];then
						Script_URL=https://raw.githubusercontent.com/Hyy2001X/AutoBuild-Actions/master/Scripts/AutoUpdate.sh
				else
					[[ $1 =~ url= ]] && {
					[[ -z $(echo $1 | cut -d "=" -f2) ]] && TIME r "脚本地址不能为空!" && EXIT 1
						Script_URL="$(echo $1 | cut -d "=" -f2)"
						TIME "使用自定义脚本地址: ${Script_URL}"
					}
				fi
				[[ $1 =~ path= ]] && {
					[ -z "$(echo $1 | cut -d "=" -f2)" ] && TIME r "保存路径不能为空!" && EXIT 1
					SH_SAVE_PATH="$(echo $1 | cut -d "=" -f2)"
				}
				shift
			done
			[[ ${Proxy_Mode} == 1 ]] && Script_URL=https://raw.fastgit.org/Hyy2001X/AutoBuild-Actions/master/Scripts/AutoUpdate.sh
			[[ -z ${SH_SAVE_PATH} ]] && SH_SAVE_PATH=/bin
			UPDATE_SCRIPT ${SH_SAVE_PATH} ${Script_URL}
		;;
		-n | -f | -u | -T | --test | -P | --proxy | -F | --force)
			PREPARE_UPGRADES $*
		;;
		--corn-rm)
			[ ! -f /etc/crontabs/root ] && EXIT 1
			shift && [[ -n $* ]] && SHELL_HELP
			[[ $(cat /etc/crontabs/root) =~ AutoUpdate ]] && {
			    sed -i '/AutoUpdate/d' /etc/crontabs/root >/dev/null 2>&1
			    TIME y "已删除所有 AutoUpdate 相关计划任务!"
		    	/etc/init.d/cron restart
			    EXIT 0
			} || EXIT 1
		;;
		-U)
		    shift && [[ -n $* ]] && SHELL_HELP
			CHECK_UPDATES check
			[ $? == 0 ] && EXIT 0 || EXIT 1
		;;
		-X)
			shift
			case $1 in
			local | cloud)
				FW_LOGGER $1 show
			;;
			*)
				[[ ! $1 =~ R ]] && SHELL_HELP || FW_LOGGER -v $1 show
			;;
			esac
		;;
		--var)
			shift
			[[ $# != 1 ]] && SHELL_HELP
			SHOW_VARIABLE=$(GET_VARIABLE "$1" ${Custom_Variable})
			[[ -z ${SHOW_VARIABLE} ]] && SHOW_VARIABLE=$(GET_VARIABLE "$1" ${Default_Variable})
			echo "${SHOW_VARIABLE}"
			[ $? == 0 ] && EXIT 0 || EXIT 1
		;;
		--var-rm)
			shift
			[[ $# != 1 ]] && SHELL_HELP
			EDIT_VARIABLE rm ${Custom_Variable} $1
			[ $? == 0 ] && EXIT 0 || EXIT 1
		;;
		--bak)
			shift
			[[ $# -lt 1 || $# -gt 2 ]] && TIME r "格式错误,示例: [bash $0 --bak /mnt/sda1 Openwrt_Backups.tar.gz]" && EXIT 1
			[[ $# == 2 ]] && {
				[[ ! -d $1 ]] && mkdir -p $1
				FILE="$1/$2"
				[[ -f ${FILE} ]] && FILE="${FILE}-$(RANDOM 5)"
			} || {
				[[ ! -d $1 ]] && mkdir -p $1
				FILE="$1/$(uname -n)-Backups-$(date +%Y-%m-%d)-$(RANDOM 5)"
			}
			[[ ! ${FILE} =~ tar.gz ]] && FILE="${FILE}.tar.gz"
			TIME "Saving config files to [${FILE}] ..."
			sysupgrade -b "${FILE}" >/dev/null 2>&1
			[ $? == 0 ] && {
				TIME y "系统文件备份成功!"
				TIME y "保存位置: ${FILE}"
				EXIT 0
			} || TIME r "备份文件创建失败,请尝试更换保存目录!"
			EXIT 1
		;;
		--log)
			shift
			[[ -z $1 ]] && {
				[[ -f ${log_Path}/AutoUpdate.log ]] && {
					TITLE && echo
					cat ${log_Path}/AutoUpdate.log
				}
			} || {
				while [[ $1 ]];do
					if [[ $1 =~ path= ]];then
						LOG_PATH="$(echo $1 | cut -d "=" -f2)"
						EDIT_VARIABLE rm ${Custom_Variable} log_Path
						EDIT_VARIABLE edit ${Custom_Variable} log_Path ${LOG_PATH}
						[[ ! -d ${LOG_PATH} ]] && mkdir -p ${LOG_PATH}
						TIME y "AutoUpdate 日志保存目录已修改为: ${LOG_PATH}"
						EXIT 0
					fi
					[[ $1 == rm || $1 == del ]] && {
						[[ -f ${log_Path}/AutoUpdate.log ]] && rm ${log_Path}/AutoUpdate.log
					}
					[[ ! $1 =~ path= && $1 != rm && $1 != del ]] && SHELL_HELP
					EXIT
				done
			}
		;;
		*)
			SHELL_HELP
		;;
		esac
		shift
	done
}

Version=V6.2.2
log_Path=/tmp
Update_Logs_Path=/tmp
Upgrade_Command=sysupgrade
Default_Variable=/etc/AutoBuild/Default_Variable
Custom_Variable=/etc/AutoBuild/Custom_Variable
Downloader="wget -q --no-check-certificate --timeout 5"

White="\e[0m"
Yellow="\e[33m"
Red="\e[31m"
Blue="\e[34m"
Grey="\e[36m"
Green="\e[32m"

AutoUpdate_Main $*