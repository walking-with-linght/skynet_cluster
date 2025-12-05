
local total = 0
local pools = {}

local function co_create()

	local co
	co = coroutine.create(function (f)

		f(coroutine.yield())
		while true do

			table.insert(pools, co)
			f = coroutine.yield()
			f(coroutine.yield())
		end
	end)

	total = total + 1
	table.insert(pools, co)
end

local function create_co(f)

	if #pools == 0 then
		co_create()
	end

	local co = table.remove(pools)
	coroutine.resume(co, f)

	return co
end

local ct = {}
function ct.create(f)

	return create_co(function (...)

		local ok, msg = pcall(f, ...)
		if not ok then
			error(tostring(msg))
		end
	end)
end

function ct.resume(co, ...)

	local ok, msg = coroutine.resume(co, ...)
	if not ok then 
		error(tostring(msg))
	end
end

function ct.co_create_count()
	
	return total
end

function ct.co_cache_count()

	return #pools
end

function ct.running_co_count()

	return total - #pools
end

function ct.co_create_n(n)

	assert(n > 0)
	for i = 1, n do
		co_create()
	end
end


--for test coroutine pool

--ct.co_create_n(100)
--[[
local co = ct.create(function (a)

	print("co 1----print:", a)
	local b, c = coroutine.yield()
	print("co 2---print:", b, c)
	--error("co error")
	b, c = coroutine.yield()
	print("co 3---print: ", b, c)
end)

local co2  = ct.create(function (a)

	print("co2 1----print:", a)
	local b, c = coroutine.yield()
	print("co2 2---print:", b, c)	
end)

ct.resume(co, "hello")
ct.resume(co2, "hello222")

ct.resume(co, "aaa", "bbb")
ct.resume(co2, "aaa222", "bbb222")
]]

return ct
