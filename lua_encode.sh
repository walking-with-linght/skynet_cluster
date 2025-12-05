#!/bin/bash

# 使用相对路径
lua_path="./skynet/3rd/lua/lua"
pack_path="./pack"
key="q1a2j3s4"
target_path="./pack_safe"


if [ -d "$pack_path" ]; then
    rm -rf ${target_path}
    cp -rf ${pack_path} ${target_path}
    ${lua_path} encrycode.lua ${pack_path} ${key} ${target_path}
else
    echo "待加密目录不存在: $pack_path ,也许应该先执行 sh deploy.sh 进行打包"
fi

