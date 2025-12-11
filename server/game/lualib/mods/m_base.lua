

local skynet = require "skynet"
local base = require "base"
local Timer = require "Timer"
local error_code = require "error_code"
local event = require "event"

local DATA = base.DATA --本服务使用的表
local CMD = base.CMD  --供其他服务调用的接口
local PUBLIC = base.PUBLIC --本服务调用的接口
local REQUEST = base.REQUEST

local NM = "base"

local lf = base.LocalFunc(NM)
local ld = base.LocalData(NM,{
	db = {},--需要存库的数据
})

local db = ld.db

function lf.load(self)
	local key = PUBLIC.get_db_key(self.rid)
	local cache = Common.redisExecute({"hget",key,NM},Redis_DB.game)
	if cache then
		db = util.db_decode(cache)
	end
	log.info("rid base-mod load")
end
function lf.loaded(self)
	log.info("rid base-mod loaded")
end
function lf.enter(self)
	log.info("rid base-mod enter")
end
function lf.leave(self)
	log.info("rid base-mod leave")
end

skynet.init(function () 
	event:register("load",lf.load)
	event:register("loaded",lf.loaded)
	event:register("enter",lf.enter)
	event:register("leave",lf.leave)
end)

-------client-------
function REQUEST:heartbeat()
	return {result = error_code.success}
end



