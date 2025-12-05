local assert = assert
local ARGV = { ... }
local ENCRYPTED_PATH = ARGV[1]  -- 加密文件所在目录
local key = ARGV[2]  -- 解密密钥
local OUTPUT_PATH = ARGV[3]  -- 解密输出目录

assert(ENCRYPTED_PATH, '缺少 ENCRYPTED_PATH')
assert(key, "缺少 key")
assert(key:len() == 8, "key 长度不对 ".. key)

-- 设置模块路径
local skynet_path = ENCRYPTED_PATH .. '/skynet'
if package.config:sub(1, 1) == '\\' then
    package.cpath = ENCRYPTED_PATH .. "/luaclib/?.dll;" .. skynet_path .. '/luaclib/?.dll;'
else
    package.cpath = ENCRYPTED_PATH .. "/luaclib/?.so;" .. skynet_path .. '/luaclib/?.so;' .. "./skynet/luaclib/?.so;"
end
package.path = './lualib/?.lua;' .. './?.lua;' .. ENCRYPTED_PATH .. "/lualib/?.lua;"

local file_util = require "utils.file_util"
local crypt = require "client.crypt"
local lfs = require "lfs"

local function mkdir_p(path)
    path = path:gsub("\\", "/")
    local current_path = ""
    
    for part in path:gmatch("([^/]+)") do
        current_path = current_path == "" and part or current_path .. "/" .. part
        
        if lfs.attributes(current_path) == nil then
            local success, err = lfs.mkdir(current_path)
            if not success then
                return false, "无法创建目录: " .. current_path .. " - " .. err
            end
        end
    end
    
    return true
end

-- 创建输出目录
mkdir_p(OUTPUT_PATH)

local sfind = string.find
local io = io

local function decrypt_file(encrypted_file_path, output_file_path)
    local encrypted_file, why = io.open(encrypted_file_path, "rb")
    if not encrypted_file then
        print("can't open encrypted file >>> ", encrypted_file_path, why)
        return false
    end
    
    -- 读取文件头 "just-funny" (10字节)
    local header = encrypted_file:read(10)
    if header ~= "just-funny" then
        print("Invalid file format or corrupted file: " .. encrypted_file_path)
        encrypted_file:close()
        return false
    end
    
    -- 读取4字节的大小信息
    local size_bytes = encrypted_file:read(4)
    if not size_bytes or #size_bytes ~= 4 then
        print("Invalid size information: " .. encrypted_file_path)
        encrypted_file:close()
        return false
    end
    
    -- 解包获取加密内容的大小
    local encoded_size = string.unpack(">I4", size_bytes)
    print("encoded_size",encoded_size)
    -- 读取加密内容
    local encoded_str = encrypted_file:read(encoded_size)
    if not encoded_str or #encoded_str ~= encoded_size then
        print("File corrupted: incomplete data: " .. encrypted_file_path)
        encrypted_file:close()
        return false
    end
    
    encrypted_file:close()
    
    -- 使用 DES 解密算法解密内容
    -- 注意：根据加密脚本，参数顺序是 crypt.desencode(key, code_str)
    local decrypted_str = crypt.desdecode(key, encoded_str)
    print(#decrypted_str)
    -- 将解密后的内容写入输出文件
    local output_file, why = io.open(output_file_path, "w+")
    if not output_file then
        print("can't open output file >>> ", output_file_path, why)
        return false
    end
    
    output_file:write(decrypted_str)
    output_file:close()
    
    -- 验证解密后的文件是否可以正常加载
    local func, err = load(decrypted_str)
    if not func then
        print("解密文件验证失败: " .. output_file_path .. " - " .. err)
        return false
    end
    
    print("decrypt file succ: " .. output_file_path .. ", size: " .. #decrypted_str)
    return true
end

-- 主解密流程
for file_name, file_path, file_info in file_util.diripairs(ENCRYPTED_PATH) do
    if sfind(file_name, '.lua', nil, true) then
        local encrypted_file, why = io.open(file_path, "rb")
        if encrypted_file then
            -- 检查文件头是否为加密格式
            local header = encrypted_file:read(#"just-funny")
            encrypted_file:close()
            
            if header == "just-funny" then
                print("decrypting file: " .. file_path)
                
                local RelativePath = file_util.getRelativePath(ENCRYPTED_PATH, file_path)
                if RelativePath then
                    local output_file_path = file_util.path_join(OUTPUT_PATH, RelativePath)
                    local output_dir = file_util.getDirectoryPath(output_file_path)
                    
                    if output_dir then
                        local isok, err = mkdir_p(output_dir)
                        if not isok then
                            print("create dir_path err ", output_dir, err)
                        else
                            decrypt_file(file_path, output_file_path)
                        end
                    end
                end
            else
                print("skip non-encrypted file: " .. file_path)
            end
        end
    end
end

print("Decryption completed!")