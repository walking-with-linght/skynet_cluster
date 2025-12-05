local redisHeader 	= require "redis.redisHeader"
local saveRedis   	= require "redis.saveRedis"
local db 			= require "coredb.query"
local savedb		= require "db.savedb"

local outline 		= class("outline")

local floor			= math.floor
--只能在继承businessObject的服务中使用
function outline:init(playerId, playerMan)

	assert(type(playerId) == "string" and #playerId == 24, string.format("error playerId %s.", playerId))
	self.playerId = playerId
	self.playerMan = playerMan

	return self
end	

function outline:name(dbname)

	assert(dbname)
	self.dbField = assert(dbField[dbname], string.format("error dbname %s.", dbname))
	self.prikey  = assert(extra_db[dbname].__prikey, string.format("error extra_db dbname %s.", dbname))
	self.dbname = dbname
	self.redisHeader = redisHeader:new(dbname)
	self.saveRedis   = saveRedis:new(dbname)
	self.savedb		 = savedb:new(dbname)
	return self
end	

function outline:pk(prikey)

	self.prikeyvalue = prikey
	return self
end
--离线获取数据 可以获取单个字段也可以获取完整的数据
function outline:get(...)

	local p = {...}
	local prikey = self.prikeyvalue or table.remove(p, 1)
	assert(type(prikey) == "string" and #prikey == 24, string.format("error prikey %s.", prikey))
	local header = self.redisHeader:getHeader(prikey)
	if #p == 0 then

		--get all data
		local data = self.saveRedis:rawgetall(header)
		if type(data) == "table" and next(data) then

			data = self.saveRedis:checkField(data)	
		else

			--mysql
			data = db:name(self.dbname):where(self.prikey, prikey):find()	
			--回写redis？？			
			--self.saveRedis:rawhsetall(header, data)
		end	

		--assert(next(data), string.format("dbname %s prikey %s data not in redis and mysql.", self.dbname, prikey))

		return data
	end	

	for i = 1, #p do

		local key = p[i]
		if not self.dbField[key] then
			error(string.format("dbname %s key %s invalid.", self.dbname, key))
		end	
	end	

	local data = self.saveRedis:rawgetall(header, table.unpack(p))
	if type(data) == "table" and next(data) then

		data = self.saveRedis:checkField(data)
	else	

		data = db:name(self.dbname):field(p):where(self.prikey, prikey):find()
	end	

	assert(next(data), string.format("error dbname %s.", self.dbname))

	if #p == 1 then
		return data[p[1]]
	end	
	return data
end	

function outline:checkSet(t)

	assert(type(t) == "table" and next(t))
	local prikey = self.prikeyvalue or t[self.prikey]
	assert(prikey and #prikey == 24, string.format("param t must contain %s.", self.prikey))
	local playerId = self.playerId
	local header = self.redisHeader:getHeader(prikey)
	return playerId, header
end	
--用于新增
function outline:set(t)

	local playerId, header = self:checkSet(t)
	if self.playerMan:isFullData(playerId) then

		self.saveRedis:save(header, t, playerId)
	else

		self.savedb:save(t, playerId)
	end	
end
--用于修改
function outline:rawset(t, prikeyvalue)

	if not self.prikeyvalue then
		self.prikeyvalue = assert(prikeyvalue)
	end	
	local playerId, header = self:checkSet(t)
	if self.playerMan:isFullData(playerId) then

		self.saveRedis:rawsave(header, t, playerId)
	else
		assert(self.prikey, string.format("error dbname %s miss prikey.", self.dbname))
		self.savedb:rawsave(t, self.prikey, self.prikeyvalue, playerId)
	end	
end	
--用于删除
function outline:del(prikey)

	local prikey = self.prikeyvalue or prikey
	assert(prikey and #prikey == 24, string.format("param t must contain %s.", self.prikey))
	local header = self.redisHeader:getHeader(prikey)
	self.saveRedis:delete(header, assert(self.playerId))
end	

--表达式 对主键对应的数据加减乘除
--表示式支持 +-*/
function outline:expr(t, prikey)

	assert(type(t) == "table" and #t > 0, "param `t` must be array table.")
	local prikey = prikey or self.prikeyvalue
	assert(type(prikey) == "string" and #prikey == 24)

	local r = {}
	for _, item in pairs(t) do

		assert(#item == 3, string.dump(item))
		local a, op, b = table.unpack(item)
		assert(type(a) == "string" and self.dbField[a], string.format("error expr a %s.", a))
		assert(type(b) == "number" and b ~= 0, string.format("error expr b %s.", b))
		if op == "+" then

			r[a] = floor(self:get(a) + b)
		elseif op == "-" then
			r[a] = floor(self:get(a) - b)
		elseif op == "*" then
			r[a] = floor(self:get(a) * b)
		elseif op == "/" then
			r[a] = floor(self:get(a) / b)
		else
			error(string.format("error op %s.", op))
		end	
	end	
	assert(next(r))
	self:rawset(r, self.prikey, prikey)
end	

return outline

