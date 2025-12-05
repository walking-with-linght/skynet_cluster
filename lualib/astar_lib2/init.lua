--[[

    -- 好像现在就ASTAR好用点
    find_type 查找类型 BFS DFS ASTAR THETASTAR LAZYTHETASTAR JPS
    使用方法
    初始化
    local astar = require("astar_lib2").new(w,h,find_type)
    设置障碍坐标
    astar:set_block(x,y,blocked)
    设置障碍区域
    astar:set_block_rect(x1,y1,x2,y2,blocked)
    清除所有障碍
    astar:clear_all_blocks()
    查找路径
    astar:find_path(sx,sy,tx,ty)
]]
local Grid = require("astar_lib2.grid")
local PathFinder = require("astar_lib2.pathFinder")

local M = {}
M.__index = M

function M.new(w,h,find_type)
    local obj = setmetatable({}, M)
    obj.map = {}
    for y = 1, h do
        obj.map[y] = {}
        for x = 1, w do
            obj.map[y][x] = 0
        end
    end
    obj.find_type = find_type or "ASTAR"
    obj.grid = Grid.new(obj.map)
    obj.finder = PathFinder.new(obj.grid, obj.find_type, 0)
    return obj
end


-- 设置障碍点
function M:set_block(x,y,blocked)
    if self.map[y] then
        self.map[y][x] = blocked and 1 or 0
    end
end

-- 设置障碍区域
function M:set_block_rect(x1,y1,x2,y2,blocked)
    for x = x1, x2 do
        for y = y1, y2 do
            if self.map[y] then
                self.map[y][x] = blocked and 1 or 0
            end
        end 
    end
end

-- 清除所有障碍
function M:clear_all_blocks()
    for y = 1, #self.map do
        for x = 1, #self.map[y] do
            self.map[y][x] = 0
        end
    end
end

-- 查找路径
function M:find_path(sx,sy,tx,ty)
    local st = os.clock()
    local path = self.finder:getPath(sx,sy,tx,ty)
    local cost = (os.clock() - st) * 1000
    print(string.format("astar_lib2[%s] 耗时%s %i,%i -> %i,%i", self.find_type, cost, sx, sy, tx, ty))
    local path_list = {} -- 路径节点列表
    if path then
        for node, count in path:nodes() do
            table.insert(path_list, {x = node:getX(), y = node:getY()})
        end
        return path_list
    else
        return nil
    end
end

return M