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
