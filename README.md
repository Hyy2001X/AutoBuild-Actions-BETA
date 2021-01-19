## Actions for Building OpenWRT

![GitHub Stars](https://img.shields.io/github/stars/Hyy2001X/AutoBuild-Actions.svg?style=flat-square&label=Stars&logo=github)
![GitHub Forks](https://img.shields.io/github/forks/Hyy2001X/AutoBuild-Actions.svg?style=flat-square&label=Forks&logo=github)

**自动编译:本项目将在每天 19:00 自动编译固件,如需自助更新请点击 ***Star*****

测试通过的设备: `d-team_newifi-d2`、`phicomm_k2p`

测试通过的源码: [Lede](https://github.com/coolsnowwolf/lede)

## Github Actions 部署指南(STEP 1):

1. 首先需要获取[Github Token](https://github.com/settings/tokens/new),`Note`项随意填写,`Select scopes`**全部打勾**,完成后点击`Generate token`

2. 复制页面中显示的 **Token**

   **注意: 一定要第一时间保存到本地, Token 值只会显示一次!**

3. ***Fork*** 此仓库,然后进入你的`AutoBuild-Actions`仓库

4. 点击右上方菜单中的`Settings`,点击`Secrets`-`New Secrets`,`Name`项填写`RELEASE_TOKEN`,`Value`项粘贴你在第 2 步中复制的 **Token** 

   **注意: 以上操作只需操作一次!**

## 客制化固件(STEP 2):

1. 进入你的`AutoBuild-Actions`仓库

2. 首先需要将本地的 '.config' 文件**重命名**并上传到`AutoBuild-Actions`仓库根目录

3. 编辑`.github/workflows/AutoBuild.yml`文件,修改`第 27 行`为你上传的 '.config' 文件名称

4. 编辑`Scripts/AutoBuild_DiyScript.sh`文件,修改`第 7 行`为作者,作者将在 OpenWrt 首页显示

5. **手动启动编译**: 点击右上方 ***Star*** 即可开始编译,最好先同步我的最新改动~~以获得更多特性(bug)~~

   **AutoBuild 特有指令:** 编辑`Scripts/AutoBuild_DiyScript.sh`,参照下方语法:
```
   [git clone -b]  ExtraPackages git 安装位置 软件包名 Github仓库地址 远程分支
    
   [svn checkout]  ExtraPackages svn 安装位置 软件包名 Github仓库地址/trunk
   
   [mv -f] Replace_File 文件名称 目标路径 重命名(可选)
   
   [mkdir -p] Mkdir 目标路径
   
   [更新 Makefile] Update_Makefile 软件包名 软件包路径
   
```

## 自动编译 && 定时更新:

1. 进入你的`AutoBuild-Actions`仓库

2. 编辑`.github/workflows/AutoBuild.yml`文件,编辑`第 21 行`,并按需修改 corntab 参数(默认每天 19:00 开始编译)

3. 打开 Openwrt 主页,点击`系统`-`定时更新`,设置自动检查更新的时间并保存(需要 [luci-app-autoupdate](https://github.com/Hyy2001X/luci-app-autoupdate) 支持)

## 使用一键更新固件脚本:

   首先需要打开 Openwrt 主页,点击`系统`-`TTYD 终端`或者在浏览器输入`192.168.1.1:7681`,按需输入下方指令:
   
   检查更新(保留配置): `bash /bin/AutoUpdate.sh`

   检查更新(不保留配置): `bash /bin/AutoUpdate.sh -n`
   
   更新到最新稳定版(保留配置): `bash /bin/AutoUpdate.sh -s`
   
   更新到最新稳定版(不保留配置): `bash /bin/AutoUpdate.sh -sn`
   
## 使用一键扩展内部空间\挂载 Samba 脚本:

   同上方操作,打开`TTYD 终端`,输入`bash /bin/AutoBuild_Tools.sh`
   
## 鸣谢

   - [Lean's Openwrt](https://github.com/coolsnowwolf/lede)

   - [P3TERX](https://github.com/P3TERX/Actions-OpenWrt)
   
   - [CurssedCoffin](https://github.com/CurssedCoffin)
   
   - [Licsber](https://github.com/Licsber)
   
   - [mab-wien](https://github.com/mab-wien/openwrt-autoupdate)
