local skynet = require "skynet"
local cluster = require "skynet.cluster"
require "skynet.manager"
local utils = require "utils"

skynet.start(function()
    print('http start')
    -- local nodename = skynet.getenv("nodename")
    -- assert(nodename)

    local console_port = skynet.getenv("console_port")
    if console_port then
        skynet.newservice("debug_console",console_port)
    end

    -- cluster.open(nodename)

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