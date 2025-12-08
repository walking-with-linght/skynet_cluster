local skynet = require "skynet"

local LogFile = {}

local TEST_LEVEL			=1--,			//测试 日志
local DEBUG_LEVEL			=2--,			//调试日志
local RELEASE_LEVEL			=3--,			//发布之后的日志
local ERROR_LEVEL			=4--,			//错误日志

local LOGGER_NAME = ".logger"
local traceback = debug.traceback

LogFile.level_ = TEST_LEVEL

-- ANSI 颜色代码
local ESC = string.char(27, 91)
local RESET = ESC .. '0m'

-- 检测是否支持颜色输出（针对 Ubuntu 和 Mac 平台）
local function supports_color()
    local platform = skynet.getenv("platform")
    
    -- Windows 平台不支持 ANSI 颜色
    if platform == "windows" then
        return false
    end
    
    -- 检测 TERM 环境变量
    -- 如果 TERM 存在且不是 "dumb"，通常支持颜色
    local ok, term = pcall(os.getenv, "TERM")
    if ok and term and term ~= "dumb" then
        return true
    end
    
    -- macOS 平台默认支持颜色
    if platform == "darwin" or platform == "macos" then
        return true
    end
    
    -- Ubuntu/Linux 平台默认支持颜色
    if platform == "linux" or not platform then
        return true
    end
    
    -- 其他 Unix 系统默认支持
    return true
end

local COLOR_ENABLED = supports_color()

-- 日志级别对应的颜色
local LOG_COLOR = {
    [TEST_LEVEL]    = ESC .. '36m',  -- 青色 (Cyan)
    [DEBUG_LEVEL]   = ESC .. '34m',  -- 蓝色 (Blue)
    [RELEASE_LEVEL] = ESC .. '32m',  -- 绿色 (Green)
    [ERROR_LEVEL]   = ESC .. '31m',  -- 红色 (Red)
}

-- 为日志消息添加颜色
local function add_color(level, msg)
    if not COLOR_ENABLED then
        return msg
    end
    local color_code = LOG_COLOR[level]
    if not color_code then
        return msg
    end
    return color_code .. msg .. RESET
end

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
		
		-- 发送日志数据到 logger 服务
		-- 注意：颜色支持在 userlog.lua 中实现，这里只发送原始数据
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