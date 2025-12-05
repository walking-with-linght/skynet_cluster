local skynet = require "skynet"
local base = require "base"
local sms = require "api.sms"
local DATA = base.DATA --本服务使用的表
local CMD = base.CMD  --供其他服务调用的接口
local PUBLIC = base.PUBLIC --本服务调用的接口
local REQUEST = base.REQUEST


function PUBLIC.phone_has_reg(phone)
   local phone_account =  skynet.call(".redis", "lua", "hget", "web_phone:" .. phone, "account")
   if not phone_account then
        return false
   end
   return true
end

function PUBLIC.send_phone_code(phone,type)
    local code = string.format("%06d", math.random(0, 999999) )
    if type == "reg" then
        if PUBLIC.phone_has_reg(phone) then
            return { code = 1, messge = "该手机号已被注册!"}
        end
        print("发送短信",phone, code)
        local last_time = skynet.send(".redis","lua","hget","web_phone_code:".. phone, "time")
        if last_time and (os.time() - last_time < 60) then
            return {code = 1, messge = "操作频繁，请稍后再试!"}
        end
        local ok = sms.send_sms_bao(phone,code)
        if ok then
            skynet.send(".redis","lua","hmset","web_phone_code:".. phone,{
                code = code,
                type = type,
                time = os.time(),
            })
            skynet.send(".redis","lua","expire","web_phone_code:".. phone,5 * 60)-- 5 分钟有效
            return {code = 0,sms_code = code}
        end
        return {code = 1,messge = "短信发送失败!"}
    end

end

function PUBLIC.auth_reg_phone(phone,code)
    local data = skynet.call(".redis","lua","hgetall","web_phone_code:".. phone)
    if not data then
        return false, "验证码已过期"
    end
    print(dump({data}),type(data),phone,code)
    if data.type == "reg" and data.code == code then
        skynet.call(".redis","lua","del","web_phone_code:".. phone)
        return true
    end
    return false, "验证码错误"
end