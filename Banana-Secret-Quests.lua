-- Banana Cat Hub | Secret Quest Sea 1 (Update 30) | v1
-- Esta versão tem SÓ as funções de Secret Quest do Sea 1.
-- v2: Auto Awakened Boss + inimigos das secrets + quebrar objetos + ir/interagir com NPCs
-- + ferramentas de log. Nomes de objetos/NPCs vêm de guias (não testados): use o log para ajustar.

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
-- Settings (arquivo próprio, não mexe nas configs do hub antigo)
------------------------------------------------------------------
local FolderName = "Banana Cat Hub"
local SaveFile = FolderName .. "/" .. LP.Name .. "-SecretQuestSea1.json"
local Settings = {}

pcall(function()
	if isfile(SaveFile) then
		Settings = HttpService:JSONDecode(readfile(SaveFile))
	end
end)

local function Save(key, value)
	Settings[key] = value
	pcall(function()
		if not isfolder(FolderName) then
			makefolder(FolderName)
		end
		writefile(SaveFile, HttpService:JSONEncode(Settings))
	end)
end

------------------------------------------------------------------
-- Sea 1 check + escolha de time + anti-AFK
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
		-- usa o time salvo no hub antigo, se existir
		local team = "Pirate"
		pcall(function()
			local old = HttpService:JSONDecode(readfile(FolderName .. "/" .. LP.Name .. "-BloxFruitBNNC.json"))
			team = old["Select Team"] or team
		end)
		local path = team == "Pirate" and "Pirates" or "Marines"
		pcall(function()
			FireButton(choose.Container[path].Frame.TextButton)
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
-- Log (arquivo Banana Cat Hub/secret_log.txt + console F9)
------------------------------------------------------------------
local LogFile = FolderName .. "/secret_log.txt"

local function Log(text)
	local line = ("[%s] %s"):format(os.date("%H:%M:%S"), text)
	print("[SecretLog] " .. line)
	pcall(function()
		if not isfolder(FolderName) then
			makefolder(FolderName)
		end
		appendfile(LogFile, line .. "\n")
	end)
end

local function fmt(v, depth)
	depth = depth or 0
	local t = typeof(v)
	if t == "string" then
		return '"' .. v .. '"'
	elseif t == "Instance" then
		return v:GetFullName()
	elseif t == "table" then
		if depth > 1 then
			return "{...}"
		end
		local parts, n = {}, 0
		for k, x in pairs(v) do
			n += 1
			if n > 8 then
				parts[#parts + 1] = "..."
				break
			end
			parts[#parts + 1] = tostring(k) .. "=" .. fmt(x, depth + 1)
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(v)
end

------------------------------------------------------------------
-- Helpers de personagem
------------------------------------------------------------------
local function getRoot()
	local c = LP.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local WeaponTypes = { "Melee", "Sword", "Gun", "Blox Fruit" }

local function equipType(tp)
	local char = LP.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	for _, t in ipairs(char:GetChildren()) do
		if t:IsA("Tool") and t.ToolTip == tp then
			return
		end
	end
	for _, t in ipairs(LP.Backpack:GetChildren()) do
		if t:IsA("Tool") and t.ToolTip == tp then
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

local farmingBoss, farmingBreak = false, false

RunService.Stepped:Connect(function()
	if not (farmingBoss or farmingBreak) then
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

local function travel(cf, key)
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
			and Settings[key or "Auto Awakened Boss"]
			and tick() - t0 < time + 1 do
			task.wait()
		end
		tw:Cancel()
	end
	root.CFrame = cf
end

------------------------------------------------------------------
-- Auto Awakened Boss (Sea 1)
-- Procura em workspace.Enemies qualquer modelo com "Awakened" no nome
-- (Gorilla King, Yeti, Warden, Magma Admiral, Vice Admiral, Fishman Lord,
-- Sky Warlord, Lightning God, Cyborg, Chef) e ataca.
------------------------------------------------------------------
local BOSS_HEIGHT = 25

local KILL_PATTERNS = { "Awakened", "Megalo", "Escaped Prisoner", "Tavern Pirate" }

local function isSecretEnemy(name)
	for _, p in ipairs(KILL_PATTERNS) do
		if name:find(p, 1, true) then
			return true
		end
	end
	return false
end

local function findAwakened()
	local folder = workspace:FindFirstChild("Enemies")
	if not folder then
		return
	end
	for _, m in ipairs(folder:GetChildren()) do
		if m:IsA("Model") and isSecretEnemy(m.Name) then
			local h = m:FindFirstChildOfClass("Humanoid")
			local r = m:FindFirstChild("HumanoidRootPart")
			if h and r and h.Health > 0 then
				return m, h, r
			end
		end
	end
end

task.spawn(function()
	local notified = {}
	while task.wait(0.3) do
		if Settings["Auto Awakened Boss"] and OldWorld then
			pcall(function()
				local boss, hum, root = findAwakened()
				if not boss then
					farmingBoss = false
					return
				end
				if not notified[boss] then
					notified[boss] = true
					Log("Inimigo de secret encontrado: " .. boss.Name)
					pcall(function()
						A.CreateNoti({ Title = "Secret Quest", Desc = "Indo atacar " .. boss.Name, ShowTime = 4 })
					end)
				end
				farmingBoss = true
				travel(root.CFrame * CFrame.new(0, BOSS_HEIGHT, 0))
				while Settings["Auto Awakened Boss"] and boss.Parent and hum.Health > 0 do
					local myRoot = getRoot()
					if not myRoot or not root.Parent then
						break
					end
					myRoot.CFrame = root.CFrame * CFrame.new(0, BOSS_HEIGHT, 0)
					equipType(Settings["Select Weapon"] or "Melee")
					enableHaki()
					Click()
					task.wait(0.1)
				end
				farmingBoss = false
			end)
		else
			farmingBoss = false
		end
	end
end)

------------------------------------------------------------------
-- Ferramentas de log (para mapear as quests que ainda não têm função)
------------------------------------------------------------------
local skipRemotes = { RigControllerEvent = true, Attack = true, RE = true }
local oldNamecall

local function startRemoteLog()
	if oldNamecall then
		return
	end
	if not (hookmetamethod and getnamecallmethod) then
		Log("Executor sem hookmetamethod: Log Remotes indisponível")
		return
	end
	oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
		local m = getnamecallmethod()
		if getgenv().BananaLogRemotes
			and (m == "InvokeServer" or m == "FireServer")
			and typeof(self) == "Instance"
			and not skipRemotes[self.Name] then
			local args = { ... }
			task.spawn(function()
				pcall(function()
					Log(m .. " " .. self:GetFullName() .. " (" .. fmt(args) .. ")")
				end)
			end)
		end
		return oldNamecall(self, ...)
	end)
end

-- frases dos avisos das secrets (vindas do guia da Update 30)
local phrases = {
	"secret", "awakened", "cloud", "alarm", "storm", "bell", "junkyard",
	"stirring", "cell creaks", "invaded", "closing in", "crowd", "lightning",
}
local seen = {}

local function checkText(text, where)
	local low = text:lower()
	for _, p in ipairs(phrases) do
		if low:find(p, 1, true) then
			if not seen[text] then
				seen[text] = true
				Log("MSG (" .. where .. "): " .. text)
			end
			return
		end
	end
end

LP:WaitForChild("PlayerGui").DescendantAdded:Connect(function(d)
	if getgenv().BananaLogMessages and d:IsA("TextLabel") then
		task.wait()
		pcall(function()
			if d.Text and #d.Text > 3 then
				checkText(d.Text, d:GetFullName())
			end
		end)
	end
end)

pcall(function()
	local tcs = game:GetService("TextChatService")
	tcs.MessageReceived:Connect(function(msg)
		if getgenv().BananaLogMessages then
			checkText(msg.Text or "", "chat")
		end
	end)
end)

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

local function dumpNear(radius)
	local root = getRoot()
	if not root then
		return
	end
	Log(("=== DUMP raio %d em %s ==="):format(radius, tostring(root.Position)))
	local n = 0
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") or d:IsA("ClickDetector") then
			local pos = instPos(d)
			if pos and (pos - root.Position).Magnitude <= radius then
				n += 1
				if n > 60 then
					Log("... (limite de 60 linhas)")
					break
				end
				local extra = ""
				if d:IsA("ProximityPrompt") then
					extra = (" action='%s' object='%s'"):format(d.ActionText, d.ObjectText)
				end
				Log(("%s %s%s dist=%d"):format(d.ClassName, d:GetFullName(), extra, (pos - root.Position).Magnitude))
			end
		end
	end
	local npcs = workspace:FindFirstChild("NPCs")
	if npcs then
		for _, m in ipairs(npcs:GetChildren()) do
			local pos = instPos(m)
			if pos and (pos - root.Position).Magnitude <= radius then
				Log(("NPC %s dist=%d"):format(m.Name, (pos - root.Position).Magnitude))
			end
		end
	end
	Log("=== fim do dump ===")
end

------------------------------------------------------------------
-- Auto Break Secret Objects
-- Bate (M1) em objetos de secrets pelo nome: Cactus Petals (Desert),
-- snowballs verdes (Yeti), lava pockets / pote de lava (Magma).
-- Nomes vêm de guias: se algum não bater, use Dump/Log e ajuste BREAK_PATTERNS.
------------------------------------------------------------------
local BREAK_PATTERNS = { "cactuspetal", "cactus petal", "snowball", "lavapocket", "lava pocket", "lavapot", "lava pot" }
local broken = {}

local function findBreakable()
	local root = getRoot()
	if not root then
		return
	end
	local enemies = workspace:FindFirstChild("Enemies")
	local best, bestPos, bestDist
	for _, d in ipairs(workspace:GetDescendants()) do
		if (d:IsA("BasePart") or d:IsA("Model")) and not broken[d] then
			local low = d.Name:lower()
			for _, p in ipairs(BREAK_PATTERNS) do
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

task.spawn(function()
	while task.wait(1.5) do
		if Settings["Auto Break Secret Objects"] and OldWorld and not findAwakened() then
			pcall(function()
				local target, pos = findBreakable()
				if not target then
					return
				end
				Log("Quebrando objeto de secret: " .. target:GetFullName())
				farmingBreak = true
				travel(CFrame.new(pos + Vector3.new(0, 3, 0)), "Auto Break Secret Objects")
				local t0 = tick()
				while Settings["Auto Break Secret Objects"] and target.Parent and tick() - t0 < 6 do
					local r = getRoot()
					if not r then
						break
					end
					r.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
					equipType(Settings["Select Weapon"] or "Melee")
					Click()
					task.wait(0.15)
					pos = instPos(target) or pos
				end
				broken[target] = true
				farmingBreak = false
			end)
			farmingBreak = false
		end
	end
end)

------------------------------------------------------------------
-- NPCs das secrets: ir até o NPC e interagir (prompt / click)
-- Escolha de diálogo (Rumor, Breach Door...) ainda é manual.
------------------------------------------------------------------
local SecretNPCs = {
	["Pirate Adventurer"] = { "pirate adventurer" },
	["Secrets Master (Middletown)"] = { "secrets master", "secret master" },
	["Palrus (Marine Fortress)"] = { "palrus" },
	["Mad Scientist (Lower Sky)"] = { "mad scientist" },
	["Sky Quest Giver 2 (Upper Skylands)"] = { "sky quest giver 2" },
	["Freezebug (Fountain City)"] = { "freezebug" },
	["Experienced Captain (Middletown)"] = { "experienced captain" },
	["Janus (Middletown)"] = { "janus" },
	["Emperor (Colosseum)"] = { "emperor" },
}
local SecretNPCList = {}
for name in pairs(SecretNPCs) do
	SecretNPCList[#SecretNPCList + 1] = name
end
table.sort(SecretNPCList)

local function findNPC(key)
	local queries = SecretNPCs[key]
	if not queries then
		return
	end
	local enemies = workspace:FindFirstChild("Enemies")
	local containers = {}
	if workspace:FindFirstChild("NPCs") then
		table.insert(containers, workspace.NPCs)
	end
	table.insert(containers, workspace)
	for _, container in ipairs(containers) do
		if container then
			for _, q in ipairs(queries) do
				for _, d in ipairs(container:GetDescendants()) do
					if d:IsA("Model") and d.Name:lower():find(q, 1, true) and not (enemies and d:IsDescendantOf(enemies)) then
						return d
					end
				end
			end
		end
	end
end

local function goToNPC(key, interact)
	local npc = findNPC(key)
	if not npc then
		Log("NPC não encontrado: " .. tostring(key) .. " (talvez esteja em outra ilha)")
		pcall(function()
			A.CreateNoti({ Title = "Secret Quest", Desc = "NPC não encontrado nesta área", ShowTime = 4 })
		end)
		return
	end
	local pos = instPos(npc)
	if not pos then
		return
	end
	farmingBreak = true
	Settings.__tp = true
	travel(CFrame.new(pos + Vector3.new(0, 3, 4)), "__tp")
	Settings.__tp = nil
	farmingBreak = false
	Log("Teleportado para NPC: " .. npc:GetFullName())
	if interact then
		for _, d in ipairs(npc:GetDescendants()) do
			if d:IsA("ProximityPrompt") and fireproximityprompt then
				pcall(function()
					fireproximityprompt(d)
				end)
			elseif d:IsA("ClickDetector") and fireclickdetector then
				pcall(function()
					fireclickdetector(d)
				end)
			end
		end
	end
end

------------------------------------------------------------------
-- UI
------------------------------------------------------------------
A = loadstring(game:HttpGet("https://raw.githubusercontent.com/obiiyeuem/vthangsitink/refs/heads/main/zzzz.lua"))()
local Main = A.CreateMain({ Title = "Banana Cat Hub  By Shigaraki [Beta]", Desc = "By Shigaraki [Beta]" })
local Page = Main.CreatePage({ Page_Name = "Secret Quest Sea 1", Page_Title = "Secret Quest Sea 1" })

local SectionBoss = Page.CreateSection("Awakened Bosses")
SectionBoss.CreateDropdown({
	Title = "Select Weapon",
	List = WeaponTypes,
	Search = true,
	Selected = false,
	Default = Settings["Select Weapon"] or nil,
}, function(v)
	Save("Select Weapon", v)
end)
SectionBoss.CreateToggle({
	Title = "Auto Awakened Boss",
	Desc = nil,
	Default = Settings["Auto Awakened Boss"] or false,
}, function(v)
	Save("Auto Awakened Boss", v)
end)

local SectionObjects = Page.CreateSection("Secret Objects")
SectionObjects.CreateToggle({
	Title = "Auto Break Secret Objects",
	Desc = nil,
	Default = Settings["Auto Break Secret Objects"] or false,
}, function(v)
	Save("Auto Break Secret Objects", v)
end)

local SectionNPC = Page.CreateSection("Secret NPCs")
SectionNPC.CreateDropdown({
	Title = "Select Secret NPC",
	List = SecretNPCList,
	Search = true,
	Selected = false,
	Default = Settings["Select Secret NPC"] or nil,
}, function(v)
	Save("Select Secret NPC", v)
end)
SectionNPC.CreateButton({ Title = "Teleport To NPC" }, function()
	task.spawn(goToNPC, Settings["Select Secret NPC"], false)
end)
SectionNPC.CreateButton({ Title = "Teleport + Interact NPC" }, function()
	task.spawn(goToNPC, Settings["Select Secret NPC"], true)
end)

local SectionDev = Page.CreateSection("Secret Dev Tools")
SectionDev.CreateToggle({
	Title = "Log Remotes",
	Desc = nil,
	Default = false,
}, function(v)
	getgenv().BananaLogRemotes = v
	if v then
		startRemoteLog()
	end
end)
SectionDev.CreateToggle({
	Title = "Log Secret Messages",
	Desc = nil,
	Default = false,
}, function(v)
	getgenv().BananaLogMessages = v
end)
SectionDev.CreateButton({ Title = "Dump NPCs / Prompts (raio 60)" }, function()
	dumpNear(60)
end)
SectionDev.CreateButton({ Title = "Clear Log" }, function()
	pcall(function()
		writefile(LogFile, "")
	end)
end)

if not OldWorld then
	pcall(function()
		A.CreateNoti({ Title = "Secret Quest", Desc = "Você não está no Sea 1.", ShowTime = 6 })
	end)
end
