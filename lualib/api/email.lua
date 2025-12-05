
local skynet = require "skynet"
local base = require "base"
local CMD = base.CMD
local M = {}

function M.send_email(email_host,email_port,from, to,authcode,emailclass, code,validity_period)
    local _,success,err = CMD.cluster_call("moon","mail","send_email",{
        email_host = email_host, -- smtp.qq.com
        email_port = tonumber(email_port), -- 465
        from = from,
        to = to,
        authcode = authcode,
        emailclass = emailclass or "新注册账号",
        code = code,
        validity_period = tostring(validity_period) or "5", --有效期5分钟
    })
    if success == "success" then
        return true
    end
    print("邮件发送失败", success,err)
end

function M.send_email_by_qq(to,code,emailclass,validity_period)
    local email_host = skynet.getenv("qq_email_host") -- smtp.qq.com
    local email_port = skynet.getenv("qq_email_port") -- 465
    local from = skynet.getenv("qq_email_from")
    local authcode = skynet.getenv("qq_email_authcode")
    emailclass = emailclass or "新注册账号"
    validity_period = tostring(validity_period) or "5" --有效期5分钟
    return M.send_email(email_host,email_port,from, to,authcode,emailclass, code,validity_period)
end
function M.send_email_by_gmail(to,code,emailclass,validity_period)
    local email_host = skynet.getenv("gmail_email_host") -- smtp.gmail.com
    local email_port = skynet.getenv("gmail_email_port") -- 465
    local from = skynet.getenv("gmail_email_from")
    local authcode = skynet.getenv("gmail_email_authcode")
    emailclass = emailclass or "新注册账号"
    validity_period = tostring(validity_period) or "5" --有效期5分钟
    return M.send_email(email_host,email_port,from, to,authcode,emailclass, code,validity_period)
end

return M