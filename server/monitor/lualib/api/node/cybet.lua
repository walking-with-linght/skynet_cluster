local base = require "base"
local cjson = require "cjson"
local msgpack = require "msgpack"
local skynet= require "skynet"
cjson.encode_sparse_array(true)
local DATA = base.DATA     --本服务使用的表
local CMD = base.CMD       --供其他服务调用的接口
local PUBLIC = base.PUBLIC --本服务调用的接口
local utils = require "utils"

local REQUEST = base.REQUEST




REQUEST["/monitor/set/online"] = function(path, method, header, body, query)
    if method ~= "POST" then return 405 end
    local data = cjson.decode(body)
    if not data then
        return 400
    end
    -- local data = {
	-- 	{zone_id = 1, zone_name = "在线总人数", online_count = 10},
	-- 	{zone_id = 2, zone_name = "crash人数", online_count = 20},
	-- 	{zone_id = 3, zone_name = "三区", online_count = 5}
	-- }
    print(dump(data))
    local online_data = {}
    for _,d in ipairs(G_GAME_NAME_LIST) do
        local info = data[d.id .. ""]
        table.insert(online_data, {
            game_name = d.name,
            online_count = info and table.count(info) or 0,
            mode = data.mode or "未知",
            time = os.time(),
        })
    end
    -- for gameid, value in pairs(data) do
    --     local id = tonumber(gameid)
    --     if id then
    --         local game_name = G_GAME_NAME[id]
    --         if game_name then
    --             table.insert(online_data,{
    --                 game_name = game_name,
    --                 online_count = table.count(value),
    --                 mode = data.mode or "未知",
    --                 time = os.time(),
    --             })
    --         end
    --     end
    -- end
    local jdata = msgpack.encode(online_data)
    local idx = skynet.call(".redis","lua","hincrby","monitor_online_data" , data.mode .. "_idx" ,1)
    local ops = {}
    table.insert(ops, {"hset", "monitor_online_data", data.mode, jdata})
    table.insert(ops, {"hset", "monitor_online_history_data:" .. data.mode, idx , jdata})
    -- end
    --保留10000条
    idx = idx - 10000
    if idx > 0  then
        table.insert(ops, {"hdel","monitor_online_history_data:" .. data.mode, idx})
    end
    skynet.call(".redis","lua","pipeline",ops,{})
	return 200
end


REQUEST["/monitor/set/system"] = function(path, method, header, body, query)
    if method ~= "POST" then return 405 end
    local data = cjson.decode(body)
    if not data then
        return 400
    end
    if not data.mode then
        return 400
    end
    data.time = os.time()
    -- 这里替换为从游戏服务器获取真实数据
	-- local data = {
	-- 	{server_id = 1, server_name = "主游戏服务器", status = "online", uptime = "12天4小时", cpu = "32%", memory = "45%"},
	-- 	{server_id = 2, server_name = "数据库服务器", status = "online", uptime = "8天2小时", cpu = "18%", memory = "60%"},
	-- 	{server_id = 3, server_name = "登录服务器", status = "offline", uptime = "0", cpu = "0%", memory = "0%"}
	-- }
    
    local jdata = msgpack.encode(data)
    local idx = skynet.call(".redis","lua","hincrby","monitor_system_data" , data.mode .. "_idx" ,1)
    local ops = {}
    table.insert(ops, {"hset", "monitor_system_data", data.mode, jdata})
    table.insert(ops, {"hset", "monitor_system_history_data", data.mode, idx , jdata})
    --保留10000条
    idx = idx - 10000
    if idx > 0  then
        table.insert(ops, {"hdel", "monitor_system_history_data" .. data.mode, idx})
    end
    skynet.call(".redis","lua","pipeline",ops,{})
	return 200
end