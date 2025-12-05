local assert = assert
local ARGV = { ... }
local PACK_PATH = ARGV[1] -- "/home/ubuntu/my/skynet_cluster"-- ARGV[1]
local key = ARGV[2] -- "qwer1234" -- ARGV[2]
local TARGET_PATH = ARGV[3] -- PACK_PATH .. "/pack"--ARGV[3]

local not_pack_dir = {
    [PACK_PATH .. "/pack_lua"] = true,
    [PACK_PATH .. "/shell"] = true,
    [PACK_PATH .. "/skynet"] = true,
    [PACK_PATH .. "/pack"] = true,
}
assert(PACK_PATH, '缺少 PACK_PATH')
assert(key, "缺少 key")
assert(key:len() == 8, "key 长度不对 ".. key)

local skynet_path = PACK_PATH .. '/skynet'
if package.config:sub(1, 1) == '\\' then
    package.cpath = PACK_PATH .. "/luaclib/?.dll;" .. skynet_path .. '/luaclib/?.dll;'
else
    package.cpath = PACK_PATH .. "/luaclib/?.so;" .. skynet_path .. '/luaclib/?.so;' .. "./skynet/luaclib/?.so;"
end
package.path = './lualib/?.lua;' .. './?.lua;' .. PACK_PATH .. "/lualib/?.lua;"

-- if not TARGET_PATH then
--     TARGET_PATH = './encrycode/'
-- end

local file_util = require "utils.file_util"
local crypt = require "client.crypt"
local lfs = require "lfs"

local function mkdir_p(path)
    -- 规范化路径分隔符
    path = path:gsub("\\", "/")
    
    local current_path = ""
    
    for part in path:gmatch("([^/]+)") do
        current_path = current_path == "" and part or current_path .. "/" .. part
        
        -- 检查目录是否已存在
        if lfs.attributes(current_path) == nil then
            local success, err = lfs.mkdir(current_path)
            if not success then
                return false, "无法创建目录: " .. current_path .. " - " .. err
            end
        end
    end
    
    return true
end

mkdir_p(TARGET_PATH)

local sfind = string.find
local sgsub = string.gsub
local loadfile = loadfile
local sdump = string.dump
local io = io


for file_name, file_path, file_info in file_util.diripairs(PACK_PATH) do
    if sfind(file_name, '.lua', nil, true) and not sfind(file_name, 'encrycode.lua', nil, true) and not sfind(file_name, 'moon.conf', nil, true) then
        local code_func = loadfile(file_path)
        if not code_func then
            print("can`t loadfile >>> ", file_path)
        else
            -- print("encry file:", file_path)
            for skip_file_path in pairs(not_pack_dir) do
                local startIndex = string.find(file_path, skip_file_path, 1, true)
                if startIndex == 1 then
                    print("skip encry file:", file_path)
                    code_func = nil
                    break
                end
            end
            if code_func then
                local code_str = string.dump(code_func)
                print("加密前字节数", #code_str,type(code_func),code_str)
                local encode_str = crypt.desencode(key, code_str)
                print("加密后字节数", #encode_str)
                local RelativePath = file_util.getRelativePath(PACK_PATH,file_path)
                -- print("相对路径",RelativePath,PACK_PATH,file_path)
                if RelativePath then
                    local new_file_path = file_util.path_join(TARGET_PATH, RelativePath)
                    local new_path = file_util.getDirectoryPath(new_file_path)
                    if new_path then
                        local isok, err = mkdir_p(new_path) --这里可以不用创建，因为外部shell已经复制文件过来了
                        if not isok then
                            print("create dir_path err ", RelativePath, err)
                        else
                            -- print("create dir_path ok ", new_path)
                            local newfile,why = io.open(new_file_path, "w+b")
                            if not newfile then
                                print("can`t openfile >>> ", new_path,new_file_path,why)
                            else
                                local size = string.pack(">I4", #encode_str)
                                newfile:write("just-funny")
                                newfile:write(size)
                                newfile:write(encode_str)
                                newfile:close()
                                print("标记头","just-funny",#"just-funny")
                                print(string.format("正式大小%s%s",size,#size))
                                print(string.unpack(">I4", size))
                                local func,err = loadfile(new_file_path)
                                if not func then
                                    print("loadfile err ", err)
                                else
                                    print("encry file succ:", new_file_path, #encode_str)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end