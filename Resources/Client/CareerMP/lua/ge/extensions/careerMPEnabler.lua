--CareerMP (CLIENT) by Dudekahedron, 2026

local M = {}

--Setup

local nickname = MPConfig.getNickname()

local blockedInputActions = {}

local clientConfig

local function getClientConfig()
	return clientConfig
end

local careerMPActive = false
local syncRequested = false

local serverAuthoritative = false
local serverProfileName
local moneyReporting = false
local saveDownload
local uploadCounter = 0
local saveChunkSize = 256000
local outgoingChunks = {}
local uploadRetries = 0
local confirmedFiles = {}
local confirmedRevision = 0
local pendingUpload
local uploadQueued = false
local manualSaveRequested = false
local unconfirmedFiles = {}
local serverCareerLoaded = false
local foreignCareerLoaded = false

local trafficHost = false
local remoteTraffic = {}
local reportedTraffic = ""
local trafficReportTimer = 0
local ghostStates = {}

local inComputerMenus = false

--Settings

local userTrafficSettings = {}
local careerMPTrafficSettings = {}

local userGameplaySettings = {}
local careerMPGameplaySettings = {}

local function getUserTrafficSettings()
	userTrafficSettings.trafficSmartSelections = settings.getValue('trafficSmartSelections')
	userTrafficSettings.trafficSimpleVehicles = settings.getValue('trafficSimpleVehicles')
	userTrafficSettings.trafficAllowMods = settings.getValue('trafficAllowMods')
end

local function setTrafficSettings(trafficSettings)
	for setting, value in pairs(trafficSettings) do
		settings.setValue(setting, value)
	end
end

local function getUserGameplaySettings()
	userGameplaySettings.simplifyRemoteVehicles = settings.getValue("simplifyRemoteVehicles")
	userGameplaySettings.spawnVehicleIgnitionLevel = settings.getValue("spawnVehicleIgnitionLevel")
	userGameplaySettings.skipOtherPlayersVehicles = settings.getValue("skipOtherPlayersVehicles")
end

local function setGameplaySettings(gameplaySettings)
	for setting, value in pairs(gameplaySettings) do
		settings.setValue(setting, value)
	end
end

--Hidden Nametags by Vehicle Model

local hiddens = {
	anticut = "anticut",
	ball = "ball",
	barrels = "barrels",
	barrier = "barrier",
	barrier_plastic = "barrier_plastic",
	blockwall = "blockwall",
	bollard = "bollard",
	boxutility = "boxutility",
	boxutility_large = "boxutility_large",
	cannon = "cannon",
	caravan = "caravan",
	cardboard_box = "cardboard_box",
	cargotrailer = "cargotrailer",
	chair = "chair",
	christmas_tree = "christmas_tree",
	cones = "cones",
	containerTrailer = "containerTrailer",
	couch = "couch",
	crowdbarrier = "crowdbarrier",
	delineator = "delineator",
	dolly = "dolly",
	dryvan = "dryvan",
	engine_props = "engine_props",
	flail = "flail",
	flatbed = "flatbed",
	flipramp = "flipramp",
	frameless_dump = "frameless_dump",
	fridge = "fridge",
	gate = "gate",
	haybale = "haybale",
	inflated_mat = "inflated_mat",
	kickplate = "kickplate",
	large_angletester = "large_angletester",
	large_bridge = "large_bridge",
	large_cannon = "large_cannon",
	large_crusher = "large_crusher",
	large_hamster_wheel = "large_hamster_wheel",
	large_roller = "large_roller",
	large_spinner = "large_spinner",
	large_tilt = "large_tilt",
	large_tire = "large_tire",
	log_trailer = "log_trailer",
	logs = "logs",
	mattress = "mattress",
	metal_box = "metal_box",
	metal_ramp = "metal_ramp",
	piano = "piano",
	porta_potty = "porta_potty",
	pressure_ball = "pressure_ball",
	rallyflags = "rallyflags",
	rallysigns = "rallysigns",
	rallytape = "rallytape",
	roadsigns = "roadsigns",
	rocks = "rocks",
	rollover = "rollover",
	roof_crush_tester = "roof_crush_tester",
	sawhorse = "sawhorse",
	shipping_container = "shipping_container",
	simple_traffic = "simple_traffic",
	spikestrip = "spikestrip",
	steel_coil = "steel_coil",
	streetlight = "streetlight",
	suspensionbridge = "suspensionbridge",
	tanker = "tanker",
	testroller = "testroller",
	tiltdeck = "tiltdeck",
	tirestacks = "tirestacks",
	tirewall = "tirewall",
	trafficbarrel = "trafficbarrel",
	trampoline = "trampoline",
	trashbin = "trashbin",
	tsfb = "tsfb",
	tub = "tub",
	tube = "tube",
	tv = "tv",
	wall = "wall",
	weightpad = "weightpad",
	woodcrate = "woodcrate",
	woodplanks = "woodplanks",
}

--Vehicles and part paints

local function rxCareerVehSync(data)
	if data ~= "null" then
		local vehicleStates = jsonDecode(data)
		local vehicles = MPVehicleGE.getVehicles()
		for serverVehicleID, state in pairs(vehicleStates) do
			if vehicles[serverVehicleID] then
				local gameVehicleID = vehicles[serverVehicleID].gameVehicleID
				if gameVehicleID ~= -1 then
					local veh = be:getObjectByID(gameVehicleID)
					if veh and not MPVehicleGE.isOwn(gameVehicleID) then
						remoteTraffic[serverVehicleID] = state.traffic and true or nil
						if not state.active then
							veh:setActive(0)
							vehicles[serverVehicleID].hideNametag = true
						else
							veh:setActive(1)
							if hiddens[vehicles[serverVehicleID].jbeam] or state.traffic then
								vehicles[serverVehicleID].hideNametag = true
							else
								vehicles[serverVehicleID].hideNametag = false
							end
						end
					end
				end
			end
		end
	end
end

local function onVehicleActiveChanged(gameVehicleID, active)
	if gameVehicleID then
		if MPVehicleGE.isOwn(gameVehicleID) then
			local serverVehicleID = MPVehicleGE.getServerVehicleID(gameVehicleID)
			if serverVehicleID then
				local data = {}
				data.active = active
				data.serverVehicleID = serverVehicleID
				TriggerServerEvent("careerVehicleActiveHandler", jsonEncode(data))
			end
		else
			TriggerServerEvent("careerVehSyncRequested", "")
		end
	end
end

local function onVehicleSpawned(gameVehicleID)
	if gameVehicleID then
		ghostStates[gameVehicleID] = nil
		local veh = be:getObjectByID(gameVehicleID)
		if veh then
			veh:queueLuaCommand('careerMPEnabler.onVehicleReady()')
		end
		if not MPVehicleGE.isOwn(gameVehicleID) then
			TriggerServerEvent("careerVehSyncRequested", "")
		end
	end
end

local function onVehicleReady(gameVehicleID)
	local serverVehicleID = MPVehicleGE.getServerVehicleID(gameVehicleID)
	if serverVehicleID then
		local veh = be:getObjectByID(gameVehicleID)
		if veh then
			if not MPVehicleGE.isOwn(gameVehicleID) then
				local vehicles = MPVehicleGE.getVehicles()
				if hiddens[veh.JBeam] or remoteTraffic[serverVehicleID] then
					vehicles[serverVehicleID].hideNametag = true
				else
					vehicles[serverVehicleID].hideNametag = false
				end
			end
			veh:setField('renderDistance', '', 1610)
		end
	end
end

local function onVehicleSwitched(oldGameVehicleID, newGameVehicleID)
	local newVeh = be:getObjectByID(newGameVehicleID)
	local oldVeh = be:getObjectByID(oldGameVehicleID)
	if newVeh then
		if hiddens[newVeh.JBeam] then
			if not MPVehicleGE.isOwn(newGameVehicleID) then
				be:enterNextVehicle(0, 1)
			end
		end
		if newVeh.JBeam == "unicycle" then
			if inComputerMenus then
				gameplay_walk.setWalkingMode(false)
				be:enterVehicle(0, oldVeh)
			end
		end
	end
end

--Traffic Signals and Cameras

local function onSpeedTrapTriggered(speedTrapData, playerSpeed, overSpeed)
	if speedTrapData.subjectID == be:getPlayerVehicleID(0) and MPVehicleGE.isOwn(speedTrapData.subjectID) then
		local veh = be:getObjectByID(speedTrapData.subjectID)
		local highscore, leaderboard = gameplay_speedTrapLeaderboards.addRecord(speedTrapData, playerSpeed, overSpeed, veh)
		speedTrapData.licensePlate = veh:getDynDataFieldbyName("licenseText", 0) or "Illegible"
		speedTrapData.vehicleModel = core_vehicles.getModel(veh.JBeam).model.Name
		speedTrapData.playerSpeed = playerSpeed
		speedTrapData.overSpeed = overSpeed
		speedTrapData.highscore = highscore
		speedTrapData.leaderboard = leaderboard
		TriggerServerEvent("speedTrap", jsonEncode( speedTrapData ) )
	end
end

local function onRedLightCamTriggered(redLightData, playerSpeed)
	if redLightData.subjectID == be:getPlayerVehicleID(0) and MPVehicleGE.isOwn(redLightData.subjectID) then
		local veh = be:getObjectByID(redLightData.subjectID)
		redLightData.licensePlate = veh:getDynDataFieldbyName("licenseText", 0) or "Illegible"
		redLightData.vehicleModel = core_vehicles.getModel(veh.JBeam).model.Name
		redLightData.playerSpeed = playerSpeed
		TriggerServerEvent("redLight", jsonEncode( redLightData ) )
	end
end

local function rxTrafficSignalTimer(data)
	core_trafficSignals.setTimer(tonumber(data))
end

--Garage / Office Computer Handling

local function getSelectedVehicleID()
	if career_modules_computer and career_modules_computer.getSelectedInventoryId then
		local inventoryId = career_modules_computer.getSelectedInventoryId()
		if inventoryId then
			return career_modules_inventory.getVehicleIdFromInventoryId(inventoryId)
		end
	end
end

local function computerMenuHandler()
	local targetVehicleID = getSelectedVehicleID()
	if targetVehicleID then
		local veh = be:getObjectByID(targetVehicleID)
		if veh then
			if veh.JBeam ~= "unicycle" then
				if gameplay_walk.isWalking() then
					gameplay_walk.getInVehicle(veh)
				else
					be:enterVehicle(0, veh)
				end
				inComputerMenus = true
			end
		end
	end
end

local function onComputerOpened()
	if inComputerMenus then
		inComputerMenus = false
	end
end

--Initial Syncs and Updates

local function actionsCheck()
	if not clientConfig.consoleEnabled then
		table.insert(blockedInputActions, "toggleConsoleNG")
		extensions.core_input_actionFilter.setGroup('careerMP', blockedInputActions)
		extensions.core_input_actionFilter.addAction(0, 'careerMP', true)
	elseif clientConfig.consoleEnabled then
		extensions.core_input_actionFilter.setGroup('careerMP', blockedInputActions)
		extensions.core_input_actionFilter.addAction(0, 'careerMP', false)
	end
	if not clientConfig.worldEditorEnabled then
		table.insert(blockedInputActions, "editorToggle")
		table.insert(blockedInputActions, "editorSafeModeToggle")
		table.insert(blockedInputActions, "objectEditorToggle")
		extensions.core_input_actionFilter.setGroup('careerMP', blockedInputActions)
		extensions.core_input_actionFilter.addAction(0, 'careerMP', true)
	elseif clientConfig.worldEditorEnabled then
		extensions.core_input_actionFilter.setGroup('careerMP', blockedInputActions)
		extensions.core_input_actionFilter.addAction(0, 'careerMP', false)
	end
end

local function settingsCheck()
	careerMPTrafficSettings.trafficAllowMods = clientConfig.trafficAllowMods
	careerMPTrafficSettings.trafficSimpleVehicles = clientConfig.trafficSimpleVehicles
	careerMPTrafficSettings.trafficSmartSelections = clientConfig.trafficSmartSelections
	setTrafficSettings(careerMPTrafficSettings)
	careerMPGameplaySettings.simplifyRemoteVehicles = clientConfig.simplifyRemoteVehicles
	careerMPGameplaySettings.spawnVehicleIgnitionLevel = clientConfig.spawnVehicleIgnitionLevel
	careerMPGameplaySettings.skipOtherPlayersVehicles = clientConfig.skipOtherPlayersVehicles
	setGameplaySettings(careerMPGameplaySettings)
end

local function getProfileName(name)
	if FS:directoryExists(career_saveSystem.getSaveRootDirectory() .. name) then
		return name
	end
	local profileName = string.gsub(string.lower(name), '[^a-z0-9]', '')
	if profileName == '' then
		profileName = 'careermp'
	end
	return profileName
end

--Server Saves

local function isValidSavePath(savePath)
	if type(savePath) ~= "string" or savePath == "" or #savePath > 260 then
		return false
	end
	if string.find(savePath, "..", 1, true) or string.sub(savePath, 1, 1) == "/" then
		return false
	end
	return string.match(savePath, "^[%w_%-%./]+%.json$") ~= nil
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

local function rxCareerSaveChunk(data)
	local transferId, index, total, chunk = string.match(data, "^(%w+)|(%d+)|(%d+)|(.*)$")
	index, total = tonumber(index), tonumber(total)
	if not transferId or not index or not total or index < 1 or index > total then
		return
	end
	if not saveDownload or saveDownload.id ~= transferId then
		saveDownload = {id = transferId, total = total, chunks = {}, count = 0}
	end
	if not saveDownload.chunks[index] then
		saveDownload.chunks[index] = chunk
		saveDownload.count = saveDownload.count + 1
	end
end

local function takeDownloadedSave()
	local download = saveDownload
	saveDownload = nil
	if not download or download.count ~= download.total then
		return nil
	end
	local save = jsonDecode(table.concat(download.chunks))
	if type(save) ~= "table" or type(save.files) ~= "table" then
		return nil
	end
	return save
end

local function getNewestLocalSaveDate(profilePath)
	local newest
	for _, file in ipairs(FS:findFiles(profilePath, "info.json", 1, true, false)) do
		local info = jsonReadFile(file)
		if type(info) == "table" and type(info.date) == "string" and not info.corrupted and (not newest or info.date > newest) then
			newest = info.date
		end
	end
	return newest
end

local function keepUnsyncedLocalSave(profileName, profilePath, save)
	if not FS:directoryExists(profilePath) then
		return
	end
	local serverDate
	if save and type(save.files["info.json"]) == "string" then
		local info = jsonDecode(save.files["info.json"])
		serverDate = type(info) == "table" and info.date or nil
	end
	local localDate = getNewestLocalSaveDate(profilePath)
	if not localDate or (serverDate and localDate <= serverDate) then
		return
	end
	local backupName = profileName .. "unsynced" .. os.date("!%Y%m%d%H%M%S")
	if career_saveSystem.renameProfile(profileName, backupName) then
		log('W', 'careerMP', 'Kept a local career save that never reached the server as ' .. backupName)
		TriggerServerEvent("careerUnsyncedSave", jsonEncode({localDate = localDate, serverDate = serverDate or "", backup = backupName}))
		guihooks.trigger('toastrMsg', {type = "warning", title = "CareerMP", msg = "Your PC had newer progress than the server. It was kept as the save " .. backupName .. ", ask the server admin if you need it back.", config = {timeOut = 15000}})
	end
end

local function prepareServerProfile(profileName, save, revision)
	local profilePath = career_saveSystem.getSaveRootDirectory() .. profileName
	confirmedFiles = {}
	confirmedRevision = tonumber(revision) or 0
	pendingUpload = nil
	uploadQueued = false
	outgoingChunks = {}
	uploadRetries = 0
	unconfirmedFiles = {}
	keepUnsyncedLocalSave(profileName, profilePath, save)
	if not save then
		if FS:directoryExists(profilePath) then
			FS:directoryRemove(profilePath)
		end
		return false
	end
	for _, file in ipairs(FS:findFiles(profilePath, "*.json", -1, true, false)) do
		FS:removeFile(file)
	end
	local saveFolder = "autosave1"
	local savePath = profilePath .. "/" .. saveFolder .. "/"
	for relativePath, content in pairs(save.files) do
		if isValidSavePath(relativePath) and type(content) == "string" then
			local filePath = savePath .. relativePath
			local directory = string.match(filePath, "^(.*)/[^/]*$")
			if directory and not FS:directoryExists(directory) then
				FS:directoryCreate(directory, true)
			end
			writeFile(filePath, content)
			confirmedFiles[relativePath] = content
		end
	end
	return saveFolder
end

local function isServerProfileActive()
	if not serverAuthoritative or not careerMPActive or not serverProfileName or foreignCareerLoaded then
		return false
	end
	local profile = career_saveSystem.getCurrentProfile()
	return profile ~= nil and string.lower(profile) == serverProfileName
end

local function collectSaveFiles(savePath)
	if not savePath then
		local _, currentSavePath = career_saveSystem.getCurrentProfile()
		savePath = currentSavePath
	end
	if not savePath or savePath == "" then
		return nil
	end
	local basePath = string.lower(string.gsub(savePath, "^/", "")) .. "/"
	local files = {}
	for _, file in ipairs(FS:findFiles(savePath, "*.json", -1, true, false)) do
		local normalized = string.gsub(file, "^/", "")
		if string.sub(string.lower(normalized), 1, #basePath) == basePath then
			local relativePath = string.sub(normalized, #basePath + 1)
			if isValidSavePath(relativePath) then
				local content = readFile(file)
				if content then
					files[relativePath] = content
				end
			end
		end
	end
	if not files["info.json"] or not files["career/playerAttributes.json"] then
		return nil
	end
	return files
end

local function uploadCareerSave(force)
	if not isServerProfileActive() then
		return
	end
	if pendingUpload then
		uploadQueued = true
		return
	end
	local files = collectSaveFiles()
	if not files then
		log('E', 'careerMP', 'Career save is incomplete, not sending it to the server')
		return
	end
	local full = next(confirmedFiles) == nil
	local changed, removed = {}, {}
	local changes = 0
	for relativePath, content in pairs(files) do
		if full or confirmedFiles[relativePath] ~= content then
			changed[relativePath] = content
			changes = changes + 1
		end
	end
	if not full then
		for relativePath in pairs(confirmedFiles) do
			if not files[relativePath] then
				table.insert(removed, relativePath)
				changes = changes + 1
			end
		end
	end
	local manual = manualSaveRequested
	if changes == 0 and not manual and not force then
		return
	end
	manualSaveRequested = false
	uploadCounter = uploadCounter + 1
	local transferId = tostring(os.time()) .. tostring(uploadCounter)
	pendingUpload = {id = transferId, files = files, manual = manual}
	local upload = {id = transferId, base = confirmedRevision, full = full, manual = manual, files = changed, removed = removed}
	local chunks = splitString(jsonEncode(upload), saveChunkSize)
	outgoingChunks = {}
	for i, chunk in ipairs(chunks) do
		table.insert(outgoingChunks, transferId .. "|" .. i .. "|" .. #chunks .. "|" .. chunk)
	end
end

local function updateCareerSaveUpload()
	if #outgoingChunks > 0 then
		TriggerServerEvent("careerSaveChunk", table.remove(outgoingChunks, 1))
		if #outgoingChunks == 0 and pendingUpload then
			pendingUpload.sentAt = os.time()
		end
	elseif pendingUpload and pendingUpload.sentAt and os.time() - pendingUpload.sentAt > 30 then
		local wasManual = pendingUpload.manual
		pendingUpload = nil
		uploadRetries = uploadRetries + 1
		if uploadRetries <= 3 then
			log('W', 'careerMP', 'No answer from the server for the career save, sending it again')
			if wasManual then
				manualSaveRequested = true
			end
			uploadCareerSave(true)
		else
			uploadRetries = 0
			uploadQueued = false
			guihooks.trigger('toastrMsg', {type = "error", title = "CareerMP", msg = "Your career could not be saved on the server. It will be tried again on the next save.", config = {timeOut = 10000}})
		end
	end
end

local function onSaveFinished()
	uploadCareerSave()
end

local function rxCareerSaveStored(data)
	local result = jsonDecode(data)
	if type(result) ~= "table" or not pendingUpload or tostring(result.id) ~= pendingUpload.id then
		return
	end
	confirmedFiles = pendingUpload.files
	unconfirmedFiles = {}
	if type(result.modified) == "table" then
		for _, relativePath in pairs(result.modified) do
			confirmedFiles[relativePath] = nil
			unconfirmedFiles[relativePath] = true
		end
	end
	confirmedRevision = tonumber(result.revision) or confirmedRevision
	pendingUpload = nil
	uploadRetries = 0
	if uploadQueued then
		uploadQueued = false
		uploadCareerSave()
	end
end

local function rxCareerSaveResync(data)
	confirmedFiles = {}
	unconfirmedFiles = {}
	pendingUpload = nil
	uploadQueued = false
	outgoingChunks = {}
	if data == "manual" then
		manualSaveRequested = true
	end
	uploadCareerSave(true)
end

local function rxCareerSaveRequest(data)
	if not isServerProfileActive() or not career_career.isActive() then
		return
	end
	if not career_career.isAutosaveEnabled() then
		if data == "manual" then
			TriggerServerEvent("careerSaveUnavailable", "")
		end
		return
	end
	if data == "manual" then
		manualSaveRequested = true
		career_saveSystem.saveCurrent(nil, true)
	else
		career_saveSystem.saveCurrent()
	end
end

local function onPlayerAttributesChanged(change, reason)
	if not moneyReporting or type(change) ~= "table" or not isServerProfileActive() then
		return
	end
	local money = tonumber(change.money)
	if not money or money == 0 then
		return
	end
	local tags = {}
	if reason and type(reason.tags) == "table" then
		if reason.tags.careerMPServer then
			return
		end
		for tag, enabled in pairs(reason.tags) do
			if enabled then
				table.insert(tags, tostring(tag))
			end
		end
	end
	local label = reason and reason.label
	if type(label) == "table" then
		label = label.txt
	end
	TriggerServerEvent("careerMoneyChange", jsonEncode({money = money, tags = tags, label = tostring(label or "")}))
end

local function rxMoneyCorrection(data)
	local correction = jsonDecode(data)
	if type(correction) ~= "table" or not career_modules_playerAttributes then
		return
	end
	local value = tonumber(correction.value)
	if not value then
		return
	end
	local difference = value - career_modules_playerAttributes.getAttributeValue("money")
	if math.abs(difference) >= 0.01 then
		career_modules_playerAttributes.addAttributes({money = difference}, {tags = {"careerMPServer"}, label = "CareerMP server correction"})
		guihooks.trigger('toastrMsg', {type = "warning", title = "CareerMP", msg = tostring(correction.reason or "Your money was corrected by the server."), config = {timeOut = 5000}})
	end
end

local function rxCareerSaveFailed(data)
	pendingUpload = nil
	uploadQueued = false
	outgoingChunks = {}
	uploadRetries = 0
	guihooks.trigger('toastrMsg', {type = "error", title = "CareerMP", msg = "The server could not store your career save: " .. tostring(data), config = {timeOut = 8000}})
end

local function sameSaveFiles(files, otherFiles, ignored)
	if not files or not otherFiles then
		return false
	end
	for relativePath, content in pairs(files) do
		if otherFiles[relativePath] ~= content and not (ignored and ignored[relativePath]) then
			return false
		end
	end
	for relativePath in pairs(otherFiles) do
		if not files[relativePath] then
			return false
		end
	end
	return true
end

local function isServerSave(savePath, profile)
	if not profile or not savePath or string.lower(profile) ~= serverProfileName then
		return false
	end
	if next(confirmedFiles) == nil and not pendingUpload then
		return true
	end
	local files = collectSaveFiles(savePath)
	if sameSaveFiles(files, confirmedFiles, unconfirmedFiles) then
		return true
	end
	return pendingUpload ~= nil and sameSaveFiles(files, pendingUpload.files)
end

local function onSetProfile(savePath, profile)
	if not serverCareerLoaded or not serverAuthoritative or not careerMPActive or foreignCareerLoaded or not profile then
		return
	end
	if isServerSave(savePath, profile) then
		return
	end
	foreignCareerLoaded = true
	moneyReporting = false
	pendingUpload = nil
	uploadQueued = false
	outgoingChunks = {}
	log('W', 'careerMP', 'Loaded a career save that is not the server save: ' .. tostring(profile) .. ' ' .. tostring(savePath))
	TriggerServerEvent("careerForeignSave", jsonEncode({profile = tostring(profile), save = tostring(savePath)}))
	guihooks.trigger('toastrMsg', {type = "error", title = "CareerMP", msg = "This career save is not the one stored on the server, nothing you do with it will be saved.", config = {timeOut = 10000}})
end

local function onCareerActive(active)
	moneyReporting = active and serverAuthoritative and not foreignCareerLoaded or false
end

local function rxCareerSync(data)
	clientConfig = jsonDecode(data)
	nickname = MPConfig.getNickname()
	blockedInputActions = {}
	settingsCheck()
	actionsCheck()
	if not careerMPActive then
		careerMPActive = true
		local profileName
		local saveFolder = false
		if clientConfig.serverAuthoritative and clientConfig.profileName then
			serverAuthoritative = true
			profileName = string.lower(clientConfig.profileName)
			serverProfileName = profileName
			local save = clientConfig.hasServerSave and takeDownloadedSave()
			if clientConfig.hasServerSave and not save then
				careerMPActive = false
				log('E', 'careerMP', 'Could not download the career save from the server')
				guihooks.trigger('toastrMsg', {type = "error", title = "CareerMP", msg = "Could not download your career save from the server! Please rejoin.", config = {timeOut = 10000}})
				return
			end
			trafficHost = clientConfig.trafficHost == true
			serverCareerLoaded = false
			foreignCareerLoaded = false
			saveFolder = prepareServerProfile(profileName, save, clientConfig.saveRevision)
		else
			if clientConfig.serverSaveNameEnabled then
				nickname = clientConfig.serverSaveName
			end
			profileName = getProfileName(nickname .. clientConfig.serverSaveSuffix)
		end
		if not career_career.createOrLoadCareerAndStart(profileName, saveFolder, {startMode = "freshStart"}) then
			careerMPActive = false
			log('E', 'careerMP', 'Could not load career profile ' .. profileName)
			guihooks.trigger('toastrMsg', {type = "error", title = "CareerMP", msg = "Could not load career save " .. profileName .. "!", config = {timeOut = 10000}})
		elseif serverAuthoritative then
			serverCareerLoaded = true
		end
	end
end

local function rxClientConfigUpdate(data)
	clientConfig = jsonDecode(data)
	ghostStates = {}
	blockedInputActions = {}
	settingsCheck()
	actionsCheck()
end

local function onBeforeCareerActivate()
	if careerMPActive then
		local vehicles = MPVehicleGE.getVehicles()
		for _, vehicle in pairs(vehicles) do
			if vehicle.isLocal then
				if vehicle.jbeam ~= "unicycle" then
					local veh = be:getObjectByID(vehicle.gameVehicleID)
					if veh then
						veh:delete()
					end
				end
			end
		end
	end
end

--Shared Traffic

local function getTrafficAmounts(trafficAmount, parkingAmount)
	local extraAmount = 0
	if not clientConfig then
		return trafficAmount, parkingAmount, extraAmount
	end
	if clientConfig.sharedTraffic then
		if trafficHost then
			trafficAmount = clientConfig.roadTrafficEnabled and (tonumber(clientConfig.roadTrafficAmount) or 0) or 0
			parkingAmount = clientConfig.parkedTrafficEnabled and (tonumber(clientConfig.parkedTrafficAmount) or 0) or 0
			if trafficAmount > 0 and clientConfig.extraTrafficEnabled then
				extraAmount = tonumber(clientConfig.extraTrafficAmount) or 0
			end
		else
			trafficAmount, parkingAmount = 0, 0
		end
	else
		if clientConfig.roadTrafficEnabled then
			trafficAmount = clamp(trafficAmount, 2, tonumber(clientConfig.roadTrafficAmount) or 50)
			if clientConfig.extraTrafficEnabled then
				extraAmount = tonumber(clientConfig.extraTrafficAmount) or 0
			end
		else
			trafficAmount = 0
		end
		if clientConfig.parkedTrafficEnabled then
			parkingAmount = clamp(parkingAmount, 2, tonumber(clientConfig.parkedTrafficAmount) or 50)
		else
			parkingAmount = 0
		end
	end
	local mode = ""
	if clientConfig.sharedTraffic then
		mode = trafficHost and " (traffic host)" or " (shared traffic from another player)"
	end
	log('I', 'careerMP', string.format("Server traffic settings: %s road, %s extra, %s parked%s", tostring(trafficAmount), tostring(extraAmount), tostring(parkingAmount), mode))
	return trafficAmount, parkingAmount, extraAmount
end

local function isTrafficHost()
	return trafficHost
end

local function isTrafficAllowed()
	return not (clientConfig and clientConfig.sharedTraffic) or trafficHost
end

local function getLocalTrafficIds(includeTraffic, includeParked)
	local ids = {}
	if includeTraffic and gameplay_traffic and gameplay_traffic.getTrafficList then
		for _, id in ipairs(gameplay_traffic.getTrafficList() or {}) do
			table.insert(ids, id)
		end
	end
	if includeParked and gameplay_parking and gameplay_parking.getParkedCarsList then
		for _, id in ipairs(gameplay_parking.getParkedCarsList() or {}) do
			table.insert(ids, id)
		end
	end
	return ids
end

local function removeLocalTraffic(includeTraffic, includeParked)
	local playerVehicleID = be:getPlayerVehicleID(0)
	for _, id in ipairs(getLocalTrafficIds(includeTraffic, includeParked)) do
		local owned = career_modules_inventory and career_modules_inventory.getInventoryIdFromVehicleId(id)
		if id ~= playerVehicleID and not owned and MPVehicleGE.isOwn(id) then
			local veh = be:getObjectByID(id)
			if veh then
				veh:delete()
			end
		end
	end
	reportedTraffic = ""
end

local function spawnSharedTraffic()
	if not gameplay_traffic or not gameplay_traffic.setupTrafficHelper then
		return
	end
	local trafficAmount, parkingAmount, extraAmount = getTrafficAmounts(0, 0)
	if trafficAmount <= 0 and parkingAmount <= 0 then
		return
	end
	local spawnAmount = trafficAmount > 0 and trafficAmount + extraAmount or 0
	gameplay_traffic.setupTrafficHelper(spawnAmount, {simpleVehs = true, autoLoadFromFile = true}, parkingAmount, nil)
	gameplay_traffic.setActiveAmount(trafficAmount)
	gameplay_parking.setActiveAmount(parkingAmount)
end

local function rxTrafficHost(data)
	local isHost = data == "1"
	if isHost == trafficHost then
		return
	end
	trafficHost = isHost
	if careerMPActive and career_career.isActive() then
		if isHost then
			spawnSharedTraffic()
		else
			removeLocalTraffic(true, true)
		end
	end
end

local function reportTrafficVehicles()
	local serverVehicleIDs = {}
	for _, id in ipairs(getLocalTrafficIds(true, true)) do
		local serverVehicleID = MPVehicleGE.getServerVehicleID(id)
		if serverVehicleID then
			table.insert(serverVehicleIDs, serverVehicleID)
		end
	end
	table.sort(serverVehicleIDs)
	local report = table.concat(serverVehicleIDs, ",")
	if report ~= reportedTraffic and #serverVehicleIDs > 0 then
		reportedTraffic = report
		TriggerServerEvent("careerTrafficVehicles", jsonEncode(serverVehicleIDs))
	end
end

local function onTrafficOrParkingReady()
	if not careerMPActive or not clientConfig then
		return
	end
	if not isTrafficAllowed() then
		removeLocalTraffic(true, true)
		return
	end
	removeLocalTraffic(not clientConfig.roadTrafficEnabled, not clientConfig.parkedTrafficEnabled)
	trafficReportTimer = 0
end

local function onVehicleResetted(gameVehicleID)
	ghostStates[gameVehicleID] = nil
end

local function onVehicleDestroyed(gameVehicleID)
	ghostStates[gameVehicleID] = nil
end

local function onWorldReadyState(state)
	if state == 2 then
		if not syncRequested then
			TriggerServerEvent("prefabSyncRequested", "")
			TriggerServerEvent("careerSyncRequested", "")
			syncRequested = true
		end
	end
end

local function onUpdate(dtReal, dtSim, dtRaw)
	if serverAuthoritative then
		updateCareerSaveUpload()
	end
	if trafficHost and careerMPActive then
		trafficReportTimer = trafficReportTimer - (dtReal or 0)
		if trafficReportTimer <= 0 then
			trafficReportTimer = 3
			reportTrafficVehicles()
		end
	end
	if worldReadyState == 2 then
		if clientConfig then
			local vehicles = MPVehicleGE.getVehicles()
			for serverVehicleID in pairs(vehicles) do
				local gameVehicleID = vehicles[serverVehicleID].gameVehicleID
				local veh = be:getObjectByID(gameVehicleID)
				if veh then
					local ghost
					if not MPVehicleGE.isOwn(gameVehicleID) then
						if veh.JBeam == "unicycle" then
							ghost = clientConfig.remoteUnicycleGhost
						else
							ghost = clientConfig.remoteVehicleGhost
						end
					elseif veh.JBeam == "unicycle" then
						ghost = clientConfig.localUnicycleGhost
					end
					if ghost ~= nil then
						ghost = ghost and true or false
						if ghostStates[gameVehicleID] ~= ghost then
							ghostStates[gameVehicleID] = ghost
							veh:queueLuaCommand(string.format('careerMPEnabler.setGhost(%s)', tostring(ghost)))
						end
					end
				end
			end
		end
	end
end

--Loading / Unloading

local function onExtensionLoaded()
	getUserTrafficSettings()
	getUserGameplaySettings()
	AddEventHandler("rxCareerSync", rxCareerSync)
	AddEventHandler("rxCareerSaveChunk", rxCareerSaveChunk)
	AddEventHandler("rxCareerSaveStored", rxCareerSaveStored)
	AddEventHandler("rxCareerSaveResync", rxCareerSaveResync)
	AddEventHandler("rxCareerSaveRequest", rxCareerSaveRequest)
	AddEventHandler("rxTrafficHost", rxTrafficHost)
	AddEventHandler("rxCareerSaveFailed", rxCareerSaveFailed)
	AddEventHandler("rxMoneyCorrection", rxMoneyCorrection)
	AddEventHandler("rxClientConfigUpdate", rxClientConfigUpdate)
	AddEventHandler("rxCareerVehSync", rxCareerVehSync)
	AddEventHandler("rxTrafficSignalTimer", rxTrafficSignalTimer)
	career_career = extensions.career_careerMP
	log('W', 'careerMP', 'CareerMP Enabler LOADED!')
end

local function onExtensionUnloaded()
	log('W', 'careerMP', 'CareerMP Enabler UNLOADED!')
end

local function onServerLeave()
	blockedInputActions = {}
	extensions.core_input_actionFilter.setGroup('careerMP', blockedInputActions)
	extensions.core_input_actionFilter.addAction(0, 'careerMP', false)
	setTrafficSettings(userTrafficSettings)
	setGameplaySettings(userGameplaySettings)
end

--Access

M.getClientConfig = getClientConfig

M.onBeforeCareerActivate = onBeforeCareerActivate
M.onCareerActive = onCareerActive
M.onSetProfile = onSetProfile
M.onSaveFinished = onSaveFinished
M.onPlayerAttributesChanged = onPlayerAttributesChanged

M.onVehicleActiveChanged = onVehicleActiveChanged
M.onVehicleSpawned = onVehicleSpawned
M.onVehicleReady = onVehicleReady
M.onVehicleSwitched = onVehicleSwitched

M.onSpeedTrapTriggered = onSpeedTrapTriggered
M.onRedLightCamTriggered = onRedLightCamTriggered

M.onComputerMenuOpened = onComputerOpened

M.onCareerTuningStarted = computerMenuHandler
M.onPartShoppingStarted = computerMenuHandler
M.onVehiclePaintingUiOpened = computerMenuHandler

M.onTrafficOrParkingReady = onTrafficOrParkingReady
M.onVehicleResetted = onVehicleResetted
M.onVehicleDestroyed = onVehicleDestroyed
M.getTrafficAmounts = getTrafficAmounts
M.isTrafficHost = isTrafficHost

M.onWorldReadyState = onWorldReadyState
M.onUpdate = onUpdate

M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded

M.onServerLeave = onServerLeave
M.onBeamMPServerLeave = onServerLeave

M.onInit = function() setExtensionUnloadMode(M, 'manual') end

return M
