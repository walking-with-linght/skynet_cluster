local skynet = require "skynet"
require "skynet.manager"

skynet.start(function()
    skynet.error('rank start')

    local console_port = skynet.getenv("console_port")
    if console_port then
        skynet.newservice("debug_console",console_port)
    end


    -- etcd永远放在最后面
    local addr = skynet.uniqueservice("redis_discover")
	skynet.call(addr,"lua","start")
    skynet.exit()
end)