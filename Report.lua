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

    -- Build the same player data the DPS/Tank and Healer tables show, then
    -- post it grouped by role: Tank first, then DPS, then Healer.
    local players = self:BuildPlayerList(data)
    if self.CalculateRoleRatings then self:CalculateRoleRatings(players) end

    local function roleKey(p)
        local r = (p.role or ""):upper()
        if r == "TANK" then return 1 end
        if r == "HEALER" then return 3 end
        return 2 -- DPS / everything else
    end

    -- Stable sort: by role bucket, then by metric descending within the bucket.
    table.sort(players, function(a, b)
        local ra, rb = roleKey(a), roleKey(b)
        if ra ~= rb then return ra < rb end
        return (self:GetFightMetric(a) or 0) > (self:GetFightMetric(b) or 0)
    end)

    local t = self:GetTotals(data)
    SendChatMessage("[MCA] " .. (data.boss or "?") .. " - Durata: " .. self:FormatTime(data.duration or 0) .. " - Deaths: " .. t.deaths, chatType)

    local roleTitles = { [1] = "== TANK ==", [2] = "== DPS ==", [3] = "== HEALER ==" }
    local lastRole = nil

    for _, p in ipairs(players) do
        local rk = roleKey(p)
        if rk ~= lastRole then
            SendChatMessage(roleTitles[rk], chatType)
            lastRole = rk
        end

        local metricLabel = (rk == 3) and "HPS" or "DPS"
        local metric = self:FormatMetricValue(self:GetFightMetric(p))
        local _, _, parseText = self:ResolvePlayerParse(p, data)

        SendChatMessage(string.format("%s (%s) - %s: %s - Parse: %s",
            p.name or "?", self:PrettyClass(p.class), metricLabel, metric, parseText), chatType)
    end
end
