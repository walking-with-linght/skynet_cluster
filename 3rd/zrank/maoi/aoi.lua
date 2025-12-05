local aoi_core = require "aoi.core"

local handler = {}
function handler:new()

	local t = {}
	setmetatable(t, self)
	self.__index = self
	t:init()

	return t
end	

function handler:init()

	self.aoi = aoi_core()

	local items= {
		{id = 100, mode = "wm", pos = {40.0,50.1,0}},
		{id = 101, mode = "wm", pos = {41.0,51.1,0}},
		{id = 101, mode = "wm", pos = {42.0,58.1,0}},
		{id = 101, mode = "wm", pos = {43.0,60.1,0}},
		{id = 101, mode = "wm", pos = {44.0,61.1,0}},
		{id = 101, mode = "wm", pos = {60.0,69.1,0}},
		{id = 101, mode = "wm", pos = {84.0,81.1,0}},
	}
	for _, item in pairs(items) do
		self.aoi:aoi_update(item.id, item.mode, item.pos[1], item.pos[2])
	end	
	
	print("collect message start...")
	self.aoi:aoi_message(function (watcher, marker)

		print("aoi message watcher: ", watcher)
		print("aoi message marker: ", marker)
		print("\n")
	end)
	print("collect message end...")		

	local count, mem, maxmem = self.aoi:aoi_state()
	print("count = ", count)
	print("mem = ", mem)
	print("maxmem = ", maxmem)

	self.aoi = nil
--[[
	local count, mem, maxmem = self.aoi:aoi_state()
	print("count = ", count)
	print("mem = ", mem)
	print("maxmem = ", maxmem)
]]
	--[[
aoi message watcher:    100
aoi message marker:     101


aoi message watcher:    100
aoi message marker:     102


aoi message watcher:    101
aoi message marker:     100


aoi message watcher:    101
aoi message marker:     102


aoi message watcher:    101
aoi message marker:     103


aoi message watcher:    102
aoi message marker:     100


aoi message watcher:    102
aoi message marker:     101


aoi message watcher:    102
aoi message marker:     103


aoi message watcher:    103
aoi message marker:     101


aoi message watcher:    103
aoi message marker:     102
	]]
end	

handler:new()
