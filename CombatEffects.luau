--[[
	Scripted by: Z3NIRI
]]

-- // Services
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- // Modules
local CombatUtility = require(script.Parent.CombatUtility)

-- // Variables
local DamageEffects: Folder = ReplicatedStorage.Assets.VFX.Damage
local RandomGenerator: Random = Random.new()

-- // Core
local CombatEffects = {}
CombatEffects.__index = CombatEffects

local function AddHighlight(Zombie: Model, Name: string, Color: Color3, Duration)
	local ExistingHighlight: Highlight = Zombie:FindFirstChild(Name)

	if ExistingHighlight then
		if Duration then
			Debris:AddItem(ExistingHighlight, Duration)
		end

		return
	end

	local HighlightEffect: Highlight = Instance.new("Highlight")
	HighlightEffect.Name = Name
	HighlightEffect.FillColor = Color
	HighlightEffect.FillTransparency = 0.45
	HighlightEffect.OutlineTransparency = 1
	HighlightEffect.DepthMode = Enum.HighlightDepthMode.Occluded
	HighlightEffect.Parent = Zombie

	if Duration then
		Debris:AddItem(HighlightEffect, Duration)
	end
end

local function AddDamageEffect(Zombie: Model, EffectName: string, Duration)
	if Zombie:FindFirstChild(`{EffectName}Effect`) then
		return
	end

	local EffectTemplate: Folder = DamageEffects:FindFirstChild(EffectName)

	if not EffectTemplate then
		return
	end

	local EffectFolder: Folder = Instance.new("Folder")
	EffectFolder.Name = `{EffectName}Effect`
	EffectFolder.Parent = Zombie

	local RootPart: MeshPart = Zombie.UpperTorso
	local PartTemplate: Instance = EffectTemplate:FindFirstChild("UpperTorso")
		or EffectTemplate:FindFirstChild("Head")
		or EffectTemplate:FindFirstChildWhichIsA("BasePart")
		or EffectTemplate:FindFirstChildWhichIsA("Attachment")

	if PartTemplate then
		for _, Effect: Instance in PartTemplate:GetDescendants() do
			if not Effect:IsA("ParticleEmitter") then
				continue
			end

			local Particle: ParticleEmitter = Effect:Clone()
			Particle.Enabled = true
			Particle.Parent = RootPart

			local EmitCount: number = Particle:GetAttribute("EmitCount")

			if EmitCount then
				Particle:Emit(EmitCount)
			end

			if Duration then
				Debris:AddItem(Particle, Duration)
			end
		end
	end

	if Duration then
		Debris:AddItem(EffectFolder, Duration)
	end
end

local function AddPentagram(Zombie: Model, Duration: number)
	if Zombie:FindFirstChild("PentagramEffect") then
		return
	end

	local Humanoid: Humanoid = Zombie.Humanoid
	local RootPart: MeshPart = Zombie.HumanoidRootPart
	local EffectTemplate: Folder = DamageEffects.Pentagram
	local EffectFolder: Folder = Instance.new("Folder")
	EffectFolder.Name = "PentagramEffect"
	EffectFolder.Parent = Zombie

	local Holder: Part = EffectTemplate.Holder:Clone()
	Holder.Position = RootPart.Position
	Holder.Parent = EffectFolder

	local Attachments = {}

	for _, Effect: Instance in EffectTemplate:GetChildren() do
		if not Effect:IsA("Attachment") then
			continue
		end

		local Attachment: Attachment = Effect:Clone()
		Attachment.Parent = Holder
		Attachments[Effect] = Attachment

		for _, Particle: Instance in Attachment:GetDescendants() do
			if Particle:IsA("ParticleEmitter") then
				Particle.Enabled = true
				Particle:Emit(Particle:GetAttribute("EmitCount") or 1)
			end
		end
	end

	for _, Effect: Instance in EffectTemplate:GetChildren() do
		if not Effect:IsA("Beam") then
			continue
		end

		local Beam: Beam = Effect:Clone()
		Beam.Attachment0 = Attachments[Effect.Attachment0]
		Beam.Attachment1 = Attachments[Effect.Attachment1]
		Beam.Enabled = true
		Beam.Parent = EffectFolder
	end

	task.spawn(function()
		while Holder.Parent and RootPart.Parent and Humanoid.Health > 0 do
			Holder.Position = RootPart.Position
			RunService.Heartbeat:Wait()
		end
	end)

	Debris:AddItem(EffectFolder, Duration)
end

-- // Server Functions
function CombatEffects.new(CombatService)
	local self = setmetatable({}, CombatEffects)
	self.CombatService = CombatService
	return self
end

function CombatEffects:UpdateZombieSpeed(Zombie: Model)
	local Humanoid: Humanoid = CombatUtility.GetHumanoid(Zombie)

	if not Humanoid then
		return
	end

	local SlowMultiplier: number = 1

	if Zombie:GetAttribute("Wet") then
		SlowMultiplier = math.min(SlowMultiplier, Zombie:GetAttribute("WetSlowMultiplier"))
	end

	if Zombie:GetAttribute("Pentagram") then
		SlowMultiplier = math.min(SlowMultiplier, Zombie:GetAttribute("PentagramSlowMultiplier"))
	end

	if Zombie:GetAttribute("PinkSlime") then
		SlowMultiplier = math.min(SlowMultiplier, Zombie:GetAttribute("PinkSlimeSlowMultiplier"))
	end

	Humanoid.WalkSpeed = Zombie:GetAttribute("BaseSpeed")
		* SlowMultiplier
end

function CombatEffects:ApplyTimedSlow(Zombie: Model, EffectName: string, Slow: number, Duration: number)
	local UntilAttribute: string = EffectName .. "Until"
	local SlowAttribute: string = EffectName .. "SlowMultiplier"
	local ExpiresAt: number = os.clock() + Duration

	Zombie:SetAttribute(EffectName, true)
	Zombie:SetAttribute(SlowAttribute, 1 - Slow)
	Zombie:SetAttribute(UntilAttribute, ExpiresAt)
	self:UpdateZombieSpeed(Zombie)

	task.delay(Duration, function()
		if not Zombie.Parent or os.clock() < (Zombie:GetAttribute(UntilAttribute) or 0) then
			return
		end

		Zombie:SetAttribute(EffectName, nil)
		Zombie:SetAttribute(SlowAttribute, nil)
		Zombie:SetAttribute(UntilAttribute, nil)
		self:UpdateZombieSpeed(Zombie)
	end)
end

function CombatEffects:ApplyWet(Zombie: Model, CharacterData, BattleSpeed: number)
	local Duration: number = CharacterData.Duration / BattleSpeed

	self:ApplyTimedSlow(Zombie, "Wet", CharacterData.Slow, Duration)
	AddHighlight(Zombie, "WetHighlight", Color3.fromRGB(70, 145, 255), Duration)
	AddDamageEffect(Zombie, "Wet", Duration)
end

function CombatEffects:ApplyPentagram(Zombie: Model, CharacterData, BattleSpeed: number)
	local Duration: number = CharacterData.Duration / BattleSpeed
	local ExpiresAt: number = os.clock() + Duration

	self:ApplyTimedSlow(Zombie, "Pentagram", CharacterData.Slow, Duration)
	Zombie:SetAttribute("DamageMultiplier", CharacterData.DamageMultiplier)
	Zombie:SetAttribute("DamageMultiplierUntil", ExpiresAt)
	AddPentagram(Zombie, Duration)

	task.delay(Duration, function()
		if not Zombie.Parent or os.clock() < (Zombie:GetAttribute("DamageMultiplierUntil") or 0) then
			return
		end

		Zombie:SetAttribute("DamageMultiplier", nil)
		Zombie:SetAttribute("DamageMultiplierUntil", nil)
	end)
end

function CombatEffects:ApplyFreeze(Zombie: Model, CharacterData, BattleSpeed: number)
	local Time: number = os.clock()

	if Time < (Zombie:GetAttribute("FreezeImmuneUntil") or 0) then
		return
	end

	local Duration: number = CharacterData.Duration / BattleSpeed
	local Immunity: number = CharacterData.Immunity / BattleSpeed
	Zombie:SetAttribute("FrozenUntil", Time + Duration)
	Zombie:SetAttribute("FreezeImmuneUntil", Time + Duration + Immunity)
	AddHighlight(Zombie, "FrozenHighlight", Color3.fromRGB(145, 220, 255), Duration)
	AddDamageEffect(Zombie, "Ice", Duration)
end

function CombatEffects:ApplyPinkSlime(Zombie: Model, CharacterData, BattleSpeed: number)
	local Duration: number = CharacterData.Duration / BattleSpeed

	self:ApplyTimedSlow(Zombie, "PinkSlime", CharacterData.Slow, Duration)
	AddHighlight(Zombie, "PinkSlimeHighlight", Color3.fromRGB(255, 75, 210), Duration)
	AddDamageEffect(Zombie, "PinkSlime", Duration)
end

function CombatEffects:ApplyCharacterEffect(WaveData, CharacterData, Zombie: Model)
	if CharacterData.Ability == "Wet" then
		self:ApplyWet(Zombie, CharacterData, WaveData.Speed)
	elseif CharacterData.Ability == "Freeze" and RandomGenerator:NextNumber() <= CharacterData.Chance then
		self:ApplyFreeze(Zombie, CharacterData, WaveData.Speed)
	elseif CharacterData.Ability == "Pentagram" then
		self:ApplyPentagram(Zombie, CharacterData, WaveData.Speed)
	elseif CharacterData.Ability == "PinkSlime" then
		self:ApplyPinkSlime(Zombie, CharacterData, WaveData.Speed)
	end
end

function CombatEffects:DealDamage(Player: Player, Zombie: Model, Damage: number, Critical: boolean)
	local Humanoid: Humanoid = CombatUtility.GetHumanoid(Zombie)

	if not Humanoid then
		return
	end

	local FinalDamage: number = Damage
		* (Zombie:GetAttribute("DamageMultiplier") or 1)
	local HealthBefore: number = Humanoid.Health
	Humanoid:TakeDamage(FinalDamage)
	local DamageDone: number = math.min(HealthBefore, FinalDamage)

	self.CombatService.Client.CombatEffect:Fire(Player, "Damage", Zombie, DamageDone, Humanoid.Health, Humanoid.MaxHealth, Critical)
end

function CombatEffects:FireAtZombie(Player: Player, WaveData, CharacterData, WeaponData, Zombie: Model, DamageMultiplier)
	local Accuracy: number = if CharacterData.Ability == "Overcharge"
		then 1
		else WeaponData.Accuracy
	local Critical: boolean = RandomGenerator:NextNumber() <= Accuracy
	local Damage: number = WeaponData.Damage * (DamageMultiplier or 1)

	if CharacterData.Ability == "PistolMastery" and WeaponData.Type == "Pistol" then
		Damage *= CharacterData.Damage
	end

	self:ApplyCharacterEffect(WaveData, CharacterData, Zombie)

	if Critical then
		Damage *= 2
	end

	self:DealDamage(Player, Zombie, Damage, Critical)
end

function CombatEffects:FireShotgun(Player: Player, WaveData, Character: Model, CharacterData, WeaponData, Target: Model, Zombies)
	local Origin: Vector3 = Character:GetPivot().Position
	local TargetOffset: Vector3 = Target:GetPivot().Position - Origin

	if TargetOffset.Magnitude <= 0.01 then
		return
	end

	local AimDirection: Vector3 = TargetOffset.Unit
	local MinimumDot: number = math.cos(math.rad(WeaponData.ConeAngle / 2))
	local Candidates = {}

	for _, Zombie: Model in Zombies do
		local Offset: Vector3 = Zombie:GetPivot().Position - Origin
		local Distance: number = Offset.Magnitude

		if Distance <= WeaponData.PelletRange and Distance > 0.01 and AimDirection:Dot(Offset.Unit) >= MinimumDot then
			table.insert(Candidates, {
				Zombie = Zombie,
				Distance = Distance,
			})
		end
	end

	if not Candidates[1] then
		return
	end

	local Accuracy: number = if CharacterData.Ability == "Overcharge"
		then 1
		else WeaponData.Accuracy
	local Hits = {}

	for _ = 1, WeaponData.Pellets do
		local Candidate = Candidates[
			RandomGenerator:NextInteger(1, #Candidates)
		]
		local HitChance: number = math.clamp(1 - Candidate.Distance / WeaponData.PelletRange, 0, 1)

		if RandomGenerator:NextNumber() > HitChance then
			continue
		end

		local Critical: boolean = RandomGenerator:NextNumber() <= Accuracy
		local Hit = Hits[Candidate.Zombie]

		if not Hit then
			Hit = {
				Damage = 0,
				Critical = false,
			}
			Hits[Candidate.Zombie] = Hit
		end

		Hit.Damage += WeaponData.Damage * (if Critical then 2 else 1)
		Hit.Critical = Hit.Critical or Critical
	end

	for Zombie: Model, Hit in Hits do
		self:ApplyCharacterEffect(WaveData, CharacterData, Zombie)
		self:DealDamage(Player, Zombie, Hit.Damage, Hit.Critical)
	end
end

function CombatEffects:Explode(Player: Player, WaveData, CharacterData, WeaponData, Position: Vector3)
	for _, Zombie: Model in CombatUtility.GetAliveZombies(WaveData.Folder) do
		if (Zombie:GetPivot().Position - Position).Magnitude <= WeaponData.ExplosionRadius then
			self:FireAtZombie(Player, WaveData, CharacterData, WeaponData, Zombie)
		end
	end
end

function CombatEffects:ThrowGrenade(Player: Player, WaveData, CharacterData, WeaponData, Position: Vector3)
	for _, Zombie: Model in CombatUtility.GetAliveZombies(WaveData.Folder) do
		if (Zombie:GetPivot().Position - Position).Magnitude <= CharacterData.GrenadeRadius then
			self:DealDamage(Player, Zombie, WeaponData.Damage * CharacterData.GrenadeDamage, false)
		end
	end
end

-- // Exports
return CombatEffects
