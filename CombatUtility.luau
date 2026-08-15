--[[
	Scripted by: Z3NIRI
]]

-- // Services

-- // Modules

-- // Variables

-- // Core
local CombatUtility = {}

-- // Server Functions
function CombatUtility.GetHumanoid(Model: Model)
	local Humanoid: Humanoid = Model.Humanoid

	if Humanoid.Health > 0 then
		return Humanoid
	end

	return nil
end

function CombatUtility.GetAliveZombies(ZombieFolder: Folder)
	local AliveZombies = {}

	for _, Zombie: Model in ZombieFolder:GetChildren() do
		if CombatUtility.GetHumanoid(Zombie) then
			table.insert(AliveZombies, Zombie)
		end
	end

	table.sort(AliveZombies, function(First: Model, Second: Model)
		return (First:GetAttribute("RoadProgress") or 0)
			> (Second:GetAttribute("RoadProgress") or 0)
	end)

	return AliveZombies
end

function CombatUtility.GetClosestZombies(Character: Model, Zombies, TargetHealth)
	local CharacterPosition: Vector3 = Character:GetPivot().Position
	local ClosestZombies = {}
	local Distances = {}

	for _, Zombie: Model in Zombies do
		local Humanoid: Humanoid = CombatUtility.GetHumanoid(Zombie)

		if Humanoid then
			TargetHealth[Zombie] = math.min(TargetHealth[Zombie], Humanoid.Health)

			if TargetHealth[Zombie] > 0 then
				table.insert(ClosestZombies, Zombie)
				Distances[Zombie] = (Zombie:GetPivot().Position - CharacterPosition).Magnitude
			end
		end
	end

	table.sort(ClosestZombies, function(First: Model, Second: Model)
		local FirstDistance: number = Distances[First]
		local SecondDistance: number = Distances[Second]

		if FirstDistance == SecondDistance then
			return (First:GetAttribute("RoadProgress") or 0)
				> (Second:GetAttribute("RoadProgress") or 0)
		end

		return FirstDistance < SecondDistance
	end)

	return ClosestZombies
end

function CombatUtility.GetCharacters(Plot: Model)
	local Characters = {}
	local CharacterFolder: Folder = Plot:FindFirstChild("OccupiedCharacters")

	if not CharacterFolder then
		return Characters
	end

	for _, Character: Model in CharacterFolder:GetChildren() do
		if not Character:GetAttribute("IsBackup") and Character:GetAttribute("CharacterName") then
			table.insert(Characters, Character)
		end
	end

	return Characters
end

function CombatUtility.GetWeapon(Character: Model)
	local WeaponName: string = Character:GetAttribute("WeaponName")

	if not WeaponName then
		return nil
	end

	return Character:FindFirstChild(WeaponName)
end

function CombatUtility.FaceTarget(Character: Model, Zombie: Model)
	local CharacterPosition: Vector3 = Character:GetPivot().Position
	local TargetPosition: Vector3 = Zombie:GetPivot().Position
	local FlatTarget: Vector3 = Vector3.new(TargetPosition.X, CharacterPosition.Y, TargetPosition.Z)

	if (FlatTarget - CharacterPosition).Magnitude > 0.01 then
		Character:PivotTo(CFrame.lookAt(CharacterPosition, FlatTarget))
	end
end

function CombatUtility.ResetCharacters(Plot: Model)
	for _, Character: Model in CombatUtility.GetCharacters(Plot) do
		for _, Animator: Instance in Character:GetDescendants() do
			if Animator:IsA("Animator") then
				for _, Track: AnimationTrack in Animator:GetPlayingAnimationTracks() do
					if Track.Priority == Enum.AnimationPriority.Action then
						Track:Stop(0.1)
					end
				end
			end
		end

		local Glow: Highlight = Character:FindFirstChild("OverchargeGlow")

		if Glow then
			Glow:Destroy()
		end

		local Weapon: Model = CombatUtility.GetWeapon(Character)
		local Rocket: Instance = Weapon
			and Weapon:FindFirstChild("Rocket", true)

		if Rocket and Rocket:IsA("MeshPart") then
			Rocket.Transparency = 0
		end

		local DefaultPivot: CFrame = Character:GetAttribute("DefaultPivot")

		if DefaultPivot then
			Character:PivotTo(DefaultPivot)
		end
	end
end

-- // Exports
return CombatUtility
