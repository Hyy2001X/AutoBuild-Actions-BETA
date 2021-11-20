# OpenWrt-Actions & One-key AutoUpdate

![GitHub Stars](https://img.shields.io/github/stars/Hyy2001X/AutoBuild-Actions.svg?style=flat-square&label=Stars&logo=github)
![GitHub Forks](https://img.shields.io/github/forks/Hyy2001X/AutoBuild-Actions.svg?style=flat-square&label=Forks&logo=github)

AutoBuild-Actions 稳定版仓库地址: [AutoBuild-Actions-Template](https://github.com/Hyy2001X/AutoBuild-Actions-Template)

自用修改版软件包地址: [AutoBuild-Packages](https://github.com/Hyy2001X/AutoBuild-Packages)

支持的 OpenWrt 源码: `coolsnowwolf/lede`、`immortalwrt/immortalwrt`、`openwrt/openwrt`、`lienol/openwrt`

## 维护设备列表

| 机型 | 配置文件 | 拥有设备 |
| :----: | :----: | :----: |
| x86_64 | x86_64 | ✅ |
| 新路由3 | d-team_newifi-d2 | ✅ |
| 华硕 acrh17 | asus_rt-acrh17 | ❎ |
| 竞斗云 2.0 | p2w_r619ac-128m | ❎ |
| 红米 AC2100 | xiaomi_redmi-router-ac2100 | ✅ |
| 小娱C1/3/5 | xiaoyu_xy-c5 | ❎ |

## 一、定制固件(可选)

   🎈 **提示**: 文中的 **TARGET_PROFILE** 为要编译的设备名称, 例如: `d-team_newifi-d2`、`asus_rt-acrh17`

   从本地获取: 在源码目录执行`egrep -o "CONFIG_TARGET.*DEVICE.*=y" .config | sed -r 's/.*DEVICE_(.*)=y/\1/'`
   
   或执行`grep 'TARGET_PROFILE' .config`, 请先执行`make menuconfig`进行配置

1. 进入你的`AutoBuild-Actions`仓库, **下方所有操作都将在你的`AutoBuild-Actions`仓库下进行**

   建议使用`Github Desktop`和`Notepad++`进行操作 [[Github Desktop](https://desktop.github.com/)] [[Notepad++](https://notepad-plus-plus.org/downloads/)]

2. 编辑`/Configs`目录下的配置文件, 若配置文件不存在则需要在本地生成`.config`重命名并上传

3. 编辑`/.github/workflows/某设备.yml`文件, 修改`第 7 行`为随便的名称

4. 编辑`/.github/workflows/某设备.yml`文件, 修改`第 32 行`为上传的`.config`配置文件名称

5. 按照需求且编辑`/Scripts/AutoBuild_DiyScript.sh`文件即可, `/Scripts`下的其他文件无需修改

**/Scripts/AutoBuild_DiyScript.sh: Firmware_Diy_Core() 函数中的变量解释:**
```
   Author 作者名称, AUTO: [自动识别]
   
   Author_URL 自定义作者网站或域名, 将写入到内核信息, 例如 AUTO: [自动识别]; "https://www.baidu.com"

   Banner_Message 终端中显示的额外信息

   Default_IP 固件初始 IP 地址

   Short_Firmware_Date 简短的固件日期, 例如 true: [20210601]; false: [202106012359]

   Checkout_Virtual_Images 额外上传已检测到的 x86 虚拟磁盘镜像
   
   Firmware_Format 自定义固件格式, 例如 "bin img.gz tar.gz"; AUTO: [自动识别]

   REGEX_Skip_Checkout 输出固件时丢弃包含该内容的文件 [正则表达式]

   INCLUDE_AutoBuild_Features 自动添加 AutoBuild 固件特性, 例如 一键更新固件; 固件工具箱

   INCLUDE_DRM_I915 自动启用 x86 设备的 Intel Graphics 显卡驱动

   INCLUDE_Original_OpenWrt_Compatible 完善原生 OpenWrt 支持, 例如 true: [自动识别]; 19.07; 21.02
   
   注: 禁用某功能请将变量值修改为 false, 开启则为 true

```

## 二、编译固件(必选)

   **手动编译** 点击上方`Actions`, 在左栏选择要编译的设备,点击右方`Run workflow`再点击`绿色按钮`即可开始编译

   **一键编译** 删除`第 29-30 行`的注释并保存, 触发点亮右上角的 **Star** 按钮即可一键编译

   **定时编译** 删除`第 26-27 行`的注释, 然后按需修改时间并提交修改 [Corn 使用方法](https://www.runoob.com/w3cnote/linux-crontab-tasks.html)

   **临时修改固件 IP 地址** 该功能仅在**手动编译**生效, 点击`Run workflow`后即可输入 IP 地址
   
   **使用其他 [.config] 配置文件** 点击`Run workflow`后即可输入位于`/Configs`下的配置文件名称

   🔔 **为了你的账号安全, 请不要使用 SSH 连接 Github Action**, `.config`配置等操作请务必在本地完成

## 三、部署云端日志(可选)

1. 下载本仓库中的 [Update_Logs.json](https://github.com/Hyy2001X/AutoBuild-Actions/releases/download/AutoUpdate/Update_Logs.json) 到本地 (如果有)

2. 以 **JSON** 格式编辑本地的`Update_Logs.json`

3. 手动上传修改后的`Update_Logs.json`到`Github Release`

4. 在本地执行`autoupdate --fw-log`测试

## 使用一键更新固件脚本

   首先需要打开`TTYD 终端`或者使用`SSH`, 按需输入下方指令:

   常规更新固件: `autoupdate`或完整指令`bash /bin/AutoUpdate.sh`

   使用镜像加速更新固件: `autoupdate -P`

   更新固件(不保留配置): `autoupdate -n`
   
   强制刷入固件: `autoupdate -F`
   
   "我不管, 我就是要更新!": `autoupdate -f`

   更新脚本: `autoupdate -x`

   列出相关信息: `autoupdate --list`

   查看所有可用参数: `autoupdate --help`

   **注意: **部分参数可一起使用, 例如 `autoupdate -n -P -F --path /mnt/sda1`

## 使用 tools 固件工具箱

   打开`TTYD 终端`或者使用`SSH`, 执行指令`tools`或`bash /bin/AutoBuild_Tools.sh`即可启动固件工具箱

   当前支持以下功能:

   - USB 扩展内部空间
   - Samba 相关设置
   - 打印端口占用详细列表
   - 打印所有硬盘信息
   - 网络检查 (基础网络 | Google 连接检测)
   - AutoBuild 固件环境修复
   - 系统信息监控
   - 打印在线设备列表

## 鸣谢

   - [Lean's Openwrt Source code](https://github.com/coolsnowwolf/lede)

   - [P3TERX's Blog](https://p3terx.com/archives/build-openwrt-with-github-actions.html)

   - [ImmortalWrt's Source code](https://github.com/immortalwrt)

   - [eSir 's workflow template](https://github.com/esirplayground/AutoBuild-OpenWrt/blob/master/.github/workflows/Build_OP_x86_64.yml)
   
   - [[openwrt-autoupdate](https://github.com/mab-wien/openwrt-autoupdate)] [[Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt)]

   - 测试与建议: [CurssedCoffin](https://github.com/CurssedCoffin) [Licsber](https://github.com/Licsber) [sirliu](https://github.com/sirliu) [神雕](https://github.com/teasiu) [yehaku](https://www.right.com.cn/forum/space-uid-28062.html) [缘空空](https://github.com/NaiHeKK) [281677160](https://github.com/281677160)
