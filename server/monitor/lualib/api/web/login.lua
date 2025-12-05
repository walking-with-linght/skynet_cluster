local base = require "base"
local cjson = require "cjson"
local msgpack = require "msgpack"
local skynet= require "skynet"
local DATA = base.DATA     --本服务使用的表
local CMD = base.CMD       --供其他服务调用的接口
local PUBLIC = base.PUBLIC --本服务调用的接口
local dump = require "dump"
local utils = require "utils"
local REQUEST = base.REQUEST
local httpc = require "http.httpc"
require "api.web.token"
require "api.web.public"
require "httpclient"

-- 默认不开启发送历史在线，浪费
 DATA.send_histroy = false
-- 登录
REQUEST["/monitor/get/online"] = function(path, method, header, body, query)
    -- 验证token
    local ok,why = PUBLIC.auth_token(header)
    if not ok then
        return 401
    end

    local data = skynet.call(".redis","lua","hgetall","monitor_online_data")
    -- print(dump(data))
    local result = {}
    for key, value in pairs(data) do
        if not utils.endsWith(key, "_idx") then
            local info = msgpack.decode(value) or {}
            for _, v in pairs(info) do
                if v.time and os.time() - v.time <  20 then --超过N秒认为数据已过期
                    v.server_name = GAME_SERVER_NAME[v.mode] or "未知"
                    table.insert(result, v)
                end
            end
        end
    end
	return 200,result
end

REQUEST["/monitor/get/server-status"] = function(path, method, header, body, query)
    local ok,why = PUBLIC.auth_token(header)
    if not ok then
        return 401
    end
	-- 这里替换为从游戏服务器获取真实数据
	-- local data = {
	-- 	{server_id = 1, server_name = "主游戏服务器", status = "online", uptime = "12天4小时", cpu = "32%", memory = "45%"},
	-- 	{server_id = 2, server_name = "数据库服务器", status = "online", uptime = "8天2小时", cpu = "18%", memory = "60%"},
	-- 	{server_id = 3, server_name = "登录服务器", status = "offline", uptime = "0", cpu = "0%", memory = "0%"}
	-- }
     local data = skynet.call(".redis","lua","hgetall","monitor_system_data")
     local result = {}
    for key, value in pairs(data) do
        if not utils.endsWith(key, "_idx") then
            local info = msgpack.decode(value)
            info.start_time = info.start_time or "未知"
            info.status = "online"
            info.server_name = GAME_SERVER_NAME[info.mode] or "未知"
            -- print(info.time,os.time(),os.time() - info.time)
            if info.time and os.time() - info.time >  30 then --超过N秒认为数据已过期
                info.status = "offline"
            end
            table.insert(result, info)
        end
    end
	return 200, result
end
local online_history_data_cache = {}
local history_config = {
    version = { "test", "online"},
    version_name = { "测试服", "正式服"},
    max_count = 8000,
    game_name = {'crash', 'mines', 'dice', 'limbo', 'plinko' },
}

local function get_data_from_table(tb,k,v)
    for i,value in pairs(tb) do
        if value[k] == v then
            return value
        end
    end
end

REQUEST["/monitor/get/online-history"] = function(path, method, header, body, query)
    local ok,why = PUBLIC.auth_token(header)
    if not ok then
        return 401
    end
   
    local options = {}
    local all_history = {}
    if DATA.send_histroy then
        for k,v in pairs(history_config.version) do
            online_history_data_cache[v] = online_history_data_cache[v] or {}
            -- 插入服务器下拉列表选项
            table.insert(options,{value = v,label = history_config.version_name[k] or v})


            local now_idx = skynet.call(".redis","lua","hget","monitor_online_data",v .. "_idx")
            local start_idx = math.max(1, now_idx - history_config.max_count)
            
            

            local history_data = {
                title = {
                    text = history_config.version_name[k] or v
                },
                tooltip = {
                    trigger = 'axis'
                },
                legend = {
                    data = history_config.game_name
                },
                grid = {
                    left = '3%',
                    right = '4%',
                    bottom = '3%',
                    containLabel = true
                },
                toolbox = {
                    feature = {
                    saveAsImage = {}
                    }
                },
                xAxis = {
                    type = 'category',
                    boundaryGap = false,
                    data = {},--时间
                },
                yAxis = {
                    type = 'value'
                },
                series = {
                    {
                        name = 'crash',
                        type = 'line',
                        stack = 'Total',
                        data = {}
                    },
                    {
                        name = 'mines',
                        type = 'line',
                        stack = 'Total',
                        data = {}
                    },
                    {
                        name = 'dice',
                        type = 'line',
                        stack = 'Total',
                        data = {}
                    },
                    {
                        name = 'limbo',
                        type = 'line',
                        stack = 'Total',
                        data = {}
                    },
                    {
                        name = 'plinko',
                        type = 'line',
                        stack = 'Total',
                        data = {}
                    }
                }
            }
            local need_query_keys = {}
            for i = start_idx, now_idx do
                if not online_history_data_cache[v][i] then
                    table.insert(need_query_keys, i)
                end
            end
            if next(need_query_keys) then
                local data = skynet.call(".redis","lua","hmget","monitor_online_history_data:" .. v, need_query_keys)
                for m,n in ipairs(data) do
                    if v then
                        online_history_data_cache[v][need_query_keys[m]] = msgpack.decode(n)
                    end
                end
            end
            local x_list = {}
            local history_data_series = {}
            local game_y_list = {}
            local client_idx = 0
            for i = start_idx, now_idx do
                client_idx = client_idx + 1

                x_list[client_idx] = os.date("%Y-%m-%d %H:%M:%S", online_history_data_cache[v][i][1].time)

                for m , n in ipairs(G_GAME_NAME_LIST)  do
                    game_y_list[m] = game_y_list[m] or {
                        name = n.name,
                        type = 'line',
                        stack = 'Total',
                        data = {}
                    }
                    game_y_list[m].data[client_idx] = online_history_data_cache[v][i][m] and (online_history_data_cache[v][i][m].online_count or 0) or 0
                end
            end
            history_data.xAxis.data = x_list
            history_data.series = game_y_list

            all_history[v] = history_data
        end
    end

	return 200, {
        code = 0,
        message = "success",
        options = options,
        data = all_history,
    }
end


function PUBLIC.auth_cloudflare(token)
	local host = "https://challenges.cloudflare.com"
	local url = "/turnstile/v0/siteverify"
	local header = {
		["Content-Type"] = "application/json; charset=utf-8",
	}
	local postdata = {
        secret = "0x4AAAAAABuy2jt2V77-namu8UMdjiElG40",
        response = token,
    }
	local ok,body = PUBLIC.http_request(host,url,header,"POST",postdata)
    print("auth_cloudflare", ok, body)
    if not ok then
        return false, "内部验证服务器错误"
    end
    if not ok then
        return false, "内部验证服务器错误"
    end
    -- if err ~= 200 then
    --     return false, "Cloudflare验证请求失败，状态码：" .. tostring(err)
    -- end
    local res = cjson.decode(body)
    if not res.success then
        return false, "Cloudflare验证失败"
    end
    return true
end


REQUEST["/monitor/get/login"] = function(path, method, header, body, query)
	if method ~= "POST" then return 405 end
    
    local ok, params = pcall(cjson.decode, body)
    if not ok then return 400 end
    
    if not params.username or params.username == ""
        or not params.password or params.password == "" or not params.turnstile_token then

        return 200, { code = 1,message = "请填写账号或者密码"}
    end
    -- cloudflare turnstile 验证

    -- local ok,why = PUBLIC.auth_cloudflare(params.turnstile_token)
    -- if not ok then
    --     print("auth_cloudflare error:", why)
    --     return 200,{code = 1, message = why}
    -- end

    local ret = PUBLIC.login(params.username,params.password)
    if not ret then
        return 200,{code = 1, message = "账号不存在或密码错误"}
    end
    return 200, ret
end

REQUEST["/monitor/get/register"] = function(path, method, header, body, query)
	if method ~= "POST" then return 405 end
    
    local ok, params = pcall(cjson.decode, body)
    if not ok then return 400 end
    
    -- 这里实现实际注册逻辑
    -- 应该验证短信验证码等
    local phone = utils.is_phone_str(params.phone)
    print(phone, params.phone)
    if not phone then
        return 200, {code = 1, message = "请正确填写手机号!"}
    end
    if not params.username or params.username == ""
        or not params.password or params.password == "" then

        return 200,{code = 1, message = "请填写账号或者密码"}
    end
    if not params.code or params.code == "" then

        return 200,{code = 1, message = "请填写验证码"}
    end

    local info = {
        phone = phone,
        username = params.username,
        password = params.password,
        reg_time = os.time(),
    }
    print(dump(info),"注册账号")
    local ok,why = PUBLIC.auth_reg_phone(phone, params.code)
    if not ok then
        print("auth_reg_phone error:", why)
        return 200,{code = 1, message = why}
    end
    ok,why = PUBLIC.reg_account(info)
    if not ok then
        print("reg_account error:", why)
        return 200,{code = 1, message = why}
    end

    return 200, {
        code = 0,
        token = ok.token,
        username = ok.username
    }
end

REQUEST["/monitor/get/user-info"] = function(path, method, header, body, query)
	-- 验证token
    local ok,why = PUBLIC.auth_token(header)
    if not ok then
        return 401
    end
    
    -- 这里根据token获取用户信息
    return 200, cjson.encode({
        username = "admin",
        phone = "13800138000"
    }), {
        ["Content-Type"] = "application/json"
    }
end

REQUEST["/monitor/get/send-sms"] = function(path, method, header, body, query)
	if method ~= "POST" then return 405 end
    local ok, params = pcall(cjson.decode, body)
    if not ok then return 400 end

    local phone = utils.is_phone_str(params.phone)
    print(phone, params.phone,params.type)
    if not phone then
        return 200, {code = 1, message = "请正确填写手机号!"}
    end
    local ret = PUBLIC.send_phone_code(phone,params.type)

    return 200, ret
end

REQUEST["/monitor/get/change-password"] = function(path, method, header, body, query)
	if method ~= "POST" then return 405 end
    
    local ok,why = PUBLIC.auth_token(header)
    if not ok then
        return 401
    end
    
    -- 这里实现密码修改逻辑
    return 200, cjson.encode({
        success = true
    }), {
        ["Content-Type"] = "application/json"
    }
end


REQUEST["/monitor/get/config"] = function(path, method, header, body, query)
	if method ~= "POST" then
		return 405, "Method Not Allowed"
	end
    local ok,why = PUBLIC.auth_token(header)
    if not ok then
        return 401
    end
	
	local ok, params = pcall(cjson.decode, body)
	if not ok then
		return 400, "Bad Request"
	end
	
	-- 这里处理参数修改逻辑
	-- 实际项目中应该调用skynet服务修改配置
	
	local response = {
		status = "success",
		message = "参数更新成功",
		data = params
	}
	
	return 200, cjson.encode(response), {
		["Content-Type"] = "application/json",
		["Access-Control-Allow-Origin"] = "*"
	}
end

REQUEST["/monitor/get/change-phone"] = function(path, method, header, body, query)
	if method ~= "POST" then return 405 end
    
    -- 验证token
    local ok,why = PUBLIC.auth_token(header)
    if not ok then
        return 401
    end
    
    local ok, params = pcall(cjson.decode, body)
    if not ok then return 400 end
    
    -- 这里实现手机号修改逻辑
    -- 应该验证短信验证码
    
    return 200, cjson.encode({
        success = true,
        newPhone = params.newPhone
    }), {
        ["Content-Type"] = "application/json"
    }
end

REQUEST["/views/auth/"] = function(path, method, header, body, query)
	if method ~= "POST" then return 405 end
    
    -- 验证token
    local ok,why = PUBLIC.auth_token(header)
    if not ok then
        return 401
    end
    
    local ok, params = pcall(cjson.decode, body)
    if not ok then return 400 end
    
    -- 这里实现手机号修改逻辑
    -- 应该验证短信验证码
    
    return 200, cjson.encode({
        success = true,
        newPhone = params.newPhone
    }), {
        ["Content-Type"] = "application/json"
    }
end

REQUEST["/monitor/get/verify-old-phone"] = function(path, method, header, body, query)
	if method ~= "POST" then return 405 end
    
    -- 验证token
    local ok,why = PUBLIC.auth_token(header)
    if not ok then
        return 401
    end
    
    local ok, params = pcall(cjson.decode, body)
    if not ok then return 400 end
    
    -- 这里实现手机号修改逻辑
    -- 应该验证短信验证码
    
    return 200, cjson.encode({
        success = true,
        newPhone = params.newPhone
    }), {
        ["Content-Type"] = "application/json"
    }
end

REQUEST["/monitor/get/verify-phone-for-password"] = function(path, method, header, body, query)
	if method ~= "POST" then return 405 end
    
    -- 验证token
    local ok,why = PUBLIC.auth_token(header)
    if not ok then
        return 401
    end
    
    local ok, params = pcall(cjson.decode, body)
    if not ok then return 400 end
    
    -- 这里实现手机号修改逻辑
    -- 应该验证短信验证码
    
    return 200, cjson.encode({
        success = true,
        newPhone = params.newPhone
    }), {
        ["Content-Type"] = "application/json"
    }
end