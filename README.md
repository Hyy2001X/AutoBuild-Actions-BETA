## Actions for Building OpenWRT

![GitHub Stars](https://img.shields.io/github/stars/Hyy2001X/AutoBuild-Actions.svg?style=flat-square&label=Stars&logo=github)
![GitHub Forks](https://img.shields.io/github/forks/Hyy2001X/AutoBuild-Actions.svg?style=flat-square&label=Forks&logo=github)

**自动编译:本项目将在每天 19:00 自动编译固件,如需自助更新请点击 ***Star*****

测试通过的设备: `d-team_newifi-d2`、`phicomm_k2p`

测试通过的源码: [Lede](https://github.com/coolsnowwolf/lede)

## Github Actions 部署指南(STEP 1):

1. 首先需要获取[Github Token](https://github.com/settings/tokens/new),`Note`项随意填写,`Select scopes`项如果不懂就**全部打勾**,完成后点击`Generate token`

2. 复制页面中显示的 **Token**

   **注意: 一定要第一时间保存到本地, Token 值只会显示一次!**

3. ***Fork*** 此仓库,然后进入你的`AutoBuild-Actions`仓库

4. 点击右上方菜单中的`Settings`,点击`Secrets`-`New Secrets`,`Name`项填写`RELEASE_TOKEN`,`Value`项粘贴你在第 2 步中复制的 **Token** 

5. **启用 Actions 权限**,点击上方菜单中的`Actions`,点击绿色的`I understand...`即可启用 Actions 使用权限

6. 保持上方菜单,点击**带有感叹号**的`AutoBuild OpenWrt`,点击`Enable workflow`即可完成 Actions 的环境设置

   **注意: 以上操作只需操作一次!**

## 客制化固件(STEP 2):

1. 进入你的`AutoBuild-Actions`仓库

2. 首先需要将本地的 '.config' 文件**重命名**并上传到`Configs`文件夹

3. 编辑`.github/workflows/NEWIFI_D2-NIGHTLY.yml`文件,修改`第 20 行`为上方**重命名**后的配置名称

4. 编辑`Customize/AutoUpdate.sh`文件,修改`第 7 行`为你的 **设备名称**,修改`第 8 行`为你的 **Github 地址**

   **注意: 设备名称 应为设备的完整代号,例如 d-team_newifi-d2 而并非 Newifi-D2**

5. 编辑`Scripts/diy-script.sh`文件,修改`第 7 行`为作者,作者将在 OpenWrt 首页显示

6. **手动启动编译**: 点击右上方 ***Star*** 即可开始编译,最好先同步我的最新改动~~以获得更多特性(bug)~~

   **添加额外的软件包:** 编辑`Scripts/diy-script.sh`,修改`Diy-Part1()`函数,参照下方语法:
```
   [git clone -b]  ExtraPackages git 安装位置 软件包名 Github仓库地址 远程分支
    
   [svn checkout]  ExtraPackages svn 安装位置 软件包名 Github仓库地址/trunk
```

   **添加自定义文件:** 首先将文件上传到`/Customize`,然后修改`Scripts/diy-script.sh`,参照下方语法:
```
   [mv -f] Replace_File 文件名称 替换目录 重命名
```

## 自动编译 && 定时更新:

1. 进入你的`AutoBuild-Actions`仓库

2. 编辑`.github/workflows/AutoBuild.yml`文件,编辑`第 20 行`,并按需修改 corntab 参数(默认每天 19:00 开始编译)

3. 打开 Openwrt 主页,点击`系统`-`定时更新`,设置自动检查更新的时间并保存(**需要 [luci-app-autoupdate](https://github.com/Hyy2001X/luci-app-autoupdate) 支持**)

## 使用指令更新固件:
   
   在终端输入: `bash /bin/AutoUpdate.sh`

   不保留配置更新: `bash /bin/AutoU*.sh -n`
   
## 鸣谢

   - [Lean's Openwrt](https://github.com/coolsnowwolf/lede)

   - [P3TERX](https://github.com/P3TERX/Actions-OpenWrt)
   
   - [CurssedCoffin](https://github.com/CurssedCoffin)
   
   - [Licsber](https://github.com/Licsber)
   
   - [mab-wien](https://github.com/mab-wien/openwrt-autoupdate)
