#!/bin/bash


# 1.10/1.11
versvers=$(spcomp64 -v | grep "Compiler" --color=never | cut -d " " -f 3 | cut -d "." -f 1,2)


nv_plugs=("nativevotes")
nv_plugs+=("nativevotes_basecommands")
nv_plugs+=("nativevotes_basevotes")
nv_plugs+=("nativevotes_funvotes")
nv_plugs+=("nativevotes_mapchooser")
nv_plugs+=("nativevotes_nominations")
nv_plugs+=("nativevotes_rockthevote")
nv_plugs+=("nativevotes_voterp")

# we start in git root
pushd ./addons/sourcemod/scripting

for target in "${nv_plugs[@]}"; do
    spcomp64 -i"./include/" "${target}".sp -o ../plugins/"${target}".smx || exit 1
done

popd

mkdir build || true
7za a -r build/nativevotes_sm_"${versvers}".zip scripting/ translations/ plugins/
rm plugins/ -rfv
ls -la

