--[[
    库 1
    astar_lib,
    库 2
    astar_lib2,
]]

local base = require "base"

local CMD = base.CMD
local REQUEST = base.REQUEST
local PUBLIC=base.PUBLIC
local DATA = base.DATA

-- module
local astar_lib = require "astar_lib"
local astar_lib2 = require "astar_lib2"

local lib = nil

-- 初始化
function PUBLIC.astar_init(w,h)
    lib = astar_lib2.new(w,h)
end

-- 查找路径
function PUBLIC.astar_find_path(sx,sy,tx,ty)
    return lib:find_path(sx,sy,tx,ty)
end

-- 设置障碍点
function PUBLIC.astar_set_block(x,y,blocked)
    return lib:set_block(x,y,blocked)
end

-- 设置障碍区域
function PUBLIC.astar_set_block_rect(x1,y1,x2,y2,blocked)   
    return lib:set_block_rect(x1,y1,x2,y2,blocked)
end

-- 清除所有障碍
function PUBLIC.astar_clear_all_blocks()
    return lib:clear_all_blocks()
end
