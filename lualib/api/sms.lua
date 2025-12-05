
local base = require "base"
local DATA = base.DATA     --本服务使用的表
local CMD = base.CMD       --供其他服务调用的接口
local PUBLIC = base.PUBLIC --本服务调用的接口
require "httpclient"

local M = {}

-- 发送短信验证码
-- 短信宝 https://console.smsbao.com/
function M.send_sms_bao(phone,code)
    local api_key = "bc3a3**********f2df0f9c4"
    local host = "https://api.smsbao.com"
    local url = "/sms?"
    --
    local content = string.format("【乐商博】您的验证码是%s。如非本人操作，请忽略本短信。", code)
    
    local code,body = PUBLIC.http_request(host,url .. array_to_get_params(
        { 
            u = "654****0",
            p = api_key,
            m = phone,
            c = content,

        }))
    print("send_sms_bao",phone,code, code, body)

    if code == 200 and body == "0" then
        return true
    end
end

return M