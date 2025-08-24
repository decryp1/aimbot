-- services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- variables
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Container = Instance.new("Folder", game:GetService("CoreGui"))

-- locals
local floor = math.floor
local round = math.round
local wtvp = Camera.WorldToViewportPoint

-- constants
local NAME_OFFSET = UDim2.new(0, 0, 0, -20)
local HEALTH_OFFSET = UDim2.new(0, 0, 0, -40)
local TRACER_THICKNESS = 1

-- esp object
local EspObject = {}
EspObject.__index = EspObject

function EspObject.new(instance, type)
	local self = setmetatable({}, EspObject)
	self.instance = instance
	self.type = type
	self.gui = Instance.new("BillboardGui", Container)
	self.gui.Name = instance.Name .. "_ESP"
	self.gui.AlwaysOnTop = true
	self.gui.Size = UDim2.new(0, 100, 0, 50)
	self.gui.StudsOffset = Vector3.new(0, 2, 0)
	self.gui.Adornee = instance:FindFirstChildWhichIsA("BasePart") or instance
	self.nameLabel = Instance.new("TextLabel", self.gui)
	self.nameLabel.Size = UDim2.new(0, 100, 0, 20)
	self.nameLabel.BackgroundTransparency = 1
	self.nameLabel.Text = instance.Name
	self.nameLabel.TextColor3 = Color3.new(0, 1, 0)
	self.nameLabel.TextStrokeTransparency = 0
	self.healthLabel = Instance.new("TextLabel", self.gui)
	self.healthLabel.Size = UDim2.new(0, 100, 0, 20)
	self.healthLabel.Position = HEALTH_OFFSET
	self.healthLabel.BackgroundTransparency = 1
	self.healthLabel.TextColor3 = Color3.new(0, 1, 0)
	self.healthLabel.TextStrokeTransparency = 0
	self.tracer = Instance.new("LineHandleAdornment", self.gui)
	self.tracer.Thickness = TRACER_THICKNESS
	self.tracer.Color3 = Color3.new(0, 1, 0)
	self.tracer.Length = 100
	self.tracer.AlwaysOnTop = true
	self:Update()
	return self
end

function EspObject:Update()
	local part = self.instance:FindFirstChildWhichIsA("BasePart") or self.instance
	if not part then return end
	local screenPos, onScreen = wtvp(Camera, part.Position)
	if onScreen then
		self.gui.Enabled = true
		self.nameLabel.Text = self.instance.Name
		self.nameLabel.Position = UDim2.new(0, floor(screenPos.X), 0, floor(screenPos.Y)) + NAME_OFFSET
		local humanoid = self.instance:FindFirstChildWhichIsA("Humanoid")
		if humanoid and (self.type == "deer" or self.type == "mammoth" or self.type == "scp") then
			self.healthLabel.Text = round(humanoid.Health) .. "hp"
			self.healthLabel.Position = UDim2.new(0, floor(screenPos.X), 0, floor(screenPos.Y)) + HEALTH_OFFSET
			self.healthLabel.Visible = true
		else
			self.healthLabel.Visible = false
		end
		self.tracer.WorldCFrame = CFrame.new(Camera.CFrame.Position, part.Position) * CFrame.new(0, 0, -self.tracer.Length)
		self.tracer.Visible = true
	else
		self.gui.Enabled = false
	end
end

function EspObject:Destroy()
	self.gui:Destroy()
end

-- esp manager
local EspManager = {
	objects = {},
}

function EspManager.AddInstance(instance, type)
	if EspManager.objects[instance] then return end
	local esp = EspObject.new(instance, type)
	EspManager.objects[instance] = esp
end

function EspManager.RemoveInstance(instance)
	if EspManager.objects[instance] then
		EspManager.objects[instance]:Destroy()
		EspManager.objects[instance] = nil
	end
end

function EspManager.Load()
	print("Loading custom ESP...")
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
		if type == "player" and instance == LocalPlayer then return end
		print("Creating ESP for", instance.Name, "type:", type)
		EspManager.AddInstance(instance, type)
	end

	for name, data in pairs(objects) do
		if name ~= "player" and name ~= "scp" then
			local folder = Workspace:FindFirstChild(data.path)
			if folder then
				for _, instance in ipairs(folder:GetChildren()) do
					if instance.Name == name then
						createObject(instance, name)
					end
				end
			else
				print("Warning: Folder", data.path, "not found for", name)
			end
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			createObject(player, "player")
		end
	end

	local scps = Workspace:FindFirstChild("scps")
	if scps then
		for _, scp in ipairs(scps:GetChildren()) do
			createObject(scp, "scp")
		end
	end

	EspManager.connection = RunService.RenderStepped:Connect(function()
		for _, esp in pairs(EspManager.objects) do
			esp:Update()
		end
	end)
	print("Custom ESP loaded successfully")
end

function EspManager.Unload()
	print("Unloading custom ESP...")
	if EspManager.connection then
		EspManager.connection:Disconnect()
	end
	for _, esp in pairs(EspManager.objects) do
		esp:Destroy()
	end
	EspManager.objects = {}
	print("Custom ESP unloaded successfully")
end

-- init
EspManager.Load()

return EspManager
