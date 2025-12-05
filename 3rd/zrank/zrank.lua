local skiplist = require "skiplist.c"
local tonumber = tonumber
local math_floor = math.floor

local handler = {}
function handler:new()
    local t = {}
    setmetatable(t, self)
    self.__index = self

    t:init()

    return t
end

function handler:init()

    self.sl = skiplist()
    self.tbl = {}
end    

--增加一个元素score会转换成double, member切记要唯一, 一般用角色ID或者activity state id
--这个排序是从小到大， 所以一般排行榜需要反向取
function handler:add(score, member)
    local old = self.tbl[member]
    if old then
        if old == score then
            return
        end
        self.sl:delete(old, member)
    end

    self.sl:insert(score, member)
    self.tbl[member] = score
end

function handler:rem(member)
    local score = self.tbl[member]
    if score then
        self.sl:delete(score, member)
        self.tbl[member] = nil
    end
end

function handler:count()
    return self.sl:get_count()
end

function handler:_reverse_rank(r)
    return self.sl:get_count() - r + 1
end

function handler:limit(count, delete_handler)
    local total = self.sl:get_count()
    if total <= count then
        return 0
    end

    local delete_function = function(member)
        self.tbl[member] = nil
        if delete_handler then
            delete_handler(member)
        end
    end

    return self.sl:delete_by_rank(count+1, total, delete_function)
end

function handler:rev_limit(count, delete_handler)
    local total = self.sl:get_count()
    if total <= count then
        return 0
    end
    local from = self:_reverse_rank(count+1)
    local to   = self:_reverse_rank(total)

    local delete_function = function(member)
        self.tbl[member] = nil
        if delete_handler then
            delete_handler(member)
        end
    end

    return self.sl:delete_by_rank(from, to, delete_function)
end

--通常排行榜需要调用这个得到范围， 反向排序
function handler:rev_range(r1, r2)
    local r1 = self:_reverse_rank(r1)
    local r2 = self:_reverse_rank(r2)
    return self:range(r1, r2)
end

function handler:getrangemembers(r1, r2)

    if not r1 and not r2 then 
        r1 = 1
        r2 = self:count()
    end    
    if not r2 and r1 then  
        r2 = r1  
        r1 = 1 
    end
    return self:rev_range(r1, r2)
end    

--正向排序 从小到大
function handler:range(r1, r2)
    if r1 < 1 then
        r1 = 1
    end

    if r2 < 1 then
        r2 = 1
    end
    return self.sl:get_rank_range(r1, r2)
end
--获取自己从大到小的排名
function handler:rev_rank(member)
    local r = self:rank(member)
    if r then
        return self:_reverse_rank(r)
    end
    return r
end

function handler:getselfrank(member)

    return self:rev_rank(member) or -1
end    

--获取自己从小到大的排名
function handler:rank(member)
    local score = self.tbl[member]
    if not score then
        return nil
    end
    return self.sl:get_rank(score, member)
end

--获取2个分数之间的排名， 可以用来做战力匹配之类的功能
function handler:range_by_score(s1, s2)
    return self.sl:get_score_range(s1, s2)
end

--得到成员的分数 通常比较的是数字
function handler:score(member)

    local score = self.tbl[member] or 0
    return math_floor(tonumber(score)) 
end

--调试函数
function handler:dump()
    self.sl:dump()
end

return handler

