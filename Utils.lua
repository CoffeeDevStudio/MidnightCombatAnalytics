_G.MCA = _G.MCA or {}
MCA = _G.MCA

function MCA:GetSpellNameSafe(spellID, fallback)
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, spellID)
        if ok and name then return name end
    end

    if GetSpellInfo then
        local ok, name = pcall(GetSpellInfo, spellID)
        if ok and name then return name end
    end

    return fallback or ("Spell " .. tostring(spellID))
end

function MCA:GetSpellIconSafe(spellID)
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, icon = pcall(C_Spell.GetSpellTexture, spellID)
        if ok and icon then return icon end
    end

    if GetSpellInfo then
        local ok, _, _, icon = pcall(GetSpellInfo, spellID)
        if ok and icon then return icon end
    end

    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function MCA:FormatTime(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    return string.format("%02d:%02d", m, s)
end

function MCA:GetUnitRole(unit)
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
    if role and role ~= "NONE" then return role end
    return "DAMAGER"
end

function MCA:GetPlayerIdentity()
    local name = UnitName("player")
    local _, class = UnitClass("player")
    local guid = UnitGUID("player")
    local role = self:GetUnitRole("player")
    return name, class, role, guid
end

function MCA:ResolveDefensiveSpell(class, spellID)
    if not class or not spellID then return nil, nil end

    local classDB = self.DefensiveDB and self.DefensiveDB[class]
    if not classDB then return nil, nil end

    -- Do not use classDB[spellID], because Retail/Midnight can pass secret spell keys.
    for knownSpellID, fallbackName in pairs(classDB) do
        local ok, match = pcall(function()
            return knownSpellID == spellID
        end)

        if ok and match then
            return knownSpellID, fallbackName
        end
    end

    return nil, nil
end

function MCA:AddTimelineEvent(event)
    if not self.session then return end
    self.session.timeline = self.session.timeline or {}
    table.insert(self.session.timeline, event)
end

function MCA:ShouldOpenReport(report)
    if not report then return false end
    if not MidnightCombatAnalyticsDB.config.autoOpen then return false end

    if report.type == "raid" then
        if report.result and MidnightCombatAnalyticsDB.config.showAfterKill then return true end
        if (not report.result) and MidnightCombatAnalyticsDB.config.showAfterWipe then return true end
        return false
    end

    if report.type == "M+" then
        return MidnightCombatAnalyticsDB.config.showMythicEnd
    end

    return true
end

function MCA:SafeOpenReport(report)
    if not self:ShouldOpenReport(report) then return end

    local function openReport()
        if MCA and MCA.ShowUI then
            MCA:ShowUI(report)
        end
    end

    if InCombatLockdown and InCombatLockdown() then
        local waitFrame = CreateFrame("Frame")
        waitFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        waitFrame:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            C_Timer.After(0.25, openReport)
        end)
    else
        C_Timer.After(0.5, openReport)
    end
end


-- ============================================================================
-- MCA 4.1.4 Class-based rating
-- Rating is normalized against the best player of the same class and same metric.
-- DPS/Tank compare DPS inside their class. Healers compare HPS inside their class.
-- ============================================================================

-- ============================================================================
-- MCA 4.1.7 Blizzard Interrupt helpers
-- ============================================================================

function MCA:GetInterruptValue(player)
    if not player then return 0 end
    return tonumber(player.blizzardInterrupts or player.interrupts or player.interruptCount or 0) or 0
end

function MCA:GetSortedInterruptPlayers(report)
    local list = {}
    if report and type(report.players) == "table" then
        for _, p in ipairs(report.players) do
            local value = self:GetInterruptValue(p)
            if value and value > 0 then
                table.insert(list, p)
            end
        end
    end

    table.sort(list, function(a, b)
        local av = self:GetInterruptValue(a)
        local bv = self:GetInterruptValue(b)
        if av == bv then
            return tostring(a.name or "") < tostring(b.name or "")
        end
        return av > bv
    end)

    return list
end

function MCA:CaptureBlizzardInterrupts(report, sessionID)
    if not report or not sessionID then return end
    if not C_DamageMeter or not Enum or not Enum.DamageMeterType or not Enum.DamageMeterType.Interrupts then return end
    if type(C_DamageMeter.GetCombatSessionFromID) ~= "function" then return end

    local ok, data = pcall(C_DamageMeter.GetCombatSessionFromID, sessionID, Enum.DamageMeterType.Interrupts)
    if not ok or type(data) ~= "table" or type(data.combatSources) ~= "table" then return end

    report.blizzardInterrupts = report.blizzardInterrupts or {}

    local byGuid = {}
    local byName = {}

    if type(report.players) == "table" then
        for _, p in ipairs(report.players) do
            if p.guid then byGuid[p.guid] = p end
            if p.name then byName[p.name] = p end
        end
    end

    for _, source in ipairs(data.combatSources) do
        local value = tonumber(source.totalAmount or source.amount or source.count or 0) or 0
        local guid = source.sourceGUID or source.guid or source.unitGUID
        local name = nil
        local okName, plainName = pcall(tostring, source.name)
        if okName then name = plainName end

        if value > 0 then
            report.blizzardInterrupts[guid or name or tostring(_)] = value

            local p = (guid and byGuid[guid]) or (name and byName[name])
            if p then
                p.blizzardInterrupts = value
            end
        end
    end
end


-- ============================================================================
-- MCA 4.2.8 Final class-only rating
-- Best player of each class gets 99. Others are scaled only against same class.
-- DPS/Tank use DPS. Healers use HPS. No spec grouping.
-- ============================================================================




-- ============================================================================
-- MCA 4.3.0 Forced class-only rating
-- This is the single source of truth for rating.
-- Best DPS/HPS of each class = 99. Missing/zero meter value = 0.
-- ============================================================================



-- ============================================================================
-- MCA 4.3.3 Strict meter-based rating helpers
-- Deaths do not affect rating. Missing DPS/HPS means rating 0.
-- ============================================================================

function MCA:IsRatingHealer(player)
    local role = tostring(player and (player.role or player.ruolo or player.Role or "") or ""):lower()
    return role:find("heal") ~= nil
end

function MCA:GetRawMeterValueForRating(player)
    if not player then return 0 end

    if self:IsRatingHealer(player) then
        return tonumber(player.blizzardHps or player.hps or player.fightHPS or player.healingPerSecond or 0) or 0
    end

    return tonumber(player.blizzardDps or player.dps or player.fightDPS or player.damagePerSecond or player.amountPerSecond or 0) or 0
end

function MCA:GetRatingClassKey(player)
    if not player then return "UNKNOWN" end
    return tostring(player.class or player.classFilename or player.className or player.localizedClass or "UNKNOWN"):upper()
end

function MCA:ApplyClassBasedRatings(report)
    if not report or type(report.players) ~= "table" then return end

    local maxDpsByClass = {}
    local maxHpsGlobal = 0

    for _, p in pairs(report.players) do
        local value = self:GetRawMeterValueForRating(p)
        if value and value > 0 then
            if self:IsRatingHealer(p) then
                if value > maxHpsGlobal then maxHpsGlobal = value end
            else
                local classKey = self:GetRatingClassKey(p)
                if not maxDpsByClass[classKey] or value > maxDpsByClass[classKey] then
                    maxDpsByClass[classKey] = value
                end
            end
        end
    end

    for _, p in pairs(report.players) do
        local value = self:GetRawMeterValueForRating(p)
        local rating = 0

        if value and value > 0 then
            local maxValue = 0
            if self:IsRatingHealer(p) then
                maxValue = maxHpsGlobal
            else
                maxValue = maxDpsByClass[self:GetRatingClassKey(p)] or 0
            end

            if maxValue and maxValue > 0 then
                rating = math.floor((value / maxValue) * 99 + 0.5)
                if rating < 1 then rating = 1 end
                if rating > 99 then rating = 99 end
            end
        end

        p.rating = rating
        p.score = rating
        p.classRating = rating
        p.ratingMode = self:IsRatingHealer(p) and "healer_global_4_3_3" or "dps_class_4_3_3"
    end
end

function MCA:GetDisplayRating(player)
    if not player then return 0 end

    local role = tostring(player.role or player.ruolo or player.Role or ""):lower()
    local value = 0

    if role:find("heal") then
        value = tonumber(player.blizzardHps or player.hps or player.fightHPS or player.healingPerSecond or 0) or 0
    else
        value = tonumber(player.blizzardDps or player.dps or player.fightDPS or player.damagePerSecond or player.amountPerSecond or 0) or 0
    end

    if value <= 0 then return 0 end
    return tonumber(player.classRating or player.rating or player.score or 0) or 0
end
function MCA:GetScore(player)
    return self:GetDisplayRating(player)
end
