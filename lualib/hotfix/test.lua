

-- 热更命令
-- call :0000000f "exe_file","lualib/hotfix/test.lua"



local base = require "base"
local skynet = require "skynet"
local dump = require "dump"
local DATA = base.DATA
-- 在本文件直接重写或者修改变量即可
-- 只能热更base下的所有属性

-- local oldstart = base.CMD.startPlay
-- -- 开始下注
-- function base.CMD.startPlay()
-- 	oldstart()
--     tlog('CMD.startPlay new --- hotfix')
-- end

DATA.robot_open = true

return function ()
	print("open crash robot ok")
end
-- or
-- local m = {
-- 	on_load = function ()
-- 		print("hotfix ok")
-- 	end
-- }
-- return m