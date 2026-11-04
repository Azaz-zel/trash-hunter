-- Minimal stand-ins for the Roblox datatypes the shared modules use
-- (Vector3, CFrame, Color3, Random, ...), so they run in the plain luau CLI.
-- Minimal Vector3/CFrame shim so shared modules can run in plain luau.
local V = {}
local function vnew(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V)
end
V.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return vnew(v.X / m, v.Y / m, v.Z / m)
	end
	return V[k]
end
V.__add = function(a, b)
	return vnew(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V.__sub = function(a, b)
	return vnew(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V.__mul = function(a, b)
	if type(a) == "number" then
		return vnew(b.X * a, b.Y * a, b.Z * a)
	elseif type(b) == "number" then
		return vnew(a.X * b, a.Y * b, a.Z * b)
	end
	return vnew(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V.__div = function(a, b)
	return vnew(a.X / b, a.Y / b, a.Z / b)
end
V.__unm = function(a)
	return vnew(-a.X, -a.Y, -a.Z)
end
V.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V.__tostring = function(a)
	return string.format("%.1f, %.1f, %.1f", a.X, a.Y, a.Z)
end
function V.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
function V.Cross(a, b)
	return vnew(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function V.Lerp(a, b, t)
	return a + (b - a) * t
end
Vector3 = { yAxis = vnew(0, 1, 0), new = vnew, zero = vnew(0, 0, 0), xAxis = vnew(1, 0, 0), yAxis = vnew(0, 1, 0), zAxis = vnew(0, 0, 1) }
Vector2 = { new = function(x, y)
	return { X = x, Y = y }
end }

-- CFrame: position p, columns r (right), u (up), b (back = -look)
local C = {}
local function cnew(p, r, u, b)
	return setmetatable({ p = p, r = r, u = u, b = b }, C)
end
C.__index = function(c, k)
	if k == "Position" then
		return c.p
	elseif k == "X" then
		return c.p.X
	elseif k == "Y" then
		return c.p.Y
	elseif k == "Z" then
		return c.p.Z
	elseif k == "LookVector" then
		return -c.b
	elseif k == "RightVector" then
		return c.r
	elseif k == "UpVector" then
		return c.u
	end
	return C[k]
end
local function rot(c, v)
	return c.r * v.X + c.u * v.Y + c.b * v.Z
end
C.__mul = function(a, b)
	if getmetatable(b) == V then
		return a.p + rot(a, b)
	end
	return cnew(a.p + rot(a, b.p), rot(a, b.r), rot(a, b.u), rot(a, b.b))
end
C.__add = function(a, v)
	return cnew(a.p + v, a.r, a.u, a.b)
end
function C.VectorToObjectSpace(a, v)
	return vnew(v:Dot(a.r), v:Dot(a.u), v:Dot(a.b))
end
function C.VectorToWorldSpace(a, v)
	return a.r * v.X + a.u * v.Y + a.b * v.Z
end
function C.PointToObjectSpace(a, v)
	return a:VectorToObjectSpace(v - a.p)
end
function C.ToObjectSpace(a, b)
	local function inv(v)
		return vnew(v:Dot(a.r), v:Dot(a.u), v:Dot(a.b))
	end
	return cnew(inv(b.p - a.p), inv(b.r), inv(b.u), inv(b.b))
end
local I = { vnew(1, 0, 0), vnew(0, 1, 0), vnew(0, 0, 1) }
CFrame = {
	new = function(x, y, z)
		if type(x) == "table" then
			return cnew(x, I[1], I[2], I[3])
		end
		return cnew(vnew(x or 0, y or 0, z or 0), I[1], I[2], I[3])
	end,
	lookAt = function(at, target)
		local look = (target - at).Unit
		local right = look:Cross(vnew(0, 1, 0)).Unit
		local up = right:Cross(look)
		return cnew(at, right, up, -look)
	end,
	Angles = function(x, y, z)
		assert(x == 0 and z == 0, "only yaw supported")
		local c, s = math.cos(y), math.sin(y)
		return cnew(vnew(0, 0, 0), vnew(c, 0, -s), vnew(0, 1, 0), vnew(s, 0, c))
	end,
}
Random = {
	new = function(seed)
		local state = seed or 1
		local function nxt()
			state = (state * 1103515245 + 12345) % 2147483648
			return state / 2147483648
		end
		return {
			NextNumber = function(_, a, b)
				a = a or 0
				b = b or 1
				return a + (b - a) * nxt()
			end,
			NextInteger = function(_, a, b)
				return a + math.floor(nxt() * (b - a + 1))
			end,
		}
	end,
}

Color3 = {
	new = function(r, g, b)
		return { R = r or 0, G = g or 0, B = b or 0 }
	end,
	fromRGB = function(r, g, b)
		return { R = (r or 0) / 255, G = (g or 0) / 255, B = (b or 0) / 255 }
	end,
	fromHex = function()
		return { R = 0, G = 0, B = 0 }
	end,
}
