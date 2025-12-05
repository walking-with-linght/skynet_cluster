local ts = require "typesystem"
print("1------------>>>")
ts.foo {
	_ctor = function(self, a)
		self.a = a
	end,
	_dtor = function(self)
		print("delete", self)
	end,
	a = 0,
	b = true,
	c = "hello",
	f = ts.foo,
	weak_g = ts.foo,
}
print("2------------>>>")
local f = ts.foo:new(1)

--print("1---f = ", f, " f.f = ", f.f, "f.a = ", f.a, " id = ", f._id, " owner = ", f.owner)
f._ref.f(2)
f._ref.f = nil
--print("4---f = ", f, " f.f = ", f.f, " f.f.a = ", f.f.a, " id = ", f.f._id, " owner = ", f.f.owner)

--local nf2 = f._ref.f(3)

--print("3---f = ", f, " f.f = ", f.f, " f.f.a = ", f.f.a, " id = ", f.f._id, " owner = ", f.f.owner)

for k, obj in ts.each() do
	print("for-->>>", k, obj, ts.typename(k))
end

--[[
ts.collectgarbage()

f._ref.f = nil
print("clear f.f")

ts.collectgarbage()

ts.delete(f)
print("delete f")

ts.collectgarbage()

]]
