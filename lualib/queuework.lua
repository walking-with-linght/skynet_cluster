local Queue = require "skynet.queue"
local pcall = pcall
local M = {}



function M.new()
	local obj = {}
	obj.queue = {}
	obj.queue_ref = {}
	return setmetatable(obj,M)
end



function M:queue_work_free()
	for k,v in pairs(self.queue) do
		return false
	end

	return true
end

function M:queue_cs_do(key,ok,...)
	self.queue_ref[key] = self.queue_ref[key] - 1
	if self.queue_ref[key] == 0 then
		self.queue[key] = nil
		self.queue_ref[key] = nil
	end
	if not ok then
		error(...)
	end
	return ...
end

function M:queuework(key,func,...)
	local csp = self.queue[key]
 	if not csp then
 		csp = Queue()
 		self.queue[key] = csp
 		self.queue_ref[key] = 1
 	else
		self.queue_ref[key] = self.queue_ref[key] + 1
 	end
	 local this = self
	return csp(function (...)
		return this:queue_cs_do(key,pcall(func,...))
		-- return this:queue_cs_do(key,func,...)
	end,...)
end

return M