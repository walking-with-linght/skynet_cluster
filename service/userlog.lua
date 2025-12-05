local skynet = require "skynet"
require "skynet.manager"

local CMD = {}
local RESPONE = {}
local service_log_config = {}

local TEST_LEVEL			=1--,			//测试 日志
local DEBUG_LEVEL			=2--,			//调试日志
local RELEASE_LEVEL			=3--,			//发布之后的日志
local ERROR_LEVEL			=4--,			//错误日志


G_LEVEL = TEST_LEVEL --默认等级
G_SAVE_LOG = true
G_SERVICE_LIST = {}

G_ALL_LOG = nil
G_ERR_LOG = nil
G_CURR_DATE = nil
G_CURR_HOUR = nil

local L_LOGGER_NAME = ".logger"
local L_LOG_DIR = "log"
local lformat = string.format

local log_head = {
	[TEST_LEVEL]    = "[TEST ]",
	[DEBUG_LEVEL]   = "[DEBUG]",
	[RELEASE_LEVEL] = "[REL  ]",
	[ERROR_LEVEL]   = "[ERROR]",	
}

local function save_log(level, ... )
	local date = os.date("*t")
	if date.yday ~= G_CURR_DATE then
		if G_ALL_LOG then
			G_ALL_LOG:close()
			G_ALL_LOG = nil
		end

		if G_ERR_LOG then
			G_ERR_LOG:close()
			G_ERR_LOG = nil
		end
		G_ALL_LOG = io.open(string.format("%s/%s-%d-%d-%d.log",L_LOG_DIR, skynet.getenv('cluster_name'), date.year,date.month,date.day),"a")
		
		if G_ALL_LOG and G_ERR_LOG then
			G_CURR_DATE = date.yday
		end

		if ERROR_LEVEL <= level then
			G_ERR_LOG = io.open(string.format("%s/%s-%d-%d-%d-err.log",L_LOG_DIR,skynet.getenv('cluster_name'),date.year,date.month,date.day),"a")
		end
	end

	if G_ALL_LOG then
		G_ALL_LOG:write(...)
	end

	if G_ERR_LOG and ERROR_LEVEL <= level then
		G_ERR_LOG:write(...)
		G_ERR_LOG:flush()
	end
end


local function log(source,level, ... )
	if G_LEVEL > level then
		return
	end 
	source = source or 0
	local tt = {string.format("[%s][%s]",skynet.getenv('cluster_name'),os.date("%Y-%m-%d %H:%M:%S")),lformat("[%08x]",source),log_head[level],...}
	local temp = table.concat( tt, " ")
	if G_SAVE_LOG then
		save_log(level,temp,"\r\n")
		print(temp,"\r\n")
	else
		print(temp)
	end
end

G_detect_log_service_client = function ()
	CMD.loglevel(0,G_LEVEL)
	skynet.timeout(100*60*10,function ()
		return G_detect_log_service_client()
	end)
end

skynet.register_protocol {
	name = "text",
	id = skynet.PTYPE_TEXT,
	unpack = skynet.tostring,
	dispatch = function(_, address, msg)
		log(address,RELEASE_LEVEL,"#-#",msg)
	end
}

skynet.start(function()
	do
		pcall(function ()
			local dir = io.open(L_LOG_DIR,"r")
			if not dir then
				os.execute(string.format("mkdir %s",L_LOG_DIR))
			end
		end)
	end

	skynet.dispatch("lua", function(_,address,cmd, ...)
		local f = CMD[cmd]
		if f then
			f(address,...)
		else
			f = RESPONE[cmd]
			if f then
				skynet.ret(skynet.pack(f(address,...)))
			end
		end
	end)
	skynet.register(L_LOGGER_NAME)

	skynet.fork(function ()
		skynet.error(L_LOG_DIR)
		local cmd = string.format("find %s -mtime +2 -name \"*.log\" -exec rm -rf {} \\;",L_LOG_DIR)
		skynet.error(cmd)
		while true do
			pcall(os.execute,cmd)
			skynet.sleep(100*60*60*24 * 30)
		end
	end)
end)

function CMD.loglevel(address,lvl,...)
	log(address,RELEASE_LEVEL,string.format("setloglevel from %x level is %d",address,lvl))
	if TEST_LEVEL <= lvl  and ERROR_LEVEL >= lvl then
		G_LEVEL = lvl
		for address,_ in pairs(G_SERVICE_LIST) do
			skynet.send(address,"lua","loggerlevelupdate")
		end

		G_SERVICE_LIST = {}
	end
end

function CMD.logflush()
	if G_ALL_LOG then
		G_ALL_LOG:flush()
	end

	if G_ERR_LOG then
		G_ERR_LOG:flush()
	end
end

function RESPONE.sync_log_level(address)
	G_SERVICE_LIST[address] = true
	log(address,RELEASE_LEVEL,string.format("sync_log_level %x level is %d",address,G_LEVEL))
	return G_LEVEL
end

function CMD.log(address,level,... )
	log(address,level,...)
end