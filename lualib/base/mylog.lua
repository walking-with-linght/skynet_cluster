local skynet 		= require "skynet"
local string 		= string
local strf 			= string.format

local LOG_DEBUG 	= 1
local LOG_INFO 		= 2
local LOG_NOTICE 	= 3
local LOG_WARNING 	= 4
local LOG_ERROR 	= 5


local mylog = {}

local level = LOG_DEBUG
local traceback = debug.traceback

local header2level = {
	
	[LOG_INFO] 		= "[INFO]",
	[LOG_NOTICE] 	= "[NOTICE]",
	[LOG_WARNING] 	= "[WARNING]",
	[LOG_DEBUG] 	= "[DEBUG]",
	[LOG_ERROR] 	= "[ERROR]",
}

local function setlevel(l)

	level = l
end 

setlevel(level)

function mylog.initLogMode()
	local logmode = skynet.getenv("log_mode")
	if logmode then
		local l = tonumber(logmode)
		if l<LOG_DEBUG or l>LOG_ERROR then
			assert(false,'error log level '..l)
		end
		level=l
		if l == LOG_DEBUG then
			mylog.isDebug = true
		end
	end
end

function mylog.log(priority, format,...)

	if priority < level then return end
	if priority >=  LOG_WARNING then 
		skynet.error(traceback(strf(format,...)))
	else
		skynet.error(strf(format,...))
	end
end

function mylog.debug(format,...)

	mylog.log(LOG_DEBUG, strf("[DEBUG][%s]", SERVICE_NAME) .. format,...)
end

function mylog.info(format,...)

	mylog.log(LOG_INFO, strf("[INFO][%s]", SERVICE_NAME) .. format,...)
end	

function mylog.notice(format,...)

	mylog.log(LOG_NOTICE, strf("[NOTICE][%s]", SERVICE_NAME) .. format,...)
end

function mylog.warn(format,...)

	mylog.log(LOG_WARNING, strf("[WARNING][%s]", SERVICE_NAME) .. format,...)
end

function mylog.error(format,...)

	mylog.log(LOG_ERROR, strf("[ERROR][%s]", SERVICE_NAME) .. format,...)
end	

function mylog.dump(t)
	require "ext.string"
	mylog.isDebug=true
	mylog.debug("%s", string.dump(t))
end

function mylog.halt(t, ...)
	
	mylog.dump(t)
	error(...)
end




mylog.initLogMode()

return mylog
