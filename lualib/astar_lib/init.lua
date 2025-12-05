-- require('jit.v').on('jit.trace')
local AStar = require 'astar_lib.astar'

--[[

    使用方法
    初始化地图
    M.new(w,h)
    设置单点障碍
    M.set_block(x,y,blocked)
    设置矩形区域障碍
    M.set_block_rect(x1,y1,x2,y2,blocked)
    清除所有障碍
    M.clear_all_blocks()
    查找路径
    M.find_path(sx,sy,tx,ty)

]]
local M = {}
local finder = nil

local map = {}

-- Node must be able to check if they are the same
-- Cannot directly return different tables for the same coord
-- The library doesn't change nodes, so you able to reuse your node or create a C struct for faster
local function get_node(x, y)
    local w = M.astar_width
    local h = M.astar_height
    if not w or not h then return nil end
    if x < 1 or x > w or y < 1 or y > h then return nil end
    local idx = (y - 1) * w + x
    local node = M.astar_cached_nodes[idx]
    if node and node.blocked then return nil end
    return node
end

local neighbors_offset = {
    {-1, -1}, {0, -1}, {1, -1}, {-1, 0}, {1, 0}, {-1, 1}, {0, 1}, {1, 1}
}
-- Return all neighbor nodes. Means a target that can be moved from the current node
function map:get_neighbors(node, from_node, add_neighbor_fn, userdata)
    local nodes = {}
    local w = M.astar_width
    local h = M.astar_height
    for i, offset in ipairs(neighbors_offset) do
        local nx = node.x + offset[1]
        local ny = node.y + offset[2]
        if nx >= 1 and nx <= w and ny >= 1 and ny <= h then
            local neighbor = get_node(nx, ny)
            if neighbor then add_neighbor_fn(neighbor) end
        end
    end
    return nodes
end

-- Cost of two adjacent nodes.
-- Distance, distance + cost or other comparison value you want
function map:get_cost(from_node, to_node)
    local v = math.sqrt((from_node.x - to_node.x) ^ 2 +
                            (from_node.y - to_node.y) ^ 2)
    return v * (from_node.s + to_node.s) * 0.5
end

-- For heuristic. Estimate cost of current node to goal node
-- As close to the real cost as possible
function map:estimate_cost(node, goal_node)
    return math.sqrt((node.x - goal_node.x) ^ 2 + (node.y - goal_node.y) ^ 2)
end



function M.new(w,h)
    -- store width/height explicitly
    M.astar_width = w
    M.astar_height = h
    M.astar_size = w -- keep backward compatibility
    M.astar_cached_nodes = {}
    for x = 1, w do
        for y = 1, h do
            local idx = (y - 1) * w + x
            local s = ((x % 2 == 0) and (y % 2 == 0)) and 10 or 1
            local node = {x = x, y = y, s = s, blocked = false}
            M.astar_cached_nodes[idx] = node
        end
    end
    finder = AStar.new(map)
    return M
end

-- API: 设置/清除单点障碍
function M:set_block(x,y,blocked)
    local w = M.astar_width
    local h = M.astar_height
    if not w or not h then return false end
    if x < 1 or x > w or y < 1 or y > h then return false end
    local idx = (y - 1) * w + x
    local node = M.astar_cached_nodes[idx]
    if not node then return false end
    node.blocked = not not blocked
    return true
end

-- API: 设置矩形区域为障碍（包含边界）
function M:set_block_rect(x1,y1,x2,y2, blocked)
    local w = M.astar_width
    local h = M.astar_height
    if not w or not h then return false end
    local xa = math.max(1, math.min(x1,x2))
    local xb = math.min(w, math.max(x1,x2))
    local ya = math.max(1, math.min(y1,y2))
    local yb = math.min(h, math.max(y1,y2))
    for x = xa, xb do
        for y = ya, yb do
            local idx = (y - 1) * w + x
            local node = M.astar_cached_nodes[idx]
            if node then node.blocked = not not blocked end
        end
    end
    return true
end

function M:clear_all_blocks()
    for _, node in ipairs(M.astar_cached_nodes) do
        if node then node.blocked = false end
    end
end

function M:find_path( sx, sy, tx, ty )
	local start, goal = get_node(sx, sy), get_node(tx, ty)
    local st = os.clock()
	local path, g_score = finder:find(start, goal)
    local cost = (os.clock() - st) * 1000
    print(string.format("astar_lib 耗时%s %i,%i -> %i,%i", cost, sx, sy, tx, ty))
	return path
end
return M