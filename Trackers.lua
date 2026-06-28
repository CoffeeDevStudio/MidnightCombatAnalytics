_G.MCA = _G.MCA or {}
MCA = _G.MCA

function MCA:AddDefensiveToPlayer(player, spellID, time, source)
    if not player or not spellID then return false end

    local resolvedSpellID, fallbackName = self:ResolveDefensiveSpell(player.class, spellID)
    if not resolvedSpellID then return false end

    player.usedBySpell = player.usedBySpell or {}
    local key = tostring(resolvedSpellID)

    if player.usedBySpell[key] and math.abs((time or 0) - player.usedBySpell[key]) < 2 then
        return false
    end

    player.usedBySpell[key] = time or 0

    table.insert(player.used, {
        name = self:GetSpellNameSafe(resolvedSpellID, fallbackName),
        spellID = resolvedSpellID,
        icon = self:GetSpellIconSafe(resolvedSpellID),
        time = time or 0,
        source = source or "unknown"
    })

    self:AddTimelineEvent({
        type = "defensive",
        time = time or 0,
        player = player.name,
        text = (player.name or "?") .. " usa " .. fallbackName,
        spellID = resolvedSpellID
    })

    return true
end

function MCA:RecordDefensive(player, spellID, source)
    if not self.session then return end

    local t = GetTime() - self.session.start
    local added = self:AddDefensiveToPlayer(player, spellID, t, source)

    if added and player.name == UnitName("player") then
        self:SendDefensive(spellID, t)
    end
end

function MCA:UNIT_SPELLCAST_SUCCEEDED(unit, castGUID, spellID)
    if not self.session or not unit or not spellID then return end

    -- SafeFight:
    -- Track reliable local/player/visible unit casts only.
    -- Other players are reliably tracked through MCA sync if they have the addon.
    local name = UnitName(unit)
    if not name then return end

    local player = self.session.players and self.session.players[name]
    if not player then return end

    self:RecordDefensive(player, spellID, "cast")
end

function MCA:MarkDead(unit)
    if not self.session or not UnitExists(unit) or not UnitIsDeadOrGhost(unit) then return end

    local name = UnitName(unit)
    local player = name and self.session.players and self.session.players[name]

    if not player or player.deadSeen then return end

    player.deaths = (player.deaths or 0) + 1
    player.deadSeen = true
    player.deathTime = GetTime() - self.session.start

    self:AddTimelineEvent({
        type = "death",
        time = player.deathTime,
        player = name,
        text = name .. " muore"
    })

    if name == UnitName("player") then
        self:SendDeath(player.deathTime)
    end
end

function MCA:PLAYER_DEAD()
    self:MarkDead("player")
end

function MCA:UNIT_HEALTH(unit)
    if unit then
        self:MarkDead(unit)
    end
end

-- Compatibility no-op functions.
-- FinalizeSession calls these safely, but SafeFight deliberately does not scan auras/debuffs.
function MCA:ScanAllAuras()
end

function MCA:ScanAllDebuffs()
end

function MCA:UNIT_AURA(unit)
end

function MCA:TrackerOnUpdate(delta)
end
