local skynet = require "skynet"
require "skynet.manager"

skynet.start(function()
    skynet.error('rank start')

    local console_port = skynet.getenv("console_port")
    if console_port then
        skynet.newservice("debug_console",console_port)
    end

    -- 通用排行榜服务
    local addr = skynet.newservice("common_rank")
    local redis_config = {
		host 	= skynet.getenv("rank_redis_host"),
		port 	= skynet.getenv("rank_redis_port"),
		db 		= skynet.getenv("rank_redis_db"),
		auth 	= skynet.getenv("rank_redis_auth"),
	}
    local mysql_config = {
		host 		= skynet.getenv("rank_mysql_host"),
		port 		= skynet.getenv("rank_mysql_port"),
		database 	= skynet.getenv("rank_mysql_db"),
		user 		= skynet.getenv("rank_mysql_user"),
		password 	= skynet.getenv("rank_mysql_pwd"),
	}
    skynet.send(addr,"lua","init",redis_config,mysql_config)


    --提供http接口
    local port = skynet.getenv("rank_webport")
    --开启web服务
	local http_watchdog = skynet.newservice("http_watchdog")
	skynet.send(http_watchdog,"lua","start",{
		protocol = "http",
		agent_cnt = 5,
		port = port,
		handle = "rank"
	})


    -- etcd永远放在最后面
    local addr = skynet.uniqueservice("redis_discover")
	skynet.call(addr,"lua","start")
    skynet.exit()
end)