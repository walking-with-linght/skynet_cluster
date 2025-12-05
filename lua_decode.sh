#!/bin/bash

# 使用相对路径
lua_path="./skynet/3rd/lua/lua"
pack_path="./pack_safe"
key="q1a2j3s4"
target_path="./decode_temp"


if [ -d "$pack_path" ]; then
    rm -rf ${target_path}
    cp -rf ${pack_path} ${target_path}
    ${lua_path} decrycode.lua ${pack_path} ${key} ${target_path}
else
    echo "待解密目录不存在: $pack_path"
fi

