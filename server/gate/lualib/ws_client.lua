local skynet = require "skynet"
local basefunc = require "basefunc"
local base = require "base"
local websocket = require "http.websocket"
local sharetable = require "skynet.sharetable"
local error_code = require "error_code"
-- local sprotoloader = require "sprotoloader"
-- local sproto_core = require "sproto.core"
local cjson = require "cjson"
local cluster = require "skynet.cluster"
-- local ProtoIDs = require "ProtoIDs"
local gzip = require "gzip"
local protoloader
local sprotoloader

local _AuthInterval = 50 -- connect 到 auth 的间隔

local notice_login_time = 3

local client = basefunc.class()
-- 本连接处理的请求
client.req = {}

local protocol = skynet.getenv("protocol") == "protobuf3"

local CMD = base.CMD
local PUBLIC = base.PUBLIC
local DATA = base.DATA

-- 协议解包/打包
local proto_pack, proto_unpack
-- 登录服节点
-- client 对象的 id ，在当前 gate agent 中唯一
local last_client_id = 0

function client.init()

    -- client.load_sproto()

    CMD.reload_protocol()
end

function CMD.reload_protocol()
    if protocol == "json" then
        proto_pack = function(cmd, data, session, prefix)
            return cjson.encode({name = cmd, msg = data, session = session, prefix = prefix})
        end
        proto_unpack = function(msg) return cjson.decode(msg) end
    end
    if protocol == "sproto" then
        sprotoloader = sprotoloader or require "sprotoloader"
        local host = sprotoloader.load(SPROTO_SLOT.RPC):host "package"
        local attach = host:attach(sprotoloader.load(SPROTO_SLOT.RPC))

        proto_pack = function(cmd, data, session, prefix)
            session = session or 1
            return attach(cmd, data, session)
        end
        proto_unpack = function(msg) return host:dispatch(msg) end
    end
    if protocol == "protobuf3" then
        protoloader = protoloader or require "proto/proto3/protobuf3_helper"
        local host = protoloader.new({pbfiles = sharetable.query("pbprotos")})
        proto_pack = function(cmd, data, session, prefix)
            return host:pack_message(cmd, data, session, prefix)
        end
        proto_unpack = function(msg, sz, prefix, need_unpack)
            return host:dispatch(msg, sz, prefix, need_unpack)
        end
    end
end
-- 解包协议
function CMD.unpack_message(msg, sz, prefix, need_unpack)
    return proto_unpack(msg, sz, prefix, need_unpack)
end
-- 打包协议
function CMD.pack_message(cmd, data, session, prefix)
    return proto_pack(cmd, data, session, prefix)
end

function client:ctor()

    last_client_id = last_client_id + 1
    self.id = last_client_id

end
-- 生成随机密钥
local function generate_secret_key()
    local chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local key = ""
    for i = 1, 16 do
        local idx = math.random(1, #chars)
        key = key .. string.sub(chars, idx, idx)
    end
    return key
end

-- 连接的时候调用
function client:on_connect(fd, addr)

    self.fd = fd

    self.ip = string.gsub(addr, "(:.*)", "")

    self:print_log("new client", fd, addr)

    -- 首次连接时间
    self.auth_time_out = os.time() + _AuthInterval

    self.auth = false

    self.gate_link = {
        node = skynet.getenv("cluster_type"),
        agent = skynet.self(),
        fd = self.fd,
        ip = self.ip,
        id = self.id,
    }

    -- 用于匹配发回 response 的 id
    self._last_responeId = 0

    -- 发回的 response 暂存: response id => response
    self.responses = {}

    -- 请求的名称缓存： response id => name
    self.req_names = {}

    -- 接受消息时间记录： response id => time
    self.req_time = {}

    -- 玩家 agent 的 service id
    self.player_agent_id = nil

    -- 玩家agent 连接
    self.agent_link = nil

    -- 登录 id，登录成功后有效
    self.login_id = nil

    -- 上次发送login消息时间
    self.login_time = nil

    -- 用户 id，登录成功后有效
    self.pid = nil

    -- 消息序号
    self._request_number = 0

    -- 在此时间后才处理此玩家消息
    self._forbid_request_time = nil

    -- 连接已断开
    self._dis_connected = false

    -- 已经禁止收数据
    self._forbid_request = false

    -- 消息限制计数器
    self.__limit_request_counter = 0

    -- 等待踢出
    self._wait_kick = false

    -- 通讯密码
    self.proto_key = nil

    -- 发送通信密钥
    local secret_key = generate_secret_key()
    self.proto_key = secret_key
    skynet.timeout(100, function()
        local msg = cjson.encode({ code = 0,seq = 0, name = "handshake", msg = { key = secret_key}})
        local comp = gzip.deflate(msg)
        websocket.write(self.fd, comp, "binary")
    end)

end
-- 断开的时候调用
function client:on_disconnect()
    self._dis_connected = true
    if self.game_link then
        cluster.send(self.game_link.node,"agent_manager","disconnect",self.pid,self.rid)
    end

end

-- 游戏服创建好了agent
function client:update_game_agent(agent, rid)

    self.game_link.agent = agent
    self.rid = rid
    rlog("更新玩家agent和所选角色rid",agent, rid)
end

function client:send_package(pack)

    if string.len(pack) <= 0 then return end

    if self.fd then

        -- if self.proto_key and string.len(pack) > 0 then
        -- 	pack = sproto_core.xteaencrypt(pack,self.proto_key)
        -- end

        -- local package = string.pack(">s2", pack)
        -- print("websocket 发送消息", #pack)
        websocket.write(self.fd, pack, "binary")
    end
end

function client:print_log(_info, ...)
    rlog(string.format("[cli-%d#%d]", self.id or 0, self.fd or 0) ..
              tostring(_info), ...)
end

function client:gen_response_id(_req_name, _resp)

    print("self._last_responeId", self._last_responeId, self.id)
    assert(self._last_responeId)
    self._last_responeId = self._last_responeId + 1
    local _responeId = self._last_responeId

    self.responses[_responeId] = _resp
    self.req_names[_responeId] = _req_name
    self.req_time[_responeId] = skynet.now()

    return _responeId
end

function client:del_response_id(_response_id)
    if _response_id then
        self.responses[_response_id] = nil
        self.req_names[_response_id] = nil
        self.req_time[_response_id] = nil
    end
end

function client:check_responses()

    -- 移除过期的

    local _remove
    local _now = skynet.now()
    local _timeout_cfg = 2000 -- 单位： 0.01 秒
    for k, v in pairs(self.req_time) do
        if _now - v > _timeout_cfg then
            _remove = _remove or {}
            table.insert(_remove, k)
        end
    end

    if _remove then
        for _, v in ipairs(_remove) do self:del_response_id(v) end
    end
end

-- 记录消息日志
-- 参数 _type ： 类型：  "request_c2s" , "request_s2c", "response_s2c"
function client:log_msg(_type, _name, _data, responeId)
    print("log_msg", _type, _name, _data, responeId)
    local _t_diff = -1
    if self.req_time[responeId] then
        _t_diff = skynet.now() - self.req_time[responeId]
        if _t_diff > 300 then
            elog("message reponse time too long:",
                     string.format("type=%s, msg='%s',t=%s,response id=%s:",
                                   _type, _name, _t_diff, responeId or 0) ..
                         cjson.encode(_data))
        end
    end

    -- -- 心跳需要主动配置（因为太频繁）
    -- if _name == "heartbeat" then
    --     return
    -- end

    -- if not skynet.getenv("network_error_debug") then
    -- 	return
    -- end

    -- if not skynet.getenv("log_all_msg") then
    --     local _no_log = nodefunc.get_global_config("debug_no_log")
    --     if _no_log and _no_log[_name] then
    --         return
    --     end
    -- end

    self:print_log(string.format("[gate msg] %s '%s' t(%s) #%s:", _type, _name,
                                 _t_diff, responeId or 0) .. cjson.encode(_data))
end

--[[
发送消息响应包
默认 会 清除 response id 信息（除非强制 设置 _not_del_id=true）
--]]
function client:send2client(cmd, _data, resp_id)

    print("send_to_client_s2c", cmd, cjson.encode({_data}), resp_id)
    if sproto and self.responses[resp_id] then
        self:send_response(resp_id, _data)
    else
        local ecode,msg = CMD.pack_message(cmd, _data, resp_id)
        if ecode == error_code.success then
            self:send_package(msg)
        end
    end
end

function client:response2client(cmd, _data, resp_id)
    -- if ProtoIDs[cmd].response_id then
    --     self:send2client(ProtoIDs[cmd].response_id, _data, resp_id)
    -- else
        elog("消息没有设置回包ID",cmd)
    -- end
end

function client:send_error_code(erro_code)
    assert(erro_code)
    self:send2client("error_code", {result = erro_code})
end


-- 来自客户端的请求
function client:on_request(msg, sz)
    -- msg = string.unpack(">s2", msg)
    sz = #msg
    print("on_request self._last_responeId", self._last_responeId, self.id)
    if self._forbid_request_time and self._forbid_request_time > 0 then
        if self._forbid_request_time < os.time() then return end
        self._forbid_request_time = nil
    end
    -- 如果有加密，这里就需要解密了
    -- if self.proto_key and sz > 0 then
    -- 	sproto_core.xteadecrypt_c(self.proto_key,msg,sz)
    -- end
    -- 如果是sproto，返回结果应该是ok,type,name,args,response
    -- 如果是proto3，返回结果应该是ok,nil,name,args,session
    local ok, err_code, name, args, response = pcall(CMD.unpack_message, msg, sz)
    local _resp_id

    if sproto then _resp_id = self:gen_response_id(name, response) end

    if not ok then
        self._forbid_request = true
        self._wait_kick = true
        elog("协议错误",err_code, self.pid)
        return
    end

    if err_code ~= error_code.success then
        elog("协议解析错误",err_code, self.pid)
        self._forbid_request = true
        self._wait_kick = true
        return
    end

    if self._forbid_request then
        self:response2client(name, {result = error_code.forbid_network}, _resp_id)
        self._wait_kick = true
        rlog("禁止请求协议",self.id, self.pid)
        return
    end
    -- if tp == "RESPONSE" then
    --     self:send_error_code(10012)
    --     self._forbid_request = true
    --     self._wait_kick = true
    --     elog("不支持服务器下发消息的回包")
    --     return
    -- end
    if name ~= "heartbeat" then
    	dlog("收到消息",cjson.encode({name,args}))
    end

    if self.auth == false then

        self.auth = true

        if name ~= "c2s_login" then
            elog("第一条消息必须是c2s_login",self.id)
            self._forbid_request = true
            self._wait_kick = true
            return
        end

        if not args.token then
            self:response2client(name, {result = error_code.token_invalid}, _resp_id)
            return
        end

        local err_code,data, roles = skynet.call("token_manager","lua","check_token",args.token,self.gate_link)
        if err_code ~= error_code.success then
            elog("token验证失败",err_code, self.pid)
            self:response2client(name, {result = err_code}, _resp_id)
            self._forbid_request = true
            self._wait_kick = true
            return
        end
        self.pid = data.pid
        self.game_link = data.game_link
        self.auth_time_out = nil
        self:response2client(name, {result = error_code.success, roles = roles}, _resp_id)
        return
    end

    if self.game_link then
        local ok, result = xpcall(client.dispatch_request,
                                  basefunc.error_handle, self, name, args,
                                  _resp_id)
        if not ok then
            self:print_log("call dispatch_request error:", result)
        end
        
    end


end

function PUBLIC.get_remaining_time(remaining_count)
    local remaining_time = math.abs(math.ceil(remaining_count / 10)) -- 向上取整  10 = login_manager.lua中的 max_accept_login * 2
    return remaining_time, remaining_count
end

-- 更新函数（1 秒）
function client:update(dt)

    if self._wait_kick then
        self:print_log("client kick", self.id)
        -- skynet.send(DATA.gate,"lua","kick",self.fd)
        self._wait_kick = false
        CMD.kick_client(self.id, true)
        return
    end

    -- if self.login_id and self.login_time and (os.time() - self.login_time) >
    --     notice_login_time then
    --     print("正在排队", self.id, DATA.login_deal_index,
    --           DATA.login_deal_index < self.login_id)
    --     if DATA.login_deal_index and DATA.login_deal_index < self.login_id then
    --         self:send2client("login_queue", {
    --             remaining_count = PUBLIC.get_remaining_time(
    --                 self.login_id - DATA.login_deal_index),
    --             remaining_time = 10004
    --         })
    --     end
    -- end
    -- 每 5 秒 update
    if os.time() - (self.__last_update5 or 0) >= 5 then
        self.__last_update5 = os.time()
        self:update5(dt)
    end

    self:check_login_timeout()
end

-- 更新函数（5 秒）
function client:update5(dt)

    self.__limit_request_counter = 0
    self:check_responses()

end

-- 登录N秒后没有消息，直接踢
function client:check_login_timeout()
    -- 进入登录排队的除外
    if self.auth_time_out and os.time() >
        self.auth_time_out then
        self._forbid_request = true
        rlog("长时间未登录，踢人",self.id)
        self._wait_kick = true
    end
end
--[[
发送消息响应包
默认 会 清除 response id 信息（除非强制 设置 _not_del_id=true）
--]]
function client:send_response(_resp_id, _data, _not_del_id)
    local _resp = self.responses[_resp_id]
    print("服务器回包", _resp_id, _data, _not_del_id, _resp)
    if _resp then

        self:log_msg("response_s2c", tostring(self.req_names[_resp_id]), _data,
                     _resp_id)
        if _data then self:send_package(_resp(_data)) end
    end

    if not _not_del_id then self:del_response_id(_resp_id) end
end

-- 客户端消息分发
function client:dispatch_request(name, args, _resp_id)

    if self._forbid_request or self._dis_connected then return end

    self._request_number = self._request_number + 1

    -- 客户端发送请求太频繁，则断开
    self.__limit_request_counter = (self.__limit_request_counter or 0) + 1
    if self.__limit_request_counter >= DATA.max_request_rate then

        elog(string.format(
                           "error:request too much , max is %d ,but %d!",
                           DATA.max_request_rate, self.__limit_request_counter))
        self:response2client(name, {result = error_code.msg_times_limit}, _resp_id)
        self._wait_kick = true
        self._forbid_request = true
        return
    end

    local _func = client.req[name]

    local ok, continue_transmit = true, true
    if _func then
        ok, continue_transmit = pcall(_func, self, args)
        if not ok then
            elog("网关预处理报错", continue_transmit)
        end
    end
    if continue_transmit then
        if self.game_link then
            if self.game_link.agent then
                cluster.send(self.game_link.node, self.game_link.agent, "request",
                     self.pid, name, args, _resp_id)
            else
                cluster.send(self.game_link.node, "agent_manager", "request",
                     self.pid, name, args, _resp_id)
            end
        end
    end

end

----------------------网关预处理------------------------------------------
-- 返回true时消息继续转发到agent

function client.req:client_breakdown_info(_response_id, data) end

return client
