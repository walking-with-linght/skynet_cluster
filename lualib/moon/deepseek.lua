local skynet = require "skynet"
local base = require "base"
local CMD = base.CMD
local REQUEST = base.REQUEST
local PUBLIC=base.PUBLIC
local DATA = base.DATA

-- 获取余额
function PUBLIC.check_deepseek_balance()
    local ok, callok,result = CMD.cluster_call_by_type("moon", "deepseek", "get_balance", {})
    
    if ok and callok and result then
        -- local info = {}
        -- print("是否有余额:", result.is_available)
        -- print("货币类型:", result.currency)  -- 快捷访问
        -- print("总余额:", result.total_balance)
        -- print("赠金余额:", result.granted_balance)
        -- print("充值余额:", result.topped_up_balance)
        
        -- -- 或者遍历所有余额信息（支持多币种）
        -- for i, info in ipairs(result.balance_infos) do
        --     print(string.format("余额 %d: %s %s", i, info.currency, info.total_balance))
        -- end
        return true, result
    else
        skynet.error(dump({"check_deepseek_balance fail",result}))
        return false, result
    end
end
-- 聊天--堵塞，需要等 DeepSeek 返回
function PUBLIC.deepseek_chat(text,model,session_id)
    local ok,callok , result = CMD.cluster_call_by_type("moon","deepseek", "chat", {
        -- model = "deepseek-reasoner", --打开则使用reasoner模型
        prompt = text,
        -- session_id = session_id, --会话 id，使用同一个会话id，可以连续对话 ，但只保存 30 分钟
    })
    --[[
    result = {
        content = "回答内容",
        finish_reason = "stop", -- 结束原因
        model = "deepseek-chat", -- 模型
        usage = {
            completion_tokens = 99, -- 完成 token 数
            prompt_tokens = 7, -- 提示 token 数
            total_tokens = 106 -- 总 token 数
        }
    ]]
    if ok and callok and result then
        return true, result
    else
        skynet.error(dump({"deepseek_chat fail",result}))
        return false, result
    end
end

-- 异步，立即返回
function PUBLIC.deepseek_chat_async(text,model,session_id,callback_node,callback_service,callback_method)
    local ok,callok,result =CMD.cluster_send_by_type("moon","deepseek", "chat", {
        -- model = "deepseek-reasoner", --打开则使用reasoner模型 deepseek-reasoner deepseek-chat
        prompt = text,
        -- session_id = session_id, --会话 id，使用同一个会话id，可以连续对话 ，但只保存 30 分钟
        callback_node = callback_node,
        callback_service = callback_service,
        callback_method = callback_method
    })
    --[[
    result = {
        content = "回答内容",
        finish_reason = "stop", -- 结束原因
        model = "deepseek-chat", -- 模型
        usage = {
            completion_tokens = 99, -- 完成 token 数
            prompt_tokens = 7, -- 提示 token 数
            total_tokens = 106 -- 总 token 数
        }
    ]]
    if ok   then
        return true
    else
        skynet.error(dump({"deepseek_chat_async fail",ok,callok,result}))
        return false
    end
end


return PUBLIC