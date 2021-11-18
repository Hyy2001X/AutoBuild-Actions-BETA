#!/bin/bash
# AutoBuild Module by Hyy2001 <https://github.com/Hyy2001X/AutoBuild-Actions>
# Thanks to 281677160 and TobKed
# Sync

# 上游仓库与分支
INPUT_UPSTREAM_REPOSITORY=Hyy2001X/AutoBuild-Actions
INPUT_UPSTREAM_BRANCH=master

# 需要文件的同步列表, 按需修改
Sync_List=(
	# .github/workflows/*
	# Configs/*
	CustomFiles/Depends/*
	CustomFiles/Patches/*
	CustomFiles/d-team_newifi-d2_mac80211.patch
	CustomFiles/d-team_newifi-d2_system
	# Scripts/AutoBuild_DiyScript.sh
	# Scripts/Sync.sh
	Scripts/AutoBuild_Function.sh
	Scripts/AutoUpdate.sh
	Scripts/AutoBuild_Tools.sh
	Scripts/Convert_Translation.sh
	# LICENSE
	README.md
	)

set -e

[[ $# -lt 2 ]] && exit
[[ $* =~ '--sync-all' ]] && {
	echo "Sync mode: All files"
	SYNC_ALL=true
} || {
	echo "Sync mode: <Sync_List> files"
	SYNC_ALL=false
}

DUMP_DIR=/tmp/Sync_Fork

INPUT_GITHUB_TOKEN=$1
INPUT_LOCAL_REPOSITORY=$2
INPUT_LOCAL_BRANCH=master

UPSTREAM_REPO="https://github.com/${INPUT_UPSTREAM_REPOSITORY}.git"
UPSTREAM_REPO_DIR=${DUMP_DIR}/${INPUT_UPSTREAM_REPOSITORY##*/}
LOCAL_REPO="https://${GITHUB_ACTOR}:${INPUT_GITHUB_TOKEN}@github.com/${INPUT_LOCAL_REPOSITORY}.git"
LOCAL_REPO_DIR=${DUMP_DIR}/${INPUT_LOCAL_REPOSITORY##*/}

mkdir -p ${DUMP_DIR}

if [[ ${SYNC_ALL} == true ]];then
	git clone -b ${INPUT_UPSTREAM_BRANCH} ${UPSTREAM_REPO} ${UPSTREAM_REPO_DIR}
	cd ${UPSTREAM_REPO_DIR}
	git push --force ${LOCAL_REPO} ${INPUT_UPSTREAM_BRANCH}:${INPUT_LOCAL_BRANCH}
	[[ $? == 0 ]] && echo "Sync successful" || echo "Sync failed"
else
	git clone -b ${INPUT_UPSTREAM_BRANCH} ${UPSTREAM_REPO} ${UPSTREAM_REPO_DIR}
	git clone -b ${INPUT_LOCAL_BRANCH} ${LOCAL_REPO} ${LOCAL_REPO_DIR}
	echo "Clone finished"
	cd ${UPSTREAM_REPO_DIR}
	for i in $(echo ${Sync_List[@]});do
		if [[ -f $i ]];then
			echo "Checkout [${UPSTREAM_REPO_DIR}/$i] to [${LOCAL_REPO_DIR}/$i] ..."
			[[ $i =~ '/' && ! -d ${LOCAL_REPO_DIR}/${i%/*} ]] && mkdir -p ${LOCAL_REPO_DIR}/${i%/*}
			cp -a ${UPSTREAM_REPO_DIR}/$i ${LOCAL_REPO_DIR}/$i
		else
			echo "Unable to access file ${UPSTREAM_REPO_DIR}/$i ..."
		fi
	done
	sleep 3
	cd ${LOCAL_REPO_DIR}
	git config --global user.name ${GITHUB_ACTOR}
	# git remote add origin ${LOCAL_REPO}
	git add *
	echo "Sync time: $(date "+%Y/%m/%d-%H:%M:%S")"
	git commit -m "Sync $(date "+%Y/%m/%d-%H:%M:%S")"
	git push origin ${INPUT_LOCAL_BRANCH} --force
	[[ $? == 0 ]] && echo "Sync successful" || echo "Sync failed"
fi
