# Actions for Building OpenWrt / AutoUpdate

![GitHub Stars](https://img.shields.io/github/stars/Hyy2001X/AutoBuild-Actions.svg?style=flat-square&label=Stars&logo=github)
![GitHub Forks](https://img.shields.io/github/forks/Hyy2001X/AutoBuild-Actions.svg?style=flat-square&label=Forks&logo=github)

AutoBuild-Actions 稳定版/模板地址: [AutoBuild-Actions-Template](https://github.com/Hyy2001X/AutoBuild-Actions-Template)

测试通过的设备: `x86_64`

支持的 OpenWrt 源码: `coolsnowwolf/lede`、`immortalwrt/immortalwrt`、`openwrt/openwrt`、`lienol/openwrt`

## 部署环境(STEP 1):

1. 首先需要获取 **Github Token**: [点击这里](https://github.com/settings/tokens/new) 获取,

   `Note`项填写一个名称,`Select scopes`**全部打勾**,完成后点击下方`Generate token`

2. 复制页面中生成的 **Token**,**并保存到本地,Token 只会显示一次!**

3. **Fork** 我的`AutoBuild-Actions`仓库,然后进入你的`AutoBuild-Actions`仓库进行之后的设置

4. 点击上方菜单中的`Settings`,依次点击`Secrets`-`New repository secret`

   其中`Name`项随意填写,然后将你的 **Token** 粘贴到`Value`项,完成后点击`Add secert`

## 定制固件(STEP 2):

1. 进入你的`AutoBuild-Actions`仓库,**下方所有操作都将在你的`AutoBuild-Actions`仓库下进行**

   建议使用`Github Desktop`进行操作,修改文件或者同步最新改动都很方便 [[Github Desktop](https://desktop.github.com/)] [[Notepad++](https://notepad-plus-plus.org/downloads/)]

   **提示**: 文中的`TARGET_PROFILE`为设备名称,可以在`.config`中获取,例如: `d-team_newifi-d2`

   本地获取: `egrep -o "CONFIG_TARGET.*DEVICE.*=y" .config | sed -r 's/.*DEVICE_(.*)=y/\1/'`
   
   或者: `grep 'TARGET_PROFILE' .config`,名称中不应含有`DEVICE_`

2. 把本地的`.config`文件**重命名**并上传到仓库的`/Configs`目录

    **/Configs/Common**: 通用配置文件,将在编译开始前被追加到 .config,用于同时管理多个设备,不需要删除即可

3. 编辑`/.github/workflows/*.yml`文件,修改`第 7 行`为易于自己识别的名称

4. 编辑`/.github/workflows/*.yml`文件,修改`第 32 行`为上传的`.config`文件名称

5. 按照需求且编辑`/Scripts/AutoBuild_DiyScript.sh`文件即可,`/Scripts`下的其他文件可以都不用修改

   **额外的软件包列表** 按照现有语法和提示编辑`/Scripts/AutoBuild_ExtraPackages.sh`文件

**AutoBuild_DiyScript.sh: Diy_Core() 函数中的变量解释:**
```
   Author 作者名称,若留空将自动获取为 Github 用户名
   
   Banner_Title Banner 标题,与作者名称一同在 Shell 展示

   Default_LAN_IP 固件默认 LAN IP 地址

   Short_Firmware_Date 简短的固件日期 true: [20210601]; false: [202106012359]

   Load_CustomPackages_List 启用后,将自动运行 /Scripts/AutoBuild_ExtraPackages.sh 脚本

   Checkout_Virtual_Images 额外上传已检测到的  x86 虚拟磁盘镜像
   
   Firmware_Format 自定义固件格式,多设备编译请搭配 case 使用

   REGEX_Skip_Checkout 固件检测屏蔽正则列表,用于过滤无用文件

   INCLUDE_AutoBuild_Features 自动添加 AutoBuild 固件特性,例如: 一键更新、部分优化

   INCLUDE_DRM_I915 自动启用 x86 设备的 Intel Graphics i915 驱动

   INCLUDE_Argon 自动添加 luci-theme-argon 主题和主题控制器

   INCLUDE_Obsolete_PKG_Compatible 完善原生 OpenWrt-19.07、21.02 支持 (测试特性)
   
   注: 禁用某项功能请将变量值修改为 false 或直接留空
```
**其他指令:** 参照下方语法:
```
   [使用 git clone 拉取文件]  AddPackage git 存放位置 仓库名称 仓库作者 分支

   [使用 svn co 拉取文件]  AddPackage svn 存放位置 软件包名 仓库作者/仓库名称/branches/分支名称/路径(可选)

   [复制 /CustomFiles 文件到源码] Copy 文件(夹)名称 目标路径 新名称(可选)
```
## 编译固件(STEP 3):

   **一键编译** 先删除`第 26-27 行`的注释并保存,单(双)击重新点亮右上角的 **Star** 即可一键编译

   **定时编译** 先删除`第 23-24 行`的注释,然后按需修改相关参数并保存,[使用方法](https://www.runoob.com/w3cnote/linux-crontab-tasks.html)

   **手动编译** 点击上方`Actions`,选择你要编译的设备名称,点击右方`Run workflow`,点击绿色按钮即可开始编译
   
   **临时修改 IP 地址** 该功能仅在**手动编译**时生效,点击`Run workflow`后即可输入 IP 地址(优先级**高于** `Default_LAN_IP`)

## 使用 AutoUpdate 一键更新脚本:

   首先需要打开`TTYD 终端`或者在使用`ssh`连接设备,按需输入下方指令:

   更新固件: `autoupdate`或`bash /bin/AutoUpdate.sh`

   更新固件(优先使用镜像加速 Ghproxy | FastGit): `autoupdate -P <G | F>`

   更新固件(不保留配置): `autoupdate -n`
   
   强制刷入固件: `autoupdate -F`
   
   "我不管,我就是要更新!": `autoupdate -f`
   
   **注意:** 部分参数可一起使用,例如: `autoupdate -n -P -F --skip path=/mnt/sda1`

   查看更多参数/使用方法: `autoupdate --help`

## 鸣谢

   - [Lean's Openwrt Source code](https://github.com/coolsnowwolf/lede)

   - [P3TERX's Blog](https://p3terx.com/archives/build-openwrt-with-github-actions.html)

   - [ImmortalWrt's Source code](https://github.com/immortalwrt)

   - [eSir 's workflow template](https://github.com/esirplayground/AutoBuild-OpenWrt/blob/master/.github/workflows/Build_OP_x86_64.yml)
   
   - 灵感来源/Based on: [openwrt-autoupdate](https://github.com/mab-wien/openwrt-autoupdate) [Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt)

   - 测试与建议: [CurssedCoffin](https://github.com/CurssedCoffin) [Licsber](https://github.com/Licsber) [sirliu](https://github.com/sirliu) [神雕](https://github.com/teasiu) [yehaku](https://www.right.com.cn/forum/space-uid-28062.html) [缘空空](https://github.com/NaiHeKK) [281677160](https://github.com/281677160)
