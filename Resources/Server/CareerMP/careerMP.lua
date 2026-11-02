--CareerMP (SERVER) by Dudekahedron, 2026
--Thanks to Bouboule, and Lion and Luuk from BeamPaint, for http request examples

local HARD_CLIENT_VERSION = {major = 0, minor = 1, revision = 0}
local HARD_SERVER_VERSION = {major = 0, minor = 1, revision = 0}

local RAW = "https://raw.githubusercontent.com/"
local GITHUB_REPO = "MisterP-dev/CareerMP-Server-Authoritive/"
local BRANCH = "main/"
local CLIENT_PATH = "Resources/Client/"
local CLIENT_FILE = "CareerMP.zip"
local SERVER_PATH = "Resources/Server/CareerMP/"
local SERVER_FILE = "careerMP.lua"
local CLIENT_VERSION_FILE = "versions/client.json"
local SERVER_VERSION_FILE = "versions/server.json"
local CLIENT_URL = RAW .. GITHUB_REPO .. BRANCH .. CLIENT_PATH .. CLIENT_FILE
local SERVER_URL = RAW .. GITHUB_REPO .. BRANCH .. SERVER_PATH .. SERVER_FILE
local CLIENT_UPDATE_URL = RAW .. GITHUB_REPO .. BRANCH .. SERVER_PATH .. CLIENT_VERSION_FILE
local SERVER_UPDATE_URL = RAW .. GITHUB_REPO .. BRANCH .. SERVER_PATH .. SERVER_VERSION_FILE

local configPath = "Resources/Server/CareerMP/config/"

local willExit = false

local defaultConfig = {
	server = {
		autoUpdate = false,
		autoExit = true,
		longWindowMax = 10000,
		shortWindowMax = 1000,
		longWindowSeconds = 300,
		shortWindowSeconds = 30,
		allowTransactions = true,
		sessionSendingMax = 100000,
		sessionReceiveMax = 200000,
		requireAccount = true,
		startingMoney = 10000,
		incomeLimitSingle = 250000,
		incomeLimitPerHour = 1000000,
		saleLimitSingle = 5000000,
		saleLimitPerHour = 10000000,
		blockCheatIncome = true,
		kickOnMoneyViolation = false,
		kickOnForeignSave = true,
		maxSaveSizeMB = 32,
		backupCount = 5,
		autoSaveMinutes = 5,
		saveCommandCooldown = 30,
	},
	client = {
		localUnicycleGhost = false,
		remoteUnicycleGhost = true,
		remoteVehicleGhost = false,
		serverSaveName = "",
		serverSaveSuffix = "",
		serverSaveNameEnabled = false,
		roadTrafficAmount = 10,
		extraTrafficAmount = 0,
		parkedTrafficAmount = 10,
		roadTrafficEnabled = true,
		extraTrafficEnabled = false,
		parkedTrafficEnabled = true,
		sharedTraffic = true,
		worldEditorEnabled = false,
		consoleEnabled = false,
		simplifyRemoteVehicles = false,
		spawnVehicleIgnitionLevel = 0,
		skipOtherPlayersVehicles = false,
		trafficSmartSelections = true,
		trafficSimpleVehicles = true,
		trafficAllowMods = false
	}
}

local pendingActivation = {}
local activationThreshold = 90
local vehicleStates = {}
local loadedPrefabs = {}

local SAVE_PATH = "Resources/Server/CareerMP/saves/"
local SAVE_CHUNK_SIZE = 1000000

local careerStates = {}
local saveUploads = {}
local incomeHistory = {}
local transferCounter = 0
local trafficHost

local coreSaveFiles = {
	"info.json",
	"career/general.json",
	"career/playerAttributes.json",
	"career/inventory.json"
}

local saleTags = {
	selling = true,
	vehicleSold = true,
	partsSold = true
}

local cheatTags = {
	cheat = true,
	Cheat = true
}

local signalTimer = MP.CreateTimer()

local ledger = {
	send = {},
	receive = {}
}

local trapNames = {
	[1] = "Riverway Plaza",
	[2] = "Plaza Northbound",
	[3] = "Plaza Southbound",
	[4] = "Beach",
	[5] = "Lighthouse",
	[6] = "Island Port Northbound",
	[7] = "Island Port Southbound"
}

local function downloadVersionFile(url, path)
	local response
    if MP.GetOSName() == "Windows" then
        response = os.execute('powershell -Command "Invoke-WebRequest -Uri ' .. url .. ' -OutFile ' .. path .. '"')
    else
        response = os.execute("wget -q -O " .. path .. " " .. url)
    end
	if response then
		local file = io.open(path, "r")
		if file then
			local data = file:read("*all")
			file:close()
			return data
		end
	else
		return nil
	end
end

local function downloadFile(url, path)
	local response
    if MP.GetOSName() == "Windows" then
        response = os.execute('powershell -Command "Invoke-WebRequest -Uri ' .. url .. ' -OutFile ' .. path .. '"')
    else
        response = os.execute("wget -q -O " .. path .. " " .. url)
    end
	return response
end

local function needsUpdate(installedVersion, latest)
    local components = { "major", "minor", "revision" }
    for _, key in pairs(components) do
        local i, l = installedVersion[key] or 0, latest[key] or 0
        if l > i then
            return true
        end
        if l < i then
            return false
        end
    end
    return false
end

local function updateClient()
    local installedVersion = ReadJson(SERVER_PATH .. CLIENT_VERSION_FILE)
	local installed = FS.Exists(CLIENT_PATH .. CLIENT_FILE)
	if not installed then
		print("[CareerMP] ---------- CareerMP Update Client not installed, downloading...")
		downloadFile(CLIENT_URL, CLIENT_PATH .. CLIENT_FILE)
	end
	if not installedVersion then
        print("[CareerMP] ---------- CareerMP Update Applying self version!")
		installedVersion = HARD_CLIENT_VERSION
		WriteJson(SERVER_PATH .. CLIENT_VERSION_FILE, HARD_CLIENT_VERSION)
	end
    local latestVersionFile = downloadVersionFile(CLIENT_UPDATE_URL, SERVER_PATH .. CLIENT_VERSION_FILE)
	local latest = Util.JsonDecode(latestVersionFile)
    if not latest then
        print("[CareerMP] ---------- CareerMP Update Failed to fetch latest client version!")
        return
    end
	local update = needsUpdate(installedVersion, latest)
    if installedVersion then
        print("[CareerMP] ---------- CareerMP Update Client installed: " .. installedVersion.major .. "." .. installedVersion.minor .. "." .. installedVersion.revision)
        print("[CareerMP] ---------- CareerMP Update Client latest: " .. latest.major .. "." .. latest.minor .. "." .. latest.revision)
        if update then
			print("[CareerMP] ---------- CareerMP Update Updating client...")
			downloadFile(CLIENT_URL, CLIENT_PATH .. CLIENT_FILE)
			print("[CareerMP] ---------- CareerMP Update Client updated to " ..  latest.major .. "." .. latest.minor .. "." .. latest.revision .. "! Restart the server to apply the update!")
		else
			print("[CareerMP] ---------- CareerMP Update Client up to date!")
			return
		end
	else
		print("[CareerMP] ---------- CareerMP Update Client version not found.")
        downloadFile(CLIENT_URL, CLIENT_PATH .. CLIENT_FILE)
        print("[CareerMP] ---------- CareerMP Update Client version updated to " ..  latest.major .. "." .. latest.minor .. "." .. latest.revision .. "! Restart the server to apply the update!")
    end
	return update
end

local function updateServer()
    local installedVersion = ReadJson(SERVER_PATH .. SERVER_VERSION_FILE)
	local installed = FS.Exists(SERVER_PATH .. SERVER_FILE)
	if not installed then
		print("[CareerMP] ---------- CareerMP Update Server not installed, downloading...")
		downloadFile(SERVER_URL, SERVER_PATH .. SERVER_FILE)
	end
	if not installedVersion then
        print("[CareerMP] ---------- CareerMP Update Applying self version!")
		installedVersion = HARD_SERVER_VERSION
		WriteJson(SERVER_PATH .. SERVER_VERSION_FILE, HARD_SERVER_VERSION)
	end
    local latestVersionFile = downloadVersionFile(SERVER_UPDATE_URL, SERVER_PATH .. SERVER_VERSION_FILE)
    local latest = Util.JsonDecode(latestVersionFile)
    if not latest then
        print("[CareerMP] ---------- CareerMP Update Failed to fetch latest server version")
        return
    end
	local update = needsUpdate(installedVersion, latest)
    if installedVersion then
        print("[CareerMP] ---------- CareerMP Update Server installed: " .. installedVersion.major .. "." .. installedVersion.minor .. "." .. installedVersion.revision)
        print("[CareerMP] ---------- CareerMP Update Server latest: " .. latest.major .. "." .. latest.minor .. "." .. latest.revision)
        if update then
			print("[CareerMP] ---------- CareerMP Update Updating server...")
			downloadFile(SERVER_URL, SERVER_PATH .. SERVER_FILE)
			print("[CareerMP] ---------- CareerMP Update Server updated to " ..  latest.major .. "." .. latest.minor .. "." .. latest.revision .. "! Restart the server to apply the update!")
		else
			print("[CareerMP] ---------- CareerMP Update Server up to date!")
			return
		end
	else
		print("[CareerMP] ---------- CareerMP Update Server version not found.")
        downloadFile(SERVER_URL, SERVER_PATH .. SERVER_FILE)
        print("[CareerMP] ---------- CareerMP Update Server version updated to " ..  latest.major .. "." .. latest.minor .. "." .. latest.revision .. "! Restart the server to apply the update!")
    end
	return update
end

local function parseQuotedString(input, startIndex)
	local closingQuoteIndex = input:find('"', startIndex + 1)
	if closingQuoteIndex then
		local value = input:sub(startIndex + 1, closingQuoteIndex - 1)
		return value, closingQuoteIndex + 2
	else
		local value = input:sub(startIndex + 1)
		return value, nil
	end
end

local function parseWord(input, startIndex)
	local nextSpaceIndex = input:find(' ', startIndex)
	if nextSpaceIndex then
		local value = input:sub(startIndex, nextSpaceIndex - 1)
		return value, nextSpaceIndex + 1
	else
		return input:sub(startIndex), nil
	end
end

local function parseCommand(message, separator)
	local arguments = {}
	local command = nil
	if separator then
		command = message:sub(1, separator - 1)
		local argumentsString = message:sub(separator + 1)
		local currentIndex = 1
		while currentIndex <= #argumentsString do
			local currentChar = argumentsString:sub(currentIndex, currentIndex)
			if currentChar == '"' then
				local value, nextIndex = parseQuotedString(argumentsString, currentIndex)
				table.insert(arguments, value)
				if not nextIndex then
					break
				end
				currentIndex = nextIndex
			elseif currentChar ~= ' ' then
				local value, nextIndex = parseWord(argumentsString, currentIndex)
				table.insert(arguments, value)
				if not nextIndex then
					break
				end
				currentIndex = nextIndex
			else
				currentIndex = currentIndex + 1
			end
		end
	end
	return command, arguments
end

local function prepareConfig()
	print("[CareerMP] ---------- CareerMP Config Loading...")
	Config = ReadJson(configPath .. "config.json")
	if not Config then
		print("[CareerMP] ---------- CareerMP Config Initializing...")
		Config = defaultConfig
		for section, fields in pairs(defaultConfig) do
			for field, value in pairs(fields) do
				print("[CareerMP] ---------- CareerMP Config " .. section .. " " .. field .. " set to " .. tostring(value))
			end
		end
		WriteJson(configPath .. "config.json", Config)
	else
		local updateFound
		for section, fields in pairs(defaultConfig) do
			print("[CareerMP] ---------- CareerMP Config Checking " .. section)
			if Config[section] == nil then
				updateFound = true
				print("[CareerMP] ---------- CareerMP Config Adding: " .. section)
				Config[section] = {}
				for field, value in pairs(fields) do
					print("[CareerMP] ---------- CareerMP Config " .. section .. " " .. field .. " set to " .. tostring(value))
					Config[section][field] = value
				end
			else
				for field, value in pairs(fields) do
					if Config[section][field] == nil then
						print("[CareerMP] ---------- CareerMP Config " .. section .. " " .. field .. " not found")
						print("[CareerMP] ---------- CareerMP Config " .. section .. " " .. field .. " set to " .. tostring(value))
						updateFound = true
						Config[section][field] = value
					end
				end
			end
		end
		for _, section in pairs({"client", "server"}) do
			if Config[section] then
				for field in pairs(Config[section]) do
					if defaultConfig[section][field] == nil then
						print("[CareerMP] ---------- CareerMP Config " .. section .. " " .. field .. " is invalid, removing")
						updateFound = true
						Config[section][field] = nil
					end
				end
			end
		end
		if updateFound then
			print("[CareerMP] ---------- CareerMP Config Updated!")
			WriteJson(configPath .. "config.json", Config)
		end
	end
	print("[CareerMP] ---------- CareerMP Config Loaded!")
end

local function readText(path)
	local file = io.open(path, "rb")
	if not file then
		return nil
	end
	local text = file:read("*a")
	file:close()
	return text
end

local function writeText(path, text)
	local file = io.open(path, "wb")
	if not file then
		return false
	end
	file:write(text)
	file:close()
	return true
end

local function ensureSaveDirectory()
	if not FS.IsDirectory(SAVE_PATH) then
		FS.CreateDirectory(SAVE_PATH)
	end
end

local function splitString(text, size)
	local chunks = {}
	local i, len = 1, #text
	while i <= len do
		local j = math.min(i + size - 1, len)
		while j < len and j > i do
			local b = string.byte(text, j + 1)
			if b >= 128 and b < 192 then
				j = j - 1
			else
				break
			end
		end
		table.insert(chunks, string.sub(text, i, j))
		i = j + 1
	end
	return chunks
end

local function isValidSavePath(savePath)
	if type(savePath) ~= "string" or savePath == "" or #savePath > 260 then
		return false
	end
	if string.find(savePath, "..", 1, true) or string.sub(savePath, 1, 1) == "/" then
		return false
	end
	return string.match(savePath, "^[%w_%-%./]+%.json$") ~= nil
end

local function getAccountKey(player_id)
	local identifiers = MP.GetPlayerIdentifiers(player_id)
	local beammpId = identifiers and identifiers.beammp
	if beammpId ~= nil and tostring(beammpId) ~= "" then
		local key = string.gsub(string.lower(tostring(beammpId)), "[^%w]", "")
		if key ~= "" then
			return "beammp" .. key
		end
	end
	if not Config.server.requireAccount then
		local name = MP.GetPlayerName(player_id) or ""
		local key = string.gsub(string.lower(name), "[^%w]", "")
		if key ~= "" then
			return "name" .. key
		end
	end
end

local function getSaveMoney(save)
	local attributesText = type(save) == "table" and type(save.files) == "table" and save.files["career/playerAttributes.json"]
	if type(attributesText) ~= "string" then
		return nil
	end
	local attributes = Util.JsonDecode(attributesText)
	if type(attributes) ~= "table" or type(attributes.money) ~= "table" then
		return nil
	end
	return tonumber(attributes.money.value), attributes
end

local function setSaveMoney(save, money)
	local _, attributes = getSaveMoney(save)
	if attributes then
		attributes.money.value = money
		save.files["career/playerAttributes.json"] = Util.JsonEncode(attributes)
		return true
	end
	return false
end

local function decodeSave(text)
	if not text or text == "" then
		return nil
	end
	local save = Util.JsonDecode(text)
	if type(save) ~= "table" or type(save.files) ~= "table" or not getSaveMoney(save) then
		return nil
	end
	return save
end

local function getBackupCount()
	return math.max(1, math.floor(tonumber(Config.server.backupCount) or 5))
end

local function loadSave(key)
	local paths = {SAVE_PATH .. key .. ".json"}
	for i = 1, getBackupCount() do
		table.insert(paths, SAVE_PATH .. key .. ".bak" .. i .. ".json")
	end
	table.insert(paths, SAVE_PATH .. key .. ".bak.json")
	for i, path in ipairs(paths) do
		local text = readText(path)
		local save = decodeSave(text)
		if save then
			if i > 1 then
				print("[CareerMP] ---------- Loaded backup " .. path .. " because the newer save was missing or broken")
			end
			return save, text
		end
	end
end

local function rotateBackups(key)
	local count = getBackupCount()
	local oldest = SAVE_PATH .. key .. ".bak" .. count .. ".json"
	if FS.Exists(oldest) then
		FS.Remove(oldest)
	end
	for i = count - 1, 1, -1 do
		local from = SAVE_PATH .. key .. ".bak" .. i .. ".json"
		if FS.Exists(from) then
			FS.Rename(from, SAVE_PATH .. key .. ".bak" .. (i + 1) .. ".json")
		end
	end
	local current = SAVE_PATH .. key .. ".json"
	if FS.Exists(current) then
		FS.Rename(current, SAVE_PATH .. key .. ".bak1.json")
	end
end

local function storeSave(key, save)
	ensureSaveDirectory()
	local text = Util.JsonEncode(save)
	if not text or text == "" then
		return false
	end
	local savePath = SAVE_PATH .. key .. ".json"
	local tempPath = SAVE_PATH .. key .. ".tmp"
	if not writeText(tempPath, text) then
		return false
	end
	local check = readText(tempPath)
	if not check or #check ~= #text then
		return false
	end
	rotateBackups(key)
	FS.Rename(tempPath, savePath)
	return FS.Exists(savePath), #text
end

local function logMoney(state, text)
	ensureSaveDirectory()
	local file = io.open(SAVE_PATH .. state.key .. ".log", "a")
	if file then
		file:write(os.date("%Y-%m-%d %H:%M:%S") .. " [" .. tostring(state.name) .. "] " .. text .. "\n")
		file:close()
	end
end

local function sendSave(player_id, text)
	transferCounter = transferCounter + 1
	local transferId = tostring(os.time()) .. tostring(transferCounter)
	local chunks = splitString(text, SAVE_CHUNK_SIZE)
	for i, chunk in ipairs(chunks) do
		MP.TriggerClientEvent(player_id, "rxCareerSaveChunk", transferId .. "|" .. i .. "|" .. #chunks .. "|" .. chunk)
	end
end

local function sendMoneyCorrection(player_id, state, reason)
	MP.TriggerClientEventJson(player_id, "rxMoneyCorrection", {value = state.money, reason = reason})
end

local function windowTotal(entries, now, seconds)
	local total = 0
	for i = #entries, 1, -1 do
		if now - entries[i].time >= seconds then
			table.remove(entries, i)
		else
			total = total + entries[i].amount
		end
	end
	return total
end

local function hasTag(tags, lookup)
	for _, tag in pairs(tags) do
		if lookup[tag] then
			return true
		end
	end
	return false
end

local function rejectIncome(player_id, state, amount, label, reason)
	print("[CareerMP] ---------- Rejected income of " .. amount .. " for " .. state.name .. " (" .. label .. "): " .. reason)
	logMoney(state, "REJECTED +" .. amount .. " (" .. label .. ") " .. reason)
	sendMoneyCorrection(player_id, state, "Income of $" .. amount .. " was rejected by the server: " .. reason)
	if Config.server.kickOnMoneyViolation then
		MP.DropPlayer(player_id, "CareerMP: " .. reason)
	end
end

local function failSave(player_id, state, reason)
	print("[CareerMP] ---------- Rejected save from " .. state.name .. ": " .. reason)
	MP.TriggerClientEvent(player_id, "rxCareerSaveFailed", reason)
end

local function processSaveUpload(player_id, state, text)
	if state.foreignSave then
		return
	end
	local upload = Util.JsonDecode(text)
	if type(upload) ~= "table" or type(upload.files) ~= "table" then
		failSave(player_id, state, "invalid save data")
		return
	end
	local full = upload.full == true
	if not full and tonumber(upload.base) ~= state.revision then
		MP.TriggerClientEvent(player_id, "rxCareerSaveResync", upload.manual == true and "manual" or "")
		return
	end
	local files = {}
	if not full and state.save then
		for savePath, content in pairs(state.save.files) do
			files[savePath] = content
		end
	end
	local changed = 0
	for savePath, content in pairs(upload.files) do
		if not isValidSavePath(savePath) or type(content) ~= "string" then
			failSave(player_id, state, "invalid file in save " .. tostring(savePath))
			return
		end
		files[savePath] = content
		changed = changed + 1
	end
	if type(upload.removed) == "table" then
		for _, savePath in pairs(upload.removed) do
			if isValidSavePath(savePath) then
				files[savePath] = nil
				changed = changed + 1
			end
		end
	end
	local fileCount = 0
	for _ in pairs(files) do
		fileCount = fileCount + 1
	end
	if fileCount > 5000 then
		failSave(player_id, state, "too many files in save")
		return
	end
	for _, savePath in ipairs(coreSaveFiles) do
		if type(files[savePath]) ~= "string" then
			failSave(player_id, state, "incomplete save, " .. savePath .. " is missing")
			return
		end
	end
	local save = {files = files}
	local uploadedMoney = getSaveMoney(save)
	if not uploadedMoney then
		failSave(player_id, state, "money missing from save")
		return
	end
	local modified = {}
	if uploadedMoney > state.money + 1 then
		print("[CareerMP] ---------- Corrected money of " .. state.name .. " from " .. uploadedMoney .. " to " .. state.money)
		logMoney(state, "CORRECTED save money " .. uploadedMoney .. " -> " .. state.money)
		setSaveMoney(save, state.money)
		table.insert(modified, "career/playerAttributes.json")
		sendMoneyCorrection(player_id, state, "Your money did not match the server and was corrected.")
	else
		state.money = uploadedMoney
	end
	save.revision = state.revision + 1
	save.owner = {name = state.name, key = state.key}
	save.savedAt = os.date("!%Y-%m-%dT%H:%M:%SZ")
	local stored, size = storeSave(state.key, save)
	if not stored then
		failSave(player_id, state, "the server could not write the file")
		return
	end
	state.save = save
	state.revision = save.revision
	state.hasSave = true
	state.lastSaved = os.time()
	MP.TriggerClientEventJson(player_id, "rxCareerSaveStored", {id = tostring(upload.id or ""), revision = state.revision, modified = modified})
	print("[CareerMP] ---------- Saved career of " .. state.name .. " (revision " .. state.revision .. ", " .. changed .. " changed files, " .. math.floor((size or 0) / 1024) .. " KB)")
	if upload.manual == true then
		MP.SendChatMessage(player_id, "Your career was saved on the server.")
	end
end

local function setTrafficHost(player_id)
	if trafficHost == player_id then
		return
	end
	local oldHost = trafficHost
	trafficHost = player_id
	if oldHost and careerStates[oldHost] and MP.IsPlayerConnected(oldHost) then
		MP.TriggerClientEvent(oldHost, "rxTrafficHost", "0")
	end
	if player_id and careerStates[player_id] then
		MP.TriggerClientEvent(player_id, "rxTrafficHost", "1")
		print("[CareerMP] ---------- Traffic is now hosted by " .. careerStates[player_id].name)
	end
end

local function updateTrafficHost()
	if trafficHost and careerStates[trafficHost] and MP.IsPlayerConnected(trafficHost) then
		return
	end
	local newHost
	for player_id in pairs(careerStates) do
		if MP.IsPlayerConnected(player_id) and (not newHost or player_id < newHost) then
			newHost = player_id
		end
	end
	setTrafficHost(newHost)
end

local function findCareerStateByName(name)
	for player_id, state in pairs(careerStates) do
		if state.name == name then
			return player_id, state
		end
	end
end

function onInit()

	print("[CareerMP] ---------- CareerMP Loading...")

	MP.RegisterEvent("perPartPainting","perPartPaintingHandler")
	MP.RegisterEvent("requestPartPaints","requestPartPaintsHandler")

	MP.RegisterEvent("payPlayer","payPlayer")

	MP.RegisterEvent("careerPrefabSync","careerPrefabSync")
	MP.RegisterEvent("careerSyncRequested","careerSyncRequested")
	MP.RegisterEvent("prefabSyncRequested","prefabSyncRequested")
	MP.RegisterEvent("careerVehSyncRequested","careerVehSyncRequested")
	MP.RegisterEvent("careerVehicleActiveHandler","careerVehicleActiveHandler")
	MP.RegisterEvent("careerSaveChunk","careerSaveChunk")
	MP.RegisterEvent("careerMoneyChange","careerMoneyChange")
	MP.RegisterEvent("careerSaveUnavailable","careerSaveUnavailable")
	MP.RegisterEvent("careerUnsyncedSave","careerUnsyncedSave")
	MP.RegisterEvent("careerForeignSave","careerForeignSave")
	MP.RegisterEvent("careerTrafficVehicles","careerTrafficVehicles")
	MP.RegisterEvent("onChatMessage","onChatMessageHandler")
	MP.RegisterEvent("careerAutoSave","careerAutoSave")
	MP.CreateEventTimer("careerAutoSave", 30000)

	MP.RegisterEvent("txUpdateDisplay", "txUpdateDisplay")
	MP.RegisterEvent("txUpdateWinnerLight", "txUpdateWinnerLight")
	MP.RegisterEvent("txUpdateBlueLight", "txUpdateBlueLight")
	MP.RegisterEvent("txUpdatePreStageLight", "txUpdatePreStageLight")
	MP.RegisterEvent("txUpdateStageLight", "txUpdateStageLight")
	MP.RegisterEvent("txUpdateDisqualifiedLight", "txUpdateDisqualifiedLight")
	MP.RegisterEvent("txUpdateTreeLights", "txUpdateTreeLights")
	MP.RegisterEvent("txClearDisplay", "txClearDisplay")
	MP.RegisterEvent("txClearAll", "txClearAll")

	MP.RegisterEvent("speedTrap", "speedTrap")
	MP.RegisterEvent("redLight", "redLight")
	MP.RegisterEvent("trafficLightTimer","trafficLightTimer")
	MP.CreateEventTimer("trafficLightTimer", 10000)

	MP.RegisterEvent("onPlayerAuth","onPlayerAuthHandler")
	MP.RegisterEvent("onPlayerJoin","onPlayerJoinHandler")
	MP.RegisterEvent("onVehicleSpawn","onVehicleSpawnHandler")
	MP.RegisterEvent("onVehicleEdited","onVehicleEditedHandler")
	MP.RegisterEvent("onVehicleDeleted","onVehicleDeletedHandler")
	MP.RegisterEvent("onPlayerDisconnect","onPlayerDisconnectHandler")

	MP.RegisterEvent("onConsoleInput","onConsoleInputHandler")

	MP.RegisterEvent("GetConfig","GetConfig")
	MP.RegisterEvent("SetConfig","SetConfig")
	MP.RegisterEvent("Update","Update")
	MP.RegisterEvent("Money","Money")
	MP.RegisterEvent("Help","Help")

	MP.RegisterEvent("tick","tick")
	MP.CreateEventTimer("tick", 1000)

	prepareConfig()
	ensureSaveDirectory()

	if Config.server.autoUpdate then
		if not FS.IsDirectory(SERVER_PATH .. "/versions") then
			FS.CreateDirectory(SERVER_PATH .. "/versions")
		end
		local update
		update = updateClient()
		update = updateServer()
		if update and Config.server.autoExit then
			willExit = true
		end
	end

	print("[CareerMP] ---------- CareerMP Loaded!")
end

function perPartPaintingHandler(player_id, data)
	local paintData = Util.JsonDecode(data)
	if not paintData.originID then
		for id in pairs(MP.GetPlayers()) do
			if player_id ~= id then
				MP.TriggerClientEvent(id, "rxRemotePartPaint", data)
			end
		end
	else
		MP.TriggerClientEvent(paintData.originID, "rxRemotePartPaint", data)
	end
end

function requestPartPaintsHandler(player_id, data)
	local requestData = Util.JsonDecode(data)
	local targetID = tonumber(requestData.serverVehicleID:sub(1,1))
	requestData.originID = player_id
	MP.TriggerClientEventJson(targetID, "rxRequestPartPaints", requestData)
end

local function getOrCreate(ledger, player_id)
	if not ledger[player_id] then
		ledger[player_id] = {
			session_total = 0,
			short_transactions = {},
			long_transactions = {}
		}
	end
	return ledger[player_id]
end

local function getWindowTotal(transactions, now, windowSeconds)
	local window_total = 0
	local cutoff = now - windowSeconds
	local kept = {}
	for _, transaction in ipairs(transactions) do
		if transaction.timestamp > cutoff then
			table.insert(kept, transaction)
			window_total = window_total + transaction.amount
		end
	end
	for i = #transactions, 1, -1 do
		transactions[i] = nil
		end
	for _, t in ipairs(kept) do
		table.insert(transactions, t)
	end
	return window_total
end

local function attemptTransaction(sender_id, receiver_id, amount, now)
	local sender = getOrCreate(ledger.send, sender_id)
	local receiver = getOrCreate(ledger.receive, receiver_id)
	local short_total = getWindowTotal(sender.short_transactions, now, Config.server.shortWindowSeconds)
	local long_total = getWindowTotal(sender.long_transactions, now, Config.server.longWindowSeconds)
	if sender.session_total + amount > Config.server.sessionSendingMax then
		return false
	end
	if short_total > 0 and short_total + amount > Config.server.shortWindowMax then
		return false
	end
	if long_total > 0 and long_total + amount > Config.server.longWindowMax then
		return false
	end
	if receiver.session_total + amount > Config.server.sessionReceiveMax then
		return false
	end
	sender.session_total = sender.session_total + amount
	receiver.session_total = receiver.session_total + amount
	if amount <= Config.server.shortWindowMax then
		table.insert(sender.short_transactions, { amount = amount, timestamp = now })
	end
	if amount <= Config.server.longWindowMax then
		table.insert(sender.long_transactions, { amount = amount, timestamp = now })
	end
	return true
end

function payPlayer(player_id, data)
	local paymentData = Util.JsonDecode(data)
	if type(paymentData) ~= "table" then
		return
	end
	local amount = tonumber(paymentData.money)
	local target_player_id = tonumber(paymentData.target_player_id)
	if not amount or amount ~= amount or amount <= 0 or amount == math.huge or not target_player_id then
		return
	end
	paymentData.money = amount
	paymentData.target_player_id = target_player_id
	paymentData.sender = MP.GetPlayerName(player_id)
	paymentData.tags = {"gameplay", "careerMPServer"}
	if not Config.server.allowTransactions then
		MP.TriggerClientEventJson(player_id, "rxDeny", paymentData)
		return
	end
	local sender = careerStates[player_id]
	local receiver = careerStates[target_player_id]
	if target_player_id == player_id or not MP.IsPlayerConnected(target_player_id) or not sender or not receiver then
		paymentData.reason = "That player is not available."
		MP.TriggerClientEventJson(player_id, "rxBounce", paymentData)
		return
	end
	if sender.money < amount then
		paymentData.reason = "You do not have enough money."
		MP.TriggerClientEventJson(player_id, "rxBounce", paymentData)
		return
	end
	if attemptTransaction(player_id, target_player_id, amount, signalTimer:GetCurrent()) then
		sender.money = sender.money - amount
		receiver.money = receiver.money + amount
		logMoney(sender, "PAID " .. amount .. " to " .. receiver.name)
		logMoney(receiver, "RECEIVED " .. amount .. " from " .. sender.name)
		MP.TriggerClientEventJson(target_player_id, "rxPayment", paymentData)
		MP.TriggerClientEventJson(player_id, "rxConfirmation", paymentData)
	else
		MP.TriggerClientEventJson(player_id, "rxBounce", paymentData)
	end
end

function careerSaveChunk(player_id, data)
	local state = careerStates[player_id]
	if not state or type(data) ~= "string" then
		return
	end
	local transferId, index, total, chunk = string.match(data, "^(%w+)|(%d+)|(%d+)|(.*)$")
	index, total = tonumber(index), tonumber(total)
	if not transferId or not index or not total or index < 1 or index > total then
		return
	end
	local upload = saveUploads[player_id]
	if not upload or upload.id ~= transferId then
		if upload and upload.count < upload.total then
			print("[CareerMP] ---------- Replaced an unfinished save from " .. state.name .. " (" .. upload.count .. "/" .. upload.total .. " parts arrived)")
		end
		upload = {id = transferId, total = total, chunks = {}, count = 0, size = 0, started = os.time()}
		saveUploads[player_id] = upload
	end
	if upload.total ~= total or upload.chunks[index] then
		return
	end
	upload.size = upload.size + #chunk
	if upload.size > Config.server.maxSaveSizeMB * 1048576 then
		saveUploads[player_id] = nil
		print("[CareerMP] ---------- Rejected save from " .. state.name .. ": too large")
		MP.TriggerClientEvent(player_id, "rxCareerSaveFailed", "the save is too large")
		return
	end
	upload.chunks[index] = chunk
	upload.count = upload.count + 1
	if upload.count == upload.total then
		saveUploads[player_id] = nil
		processSaveUpload(player_id, state, table.concat(upload.chunks))
	end
end

function careerMoneyChange(player_id, data)
	local state = careerStates[player_id]
	if not state or state.foreignSave then
		return
	end
	local change = Util.JsonDecode(data)
	local amount = type(change) == "table" and tonumber(change.money)
	if not amount or amount ~= amount or amount == math.huge or amount == -math.huge then
		return
	end
	local tags = type(change.tags) == "table" and change.tags or {}
	local label = tostring(change.label or "")
	if amount < 0 then
		state.money = state.money + amount
		return
	end
	if Config.server.blockCheatIncome and hasTag(tags, cheatTags) then
		rejectIncome(player_id, state, amount, label, "cheat income is not allowed")
		return
	end
	local isSale = hasTag(tags, saleTags)
	local singleLimit = tonumber(isSale and Config.server.saleLimitSingle or Config.server.incomeLimitSingle) or 0
	local hourLimit = tonumber(isSale and Config.server.saleLimitPerHour or Config.server.incomeLimitPerHour) or 0
	local entries = isSale and state.sales or state.incomes
	local now = os.time()
	if singleLimit > 0 and amount > singleLimit then
		rejectIncome(player_id, state, amount, label, "over the limit of $" .. singleLimit .. " per transaction")
		return
	end
	if hourLimit > 0 and windowTotal(entries, now, 3600) + amount > hourLimit then
		rejectIncome(player_id, state, amount, label, "over the limit of $" .. hourLimit .. " per hour")
		return
	end
	table.insert(entries, {amount = amount, time = now})
	state.money = state.money + amount
	logMoney(state, "+" .. amount .. " (" .. label .. ")")
end

function txUpdateDisplay(player_id, data)
	for id in pairs(MP.GetPlayers()) do
		if player_id ~= id then
			MP.TriggerClientEvent(id, "rxUpdateDisplay", data)
		end
	end
end

function txUpdateWinnerLight(player_id, data)
	for id in pairs(MP.GetPlayers()) do
		if player_id ~= id then
			MP.TriggerClientEvent(id, "rxUpdateWinnerLight", data)
		end
	end
end

function txUpdateBlueLight(player_id, data)
	for id in pairs(MP.GetPlayers()) do
		if player_id ~= id then
			MP.TriggerClientEvent(id, "rxUpdateBlueLight", data)
		end
	end
end

function txUpdatePreStageLight(player_id, data)
	for id in pairs(MP.GetPlayers()) do
		if player_id ~= id then
			MP.TriggerClientEvent(id, "rxUpdatePreStageLight", data)
		end
	end
end

function txUpdateStageLight(player_id, data)
	for id in pairs(MP.GetPlayers()) do
		if player_id ~= id then
			MP.TriggerClientEvent(id, "rxUpdateStageLight", data)
		end
	end
end

function txUpdateDisqualifiedLight(player_id, data)
	for id in pairs(MP.GetPlayers()) do
		if player_id ~= id then
			MP.TriggerClientEvent(id, "rxUpdateDisqualifiedLight", data)
		end
	end
end

function txUpdateTreeLights(player_id, data)
	for id in pairs(MP.GetPlayers()) do
		if player_id ~= id then
			MP.TriggerClientEvent(id, "rxUpdateTreeLights", data)
		end
	end
end

function txClearDisplay(player_id)
	for id in pairs(MP.GetPlayers()) do
		if player_id ~= id then
			MP.TriggerClientEvent(id, "rxClearDisplay", "")
		end
	end
end

function txClearAll(player_id)
	for id in pairs(MP.GetPlayers()) do
		if player_id ~= id then
			MP.TriggerClientEvent(id, "rxClearAll", "")
		end
	end
end

function speedTrap(player_id, data)
	local speedTrapData = Util.JsonDecode(data)
	local triggerName = speedTrapData.triggerName
	local triggerNumber = tonumber(string.match(triggerName, "%d+"))
	local triggerPlace = trapNames[triggerNumber] or "Unknown"
	local player_name = MP.GetPlayerName(player_id)
	MP.SendNotification(-1, "Speed Violation by " .. player_name .. "!", "survellianceCamera", "survellianceCamera")
	MP.SendNotification(-1, "Speed: " .. string.format( "%.1f", speedTrapData.playerSpeed * 2.23694 ) .. " in " .. string.format( "%.0f", speedTrapData.speedLimit * 2.23694 ) .. " MPH Zone", "powerGauge05", "powerGauge05")
	MP.SendNotification(-1, "Location: " .. triggerPlace, "location1", "location1")
	MP.SendNotification(-1, "Vehicle: " .. speedTrapData.vehicleModel, "car", "car")
	MP.SendNotification(-1, "Plate: " .. speedTrapData.licensePlate, "code", "code")
end

function redLight(player_id, data)
	local redLightData = Util.JsonDecode(data)
	local triggerName = redLightData.triggerName
	local triggerNumber = tonumber(string.match(triggerName, "%d+"))
	local triggerPlace = trapNames[triggerNumber] or "Unknown"
	local player_name = MP.GetPlayerName(player_id)
	MP.SendNotification(-1, "Failure to stop at Red Light by " .. player_name .. "!", "trafficLight", "trafficLight")
	MP.SendNotification(-1, "Speed: " .. string.format( "%.1f", redLightData.playerSpeed * 2.23694 ) .. " MPH", "powerGauge05", "powerGauge05")
	MP.SendNotification(-1, "Location: " .. triggerPlace, "location1", "location1")
	MP.SendNotification(-1, "Vehicle: " .. redLightData.vehicleModel, "car", "car")
	MP.SendNotification(-1, "Plate: " .. redLightData.licensePlate, "code", "code")
end

function trafficLightTimer()
	for id in pairs(MP.GetPlayers()) do
		if MP.IsPlayerConnected(id) then
			MP.TriggerClientEvent(id, "rxTrafficSignalTimer", tostring(signalTimer:GetCurrent()))
		end
	end
end

function careerVehSyncRequested(player_id)
	MP.TriggerClientEventJson(player_id, "rxCareerVehSync", vehicleStates)
end

function careerPrefabSync(player_id, data)
	local prefab = Util.JsonDecode(data)
	if prefab.pLoad == true then
		loadedPrefabs[player_id][prefab.pName] = prefab
	elseif prefab.pLoad == false then
		loadedPrefabs[player_id][prefab.pName] = nil
	end
	for id in pairs(MP.GetPlayers()) do
		if player_id ~= id then
			MP.TriggerClientEvent(id, "rxPrefabSync", data)
		end
	end
end

function careerSyncRequested(player_id)
	local key = getAccountKey(player_id)
	if not key then
		MP.DropPlayer(player_id, "CareerMP: please log in to BeamMP to play on this server.")
		return
	end
	for id, state in pairs(careerStates) do
		if id ~= player_id and state.key == key and MP.IsPlayerConnected(id) then
			MP.DropPlayer(player_id, "CareerMP: this account is already playing on this server.")
			return
		end
	end
	local save, text = loadSave(key)
	if not incomeHistory[key] then
		incomeHistory[key] = {incomes = {}, sales = {}}
	end
	local state = {
		key = key,
		name = MP.GetPlayerName(player_id),
		money = (save and getSaveMoney(save)) or tonumber(Config.server.startingMoney) or 0,
		hasSave = save ~= nil,
		save = save,
		revision = save and tonumber(save.revision) or 0,
		joinedAt = os.time(),
		incomes = incomeHistory[key].incomes,
		sales = incomeHistory[key].sales
	}
	careerStates[player_id] = state
	if not trafficHost or not careerStates[trafficHost] or not MP.IsPlayerConnected(trafficHost) then
		trafficHost = player_id
		print("[CareerMP] ---------- Traffic is now hosted by " .. state.name)
	end
	saveUploads[player_id] = nil
	if text then
		sendSave(player_id, text)
	end
	local clientConfig = {}
	for field, value in pairs(Config.client) do
		clientConfig[field] = value
	end
	clientConfig.serverAuthoritative = true
	clientConfig.profileName = "careermp" .. key
	clientConfig.hasServerSave = save ~= nil
	clientConfig.saveRevision = state.revision
	clientConfig.trafficHost = trafficHost == player_id
	MP.TriggerClientEventJson(player_id, "rxCareerSync", clientConfig)
	print("[CareerMP] ---------- Career of " .. state.name .. " loaded from the server (" .. key .. ", $" .. state.money .. ")")
	if pendingActivation[player_id] then
		pendingActivation[player_id].careerActive = true
	end
end

function prefabSyncRequested(player_id)
	for id in pairs(MP.GetPlayers()) do
		if player_id ~= id then
			if loadedPrefabs[id] then
				for k,v in pairs(loadedPrefabs[id]) do
					MP.TriggerClientEventJson(player_id, "rxPrefabSync", loadedPrefabs[id][k])
				end
			end
		end
	end
end

function careerVehicleActiveHandler(player_id, data)
	local vehicleData = Util.JsonDecode(data)
	if vehicleStates[vehicleData.serverVehicleID] then
		vehicleStates[vehicleData.serverVehicleID].active = vehicleData.active
	else
		vehicleStates[vehicleData.serverVehicleID] = {}
		vehicleStates[vehicleData.serverVehicleID].active = vehicleData.active
	end
	MP.TriggerClientEventJson(-1, "rxCareerVehSync", vehicleStates)
end

function validateCareerMPActivation()
	for id in pairs(MP.GetPlayers()) do
		if MP.IsPlayerConnected(id) then
			if pendingActivation[id] then
				if not pendingActivation[id].careerActive then
					if pendingActivation[id].joinTimestamp then
						if signalTimer:GetCurrent() - pendingActivation[id].joinTimestamp >= activationThreshold then
							MP.DropPlayer(id, "CareerMP failed to load!")
						end
					end
				end
			end
		end
	end
end

function tick()
	if willExit then
		exit()
	end
	validateCareerMPActivation()
	local now = os.time()
	for player_id, upload in pairs(saveUploads) do
		if upload.started and now - upload.started > 120 then
			local state = careerStates[player_id]
			print("[CareerMP] ---------- Dropped an unfinished save from " .. (state and state.name or tostring(player_id)) .. " (" .. upload.count .. "/" .. upload.total .. " parts arrived)")
			saveUploads[player_id] = nil
		end
	end
end

function onPlayerJoinHandler(player_id)
	loadedPrefabs[player_id] = {}
	pendingActivation[player_id] = {
		joinTimestamp = signalTimer:GetCurrent(),
		careerActive = false
	}
end

function onVehicleSpawnHandler(player_id, vehicle_id,  data)
	vehicleStates[player_id .. "-" .. vehicle_id] = {}
	vehicleStates[player_id .. "-" .. vehicle_id].active = true
	MP.TriggerClientEventJson(-1, "rxCareerVehSync", vehicleStates)
end

function onVehicleEditedHandler(player_id, vehicle_id,  data)
	if vehicleStates[player_id .. "-" .. vehicle_id] then
		vehicleStates[player_id .. "-" .. vehicle_id].active = true
	else
		vehicleStates[player_id .. "-" .. vehicle_id] = {}
		vehicleStates[player_id .. "-" .. vehicle_id].active = true
	end
end

function onVehicleDeletedHandler(player_id, vehicle_id)
	if vehicleStates[player_id .. "-" .. vehicle_id] then
		vehicleStates[player_id .. "-" .. vehicle_id] = nil
	end
end

function onPlayerAuthHandler(player_name, player_role, is_guest, identifiers)
	if Config.server.requireAccount and (is_guest or type(identifiers) ~= "table" or not identifiers.beammp or tostring(identifiers.beammp) == "") then
		return "CareerMP saves careers on the server, please log in to BeamMP to join (guests are not allowed)."
	end
end

function onPlayerDisconnectHandler(player_id)
	loadedPrefabs[player_id] = nil
	ledger.send[player_id] = nil
	ledger.receive[player_id] = nil
	pendingActivation[player_id] = nil
	careerStates[player_id] = nil
	saveUploads[player_id] = nil
	if trafficHost == player_id then
		trafficHost = nil
		updateTrafficHost()
	end
end

function onChatMessageHandler(player_id, player_name, message)
	local command = string.lower(string.match(tostring(message or ""), "^%s*(.-)%s*$") or "")
	if command ~= "/save" then
		return
	end
	local state = careerStates[player_id]
	if not state then
		MP.SendChatMessage(player_id, "Your career is not loaded yet.")
		return 1
	end
	local now = os.time()
	local cooldown = tonumber(Config.server.saveCommandCooldown) or 0
	if state.lastSaveCommand and now - state.lastSaveCommand < cooldown then
		MP.SendChatMessage(player_id, "Please wait " .. (cooldown - (now - state.lastSaveCommand)) .. " seconds before saving again.")
		return 1
	end
	state.lastSaveCommand = now
	MP.TriggerClientEvent(player_id, "rxCareerSaveRequest", "manual")
	MP.SendChatMessage(player_id, "Saving your career...")
	return 1
end

function careerForeignSave(player_id, data)
	local info = Util.JsonDecode(data)
	if type(info) ~= "table" then
		info = {}
	end
	local state = careerStates[player_id]
	local name = state and state.name or tostring(MP.GetPlayerName(player_id))
	print("[CareerMP] ---------- " .. name .. " loaded a career save that is not the server save (" .. tostring(info.profile) .. "), their progress is no longer stored")
	if state then
		state.foreignSave = true
		saveUploads[player_id] = nil
		logMoney(state, "FOREIGN SAVE loaded: " .. tostring(info.profile) .. " " .. tostring(info.save))
	end
	if Config.server.kickOnForeignSave then
		print("[CareerMP] ---------- Kicking " .. name .. " for loading a career save that is not the server save")
		MP.DropPlayer(player_id, "CareerMP: you loaded a career save that is not stored on this server. Rejoin to play with your server save.")
	end
end

function careerUnsyncedSave(player_id, data)
	local info = Util.JsonDecode(data)
	if type(info) ~= "table" then
		info = {}
	end
	local state = careerStates[player_id]
	local name = state and state.name or tostring(MP.GetPlayerName(player_id))
	print("[CareerMP] ---------- " .. name .. " had newer progress on their PC (" .. tostring(info.localDate) .. ") than the server (" .. tostring(info.serverDate) .. "). The server save was loaded, the PC copy was kept as " .. tostring(info.backup))
	if state then
		logMoney(state, "UNSYNCED local save from " .. tostring(info.localDate) .. " kept on the player's PC as " .. tostring(info.backup))
	end
end

function careerSaveUnavailable(player_id)
	MP.SendChatMessage(player_id, "You can't save right now, finish your mission or tutorial first.")
end

function careerAutoSave()
	local minutes = tonumber(Config.server.autoSaveMinutes) or 0
	if minutes <= 0 then
		return
	end
	local now = os.time()
	for player_id, state in pairs(careerStates) do
		if MP.IsPlayerConnected(player_id) then
			local lastSaved = state.lastSaved or state.joinedAt or now
			local lastRequest = state.lastAutoSaveRequest or 0
			if now - lastSaved >= minutes * 60 and now - lastRequest >= minutes * 60 then
				state.lastAutoSaveRequest = now
				MP.TriggerClientEvent(player_id, "rxCareerSaveRequest", "auto")
			end
		end
	end
end

function careerTrafficVehicles(player_id, data)
	if player_id ~= trafficHost then
		return
	end
	local list = Util.JsonDecode(data)
	if type(list) ~= "table" then
		return
	end
	local prefix = tostring(player_id) .. "-"
	local changed = false
	for _, serverVehicleID in pairs(list) do
		serverVehicleID = tostring(serverVehicleID)
		if string.sub(serverVehicleID, 1, #prefix) == prefix then
			if not vehicleStates[serverVehicleID] then
				vehicleStates[serverVehicleID] = {active = true}
			end
			if not vehicleStates[serverVehicleID].traffic then
				vehicleStates[serverVehicleID].traffic = true
				changed = true
			end
		end
	end
	if changed then
		MP.TriggerClientEventJson(-1, "rxCareerVehSync", vehicleStates)
	end
end

function onConsoleInputHandler(message)
	local space = message:find(" ")
	if not space then
		return ""
	end
	local commandPrefix = message:sub(1, space)
	if commandPrefix == "CareerMP " or "CMP " then
		local prefixLen = commandPrefix:len()
		message = message:sub(prefixLen + 1)
		local command = message
		local arguments = {}
		local separator = message:find(' ')
		if separator then
			command, arguments = parseCommand(message, separator)
		end
		MP.TriggerLocalEvent(command, arguments)
	end
	return ""
end

local function checkValue(value)
	if tonumber(value) then
		return tonumber(value)
	elseif value == "true" then
		return true
	elseif value == "false" then
		return false
	end
	return value
end

function GetConfig(arguments)
	Config = ReadJson(configPath .. "config.json")
	if #arguments == 0 then
		print(Config)
	elseif #arguments == 1 then
		print(Config[arguments[1]])
	else
		print(Config[arguments[1]][arguments[2]])
	end
end

function SetConfig(arguments)
	if #arguments < 3 then
		print("Usage: CareerMP SetConfig <section> <key> <value>")
		return
	end
	Config = ReadJson(configPath .. "config.json")
	local section = arguments[1]
	local key = arguments[2]
	local value = arguments[3]
	if not Config[section] then
		print("[CareerMP] ---------- Unknown section: " .. section)
		return
	end
	if Config[section][key] == nil then
		print("[CareerMP] ---------- Unknown key: " .. section .. " " .. key)
		return
	end
	Config[section][key] = checkValue(value)
	print("[CareerMP] ---------- Config:    " .. section .. " " .. tostring(key) .. " set to " .. tostring(Config[section][key]))
	WriteJson(configPath .. "config.json", Config)
	MP.TriggerClientEventJson(-1, "rxClientConfigUpdate", Config.client)
end

function Update(arguments)
	if not FS.IsDirectory(SERVER_PATH .. "/versions") then
		FS.CreateDirectory(SERVER_PATH .. "/versions")
	end
	local update
	update = updateClient()
	update = updateServer()
	if update and Config.server.autoExit then
		willExit = true
	end
end

function Money(arguments)
	if #arguments == 0 then
		for _, state in pairs(careerStates) do
			print("[CareerMP] ---------- " .. state.name .. ": $" .. state.money)
		end
		return
	end
	local player_id, state = findCareerStateByName(arguments[1])
	if not state then
		print("[CareerMP] ---------- No career loaded for " .. arguments[1])
		return
	end
	local amount = tonumber(arguments[2])
	if amount then
		state.money = amount
		local save = state.save or loadSave(state.key)
		if save and setSaveMoney(save, amount) then
			save.revision = state.revision + 1
			if storeSave(state.key, save) then
				state.save = save
				state.revision = save.revision
			end
		end
		logMoney(state, "SET by server console to " .. amount)
		sendMoneyCorrection(player_id, state, "Your money was set by the server.")
	end
	print("[CareerMP] ---------- " .. state.name .. ": $" .. state.money)
end

function Help(arguments)
	print("CareerMP GetConfig <section> <key>            - Displays Config, or section, or key")
	print("CareerMP SetConfig <section*> <key*> <value*> - Sets Config section key to value, * = REQUIRED")
	print("CareerMP Money <player> <amount>              - Shows or sets the money of online players")
	print("CareerMP Update                               - Checks for CareerMP update")
	print("CareerMP Help                                 - Displays Commands Usage")
	print("Players can type /save in chat to save their career on the server")
end

function ReadJson(path)
	if not path then
		print("[CareerMP] ---------- ReadJson:  path is nil!")
		return
	end
	if not FS.Exists(path) then
		print("[CareerMP] ---------- ReadJson:  " .. path .. " does not exist!")
		return
	end
	local jsonFile, err = io.open(path, "r")
	if not jsonFile then
		print("[CareerMP] ---------- ReadJson:  failed to open " .. path .. ": " .. tostring(err))
		return
	end
	local jsonText = jsonFile:read("*a")
	jsonFile:close()
	if not jsonText or jsonText == "" then
		print("[CareerMP] ---------- ReadJson:  " .. path .. " is empty!")
		return
	end
	local data = Util.JsonDecode(jsonText)
	if data == nil then
		print("[CareerMP] ---------- ReadJson:  failed to decode " .. path)
		return
	end
	return data
end

function WriteJson(path, data)
	if not path then
		print("[CareerMP] ---------- WriteJson: path is nil!")
		return
	end
	if data == nil then
		print("[CareerMP] ---------- WriteJson: data is nil, aborting!")
		return
	end
	local checkDirectory = path:match("(.+)/[^/]+$")
	if checkDirectory and not FS.Exists(checkDirectory) then
		FS.CreateDirectory(checkDirectory)
		print("[CareerMP] ---------- WriteJson: created directory " .. checkDirectory)
	end
	local encoded = Util.JsonEncode(data)
	if not encoded then
		print("[CareerMP] ---------- WriteJson: failed to encode data!")
		return
	end
	local jsonFile, err = io.open(path, "w")
	if not jsonFile then
		print("[CareerMP] ---------- WriteJson: failed to open " .. path .. ": " .. tostring(err))
		return
	end
	print("[CareerMP] ---------- WriteJson: writing " .. path)
	jsonFile:write(Util.JsonPrettify(encoded))
	jsonFile:close()
	return true
end
