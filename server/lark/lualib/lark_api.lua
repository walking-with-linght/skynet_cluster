local skynet = require "skynet"
local base = require "base"
local cjson = require "cjson"

local DATA = base.DATA --本服务使用的表
local CMD = base.CMD  --供其他服务调用的接口
local PUBLIC = base.PUBLIC --本服务调用的接口
local REQUEST = base.REQUEST

require "httpclient"
local lark_define = require "lark_define"
local _M = {}


--回复消息
function _M.reply(app, message_id, content,msg_type)
    -- https://open.larksuite.com/document/server-docs/im-v1/message/reply
    local host = lark_define.reply_host
    local url = string.format(lark_define.reply_url, message_id)
    
    local token = skynet.call(".lark_token_mgr", "lua", "get_token", app)
    if not token then
        return false, "get token fail"
    end
    local headers = {
        Authorization = "Bearer " .. token,
        ["Content-Type"] = "application/json",
    }
    if type(content) == "table" then
        content = cjson.encode(content)
    end
    local body = {
        content = content,
        msg_type = msg_type or lark_define.default_reply_msg_type,
    }
    local code,ret_body = PUBLIC.http_request(host, url, headers,"POST", body)
    if code ~= 200 then
        return false, "reply fail"
    end
    return true
end

-- 主动发送消息
function _M.send_message(app, content,msg_type,receive_id_type,receive_id)
    receive_id_type = receive_id_type or lark_define.send_message_default_receive_id_type
    receive_id = receive_id or lark_define.send_message_default_receive_id
    -- https://open.larksuite.com/document/server-docs/im-v1/message/create
    local host = lark_define.send_message_host
    local url = string.format(lark_define.send_message_url, receive_id_type)
    local token = skynet.call(".lark_token_mgr", "lua", "get_token", app)
    if not token then
        return false, "get token fail"
    end
    local headers = {
        Authorization = "Bearer " .. token,
        ["Content-Type"] = "application/json",
    }
    if type(content) == "table" then
        content = cjson.encode(content)
    end
    local body = {
        receive_id = receive_id,
        msg_type = msg_type or lark_define.default_reply_msg_type,
        content = content,
    }
    local code,ret_body = PUBLIC.http_request(host, url, headers,"POST", body)
    if code ~= 200 then
        return false, "send message fail"
    end
    return true
end

return _M

