local skynet = require "skynet"

local refd
skynet.init(function()
	refd = skynet.uniqueservice("refd")
end)

local _M = {}

local inited
function _M.init(delay)
	inited = true
	setmetatable(_M, {
		__gc = function()
			skynet.send(refd, "lua", "release", skynet.self())
		end
	})
	skynet.send(refd, "lua", "init", skynet.self(), delay)
end

function _M.ref()
	assert(inited)
	return skynet.call(refd, "lua", "ref", skynet.self())
end

function _M.unref()
	if inited then return skynet.call(refd, "lua", "unref", skynet.self()) end
end

return _M
