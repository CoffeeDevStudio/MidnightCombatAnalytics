_G.MCA = _G.MCA or {}
MCA = _G.MCA

function MCA:CreateEmptyPlayer(name, class, role, guid, unit)
    return {
        name = name,
        unit = unit,
        guid = guid,
        class = class or "UNKNOWN",
        role = role or "DAMAGER",
        used = {},
        usedBySpell = {},
        deaths = 0,
        debuffs = {},
        debuffSeen = {},
        deadSeen = false,
        hasAddon = name == UnitName("player")
    }
end

function MCA:AddRosterUnit(unit)
    if not UnitExists(unit) then return end

    local name = UnitName(unit)
    if not name then return end

    local _, class = UnitClass(unit)
    local guid = UnitGUID(unit)
    local role = self:GetUnitRole(unit)

    self.roster[name] = self:CreateEmptyPlayer(name, class, role, guid, unit)

    if guid then
        self.guidToName[guid] = name
    end
end

function MCA:UpdateRoster()
    self.roster = {}
    self.guidToName = {}

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            self:AddRosterUnit("raid" .. i)
        end
    elseif IsInGroup() then
        self:AddRosterUnit("player")
        for i = 1, GetNumSubgroupMembers() do
            self:AddRosterUnit("party" .. i)
        end
    else
        self:AddRosterUnit("player")
    end
end

function MCA:CopyRosterToSession()
    if not self.session then return end

    self.session.players = {}

    for name, p in pairs(self.roster or {}) do
        self.session.players[name] = self:CreateEmptyPlayer(p.name, p.class, p.role, p.guid, p.unit)
        self.session.players[name].hasAddon = p.hasAddon
        self.session.players[name].version = p.version
    end
end

function MCA:EnsureSessionPlayer(name, class, role, guid)
    if not self.session or not name then return nil end

    self.session.players = self.session.players or {}

    if not self.session.players[name] then
        self.session.players[name] = self:CreateEmptyPlayer(name, class, role, guid, nil)
        self.session.players[name].hasAddon = true
        self.session.players[name].synced = true
    else
        local p = self.session.players[name]
        p.class = class or p.class
        p.role = role or p.role
        p.guid = guid or p.guid
        p.hasAddon = true
    end

    return self.session.players[name]
end

function MCA:StartRaidEncounter(id, name)
    if self.session and self.session.type == "M+" then
        self.currentMythicBoss = {
            id = id,
            name = name,
            startTime = GetTime() - self.session.start
        }
        self:Debug("M+ boss started: " .. tostring(name))
        return
    end

    self:UpdateRoster()

    self.session = {
        type = "raid",
        encounterID = id,
        boss = name or "Raid Encounter",
        start = GetTime(),
        duration = 0,
        result = false,
        players = {},
        bosses = {},
        timeline = {}
    }

    self:CopyRosterToSession()
    self:SendHello()

    self:Print("Raid encounter started: " .. tostring(name))
end

function MCA:FinishRaidEncounter(id, name, success)
    if self.session and self.session.type == "M+" then
        local startTime = self.currentMythicBoss and self.currentMythicBoss.startTime or math.max(0, (GetTime() - self.session.start) - 30)
        local endTime = GetTime() - self.session.start

        table.insert(self.session.bosses, {
            id = id,
            name = name or "Boss",
            success = success == 1,
            startTime = startTime,
            endTime = endTime,
            duration = math.max(0, endTime - startTime)
        })

        self.currentMythicBoss = nil
        self:Debug("M+ boss ended: " .. tostring(name))
        return
    end

    if not self.session or self.session.type ~= "raid" then return end

    self:FinalizeSession(success == 1)
end

function MCA:StartMythicPlusSession()
    self:UpdateRoster()

    local dungeonName = "Mythic+"

    if C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID and C_ChallengeMode.GetMapUIInfo then
        local okMap, mapID = pcall(C_ChallengeMode.GetActiveChallengeMapID)
        if okMap and mapID then
            local okInfo, name = pcall(C_ChallengeMode.GetMapUIInfo, mapID)
            if okInfo and name then dungeonName = name end
        end
    end

    self.session = {
        type = "M+",
        boss = dungeonName,
        start = GetTime(),
        duration = 0,
        result = false,
        players = {},
        bosses = {},
        timeline = {}
    }

    self:CopyRosterToSession()
    self:SendHello()

    self:Print("Mythic+ started")
end

function MCA:FinishMythicPlusSession(success)
    if not self.session or self.session.type ~= "M+" then return end
    self:FinalizeSession(success == true)
end


function MCA:GetDamageMeterSourceValue(source, keys)
    if not source or not keys then return 0 end

    for _, key in ipairs(keys) do
        local value = source[key]
        if type(value) == "number" then
            return value
        end

        if type(value) == "function" then
            local ok, result = pcall(value, source)
            if ok and type(result) == "number" then
                return result
            end
        end
    end

    return 0
end

function MCA:NormalizeDamageMeterName(name)
    -- MCA 4.1.6:
    -- C_DamageMeter can return player names as protected/secret strings.
    -- Direct comparisons on derived values can taint and fail, so avoid
    -- comparing the protected value itself. Convert with pcall first.
    if name == nil then return nil end

    local ok, plain = pcall(tostring, name)
    if not ok or plain == nil then
        return nil
    end

    local okShort, short = pcall(strsplit, "-", plain)
    if okShort and short ~= nil then
        return tostring(short)
    end

    return tostring(plain)
end
function MCA:FindSessionPlayerByDamageMeterSource(source)
    if not self.session or not source then return nil end

    local name = source.name or source.unitName or source.playerName or source.sourceName
    name = self:NormalizeDamageMeterName(name)

    if name and self.session.players and self.session.players[name] then
        return self.session.players[name]
    end

    local guid = source.guid or source.GUID or source.unitGUID or source.sourceGUID
    if guid then
        for _, p in pairs(self.session.players or {}) do
            if p.guid == guid then return p end
        end
    end

    return nil
end

function MCA:GetDamageMeterSource(index)
    if not C_DamageMeter then return nil end

    local calls = {
        function() return C_DamageMeter.GetCombatSessionSourceFromType(index) end,
        function() return C_DamageMeter.GetCombatSessionSource(index) end,
        function() return C_DamageMeter.GetSource(index) end,
    }

    for _, call in ipairs(calls) do
        local ok, source = pcall(call)
        if ok and source then return source end
    end

    return nil
end

function MCA:GetDamageMeterSourceCount()
    if not C_DamageMeter then return 0 end

    local calls = {
        function() return C_DamageMeter.GetCombatSessionNumSources() end,
        function() return C_DamageMeter.GetNumCombatSessionSources() end,
        function() return C_DamageMeter.GetNumSources() end,
    }

    for _, call in ipairs(calls) do
        local ok, count = pcall(call)
        if ok and type(count) == "number" and count > 0 then
            return count
        end
    end

    return 0
end


-- 4.0.28: Blizzard Damage Meter integration
-- Reads the official Blizzard meter at the end of the fight and copies final DPS/HPS
-- into the MCA report tables. MCA still owns deaths, class, timeline and the rest.
function MCA:DamageMeterAvailable()
    if not C_DamageMeter then return false end
    if C_DamageMeter.IsDamageMeterAvailable then
        local ok, available = pcall(C_DamageMeter.IsDamageMeterAvailable)
        if ok and available == false then return false end
    end
    return true
end

function MCA:GetDamageMeterEnumValue(enumTable, key, fallback)
    if Enum and enumTable and Enum[enumTable] and Enum[enumTable][key] ~= nil then
        return Enum[enumTable][key]
    end
    return fallback
end

function MCA:NormalizeDamageMeterSessionName(name)
    if not name then return "" end
    local n = tostring(name)
    n = n:gsub("^%s*%!%s*", "")
    n = n:gsub("^%s*%(%!%)%s*", "")
    n = n:gsub("^%s*", ""):gsub("%s*$", "")
    return string.lower(n)
end

function MCA:FindBlizzardDamageMeterSessionID(encounterName)
    if not self:DamageMeterAvailable() or not C_DamageMeter.GetAvailableCombatSessions then return nil end

    local ok, sessions = pcall(C_DamageMeter.GetAvailableCombatSessions)
    if not ok or type(sessions) ~= "table" then return nil end

    local target = self:NormalizeDamageMeterSessionName(encounterName)
    local bestID, bestScore, bestDuration = nil, -1, -1

    for _, sessionInfo in ipairs(sessions) do
        local sid = sessionInfo and sessionInfo.sessionID
        local sname = self:NormalizeDamageMeterSessionName(sessionInfo and sessionInfo.name)
        local duration = tonumber(sessionInfo and sessionInfo.durationSeconds or 0) or 0
        local score = 0

        if target ~= "" and sname ~= "" then
            if sname == target then
                score = 100
            elseif string.find(sname, target, 1, true) or string.find(target, sname, 1, true) then
                score = 80
            end
        end

        -- Keep the latest/longest plausible fight if there is no name match.
        if score == 0 and duration > 0 then
            score = 10
        end

        if sid and (score > bestScore or (score == bestScore and duration >= bestDuration)) then
            bestID = sid
            bestScore = score
            bestDuration = duration
        end
    end

    return bestID
end

function MCA:GetBlizzardDamageMeterSession(sessionID, meterType)
    if not self:DamageMeterAvailable() then return nil end

    if sessionID and C_DamageMeter.GetCombatSessionFromID then
        local ok, session = pcall(C_DamageMeter.GetCombatSessionFromID, sessionID, meterType)
        if ok and type(session) == "table" then return session end
    end

    if C_DamageMeter.GetCombatSessionFromType then
        local sessionTypes = {
            self:GetDamageMeterEnumValue("DamageMeterSessionType", "Current", 1),
            self:GetDamageMeterEnumValue("DamageMeterSessionType", "Expired", 2),
            self:GetDamageMeterEnumValue("DamageMeterSessionType", "Overall", 0),
        }
        for _, sessionType in ipairs(sessionTypes) do
            local ok, session = pcall(C_DamageMeter.GetCombatSessionFromType, sessionType, meterType)
            if ok and type(session) == "table" then return session end
        end
    end

    return nil
end

function MCA:ApplyBlizzardDamageMeterSources(session, bucketName, metricField, totalField)
    if not self.session or type(session) ~= "table" or type(session.combatSources) ~= "table" then return 0 end

    self.session.blizzard = self.session.blizzard or { dps = {}, hps = {} }
    self.session.blizzard[bucketName] = self.session.blizzard[bucketName] or {}

    local applied = 0

    for _, source in ipairs(session.combatSources) do
        local p = self:FindSessionPlayerByDamageMeterSource(source)
        local amountPerSecond = tonumber(source.amountPerSecond or source.dps or source.hps or 0) or 0
        local totalAmount = tonumber(source.totalAmount or source.total or 0) or 0

        if p and amountPerSecond > 0 then
            p.blizzard = p.blizzard or {}
            p.blizzard[bucketName] = {
                amountPerSecond = amountPerSecond,
                totalAmount = totalAmount,
                sourceGUID = source.sourceGUID or source.guid or source.unitGUID,
                name = source.name,
                classFilename = source.classFilename,
                sessionDuration = session.durationSeconds,
            }

            local key = p.guid or source.sourceGUID or p.name or source.name
            if key then
                self.session.blizzard[bucketName][key] = p.blizzard[bucketName]
            end

            p[metricField] = amountPerSecond
            p[totalField] = totalAmount

            if bucketName == "dps" then
                p.fightDPS = amountPerSecond
                p.dps = amountPerSecond
                p.damageDone = totalAmount
            elseif bucketName == "hps" then
                p.fightHPS = amountPerSecond
                p.hps = amountPerSecond
                p.healingDone = totalAmount
            end

            if source.classFilename and (not p.class or p.class == "UNKNOWN") then
                p.class = source.classFilename
            end

            applied = applied + 1
        end
    end

    return applied
end



-- MCA 4.2.0: Mythic+ overall meter helpers
function MCA:IsCurrentSessionMythicPlus()
    if not self.session then return false end
    local t = tostring(self.session.type or ""):lower()
    local m = tostring(self.session.mode or ""):lower()
    local d = tostring(self.session.difficulty or ""):lower()
    return t == "m+" or m:find("mythic%+") ~= nil or d:find("%+") ~= nil or d:find("mythic%+") ~= nil
end

function MCA:GetBestOverallDamageMeterSession(meterType)
    if not meterType or not self:DamageMeterAvailable() then return nil, nil end

    local bestData, bestID, bestDuration = nil, nil, -1

    for sessionID = 0, 30 do
        local data = self:GetBlizzardDamageMeterSession(sessionID, meterType)
        if type(data) == "table" and type(data.combatSources) == "table" and #data.combatSources > 0 then
            local duration = tonumber(data.durationSeconds or data.duration or 0) or 0
            if duration > bestDuration then
                bestData = data
                bestID = sessionID
                bestDuration = duration
            end
        end
    end

    return bestData, bestID
end

function MCA:ApplyBlizzardInterruptSources(session)
    if not self.session or type(session) ~= "table" or type(session.combatSources) ~= "table" then return 0 end

    self.session.blizzard = self.session.blizzard or { dps = {}, hps = {}, interrupts = {} }
    self.session.blizzard.interrupts = self.session.blizzard.interrupts or {}

    local applied = 0

    for _, source in ipairs(session.combatSources) do
        local p = self:FindSessionPlayerByDamageMeterSource(source)
        local totalAmount = tonumber(source.totalAmount or source.total or source.amount or source.count or 0) or 0

        if p then
            p.blizzardInterrupts = totalAmount
            p.interrupts = totalAmount
            local key = p.guid or source.sourceGUID or p.name
            if key then
                self.session.blizzard.interrupts[key] = {
                    totalAmount = totalAmount,
                    sourceGUID = source.sourceGUID or source.guid or source.unitGUID,
                    name = source.name,
                    classFilename = source.classFilename,
                    sessionDuration = session.durationSeconds,
                }
            end

            if source.classFilename and (not p.class or p.class == "UNKNOWN") then
                p.class = source.classFilename
            end

            applied = applied + 1
        end
    end

    return applied
end

function MCA:CaptureMythicPlusOverallDamageMeterStats()
    if not self.session or not self:IsCurrentSessionMythicPlus() or not self:DamageMeterAvailable() then return false end

    local dpsType = self:GetDamageMeterEnumValue("DamageMeterType", "Dps", 1)
    local hpsType = self:GetDamageMeterEnumValue("DamageMeterType", "Hps", 3)
    local interruptType = self:GetDamageMeterEnumValue("DamageMeterType", "Interrupts", 5)

    self.session.blizzard = self.session.blizzard or { dps = {}, hps = {}, interrupts = {} }
    self.session.blizzard.mode = "mythicplus_overall"
    self.session.blizzard.capturedAt = date and date("%d/%m/%Y %H:%M:%S") or nil

    local dpsSession, dpsID = self:GetBestOverallDamageMeterSession(dpsType)
    local hpsSession, hpsID = self:GetBestOverallDamageMeterSession(hpsType)
    local interruptSession, interruptID = self:GetBestOverallDamageMeterSession(interruptType)

    local dpsApplied = self:ApplyBlizzardDamageMeterSources(dpsSession, "dps", "blizzardDps", "blizzardDamageDone")
    local hpsApplied = self:ApplyBlizzardDamageMeterSources(hpsSession, "hps", "blizzardHps", "blizzardHealingDone")
    local interruptsApplied = self:ApplyBlizzardInterruptSources(interruptSession)

    self.session.blizzard.overallDpsSessionID = dpsID
    self.session.blizzard.overallHpsSessionID = hpsID
    self.session.blizzard.overallInterruptSessionID = interruptID
    self.session.blizzard.dpsApplied = dpsApplied
    self.session.blizzard.hpsApplied = hpsApplied
    self.session.blizzard.interruptsApplied = interruptsApplied

    if self.Debug then
        self:Debug("M+ Overall DamageMeter captured: dps=" .. tostring(dpsApplied) .. " hps=" .. tostring(hpsApplied) .. " interrupts=" .. tostring(interruptsApplied))
    end

    return (dpsApplied or 0) > 0 or (hpsApplied or 0) > 0 or (interruptsApplied or 0) > 0
end

function MCA:CaptureDamageMeterStats()

    -- MCA 4.2.0 Mythic+ overall capture:
    -- for M+ reports, use overall key data instead of the last boss/encounter.
    if self.CaptureMythicPlusOverallDamageMeterStats and self:CaptureMythicPlusOverallDamageMeterStats() then
        return
    end
    if not self.session or not self:DamageMeterAvailable() then return end

    local dpsType = self:GetDamageMeterEnumValue("DamageMeterType", "Dps", 1)
    local hpsType = self:GetDamageMeterEnumValue("DamageMeterType", "Hps", 3)
    local sessionID = self:FindBlizzardDamageMeterSessionID(self.session.boss)

    self.session.blizzard = self.session.blizzard or { dps = {}, hps = {} }
    self.session.blizzard.sessionID = sessionID
    self.session.blizzard.capturedAt = date and date("%d/%m/%Y %H:%M:%S") or nil

    local dpsSession = self:GetBlizzardDamageMeterSession(sessionID, dpsType)
    local hpsSession = self:GetBlizzardDamageMeterSession(sessionID, hpsType)

    local dpsApplied = self:ApplyBlizzardDamageMeterSources(dpsSession, "dps", "blizzardDps", "blizzardDamageDone")
    local hpsApplied = self:ApplyBlizzardDamageMeterSources(hpsSession, "hps", "blizzardHps", "blizzardHealingDone")

    self.session.blizzard.dpsApplied = dpsApplied
    self.session.blizzard.hpsApplied = hpsApplied

    if self.Debug then
        self:Debug("Blizzard DamageMeter captured: sessionID=" .. tostring(sessionID) .. " dps=" .. tostring(dpsApplied) .. " hps=" .. tostring(hpsApplied))
    end
end

function MCA:FinalizeSession(success)
    if not self.session then return end

    if self.ScanAllAuras then self:ScanAllAuras() end
    if self.ScanAllDebuffs then self:ScanAllDebuffs() end

    self.session.duration = GetTime() - self.session.start
    self.session.result = success == true

    local mcaMode, mcaDifficulty = self:GetCurrentModeDifficulty()
    self.session.mode = self.session.mode or mcaMode
    self.session.difficulty = self.session.difficulty or mcaDifficulty
    self.session.savedAt = self.session.savedAt or (date and date("%d/%m/%Y %H:%M") or "?")
    self.session.savedAtEpoch = self.session.savedAtEpoch or (time and time() or 0)

    self.session.difficulty = self.session.difficulty or self:GetCurrentRaidDifficultyLabel()
    if self.CaptureDamageMeterStats then self:CaptureDamageMeterStats() end
    local report = self:BuildReport(self.session)

    self.lastReport = report
    self:SaveReportToHistory(report)
    if self.SendReportSnapshot then
        self:SendReportSnapshot(report)
        C_Timer.After(0.7, function()
            if MCA and MCA.lastReport == report then MCA:SendReportSnapshot(report) end
        end)
        C_Timer.After(2.0, function()
            if MCA and MCA.lastReport == report then MCA:SendReportSnapshot(report) end
        end)
    end

    self.session = nil
    self.currentMythicBoss = nil

    self:SafeOpenReport(report)
end


function MCA:GetCurrentDifficultyLabel()
    local _, _, difficultyID, difficultyName = GetInstanceInfo()

    if difficultyName and difficultyName ~= "" then
        return difficultyName
    end

    if difficultyID == 17 then return "LFR" end
    if difficultyID == 14 then return "Normal" end
    if difficultyID == 15 then return "Heroic" end
    if difficultyID == 16 then return "Mythic" end
    if difficultyID == 8 then return "Mythic+" end
    if difficultyID == 23 then return "Mythic" end

    return "-"
end


function MCA:GetCurrentModeDifficulty()
    local mode = "Raid"
    local difficulty = "-"

    local _, instanceType, difficultyID, difficultyName = GetInstanceInfo()

    if instanceType == "party" then
        mode = "Dungeon"
    elseif instanceType == "raid" then
        mode = "Raid"
    end

    if C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo then
        local ok, level = pcall(C_ChallengeMode.GetActiveKeystoneInfo)
        if ok and level and level > 0 then
            return "Mythic+", "+" .. tostring(level)
        end
    end

    if difficultyName and difficultyName ~= "" then
        difficulty = difficultyName
    elseif difficultyID == 17 then
        difficulty = "LFR"
    elseif difficultyID == 14 then
        difficulty = "Normal"
    elseif difficultyID == 15 then
        difficulty = "Heroic"
    elseif difficultyID == 16 then
        difficulty = "Mythic"
    elseif difficultyID == 8 then
        difficulty = "Mythic+"
    elseif difficultyID == 23 then
        difficulty = "Mythic"
    end

    return mode, difficulty
end


function MCA:SaveReportToHistory(report)
    if self.ApplyClassBasedRatings then self:ApplyClassBasedRatings(report) end
    if not report then return end

    MidnightCombatAnalyticsDB.history = MidnightCombatAnalyticsDB.history or {}

    report.savedAt = report.savedAt or (date and date("%d/%m/%Y %H:%M") or "?")
    report.savedAtEpoch = report.savedAtEpoch or (time and time() or 0)
    report.historyID = report.historyID or (tostring(report.savedAtEpoch) .. "-" .. tostring(math.random(1000, 9999)))

    table.insert(MidnightCombatAnalyticsDB.history, report)

    local limit = 50
    if MidnightCombatAnalyticsDB.config and MidnightCombatAnalyticsDB.config.historyLimit then
        limit = MidnightCombatAnalyticsDB.config.historyLimit
    end

    if not limit or limit < 1 then limit = 50 end

    while #MidnightCombatAnalyticsDB.history > limit do
        table.remove(MidnightCombatAnalyticsDB.history, 1)
    end
end

function MCA:GetHistory()
    MidnightCombatAnalyticsDB.history = MidnightCombatAnalyticsDB.history or {}
    return MidnightCombatAnalyticsDB.history
end

function MCA:ClearHistory()
    MidnightCombatAnalyticsDB.history = {}
    self:Print("Storico report cancellato.")
end


function MCA:GetCurrentRaidDifficultyLabel()
    local _, _, difficultyID, difficultyName = GetInstanceInfo()

    if difficultyName and difficultyName ~= "" then
        if difficultyName == "Looking For Raid" then return "LFR" end
        return difficultyName
    end

    if difficultyID == 17 then return "LFR" end
    if difficultyID == 14 then return "Normal" end
    if difficultyID == 15 then return "Heroic" end
    if difficultyID == 16 then return "Mythic" end
    if difficultyID == 8 then return "Mythic+" end
    if difficultyID == 23 then return "Mythic" end

    return "-"
end
