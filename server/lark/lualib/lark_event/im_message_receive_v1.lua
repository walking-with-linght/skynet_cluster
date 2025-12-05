
local skynet = require "skynet"
local base = require "base"
local cjson = require "cjson"
local lark_api = require "lark_api"

local DATA = base.DATA --本服务使用的表
local CMD = base.CMD  --供其他服务调用的接口
local PUBLIC = base.PUBLIC --本服务调用的接口
local REQUEST = base.REQUEST
require "moon.deepseek"
require "lark_event.chat_text"
local lark_define = require "lark_define"

local callback_node = skynet.getenv("cluster_type")
local callback_service = ".lark_deal_msg"
local callback_method = "on_deepseek_result"

function CMD.on_deepseek_result(ok,result)
    print("on_deepseek_result",dump({ok,result}))
    if ok and result then
        lark_api.send_message(lark_define.robot, { text = result.content }, lark_define.default_reply_msg_type)
    else
        lark_api.send_message(lark_define.robot, { text = "DeepSeek chat fail" }, lark_define.default_reply_msg_type)
    end
end

function PUBLIC.p2p(body)
    print("p2p",type(body))
    -- p2p 只允许特定某人发送消息
    local sender_open_id = body.event.sender.sender_id.open_id
    if sender_open_id ~= lark_define.admin_openid then
        print("sender_open_id not allowed",sender_open_id)
        return false,"sender_open_id not allowed"
    end
    local message_type = body.event.message.message_type
    if not lark_define.allow_msg_type[message_type] then
        print("message_type not allowed",message_type)
        return false,"message_type not allowed"
    end
    local content = cjson.decode(body.event.message.content)
    local text = string.trim(content.text or "")
    if not text or text == "" then
        return false,"text is empty"
    end
    local f = PUBLIC[text]
    if f then
        local ok,ret,tp = pcall(f,content)
        if ok and ret then
            lark_api.reply(lark_define.robot, body.event.message.message_id, ret, tp)
            return true
        else
            lark_api.reply(lark_define.robot, body.event.message.message_id, { text = ret }, lark_define.default_reply_msg_type)
            return false,ret
        end
    else
        print("text not found",text)
        -- 没找到就直接调 DeepSeek 回答
        local ok, result = PUBLIC.deepseek_chat_async(text, 
            "deepseek-chat", nil, callback_node, callback_service, callback_method)
        -- print("DeepSeek chat",dump(result),type(result))
        if ok  then
            -- lark_api.send_message(lark_define.robot, { text = result.content }, lark_define.default_reply_msg_type)
            return true
        else
            lark_api.send_message(lark_define.robot, { text = "DeepSeek chat fail" }, lark_define.default_reply_msg_type)
            return false,"DeepSeek chat fail"
        end
    end
end

function PUBLIC.group(body)
    return false,"group not supported"
end

local function deal(body)
    -- 验证对方是否合法
    local app_id = body.header.app_id
    if app_id ~= lark_define.app_id then
        skynet.error("app_id not found",app_id)
        return false,"app_id not found"
    end
    local create_time = body.header.create_time
    local now = os.time() * 1000 -- 毫秒
    if now - create_time > lark_define.default_msg_timeout then
        skynet.error("timeout, please retry",now,create_time)
        return false,"timeout, please retry"
    end
    -- p2p group
    local chat_type = body.event.message.chat_type
    if PUBLIC[chat_type] then
        return PUBLIC[chat_type](body)
    else
        return false,"chat_type not found"
    end
end
return deal