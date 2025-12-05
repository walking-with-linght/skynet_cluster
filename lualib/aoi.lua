local zrank = require "zrank"

local assert = assert
local ipairs = ipairs
local pairs  = pairs
local push	 = table.insert
local tostring = tostring
--
local enter_set = {}
local leave_set = {}
local move_set	= {}

--
local x_list = zrank:new()
local y_list = zrank:new()

--
local obj_list = {}
local enter_cb = nil
local leave_cb = nil
local move_cb = nil
local scene_max_x = 100.0
local scene_max_y = 100.0
local distance    = 10.0

local handler = {}
function handler:new(param)
    local t = {}
    setmetatable(t, self)
    self.__index = self

    t:init(param)

    return t
end

function handler:init(param)

	assert(type(param.enter_cb) == "function")
	assert(type(param.leave_cb) == "function")
	assert(type(param.move_cb) == "function")

	enter_cb = param.enter_cb
	leave_cb = param.leave_cb
	move_cb  = param.move_cb
	scene_max_x = assert(tonumber(param.scene_max_x))
	scene_max_y = assert(tonumber(param.scene_max_y))
	distance    = assert(tonumber(param.distance))
end	

function handler:getobj(id)

	return obj_list[id]
end	

function handler:add(id, x, y, dis)

	id = tostring(id)
	dis = dis or distance
	if self:getobj(id) then return end
	local obj =  {
		id 		 = id,
		x  		 = x,
		y  		 = y,
		distance = dis,
	}
	obj_list[id] = obj
	x_list:add(x, id)
	y_list:add(y, id)

	enter_set = self:getvisionset(obj)

	self:update(obj)
end	

function handler:getvisionset(obj)

	local set = {}
	local x = obj.x
	local y = obj.y
	local objid = obj.id
	local distance = obj.distance

	local x_min = x - distance
	if x_min < 0 then x_min = 0 end
	local x_max = x + distance
	if x_max > scene_max_x then x_max = scene_max_x end
	local xids = x_list:range_by_score(x_min, x_max)
	local x_set_tmp = {}
	for _, id in ipairs(xids) do 
		
		if id ~= objid then
			x_set_tmp[id] = true 
		end	
	end

	local y_min = y - distance
	if y_min < 0 then y_min = 0 end
	local y_max = y + distance
	if y_max > scene_max_y then y_max = scene_max_y end
	local yids = y_list:range_by_score(y_min, y_max)
	for _, id in ipairs(yids) do 
		
		if x_set_tmp[id] then
			--push(set, self:getobj(id))
			set[id] = self:getobj(id)
		end	
	end	 	

	return set
end	

function handler:update(obj)

	for _, o in pairs(enter_set) do

		enter_cb(obj, o)
		enter_cb(o, obj)
	end	

	for _, o in pairs(move_set) do

		move_cb(o, obj)
	end	

	for _, o in pairs(leave_set) do

		leave_cb(o, obj)
	end	

	enter_set = {}
	leave_set = {}
	move_set  = {}
end	

function handler:move(id, x, y)

	id = tostring(id)
	local obj = self:getobj(id)
	if not obj then return end

	local old_set = self:getvisionset(obj)
	obj.x = x
	obj.y = y
	x_list:add(x, id)
	y_list:add(y, id)
	local new_set = self:getvisionset(obj)

	move_set = {}
	--move_set old_set mix new_set
	for id, obj in pairs(old_set) do
		if new_set[id] then
			move_set[id] = obj
		end	
	end	

	enter_set = {}
	--enter_set move_set sub new_set
	for id, obj in pairs(new_set) do

		if not move_set[id] then
			enter_set[id] = obj
		end	
	end	

	leave_set = {}
	--leave_set move_set sub old_set
	for id, obj in pairs(old_set) do

		if not move_set[id] then
			leave_set[id] = obj
		end	
	end	

	self:update(obj)
end	

function handler:leave(id)

	id = tostring(id)
	local obj = self:getobj(id)
	if not obj then return end
	leave_set = self:getvisionset(obj)
	self:update(obj)
	obj_list[id] = nil
	x_list:rem(id)
	y_list:rem(id)
end	

return handler
