local crab = require "crab.c"
local utf8 = require "utf8.c"

local assert = assert
local push = table.insert
local handle = {}
function handle.init(data) 

	assert(type(data) == "table" and #data > 0, "sensitive data must be array.")
	local words = {}

	for _, line in ipairs(data) do 
	    local t = {}
	    assert(utf8.toutf32(line, t), "non utf8 words detected:" .. line)
	    push(words, t)
	end	

	assert(#words > 0)
	crab.open(words)
end

function handle.output(input) 
	local texts = {}
	assert(utf8.toutf32(input, texts), "non utf8 words detected:", texts)
	crab.filter(texts)
	return utf8.toutf8(texts)
end

--[[
	使用示例
	local s = require "base.sensitive"
	local words = {'习近平', '大哥哥大', '赌博'}
	s.init(words)

	print(s.output("我就是爱习近平， 你想咋滴"))
]]
return handle

