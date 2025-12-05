local skynet = require "skynet"

local LogFile = {}

local TEST_LEVEL			=1--,			//测试 日志
local DEBUG_LEVEL			=2--,			//调试日志
local RELEASE_LEVEL			=3--,			//发布之后的日志
local ERROR_LEVEL			=4--,			//错误日志

local LOGGER_NAME = ".logger"
local traceback = debug.traceback

LogFile.level_ = TEST_LEVEL

local function stackinfo()
	local info = debug.getinfo(4, "Sl")
	local source = info.source
	if info.source and string.sub(info.source,1,1)=="@" then
		return source:sub(2),info.currentline
	end
end

local function log(nowlevel,... )
	if LogFile.level_ <= nowlevel then
		local tt = {stackinfo()}
		local temp = {...}
		local data = {}
		local len_tt = #tt
		for i=1,len_tt do
			data[i] = tostring(tt[i])
		end
		for i=1,select("#",...) do
			data[i+len_tt] = tostring(temp[i])
		end
		if nowlevel >= ERROR_LEVEL then
			table.insert(data, 1, traceback())
		end
		skynet.send(LOGGER_NAME,"lua","log",nowlevel,table.unpack(data))
	end
end

function LogFile.Debug( ... )
	log(DEBUG_LEVEL,...)
end


function LogFile.Test( ... )
	log(TEST_LEVEL,...)
end


function LogFile.Err( ... )
	log(ERROR_LEVEL,...)
end

function LogFile.Rel( ... )
	log(RELEASE_LEVEL,...)
end

function LogFile.cmd(cmd,level,...)

end

return LogFile