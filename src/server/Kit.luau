--!strict
-- Supermarket Empire: small building blocks shared by Scenery and World, and the palette from
-- docs/world-brief.md. Everything is anchored; decoration never collides, touches or is queried.
-- Status: reviewed, not run in Studio.

local Kit = {}

local hex = Color3.fromHex
Kit.FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)

-- Palette. Saturation goes on what the player touches or is paid by, never on the ground.
Kit.C = {
	asphalt = Color3.fromRGB(58, 58, 68),
	asphaltDark = Color3.fromRGB(46, 46, 54),
	sidewalk = Color3.fromRGB(226, 222, 212),
	curb = Color3.fromRGB(168, 164, 156),
	pad = Color3.fromRGB(206, 198, 180),
	grass = Color3.fromRGB(104, 170, 80),
	grassDark = Color3.fromRGB(84, 146, 66),
	hedge = Color3.fromRGB(62, 128, 58),
	leaf = Color3.fromRGB(74, 160, 70),
	leafLight = Color3.fromRGB(110, 190, 84),
	trunk = Color3.fromRGB(120, 84, 60),
	wall = Color3.fromRGB(240, 230, 208),
	wallShade = Color3.fromRGB(212, 200, 176),
	trim = Color3.fromRGB(52, 50, 60),
	tileA = Color3.fromRGB(232, 232, 236),
	tileB = Color3.fromRGB(190, 200, 216),
	metal = Color3.fromRGB(176, 182, 194),
	metalDark = Color3.fromRGB(96, 100, 112),
	glass = Color3.fromRGB(170, 225, 255),
	wood = Color3.fromRGB(196, 146, 98),
	cardboard = Color3.fromRGB(206, 160, 108),
	paint = Color3.fromRGB(250, 250, 250),
	yellow = Color3.fromRGB(255, 214, 0),
	lime = hex("8CFF00"), -- the one "pay / touch" accent
	limeDark = hex("12A600"),
	red = hex("FF1F2A"),
	white = Color3.new(1, 1, 1),
	black = Color3.new(0, 0, 0),
}
Kit.STAGE = { hex("FF8A00"), hex("0A9CF0"), hex("2BE000"), hex("FF1F2A"), hex("9312E4") }

export type Props = { [string]: any }

local function apply(p: Instance, props: Props?)
	if props then
		for k, v in props do
			(p :: any)[k] = v
		end
	end
end

-- A solid, collidable block (floors, walls, counters).
function Kit.block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, props: Props?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	apply(p, props)
	p.Parent = parent
	return p
end

-- Decoration: no collision, touch or queries, and no shadow unless asked for.
function Kit.deco(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, props: Props?): Part
	local p = Kit.block(parent, name, size, cf, color, nil)
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	apply(p, props)
	return p
end

-- A cylinder standing upright: diameter d, height h, centred on cf.
function Kit.pole(parent: Instance, name: string, d: number, h: number, cf: CFrame, color: Color3, props: Props?): Part
	local p = Kit.deco(parent, name, Vector3.new(h, d, d), cf * CFrame.Angles(0, 0, math.rad(90)), color, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end

function Kit.ball(parent: Instance, name: string, d: number, cf: CFrame, color: Color3, props: Props?): Part
	local p = Kit.deco(parent, name, Vector3.new(d, d, d), cf, color, props)
	p.Shape = Enum.PartType.Ball
	return p
end

function Kit.wedge(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, props: Props?): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	apply(p, props)
	p.Parent = parent
	return p
end

-- Text in the UI kit's look: Montserrat Heavy with a black bevel stroke.
function Kit.label(parent: Instance, text: string, height: number, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = Kit.FONT
	l.Text = text
	l.TextScaled = true
	l.TextColor3 = color or Kit.C.white
	l.Size = UDim2.new(1, 0, height, 0)
	local s = Instance.new("UIStroke")
	s.Name = "UIStroke"
	s.Thickness = 3.7
	s.LineJoinMode = Enum.LineJoinMode.Bevel
	s.Color = Kit.C.black
	s.Parent = l
	l.Parent = parent
	return l
end

-- Text painted on one face of a part (signs built into the art, 3-8 words).
function Kit.sign(part: BasePart, face: Enum.NormalId, text: string, color: Color3?, stroke: boolean?): TextLabel
	local g = Instance.new("SurfaceGui")
	g.Name = "Sign"
	g.Face = face
	g.LightInfluence = 0
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	local l = Kit.label(g, text, 1, color)
	if stroke == false then
		local s = l:FindFirstChildOfClass("UIStroke")
		if s then
			s:Destroy()
		end
	end
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.PaddingTop = UDim.new(0.08, 0)
	pad.PaddingBottom = UDim.new(0.08, 0)
	pad.Parent = l
	g.Parent = part
	return l
end

function Kit.billboard(adornee: BasePart, name: string, width: number, height: number, offset: number, maxDistance: number?): BillboardGui
	local b = Instance.new("BillboardGui")
	b.Name = name
	b.Adornee = adornee
	b.Size = UDim2.fromScale(width, height)
	b.StudsOffset = Vector3.new(0, offset, 0)
	b.LightInfluence = 0
	b.MaxDistance = maxDistance or 120
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.Parent = b
	b.Parent = adornee
	return b
end

-- A cartoon tree built from parts: the fallback when the pack's pine cannot be loaded.
function Kit.tree(parent: Instance, cf: CFrame, scale: number): Model
	local m = Instance.new("Model")
	m.Name = "Tree"
	Kit.pole(m, "Trunk", 1.6 * scale, 7 * scale, cf * CFrame.new(0, 3.5 * scale, 0), Kit.C.trunk, { CanCollide = true })
	Kit.ball(m, "Canopy1", 9 * scale, cf * CFrame.new(0, 9.5 * scale, 0), Kit.C.leaf, { CastShadow = true })
	Kit.ball(m, "Canopy2", 6.5 * scale, cf * CFrame.new(2.6 * scale, 8 * scale, 1.2 * scale), Kit.C.leafLight)
	Kit.ball(m, "Canopy3", 6 * scale, cf * CFrame.new(-2.4 * scale, 8.4 * scale, -1.4 * scale), Kit.C.leaf)
	Kit.ball(m, "Canopy4", 5 * scale, cf * CFrame.new(0.4 * scale, 12.4 * scale, 0.6 * scale), Kit.C.leafLight)
	m.Parent = parent
	return m
end

-- A potted bush for door fronts.
function Kit.planter(parent: Instance, cf: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "Planter"
	Kit.deco(m, "Pot", Vector3.new(2.6, 1.6, 2.6), cf * CFrame.new(0, 0.8, 0), Kit.C.trim, { CanCollide = true })
	Kit.ball(m, "Bush", 3.2, cf * CFrame.new(0, 2.6, 0), Kit.C.leaf)
	Kit.ball(m, "Bush2", 2.2, cf * CFrame.new(0.7, 3.5, 0.3), Kit.C.leafLight)
	m.Parent = parent
	return m
end

-- A street lamp. lit = add a real light (keep these few: the budget is 12).
function Kit.lamp(parent: Instance, cf: CFrame, lit: boolean): Model
	local m = Instance.new("Model")
	m.Name = "Lamp"
	Kit.pole(m, "Base", 1.4, 1, cf * CFrame.new(0, 0.5, 0), Kit.C.trim)
	Kit.pole(m, "Pole", 0.5, 13, cf * CFrame.new(0, 7, 0), Kit.C.trim, { CanCollide = true })
	Kit.deco(m, "Arm", Vector3.new(0.4, 0.4, 3.4), cf * CFrame.new(0, 13.3, -1.5), Kit.C.trim)
	local head = Kit.deco(m, "Head", Vector3.new(1.6, 0.5, 2.2), cf * CFrame.new(0, 13, -2.8), Kit.C.yellow, { Material = Enum.Material.Neon })
	if lit then
		local light = Instance.new("PointLight")
		light.Range = 26
		light.Brightness = 0.6
		light.Color = Color3.fromRGB(255, 236, 190)
		light.Shadows = false
		light.Parent = head
	end
	m.Parent = parent
	return m
end

-- A shopping cart, for the "badly parked carts" story group.
function Kit.cart(parent: Instance, cf: CFrame, color: Color3): Model
	local m = Instance.new("Model")
	m.Name = "Cart"
	Kit.deco(m, "Basket", Vector3.new(2, 1.3, 3), cf * CFrame.new(0, 2.2, 0), Kit.C.metal, { Transparency = 0.25 })
	Kit.deco(m, "Bottom", Vector3.new(1.8, 0.2, 2.8), cf * CFrame.new(0, 1.5, 0), Kit.C.metalDark)
	Kit.deco(m, "Handle", Vector3.new(2.2, 0.3, 0.3), cf * CFrame.new(0, 3.1, 1.7), color)
	Kit.deco(m, "Frame", Vector3.new(1.6, 0.2, 2.6), cf * CFrame.new(0, 0.7, 0), Kit.C.metalDark)
	for _, o in { Vector3.new(-0.8, 0.3, -1.1), Vector3.new(0.8, 0.3, -1.1), Vector3.new(-0.8, 0.3, 1.1), Vector3.new(0.8, 0.3, 1.1) } do
		Kit.ball(m, "Wheel", 0.6, cf * CFrame.new(o), Kit.C.trim)
	end
	m.Parent = parent
	return m
end

-- A stack of delivery boxes: one big, two mid, one small (odd groups read as placed, not scattered).
function Kit.boxes(parent: Instance, cf: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "Boxes"
	local c = Kit.C.cardboard
	Kit.deco(m, "Big", Vector3.new(3.4, 3, 3.4), cf * CFrame.new(0, 1.5, 0), c, { CanCollide = true, CastShadow = true })
	Kit.deco(m, "Mid1", Vector3.new(2.4, 2.2, 2.4), cf * CFrame.new(3.2, 1.1, 0.4) * CFrame.Angles(0, math.rad(12), 0), c:Lerp(Kit.C.black, 0.08), { CanCollide = true })
	Kit.deco(m, "Mid2", Vector3.new(2.2, 2, 2.2), cf * CFrame.new(0.3, 4, -0.2) * CFrame.Angles(0, math.rad(-18), 0), c:Lerp(Kit.C.white, 0.12))
	Kit.deco(m, "Small", Vector3.new(1.4, 1.2, 1.4), cf * CFrame.new(3, 2.8, 0.5) * CFrame.Angles(0, math.rad(30), 0), c)
	Kit.deco(m, "Tape", Vector3.new(3.5, 0.1, 0.6), cf * CFrame.new(0, 3.01, 0), Kit.C.wood)
	m.Parent = parent
	return m
end

return Kit
