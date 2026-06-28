_G.MCA = _G.MCA or {}
MCA = _G.MCA

function MCA:InitSync()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(self.PREFIX)
    end
end

function MCA:GetSyncChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
    return nil
end

function MCA:SendAddon(msg)
    self:SendAddonMulti(msg)
end


function MCA:SendAddonMulti(msg)
    if not MidnightCombatAnalyticsDB.config.syncEnabled then return end
    if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then return end

    local sent = {}

    local function send(channel)
        if channel and not sent[channel] then
            sent[channel] = true
            C_ChatInfo.SendAddonMessage(self.PREFIX, msg, channel)
        end
    end

    if IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        send("INSTANCE_CHAT")
    end

    if IsInRaid and IsInRaid() then
        send("RAID")
    elseif IsInGroup and IsInGroup() then
        send("PARTY")
    end
end

function MCA:SendHello()
    local name, class, role, guid = self:GetPlayerIdentity()
    if not name then return end

    self:SendAddon(table.concat({
        "HELLO",
        self.VERSION,
        name,
        class or "",
        role or "",
        guid or ""
    }, "|"))
end

function MCA:SendDefensive(spellID, time)
    local name, class, role, guid = self:GetPlayerIdentity()
    if not name or not spellID then return end

    self:SendAddon(table.concat({
        "DEF",
        name,
        class or "",
        role or "",
        guid or "",
        tostring(spellID),
        tostring(time or 0)
    }, "|"))
end

function MCA:SendDeath(time)
    local name, class, role, guid = self:GetPlayerIdentity()
    if not name then return end

    self:SendAddon(table.concat({
        "DEATH",
        name,
        class or "",
        role or "",
        guid or "",
        tostring(time or 0)
    }, "|"))
end

function MCA:SplitMessage(msg)
    local parts = {}
    msg = tostring(msg or "")

    local start = 1
    while true do
        local sep = string.find(msg, "|", start, true)
        if not sep then
            table.insert(parts, string.sub(msg, start))
            break
        end

        table.insert(parts, string.sub(msg, start, sep - 1))
        start = sep + 1
    end

    return parts
end

function MCA:CHAT_MSG_ADDON(prefix, msg)
    if prefix ~= self.PREFIX then return end

    local parts = self:SplitMessage(msg)
    local kind = parts[1]

    if kind == "RSTART" or kind == "RDEF" or kind == "RDEATH" or kind == "REND" then
        if self.HandleReportSyncMessage then self:HandleReportSyncMessage(kind, parts) end
        return
    end

    if kind == "HELLO" then
        local version = parts[2]
        local name = parts[3]
        local class = parts[4]
        local role = parts[5]
        local guid = parts[6]

        if name and self.roster[name] then
            self.roster[name].hasAddon = true
            self.roster[name].version = version
        end

        if self.session then
            local p = self:EnsureSessionPlayer(name, class, role, guid)
            if p then p.version = version end
        end

        return
    end

    if not self.session then return end

    if kind == "DEF" then
        local p = self:EnsureSessionPlayer(parts[2], parts[3], parts[4], parts[5])
        if p then
            self:AddDefensiveToPlayer(p, tonumber(parts[6]), tonumber(parts[7]) or 0, "sync")
        end
        return
    end

    if kind == "DEATH" then
        local p = self:EnsureSessionPlayer(parts[2], parts[3], parts[4], parts[5])
        if p and not p.deadSeen then
            p.deaths = (p.deaths or 0) + 1
            p.deadSeen = true
            p.deathTime = tonumber(parts[6]) or 0
            self:AddTimelineEvent({
                type = "death",
                time = p.deathTime,
                player = p.name,
                text = p.name .. " muore"
            })
        end
    end
end


-- Report Sync v4.0.12
-- Sends compact player-owned report events at the end of a pull/key and merges data received from party/raid members.
function MCA:GetReportSyncID(data)
    data = data or self.session or self.lastReport or {}
    local boss = tostring(data.boss or "?"):gsub("|", "/")
    local started = tostring(math.floor(data.savedAtEpoch or data.start or 0))
    return boss .. "@" .. started
end

function MCA:GetReportMergeTarget(syncID, bossName)
    if self.session then return self.session end
    if self.lastReport then
        if not bossName or self.lastReport.boss == bossName or (self.lastReport.boss and bossName and tostring(self.lastReport.boss):lower() == tostring(bossName):lower()) then
            return self.lastReport
        end
        return self.lastReport
    end

    if MidnightCombatAnalyticsDB and MidnightCombatAnalyticsDB.history then
        for i = #MidnightCombatAnalyticsDB.history, 1, -1 do
            local r = MidnightCombatAnalyticsDB.history[i]
            if r and ((bossName and r.boss == bossName) or (syncID and self:GetReportSyncID(r) == syncID)) then
                self.lastReport = r
                return r
            end
        end
    end

    return nil
end

function MCA:EnsureReportPlayer(data, name, class, role, guid)
    if not data or not name then return nil end

    data.players = data.players or {}

    if not data.players[name] then
        data.players[name] = self:CreateEmptyPlayer(name, class, role, guid, nil)
        data.players[name].hasAddon = true
        data.players[name].synced = true
    else
        local p = data.players[name]
        p.class = class or p.class
        p.role = role or p.role
        p.guid = guid or p.guid
        p.hasAddon = true
        p.synced = true
        p.used = p.used or {}
        p.usedBySpell = p.usedBySpell or {}
        p.debuffs = p.debuffs or {}
    end

    return data.players[name]
end

function MCA:AddReportTimelineEvent(data, event)
    if not data or not event then return end

    data.timeline = data.timeline or {}

    local key = tostring(event.type or "") .. ":" .. tostring(event.player or "") .. ":" .. tostring(event.spellID or "") .. ":" .. tostring(math.floor((event.time or 0) * 10))

    data._syncTimelineSeen = data._syncTimelineSeen or {}
    if data._syncTimelineSeen[key] then return end
    data._syncTimelineSeen[key] = true

    for _, e in ipairs(data.timeline) do
        local existingKey = tostring(e.type or "") .. ":" .. tostring(e.player or "") .. ":" .. tostring(e.spellID or "") .. ":" .. tostring(math.floor((e.time or 0) * 10))
        if existingKey == key then return end
    end

    table.insert(data.timeline, event)
    table.sort(data.timeline, function(a, b) return (a.time or 0) < (b.time or 0) end)
end

function MCA:AddSyncedDefensiveToReport(data, name, class, role, guid, spellID, t)
    local p = self:EnsureReportPlayer(data, name, class, role, guid)
    if not p or not spellID then return end

    local resolvedSpellID, fallbackName = self:ResolveDefensiveSpell(p.class, spellID)
    if not resolvedSpellID then return end

    p.used = p.used or {}
    p.usedBySpell = p.usedBySpell or {}

    local key = tostring(resolvedSpellID) .. ":" .. tostring(math.floor((tonumber(t) or 0) * 10))
    p._syncUsedSeen = p._syncUsedSeen or {}

    if p._syncUsedSeen[key] then return end

    for _, u in ipairs(p.used) do
        if tonumber(u.spellID) == tonumber(resolvedSpellID) and math.abs((tonumber(u.time) or 0) - (tonumber(t) or 0)) < 1.5 then
            p._syncUsedSeen[key] = true
            return
        end
    end

    p._syncUsedSeen[key] = true
    p.usedBySpell[tostring(resolvedSpellID)] = tonumber(t) or 0

    table.insert(p.used, {
        name = self:GetSpellNameSafe(resolvedSpellID, fallbackName),
        spellID = resolvedSpellID,
        icon = self:GetSpellIconSafe(resolvedSpellID),
        time = tonumber(t) or 0,
        source = "sync-report"
    })

    self:AddReportTimelineEvent(data, {
        type = "defensive",
        time = tonumber(t) or 0,
        player = p.name,
        text = (p.name or "?") .. " usa " .. (self:GetSpellNameSafe(resolvedSpellID, fallbackName) or fallbackName or tostring(resolvedSpellID)),
        spellID = resolvedSpellID
    })
end

function MCA:AddSyncedDeathToReport(data, name, class, role, guid, t)
    local p = self:EnsureReportPlayer(data, name, class, role, guid)
    if not p then return end

    p.deaths = math.max(tonumber(p.deaths) or 0, 1)
    p.deadSeen = true
    p.deathTime = tonumber(t) or p.deathTime or 0

    self:AddReportTimelineEvent(data, {
        type = "death",
        time = p.deathTime or 0,
        player = p.name,
        text = (p.name or "?") .. " muore"
    })
end

function MCA:SendReportSnapshot(report)
    if not report or not MidnightCombatAnalyticsDB.config.syncEnabled then return end

    local myName, myClass, myRole, myGuid = self:GetPlayerIdentity()
    if not myName then return end

    local p = report.players and report.players[myName]
    if not p then return end

    local syncID = self:GetReportSyncID(report)
    local boss = tostring(report.boss or "?"):gsub("|", "/")

    self:SendAddon(table.concat({"RSTART", syncID, boss, myName, myClass or "", myRole or "", myGuid or ""}, "|"))

    for _, u in ipairs(p.used or {}) do
        if u.spellID then
            self:SendAddon(table.concat({
                "RDEF",
                syncID,
                boss,
                myName,
                myClass or p.class or "",
                myRole or p.role or "",
                myGuid or p.guid or "",
                tostring(u.spellID),
                tostring(u.time or 0)
            }, "|"))
        end
    end

    if (p.deaths or 0) > 0 then
        self:SendAddon(table.concat({
            "RDEATH",
            syncID,
            boss,
            myName,
            myClass or p.class or "",
            myRole or p.role or "",
            myGuid or p.guid or "",
            tostring(p.deathTime or 0)
        }, "|"))
    end

    self:SendAddon(table.concat({"REND", syncID, boss, myName}, "|"))
end

function MCA:HandleReportSyncMessage(kind, parts)
    local syncID = parts[2]
    local boss = parts[3]
    local name = parts[4]
    local class = parts[5]
    local role = parts[6]
    local guid = parts[7]

    if not name or name == UnitName("player") then return true end

    local data = self:GetReportMergeTarget(syncID, boss)
    if not data then return true end

    if kind == "RSTART" then
        self:EnsureReportPlayer(data, name, class, role, guid)
        return true
    end

    if kind == "RDEF" then
        local spellID = tonumber(parts[8])
        local t = tonumber(parts[9]) or 0

        -- Backward compatibility with clients affected by empty-field parsing.
        if not spellID and tonumber(parts[7]) then
            spellID = tonumber(parts[7])
            t = tonumber(parts[8]) or 0
            guid = ""
        end

        self:AddSyncedDefensiveToReport(data, name, class, role, guid, spellID, t)
        if self.lastReport == data and _G.MCAFrame and _G.MCAFrame:IsShown() then
            self._syncNeedsRefresh = true
            C_Timer.After(0.3, function()
                if MCA and MCA._syncNeedsRefresh and _G.MCAFrame and _G.MCAFrame:IsShown() then
                    MCA._syncNeedsRefresh = false
                    MCA:BuildDashboard(data)
                end
            end)
        end
        return true
    end

    if kind == "RDEATH" then
        local t = tonumber(parts[8]) or 0
        if t == 0 and tonumber(parts[7]) then
            t = tonumber(parts[7]) or 0
            guid = ""
        end
        self:AddSyncedDeathToReport(data, name, class, role, guid, t)
        if self.lastReport == data and _G.MCAFrame and _G.MCAFrame:IsShown() then
            self._syncNeedsRefresh = true
            C_Timer.After(0.3, function()
                if MCA and MCA._syncNeedsRefresh and _G.MCAFrame and _G.MCAFrame:IsShown() then
                    MCA._syncNeedsRefresh = false
                    MCA:BuildDashboard(data)
                end
            end)
        end
        return true
    end

    if kind == "REND" then
        if self.lastReport == data and self.MainFrame and self.MainFrame:IsShown() then
            -- Light refresh: redraw current report only if the report window is already open.
            self:BuildDashboard(data)
        end
        return true
    end

    return false
end
