local skynet = require "skynet"
require "skynet.manager"

local CMD = {}

function CMD.ping(args)
    print("ping args",args)
    return "pong",args
end

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = assert(CMD[cmd], cmd .. " not found")
        skynet.retpack(f(...))
    end)
    skynet.register(".ping")
end)