--[[
 $ @Author: 654146770@qq.com
 $ @Date: 2024-06-05 21:52:14
 $ @LastEditors: 654146770@qq.com
 $ @LastEditTime: 2024-07-21 16:39:39
 $ @FilePath: \my_skynet_lib\server\gate_server\logic\service\ws\ws.lua
]]


local skynet = require "skynet"
local base = require "base"
local basefunc = require "basefunc"
require "skynet.manager"
local sessionlib = require "session"
local error_code = require "error_code"
local CMD=base.CMD
local PUBLIC=base.PUBLIC
local DATA=base.DATA
local REQUEST=base.REQUEST

local function send2client(gate_link, data)
    CMD.cluster_send(gate_link.node, gate_link.addr, "send2client", gate_link.client,data)
end


-- 登录
REQUEST["account.login"] = function(data, gate_link)
    print("account.login", dump(data))
    -- 验证用户名和密码
    local username = data.msg.username
    local password = data.msg.password
    local ip = data.msg.ip
    local hardware = data.msg.hardware

    local username_redis_key = string.format("username:%s", username)
    --- 拿到 uid
    local uid = skynet.call(".redis", "lua", "get", username_redis_key)
    if not uid then
        send2client(gate_link, {
            name = "account.login",
            -- msg = {
            -- },
            seq = data.seq,
            code = error_code.account_not_exists,
        })
        return
    end
    local uid_redis_key = string.format("uid:%s", uid)
    local user_data = skynet.call(".redis", "lua", "hmget", uid_redis_key, {"passcode", "passwd", "uid", "username"})
    print(uid_redis_key,"uid_redis_key",dump(user_data))
    if not user_data[1] then
        send2client(gate_link, {
            name = "account.login",
            msg = {
                password = "",
                session = "",
                uid = "",
                username = "",
            },
            seq = data.seq,
            code = error_code.account_not_exists,
        })
        elog("有 uid，但查不到具体账号数据", uid_redis_key)
        return
    end
    local passwd = user_data[2]
    if passwd ~= basefunc.md5(password, user_data[1]) then
        send2client(gate_link, {
            name = "account.login",
            msg = {
                password = "",
                session = "",
                uid = "",
                username = "",
            },
            seq = data.seq,
            code = error_code.password_incorrect,
        })
        return
    end
    local ok,session = sessionlib.generate_session(user_data[3])
    if not ok then
        elog(user_data[3],session)
        return
    end
    print(session,"session")
    skynet.call(".redis", "lua", "hset", uid_redis_key, "session", session)
    send2client(gate_link, {
        name = "account.login",
        msg = {
            password = user_data[2],
            session = session,
            uid = user_data[3],
            username = user_data[4],
            sid = 0,-- 这里设置了好像也没用
        },
        seq = data.seq,
        code = error_code.success,
    })
    -- 写日志，tb_login_last tb_login_history
    -- 但用户只有一条
    skynet.send(".mysql", "lua", "execute", 
        string.format("insert into tb_login_last(uid,login_time,ip,is_logout,hardware,session) value (%d, '%s', '%s', %d, '%s', '%s') on duplicate key update login_time = ''%s, ip = '%s', is_logout = %d,hardware = '%s',session = '%s' ;",
            tonumber(uid),
            os.date('%Y-%m-%d %H:%M:%S'),
            data.ip,
            0, -- 0=登录 1=登出
            hardware,
            session,

            os.date('%Y-%m-%d %H:%M:%S'),
            data.ip,
            0, -- 0=登录 1=登出
            hardware,
            session
        )
    )
    skynet.send(".mysql", "lua", "insert", "tb_login_history", {
        uid = tonumber(uid),
        ctime = os.date('%Y-%m-%d %H:%M:%S'),
        ip = data.ip,
        state = 0, -- 0=登录 1=登出
        hardware = hardware,
    })
    CMD.cluster_send(gate_link.node, gate_link.addr, "update_login_state", gate_link.client, {username = username,uid = uid} , true)
end

function CMD.client_request(data, gate_link)
    print("dispatch_request", data.name, data.msg, data.seq)
    local f = REQUEST[data.name]
    if f then
        local ok, ret = pcall(f, data,gate_link)
        if not ok then
            elog("error", data.name, ret)
        end
    else
        print("command not found", data.name)
    end
end

local function init()
    local ok,ret = skynet.call(".mysql", "lua", "execute", "SELECT MAX(uid) FROM tb_user_info;SELECT MAX(rid) FROM tb_role_1;")
    if ok then
        print(dump(ret))
        local uid_max = ret[1][1]["MAX(uid)"]
        local rid_max = ret[2][1]["MAX(rid)"]
        -- print("uid_max",uid_max)
        -- print("rid_max",rid_max)
        skynet.call(".redis", "lua", "set", "uid_seq", uid_max)
        skynet.call(".redis", "lua", "set", "rid_seq", rid_max)
    end
end

-- 服务主入口
-- skynet.start(function()
--     skynet.dispatch("lua", function(session, _, cmd, ...)
--         local f = CMD[cmd]
--         if not f then
--             skynet.ret(skynet.pack(nil, "command not found"))
--             return
--         end
        
--         local ok, ret,ret2,ret3,ret4 = pcall(f, ...)
--         if not ok then
--             rlog("error",ret)
--         end
--         if session ~= 0 then
--             if ok  then
--                 skynet.retpack(ret,ret2,ret3,ret4)
--             else
--                 skynet.ret(skynet.pack(nil, ret))
--             end
--         end
--     end)
--     skynet.register(".login_manager")
-- end)
base.start_service(".login_manager",nil,init)