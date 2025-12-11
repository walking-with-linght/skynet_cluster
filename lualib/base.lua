local skynet = require "skynet"
local cluster = require "skynet.cluster"
local Timer = require "utils.timer"
local basefunc = require "basefunc"
require "skynet.manager"
local base = {

    -- 供外部服务调用的命令
        CMD = {},
    
        -- 客户端的请求
        REQUEST={},
    
        -- 公共函数
        PUBLIC = {},
    
        -- 公共数据
        DATA = {},
    
        CUR_CMD = {},
    }
    
local CMD=base.CMD
local DATA = base.DATA
local PUBLIC = base.PUBLIC
local CUR_CMD = base.CUR_CMD


-- 得到本地数据 表
function base.LocalData(_module_name,_default)
    local _name = "LD_" .. _module_name
    DATA[_name] = DATA[_name] or _default or {}
    return DATA[_name]
end

-- 得到本地函数 表
function base.LocalFunc(_module_name,_default)
    local _name = "LF_" .. _module_name
    PUBLIC[_name] = PUBLIC[_name] or _default or {}
    return PUBLIC[_name]
end

---- add by wss
--- 操作锁
DATA.action_lock = DATA.action_lock or {}
--- 打开 操作锁,   ！！！！ player_id 不传用于agent；player_id要传用于中心服务
function PUBLIC.on_action_lock( lock_name , player_id )
    if player_id then
        DATA.action_lock[lock_name] = DATA.action_lock[lock_name] or {}
        DATA.action_lock[lock_name][player_id] = true
    else
        DATA.action_lock[lock_name] = true
    end
end
--- 关闭锁
function PUBLIC.off_action_lock( lock_name , player_id )
    if player_id then
        DATA.action_lock[lock_name] = DATA.action_lock[lock_name] or {}
        DATA.action_lock[lock_name][player_id] = nil
    else
        DATA.action_lock[lock_name] = nil
    end
end
--- 获得锁
function PUBLIC.get_action_lock( lock_name , player_id )
    if player_id then
        return DATA.action_lock[lock_name] and DATA.action_lock[lock_name][player_id]
    else
        return DATA.action_lock[lock_name]
    end
end

local function real_load(_text,_name)

	if not _text or "" == _text then
		error("exe_lua error:_text is empty!",2)
	end

	_name = _name or ("code:" .. string.gsub(string.sub(_text,1,50),"[\r\n]"," "))

	local chunk,err = load(_text,_name)
	if not chunk then
		error(string.format("exe_lua %s error:%s ",_name,tostring(err)),2)
	end

	return chunk() or true

end

function base.CMD.exe_lua_base(_text,_name)
	local _err_stack

	local ok,msg = xpcall(
		function()
			local _ret = real_load(_text,_name)
			if type(_ret) == "table" then
				if _ret.on_load then
					return _ret.on_load()
				end
			elseif type(_ret) == "function" then
				return _ret()
			else
				return "lua loaded!"
			end
		end,
		function(_msg)
			_err_stack = debug.traceback()
			return _msg
		end
	)

	if ok then
		return true,msg
	else
		return false,tostring(msg) .. ":\n" .. tostring(_err_stack)
	end
end

function base.CMD.exe_lua(_text,_name)

	local _,msg = base.CMD.exe_lua_base(_text,_name)

	-- 返回值 丢弃是否错误
	return msg
end

-- 热更新的入口，call addr exe_file filename
function base.CMD.exe_file(_file)
    local _text
	local f = io.open(_file)
	if f then
		if _VERSION == "Lua 5.3" then
			_text = f:read("a")
		else
			_text = f:read("*a")
		end

		f:close()
	end
    if _text then
	    return base.CMD.exe_lua(_text,_file)
    end
end


local function cmd_get_args(...)
	if select("#") > 0 then
		return table.pack(...)
	else
		return nil
	end
end

local _service_start_stack_info

-- 默认的消息分发函数
function base.default_dispatcher(session, source, cmd, subcmd, ...)
	local f = CMD[cmd]

	CUR_CMD.session = session
	CUR_CMD.source = source
	CUR_CMD.cmd = cmd
	CUR_CMD.subcmd = subcmd
	CUR_CMD.args = cmd_get_args(...)

	if f then
		if session == 0 then
			local ok,msg = xpcall(function(...) f(subcmd, ...) end,basefunc.error_handle,...)
			if not ok then
				local _err_str = string.format("send :%08x ,session %d,from :%08x,CMD.%s(...)\n error:%s\n >>>> param:\n%s ",skynet.self(),session,source,cmd,tostring(msg),basefunc.tostring({subcmd, ...}))
				print(_err_str)
				error(_err_str)
			end
		else
			local ok,msg,sz = xpcall(function(...) return skynet.pack(f(subcmd, ...)) end,basefunc.error_handle,...)
			if ok then
				skynet.ret(msg,sz)
			else
				local _err_str = string.format("send :%08x ,session %d,from :%08x,CMD.%s(...)\n error:%s\n >>>> param:\n%s ",skynet.self(),session,source,cmd,tostring(msg),basefunc.tostring({subcmd, ...}))
				print(_err_str)
				error(_err_str)
			end
		end
	else
		local _err_str
		if _service_start_stack_info then
			_err_str = string.format("call :%08x ,session %d,from :%08x ,error: command '%s' not found.\nservice start %s",skynet.self(),session,source,cmd,_service_start_stack_info)
		else
			_err_str = string.format("call :%08x ,session %d,from :%08x ,error: command '%s' not found.",skynet.self(),session,source,cmd)
		end
		elog(_err_str)
		error(_err_str)
		-- if session ~= 0 then
		-- 	skynet.ret(skynet.pack("CALL_FAIL"))
		-- end
	end
end
local default_dispatcher = base.default_dispatcher

-- 启动服务
-- 参数:
-- 	_dispatcher    （可选） 协议分发函数
-- 	_register_name （可选） 注册服务名字

function base.start_service(_register_name,_dispatcher,_on_start)

	-- 记录栈信息，以便在找不到命令是，输出上层文件信息
	_service_start_stack_info = debug.traceback(nil,2)

	skynet.start(function()

		if type(_on_start) == "function" then
			if _on_start() then -- 返回 true 表示 自己处理完，系统不要再处理
				return
			end
		end

		skynet.dispatch("lua", _dispatcher or default_dispatcher)

		if _register_name then
			skynet.register(_register_name)
		end

	end)

end


-- 当前状态 ： 含义参见 try_stop_service 函数
base.DATA.current_service_status = "running"
base.DATA.current_service_info = nil 			-- 说明信息

--[[
尝试停止服务：在这个函数中执行关闭前的事情，比如保存数据
（这里是默认实现，服务应该根据需要实现这个函数）
参数 ：
	_count 被调用的次数，可以用来判断当前是第几次尝试
	_time 距第一次调用以来的时间
返回值：status,info
	status
		"free"		自由状态。没有缓存数据需要写入，可以关机。
		"stop"	    已停止服务，可以关机
		"runing"	正在运行，不能关机
		"wait"      正在关闭，但还未完成，需要等待；
		            如果返回此值，则会一直调用 check_service_status 直到结果不是 "wait"
	info  （可选）可以返回一段文本信息，用于说明当前状态（比如还有 n 个玩家在比赛）
 ]]
function base.PUBLIC.try_stop_service(_count,_time)
	-- 5 秒后允许关闭
	if _time < 5 then
		return "wait",string.format("after %g second stop!",5 - _time)
	else
		return "stop"
	end
end

-- 得到服务状态
function CMD.get_service_status()
	return base.DATA.current_service_status,base.DATA.current_service_info
end

-- 供调试控制台列出所有命令
function CMD.incmd()
	local ret = {}
	for _name,_ in pairs(CMD) do
		ret[#ret + 1] = _name
	end

	table.sort(ret)
	return ret
end

--[[
关闭服务
	返回执行此命令后的状态
返回值：
	参见 try_stop_service

注意： 如果 返回 "stop" 则在返回后 会立即退出（后续不要再调用此服务）
	2024年09月11日15:24:01  有用到，refd
 ]]
local _last_command_running = false
function CMD.stop_service()

	-- 最近一次还正在执行，则直接返回结果
	if _last_command_running then
		return base.DATA.current_service_status,base.DATA.current_service_info
	end

	-- 停止
	base.DATA.current_service_status,base.DATA.current_service_info = base.PUBLIC.try_stop_service(1,0)

	if base.PUBLIC.on_close_service then
		pcall(base.PUBLIC.on_close_service)
	end
	-- 如果需要等待，则不断查询状态
	if "wait" == base.DATA.current_service_status then

		local _stop_time = skynet.now()
		local _count = 1

		_last_command_running = true
		Timer.runAfter(550,function()
			_count = _count + 1
			base.DATA.current_service_status,base.DATA.current_service_info = base.PUBLIC.try_stop_service(_count,(skynet.now()-_stop_time)*0.01)

			if "stop" == base.DATA.current_service_status then

				-- 停止服务
				skynet.timeout(1,function ()
					skynet.exit()
				end)
				return false

			elseif "wait" ~= base.DATA.current_service_status then

				-- 服务已不是等待状态，不需要再查询

				_last_command_running = false
				return false
			end

			_last_command_running = false
		end)
	end

	-- 停止服务
	if "stop" == base.DATA.current_service_status then
		skynet.timeout(1,function ()
			dlog("退出---log by base.lua")
			skynet.exit()
		end)
	end
	return base.DATA.current_service_status,base.DATA.current_service_info
end


local function check_node_online(cluster_name)
	local alive = skynet.call(".node_discover","lua","check_node_online",cluster_name)
	if not alive then
		print("cluster node not online",cluster_name)
		return false,"cluster node not online"
	end
	return true
end
function base.CMD.cluster_call(cluster_name,service_name,func_name,...)
	if skynet.getenv("cluster_name") == cluster_name then
		local ok,arg1,arg2,arg3,arg4,arg5 = pcall(skynet.call,service_name, "lua", func_name, ...)
		return ok,arg1,arg2,arg3,arg4,arg5
	end
	if not check_node_online(cluster_name) then
		elog("cluster node not online",cluster_name,service_name,func_name)
		return false,"cluster node not online"
	end
	local ok,arg1,arg2,arg3,arg4,arg5 = pcall(cluster.call,cluster_name,service_name,func_name,...)
	return ok,arg1,arg2,arg3,arg4,arg5
end

function base.CMD.cluster_send(cluster_name,service_name,func_name,...)
	if skynet.getenv("cluster_name") == cluster_name then
		local ok,why = pcall(skynet.send,service_name, "lua", func_name, ...)
		return ok,why
	end
	if not check_node_online(cluster_name) then
		elog("cluster node not online",cluster_name,service_name,func_name)
		return false,"cluster node not online"
	end
	local ok,why = pcall(cluster.send,cluster_name,service_name,func_name,...)
	print("cluster_send",cluster_name,service_name,func_name,ok,why)
	return ok,why
end


function base.CMD.cluster_call_by_type(cluster_type,service_name,func_name,...)
	local cluster_name = skynet.call(".node_discover","lua","get_node",cluster_type)
	if not cluster_name then
		elog("cluster node not online",cluster_type,service_name,func_name)
		return false,"cluster node not online"
	end
	return base.CMD.cluster_call(cluster_name,service_name,func_name,...)
end

function base.CMD.cluster_send_by_type(cluster_type,service_name,func_name,...)
	local cluster_name = skynet.call(".node_discover","lua","get_node",cluster_type)
	if not cluster_name then
		elog("cluster node not online",cluster_type,service_name,func_name)
		return false,"cluster node not online"
	end
	print("cluster_send_by_type",cluster_name,service_name,func_name)
	return base.CMD.cluster_send(cluster_name,service_name,func_name,...)
end

return base