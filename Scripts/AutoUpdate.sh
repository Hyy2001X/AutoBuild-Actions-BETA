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
		$0 [<更新脚本>] [-x/-x <path=>/-x <url=>]

更新固件:
	-n		更新固件 [不保留配置]
	-f		跳过版本号验证,并强制刷写固件 [保留配置]
	-u		适用于定时更新 LUCI 的参数 [保留配置]
	-? <path=>	更新固件 (保存固件到用户指定的目录)

更新脚本:
	-x		更新 AutoUpdate.sh 脚本
	-x <path=>	更新 AutoUpdate.sh 脚本 (保存脚本到用户指定的目录)
	-x <url=>	更新 AutoUpdate.sh 脚本 (使用用户提供的脚本地址更新)

其他参数:
	-F,--force		强制刷写固件 (可附加)
	-T,--test		测试模式 (可附加)
	-P,--proxy		强制使用 [FastGit] 加速 (可附加)
	-C <Github URL>		更改 Github 地址
	-B <UEFI | Legacy>	指定 x86_64 设备下载 <UEFI | Legacy> 引导的固件 (危险)
	-V <local | cloud>	打印 <本地 | 云端> AutoUpdate 脚本版本
	-H,--help		打印 AutoUpdate 帮助信息
	-L,--list		打印当前系统信息
	-U			检查版本更新
	--corn-rm		删除所有 AutoUpdate 定时任务
	--bak <path> <name>	备份 Openwrt 配置文件到用户指定的目录
	--clean			清理固件下载缓存
	--check			检查 AutoUpdate 依赖软件包
	--var <variable>	打印用户指定的 <variable>
	--var-rm <variable>	删除用户指定的 <variable>
	--log			打印 AutoUpdate 历史运行日志
	--log-path <path>	更改 AutoUpdate 运行日志保存目录
	--random <number>	打印一个随机数字与字母组合 (0-31)

EOF
	EXIT 1
}

SHOW_VARIABLE() {
	TITLE
	cat <<EOF

设备名称:		$(uname -n) / ${TARGET_PROFILE}
固件作者:		${Author}
默认设备:		${Default_Device}
软件架构:		${TARGET_SUBTARGET}
固件版本:		${CURRENT_Version}
作者仓库:		${Github}
源码仓库:		https://github.com/${Openwrt_Author}/${Openwrt_Repo_Name}:${Openwrt_Branch}	
Release API:		${Github_Tag_URL}
固件格式-框架:		$(GET_VARIABLE AutoBuild_Firmware ${Default_Variable})
固件名称-框架:		$(GET_VARIABLE Egrep_Firmware ${Default_Variable})
默认下载地址:		${Github_Release_URL}
固件保存位置:           ${FW_SAVE_PATH}
固件格式:		${Firmware_Type}
log 文件:		${log_Path}/AutoUpdate.log
EOF
	[[ ${TARGET_PROFILE} == x86_64 ]] && {
		echo "引导模式:		${x86_64_Boot}"
	}
	EXIT 2
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
		echo -ne "\n\e[36m[$(date "+%H:%M:%S")]\e[0m "
	} || {
	case $1 in
		r) Color="\e[31m";;
		g) Color="\e[32m";;
		b) Color="\e[34m";;
		y) Color="\e[33m";;
		x) Color="\e[36m";;
	esac
		[[ $# -lt 2 ]] && {
			echo -e "\n\e[36m[$(date "+%H:%M:%S")]\e[0m $1"
			echo "[$(date "+%Y-%m-%d-%H:%M:%S")] $1" >> ${log_Path}/AutoUpdate.log
		} || {
			echo -e "\n\e[36m[$(date "+%H:%M:%S")]\e[0m ${Color}$2\e[0m"
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
	[[ -z ${TARGET_PROFILE} && -n ${Default_Device} ]] && TARGET_PROFILE="${Default_Device}"
	[[ -z ${TARGET_PROFILE} ]] && TARGET_PROFILE="$(jsonfilter -e '@.model.id' < /etc/board.json | tr ',' '_')"
	[[ -z ${TARGET_PROFILE} ]] && TIME r "获取设备名称失败,无法执行更新!" && EXIT 1
	[[ -z ${CURRENT_Version} ]] && CURRENT_Version=未知
	[[ -z ${FW_SAVE_PATH} ]] && FW_SAVE_PATH=/tmp/Downloads
	Github_Release_URL="${Github}/releases/download/AutoUpdate"
	FW_Author="${Github##*com/}"
	Github_Tag_URL="https://api.github.com/repos/${FW_Author}/releases/latest"
	Github_Proxy_URL="https://download.fastgit.org"
	FW_NoProxy_URL="https://github.com/${FW_Author}/releases/download/AutoUpdate"
	FW_Proxy_URL="${Github_Proxy_URL}/${FW_Author}/releases/download/AutoUpdate"
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
	wget -q --tries 3 --timeout 5 $2 -O /tmp/AutoUpdate.sh
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

CHECK_UPDATES() {
	local Size X
	TIME "正在获取版本更新..."
	[ ! -d ${FW_SAVE_PATH} ] && mkdir -p ${FW_SAVE_PATH}
	wget -q --timeout 5 ${Github_Tag_URL} -O ${FW_SAVE_PATH}/Github_Tags
	[[ ! $? == 0 || ! -f ${FW_SAVE_PATH}/Github_Tags ]] && {
		[[ $1 == check ]] && echo "获取失败" > /tmp/Cloud_Version
		TIME r "检查更新失败,请稍后重试!"
		EXIT 1
	}
	eval X=$(GET_VARIABLE Egrep_Firmware ${Default_Variable})
	FW_Name=$(egrep -o "${X}" ${FW_SAVE_PATH}/Github_Tags | awk 'END {print}')
	[[ -z ${FW_Name} ]] && TIME "云端固件名称获取失败!" && EXIT 1
	CLOUD_Firmware_Version=$(echo ${FW_Name} | egrep -o "R[0-9].*20[0-9]+")
	SHA5BIT=$(echo ${FW_Name} | egrep -o "[a-zA-Z0-9]+.${Firmware_Type}" | sed -r "s/(.*).${Firmware_Type}/\1/")
	let Size="$(grep -n "${FW_Name}" ${FW_SAVE_PATH}/Github_Tags | tail -1 | cut -d : -f 1)-4"
	let CLOUD_Firmware_Size="$(sed -n "${Size}p" ${FW_SAVE_PATH}/Github_Tags | egrep -o "[0-9]+" | awk '{print ($1)/1048576}' | awk -F. '{print $1}')+1"
	[[ $1 == check ]] && {
		echo -e "\n当前固件版本: ${CURRENT_Version}\n$([[ ! ${CLOUD_Firmware_Version} == ${CURRENT_Version} ]] && echo "云端固件版本: ${CLOUD_Firmware_Version} [可更新]" || echo "云端固件版本: ${CLOUD_Firmware_Version} [无需更新]")\n"
		if [[ "${CURRENT_Version}" == "${CLOUD_Firmware_Version}" ]];then
			Checked_Type=" [已是最新]"
		else
			Checked_Type=" [可更新]"
		fi
		echo "${CLOUD_Firmware_Version} /${x86_64_Boot}${Checked_Type}" > /tmp/Cloud_Version
	}
	rm ${FW_SAVE_PATH}/Github_Tags
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
			Proxy_Echo="[FastGit] "
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
	REMOVE_FW_CACHE quiet ${FW_SAVE_PATH}
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
	[[ ! $Test_Mode == 1 ]] && Wget_Head="wget -q" || Wget_Head="wget"
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
		FW_URL="${FW_Proxy_URL}"
	} || FW_URL="${FW_NoProxy_URL}"
	cat <<EOF

固件作者: ${FW_Author%/*}
设备名称: $(uname -n) / ${TARGET_PROFILE}
$([[ ${TARGET_PROFILE} == x86_64 ]] && echo "固件格式: ${Firmware_Type} / ${x86_64_Boot}" || echo "固件格式: ${Firmware_Type}")

当前固件版本: ${CURRENT_Version}
$([[ ! ${CLOUD_Firmware_Version} == ${CURRENT_Version} ]] && echo "云端固件版本: ${CLOUD_Firmware_Version} [可更新]" || echo "云端固件版本: ${CLOUD_Firmware_Version} [已是更新]")
云端固件体积: ${CLOUD_Firmware_Size}MB

云端固件名称: ${FW_Name}
固件下载地址: ${FW_URL}
EOF
	if [[ ${CURRENT_Version} == ${CLOUD_Firmware_Version} ]];then
		[[ ${AutoUpdate_Mode} == 1 ]] && {
			TIME y "已是最新版本,无需更新!"
			EXIT 0
		}
		[[ ! ${Force_Mode} == 1 ]] && {
			TIME && read -p "已是最新版本,是否继续更新固件?[Y/n]:" Choose
		} || Choose=Y
		[[ ! ${Choose} =~ [Yy] ]] && EXIT 0
	fi
	Retry_Times=5
	TIME "正在下载固件,请耐心等待..."
	while [[ ${Retry_Times} -ge 0 ]];do
		if [[ ! ${PROXY_Mode} == 1 ]];then
			[[ ${Retry_Times} == 4 ]] && {
				TIME g "尝试使用 [FastGit] 镜像加速下载固件!"
				FW_URL="${FW_Proxy_URL}"
			}
		fi
		[[ ${Retry_Times} == 2 ]] && {
				FW_URL="${FW_NoProxy_URL}"
		}
		if [[ ${Retry_Times} == 0 ]];then
			TIME r "固件下载失败,请检查网络后重试!"
			EXIT 1
		else
			${Wget_Head} --tries 3 --timeout 5 "${FW_URL}/${FW_Name}" -O ${FW_SAVE_PATH}/${FW_Name}
			[[ $? == 0 ]] && TIME y "固件下载成功!" && break
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

REMOVE_FW_CACHE() {
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
				Cloud_Script_Version="$(wget -q --tries 3 --timeout 5 https://raw.fastgit.org/Hyy2001X/AutoBuild-Actions/master/Scripts/AutoUpdate.sh -O - | egrep -o "V[0-9].+")"
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
			REMOVE_FW_CACHE normal $*
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
				FILE="$1/Openwrt-Backups-$(date +%Y-%m-%d)-$(RANDOM 5)"
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

export Version=V6.1.3
export log_Path=/tmp
export Upgrade_Command=sysupgrade
export Default_Variable=/etc/AutoBuild/Default_Variable
export Custom_Variable=/etc/AutoBuild/Custom_Variable

AutoUpdate_Main $*