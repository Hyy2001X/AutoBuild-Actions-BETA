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

使用方法:	$0 [none] [<path=>] [-P] [-n] [-f] [-u]
		$0 [<更新脚本>] [-x/-x <path=>/-x <url=>]

更新固件:
	[none]		更新固件 [保留配置]
	-n		更新固件 [不保留配置]
	-f		强制更新固件,即跳过版本号验证,自动下载以及安装必要软件包 [保留配置]
	-u		适用于定时更新 LUCI 的参数 [保留配置]
	-? <path=>	更新固件 (保存固件到用户提供的目录)

设置参数:
	-C <Github URL>		更换 Github 地址
	-B <UEFI/Legacy>	指定 x86_64 设备下载 UEFI 或 Legacy 的固件 (危险)
	--corn <task=> <time>	设置定时任务
	--del-corn		删除所有 AutoUpdate 定时任务

更新脚本:
	-x		更新 AutoUpdate.sh 脚本
	-x <path=>	更新 AutoUpdate.sh 脚本 (保存脚本到用户提供的目录)
	-x <url=>	更新 AutoUpdate.sh 脚本 (使用用户提供的脚本地址更新)

其他参数:
	-P,--proxy	强制镜像加速
	-T,--test	测试模式 (仅运行流程,不更新固件)
	-H,--help	打印帮助信息
	-L,--list	打印系统信息
	-U		检查版本更新
	-U <path=>	检查版本更新并输出信息到指定文件
	--clean		清理固件下载缓存
	--check		检查 AutoUpdate 依赖
	--var <var>	打印定义
EOF
	exit 0
}

SHOW_VARIABLE() {
	TITLE
	cat <<EOF

设备名称:		$(uname -n) / ${TARGET_PROFILE}
固件作者:               ${Author}
默认设备:		${Default_Device}
软件架构:		${TARGET_SUBTARGET}
固件版本:		${CURRENT_Version}
作者仓库:		${Github}
源码仓库:		https://github.com/${Openwrt_Author}/${Openwrt_Repo_Name}:${Openwrt_Branch}	
Release API:		${Github_Tag_URL}
固件格式-框架:		$(GET_VARIABLE AutoBuild_Firmware= $1)
固件名称-框架:		$(GET_VARIABLE Egrep_Firmware= $1)
默认下载地址:		${Github_Release_URL}
默认保存位置:           ${FW_SAVE_PATH}
固件格式:		${Firmware_Type}
EOF
	[[ ${TARGET_PROFILE} == x86_64 ]] && {
		echo "引导模式:		${x86_64_Boot}"
	}
	exit 0
}

TIME() {
	[ ! -f /tmp/AutoUpdate.log ] && touch /tmp/AutoUpdate.log
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
			echo "[$(date "+%H:%M:%S")] $1" >> /tmp/AutoUpdate.log
		} || {
			echo -e "\n\e[36m[$(date "+%H:%M:%S")]\e[0m ${Color}$2\e[0m"
			echo "[$(date "+%H:%M:%S")] $2" >> /tmp/AutoUpdate.log
		}
	}
}

CHECK_PKG() {
	which $1 > /dev/null 2>&1
	[[ $? == 0 ]] && echo true || echo false
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
	[[ -z ${TARGET_PROFILE} ]] && TIME r "获取设备名称失败,无法执行更新!" && exit 1
	[[ -z ${CURRENT_Version} ]] && CURRENT_Version=未知
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
			exit 1
		;;
		esac
	;;
	*)
		[[ -z ${Firmware_Type} ]] && Firmware_Type=bin
	esac
}

EDIT_VARIABLE() {
	[[ $# != 3 ]] && TIME r "[EDIT_VARIABLE] 错误的函数输入: [$*]!" && exit 1
	[[ ! -f $1 ]] && TIME r "未检测到定义文件: [$1] !" && exit 1
	if [[ -z $(GET_VARIABLE ${2}= $1) ]];then
		echo -e "\n$2=$3" >> $1
	else
		sed -i "s?$(GET_VARIABLE ${2}= $1)?$3?g" $1
	fi
}

CHANGE_GITHUB() {
	[[ ! $1 =~ https://github.com/ ]] && {
		TIME y "错误的 Github 地址,示例: https://github.com/Hyy2001X/AutoBuild-Actions"
		exit 1
	}
	UCI_Github_URL=$(uci get autoupdate.@login[0].github 2>/dev/null)
	[[ -n ${UCI_Github_URL} && ! ${UCI_Github_URL} == $1 ]] && {
		uci set autoupdate.@login[0].github=$1
		uci commit autoupdate
		TIME y "UCI 设置已更新!"
	}
	[[ ! ${Github} == $1 ]] && {
		EDIT_VARIABLE /etc/AutoBuild/Custom_Variable Github $1
		TIME y "Github 地址已更换为: $1"
	} || {
		TIME y "当前输入的地址与原地址相同,无需修改!"
	}
	exit 0
}

CHANGE_BOOT() {
	[[ -z $1 ]] && SHELL_HELP
	case "$1" in
	UEFI | Legacy)
		EDIT_VARIABLE /etc/AutoBuild/Custom_Variable x86_64_Boot $1
		TIME y "新固件引导格式已指定为: $1"
	;;
	*)
		TIME r "错误的参数: [$1],当前支持的选项: [UEFI/Legacy] !"
		exit 1
	;;
	esac
	exit 0
}

GET_VARIABLE() {
	[[ $# != 2 ]] && TIME r "[GET_VARIABLE] 错误的函数输入: [$*]!" && exit 1
	[[ ! -f $2 ]] && TIME "未检测到定义文件: [$2] !" && exit 1
	echo -e "$(grep "$1" $2 | cut -c$(echo $1 | wc -c)-200)"
}

UPDATE_SCRIPT() {
	[[ $# != 2 ]] && TIME r "[UPDATE_SCRIPT] 错误的函数输入: [$*]!" && exit 1
	TIME b "脚本保存目录: $1"
	TIME b "下载地址: $2"
	TIME "开始更新 AutoUpdate 脚本,请耐心等待..."
	[ ! -d "$1" ] && mkdir -p $1
	wget -q --tries 3 --timeout 5 $2 -O /tmp/AutoUpdate.sh
	if [[ $? == 0 ]];then
		mv -f /tmp/AutoUpdate.sh $1
		[[ ! $? == 0 ]] && TIME r "AutoUpdate 脚本更新失败!" && exit 1
		chmod +x $1/AutoUpdate.sh
		NEW_Version=$(egrep -o "V[0-9].+" $1/AutoUpdate.sh | awk 'END{print}')
		Banner_Version=$(egrep -o "V[0-9]+.[0-9].+" /etc/banner)
		[[ -n "${Banner_Version}" ]] && sed -i "s?${Banner_Version}?${NEW_Version}?g" /etc/banner
		TIME y "[${Version}] > [${NEW_Version}] AutoUpdate 脚本更新成功!"
	else
		TIME r "AutoUpdate 脚本更新失败,请检查网络后重试!"
	fi
	exit
}

CHECK_DEPENDS() {
	TITLE
	local PKG
	echo -e "\n软件包		状态"
	for PKG in $(echo $*)
	do
		if [[ ${PKG} =~ : ]];then
			[[ $(echo ${PKG} | cut -d ":" -f1) == ${TARGET_BOARD} ]] && {
				PKG="$(echo ${PKG} | cut -d ":" -f2)"
				echo -e "${PKG}		$(CHECK_PKG ${PKG})"
			}
		else
			echo -e "${PKG}		$(CHECK_PKG ${PKG})"
		fi
	done
	TIME y "测试结束,若某项结果为 false,请手动安装该软件包!"
	exit 0
}

CHECK_UPDATES() {
	local Size X SAVE_PATH FILE_NAME Mode
	case $1 in
	1)
		Check_Mode=1
	;;
	0)
		Check_Mode=0
	;;
	esac
	shift
	TIME "正在获取版本更新..."
	SAVE_PATH=$(echo ${1%/*})
	FILE_NAME=$(echo ${1##*/})
	[ ! -d ${SAVE_PATH} ] && mkdir -p ${SAVE_PATH}
	wget -q --timeout 5 ${Github_Tag_URL} -O ${SAVE_PATH}/${FILE_NAME}
	[[ ! $? == 0 ]] && {
		echo "获取失败" > ${SAVE_PATH}/Cloud_Version
		TIME r "检查更新失败,请稍后重试!"
		exit 1
	}
	eval X=$(GET_VARIABLE Egrep_Firmware= /etc/AutoBuild/Default_Variable)
	FW_Name=$(egrep -o "${X}" ${SAVE_PATH}/${FILE_NAME} | awk 'END {print}')
	CLOUD_Firmware_Version=$(echo ${FW_Name} | egrep -o "R[0-9].*20[0-9]+")
	SHA5BIT=$(echo ${FW_Name} | egrep -o "[a-zA-Z0-9]+.${Firmware_Type}" | sed -r "s/(.*).${Firmware_Type}/\1/")
	let Size="$(grep -n "${FW_Name}" ${SAVE_PATH}/${FILE_NAME} | tail -1 | cut -d : -f 1)-4"
	let CLOUD_Firmware_Size="$(sed -n "${Size}p" ${SAVE_PATH}/${FILE_NAME} | egrep -o "[0-9]+" | awk '{print ($1)/1048576}' | awk -F. '{print $1}')+1"
	case "${Check_Mode}" in
	1)
		echo -e "\n当前固件版本: ${CURRENT_Version}\n$([[ ! ${CLOUD_Firmware_Version} == ${CURRENT_Version} ]] && echo "云端固件版本: ${CLOUD_Firmware_Version} [可更新]" || echo "云端固件版本: ${CLOUD_Firmware_Version} [无需更新]")\n"
		if [[ "${CURRENT_Version}" == "${CLOUD_Firmware_Version}" ]];then
			Checked_Type=" [已是最新]"
		else
			Checked_Type=" [可更新]"
		fi
		echo "${CLOUD_Firmware_Version} /${x86_64_Boot}${Checked_Type}" > ${SAVE_PATH}/Cloud_Version
	;;
	esac
}

PREPARE_UPGRADES() {
	TITLE
	local Z
	for Z in $(echo $*)
	do
		[[ ${Z} == -T || ${Z} == --test ]] && {
			Test_Mode=1
			TAIL_MSG=" [Test Mode]"
		}
		[[ ${Z} == -P || ${Z} == --proxy ]] && {
			Proxy_Mode=1
			Proxy_Echo="[FastGit] "
		} || {
			Proxy_Mode=0
			unset Proxy_Echo
		}
		[[ ${Z} =~ path= ]] && {
			[ -z "$(echo ${Z} | cut -d "=" -f2)" ] && TIME r "保存路径不能为空!" && exit 1
			FW_SAVE_PATH=$(echo ${Z} | cut -d "=" -f2)
			TIME g "使用自定义固件保存位置: ${FW_SAVE_PATH}"
		}
	done
	REMOVE_FW_CACHE quiet ${FW_SAVE_PATH}
	case $1 in
	-n)
		Upgrade_Option="${Upgrade_Command} -n"
		MSG="更新固件 (不保留配置)"
	;;
	-f)
		Force_Mode=1
		MSG="强制更新固件 (保留配置)"
	;;
	-u)
		AutoUpdate_Mode=1
		MSG="定时更新 (保留配置)"
	;;
	*)
		MSG="更新固件 (保留配置)"
		Upgrade_Option="${Upgrade_Command} -q"
	esac
	TIME g "执行: ${Proxy_Echo}${MSG}${TAIL_MSG}"
	if [[ $(CHECK_PKG curl) == true && ${Proxy_Mode} == 0 ]];then
		Google_Check=$(curl -I -s --connect-timeout 3 google.com -w %{http_code} | tail -n1)
		[[ ! ${Google_Check} == 301 ]] && {
			TIME r "Google 连接失败,尝试使用 [FastGit] 镜像加速!"
			Proxy_Mode=1
		}
	fi
	CHECK_UPDATES 0 ${FW_SAVE_PATH}/Github_Tags
	[[ -z ${CLOUD_Firmware_Version} ]] && {
		TIME r "云端固件信息获取失败!"
		exit 1
	}
	[[ ${Proxy_Mode} == 1 ]] && {
        FW_URL="${FW_Proxy_URL}"
	} || FW_URL="${FW_NoProxy_URL}"
	cat <<EOF

固件作者: ${FW_Author%/*}
设备名称: $(uname -n) / ${TARGET_PROFILE}
$([[ ${TARGET_PROFILE} == x86_64 ]] && echo "固件格式: ${Firmware_Type} / ${x86_64_Boot}" || echo "固件格式: ${Firmware_Type}")

当前固件版本: ${CURRENT_Version}
$([[ ! ${CLOUD_Firmware_Version} == ${CURRENT_Version} ]] && echo "云端固件版本: ${CLOUD_Firmware_Version} [可更新]" || echo "云端固件版本: ${CLOUD_Firmware_Version} [无需更新]")
云端固件体积: ${CLOUD_Firmware_Size}MB

云端固件名称: ${FW_Name}
固件下载地址: ${FW_URL}
EOF
	if [[ ${CURRENT_Version} == ${CLOUD_Firmware_Version} ]];then
		[[ ${AutoUpdate_Mode} == 1 ]] && {
			TIME y "已是最新版本,无需更新!"
			exit 0
		}
		[[ ! ${Force_Mode} == 1 ]] && {
			TIME && read -p "已是最新版本,是否重新刷写固件?[Y/n]:" Choose
		} || Choose=Y
		[[ ! ${Choose} =~ [Yy] ]] && exit 0
		TIME g "开始强制更新固件..."
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
			exit 1
		else
			wget -q --tries 3 --timeout 5 "${FW_URL}/${FW_Name}" -O ${FW_SAVE_PATH}/${FW_Name}
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
			exit 1
		}
	;;
	esac
	[[ ! ${Test_Mode} == 1 ]] && {
		sleep 3
		DO_UPGRADE ${Upgrade_Option} ${FW_SAVE_PATH}/${FW_Name} 
	} || {
		TIME b "[Test Mode] 执行: ${Upgrade_Option} ${FW_Name}"
		TIME b "[Test Mode] 测试模式运行完毕!"
		exit 0
	}
}

DO_UPGRADE() {
	TIME g "正在更新固件,更新期间请耐心等待..."
	sleep 1
	$*
	[[ $? -ne 0 ]] && {
		TIME r "固件刷写失败,请尝试手动更新固件!"
		exit 1
	} || exit 0
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
		exit 0
	;;
	esac
}

export Version=V6.0
export FW_SAVE_PATH=/tmp/Downloads
export Upgrade_Command=sysupgrade
[ ! -f /etc/AutoBuild/Custom_Variable ] && touch /etc/AutoBuild/Custom_Variable
LOAD_VARIABLE /etc/AutoBuild/Default_Variable /etc/AutoBuild/Custom_Variable

[[ -z $* ]] && PREPARE_UPGRADES $*
[[ $* =~ path= && ! $* =~ -x && ! $* =~ -U ]] && PREPARE_UPGRADES $*

while [[ $1 ]];do
	case "$1" in
	--clean)
		REMOVE_FW_CACHE normal $*
	;;
	--check)
		CHECK_DEPENDS curl wget x86:gzip
	;;
	-H | --help)
		SHELL_HELP
	;;
	-L | --list)
		SHOW_VARIABLE /etc/AutoBuild/Default_Variable
	;;
	-C)
		CHANGE_GITHUB $2
	;;
	-B)
		[[ ! ${TARGET_PROFILE} == x86_64 ]] && TIME r "该参数仅适用于 x86_64 设备!" && exit 1
		CHANGE_BOOT $2
	;;
	-x)
		while [[ $1 ]];do
			[[ $1 == -P || $1 == --proxy ]] && Proxy_Mode=1
			if [[ ${Proxy_Mode} == 1 && $1 =~ url= ]];then
				TIME r "参数冲突: [$0 $*],[-P,--proxy] 与 [url=] 不能同时存在!"
				exit 1
			fi
			if [[ ! $1 =~ url= ]];then
					Script_URL=https://raw.githubusercontent.com/Hyy2001X/AutoBuild-Actions/master/Scripts/AutoUpdate.sh
			else
				[[ $1 =~ url= ]] && {
				[[ -z $(echo $1 | cut -d "=" -f2) ]] && TIME r "脚本地址不能为空!" && exit 1
					Script_URL="$(echo $1 | cut -d "=" -f2)"
					TIME "使用自定义脚本地址: ${Script_URL}"
				}
			fi
			[[ $1 =~ path= ]] && {
				[ -z "$(echo $1 | cut -d "=" -f2)" ] && TIME r "保存路径不能为空!" && exit 1
				SH_SAVE_PATH="$(echo ${Z} | cut -d "=" -f2)"
			}
			shift
		done
		[[ ${Proxy_Mode} == 1 ]] && Script_URL=https://raw.fastgit.org/Hyy2001X/AutoBuild-Actions/master/Scripts/AutoUpdate.sh
		[[ -z ${SH_SAVE_PATH} ]] && SH_SAVE_PATH=/bin
		UPDATE_SCRIPT ${SH_SAVE_PATH} ${Script_URL}
	;;
	-n | -f | -u | -T | --test | -P)
		PREPARE_UPGRADES $*
	;;
	--corn)
		[[ $# != 3 ]] && SHELL_HELP
		shift
		while [[ $1 ]];do
			[[ $1 =~ task= ]] && Task="$(echo $1 | cut -d "=" -f2)"
			Time="$1"
			shift
		done
		[[ -z ${Task} || -z ${Time} ]] && SHELL_HELP
		echo -e "\n${Time} bash $0 $Task" >> /etc/crontabs/root
		/etc/init.d/cron restart
		TIME y "已设置计划任务: [${Time} bash $0 $Task]"
		exit 0
	;;
	--corn-del)
		[ ! -f /etc/crontabs/root ] && exit 1
		sed -i '/AutoUpdate/d' /etc/crontabs/root >/dev/null 2>&1
		TIME y "已删除所有 AutoUpdate 相关计划任务!"
		/etc/init.d/cron restart
		exit 0
	;;
	-U)
		shift
		[[ -z $1 ]] && CHECK_UPDATES 1 ${FW_SAVE_PATH}/Github_Tags && exit
		[[ $1 =~ path= ]] && {
			[ -z "$(echo $1 | cut -d "=" -f2)" ] && TIME r "保存路径不能为空!" && exit 1
			SAVE_PATH="$(echo $1 | cut -d "=" -f2)"
		}
		CHECK_UPDATES 1 ${SAVE_PATH}
		exit 1
	;;
	--var)
		shift
		[[ $# != 1 ]] && TIME r "格式错误,示例: [bash $0 --var Github]" && exit 1
		SHOW_VARIABLE=$(GET_VARIABLE "$1=" /etc/AutoBuild/Custom_Variable)
		[[ -z ${SHOW_VARIABLE} ]] && SHOW_VARIABLE=$(GET_VARIABLE "$1=" /etc/AutoBuild/Default_Variable)
		echo "${SHOW_VARIABLE}"
		exit
	;;
	*)
		SHELL_HELP
	;;
	esac
	shift
done