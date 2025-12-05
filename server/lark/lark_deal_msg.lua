local skynet = require "skynet"
local base = require "base"
local cjson = require "cjson"
local httpclient = require "httpclient"
require "skynet.manager"

local CMD = base.CMD
local REQUEST = base.REQUEST
local PUBLIC=base.PUBLIC
local DATA = base.DATA




function CMD.lark_event(body)
	local event_type = string.gsub(string.lower(body.header.event_type), "%.", "_")
    local deal = require ("lark_event." .. event_type)
    if deal then
        local ok,why = deal(body)
		if not ok then
			skynet.error("deal lark_event failed",why)
		end
    else
        skynet.error("lark_event not found",event_type)
    end
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
	skynet.register(".lark_deal_msg")
end)