
local skynet = require "skynet"



local base = require "base"
require "moon.deepseek"
local lark_define = require "lark_define"


local DATA = base.DATA --本服务使用的表
local CMD = base.CMD  --供其他服务调用的接口
local PUBLIC = base.PUBLIC --本服务调用的接口
local REQUEST = base.REQUEST

DATA.chat_text = {
    ["当前服务器时间"] = "获取当前服务器时间",
    ["命令列表"] = "获取命令列表",
}

PUBLIC["当前服务器时间"] = function(content)
    local ret = {
        text = "当前服务器时间：" .. os.date("%Y-%m-%d %H:%M:%S"),
    }
    return ret,lark_define.default_reply_msg_type
end

PUBLIC["命令列表"] = function(content)
    local command_list = {}
    for k, v in pairs(DATA.chat_text) do
        table.insert(command_list, k .. "：" .. v)
    end
    local ret = {
        text = table.concat(command_list, "\n"),
    }
    return ret,lark_define.default_reply_msg_type
end

PUBLIC["当前余额"] = function(content)
    local ok, result = PUBLIC.check_deepseek_balance()
    if ok and result then
        --[[
             print("是否有余额:", result.is_available)
            print("货币类型:", result.currency)  -- 快捷访问
            print("总余额:", result.total_balance)
            print("赠金余额:", result.granted_balance)
            print("充值余额:", result.topped_up_balance)
            
        ]]
        if result.is_available then
            local ret = {
                text = "当前余额：" .. result.total_balance .. "，赠金余额：" .. result.granted_balance .. "，充值余额：" .. result.topped_up_balance,
            }
            return ret,lark_define.default_reply_msg_type
        else
            local ret = {
                text = "当前没有余额",
            }
            return ret,lark_define.default_reply_msg_type
        end
    end
    return false,"当前余额获取失败"
end