local skynet = require "skynet"
require "skynet.manager"
local base = require "base"

local CMD = base.CMD
local REQUEST = base.REQUEST
local PUBLIC=base.PUBLIC
local DATA = base.DATA


skynet.start(function()
	
    

	-- local addr = skynet.uniqueservice("redis_discover")
	-- skynet.call(addr,"lua","start")
	local console_port = skynet.getenv("console_port")
    if console_port then
        skynet.newservice("debug_console",console_port)
    end
	skynet.newservice("lark_deal_msg")
	skynet.newservice("lark_token_mgr")
	
    local nodename = skynet.getenv("webport")
    --开启web服务
	local http_watchdog = skynet.newservice("http_watchdog")
	skynet.send(http_watchdog,"lua","start",{
		protocol = "http",
		agent_cnt = 5,
		port = nodename,
		handle = "router"
	})



	local addr = skynet.uniqueservice("redis_discover")
	skynet.call(addr,"lua","start")

	skynet.exit()
end)