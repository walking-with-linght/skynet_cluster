#!/bin/bash

pack_path="./pack_safe"
if [ -d "./pack" ]; then
    sh lua_encode.sh
    sh _pack.sh -s "safe" -w "$pack_path"
else
    echo "打包目录不存在: ./pack ,也许应该先执行 sh deploy.sh 进行打包"
fi
