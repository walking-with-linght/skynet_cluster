
local skynet = require "skynet"
local base = require "base"
local Timer = require "Timer"
local error_code = require "error_code"
local event = require "event"
local queue = require "skynet.queue"()

local DATA = base.DATA --本服务使用的表
local CMD = base.CMD  --供其他服务调用的接口
local PUBLIC = base.PUBLIC --本服务调用的接口
local REQUEST = base.REQUEST

local debug_traceback = debug.traceback
local NM = "boom"

local lf = base.LocalFunc(NM)
local ld = base.LocalData(NM,{
	db = {},--需要存库的数据
})


local db = ld.db

function lf.load(self,key)
	log.info("rid boom-mod load")
end
function lf.loaded(self)
	log.info("rid boom-mod loaded")
end
function lf.enter(self)
	log.info("rid boom-mod enter")
end
function lf.leave(self)
	if ld.room then
		skynet.send(ld.room.room_addr,"lua","client_request","c2s_leave_room", self.rid)
	end
	ld.room = nil
	log.info("rid boom-mod leave")
end

skynet.init(function () 
	event:register("load",lf.load)
	event:register("loaded",lf.loaded)
	event:register("enter",lf.enter)
	event:register("leave",lf.leave)
end)

function PUBLIC:is_boom_state()
	return ld.room
end

local ignor_msg = {
	s2c_player_kill_player = true,
	s2c_player_real_kill_player = true,
}

function lf:just_send2client(cmd,data)
	-- log.debug("发送到客户端",self,cmd,sdump(data))
	if ignor_msg[cmd] then
		return
	end
	if data and self.rid == data.rid then
		return
	end
	CMD.send2client(cmd,data)
end


-- 通知玩家进入房间
function lf:boom_on_join(data)
	ld.room = data
	--[[
		int32 id 		= 1;
		int32 col		= 2;
		int32 row 		= 3;
		string name 	= 4;
		string team 	= 5;
	]]
	CMD.send2client("s2c_join_success",data)
	log.debug("agent-玩家进入房间成功")
end

-----------------------------------------------------------------
function lf.do_room_request(cmd,arg1, ...)
	local f = lf[cmd]
	if f then
		local ok, ret = xpcall(f, debug_traceback, DATA.role, arg1,...)
		if not ok then
			log.error("执行房间请求失败",cmd,ret)
			return
		end
		-- log.debug("房间协议处理结果",sdump(ret))
		return ret
	else
		log.error("未找到处理房间消息函数",cmd)
	end
end

function CMD.req_from_boom_room(cmd,arg1, ... )
	-- log.debug("boom模块处理房间回调",cmd)
	return queue(lf.do_room_request, cmd, arg1,...)
end


function REQUEST:c2s_search_room(args)
	-- log.debug("boom 处理查找房间消息")
 	if PUBLIC.is_boom_state(self) then
 		return { result = error_code.room_already_in_room}
 	end
 	local data = {
 		rid = self.rid,
 		agent = skynet.self(),
 		prof = self.prof,
 		nickname = self.nickname,
 		level = self.level
 	}
 	local ok = skynet.call(".boom_match_manager","lua","join_match",self.rid,data)
 	if not ok then
 		return { result = error_code.room_already_in_match}
 	end
 	return { result = error_code.success}

end
-- 上一把对局结束后才会调用，在同一个房间内
function REQUEST:c2s_game_restart(args)
 	if not PUBLIC.is_boom_state(self) then
 		return { result = error_code.room_not_in_game}
 	end
 	skynet.send(ld.room.room_addr,"lua","client_request","c2s_game_restart", self.rid, args)
end

-- 退出房间
function REQUEST:c2s_leave_room(args)
 	if not PUBLIC.is_boom_state(self) then
 		return { result = error_code.room_not_in_game}
 	end
 	skynet.send(ld.room.room_addr,"lua","client_request", "c2s_leave_room", self.rid, args)
end

-- 击杀
function REQUEST:c2s_kill_player(args)
 	if not PUBLIC.is_boom_state(self) then
 		return { result = error_code.room_not_in_game}
 	end
 	skynet.send(ld.room.room_addr,"lua","client_request", "c2s_kill_player", self.rid, args)
end

-- 触碰倒地玩家
function REQUEST:c2s_real_kill_player(args)
 	if not PUBLIC.is_boom_state(self) then
 		return { result = error_code.room_not_in_game}
 	end
 	skynet.send(ld.room.room_addr,"lua","client_request", "c2s_real_kill_player", self.rid, args)
end

-- 吃道具
function REQUEST:c2s_eat_medicine(args)
 	if not PUBLIC.is_boom_state(self) then
 		return { result = error_code.room_not_in_game}
 	end
 	skynet.send(ld.room.room_addr,"lua","client_request", "c2s_eat_medicine", self.rid, args)
end

-- 开始移动
function REQUEST:c2s_walk(args)
 	if not PUBLIC.is_boom_state(self) then
 		return { result = error_code.room_not_in_game}
 	end
 	skynet.send(ld.room.room_addr,"lua","client_request", "c2s_walk", self.rid, args)
end

-- 停止移动
function REQUEST:c2s_stop_walk(args)
 	if not PUBLIC.is_boom_state(self) then
 		return { result = error_code.room_not_in_game}
 	end
 	skynet.send(ld.room.room_addr,"lua","client_request", "c2s_stop_walk", self.rid, args)
end

-- 放置炸弹
function REQUEST:c2s_create_bubble(args)
 	if not PUBLIC.is_boom_state(self) then
 		return { result = error_code.room_not_in_game}
 	end
 	skynet.send(ld.room.room_addr,"lua","client_request", "c2s_create_bubble", self.rid, args)
end

-- 引爆炸弹
function REQUEST:c2s_bubble_boom(args)
 	if not PUBLIC.is_boom_state(self) then
 		return { result = error_code.room_not_in_game}
 	end
 	skynet.send(ld.room.room_addr,"lua","client_request", "c2s_bubble_boom", self.rid, args)
end
