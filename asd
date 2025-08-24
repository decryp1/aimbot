-- services
local runService = game:GetService("RunService")
local players = game:GetService("Players")
local workspace = game:GetService("Workspace")

-- variables
local localPlayer = players.LocalPlayer
local camera = workspace.CurrentCamera
local viewportSize = camera.ViewportSize
local container = Instance.new("Folder", gethui and gethui() or game:GetService("CoreGui"))

-- locals
local floor = math.floor
local round = math.round
local sin = math.sin
local cos = math.cos
local clear = table.clear
local unpack = table.unpack
local find = table.find
local create = table.create
local fromMatrix = CFrame.fromMatrix

-- methods
local wtvp = camera.WorldToViewportPoint
local isA = workspace.IsA
local getPivot = workspace.GetPivot
local findFirstChild = workspace.FindFirstChild
local findFirstChildOfClass = workspace.FindFirstChildOfClass
local getChildren = workspace.GetChildren
local toOrientation = CFrame.identity.ToOrientation
local pointToObjectSpace = CFrame.identity.PointToObjectSpace
local lerpColor = Color3.new().Lerp
local min2 = Vector2.zero.Min
local max2 = Vector2.zero.Max
local lerp2 = Vector2.zero.Lerp
local min3 = Vector3.zero.Min
local max3 = Vector3.zero.Max

-- constants
local HEALTH_BAR_OFFSET = Vector2.new(5, 0)
local HEALTH_TEXT_OFFSET = Vector2.new(3, 0)
local HEALTH_BAR_OUTLINE_OFFSET = Vector2.new(0, 1)
local NAME_OFFSET = Vector2.new(0, 2)
local DISTANCE_OFFSET = Vector2.new(0, 2)
local VERTICES = {
	Vector3.new(-1, -1, -1),
	Vector3.new(-1, 1, -1),
	Vector3.new(-1, 1, 1),
	Vector3.new(-1, -1, 1),
	Vector3.new(1, -1, -1),
	Vector3.new(1, 1, -1),
	Vector3.new(1, 1, 1),
	Vector3.new(1, -1, 1)
}

-- functions
local function isBodyPart(name)
	return name == "Head" or name:find("Torso") or name:find("Leg") or name:find("Arm")
end

local function getBoundingBox(instance)
	if instance:IsA("Model") then
		local parts = {}
		for _, part in ipairs(instance:GetDescendants()) do
			if isA(part, "BasePart") then
				parts[#parts + 1] = part
			end
		end
		if #parts == 0 then
			return getPivot(instance), instance:GetExtentsSize() or Vector3.new(2, 2, 2)
		end
		local min, max
		for i = 1, #parts do
			local part = parts[i]
			local cframe, size = part.CFrame, part.Size
			min = min3(min or cframe.Position, (cframe - size*0.5).Position)
			max = max3(max or cframe.Position, (cframe + size*0.5).Position)
		end
		local center = (min + max)*0.5
		local front = Vector3.new(center.X, center.Y, max.Z)
		return CFrame.new(center, front), max - min
	elseif isA(instance, "BasePart") then
		return instance.CFrame, instance.Size
	else
		return getPivot(instance), Vector3.new(2, 2, 2)
	end
end

local function worldToScreen(world)
	local screen, inBounds = wtvp(camera, world)
	return Vector2.new(screen.X, screen.Y), inBounds, screen.Z
end

local function calculateCorners(cframe, size)
	local corners = create(#VERTICES)
	for i = 1, #VERTICES do
		corners[i] = worldToScreen((cframe + size*0.5*VERTICES[i]).Position)
	end
	local min = min2(viewportSize, unpack(corners))
	local max = max2(Vector2.zero, unpack(corners))
	return {
		corners = corners,
		topLeft = Vector2.new(floor(min.X), floor(min.Y)),
		topRight = Vector2.new(floor(max.X), floor(min.Y)),
		bottomLeft = Vector2.new(floor(min.X), floor(max.Y)),
		bottomRight = Vector2.new(floor(max.X), floor(max.Y))
	}
end

local function rotateVector(vector, radians)
	local x, y = vector.X, vector.Y
	local c, s = cos(radians), sin(radians)
	return Vector2.new(x*c - y*s, x*s + y*c)
end

local function parseColor(self, color, isOutline)
	if color == "Team Color" or (self.interface.sharedSettings.useTeamColor and not isOutline) then
		return self.interface.getTeamColor(self.instance) or Color3.new(1,1,1)
	end
	return color
end

-- esp object
local EspObject = {}
EspObject.__index = EspObject

function EspObject.new(instance, interface)
	local self = setmetatable({}, EspObject)
	self.instance = assert(instance, "Missing argument #1 (Instance expected)")
	self.interface = assert(interface, "Missing argument #2 (table expected)")
	self:Construct()
	return self
end

function EspObject:_create(class, properties)
	local drawing = Drawing.new(class)
	for property, value in next, properties do
		pcall(function() drawing[property] = value end)
	end
	self.bin[#self.bin + 1] = drawing
	return drawing
end

function EspObject:Construct()
	self.charCache = {}
	self.childCount = 0
	self.bin = {}
	self.drawings = {
		box3d = {
			{
				self:_create("Line", { Thickness = 1, Visible = false }),
				self:_create("Line", { Thickness = 1, Visible = false }),
				self:_create("Line", { Thickness = 1, Visible = false })
			},
			{
				self:_create("Line", { Thickness = 1, Visible = false }),
				self:_create("Line", { Thickness = 1, Visible = false }),
				self:_create("Line", { Thickness = 1, Visible = false })
			},
			{
				self:_create("Line", { Thickness = 1, Visible = false }),
				self:_create("Line", { Thickness = 1, Visible = false }),
				self:_create("Line", { Thickness = 1, Visible = false })
			},
			{
				self:_create("Line", { Thickness = 1, Visible = false }),
				self:_create("Line", { Thickness = 1, Visible = false }),
				self:_create("Line", { Thickness = 1, Visible = false })
			}
		},
		visible = {
			tracerOutline = self:_create("Line", { Thickness = 3, Visible = false }),
			tracer = self:_create("Line", { Thickness = 1, Visible = false }),
			boxFill = self:_create("Square", { Filled = true, Visible = false }),
			boxOutline = self:_create("Square", { Thickness = 3, Visible = false }),
			box = self:_create("Square", { Thickness = 1, Visible = false }),
			healthBarOutline = self:_create("Line", { Thickness = 3, Visible = false }),
			healthBar = self:_create("Line", { Thickness = 1, Visible = false }),
			healthText = self:_create("Text", { Center = true, Visible = false }),
			name = self:_create("Text", { Text = self.interface.getName(self.instance), Center = true, Visible = false }),
			distance = self:_create("Text", { Center = true, Visible = false }),
			weapon = self:_create("Text", { Center = true, Visible = false }),
		},
		hidden = {
			arrowOutline = self:_create("Triangle", { Thickness = 3, Visible = false }),
			arrow = self:_create("Triangle", { Filled = true, Visible = false })
		}
	}
	self.renderConnection = runService.Heartbeat:Connect(function(deltaTime)
		self:Update(deltaTime)
		self:Render(deltaTime)
	end)
end

function EspObject:Destruct()
	self.renderConnection:Disconnect()
	for i = 1, #self.bin do
		self.bin[i]:Remove()
	end
	clear(self)
end

function EspObject:Update()
	local interface = self.interface
	local settings = interface.settings[self.type] or interface.teamSettings[interface.isFriendly(self.instance) and "friendly" or "enemy"]
	self.options = settings
	self.character = interface.getCharacter(self.instance)
	self.health, self.maxHealth = interface.getHealth(self.instance)
	self.weapon = interface.getWeapon(self.instance)
	self.enabled = settings.enabled and self.character and not
		(#interface.whitelist > 0 and not find(interface.whitelist, self.instance.UserId or 0))

	if not self.enabled then
		self.charCache = {}
		self.onScreen = false
		return
	end

	local cframe, size = getBoundingBox(self.character)
	local _, onScreen, depth = worldToScreen(cframe.Position)
	self.onScreen = onScreen
	self.distance = depth

	if interface.sharedSettings.limitDistance and depth > interface.sharedSettings.maxDistance then
		self.onScreen = false
	end

	if self.onScreen then
		self.corners = calculateCorners(cframe, size)
	else
		local camCframe = camera.CFrame
		local flat = fromMatrix(camCframe.Position, camCframe.RightVector, Vector3.yAxis)
		local objectSpace = pointToObjectSpace(flat, cframe.Position)
		self.direction = Vector2.new(objectSpace.X, objectSpace.Z).Unit
	end
end

function EspObject:Render()
	local onScreen = self.onScreen or false
	local enabled = self.enabled or false
	local visible = self.drawings.visible
	local hidden = self.drawings.hidden
	local box3d = self.drawings.box3d
	local options = self.options
	local corners = self.corners

	visible.box.Visible = enabled and onScreen and options.box
	visible.boxOutline.Visible = visible.box.Visible and options.boxOutline
	if visible.box.Visible then
		local box = visible.box
		box.Position = corners.topLeft
		box.Size = corners.bottomRight - corners.topLeft
		box.Color = parseColor(self, options.boxColor[1])
		box.Transparency = options.boxColor[2]
		local boxOutline = visible.boxOutline
		boxOutline.Position = box.Position
		boxOutline.Size = box.Size
		boxOutline.Color = parseColor(self, options.boxOutlineColor[1], true)
		boxOutline.Transparency = options.boxOutlineColor[2]
	end

	visible.boxFill.Visible = enabled and onScreen and options.boxFill
	if visible.boxFill.Visible then
		local boxFill = visible.boxFill
		boxFill.Position = corners.topLeft
		boxFill.Size = corners.bottomRight - corners.topLeft
		boxFill.Color = parseColor(self, options.boxFillColor[1])
		boxFill.Transparency = options.boxFillColor[2]
	end

	visible.healthBar.Visible = enabled and onScreen and options.healthBar
	visible.healthBarOutline.Visible = visible.healthBar.Visible and options.healthBarOutline
	if visible.healthBar.Visible then
		local barFrom = corners.topLeft - HEALTH_BAR_OFFSET
		local barTo = corners.bottomLeft - HEALTH_BAR_OFFSET
		local healthBar = visible.healthBar
		healthBar.To = barTo
		healthBar.From = lerp2(barTo, barFrom, self.health/self.maxHealth)
		healthBar.Color = lerpColor(options.dyingColor, options.healthyColor, self.health/self.maxHealth)
		local healthBarOutline = visible.healthBarOutline
		healthBarOutline.To = barTo + HEALTH_BAR_OUTLINE_OFFSET
		healthBarOutline.From = barFrom - HEALTH_BAR_OUTLINE_OFFSET
		healthBarOutline.Color = parseColor(self, options.healthBarOutlineColor[1], true)
		healthBarOutline.Transparency = options.healthBarOutlineColor[2]
	end

	visible.healthText.Visible = enabled and onScreen and options.healthText
	if visible.healthText.Visible then
		local barFrom = corners.topLeft - HEALTH_BAR_OFFSET
		local barTo = corners.bottomLeft - HEALTH_BAR_OFFSET
		local healthText = visible.healthText
		healthText.Text = round(self.health) .. "hp"
		healthText.Size = self.interface.sharedSettings.textSize
		healthText.Font = self.interface.sharedSettings.textFont
		healthText.Color = parseColor(self, options.healthTextColor[1])
		healthText.Transparency = options.healthTextColor[2]
		healthText.Outline = options.healthTextOutline
		healthText.OutlineColor = parseColor(self, options.healthTextOutlineColor, true)
		healthText.Position = lerp2(barTo, barFrom, self.health/self.maxHealth) - healthText.TextBounds*0.5 - HEALTH_TEXT_OFFSET
	end

	visible.name.Visible = enabled and onScreen and options.name
	if visible.name.Visible then
		local name = visible.name
		name.Text = self.interface.getName(self.instance)
		name.Size = self.interface.sharedSettings.textSize
		name.Font = self.interface.sharedSettings.textFont
		name.Color = parseColor(self, options.nameColor[1])
		name.Transparency = self.interface.sharedSettings.nameTransparency or options.nameColor[2]
		name.Outline = options.nameOutline
		name.OutlineColor = parseColor(self, options.nameOutlineColor, true)
		name.Position = (corners.topLeft + corners.topRight)*0.5 - Vector2.yAxis*name.TextBounds.Y - NAME_OFFSET
	end

	visible.distance.Visible = enabled and onScreen and self.distance and options.distance
	if visible.distance.Visible then
		local distance = visible.distance
		distance.Text = round(self.distance) .. " studs"
		distance.Size = self.interface.sharedSettings.textSize
		distance.Font = self.interface.sharedSettings.textFont
		distance.Color = parseColor(self, options.distanceColor[1])
		distance.Transparency = options.distanceColor[2]
		distance.Outline = options.distanceOutline
		distance.OutlineColor = parseColor(self, options.distanceOutlineColor, true)
		distance.Position = (corners.bottomLeft + corners.bottomRight)*0.5 + DISTANCE_OFFSET
	end

	visible.weapon.Visible = enabled and onScreen and options.weapon
	if visible.weapon.Visible then
		local weapon = visible.weapon
		weapon.Text = self.weapon
		weapon.Size = self.interface.sharedSettings.textSize
		weapon.Font = self.interface.sharedSettings.textFont
		weapon.Color = parseColor(self, options.weaponColor[1])
		weapon.Transparency = options.weaponColor[2]
		weapon.Outline = options.weaponOutline
		weapon.OutlineColor = parseColor(self, options.weaponOutlineColor, true)
		weapon.Position = (corners.bottomLeft + corners.bottomRight)*0.5 +
			(visible.distance.Visible and DISTANCE_OFFSET + Vector2.yAxis*visible.distance.TextBounds.Y or Vector2.zero)
	end

	visible.tracer.Visible = enabled and onScreen and options.tracer
	visible.tracerOutline.Visible = visible.tracer.Visible and options.tracerOutline
	if visible.tracer.Visible then
		local tracer = visible.tracer
		tracer.Color = parseColor(self, options.tracerColor[1])
		tracer.Transparency = options.tracerColor[2]
		tracer.To = (corners.bottomLeft + corners.bottomRight)*0.5
		tracer.From = options.tracerOrigin == "Middle" and viewportSize*0.5 or
		              options.tracerOrigin == "Top" and viewportSize*Vector2.new(0.5, 0) or
		              options.tracerOrigin == "Bottom" and viewportSize*Vector2.new(0.5, 1)
		local tracerOutline = visible.tracerOutline
		tracerOutline.Color = parseColor(self, options.tracerOutlineColor[1], true)
		tracerOutline.Transparency = options.tracerOutlineColor[2]
		tracerOutline.To = tracer.To
		tracerOutline.From = tracer.From
	end

	hidden.arrow.Visible = enabled and (not onScreen) and options.offScreenArrow
	hidden.arrowOutline.Visible = hidden.arrow.Visible and options.offScreenArrowOutline
	if hidden.arrow.Visible and self.direction then
		local arrow = hidden.arrow
		arrow.PointA = min2(max2(viewportSize*0.5 + self.direction*options.offScreenArrowRadius, Vector2.one*25), viewportSize - Vector2.one*25)
		arrow.PointB = arrow.PointA - rotateVector(self.direction, 0.45)*options.offScreenArrowSize
		arrow.PointC = arrow.PointA - rotateVector(self.direction, -0.45)*options.offScreenArrowSize
		arrow.Color = parseColor(self, options.offScreenArrowColor[1])
		arrow.Transparency = options.offScreenArrowColor[2]
		local arrowOutline = hidden.arrowOutline
		arrowOutline.PointA = arrow.PointA
		arrowOutline.PointB = arrow.PointB
		arrowOutline.PointC = arrow.PointC
		arrowOutline.Color = parseColor(self, options.offScreenArrowOutlineColor[1], true)
		arrowOutline.Transparency = options.offScreenArrowOutlineColor[2]
	end

	local box3dEnabled = enabled and onScreen and options.box3d
	for i = 1, #box3d do
		local face = box3d[i]
		for i2 = 1, #face do
			local line = face[i2]
			line.Visible = box3dEnabled
			line.Color = parseColor(self, options.box3dColor[1])
			line.Transparency = options.box3dColor[2]
		end
		if box3dEnabled then
			local line1 = face[1]
			line1.From = corners.corners[i]
			line1.To = corners.corners[i == 4 and 1 or i+1]
			local line2 = face[2]
			line2.From = corners.corners[i == 4 and 1 or i+1]
			line2.To = corners.corners[i == 4 and 5 or i+5]
			local line3 = face[3]
			line3.From = corners.corners[i == 4 and 5 or i+5]
			line3.To = corners.corners[i == 4 and 8 or i+4]
		end
	end
end

-- cham object
local ChamObject = {}
ChamObject.__index = ChamObject

function ChamObject.new(instance, interface)
	local self = setmetatable({}, ChamObject)
	self.instance = assert(instance, "Missing argument #1 (Instance expected)")
	self.interface = assert(interface, "Missing argument #2 (table expected)")
	self:Construct()
	return self
end

function ChamObject:Construct()
	self.highlight = Instance.new("Highlight", container)
	self.updateConnection = runService.Heartbeat:Connect(function()
		self:Update()
	end)
end

function ChamObject:Destruct()
	self.updateConnection:Disconnect()
	self.highlight:Destroy()
	clear(self)
end

function ChamObject:Update()
	local highlight = self.highlight
	local interface = self.interface
	local character = interface.getCharacter(self.instance)
	local settings = interface.settings[self.type] or interface.teamSettings[interface.isFriendly(self.instance) and "friendly" or "enemy"]
	local enabled = settings.enabled and character and not
		(#interface.whitelist > 0 and not find(interface.whitelist, self.instance.UserId or 0))

	highlight.Enabled = enabled and settings.chams
	if highlight.Enabled then
		highlight.Adornee = character
		highlight.FillColor = parseColor(self, settings.chamsFillColor[1])
		highlight.FillTransparency = settings.chamsFillColor[2]
		highlight.OutlineColor = parseColor(self, settings.chamsOutlineColor[1], true)
		highlight.OutlineTransparency = settings.chamsOutlineColor[2]
		highlight.DepthMode = settings.chamsVisibleOnly and "Occluded" or "AlwaysOnTop"
	end
end

-- interface
local EspInterface = {
	_hasLoaded = false,
	_objectCache = {},
	whitelist = {},
	sharedSettings = {
		textSize = 13,
		textFont = 2,
		limitDistance = false,
		maxDistance = 150,
		useTeamColor = false,
		nameTransparency = 1
	},
	teamSettings = {
		enemy = {
			enabled = false,
			box = false,
			boxColor = { Color3.new(1,0,0), 1 },
			boxOutline = true,
			boxOutlineColor = { Color3.new(), 1 },
			boxFill = false,
			boxFillColor = { Color3.new(1,0,0), 0.5 },
			healthBar = false,
			healthyColor = Color3.new(0,1,0),
			dyingColor = Color3.new(1,0,0),
			healthBarOutline = true,
			healthBarOutlineColor = { Color3.new(), 0.5 },
			healthText = false,
			healthTextColor = { Color3.new(1,1,1), 1 },
			healthTextOutline = true,
			healthTextOutlineColor = Color3.new(),
			box3d = false,
			box3dColor = { Color3.new(1,0,0), 1 },
			name = false,
			nameColor = { Color3.new(1,1,1), 1 },
			nameOutline = true,
			nameOutlineColor = Color3.new(),
			weapon = false,
			weaponColor = { Color3.new(1,1,1), 1 },
			weaponOutline = true,
			weaponOutlineColor = Color3.new(),
			distance = false,
			distanceColor = { Color3.new(1,1,1), 1 },
			distanceOutline = true,
			distanceOutlineColor = Color3.new(),
			tracer = false,
			tracerOrigin = "Bottom",
			tracerColor = { Color3.new(1,0,0), 1 },
			tracerOutline = true,
			tracerOutlineColor = { Color3.new(), 1 },
			offScreenArrow = false,
			offScreenArrowColor = { Color3.new(1,1,1), 1 },
			offScreenArrowSize = 15,
			offScreenArrowRadius = 150,
			offScreenArrowOutline = true,
			offScreenArrowOutlineColor = { Color3.new(), 1 },
			chams = false,
			chamsVisibleOnly = false,
			chamsFillColor = { Color3.new(0.2, 0.2, 0.2), 0.5 },
			chamsOutlineColor = { Color3.new(1,0,0), 0 },
		},
		friendly = {
			enabled = false,
			box = false,
			boxColor = { Color3.new(0,1,0), 1 },
			boxOutline = true,
			boxOutlineColor = { Color3.new(), 1 },
			boxFill = false,
			boxFillColor = { Color3.new(0,1,0), 0.5 },
			healthBar = false,
			healthyColor = Color3.new(0,1,0),
			dyingColor = Color3.new(1,0,0),
			healthBarOutline = true,
			healthBarOutlineColor = { Color3.new(), 0.5 },
			healthText = false,
			healthTextColor = { Color3.new(1,1,1), 1 },
			healthTextOutline = true,
			healthTextOutlineColor = Color3.new(),
			box3d = false,
			box3dColor = { Color3.new(0,1,0), 1 },
			name = false,
			nameColor = { Color3.new(1,1,1), 1 },
			nameOutline = true,
			nameOutlineColor = Color3.new(),
			weapon = false,
			weaponColor = { Color3.new(1,1,1), 1 },
			weaponOutline = true,
			weaponOutlineColor = Color3.new(),
			distance = false,
			distanceColor = { Color3.new(1,1,1), 1 },
			distanceOutline = true,
			distanceOutlineColor = Color3.new(),
			tracer = false,
			tracerOrigin = "Bottom",
			tracerColor = { Color3.new(0,1,0), 1 },
			tracerOutline = true,
			tracerOutlineColor = { Color3.new(), 1 },
			offScreenArrow = false,
			offScreenArrowColor = { Color3.new(1,1,1), 1 },
			offScreenArrowSize = 15,
			offScreenArrowRadius = 150,
			offScreenArrowOutline = true,
			offScreenArrowOutlineColor = { Color3.new(), 1 },
			chams = false,
			chamsVisibleOnly = false,
			chamsFillColor = { Color3.new(0.2, 0.2, 0.2), 0.5 },
			chamsOutlineColor = { Color3.new(0,1,0), 0 }
		}
	},
	settings = {
		berry = {enabled = false, box = false, boxColor = {Color3.new(0,1,0), 1}, name = false, nameColor = {Color3.new(0,1,0), 1}, nameOutline = true, nameOutlineColor = Color3.new(), tracer = false, tracerColor = {Color3.new(0,1,0), 1}, tracerOutline = true, tracerOutlineColor = {Color3.new(), 1}},
		bush = {enabled = false, box = false, boxColor = {Color3.new(0,1,0), 1}, name = false, nameColor = {Color3.new(0,1,0), 1}, nameOutline = true, nameOutlineColor = Color3.new(), tracer = false, tracerColor = {Color3.new(0,1,0), 1}, tracerOutline = true, tracerOutlineColor = {Color3.new(), 1}},
		flax = {enabled = false, box = false, boxColor = {Color3.new(0,1,0), 1}, name = false, nameColor = {Color3.new(0,1,0), 1}, nameOutline = true, nameOutlineColor = Color3.new(), tracer = false, tracerColor = {Color3.new(0,1,0), 1}, tracerOutline = true, tracerOutlineColor = {Color3.new(), 1}},
		flower = {enabled = false, box = false, boxColor = {Color3.new(0,1,0), 1}, name = false, nameColor = {Color3.new(0,1,0), 1}, nameOutline = true, nameOutlineColor = Color3.new(), tracer = false, tracerColor = {Color3.new(0,1,0), 1}, tracerOutline = true, tracerOutlineColor = {Color3.new(), 1}},
		pebbles = {enabled = false, box = false, boxColor = {Color3.new(0,1,0), 1}, name = false, nameColor = {Color3.new(0,1,0), 1}, nameOutline = true, nameOutlineColor = Color3.new(), tracer = false, tracerColor = {Color3.new(0,1,0), 1}, tracerOutline = true, tracerOutlineColor = {Color3.new(), 1}},
		carrot = {enabled = false, box = false, boxColor = {Color3.new(0,1,0), 1}, name = false, nameColor = {Color3.new(0,1,0), 1}, nameOutline = true, nameOutlineColor = Color3.new(), tracer = false, tracerColor = {Color3.new(0,1,0), 1}, tracerOutline = true, tracerOutlineColor = {Color3.new(), 1}},
		ghost1 = {enabled = false, box = false, boxColor = {Color3.new(0,1,0), 1}, name = false, nameColor = {Color3.new(0,1,0), 1}, nameOutline = true, nameOutlineColor = Color3.new(), tracer = false, tracerColor = {Color3.new(0,1,0), 1}, tracerOutline = true, tracerOutlineColor = {Color3.new(), 1}},
		glass = {enabled = false, box = false, boxColor = {Color3.new(0,1,0), 1}, name = false, nameColor = {Color3.new(0,1,0), 1}, nameOutline = true, nameOutlineColor = Color3.new(), tracer = false, tracerColor = {Color3.new(0,1,0), 1}, tracerOutline = true, tracerOutlineColor = {Color3.new(), 1}},
		deer = {enabled = false, box = false, boxColor = {Color3.new(0,1,0), 1}, name = false, nameColor = {Color3.new(0,1,0), 1}, nameOutline = true, nameOutlineColor = Color3.new(), healthText = false, healthTextColor = {Color3.new(0,1,0), 1}, healthTextOutline = true, healthTextOutlineColor = Color3.new(), tracer = false, tracerColor = {Color3.new(0,1,0), 1}, tracerOutline = true, tracerOutlineColor = {Color3.new(), 1}},
		mammoth = {enabled = false, box = false, boxColor = {Color3.new(0,1,0), 1}, name = false, nameColor = {Color3.new(0,1,0), 1}, nameOutline = true, nameOutlineColor = Color3.new(), healthText = false, healthTextColor = {Color3.new(0,1,0), 1}, healthTextOutline = true, healthTextOutlineColor = Color3.new(), tracer = false, tracerColor = {Color3.new(0,1,0), 1}, tracerOutline = true, tracerOutlineColor = {Color3.new(), 1}},
		scp = {enabled = false, box = false, boxColor = {Color3.new(0,1,0), 1}, name = false, nameColor = {Color3.new(0,1,0), 1}, nameOutline = true, nameOutlineColor = Color3.new(), healthText = false, healthTextColor = {Color3.new(0,1,0), 1}, healthTextOutline = true, healthTextOutlineColor = Color3.new(), tracer = false, tracerColor = {Color3.new(0,1,0), 1}, tracerOutline = true, tracerOutlineColor = {Color3.new(), 1}}
	}
}

function EspInterface.AddInstance(instance, type)
	local cache = EspInterface._objectCache
	if cache[instance] then
		warn("Instance handler already exists.")
	else
		cache[instance] = {EspObject.new(instance, EspInterface), ChamObject.new(instance, EspInterface)}
		cache[instance][1].type = type
		cache[instance][2].type = type
	end
	return cache[instance][1]
end

function EspInterface.Load()
	assert(not EspInterface._hasLoaded, "Esp has already been loaded.")

	local objects = {
		berry = {path = "harvest"},
		bush = {path = "harvest"},
		flax = {path = "harvest"},
		flower = {path = "harvest"},
		pebbles = {path = "harvest"},
		carrot = {path = "harvest"},
		ghost1 = {path = "interact"},
		glass = {path = "interact"},
		deer = {path = "animals"},
		mammoth = {path = "animals"},
		scp = {path = "scps"},
		player = {path = "players"}
	}

	local function createObject(instance, type)
		if type == "player" and instance == localPlayer then return end
		EspInterface._objectCache[instance] = {EspObject.new(instance, EspInterface), ChamObject.new(instance, EspInterface)}
		EspInterface._objectCache[instance][1].type = type
		EspInterface._objectCache[instance][2].type = type
	end

	local function removeObject(instance)
		local object = EspInterface._objectCache[instance]
		if object then
			for i = 1, #object do
				object[i]:Destruct()
			end
			EspInterface._objectCache[instance] = nil
		end
	end

	for name, data in pairs(objects) do
		if name ~= "player" and name ~= "scp" then
			local folder = workspace:FindFirstChild(data.path)
			if folder then
				for _, instance in ipairs(folder:GetChildren()) do
					if instance.Name == name then
						createObject(instance, name)
					end
				end
			end
		end
	end

	local plrs = players:GetPlayers()
	for i = 2, #plrs do
		createObject(plrs[i], "player")
	end

	local scps = workspace:FindFirstChild("scps")
	if scps then
		for _, scp in ipairs(scps:GetChildren()) do
			createObject(scp, "scp")
		end
	end

	EspInterface.playerAdded = players.PlayerAdded:Connect(function(player)
		createObject(player, "player")
	end)
	EspInterface.playerRemoving = players.PlayerRemoving:Connect(removeObject)
	if scps then
		EspInterface.scpAdded = scps.ChildAdded:Connect(function(scp)
			createObject(scp, "scp")
		end)
		EspInterface.scpRemoving = scps.ChildRemoved:Connect(removeObject)
	end

	EspInterface._hasLoaded = true
end

function EspInterface.Unload()
	assert(EspInterface._hasLoaded, "Esp has not been loaded yet.")

	for index, object in next, EspInterface._objectCache do
		for i = 1, #object do
			object[i]:Destruct()
		end
		EspInterface._objectCache[index] = nil
	end

	EspInterface.playerAdded:Disconnect()
	EspInterface.playerRemoving:Disconnect()
	if EspInterface.scpAdded then EspInterface.scpAdded:Disconnect() end
	if EspInterface.scpRemoving then EspInterface.scpRemoving:Disconnect() end
	EspInterface._hasLoaded = false
end

function EspInterface.getWeapon(instance)
	return "Unknown"
end

function EspInterface.isFriendly(instance)
	return instance:IsA("Player") and instance.Team and instance.Team == localPlayer.Team or false
end

function EspInterface.getTeamColor(instance)
	return instance:IsA("Player") and instance.Team and instance.Team.TeamColor and instance.Team.TeamColor.Color or Color3.new(1,1,1)
end

function EspInterface.getCharacter(instance)
	return instance:IsA("Player") and instance.Character or instance
end

function EspInterface.getHealth(instance)
	local humanoid = instance:IsA("Player") and instance.Character and instance.Character:FindFirstChildOfClass("Humanoid") or
	                instance:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return humanoid.Health, humanoid.MaxHealth
	end
	return 100, 100
end

function EspInterface.getName(instance)
	if instance:IsA("Player") then
		return instance.DisplayName or instance.Name or "Unknown"
	end
	return instance.Name
end

return EspInterface
