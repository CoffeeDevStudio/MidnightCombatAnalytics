_G.MCA = _G.MCA or {}
MCA = _G.MCA

function MCA:BuildReport(session)
    return session
end

function MCA:GetScore(player)
    local score = 100

    if #(player.used or {}) == 0 then score = score - 25 end

    score = score - ((player.deaths or 0) * 30)

    if score < 0 then score = 0 end

    return score
end

function MCA:GetTotals(data)
    local deaths, cds, addon, players, debuffs = 0, 0, 0, 0, 0

    for _, p in pairs(data.players or {}) do
        players = players + 1
        deaths = deaths + (p.deaths or 0)
        cds = cds + #(p.used or {})
        debuffs = debuffs + #(p.debuffs or {})
        if p.hasAddon then addon = addon + 1 end
    end

    local bossKilled = 0
    for _, b in ipairs(data.bosses or {}) do
        if b.success then bossKilled = bossKilled + 1 end
    end

    local buffPresent, buffActive, buffMissing = self:GetRaidBuffSummary(data)

    return {
        players = players,
        deaths = deaths,
        cds = cds,
        addon = addon,
        debuffs = debuffs,
        buffPresent = buffPresent,
        buffActive = buffActive,
        buffMissing = buffMissing,
        bosses = #(data.bosses or {}),
        bossKilled = bossKilled
    }
end

function MCA:GetExportText(data)
    data = data or self.lastReport
    if not data then return "No MCA report." end

    local t = self:GetTotals(data)
    local lines = {
        "Midnight Combat Analytics v" .. self.VERSION,
        "Report: " .. (data.boss or "?"),
        "Type: " .. (data.type or "?"),
        "Duration: " .. self:FormatTime(data.duration or 0),
        "Players: " .. t.players .. " | MCA: " .. t.addon .. "/" .. t.players .. " | Deaths: " .. t.deaths .. " | Defensives: " .. t.cds .. " | Debuffs: " .. t.debuffs,
        ""
    }

    for _, p in pairs(data.players or {}) do
        local metric = self.GetFightMetric and self:GetFightMetric(p) or 0
        local metricName = ((p.role or "") == "HEALER") and "hps" or "dps"
        local rating = p.mcaRating or self:GetScore(p)
        table.insert(lines, "- " .. (p.name or "?") .. " " .. (p.class or "?") .. " deaths=" .. (p.deaths or 0) .. " " .. metricName .. "=" .. tostring(math.floor(metric or 0)) .. " rating=" .. tostring(rating))
    end

    return table.concat(lines, "\n")
end

function MCA:ShowExportWindow(data)
    self:Print(self:GetExportText(data or self.lastReport))
end

function MCA:ShareSummary(data)
    data = data or self.lastReport
    if not data then return end

    local channel = self:GetSyncChannel()
    local chatType = nil

    if channel == "RAID" then chatType = "RAID"
    elseif channel == "INSTANCE_CHAT" then chatType = "INSTANCE_CHAT"
    elseif channel == "PARTY" then chatType = "PARTY" end

    if not chatType then
        self:Print("Non sei in gruppo.")
        return
    end

    local t = self:GetTotals(data)

    SendChatMessage("[MCA] " .. (data.boss or "?") .. " - Deaths: " .. t.deaths .. " - Defensives: " .. t.cds .. " - MCA: " .. t.addon .. "/" .. t.players, chatType)
end
