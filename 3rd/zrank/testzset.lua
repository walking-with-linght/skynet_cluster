package.cpath = package.cpath .. ";../cservice/?.so"

local zrank = require "zrank"

local obj = zrank:new()
obj:add(100, "aaac")--插入 通常不需要显示调用delete因为会自行判断， 但是第二参数通常是唯一key
obj:add(100, "aaaa")
obj:add(100, "aaaa1")
obj:add(88, "00001")
obj:add(77, "20000")
obj:add(129, "1988")

obj:dump()


print("getrangemembers 2 - 5 : ")
t1 = obj:getrangemembers(4)--获取前多少名
for k, v in pairs(t1) do
	print(k, v)
end	

print("getselfrank aaaa: ", obj:getselfrank("aaaa"))--获取增加的排名


obj = nil
obj = zrank:new()

print("reget t1 4rd:")
t1 = obj:getrangemembers(4)--获取前多少名
for k, v in pairs(t1) do
	print(k, v)
end	
print("end reget t1 4rd:")
