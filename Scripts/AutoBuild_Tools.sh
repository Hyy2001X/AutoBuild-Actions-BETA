#!/bin/bash
# AutoBuild Module by Hyy2001 <https://github.com/Hyy2001X/AutoBuild-Actions>
# AutoBuild_Tools for Openwrt
# Dependences: bash wget curl block-mount e2fsprogs smartmontools

Version=V1.7.3

ECHO() {
	case $1 in
		r) Color="${Red}";;
		g) Color="${Green}";;
		b) Color="${Blue}";;
		y) Color="${Yellow}";;
		x) Color="${Grey}";;
	esac
	[[ $# -gt 1 ]] && shift
	echo -e "${White}${Color}${*}${White}"
}

AutoBuild_Tools() {
while :
do
	clear
	echo -e "$(cat /etc/banner)"
	echo -e "
AutoBuild 固件工具箱 ${Version}

1. USB 空间扩展
2. Samba 设置
3. 端口占用列表
4. 硬盘信息
5. 网络检查
6. 修复固件环境

${Grey}u. 固件更新
${Yellow}x. 更新脚本
${White}q. 退出
"
	read -p "请从上方选项中选择一个操作:" Choose
	case $Choose in
	q)
		rm -rf ${Tools_Cache}/*
		exit 0
	;;
	u)
		[ -s /bin/AutoUpdate.sh ] && {
			AutoUpdate_UI
		} || {
			ECHO r "\n未检测到 '/bin/AutoUpdate.sh',请确保当前固件支持一键更新!"
			sleep 2
		}
	;;
	x)
		wget -q ${Github_Raw}/Scripts/AutoBuild_Tools.sh -O ${Tools_Cache}/AutoBuild_Tools.sh
		if [[ $? == 0 && -s ${Tools_Cache}/AutoBuild_Tools.sh ]];then
			ECHO y "\n[AutoBuild_Tools] 脚本更新成功!"
			rm -f /bin/AutoBuild_Tools.sh.sh
			mv -f ${Tools_Cache}/AutoBuild_Tools.sh /bin
			chmod +x /bin/AutoBuild_Tools.sh
		else
			ECHO r "\n[AutoBuild_Tools] 脚本更新失败!"
		fi
		sleep 2
	;;
	1)
		[[ ! $(CHECK_PKG block) == true ]] && {
			ECHO r "\n缺少相应依赖包,请先安装 [block-mount] !"
			sleep 2
		} || AutoExpand_UI
	;;
	2)
		[[ ! $(CHECK_PKG block) == true ]] && {
			ECHO r "\n缺少相应依赖包,请先安装 [block-mount] !"
			sleep 2
		} || Samba_UI
	;;
	3)
		ECHO y "\nLoading Service&Port Configuration ..."
		Netstat1=${Tools_Cache}/Netstat1
		Netstat2=${Tools_Cache}/Netstat2
		ps_Info=${Tools_Cache}/ps_Info
		rm -f ${Netstat2} && touch ${Netstat2}
		netstat -ntupa | egrep ":::[0-9].+|0.0.0.0:[0-9]+|127.0.0.1:[0-9]+" | awk '{print $1" "$4" "$6" "$7}' | sed -r 's/0.0.0.0:/\1/;s/:::/\1/;s/127.0.0.1:/\1/;s/LISTEN/\1/' | sort | uniq > ${Netstat1}
		ps -w > ${ps_Info}
		local i=1;while :;do
			Proto=$(sed -n ${i}p ${Netstat1} | awk '{print $1}')
			[[ -z ${Proto} ]] && break
			Port=$(sed -n ${i}p ${Netstat1} | awk '{print $2}')
			_Service=$(sed -n ${i}p ${Netstat1} | awk '{print $3}')
			[[ ${_Service} == '-' ]] && {
				Service="Unknown"
			} || {
				Service=$(echo ${_Service} | cut -d '/' -f2)
				PID=$(echo ${_Service} | cut -d '/' -f1)
				Task=$(grep -v "grep" ${ps_Info} | grep "${PID}" | awk '{print $5}')
			}
			i=$(($i + 1))
			echo -e "${Proto} ${Port} ${Service} ${PID} ${Task}" | egrep "tcp|udp" >> ${Netstat2}
		done
		clear
		ECHO y "协议	   占用端口       服务名称        PID             进程信息"
		local X;while read X;do
			printf "%-10s %-14s %-15s %-15s %-10s\n" ${X}
		done < ${Netstat2}
		ENTER
	;;
	4)
		[[ ! $(CHECK_PKG smartctl) == true ]] && {
			ECHO r "\n缺少相应依赖包,请先安装 [smartmontools] !"
			sleep 2
		} || SmartInfo_UI
	;;
	5)
		if [[ $(CHECK_PKG curl) == true ]];then
			ping 223.5.5.5 -c 1 -W 2 > /dev/null 2>&1
			[[ $? == 0 ]] && {
				ECHO y "\n基础网络连接正常!"
			} || {
				ECHO r "\n基础网络连接错误!"
			}
			ping www.baidu.com -c 1 -W 2 > /dev/null 2>&1
			[[ $? == 0 ]] && {
				ECHO y "Baidu 连接正常!"
			} || {
				ECHO r "Baidu 连接错误!"
			}
			Google_Check=$(curl -I -s --connect-timeout 3 google.com -w %{http_code} | tail -n1)
			case ${Google_Check} in
			301)
				ECHO y "Google 连接正常!"
			;;
			*)
				ECHO r "Google 连接错误!"
			;;
			esac
		fi
		sleep 2
	;;
	6)
		cp -a /rom/etc/AutoBuild/Default_Variable /etc/AutoBuild
		cp -a /rom/etc/profile /etc
		cp -a /rom/etc/banner /etc
		cp -a /rom/bin/AutoUpdate.sh /bin
		cp -a /rom/bin/AutoBuild_Tools.sh /bin
		cp -a /rom/etc/config/autoupdate /etc/config
		ECHO y "\n固件环境修复完成!"
		sleep 2
	;;
	esac
done
}

AutoExpand_UI() {
	USB_Info
	[[ -s ${Block_Info} ]] && {
		clear
		ECHO x "USB 扩展内部空间\n"
		echo "设备         UUID				      格式	      挂载点	      可用空间"
		local X;while read X;do
			printf "%-12s %-40s %-15s %-15s %-10s\n" ${X}
		done < ${Disk_Processed_List}
		echo -e "\nq. 返回"
		echo "r. 重新载入列表"
	} || {
		ECHO r "\n未检测到任何外接设备!"
		sleep 2
		return 1
	}
	Logic_Disk_Count=$(sed -n '$=' ${Logic_Disk_List})
	echo ""
	read -p "请输入要操作的硬盘编号[1-${Logic_Disk_Count}]:" Choose
	case ${Choose} in
	q)
		return
	;;
	r)
		AutoExpand_UI
	;;
	*)
		[[ ${Choose} =~ [0-9] && ${Choose} -le ${Logic_Disk_Count} && ${Choose} -gt 0 ]] > /dev/null 2>&1 && {
			if [[ $(CHECK_PKG mkfs.ext4) == true ]];then
				Choose_Disk=$(sed -n ${Choose}p ${Disk_Processed_List} | awk '{print $1}')
				Choose_Mount=$(grep "${Choose_Disk}" ${Disk_Processed_List} | awk '{print $4}')
				AutoExpand_Core ${Choose_Disk} ${Choose_Mount}
			else
				ECHO r "\n系统缺少相应依赖包,请先安装 [e2fsprogs] !" && sleep 2
				return
			fi
		} || {
			ECHO r "\n输入错误,请输入正确的选项!"
			sleep 2 && AutoExpand_UI
		}
	;;
	esac
}

USB_Info() {
	Logic_Disk_List="${Tools_Cache}/Logic_Disk_List"
	Phy_Disk_List="${Tools_Cache}/Phy_Disk_List"
	Block_Info="${Tools_Cache}/Block_Info"
	Disk_Processed_List="${Tools_Cache}/Disk_Processed_List"
	echo -ne "\nLoading USB Configuration ..."
	rm -f ${Block_Info} ${Logic_Disk_List} ${Disk_Processed_List} ${Phy_Disk_List}
	touch ${Disk_Processed_List}
	block mount
	block info | grep -v "mtdblock" | grep "sd[a-z][0-9]" > ${Block_Info}
	[[ -s ${Block_Info} ]] && {
		cat ${Block_Info} | awk -F ':' '/sd/{print $1}' > ${Logic_Disk_List}
		for Disk_Name in $(cat ${Logic_Disk_List})
		do
			UUID=$(grep "${Disk_Name}" ${Block_Info} | egrep -o 'UUID=".+"' | awk -F '["]' '/UUID/{print $2}')
			Logic_Mount=$(grep "${Disk_Name}" ${Block_Info} | egrep -o 'MOUNT="/[0-9a-zA-Z].+"|MOUNT="/"' | awk -F '["]' '/MOUNT/{print $2}')
			[[ -z ${Logic_Mount} ]] && Logic_Mount="$(df | grep "${Disk_Name}" | awk '{print $6}' | awk 'NR==1')"
			Logic_Format="$(grep "${Disk_Name}" ${Block_Info} | egrep -o 'TYPE="[0-9a-zA-Z].+' | awk -F '["]' '/TYPE/{print $2}')"
			Logic_Available="$(df -h | grep "${Disk_Name}" | awk '{print $4}' | awk 'NR==1')"
			[[ -z ${Logic_Format} ]] && Logic_Format='-'
			[[ -z ${Logic_Mount} ]] && Logic_Mount='-'
			[[ -z ${Logic_Available} ]] && Logic_Available='-'
			echo "${Disk_Name}	${UUID}	${Logic_Format}	${Logic_Mount}	${Logic_Available}" >> ${Disk_Processed_List}
		done
		grep -o "/dev/sd[a-z]" ${Logic_Disk_List} | sort | uniq > ${Phy_Disk_List}
	}
	echo -ne "\r                             \r"
	return
}

AutoExpand_Core() {
	ECHO r "\n警告: 操作开始后请不要中断任务或进行其他操作,否则可能导致设备数据丢失!"
	ECHO r "同时连接多个 USB 设备可能导致分区错位路由器不能正常启动!"
	ECHO r "\n本操作将把设备 '$1' 格式化为 ext4 格式,请提前做好数据备份工作!"
	read -p "是否执行格式化操作?[Y/n]:" Choose
	[[ ${Choose} == [Yesyes] ]] && {
		ECHO y "\n开始运行脚本 ..."
		sleep 2
	} || return 0
	echo "禁用自动挂载 ..."
	uci set fstab.@global[0].auto_mount='0'
	uci commit fstab
	[[ ! $2 == '-' ]] && {
		echo "卸载设备 '$1' 位于 '$2' ..."
		umount -l $2 > /dev/null 2>&1
		[[ $? != 0 ]] && {
			ECHO r "设备 '$2' 卸载失败!"
			exit 1
		}
	}
	echo "正在格式化设备 '$1' 为 ext4 格式,请耐心等待 ..."
	mkfs.ext4 -F $1 > /dev/null 2>&1
	[[ $? == 0 ]] && {
		echo "设备 '$1' 已成功格式化为 ext4 格式!"
		USB_Info
	} || {
		ECHO r "设备 '$1' 格式化失败!"
		exit 1
	}
	UUID=$(grep "$1" ${Disk_Processed_List} | awk '{print $2}')
	echo "UUID: ${UUID}"
	echo "挂载设备 '$1' 到 ' /tmp/extroot' ..."
	mkdir -p /tmp/introot || {
		ECHO r "临时文件夹 '/tmp/introot' 创建失败!"
		exit 1
	}
	mkdir -p /tmp/extroot || {
		ECHO r "临时文件夹 '/tmp/extroot' 创建失败!"
		exit 1
	}
	mount --bind / /tmp/introot || {
		ECHO r "挂载 '/' 到 '/tmp/introot' 失败!"
		exit 1

	}
	mount $1 /tmp/extroot || {
		ECHO r "挂载 '$1' 到 '/tmp/extroot' 失败!"
		exit 1

	}
	echo "正在复制系统文件到 '$1' ..."
	tar -C /tmp/introot -cf - . | tar -C /tmp/extroot -xf -
	echo "卸载设备 '/tmp/introot' '/tmp/extroot' ..."
	umount /tmp/introot
	umount /tmp/extroot
	sync
	for ((i=0;i<=10;i++));do
		uci delete fstab.@mount[0] > /dev/null 2>&1
	done
	echo "写入新分区表到 '/etc/config/fstab' ..."
	cat >> /etc/config/fstab <<EOF
config mount
        option enabled '1'
        option uuid '${UUID}'
        option target '/'

EOF
	uci commit fstab
	ECHO y "\n运行结束,外接设备 '$1' 已挂载到系统分区!\n"
	ECHO r "警告: 固件更新将会导致扩容失效,当前硬盘数据将会丢失,请提前做好备份工作!\n"
	read -p "操作需要重启生效,是否立即重启?[Y/n]:" Choose
	[[ ${Choose} == [Yesyes] ]] && {
		ECHO g "\n正在重启设备,请耐心等待 ..."
		sync
		reboot
		exit
	} || exit
}

Samba_UI() {
	USB_Info
	Samba_tmp="${Tools_Cache}/AutoSamba"
	[[ ! -d ${Tools_Cache} ]] && mkdir -p "${Tools_Cache}"
	while :
	do
		autoshare_Mode="$(uci get samba.@samba[0].autoshare)"
		clear
		ECHO x "Samba 工具箱\n"
		echo "1. 自动生成 Samba 挂载点"
		echo "2. 删除所有 Samba 挂载点"
		echo "3. $([[ ${autoshare_Mode} == 1 ]] && echo 关闭 || echo 开启) Samba 自动共享"
		echo "4. 设置 Samba 访问密码 $([ -f /etc/samba/smbpasswd ] && echo -e "${Yellow}[已设置]${White}")"
		echo -e "\nq. 返回\n"
		read -p "请从上方选项中选择一个操作:" Choose
		case ${Choose} in
		1)
			Samba_UCI_List="${Tools_Cache}/UCI_List"
			Logic_Disk_Count=$(sed -n '$=' ${Disk_Processed_List})
			echo
			for ((i=1;i<=${Logic_Disk_Count};i++));
			do
				Disk_Name=$(sed -n ${i}p ${Disk_Processed_List} | awk '{print $1}')
				Disk_Mounted_Point=$(sed -n ${i}p ${Disk_Processed_List} | awk '{print $4}')
				Samba_Name=${Disk_Mounted_Point#*/mnt/}
				Samba_Name=$(echo ${Samba_Name} | cut -d "/" -f2-5)
				uci show 2>&1 | grep "sambashare" > ${Samba_UCI_List}
				if [[ ! $(cat ${Samba_UCI_List}) =~ ${Disk_Mounted_Point} ]] > /dev/null 2>&1 ;then
					ECHO g "设置挂载点 '${Samba_Name}' ..."
					cat >> /etc/config/samba <<EOF

config sambashare
	option auto '1'
	option name '${Samba_Name}'
	option device '${Disk_Name}'
	option path '${Disk_Mounted_Point}'
	option read_only 'no'
	option guest_ok 'yes'
	option create_mask '0666'
	option dir_mask '0777'
EOF
				else
					ECHO y "'${Disk_Mounted_Point}' 挂载点已存在!"
				fi
			done
			uci commit samba
			/etc/init.d/samba restart
			sleep 2
		;;
		2)
			while :
			do
				Samba_config="$(grep "sambashare" /etc/config/samba | wc -l)"
				[[ ${Samba_config} -eq 0 ]] && break
				uci delete samba.@sambashare[0]
				uci commit samba > /dev/null 2>&1
			done
			ECHO y "\n已删除所有 Samba 挂载点!"
		;;
		3)
			[[ ${autoshare_Mode} == 0 ]] && {
				uci set samba.@samba[0].autoshare='1'
				autosamba_mode="开启"
			} || {
				uci set samba.@samba[0].autoshare='0'
				autosamba_mode="关闭"
			}
			ECHO y "\n已${autosamba_mode} Samba 自动共享!"
			uci commit samba
		;;
		4)
			sed -i '/invalid users/d' /etc/samba/smb.conf.template >/dev/null 2>&1
			ECHO y "\n注意: 请连续输入两次密码,输入的密码不会显示!"
			smbpasswd -a root
			[[ $? == 0 ]] && {
				ECHO y "\nSamba 访问密码设置成功!"
				/etc/init.d/samba restart
			} || {
				ECHO r "\nSamba 访问密码设置失败!"
			}
		;;
		q)
			break
		;;
		esac
		sleep 2
	done
}

AutoUpdate_UI() {
while :
do
	AutoUpdate_Version=$(awk 'NR==6' /bin/AutoUpdate.sh | awk -F '[="]+' '/Version/{print $2}')
	clear
	echo -e "$(cat /etc/banner)"
	echo -e "AutoBuild 固件更新/AutoUpdate ${AutoUpdate_Version}\n
${Yellow}1. 更新固件 [保留配置]
${White}2. 更新固件 (强制刷入固件) [保留配置]
3. 不保留配置更新固件 [全新安装]
4. 列出固件信息
5. 清除固件下载缓存
6. 更改 Github API 地址
7. 指定 x86 设备下载 <UEFI | Legacy> 引导的固件
8. 打印运行日志 (反馈问题)
9. 检查运行环境
10. 备份系统配置

${Yellow}x. 更新 [AutoUpdate] 脚本
${White}q. 返回\n"
	read -p "请从上方选择一个操作:" Choose
	case ${Choose} in
	q)
		break
	;;
	x)
		wget -q ${Github_Raw}/Scripts/AutoUpdate.sh -O ${Tools_Cache}/AutoUpdate.sh
		if [[ $? == 0 && -s ${Tools_Cache}/AutoUpdate.sh ]];then
			ECHO y "\n[AutoUpdate] 脚本更新成功!"
			rm -f /bin/AutoUpdate.sh
			mv -f ${Tools_Cache}/AutoUpdate.sh /bin
			chmod +x /bin/AutoBuild_Tools.sh
		else
			ECHO r "\n[AutoUpdate] 脚本更新失败!"
		fi
	;;
	1)
		bash /bin/AutoUpdate.sh
	;;
	2)
		bash /bin/AutoUpdate.sh -F
	;;
	3)
		bash /bin/AutoUpdate.sh -n
	;;
	4)
		bash /bin/AutoUpdate.sh --list
	;;
	5)
		ECHO y "\n下载缓存清理完成!"
		bash /bin/AutoUpdate.sh --clean
	;;
	6)
		echo ""
		read -p "请输入新的 Github 地址:" Github_URL
		[[ -n ${Github_URL} ]] && bash /bin/AutoUpdate.sh -C ${Github_URL} || {
			ECHO r "\nGithub 地址不能为空!"
		}
	;;
	7)
		echo ""
		read -p "请输入你想要的启动方式[UEFI/Legacy]:" _BOOT
		[[ -n ${_BOOT} ]] && bash /bin/AutoUpdate.sh -B ${_BOOT} || {
			ECHO r "\n启动方式不能为空!"
		}
	;;
	8)
		bash /bin/AutoUpdate.sh -L
	;;
	9)
		bash /bin/AutoUpdate.sh --check
	;;
	10)
		echo ""
		read -p "请输入配置保存路径(回车即为当前路径):" BAK_PATH
		bash /bin/AutoUpdate.sh --backup ${BAK_PATH}
	;;
	esac
	ENTER
done
}

SmartInfo_UI() {
	USB_Info
	clear
	smartctl -v | awk 'NR==1'
	cat ${Phy_Disk_List} | while read Phy_Disk;do
		SmartInfo_Core ${Phy_Disk}
	done
	ENTER
}

SmartInfo_Core() {
	Smart_Info1="${Tools_Cache}/Smart_Info1"
	Smart_Info2="${Tools_Cache}/Smart_Info2"
	smartctl -H -A -i $1 > ${Smart_Info1}
	smartctl -H -A -i -d scsi $1 > ${Smart_Info2}
	if [[ ! $(smartctl -H $1) =~ Unknown ]];then
		[[ $(smartctl -H $1) =~ PASSED ]] && Phy_Health=PASSED || Phy_Health=Failure
	else
		Phy_Health=$(GET_INFO "SMART Health Status:" ${Smart_Info2})
	fi
	Phy_Name=$(GET_INFO "Device Model:" ${Smart_Info1})
	Phy_ID=$(GET_INFO "Serial number:" ${Smart_Info2})
	Phy_Capacity=$(GET_INFO "User Capacity:" ${Smart_Info2})
	Phy_Part_Number=$(grep -c "${Phy_Disk}" ${Disk_Processed_List})
	Phy_Factor=$(GET_INFO "Form Factor:" ${Smart_Info2})
	[[ -z ${Phy_Factor} ]] && Phy_Factor="不可用"
	Phy_Sata_Version=$(GET_INFO "SATA Version is:" ${Smart_Info1})
	[[ -z ${Phy_Sata_Version} ]] && Phy_Sata_Version="不可用"
	TRIM_Command=$(GET_INFO "TRIM Command:" ${Smart_Info1})
	[[ -z ${TRIM_Command} ]] && TRIM_Command=不可用
	Power_On=$(grep "Power_On" ${Smart_Info1} | awk '{print $NF}')
	Power_Cycle_Count=$(grep "Power_Cycle_Count" ${Smart_Info1} | awk '{print $NF}')
	[[ -z ${Power_On} ]] && {
		Power_Status=未知
	} || {
		Power_Status="${Power_On} 小时 / ${Power_Cycle_Count} 次"
	}
	if [[ $(GET_INFO "Rotation Rate:" ${Smart_Info2}) =~ "Solid State" ]];then
		Phy_Type="固态硬盘"
		Phy_RPM="不可用"
	else
		Phy_Type="其他硬盘"
		if [[ $(GET_INFO "Rotation Rate:" ${Smart_Info2}) =~ rpm ]];then
			Phy_RPM=$(GET_INFO "Rotation Rate:" ${Smart_Info2})
			Phy_Type="机械硬盘"
		else
			Phy_RPM="不可用"
		fi
	fi
	[[ -z ${Phy_Name} ]] && {
		Phy_Name=$(GET_INFO Vendor: ${Smart_Info2})$(GET_INFO Product: ${Smart_Info2})
	}
	Phy_LB=$(GET_INFO "Logical block size:" ${Smart_Info2})
	Phy_PB=$(GET_INFO "Physical block size:" ${Smart_Info2})
	if [[ -n ${Phy_PB} ]];then
		Phy_BS="${Phy_LB} / ${Phy_PB}"
	else
		Phy_BS="${Phy_LB}"
	fi
	cat <<EOF

	硬盘型号: ${Phy_Name}
	硬盘尺寸: ${Phy_Factor}
	硬盘 ID : ${Phy_ID}
	硬盘容量: ${Phy_Capacity}
	健康状况: ${Phy_Health}
	分区数量: ${Phy_Part_Number}
	SATA 版本: ${Phy_Sata_Version}
	TRIM 指令: ${TRIM_Command}
	硬盘类型: ${Phy_Type}
	硬盘转速: ${Phy_RPM}
	扇区大小: ${Phy_BS}
	通电情况: ${Power_Status}

========================================================

EOF
}

GET_INFO() {
	grep "$1" $2 | sed "s/^[$1]*//g" 2> /dev/null | sed 's/^[ \t]*//g' 2> /dev/null
}

CHECK_PKG() {
	which $1 > /dev/null 2>&1
	[[ $? == 0 ]] && echo "true" || echo "false"
}

ENTER() {
	echo -e "${Green}"
	read -p "按下 [回车] 键以继续操作 ..." Key
	echo -e "${White}"
}

White="\e[0m"
Yellow="\e[33m"
Red="\e[31m"
Blue="\e[34m"
Grey="\e[36m"
Green="\e[32m"

Tools_Cache="/tmp/AutoBuild_Tools"
[[ ! -d ${Tools_Cache} ]] && mkdir -p "${Tools_Cache}"
Github_Raw="https://ghproxy.com/https://raw.githubusercontent.com/Hyy2001X/AutoBuild-Actions/master"
AutoBuild_Tools