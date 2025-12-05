local aoi = require "aoi.aoi"

local enter_cb = function (a, b)
	
	local str = string.format("enter a[id:%s x:%s y:%s]:  b [id:%s x:%s y:%s] enter scene",
		a.id, a.x, a.y, b.id, b.x, b.y)
	print(str)
end

local move_cb = function (a, b)
	local str = string.format("move a[id:%s x:%s y:%s]:  b [id:%s x:%s y:%s] move in scene",
		a.id, a.x, a.y, b.id, b.x, b.y)
	print(str)
end

local leave_cb = function (a, b)
	local str = string.format("leave a[id:%s x:%s y:%s]:  b [id:%s x:%s y:%s] leave scene",
		a.id, a.x, a.y, b.id, b.x, b.y)
	print(str)
end

local o = aoi:new({

	enter_cb = enter_cb,
	move_cb = move_cb,
	leave_cb = leave_cb,
	distance = 10.0, -- 观察距离
	scene_max_x = 100.0,
	scene_max_y = 100.0,
})

local objs = {
}
local function init_obj(id, x, y, vx, vy)

	objs[id] = {objs = {}, v = {}}
	objs[id].objs = {

		id = id, 
		x = x,
		y = y,
	}
	objs[id].v = {
		x = vx,
		y = vy
	}

	o:add(id, x, y)
end	

local function update_obj(id) 

	objs[id].objs.x = objs[id].objs.x + objs[id].v.x
	if objs[id].objs.x  < 0 then objs[id].objs.x = objs[id].objs.x + 100.0 end
	if objs[id].objs.x  > 100.0 then objs[id].objs.x = objs[id].objs.x - 100.0 end
	objs[id].objs.y = objs[id].objs.y + objs[id].v.y
	if objs[id].objs.y  < 0 then objs[id].objs.y = objs[id].objs.y + 100.0 end
	if objs[id].objs.y  > 100.0 then objs[id].objs.y = objs[id].objs.y - 100.0 end

	o:move(id, objs[id].objs.x, objs[id].objs.y)
end

local function main()

	init_obj(1,40,0,0,1)
	init_obj(2,42,100,0,-1)
	init_obj(3,0,40,1,0)
	init_obj(4,100,45,-1,0)

	for i = 1, 100 do
		if i<50 then
			for j = 1, 4 do
				update_obj(j)
			end
		elseif i == 50 then
			o:leave(3)
		else
			for j = 1, 4 do
				update_obj(j)
			end
		end
	end
end	

return main


--[[
enter a[id:3 x:30 y:40]:  b [id:1 x:40 y:30] enter scene
enter a[id:1 x:40 y:30]:  b [id:3 x:30 y:40] enter scene
move a[id:3 x:30 y:40]:  b [id:1 x:40 y:31] move in scene
move a[id:1 x:40 y:31]:  b [id:3 x:31 y:40] move in scene
move a[id:3 x:31 y:40]:  b [id:1 x:40 y:32] move in scene
move a[id:1 x:40 y:32]:  b [id:3 x:32 y:40] move in scene
move a[id:3 x:32 y:40]:  b [id:1 x:40 y:33] move in scene
move a[id:1 x:40 y:33]:  b [id:3 x:33 y:40] move in scene
move a[id:3 x:33 y:40]:  b [id:1 x:40 y:34] move in scene
move a[id:1 x:40 y:34]:  b [id:3 x:34 y:40] move in scene
move a[id:3 x:34 y:40]:  b [id:1 x:40 y:35] move in scene
move a[id:1 x:40 y:35]:  b [id:3 x:35 y:40] move in scene
move a[id:3 x:35 y:40]:  b [id:1 x:40 y:36] move in scene
move a[id:1 x:40 y:36]:  b [id:3 x:36 y:40] move in scene
move a[id:3 x:36 y:40]:  b [id:1 x:40 y:37] move in scene
move a[id:1 x:40 y:37]:  b [id:3 x:37 y:40] move in scene
move a[id:3 x:37 y:40]:  b [id:1 x:40 y:38] move in scene
move a[id:1 x:40 y:38]:  b [id:3 x:38 y:40] move in scene
move a[id:3 x:38 y:40]:  b [id:1 x:40 y:39] move in scene
move a[id:1 x:40 y:39]:  b [id:3 x:39 y:40] move in scene
move a[id:3 x:39 y:40]:  b [id:1 x:40 y:40] move in scene
move a[id:1 x:40 y:40]:  b [id:3 x:40 y:40] move in scene
move a[id:3 x:40 y:40]:  b [id:1 x:40 y:41] move in scene
move a[id:1 x:40 y:41]:  b [id:3 x:41 y:40] move in scene
move a[id:3 x:41 y:40]:  b [id:1 x:40 y:42] move in scene
move a[id:1 x:40 y:42]:  b [id:3 x:42 y:40] move in scene
move a[id:3 x:42 y:40]:  b [id:1 x:40 y:43] move in scene
move a[id:1 x:40 y:43]:  b [id:3 x:43 y:40] move in scene
move a[id:3 x:43 y:40]:  b [id:1 x:40 y:44] move in scene
move a[id:1 x:40 y:44]:  b [id:3 x:44 y:40] move in scene
move a[id:3 x:44 y:40]:  b [id:1 x:40 y:45] move in scene
enter a[id:2 x:42 y:55]:  b [id:1 x:40 y:45] enter scene
enter a[id:1 x:40 y:45]:  b [id:2 x:42 y:55] enter scene
move a[id:1 x:40 y:45]:  b [id:3 x:45 y:40] move in scene
enter a[id:4 x:55 y:45]:  b [id:3 x:45 y:40] enter scene
enter a[id:3 x:45 y:40]:  b [id:4 x:55 y:45] enter scene
move a[id:2 x:42 y:55]:  b [id:1 x:40 y:46] move in scene
move a[id:3 x:45 y:40]:  b [id:1 x:40 y:46] move in scene
move a[id:1 x:40 y:46]:  b [id:2 x:42 y:54] move in scene
move a[id:4 x:55 y:45]:  b [id:3 x:46 y:40] move in scene
move a[id:1 x:40 y:46]:  b [id:3 x:46 y:40] move in scene
move a[id:3 x:46 y:40]:  b [id:4 x:54 y:45] move in scene
move a[id:2 x:42 y:54]:  b [id:1 x:40 y:47] move in scene
move a[id:3 x:46 y:40]:  b [id:1 x:40 y:47] move in scene
move a[id:1 x:40 y:47]:  b [id:2 x:42 y:53] move in scene
move a[id:4 x:54 y:45]:  b [id:3 x:47 y:40] move in scene
move a[id:1 x:40 y:47]:  b [id:3 x:47 y:40] move in scene
move a[id:3 x:47 y:40]:  b [id:4 x:53 y:45] move in scene
move a[id:2 x:42 y:53]:  b [id:1 x:40 y:48] move in scene
move a[id:3 x:47 y:40]:  b [id:1 x:40 y:48] move in scene
move a[id:1 x:40 y:48]:  b [id:2 x:42 y:52] move in scene
move a[id:4 x:53 y:45]:  b [id:3 x:48 y:40] move in scene
move a[id:1 x:40 y:48]:  b [id:3 x:48 y:40] move in scene
enter a[id:4 x:52 y:45]:  b [id:2 x:42 y:52] enter scene
enter a[id:2 x:42 y:52]:  b [id:4 x:52 y:45] enter scene
move a[id:3 x:48 y:40]:  b [id:4 x:52 y:45] move in scene
move a[id:2 x:42 y:52]:  b [id:1 x:40 y:49] move in scene
move a[id:3 x:48 y:40]:  b [id:1 x:40 y:49] move in scene
move a[id:4 x:52 y:45]:  b [id:2 x:42 y:51] move in scene
move a[id:1 x:40 y:49]:  b [id:2 x:42 y:51] move in scene
move a[id:4 x:52 y:45]:  b [id:3 x:49 y:40] move in scene
move a[id:1 x:40 y:49]:  b [id:3 x:49 y:40] move in scene
move a[id:2 x:42 y:51]:  b [id:4 x:51 y:45] move in scene
move a[id:3 x:49 y:40]:  b [id:4 x:51 y:45] move in scene
1=========> leave set   3
2=========> leave set   3
=========> leave set    4       table: 0x7f34484b4c40
=========> leave set    1       table: 0x7f34484b2fc0
leave a[id:4 x:51 y:45]:  b [id:3 x:49 y:40] leave scene
leave a[id:1 x:40 y:49]:  b [id:3 x:49 y:40] leave scene
move a[id:2 x:42 y:51]:  b [id:1 x:40 y:50] move in scene
move a[id:4 x:51 y:45]:  b [id:2 x:42 y:50] move in scene
move a[id:1 x:40 y:50]:  b [id:2 x:42 y:50] move in scene
enter a[id:4 x:50 y:45]:  b [id:1 x:40 y:50] enter scene
enter a[id:1 x:40 y:50]:  b [id:4 x:50 y:45] enter scene
move a[id:2 x:42 y:50]:  b [id:4 x:50 y:45] move in scene
move a[id:4 x:50 y:45]:  b [id:1 x:40 y:51] move in scene
move a[id:2 x:42 y:50]:  b [id:1 x:40 y:51] move in scene
move a[id:4 x:50 y:45]:  b [id:2 x:42 y:49] move in scene
move a[id:1 x:40 y:51]:  b [id:2 x:42 y:49] move in scene
move a[id:2 x:42 y:49]:  b [id:4 x:49 y:45] move in scene
move a[id:1 x:40 y:51]:  b [id:4 x:49 y:45] move in scene
move a[id:4 x:49 y:45]:  b [id:1 x:40 y:52] move in scene
move a[id:2 x:42 y:49]:  b [id:1 x:40 y:52] move in scene
move a[id:4 x:49 y:45]:  b [id:2 x:42 y:48] move in scene
move a[id:1 x:40 y:52]:  b [id:2 x:42 y:48] move in scene
move a[id:2 x:42 y:48]:  b [id:4 x:48 y:45] move in scene
move a[id:1 x:40 y:52]:  b [id:4 x:48 y:45] move in scene
move a[id:4 x:48 y:45]:  b [id:1 x:40 y:53] move in scene
move a[id:2 x:42 y:48]:  b [id:1 x:40 y:53] move in scene
move a[id:4 x:48 y:45]:  b [id:2 x:42 y:47] move in scene
move a[id:1 x:40 y:53]:  b [id:2 x:42 y:47] move in scene
move a[id:2 x:42 y:47]:  b [id:4 x:47 y:45] move in scene
move a[id:1 x:40 y:53]:  b [id:4 x:47 y:45] move in scene
move a[id:4 x:47 y:45]:  b [id:1 x:40 y:54] move in scene
move a[id:2 x:42 y:47]:  b [id:1 x:40 y:54] move in scene
move a[id:4 x:47 y:45]:  b [id:2 x:42 y:46] move in scene
move a[id:1 x:40 y:54]:  b [id:2 x:42 y:46] move in scene
move a[id:2 x:42 y:46]:  b [id:4 x:46 y:45] move in scene
move a[id:1 x:40 y:54]:  b [id:4 x:46 y:45] move in scene
move a[id:4 x:46 y:45]:  b [id:1 x:40 y:55] move in scene
move a[id:2 x:42 y:46]:  b [id:1 x:40 y:55] move in scene
move a[id:4 x:46 y:45]:  b [id:2 x:42 y:45] move in scene
move a[id:1 x:40 y:55]:  b [id:2 x:42 y:45] move in scene
move a[id:2 x:42 y:45]:  b [id:4 x:45 y:45] move in scene
move a[id:1 x:40 y:55]:  b [id:4 x:45 y:45] move in scene
leave a[id:2 x:42 y:45]:  b [id:1 x:40 y:56] leave scene
leave a[id:4 x:45 y:45]:  b [id:1 x:40 y:56] leave scene
move a[id:4 x:45 y:45]:  b [id:2 x:42 y:44] move in scene
move a[id:2 x:42 y:44]:  b [id:4 x:44 y:45] move in scene
move a[id:4 x:44 y:45]:  b [id:2 x:42 y:43] move in scene
move a[id:2 x:42 y:43]:  b [id:4 x:43 y:45] move in scene
move a[id:4 x:43 y:45]:  b [id:2 x:42 y:42] move in scene
move a[id:2 x:42 y:42]:  b [id:4 x:42 y:45] move in scene
move a[id:4 x:42 y:45]:  b [id:2 x:42 y:41] move in scene
move a[id:2 x:42 y:41]:  b [id:4 x:41 y:45] move in scene
move a[id:4 x:41 y:45]:  b [id:2 x:42 y:40] move in scene
move a[id:2 x:42 y:40]:  b [id:4 x:40 y:45] move in scene
move a[id:4 x:40 y:45]:  b [id:2 x:42 y:39] move in scene
move a[id:2 x:42 y:39]:  b [id:4 x:39 y:45] move in scene
move a[id:4 x:39 y:45]:  b [id:2 x:42 y:38] move in scene
move a[id:2 x:42 y:38]:  b [id:4 x:38 y:45] move in scene
move a[id:4 x:38 y:45]:  b [id:2 x:42 y:37] move in scene
move a[id:2 x:42 y:37]:  b [id:4 x:37 y:45] move in scene
move a[id:4 x:37 y:45]:  b [id:2 x:42 y:36] move in scene
move a[id:2 x:42 y:36]:  b [id:4 x:36 y:45] move in scene
move a[id:4 x:36 y:45]:  b [id:2 x:42 y:35] move in scene
move a[id:2 x:42 y:35]:  b [id:4 x:35 y:45] move in scene
leave a[id:4 x:35 y:45]:  b [id:2 x:42 y:34] leave scene


]]