#!/bin/bash

pack_path="./pack"
if [ -d "$pack_path" ]; then
    sh _pack.sh -s "unsafe" -w $pack_path
else
    echo "打包目录不存在: $pack_path ,也许应该先执行 sh deploy.sh 进行打包"
fi

