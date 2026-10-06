-- Banana Cat Hub | Secret Quest Sea 1 (Update 30) | v3
-- UMA toggle só: "Auto Secret Quest".
-- Percorre a lista de secrets, faz as que dá para fazer agora (bosses despertados,
-- inimigos de secret, objetos para quebrar) e pula as que o script já concluiu.
-- O progresso fica salvo em Banana Cat Hub/<nick>-SecretQuestSea1.json.
-- Nomes de inimigos/objetos vêm de guias (não testados no jogo).

repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer
if getgenv().BananaSecretLoaded then return end
getgenv().BananaSecretLoaded = true

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local LP = Players.LocalPlayer

------------------------------------------------------------------
-- Settings / progresso
------------------------------------------------------------------
local FolderName = "Banana Cat Hub"
local SaveFile = FolderName .. "/" .. LP.Name .. "-SecretQuestSea1.json"
local Settings = {}

pcall(function()
	if isfile(SaveFile) then
		Settings = HttpService:JSONDecode(readfile(SaveFile))
	end
end)
Settings["Secret Done"] = Settings["Secret Done"] or {}
Settings["Secret Count"] = Settings["Secret Count"] or {}

local function Save(key, value)
	Settings[key] = value
	pcall(function()
		if not isfolder(FolderName) then
			makefolder(FolderName)
		end
		writefile(SaveFile, HttpService:JSONEncode(Settings))
	end)
end

local LogFile = FolderName .. "/secret_log.txt"
local function Log(text)
	local line = ("[%s] %s"):format(os.date("%H:%M:%S"), text)
	print("[SecretQuest] " .. line)
	pcall(function()
		if not isfolder(FolderName) then
			makefolder(FolderName)
		end
		appendfile(LogFile, line .. "\n")
	end)
end

local function Notify(text)
	pcall(function()
		A.CreateNoti({ Title = "Secret Quest", Desc = text, ShowTime = 4 })
	end)
end

------------------------------------------------------------------
-- Sea 1, time e anti-AFK
------------------------------------------------------------------
local OldWorld = game.PlaceId == 2753915549 or game.PlaceId == 85211729168715

local function FireButton(b)
	b.Selectable = true
	game:GetService("GuiService").SelectedObject = b
	local vim = game:GetService("VirtualInputManager")
	vim:SendKeyEvent(true, "Return", false, b)
	vim:SendKeyEvent(false, "Return", false, b)
end

pcall(function()
	local pg = LP:WaitForChild("PlayerGui")
	local gui
	repeat
		gui = pg:FindFirstChild("Main (minimal)") or pg:FindFirstChild("Main")
		task.wait()
	until gui
	local choose = gui:FindFirstChild("ChooseTeam")
	if choose and choose.Visible then
		local team = "Pirate"
		pcall(function()
			local old = HttpService:JSONDecode(readfile(FolderName .. "/" .. LP.Name .. "-BloxFruitBNNC.json"))
			team = old["Select Team"] or team
		end)
		pcall(function()
			FireButton(choose.Container[team == "Pirate" and "Pirates" or "Marines"].Frame.TextButton)
		end)
		task.wait(1)
		game:GetService("GuiService").SelectedObject = nil
	end
end)

LP.Idled:Connect(function()
	VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
	task.wait(1)
	VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
end)

------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------
local function getRoot()
	local c = LP.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function equipMelee()
	local char = LP.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	for _, t in ipairs(char:GetChildren()) do
		if t:IsA("Tool") and t.ToolTip == "Melee" then
			return
		end
	end
	for _, t in ipairs(LP.Backpack:GetChildren()) do
		if t:IsA("Tool") and t.ToolTip == "Melee" then
			hum:EquipTool(t)
			return
		end
	end
end

local function enableHaki()
	local char = LP.Character
	if char and not char:FindFirstChild("HasBuso") then
		pcall(function()
			RS.Remotes.CommF_:InvokeServer("Buso")
		end)
	end
end

local function Click()
	VirtualUser:CaptureController()
	VirtualUser:ClickButton1(Vector2.new(-1, 1))
end

local function instPos(inst)
	local p = inst
	while p and p ~= workspace do
		if p:IsA("BasePart") then
			return p.Position
		elseif p:IsA("Attachment") then
			return p.WorldPosition
		elseif p:IsA("Model") then
			return p:GetPivot().Position
		end
		p = p.Parent
	end
end

-- noclip + sem velocidade enquanto o script está agindo
local active = false
RunService.Stepped:Connect(function()
	if not active then
		return
	end
	local char = LP.Character
	if not char then
		return
	end
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
		end
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
end)

local function travel(cf)
	local root = getRoot()
	if not root then
		return
	end
	local d = (root.Position - cf.Position).Magnitude
	if d > 60 then
		local time = d / 280
		local tw = TweenService:Create(root, TweenInfo.new(time, Enum.EasingStyle.Linear), { CFrame = cf })
		tw:Play()
		local t0 = tick()
		while tw.PlaybackState == Enum.PlaybackState.Playing
			and Settings["Auto Secret Quest"]
			and tick() - t0 < time + 1 do
			task.wait()
		end
		tw:Cancel()
	end
	root.CFrame = cf
end

------------------------------------------------------------------
-- Lista de Secret Quests que o script consegue fazer (Sea 1, Update 30)
-- kind = "boss"  : mata o "Awakened ..." e marca como concluída
-- kind = "kill"  : mata inimigos pelo nome; concluída ao matar `need`
-- kind = "break" : bate (M1) em objetos pelo nome; concluída ao quebrar `need`
--                  (sem `need`: concluída quando não sobra nenhum)
------------------------------------------------------------------
local QUESTS = {
	{ id = "jungle_gorilla_king", kind = "boss", match = "Awakened Gorilla King" },
	{ id = "pirate_chef", kind = "boss", match = "Awakened Chef" },
	{ id = "pirate_tavern", kind = "kill", match = "Tavern Pirate", need = 3 },
	{ id = "desert_cactus", kind = "break", patterns = { "cactuspetal", "cactus petal" }, need = 10 },
	{ id = "frozen_yeti", kind = "boss", match = "Awakened Yeti" },
	{ id = "frozen_green_snowballs", kind = "break", patterns = { "greensnowball", "green snowball" }, need = 3 },
	{ id = "prison_escaped", kind = "kill", match = "Escaped Prisoner", need = 3 },
	{ id = "prison_megalo_guard", kind = "boss", match = "Megalo Guard" },
	{ id = "prison_warden", kind = "boss", match = "Awakened Warden" },
	{ id = "magma_lava", kind = "break", patterns = { "lavapocket", "lava pocket", "lavapot", "lava pot" } },
	{ id = "magma_admiral", kind = "boss", match = "Awakened Magma Admiral" },
	{ id = "marine_vice_admiral", kind = "boss", match = "Awakened Vice Admiral" },
	{ id = "underwater_fishman_lord", kind = "boss", match = "Awakened Fishman Lord" },
	{ id = "sky_warlord", kind = "boss", match = "Awakened Sky Warlord" },
	{ id = "sky_lightning_god", kind = "boss", match = "Awakened Lightning God" },
	{ id = "fountain_megalo_brute", kind = "boss", match = "Megalo Brute" },
	{ id = "fountain_cyborg", kind = "boss", match = "Awakened Cyborg" },
}

local function isDone(q)
	return Settings["Secret Done"][q.id] == true
end

local function markDone(q)
	Settings["Secret Done"][q.id] = true
	Save("Secret Done", Settings["Secret Done"])
	Log("Concluída: " .. q.id)
	Notify("Concluída: " .. q.id)
end

local function getCount(q)
	return Settings["Secret Count"][q.id] or 0
end

local function addCount(q)
	Settings["Secret Count"][q.id] = getCount(q) + 1
	Save("Secret Count", Settings["Secret Count"])
	if q.need and getCount(q) >= q.need then
		markDone(q)
	end
end

------------------------------------------------------------------
-- Lutar (boss / kill)
------------------------------------------------------------------
local HEIGHT = 25

local function findEnemy(q)
	local folder = workspace:FindFirstChild("Enemies")
	if not folder then
		return
	end
	for _, m in ipairs(folder:GetChildren()) do
		if m:IsA("Model") and m.Name:find(q.match, 1, true) then
			local h = m:FindFirstChildOfClass("Humanoid")
			local r = m:FindFirstChild("HumanoidRootPart")
			if h and r and h.Health > 0 then
				return m, h, r
			end
		end
	end
end

local function fight(model, hum, root)
	active = true
	travel(root.CFrame * CFrame.new(0, HEIGHT, 0))
	while Settings["Auto Secret Quest"] and model.Parent and hum.Health > 0 do
		local me = getRoot()
		if not me or not root.Parent then
			break
		end
		me.CFrame = root.CFrame * CFrame.new(0, HEIGHT, 0)
		equipMelee()
		enableHaki()
		Click()
		task.wait(0.1)
	end
	active = false
	return hum.Health <= 0
end

------------------------------------------------------------------
-- Quebrar objetos (break)
------------------------------------------------------------------
local broken = {}
local scanAt = {}

local function findBreakable(patterns)
	local root = getRoot()
	if not root then
		return
	end
	local enemies = workspace:FindFirstChild("Enemies")
	local best, bestPos, bestDist
	for _, d in ipairs(workspace:GetDescendants()) do
		if (d:IsA("BasePart") or d:IsA("Model")) and not broken[d] then
			local low = d.Name:lower()
			for _, p in ipairs(patterns) do
				if low:find(p, 1, true) then
					if not (enemies and d:IsDescendantOf(enemies)) and not d:IsDescendantOf(LP.Character or workspace) then
						local pos = instPos(d)
						if pos then
							local dist = (pos - root.Position).Magnitude
							if not bestDist or dist < bestDist then
								best, bestPos, bestDist = d, pos, dist
							end
						end
					end
					break
				end
			end
		end
	end
	return best, bestPos
end

local function breakOne(q)
	local target, pos = findBreakable(q.patterns)
	if not target then
		return false
	end
	Log("Quebrando: " .. target:GetFullName())
	active = true
	travel(CFrame.new(pos + Vector3.new(0, 3, 0)))
	local t0 = tick()
	while Settings["Auto Secret Quest"] and target.Parent and tick() - t0 < 6 do
		local me = getRoot()
		if not me then
			break
		end
		me.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
		equipMelee()
		Click()
		task.wait(0.15)
		pos = instPos(target) or pos
	end
	active = false
	broken[target] = true
	if not target.Parent then
		addCount(q)
	end
	return true
end

------------------------------------------------------------------
-- Loop principal: pega a primeira quest pendente que dá para fazer agora
------------------------------------------------------------------
task.spawn(function()
	while task.wait(0.5) do
		if Settings["Auto Secret Quest"] and OldWorld then
			pcall(function()
				for _, q in ipairs(QUESTS) do
					if not isDone(q) then
						if q.kind == "boss" or q.kind == "kill" then
							local model, hum, root = findEnemy(q)
							if model then
								Log("Atacando " .. model.Name .. " (" .. q.id .. ")")
								local killed = fight(model, hum, root)
								if killed then
									if q.kind == "boss" then
										markDone(q)
									else
										addCount(q)
									end
								end
								return
							end
						elseif q.kind == "break" then
							if tick() - (scanAt[q.id] or 0) > 4 then
								scanAt[q.id] = tick()
								if breakOne(q) then
									return
								elseif not q.need and getCount(q) >= 1 then
									markDone(q)
								end
							end
						end
					end
				end
			end)
		else
			active = false
		end
	end
end)

------------------------------------------------------------------
-- UI: uma toggle só
------------------------------------------------------------------
A = loadstring(game:HttpGet("https://raw.githubusercontent.com/obiiyeuem/vthangsitink/refs/heads/main/zzzz.lua"))()
local Main = A.CreateMain({ Title = "Banana Cat Hub  By Shigaraki [Beta]", Desc = "By Shigaraki [Beta]" })
local Page = Main.CreatePage({ Page_Name = "Secret Quest Sea 1", Page_Title = "Secret Quest Sea 1" })
local Section = Page.CreateSection("Secret Quest")
Section.CreateToggle({
	Title = "Auto Secret Quest",
	Desc = nil,
	Default = Settings["Auto Secret Quest"] or false,
}, function(v)
	Save("Auto Secret Quest", v)
end)

if not OldWorld then
	Notify("Você não está no Sea 1.")
end
