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


-- ============================================================================
-- MCA 4.3.5 Damage Meter late joiner helpers
-- If raid roster changed during the pull, the Blizzard meter may contain players
-- that were not in the initial MCA session snapshot. When the source is readable,
-- create/update the MCA session player by meter name.
-- ============================================================================

function MCA:GetSafeDamageMeterString(source, fieldName)
    if not source or not fieldName then return nil end
    local ok, value = pcall(function()
        local v = source[fieldName]
        if v == nil then return nil end
        return tostring(v)
    end)
    if ok and type(value) == "string" and value ~= "" then
        return value
    end
    return nil
end

function MCA:GetSafeDamageMeterSourceShortName(source)
    local name = self:GetSafeDamageMeterString(source, "name")
    if not name then return nil, nil end

    local short = name
    local ok, first = pcall(function()
        return strsplit and strsplit("-", name) or string.match(name, "^([^-]+)")
    end)

    if ok and type(first) == "string" and first ~= "" then
        short = first
    end

    return short, name
end

function MCA:EnsureSessionPlayerFromDamageMeterSource(source)
    if not self.session or not source then return nil end
    self.session.players = self.session.players or {}

    local shortName, fullName = self:GetSafeDamageMeterSourceShortName(source)
    if not shortName then return nil end

    local p = self.session.players[shortName] or (fullName and self.session.players[fullName])
    if not p then
        p = self:CreateEmptyPlayer(shortName)
        self.session.players[shortName] = p
    end

    local classFilename = self:GetSafeDamageMeterString(source, "classFilename")
    if classFilename and (not p.class or p.class == "UNKNOWN") then
        p.class = classFilename
    end

    p.name = p.name or shortName
    p.fromDamageMeter = true
    return p
end

function MCA:FindSessionPlayerByDamageMeterSource(source)
    -- MCA 4.3.5:
    -- Match by safe Damage Meter name. If roster changed mid-fight and the
    -- player was not in the original session snapshot, create/update it from
    -- the readable Blizzard meter source.
    if not self.session or not source or type(self.session.players) ~= "table" then return nil end

    local ok, p = pcall(function()
        local shortName, fullName = self:GetSafeDamageMeterSourceShortName(source)
        if not shortName then return nil end

        local existing = self.session.players[shortName]
        if existing then return existing end

        if fullName and self.session.players[fullName] then
            return self.session.players[fullName]
        end

        for _, candidate in pairs(self.session.players) do
            if candidate and (candidate.name == shortName or candidate.name == fullName) then
                return candidate
            end
        end

        return self:EnsureSessionPlayerFromDamageMeterSource(source)
    end)

    if ok then return p end
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
    local skippedProtected = 0

    for _, source in ipairs(session.combatSources) do
        local ok, matched = pcall(function()
            local p = self:FindSessionPlayerByDamageMeterSource(source)
            if not p then return false end

            local amountPerSecond = tonumber(source.amountPerSecond or source.dps or source.hps or 0) or 0
            local totalAmount = tonumber(source.totalAmount or source.total or 0) or 0

            if amountPerSecond <= 0 then return false end

            local sourceName = self:GetSafeDamageMeterString(source, "name")
            local classFilename = self:GetSafeDamageMeterString(source, "classFilename")
            if classFilename and (not p.class or p.class == "UNKNOWN") then
                p.class = classFilename
            end

            p.blizzard = p.blizzard or {}
            p.blizzard[bucketName] = {
                amountPerSecond = amountPerSecond,
                totalAmount = totalAmount,
                name = sourceName,
                classFilename = classFilename,
                sessionDuration = session.durationSeconds,
            }

            local key = p.guid or p.name or sourceName
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

            return true
        end)

        if ok and matched then
            applied = applied + 1
        elseif not ok then
            skippedProtected = skippedProtected + 1
        end
    end

    if skippedProtected > 0 then
        self.session.blizzard.skippedProtectedSources = (self.session.blizzard.skippedProtectedSources or 0) + skippedProtected
        if self.Debug then
            self:Debug("Skipped protected Blizzard meter sources: " .. tostring(skippedProtected))
        end
    end

    return applied
end
-- MCA 4.2.6: Mythic+ overall DPS/HPS helper, rebased from 4.1.8.
-- Keeps the original working ApplyBlizzardDamageMeterSources() logic untouched.
function MCA:IsCurrentSessionMythicPlusOverallMode()
    if not self.session then return false end
    local t = tostring(self.session.type or ""):lower()
    local m = tostring(self.session.mode or ""):lower()
    local d = tostring(self.session.difficulty or ""):lower()
    return t == "m+" or m:find("mythic%+") ~= nil or d:find("mythic%+") ~= nil or d:find("%+") ~= nil
end

function MCA:GetBestOverallBlizzardDamageMeterSession(meterType)
    if not meterType or not self:DamageMeterAvailable() then return nil, nil end

    local bestSession, bestID, bestDuration = nil, nil, -1

    for sessionID = 0, 30 do
        local data = self:GetBlizzardDamageMeterSession(sessionID, meterType)
        if type(data) == "table" and type(data.combatSources) == "table" and #data.combatSources > 0 then
            local duration = tonumber(data.durationSeconds or data.duration or 0) or 0
            if duration > bestDuration then
                bestSession = data
                bestID = sessionID
                bestDuration = duration
            end
        end
    end

    return bestSession, bestID
end

function MCA:CaptureMythicPlusOverallDamageHealing()
    -- MCA 4.2.7:
    -- Disabled temporarily. The Blizzard overall session can expose protected sources post-wipe.
    -- Keep stable encounter capture only until the meter API is mapped safely.
    return false
end
function MCA:CaptureDamageMeterStats()

    -- MCA 4.2.6 M+ overall first.
    -- For Mythic+, use overall key DPS/HPS instead of boss/encounter session.
    -- Raid keeps the original encounter-based behavior below.
    if self.CaptureMythicPlusOverallDamageHealing and self:CaptureMythicPlusOverallDamageHealing() then
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



-- ============================================================================
-- MCA 4.3.6 Mythic+ total key deaths
-- ============================================================================

function MCA:IsMythicPlusData(data)
    if not data then return false end
    local t = tostring(data.type or ""):lower()
    local m = tostring(data.mode or ""):lower()
    local d = tostring(data.difficulty or ""):lower()
    return t == "m+" or m:find("mythic%+") ~= nil or d:find("mythic%+") ~= nil or d:find("%+") ~= nil
end

function MCA:CalculateTotalDeaths(data)
    if not data then return 0 end

    local total = 0

    if type(data.players) == "table" then
        for _, p in pairs(data.players) do
            total = total + (tonumber(p.deaths or 0) or 0)
        end
    end

    if total == 0 and type(data.timeline) == "table" then
        for _, e in ipairs(data.timeline) do
            local eventType = tostring(e.type or ""):lower()
            local text = tostring(e.text or ""):lower()
            if eventType == "death" or text:find(" muore", 1, true) or text:find(" dies", 1, true) then
                total = total + 1
            end
        end
    end

    return total
end

function MCA:ApplyMythicPlusTotalDeaths(data)
    if not data or not self:IsMythicPlusData(data) then return end
    local total = self:CalculateTotalDeaths(data)
    data.totalDeaths = total
    data.deaths = total
    data.mplusDeathsTotal = total
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

    -- MCA 4.3.6 apply M+ total deaths before report
    if self.ApplyMythicPlusTotalDeaths then self:ApplyMythicPlusTotalDeaths(self.session) end
    local report = self:BuildReport(self.session)

    -- MCA 4.3.6 apply M+ total deaths after report
    if self.ApplyMythicPlusTotalDeaths then self:ApplyMythicPlusTotalDeaths(report) end

    -- MCA 4.3.5 late-joiner final rating pass
    if self.ApplyClassBasedRatings then self:ApplyClassBasedRatings(report) end

    -- MCA 4.3.4 final rating pass after report build
    if self.ApplyClassBasedRatings then self:ApplyClassBasedRatings(report) end

    -- MCA 4.3.3 strict meter rating after report build
    if self.ApplyClassBasedRatings then self:ApplyClassBasedRatings(report) end

    -- MCA 4.3.0 force class ratings after report build
    if self.ApplyClassBasedRatings then self:ApplyClassBasedRatings(report) end

    -- MCA 4.2.8: apply final class-only ratings after BuildReport
    if self.ApplyClassBasedRatings then self:ApplyClassBasedRatings(report) end

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
