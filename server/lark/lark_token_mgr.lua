local skynet = require "skynet"
local base = require "base"
local cjson = require "cjson"
local httpclient = require "httpclient"
local lark_define = require "lark_define"
require "skynet.manager"

local CMD = base.CMD
local REQUEST = base.REQUEST
local PUBLIC=base.PUBLIC
local DATA = base.DATA

-- 应用列表
local apps = {
	[lark_define.robot] = {
		app_id = lark_define.app_id,
		app_secret = lark_define.app_secret,
		tenant_access_token = nil,
		expire = nil,-- 过期时间 时间戳，单位秒
	}
}



function PUBLIC.try_get_token(app)
	if not apps[app] then
		return false, "app not found"
	end
	local headers = {
		["Content-Type"] = "application/json; charset=utf-8",
	}
	local body = {
		app_id = apps[app].app_id,
		app_secret = apps[app].app_secret,
	}
	local code,ret_body = PUBLIC.http_request(lark_define.token_host, lark_define.token_url, headers,"POST", body)
	if code ~= 200 then
		print("get token fail",app,code,ret_body)
		-- 获取token失败，重新获取
		-- 看下是否过期，如果没过期就直接返回，下次再获取
		if apps[app].tenant_access_token and
			 apps[app].expire and 
			 (apps[app].expire + lark_define.token_expire) > os.time()  then
			return apps[app].tenant_access_token
		end
		return false, "get token fail"
	end
	--[[
	{
		"code": 0,
		"msg": "ok",
		"tenant_access_token": "t-caecc734c2e3328a62489fe0648c4b98779515d3",
		"expire": 7200
	}
	]]
	if type(ret_body) == "string" then
		ret_body = cjson.decode(ret_body)
	end
	if ret_body.code ~= 0 then
		return false, ret_body.msg
	end
	apps[app].tenant_access_token = ret_body.tenant_access_token
	apps[app].expire = os.time() + ret_body.expire - lark_define.token_expire -- 预留lark_define.token_expire秒
	return apps[app].tenant_access_token
end

function CMD.get_token(app)
	if apps[app].tenant_access_token and apps[app].expire and apps[app].expire > os.time() then
		return apps[app].tenant_access_token
	end
	return PUBLIC.try_get_token(app)
end

skynet.start(function()
	skynet.dispatch("lua", function(_,address, command, ...)
		local f = CMD[command]
        if f then
			skynet.ret(skynet.pack(f(...)))
			return
		else
			elog('err cmd',command)
		end
	end)
	skynet.register(".lark_token_mgr")
end)