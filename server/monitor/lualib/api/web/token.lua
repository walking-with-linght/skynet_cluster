local skynet = require "skynet"
local base = require "base"
local cjson = require "cjson"


local DATA = base.DATA     --本服务使用的表
local CMD = base.CMD       --供其他服务调用的接口
local PUBLIC = base.PUBLIC --本服务调用的接口


DATA.login_expire = 86400
DATA.op_expire = 86400


local function generate_token(unique_id, length)
    unique_id = unique_id or skynet.call(".redis", "lua", "hincrby", "web_config", "unique_id", 1)
    -- 设置默认长度
    length = length or 32
    
    -- 组合当前时间和唯一ID作为随机数种子
    -- 这样即使同一毫秒内多次调用，由于unique_id不同，结果也不同
    math.randomseed(os.time() * 1000 + unique_id)
    
    -- 可用的字符集合（去除了容易混淆的字符）
    local charset = {}
    -- 数字 0-9
    for i = 48, 57 do table.insert(charset, string.char(i)) end
    -- 大写字母 A-Z
    for i = 65, 90 do table.insert(charset, string.char(i)) end
    -- 小写字母 a-z
    for i = 97, 122 do table.insert(charset, string.char(i)) end
    
    -- 生成随机字符串
    local result = {}
    for i = 1, length do
        -- 从字符集中随机选择一个字符
        table.insert(result, charset[math.random(1, #charset)])
    end
    
    return table.concat(result)
end


function PUBLIC.auth_token(header)
    -- 验证token
    local auth = header.authorization
    if not auth or not auth:match("^Bearer ") then
        return
    end
    -- 使用模式匹配提取Bearer后面的token
    local token = string.match(auth, "^[Bb]earer%s+(.+)$")
    
    if not token or token == "" then
        return
    end
    print("token", token)
    local token_info = skynet.call(".redis", "lua", "hgetall", "web_token:" .. token)
    if not token_info or not token_info.username then
        return
    end
    skynet.send(".redis", "lua", "expire", "web_token:" .. token, DATA.op_expire)
    return true
end

-- 
function PUBLIC.login(username,password)
    local account_info = skynet.call(".redis", "lua", "hgetall", "web_admins:" .. username)
    print(dump(account_info), "登录账号信息",username,password)
    if not account_info.password then
        return false
    end
    if account_info.password ~= password then
        return false
    end
    -- 验证通过，生成token
    local token = generate_token()

    local argument =  {
        --设置token
        {"hmset", "web_token:" .. token,
                "username" , username,
                "login_time" , os.time(),
        },
        --设置token过期时间
        {"expire", "web_token:" .. token, DATA.login_expire},-- 1小时过期，接口验证后可继续保留1小时
        --更新account登录时间
        {"hmset", "web_admins:" .. username , "login_time", os.time()},
    }


    skynet.call(".redis", "lua", "pipeline", argument,{})
    return {
        code = 0,
        token = token,
        username = username,
    }
end

function PUBLIC.reg_account(info)
    local username = info.username
    local account_info = skynet.call(".redis", "lua", "hgetall", "web_admins:" .. username)
    print(dump(account_info), "注册账号信息")
    if account_info and next(account_info) then
        return false, "账号已存在"
    end
    if not info.password or info.password == "" then
        return false, "请填写密码"
    end

    -- 验证通过，生成token
    local token = generate_token()
    print("token:",token)
    info.login_time = os.time()
    local argument =  {
        --设置token
        {"hmset", "web_token:" .. token,
                "username" , username,
                "login_time" , os.time(),
        },
        --设置token过期时间
        {"expire", "web_token:" .. token, DATA.login_expire},-- 1小时过期，接口验证后可继续保留1小时
        --更新account登录时间
        {"hmset", "web_admins:" .. username , table.redis_unpack(info)},
    }


    skynet.send(".redis", "lua", "pipeline", argument,{})
    return {
        code = 0,
        token = token,
        username = username,
    }
end