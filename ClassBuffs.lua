_G.MCA = _G.MCA or {}
MCA = _G.MCA


MCA.BlessingOfTheBronzeByClass = {
    DEATHKNIGHT = 381732,
    DEMONHUNTER = 381741,
    DRUID = 381746,
    EVOKER = 381748,
    HUNTER = 381749,
    MAGE = 381750,
    MONK = 381751,
    PALADIN = 381753,
    PRIEST = 381754,
    ROGUE = 381755,
    SHAMAN = 381757,
    WARLOCK = 381759,
    WARRIOR = 381762
}

MCA.ClassBuffDB = {
    -- Real raid/player buffs, shown only if source class is present.
    {
        key = "arcane_intellect",
        class = "MAGE",
        spellID = 1459,
        name = "Arcane Intellect",
        short = "Int",
        kind = "class"
    },
    {
        key = "power_word_fortitude",
        class = "PRIEST",
        spellID = 21562,
        name = "Power Word: Fortitude",
        short = "Fort",
        kind = "class"
    },
    {
        key = "mark_of_the_wild",
        class = "DRUID",
        spellID = 1126,
        name = "Mark of the Wild",
        short = "Mark",
        kind = "class"
    },
    {
        key = "battle_shout",
        class = "WARRIOR",
        spellID = 6673,
        name = "Battle Shout",
        short = "BS",
        kind = "class"
    },
    {
        key = "blessing_of_the_bronze",
        class = "EVOKER",
        spellID = 381750,
        name = "Blessing of the Bronze",
        short = "Bronze",
        kind = "class",
        classSpecific = true
    },
    {
        key = "skyfury",
        class = "SHAMAN",
        spellID = 462854,
        name = "Skyfury",
        short = "Sky",
        kind = "class"
    },

    -- Consumables.
    {
        key = "well_fed",
        class = nil,
        spellID = nil,
        icon = "Interface\\Icons\\INV_Misc_Food_15",
        name = "Well Fed",
        short = "Food",
        kind = "consumable",
        patterns = {
            "Well Fed",
            "Ben Nutrito",
            "Ben nutrita"
        }
    },
    {
        key = "flask_phial",
        class = nil,
        spellID = nil,
        icon = "Interface\\Icons\\INV_Alchemy_Elixir_05",
        name = "Flask / Phial",
        short = "Flask",
        kind = "consumable",
        patterns = {
            "Flask",
            "Phial",
            "Fiala",
            "Ampolla"
        }
    },
    {
        key = "augment_rune",
        class = nil,
        spellID = nil,
        icon = "Interface\\Icons\\INV_Misc_Rune_10",
        name = "Augment Rune",
        short = "Rune",
        kind = "consumable",
        optional = true,
        patterns = {
            "Augment Rune",
            "Crystallized Augment Rune",
            "Draconic Augment Rune",
            "Runa del Potenziamento"
        }
    }
}

function MCA:GroupUnits()
    local units = {}

    if IsInRaid and IsInRaid() then
        local count = GetNumGroupMembers and GetNumGroupMembers() or 0
        for i = 1, count do
            table.insert(units, "raid" .. i)
        end
    elseif IsInGroup and IsInGroup() then
        table.insert(units, "player")
        local count = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
        for i = 1, count do
            table.insert(units, "party" .. i)
        end
    else
        table.insert(units, "player")
    end

    return units
end

function MCA:RaidHasClass(class)
    if not class then return true end

    for _, unit in ipairs(self:GroupUnits()) do
        if UnitExists and UnitExists(unit) then
            local _, unitClass = UnitClass(unit)
            if unitClass == class then
                return true
            end
        end
    end

    return false
end

function MCA:AuraNameMatches(name, patterns)
    if not name or not patterns then return false end

    local okName, auraName = pcall(function()
        return tostring(name)
    end)

    if not okName or not auraName or auraName == "" then
        return false
    end

    auraName = string.lower(auraName)

    for _, pattern in ipairs(patterns) do
        local okPattern, patternText = pcall(function()
            return tostring(pattern)
        end)

        if okPattern and patternText and patternText ~= "" then
            patternText = string.lower(patternText)
            local okFind, found = pcall(function()
                return string.find(auraName, patternText, 1, true)
            end)

            if okFind and found then
                return true
            end
        end
    end

    return false
end

function MCA:GetAuraDataSafe(unit, index)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, "HELPFUL")
        if ok then return aura end
        return nil
    end

    if UnitBuff then
        local ok, name, icon, count, dispelType, duration, expirationTime, source, isStealable, nameplateShowPersonal, spellID = pcall(UnitBuff, unit, index)
        if ok and name then
            return {
                name = name,
                icon = icon,
                spellId = spellID
            }
        end
    end

    return nil
end

function MCA:BuffMatchesAura(buff, aura, unitClass)
    if not buff or not aura then return false end

    local auraSpellID = aura.spellId or aura.spellID

    if buff.classSpecific and buff.key == "blessing_of_the_bronze" then
        local expected = unitClass and self.BlessingOfTheBronzeByClass and self.BlessingOfTheBronzeByClass[unitClass]
        if expected and auraSpellID and tonumber(auraSpellID) == tonumber(expected) then
            return true
        end
    end

    if buff.spellID and auraSpellID then
        local ok, match = pcall(function()
            return tonumber(auraSpellID) == tonumber(buff.spellID)
        end)

        if ok and match then return true end
    end

    -- Retail/Midnight may return secret strings for aura.name.
    -- Name matching is only a fallback and must never error.
    if aura.name and buff.patterns then
        local ok, matched = pcall(function()
            return self:AuraNameMatches(aura.name, buff.patterns)
        end)

        if ok and matched then
            return true
        end
    end

    return false
end

function MCA:UnitHasChecklistBuff(unit, buff)
    if not unit or not buff then return false end
    if not UnitExists or not UnitExists(unit) then return false end

    local _, unitClass = UnitClass(unit)

    for i = 1, 40 do
        local aura = self:GetAuraDataSafe(unit, i)
        if not aura then break end

        if self:BuffMatchesAura(buff, aura, unitClass) then
            return true
        end
    end

    return false
end

function MCA:GetBuffIcon(buff)
    if not buff then return "Interface\\Icons\\INV_Misc_QuestionMark" end

    if buff.icon then return buff.icon end
    if buff.spellID and self.GetSpellIconSafe then
        return self:GetSpellIconSafe(buff.spellID)
    end

    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function MCA:IsChecklistBuffRequired(buff)
    if not buff then return false end
    if buff.kind == "consumable" then return true end
    return self:RaidHasClass(buff.class)
end

function MCA:CaptureRaidBuffs()
    local buffs = {}
    local matrix = {
        buffs = {},
        players = {}
    }

    local totalByBuff = {}
    local missingByBuff = {}

    for _, buff in ipairs(self.ClassBuffDB or {}) do
        local required = self:IsChecklistBuffRequired(buff)

        local cleanBuff = {
            key = buff.key,
            class = buff.class,
            spellID = buff.spellID,
            name = buff.spellID and self:GetSpellNameSafe(buff.spellID, buff.name) or buff.name,
            short = buff.short or buff.name,
            icon = self:GetBuffIcon(buff),
            classPresent = required,
            kind = buff.kind,
            optional = buff.optional and true or false,
            total = 0,
            missing = 0,
            active = false
        }

        table.insert(buffs, cleanBuff)
        table.insert(matrix.buffs, cleanBuff)
    end

    for _, unit in ipairs(self:GroupUnits()) do
        if UnitExists and UnitExists(unit) and (not UnitIsConnected or UnitIsConnected(unit)) then
            local name = UnitName(unit)
            local _, class = UnitClass(unit)
            local role = self.GetUnitRole and self:GetUnitRole(unit) or "DAMAGER"

            local row = {
                name = name or unit,
                class = class or "UNKNOWN",
                role = role or "DAMAGER",
                unit = unit,
                buffs = {}
            }

            for _, buff in ipairs(self.ClassBuffDB or {}) do
                local required = self:IsChecklistBuffRequired(buff)

                if required then
                    local hasBuff = self:UnitHasChecklistBuff(unit, buff)
                    row.buffs[buff.key] = hasBuff and true or false

                    if not buff.optional then
                        totalByBuff[buff.key] = (totalByBuff[buff.key] or 0) + 1

                        if not hasBuff then
                            missingByBuff[buff.key] = (missingByBuff[buff.key] or 0) + 1
                        end
                    end
                else
                    row.buffs[buff.key] = nil
                end
            end

            table.insert(matrix.players, row)
        end
    end

    for _, buff in ipairs(buffs) do
        buff.total = totalByBuff[buff.key] or 0
        buff.missing = missingByBuff[buff.key] or 0

        if buff.optional then
            buff.active = true
        else
            buff.active = buff.classPresent and buff.total > 0 and buff.missing == 0
        end
    end

    return buffs, matrix
end

function MCA:GetRaidBuffSummary(data)
    local present, active, missing = 0, 0, 0

    for _, buff in ipairs((data and data.raidBuffs) or {}) do
        if buff.classPresent and not buff.optional then
            present = present + 1

            if buff.active then
                active = active + 1
            else
                missing = missing + 1
            end
        end
    end

    return present, active, missing
end

function MCA:BuildRaidBuffRows(data)
    return {}
end
