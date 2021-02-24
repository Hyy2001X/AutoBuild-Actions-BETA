## Actions for Building OpenWRT

![GitHub Stars](https://img.shields.io/github/stars/Hyy2001X/AutoBuild-Actions.svg?style=flat-square&label=Stars&logo=github)
![GitHub Forks](https://img.shields.io/github/forks/Hyy2001X/AutoBuild-Actions.svg?style=flat-square&label=Forks&logo=github)

~~自动编译:本项目将在每天 19:00 启动自动编译~~

测试通过的设备: `d-team_newifi-d2`、`phicomm_k2p`、`x86_64(img、img.gz)`、以及使用 bin 格式固件的设备

## Github Actions 部署指南(STEP 1):

1. 首先需要获取 **Github Token**: [点击这里](https://github.com/settings/tokens/new) 进入获取页面,

   `Note`项填写你中意的名称,`Select scopes`不懂就**全部打勾**,操作完成后点击下方`Generate token`

2. 复制页面中生成的 **Token**,并保存到本地

   **一定要保存到本地,Github 为了安全起见, Token 值只会显示一次!**

3. ***Fork*** 我的`AutoBuild-Actions`仓库,然后进入你的`AutoBuild-Actions`仓库进行之后的设置

4. 点击上方菜单中的`Settings`,依次点击`Secrets`-`New repository secret`

   其中`Name`项填写`RELEASE_TOKEN`,然后将你的 **Token** 粘贴到`Value`项,完成后点击`Add secert`

   **注意: Github Actions 部署只需操作一次!**

## 客制化固件(STEP 2):

1. 进入你的`AutoBuild-Actions`仓库,**下方所有操作都将在你的`AutoBuild-Actions`仓库下进行**

2. 把本地的 '.config' 文件重命名并上传到`/Configs`或者直接修改原有文件

3. 编辑`.github/workflows/*.yml`文件,修改`第 27 行`为你上传的 '.config' 文件名称

4. 按照你的需求编辑`Scripts/AutoBuild_DiyScript.sh`文件(可以跳过此步骤)

   **Diy_Core() 函数中的名词解释:**
```
   Author 作者名称,这个名称将在 OpenWrt 首页显示
   
   Default_Device 路由器的完整名称,例如 [d-team_newifi-d2、phicomm_k2p],用于无法从 .config 正常获取设备时备用
   
   INCLUDE_AutoUpdate 启用后,将自动添加 AutoUpdate.sh 和 luci-app-autoupdate 到固件
   
   INCLUDE_AutoBuild_Tools 添加 AutoBuild_Tools.sh 到固件
   
   INCLUDE_mt7621_OC1000MHz 启用后,Ramips_mt7621 系列的路由器将自动超频到 1000MHz
   
   INCLUDE_SSR_Plus 添加 fw876 的 helloworld 仓库到源码目录
   
   INCLUDE_Passwall 添加 xiaorouji 的 openwrt-passwall 仓库到源码目录
   
   INCLUDE_HelloWorld 添加 jerrykuku 的 luci-app-vssr 仓库到源码目录 [Not tested]
   
   INCLUDE_Bypass 添加 garypang13 的 luci-app-bypass 仓库到源码目录,可能与 SSR Plus+ 存在冲突 [Not tested]
   
   INCLUDE_OpenClash 添加 vernesong 的 luci-app-openclash 到源码目录
   
   INCLUDE_OAF 添加 destan19 的 OpenAppFilter 仓库到源码目录,可能与 TurboACC 存在冲突 [Not tested]

```
   **AutoBuild 特有指令:** 编辑`Scripts/AutoBuild_DiyScript.sh`,参照下方语法:
```
   [使用 git clone 拉取文件]  ExtraPackages git 存放位置 软件包名 仓库地址 分支
    
   [使用 svn checkout 拉取文件]  ExtraPackages svn 存放位置 软件包名 仓库地址/trunk/目录
   
   [替换 /Customize 文件到源码] Replace_File 文件名称 目标路径 重命名(可选)
   
   [新建文件夹] Mkdir 文件夹名称
   
   [更新 Makefile] Update_Makefile 软件包名 软件包路径 (仅支持部分软件包,自行测试)
   
```
5. **开始编译**: 点击右上方 ***Star***即可启动编译,最好同步我的最新改动以获得更多特性

## 使用一键更新固件脚本:

   首先需要打开 Openwrt 主页,点击`系统`-`TTYD 终端`或者在浏览器输入`192.168.1.1:7681`,按需输入下方指令:
   
   检查并更新固件(保留配置): `bash /bin/AutoUpdate.sh`

   检查并更新固件(不保留配置): `bash /bin/AutoUpdate.sh -n`
   
   列出部分系统参数(用于反馈问题): `bash /bin/AutoUpdate.sh -l`
   
   切换检查更新/固件下载通道: `bash /bin/AutoUpdate.sh -c [地址]`
   
   **注意: 一键更新固件需要在 Diy-Core() 函数中启用`INCLUDE_AutoUpdate`**
   
## 使用一键扩展内部空间\挂载 Samba 共享脚本:

   同上方操作,打开`TTYD 终端`,输入`bash /bin/AutoBuild_Tools.sh`
   
   **注意: 使用此脚本需要在 Diy-Core() 函数中启用`INCLUDE_AutoBuild_Tools`**
   
## 鸣谢

   - [Lean's Openwrt](https://github.com/coolsnowwolf/lede)

   - [P3TERX's Project](https://github.com/P3TERX/Actions-OpenWrt)
   
   - [P3TERX's Blog](https://p3terx.com/archives/build-openwrt-with-github-actions.html)

   - [eSir's workflow](https://github.com/esirplayground/AutoBuild-OpenWrt/blob/master/.github/workflows/Build_OP_x86_64.yml)
   
   - 测试/建议: [CurssedCoffin](https://github.com/CurssedCoffin) [Licsber](https://github.com/Licsber) [sirliu](https://github.com/sirliu?tab=repositories)
