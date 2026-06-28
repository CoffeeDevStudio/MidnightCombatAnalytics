_G.MCA = _G.MCA or {}
MCA = _G.MCA

MCA.ClassIconCoords = {
    WARRIOR={0,0.25,0,0.25}, MAGE={0.25,0.5,0,0.25}, ROGUE={0.5,0.75,0,0.25}, DRUID={0.75,1,0,0.25},
    HUNTER={0,0.25,0.25,0.5}, SHAMAN={0.25,0.5,0.25,0.5}, PRIEST={0.5,0.75,0.25,0.5}, WARLOCK={0.75,1,0.25,0.5},
    PALADIN={0,0.25,0.5,0.75}, DEATHKNIGHT={0.25,0.5,0.5,0.75}, MONK={0.5,0.75,0.5,0.75}, DEMONHUNTER={0.75,1,0.5,0.75}, EVOKER={0,0.25,0.75,1}
}

MCA.RoleLabel = {
    TANK = "Tank",
    HEALER = "Healer",
    DAMAGER = "DPS",
    NONE = "DPS"
}

function MCA:UIColor(name)
    local colors = {
        bg = {0.015,0.018,0.020,0.92},
        panel = {0.025,0.028,0.030,0.88},
        panel2 = {0.035,0.038,0.042,0.90},
        row = {0.07,0.075,0.08,0.50},
        rowAlt = {0.10,0.105,0.11,0.50},
        border = {0.22,0.24,0.26,0.90},
        accent = {1.0,0.82,0.00,1},
        purple = {0.78,0.25,1.0,1},
        green = {0.20,1.0,0.20,1},
        red = {1.0,0.18,0.18,1},
        orange = {1.0,0.55,0.0,1},
        blue = {0.30,0.65,1.0,1},
        gray = {0.68,0.68,0.68,1},
        white = {0.92,0.92,0.92,1}
    }
    return colors[name] or colors.white
end

function MCA:SetBackdropSolid(frame, bg, border)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1
    })
    local b = bg or self:UIColor("panel")
    local e = border or self:UIColor("border")
    frame:SetBackdropColor(b[1],b[2],b[3],b[4] or 1)
    frame:SetBackdropBorderColor(e[1],e[2],e[3],e[4] or 1)
end

function MCA:Text(parent, text, font, point, width, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    fs:SetPoint(unpack(point))
    if width then fs:SetWidth(width) end
    fs:SetJustifyH(justify or "LEFT")
    fs:SetText(text or "")
    if color then fs:SetTextColor(color[1], color[2], color[3], color[4] or 1) end
    return fs
end

function MCA:Panel(parent, point, w, h, bg)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetPoint(unpack(point))
    f:SetSize(w,h)
    self:SetBackdropSolid(f, bg or self:UIColor("panel"), self:UIColor("border"))
    return f
end

function MCA:Button(parent, text, point, w, h, fn, danger)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetPoint(unpack(point))
    b:SetSize(w,h)
    local bg = danger and {0.18,0.03,0.03,0.88} or {0.06,0.055,0.025,0.88}
    local br = danger and {0.65,0.12,0.12,1} or {0.45,0.35,0.02,1}
    self:SetBackdropSolid(b, bg, br)
    self:Text(b, text, "GameFontNormal", {"CENTER", b, "CENTER", 0, 0}, w-8, danger and {1,0.55,0.55,1} or self:UIColor("accent"), "CENTER")
    b:SetScript("OnClick", fn or function() end)
    b:SetScript("OnEnter", function()
        b:SetBackdropBorderColor(1,0.82,0,1)
    end)
    b:SetScript("OnLeave", function()
        b:SetBackdropBorderColor(br[1],br[2],br[3],br[4] or 1)
    end)
    return b
end



function MCA:Scroll(parent, point, w, h, bg)
    local outer = self:Panel(parent, point, w, h, bg)
    local scroll = CreateFrame("ScrollFrame", nil, outer, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", -4, 4)

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(w - 10, h - 8)
    scroll:SetScrollChild(child)

    scroll.mdrOuterWidth = w
    scroll.mdrOuterHeight = h
    scroll.mdrChild = child

    if scroll.ScrollBar then
        self:ApplyScrollBarStyle(scroll.ScrollBar)
        scroll.ScrollBar:Hide()
    end

    scroll:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = self:GetVerticalScrollRange()
        if maxScroll <= 0 then return end
        local current = self:GetVerticalScroll()
        local step = 45
        if delta < 0 then
            self:SetVerticalScroll(math.min(current + step, maxScroll))
        else
            self:SetVerticalScroll(math.max(current - step, 0))
        end
    end)

    return outer, child, scroll
end

function MCA:UpdateScrollBar(child, scroll, neededHeight)
    if not child then return end

    local parentHeight = 1
    if child:GetParent() and child:GetParent().GetHeight then
        parentHeight = child:GetParent():GetHeight() or 1
    end

    local height = math.max(neededHeight or 1, parentHeight)
    child:SetHeight(height)

    if scroll and scroll.ScrollBar then
        C_Timer.After(0, function()
            if not scroll or not scroll.GetVerticalScrollRange then return end
            local needsScroll = scroll:GetVerticalScrollRange() and scroll:GetVerticalScrollRange() > 1
            if needsScroll then
                scroll.ScrollBar:Show()
                scroll:SetPoint("BOTTOMRIGHT", -24, 4)
                if scroll.mdrChild then scroll.mdrChild:SetWidth((scroll.mdrOuterWidth or 100) - 34) end
            else
                scroll.ScrollBar:Hide()
                scroll:SetPoint("BOTTOMRIGHT", -4, 4)
                if scroll.mdrChild then scroll.mdrChild:SetWidth((scroll.mdrOuterWidth or 100) - 10) end
            end
        end)
    end
end

function MCA:GetInnerWidth(parent, fallback)
    if parent and parent.GetWidth then
        return math.max((parent:GetWidth() or fallback or 100) - 12, 50)
    end
    return fallback or 100
end

function MCA:ClassIcon(parent, class, x, y, size)
    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", x, y)
    icon:SetSize(size, size)
    icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")

    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class or ""]

    if coords then
        icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        return icon
    end

    local c = self.ClassIconCoords[class or ""]
    if c then
        icon:SetTexCoord(c[1], c[2], c[3], c[4])
    else
        icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        icon:SetTexCoord(0,1,0,1)
    end

    return icon
end

function MCA:SpellIcon(parent, spellID, x, y, size, label)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", x, y)
    f:SetSize(size, size + (label and 12 or 0))
    f:EnableMouse(true)
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(size,size)
    icon:SetPoint("TOPLEFT",0,0)
    icon:SetTexture(self:GetSpellIconSafe(spellID))
    if label then
        local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOP", icon, "BOTTOM", 0, -1)
        fs:SetWidth(size+24)
        fs:SetJustifyH("CENTER")
        fs:SetText(label)
    end
    f:SetScript("OnEnter", function()
        GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
        if spellID then pcall(GameTooltip.SetSpellByID, GameTooltip, spellID) end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return f
end

function MCA:StatusForScore(score)
    if score >= 90 then return "Ottimo", self:UIColor("green") end
    if score >= 75 then return "Buono", self:UIColor("accent") end
    if score >= 55 then return "Discreto", self:UIColor("orange") end
    return "Critico", self:UIColor("red")
end

function MCA:RoleShort(role)
    return self.RoleLabel[role or "DAMAGER"] or role or "DPS"
end

function MCA:BuildPlayerList(data)
    local list = {}
    for _, p in pairs(data.players or {}) do
        table.insert(list,p)
    end
    table.sort(list, function(a,b)
        local sa, sb = MCA:GetScore(a), MCA:GetScore(b)
        if sa == sb then return (a.name or "") < (b.name or "") end
        return sa > sb
    end)
    return list
end

function MCA:GetPlayerDefensivesInWindow(player, startTime, endTime)
    local result = {}
    for _, u in ipairs(player.used or {}) do
        if (u.time or 0) >= (startTime or 0) and (u.time or 0) <= (endTime or 0) then
            table.insert(result,u)
        end
    end
    return result
end

function MCA:GetWindows(data)
    local windows = {}
    if data.type == "M+" then
        for _, boss in ipairs(data.bosses or {}) do table.insert(windows,boss) end
    else
        table.insert(windows,{name=data.boss or "Encounter", startTime=0, endTime=data.duration or 0, success=data.result, duration=data.duration or 0})
    end
    return windows
end

function MCA:CountDeathsInWindow(data, startTime, endTime)
    local count = 0
    for _, p in pairs(data.players or {}) do
        if p.deathTime and p.deathTime >= (startTime or 0) and p.deathTime <= (endTime or 0) then
            count = count + (p.deaths or 1)
        end
    end
    return count
end

function MCA:CountCDsInWindow(data, startTime, endTime)
    local count = 0
    for _, p in pairs(data.players or {}) do
        for _, u in ipairs(p.used or {}) do
            if (u.time or 0) >= (startTime or 0) and (u.time or 0) <= (endTime or 0) then
                count = count + 1
            end
        end
    end
    return count
end

function MCA:MainFrame()
    local old = _G.MCAFrame
    if old then old:Hide(); old:SetParent(nil); _G.MCAFrame = nil end

    local f = CreateFrame("Frame", "MCAFrame", UIParent, "BackdropTemplate")
    f:SetSize(1320, 780)

    if UISpecialFrames then
        local found = false
        for _, frameName in ipairs(UISpecialFrames) do
            if frameName == "MCAFrame" then found = true break end
        end
        if not found then table.insert(UISpecialFrames, "MCAFrame") end
    end

    f:EnableKeyboard(true)
    if f.SetPropagateKeyboardInput then f:SetPropagateKeyboardInput(true) end
    f:SetScript("OnKeyDown", function(frame, key)
        if key == "ESCAPE" then
            if MCA.MinimapMenu and MCA.MinimapMenu:IsShown() then MCA.MinimapMenu:Hide() end
            frame:Hide()
            if frame.SetPropagateKeyboardInput then frame:SetPropagateKeyboardInput(false) end
        elseif frame.SetPropagateKeyboardInput then
            frame:SetPropagateKeyboardInput(true)
        end
    end)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(100)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    self:SetBackdropSolid(f, self:UIColor("bg"), {0.28,0.28,0.30,1})

    self:Text(f, "Midnight Combat Analytics v"..(self.VERSION or "?"), "GameFontHighlightLarge", {"TOP", f, "TOP", 0, -10}, 460, self:UIColor("accent"), "CENTER")
    self:Text(f, "✦  •••  ×", "GameFontNormalLarge", {"TOPRIGHT", f, "TOPRIGHT", -18, -11}, 90, self:UIColor("gray"), "RIGHT")

    return f
end


function MCA:SmallTexture(parent, texture, point, size, vertexColor)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetPoint(unpack(point))
    t:SetSize(size or 16, size or 16)
    t:SetTexture(texture)
    if vertexColor then
        t:SetVertexColor(vertexColor[1], vertexColor[2], vertexColor[3], vertexColor[4] or 1)
    end
    return t
end

function MCA:StatusTexture(parent, point, status)
    local color = self:UIColor("green")
    local texture = "Interface\\Buttons\\UI-CheckBox-Check"

    if status == "Critico" or status == "Crit" then
        texture = "Interface\\RaidFrame\\ReadyCheck-NotReady"
        color = self:UIColor("red")
    elseif status == "Discreto" or status == "Watch" then
        texture = "Interface\\COMMON\\Indicator-Yellow"
        color = self:UIColor("orange")
    elseif status == "Buono" or status == "Good" or status == "Ottimo" or status == "OK" then
        texture = "Interface\\Buttons\\UI-CheckBox-Check"
        color = self:UIColor("green")
    end

    return self:SmallTexture(parent, texture, point, 14, color)
end

function MCA:SuccessTexture(parent, point, success)
    if success then
        return self:SmallTexture(parent, "Interface\\Buttons\\UI-CheckBox-Check", point, 14, self:UIColor("green"))
    end
    return self:SmallTexture(parent, "Interface\\RaidFrame\\ReadyCheck-NotReady", point, 14, self:UIColor("red"))
end

function MCA:DrawSidebar(root)
    local side = self:Panel(root, {"TOPLEFT", root, "TOPLEFT", 8, -8}, 138, 702, {0.012,0.017,0.022,0.96})

    -- Emblem placeholder
    local emblem = side:CreateTexture(nil, "ARTWORK")
    emblem:SetPoint("TOPLEFT", 17, -17)
    emblem:SetSize(48,48)
    emblem:SetTexture("Interface\\Icons\\INV_Misc_Orb_05")

    self:Text(side, "MCA", "GameFontHighlightLarge", {"TOPLEFT", side, "TOPLEFT", 72, -22}, 55, self:UIColor("accent"))
    self:Text(side, "v"..(self.VERSION or "?"), "GameFontNormalSmall", {"TOPLEFT", side, "TOPLEFT", 74, -47}, 55, self:UIColor("gray"))

    local tabs = {
        {"Riepilogo","summary"},
        {"Player","players"},
        {"Deaths","deaths"},
        {"Timeline","timeline"},
        {"Storico","history"},
        {"Impostazioni","settings"}
    }

    local y = -92
    for _, tab in ipairs(tabs) do
        local active = self.activeTab == tab[2]
        local b = CreateFrame("Button", nil, side, "BackdropTemplate")
        b:SetPoint("TOPLEFT", 8, y)
        b:SetSize(122, 34)
        self:SetBackdropSolid(b, active and {0.18,0.15,0.02,0.82} or {0.035,0.038,0.04,0.75}, active and {1,0.82,0,1} or {0.16,0.17,0.18,1})

        local icons = {
            summary = "Interface\\Icons\\INV_Misc_Note_01",
            players = "Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend",
            deaths = "Interface\\Icons\\Ability_Creature_Cursed_02",
            buffs = "Interface\\Icons\\Spell_Holy_GreaterBlessingofKings",
            interrupts = "Interface\\Icons\\Ability_Kick",
            timeline = "Interface\\Icons\\INV_Misc_PocketWatch_01",
            history = "Interface\\Icons\\INV_Misc_Book_09",
            settings = "Interface\\Icons\\INV_Misc_Gear_01"
        }

        self:SmallTexture(b, icons[tab[2]] or "Interface\\Icons\\INV_Misc_QuestionMark", {"LEFT", b, "LEFT", 9, 0}, 14)
        self:Text(b, tab[1], "GameFontNormal", {"LEFT", b, "LEFT", 30, 0}, 92, active and self:UIColor("accent") or self:UIColor("white"))
        b:SetScript("OnClick", function()
            MCA.activeTab = tab[2]
            MCA:BuildDashboard(MCA.lastReport)
        end)
        y = y - 40
    end

    self:Text(side, "Sync: "..(MidnightCombatAnalyticsDB.config.syncEnabled and "ON" or "OFF"), "GameFontNormal", {"BOTTOMLEFT", side, "BOTTOMLEFT", 14, 72}, 105, MidnightCombatAnalyticsDB.config.syncEnabled and self:UIColor("green") or self:UIColor("red"))
end




function MCA:GetEmptyReport()
    return {
        boss = "Nessun report",
        type = "raid",
        mode = "Raid",
        difficulty = "-",
        result = false,
        duration = 0,
        players = {},
        bosses = {},
        timeline = {},
        deaths = {},
        defensives = {},
        raidBuffs = {}
    }
end

function MCA:GetLastAvailableReport()
    if self.lastReport then return self.lastReport end

    if MidnightCombatAnalyticsDB and MidnightCombatAnalyticsDB.history and #MidnightCombatAnalyticsDB.history > 0 then
        return MidnightCombatAnalyticsDB.history[#MidnightCombatAnalyticsDB.history]
    end

    return self:GetEmptyReport()
end

function MCA:GetModeDifficultyText(data)
    local mode = "Raid"
    local difficulty = "-"

    if data then
        if data.type == "M+" then
            mode = "Mythic+"
        elseif data.mode and data.mode ~= "" then
            mode = data.mode
        elseif data.type == "raid" then
            mode = "Raid"
        end

        if data.difficulty and data.difficulty ~= "" then
            difficulty = data.difficulty
        end
    end

    if mode == "Mythic+" then
        if difficulty ~= "-" and difficulty ~= "Mythic+" then
            return "Mythic+ " .. difficulty
        end
        return "Mythic+"
    end

    if difficulty == "-" or difficulty == "" or difficulty == "Raid" then
        return mode
    end

    return mode .. " " .. difficulty
end

function MCA:DrawTopDashboard(root, data)
    local info = self:Panel(root, {"TOPLEFT", root, "TOPLEFT", 154, -36}, 290, 64, {0.018,0.021,0.024,0.50})
    self:Text(info, data.boss or "Report", "GameFontHighlightLarge", {"TOPLEFT", info, "TOPLEFT", 16, -9}, 150, self:UIColor("purple"))
    self:Text(info, (data.result and "Completato" or "Wipe")..": "..date("%d/%m/%Y %H:%M"), "GameFontNormal", {"TOPLEFT", info, "TOPLEFT", 16, -36}, 220, self:UIColor("green"))

    local totals = self:GetTotals(data)
    local kpis = self:Panel(root, {"TOPLEFT", root, "TOPLEFT", 466, -36}, 630, 64, {0.018,0.021,0.024,0.72})
    local cells = {
        {"Boss", totals.bossKilled.."/"..totals.bosses, self:UIColor("accent")},
        {"Durata", self:FormatTime(data.duration or 0), self:UIColor("accent")},
        {"Deaths", tostring(totals.deaths), self:UIColor("red")},
        {"CD Usati", tostring(totals.cds), self:UIColor("green")},
        {"Buff Raid", tostring(totals.buffActive or 0).."/"..tostring(totals.buffPresent or 0), self:UIColor((totals.buffMissing or 0) > 0 and "orange" or "green")},
        {"Punteggio", self:ComputeRaidScore(data).."%", self:UIColor("green")}
    }
    local x = 0
    for _, c in ipairs(cells) do
        local cell = CreateFrame("Frame", nil, kpis, "BackdropTemplate")
        cell:SetPoint("TOPLEFT", x, 0)
        cell:SetSize(105, 64)
        self:SetBackdropSolid(cell, {0,0,0,0}, {0.17,0.18,0.19,1})
        self:Text(cell, c[1], "GameFontNormal", {"TOP", cell, "TOP", 0, -11}, 90, self:UIColor("white"), "CENTER")
        self:Text(cell, c[2], "GameFontHighlightLarge", {"TOP", cell, "TOP", 0, -34}, 90, c[3], "CENTER")
        x = x + 105
    end

    local mode = self:Panel(root, {"TOPLEFT", root, "TOPLEFT", 1118, -36}, 186, 64, {0.018,0.021,0.024,0.72})
    local icon = mode:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("LEFT", 20, 0)
    icon:SetSize(36,36)
    icon:SetTexture("Interface\\Icons\\Achievement_Dungeon_GloryoftheRaider")
    self:Text(mode, "Modalità", "GameFontNormal", {"TOPLEFT", mode, "TOPLEFT", 70, -13}, 110, self:UIColor("white"))
    self:Text(mode, self:GetModeDifficultyText(data), "GameFontHighlight", {"TOPLEFT", mode, "TOPLEFT", 70, -36}, 130, self:GetDifficultyColor(data.difficulty))
end

function MCA:ComputeRaidScore(data)
    local total, count = 0, 0
    for _, p in pairs(data.players or {}) do
        total = total + self:GetScore(p)
        count = count + 1
    end
    if count == 0 then return 100 end
    return math.floor(total / count)
end

function MCA:TableHeader(parent, cols, y)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetPoint("TOPLEFT", 0, y)
    row:SetSize(parent:GetWidth(), 26)
    self:SetBackdropSolid(row, {0.025,0.027,0.030,0.95}, {0.16,0.17,0.18,1})
    for _, c in ipairs(cols) do
        self:Text(row, c.label, "GameFontHighlightSmall", {"LEFT", row, "LEFT", c.x, 0}, c.w, self:UIColor("white"), c.justify or "LEFT")
    end
    return y - 28
end




function MCA:DrawPlayerTable(parent, data)
    self:Text(parent, "Player", "GameFontHighlightLarge", {"TOPLEFT", parent, "TOPLEFT", 14, -10}, 120, self:UIColor("accent"))

    local search = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    search:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -30, -10)
    search:SetSize(145, 22)
    search:SetAutoFocus(false)
    search:SetText("")
    search:SetTextInsets(8, 8, 0, 0)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    self:Text(parent, "Cerca player...", "GameFontNormalSmall", {"TOPRIGHT", search, "TOPLEFT", -6, -4}, 80, self:UIColor("gray"), "RIGHT")

    local outerW = parent:GetWidth() - 16
    local outerH = parent:GetHeight() - 50
    local _, child, scroll = self:Scroll(parent, {"TOPLEFT", parent, "TOPLEFT", 8, -40}, outerW, outerH, {0.018,0.020,0.022,0.55})

    local tableW = outerW - 28

    -- Adaptive columns. Last column always ends inside tableW.
    local cols = {
        {label="#", x=6, w=22, justify="CENTER"},
        {label="Player", x=36, w=140},
        {label="Classe", x=188, w=116},
        {label="Ruolo", x=314, w=58, justify="CENTER"},
        {label="Morti", x=382, w=46, justify="CENTER"},
        {label="Score", x=438, w=58, justify="CENTER"},
        {label="Stato", x=508, w=math.max(tableW - 508, 70)}
    }

    local y = -2
    y = self:TableHeader(child, cols, y)

    local list = self:BuildPlayerList(data)

    for i, p in ipairs(list) do
        local row = CreateFrame("Button", nil, child, "BackdropTemplate")
        row:SetPoint("TOPLEFT", 0, y)
        row:SetSize(tableW, 28)
        self:SetBackdropSolid(row, i % 2 == 0 and self:UIColor("rowAlt") or self:UIColor("row"), {0.12,0.13,0.14,1})

        self:Text(row, tostring(i)..".", "GameFontNormal", {"LEFT", row, "LEFT", 6, 0}, 22, self:UIColor("white"), "CENTER")

        self:ClassIcon(row, p.class, 36, -5, 18)
        self:Text(row, p.name or "?", "GameFontNormal", {"LEFT", row, "LEFT", 60, 0}, 114, i % 3 == 0 and self:UIColor("blue") or (i % 3 == 1 and self:UIColor("accent") or self:UIColor("orange")))

        self:ClassIcon(row, p.class, 188, -5, 18)
        self:Text(row, self:PrettyClass(p.class), "GameFontNormalSmall", {"LEFT", row, "LEFT", 212, 0}, 90, self:UIColor("white"))

        self:Text(row, self:RoleShort(p.role), "GameFontNormalSmall", {"LEFT", row, "LEFT", 314, 0}, 58, self:UIColor("white"), "CENTER")
        self:Text(row, tostring(p.deaths or 0), "GameFontNormal", {"LEFT", row, "LEFT", 382, 0}, 46, (p.deaths or 0) > 0 and self:UIColor("red") or self:UIColor("white"), "CENTER")

        local score = self:GetScore(p)
        local status, color = self:StatusForScore(score)
        local shortStatus = status == "Ottimo" and "OK" or (status == "Buono" and "Good" or (status == "Discreto" and "Watch" or "Crit"))

        self:Text(row, score.."%", "GameFontNormal", {"LEFT", row, "LEFT", 438, 0}, 58, color, "CENTER")
        self:StatusTexture(row, {"LEFT", row, "LEFT", 510, 0}, shortStatus)
        self:Text(row, shortStatus, "GameFontNormalSmall", {"LEFT", row, "LEFT", 530, 0}, math.max(tableW - 530, 55), color)

        row:SetScript("OnClick", function()
            MCA.selectedPlayer = p
            MCA.activeTab = "summary"
            MCA:BuildDashboard(data)
        end)

        y = y - 28
    end

    self:UpdateScrollBar(child, scroll, math.abs(y)+20)
end

function MCA:PrettyClass(class)
    local map = {DEATHKNIGHT="Death Knight", DEMONHUNTER="Demon Hunter"}
    if map[class or ""] then return map[class] end
    local s = string.lower(class or "?")
    return s:gsub("^%l", string.upper)
end




function MCA:DrawBossBreakdown(parent, data)
    self:Text(parent, "Boss Breakdown", "GameFontHighlightLarge", {"TOPLEFT", parent, "TOPLEFT", 14, -10}, 160, self:UIColor("accent"))

    local bosses = self:GetWindows(data)
    local y = -42

    -- MCA 4.0.30: Boss Breakdown adaptive columns.
    -- The panel is narrower than the old fixed 480px layout, so every column
    -- is calculated from parent width and kept inside the frame.
    local tableW = math.max((parent:GetWidth() or 380) - 16, 320)
    local wNum, wPull, wKill, wDurata, wMorti = 24, 38, 38, 52, 42
    local gap = 6

    local xNum = 8
    local xBoss = 40
    local xMorti = tableW - wMorti
    local xDurata = xMorti - gap - wDurata
    local xKill = xDurata - gap - wKill
    local xPull = xKill - gap - wPull
    local wBoss = math.max(xPull - xBoss - gap, 100)

    local cols = {
        {label="#", x=xNum, w=wNum, justify="CENTER"},
        {label="Boss", x=xBoss, w=wBoss},
        {label="Pull", x=xPull, w=wPull, justify="CENTER"},
        {label="Kill", x=xKill, w=wKill, justify="CENTER"},
        {label="Durata", x=xDurata, w=wDurata, justify="CENTER"},
        {label="Morti", x=xMorti, w=wMorti, justify="CENTER"}
    }

    y = self:TableHeader(parent, cols, y)

    for i, b in ipairs(bosses) do
        local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
        row:SetPoint("TOPLEFT", 8, y)
        row:SetSize(parent:GetWidth()-16, 30)
        self:SetBackdropSolid(row, i == 1 and {0.10,0.16,0.25,0.75} or (i % 2 == 0 and self:UIColor("rowAlt") or self:UIColor("row")), {0.12,0.13,0.14,1})

        local deaths = self:CountDeathsInWindow(data, b.startTime or 0, b.endTime or data.duration or 0)
        local cds = self:CountCDsInWindow(data, b.startTime or 0, b.endTime or data.duration or 0)
        local score = math.max(0, 100 - deaths*10 + math.min(cds, 10))
        if score > 100 then score = 100 end

        self:Text(row, tostring(i), "GameFontNormal", {"LEFT", row, "LEFT", xNum, 0}, wNum, self:UIColor("white"), "CENTER")
        self:Text(row, b.name or "Boss", "GameFontNormal", {"LEFT", row, "LEFT", xBoss, 0}, wBoss, self:UIColor("accent"))
        self:Text(row, "1", "GameFontNormal", {"LEFT", row, "LEFT", xPull, 0}, wPull, self:UIColor("white"), "CENTER")
        self:SuccessTexture(row, {"LEFT", row, "LEFT", xKill + 12, 0}, b.success)
        self:Text(row, self:FormatTime(b.duration or ((b.endTime or 0)-(b.startTime or 0))), "GameFontNormal", {"LEFT", row, "LEFT", xDurata, 0}, wDurata, self:UIColor("white"), "CENTER")
        self:Text(row, tostring(deaths), "GameFontNormal", {"LEFT", row, "LEFT", xMorti, 0}, wMorti, deaths > 0 and self:UIColor("red") or self:UIColor("white"), "CENTER")

        row:SetScript("OnClick", function()
            MCA.selectedBoss = b
            MCA:BuildDashboard(data)
        end)

        y = y - 30
        if i >= 4 then break end
    end
end

function MCA:DrawBossDetail(parent, data)
    local boss = self.selectedBoss or (self:GetWindows(data)[1])
    self:Text(parent, "Dettaglio: "..(boss and boss.name or "Encounter"), "GameFontHighlightLarge", {"TOPLEFT", parent, "TOPLEFT", 14, -8}, 240, self:UIColor("accent"))

    local _, child, scroll = self:Scroll(parent, {"TOPLEFT", parent, "TOPLEFT", 8, -38}, parent:GetWidth()-16, parent:GetHeight()-44, {0.018,0.020,0.022,0.55})

    local cols = {
        {label="Player", x=10, w=122},
        {label="Ruolo", x=146, w=50, justify="CENTER"},
        {label="Morti", x=208, w=40, justify="CENTER"},
        {label="CD", x=262, w=35, justify="CENTER"},
        {label="Debuff", x=312, w=48, justify="CENTER"},
        {label="Score", x=380, w=50, justify="CENTER"}
    }

    local y = -2
    y = self:TableHeader(child, cols, y)

    for i, p in ipairs(self:BuildPlayerList(data)) do
        local row = CreateFrame("Button", nil, child, "BackdropTemplate")
        row:SetPoint("TOPLEFT", 0, y)
        row:SetSize(442, 24)
        self:SetBackdropSolid(row, i % 2 == 0 and self:UIColor("rowAlt") or self:UIColor("row"), {0.12,0.13,0.14,1})

        self:ClassIcon(row, p.class, 10, -3, 18)
        self:Text(row, p.name or "?", "GameFontNormal", {"LEFT", row, "LEFT", 36, 0}, 96, i % 2 == 0 and self:UIColor("orange") or self:UIColor("blue"))
        self:Text(row, self:RoleShort(p.role), "GameFontNormal", {"LEFT", row, "LEFT", 146, 0}, 50, self:UIColor("white"), "CENTER")

        local deaths = (p.deathTime and boss and p.deathTime >= (boss.startTime or 0) and p.deathTime <= (boss.endTime or data.duration or 0)) and (p.deaths or 1) or 0
        local cds = boss and #self:GetPlayerDefensivesInWindow(p, boss.startTime or 0, boss.endTime or data.duration or 0) or #(p.used or {})

        self:Text(row, tostring(deaths), "GameFontNormal", {"LEFT", row, "LEFT", 208, 0}, 40, deaths > 0 and self:UIColor("red") or self:UIColor("white"), "CENTER")
        self:Text(row, tostring(cds), "GameFontNormal", {"LEFT", row, "LEFT", 262, 0}, 35, self:UIColor("white"), "CENTER")
        self:Text(row, tostring(#(p.debuffs or {})), "GameFontNormal", {"LEFT", row, "LEFT", 312, 0}, 48, self:UIColor("white"), "CENTER")

        local score = self:GetScore(p)
        local _, c = self:StatusForScore(score)
        self:Text(row, score.."%", "GameFontNormal", {"LEFT", row, "LEFT", 380, 0}, 50, c, "CENTER")

        row:SetScript("OnClick", function()
            MCA.selectedPlayer = p
            MCA.activeTab = "summary"
            MCA:BuildDashboard(data)
        end)

        y = y - 24
    end

    self:UpdateScrollBar(child, scroll, math.abs(y)+20)
end


function MCA:NormalizeColumns(parent, headers)
    local innerW = self:GetInnerWidth(parent, 260)
    local filtered = {}

    for _, h in ipairs(headers or {}) do
        local endX = (h.x or 0) + (h.w or 0)
        if endX <= innerW - 4 then
            table.insert(filtered, h)
        end
    end

    return filtered
end

function MCA:DrawSmallPanel(parent, title, iconSpell, colorName, headers, rows, buttonText)
    local color = self:UIColor(colorName or "accent")
    self:Text(parent, title, "GameFontHighlightLarge", {"TOPLEFT", parent, "TOPLEFT", 14, -12}, parent:GetWidth()-28, color)

    local scrollW = parent:GetWidth() - 16
    local scrollH = parent:GetHeight() - 62
    local _, child, scroll = self:Scroll(parent, {"TOPLEFT", parent, "TOPLEFT", 8, -50}, scrollW, scrollH, {0.018,0.020,0.022,0.55})

    local innerW = scrollW - 10
    local normalizedHeaders = self:NormalizeColumns(child, headers)
    local y = -2
    y = self:TableHeader(child, normalizedHeaders, y)

    if #rows == 0 then
        self:Text(child, "Nessun dato registrato.", "GameFontNormal", {"TOPLEFT", child, "TOPLEFT", 12, y-6}, innerW-24, self:UIColor("gray"))
    end

    for i, rowData in ipairs(rows) do
        local row = CreateFrame("Frame", nil, child, "BackdropTemplate")
        row:SetPoint("TOPLEFT", 0, y)
        row:SetSize(innerW, 28)
        self:SetBackdropSolid(row, i % 2 == 0 and self:UIColor("rowAlt") or self:UIColor("row"), {0.12,0.13,0.14,1})

        for _, cell in ipairs(rowData) do
            local x = cell.x or 0
            local w = cell.w or 40
            if x + w <= innerW - 4 then
                if cell.spellID then self:SpellIcon(row, cell.spellID, x, -5, 18) end
                local textX = x + (cell.spellID and 25 or 0)
                local textW = w - (cell.spellID and 25 or 0)
                self:Text(row, cell.text or "", "GameFontNormalSmall", {"LEFT", row, "LEFT", textX, 0}, textW, cell.color or self:UIColor("white"), cell.justify or "LEFT")
            end
        end

        y = y - 28
    end

    self:UpdateScrollBar(child, scroll, math.abs(y)+20)

    if buttonText and buttonText ~= "" then
        self:Button(parent, buttonText, {"BOTTOMLEFT", parent, "BOTTOMLEFT", 8, 8}, parent:GetWidth()-16, 24, function()
            local label = buttonText or ""

            if label:find("Torna") then
                MCA.activeTab = "summary"
            elseif title == "Deaths" then
                MCA.activeTab = "deaths"
            elseif title and title:find("Timeline") then
                MCA.activeTab = "timeline"
            elseif title and (title:find("Difensive") or title:find("Defensive")) then
                MCA.activeTab = "players"
            else
                MCA.activeTab = "summary"
            end

            MCA:BuildDashboard(MCA.lastReport)
        end)
    end
end

function MCA:BuildDeathsRows(data)
    local rows = {}
    for _, p in pairs(data.players or {}) do
        if (p.deaths or 0) > 0 then
            table.insert(rows, {
                {x=10, w=55, text=self:FormatTime(p.deathTime or 0), color=self:UIColor("white")},
                {x=75, w=80, text=p.name or "?", color=self:UIColor("accent")},
                {x=165, w=80, text=self:BossNameAtTime(data, p.deathTime or 0), color=self:UIColor("white")},
                {x=260, w=40, text="-", color=self:UIColor("gray"), justify="CENTER"},
                {x=315, w=40, text="0%", color=self:UIColor("white"), justify="CENTER"},
                {x=365, w=60, text="-", color=self:UIColor("white"), justify="CENTER"}
            })
        end
    end
    return rows
end

function MCA:BossNameAtTime(data, t)
    for _, b in ipairs(data.bosses or {}) do
        if t >= (b.startTime or 0) and t <= (b.endTime or 0) then return b.name or "Boss" end
    end
    return data.boss or "Encounter"
end

function MCA:BuildDebuffRows(data)
    local rows = {}
    for _, p in pairs(data.players or {}) do
        for _, d in ipairs(p.debuffs or {}) do
            table.insert(rows, {
                {x=10, w=35, text="", spellID=d.spellID},
                {x=55, w=105, text=d.name or self:GetSpellNameSafe(d.spellID), color=self:UIColor("white")},
                {x=175, w=85, text=p.name or "?", color=self:UIColor("red")},
                {x=270, w=45, text="1", color=self:UIColor("white"), justify="CENTER"},
                {x=330, w=55, text="--", color=self:UIColor("white"), justify="CENTER"}
            })
        end
    end
    return rows
end

function MCA:BuildTimelineRows(data)
    local events = {}
    for _, e in ipairs(data.timeline or {}) do table.insert(events, e) end
    table.sort(events, function(a,b) return (a.time or 0) < (b.time or 0) end)
    local rows = {}
    for _, e in ipairs(events) do
        table.insert(rows, {
            {x=10, w=55, text=self:FormatTime(e.time or 0), color=self:UIColor("white")},
            {x=75, w=135, text=e.text or "Evento", spellID=e.spellID, color=e.type == "death" and self:UIColor("red") or self:UIColor("white")},
            {x=240, w=75, text=e.player or "", color=self:UIColor("blue")},
            {x=325, w=85, text=self:BossNameAtTime(data, e.time or 0), color=self:UIColor("white")}
        })
    end
    return rows
end

function MCA:BuildDefensiveRows(data)
    local player = self.selectedPlayer or self:BuildPlayerList(data)[1]
    local rows = {}
    if player then
        for _, u in ipairs(player.used or {}) do
            table.insert(rows, {
                {x=10, w=35, text="", spellID=u.spellID},
                {x=55, w=120, text=u.name or self:GetSpellNameSafe(u.spellID), color=self:UIColor("white")},
                {x=185, w=80, text=self:BossNameAtTime(data, u.time or 0), color=self:UIColor("white")},
                {x=275, w=55, text=self:FormatTime(u.time or 0), color=self:UIColor("white"), justify="CENTER"},
                {x=340, w=70, text=u.source == "sync" and "Sync" or "Difensiva", color=self:UIColor("white")}
            })
        end
    end
    return rows
end




function MCA:DrawRaidBuffMatrix(parent, data)
    self:Text(parent, "Buff Raid", "GameFontHighlightLarge", {"TOPLEFT", parent, "TOPLEFT", 14, -12}, 180, self:UIColor("purple"))

    local matrix = data and data.raidBuffMatrix
    if not matrix then
        matrix = { buffs = data and data.raidBuffs or {}, players = {} }
    end

    local buffs = {}
    for _, buff in ipairs(matrix.buffs or {}) do
        if buff.classPresent then
            table.insert(buffs, buff)
        end
    end

    local _, child, scroll = self:Scroll(parent, {"TOPLEFT", parent, "TOPLEFT", 8, -48}, parent:GetWidth()-16, parent:GetHeight()-58, {0.018,0.020,0.022,0.55})

    local playerColW = 190
    local roleColW = 70
    local buffColW = 90
    local tableW = playerColW + roleColW + (#buffs * buffColW) + 20

    child:SetWidth(math.max(tableW, parent:GetWidth()-32))

    local header = CreateFrame("Frame", nil, child, "BackdropTemplate")
    header:SetPoint("TOPLEFT", 0, -2)
    header:SetSize(child:GetWidth(), 30)
    self:SetBackdropSolid(header, {0.025,0.027,0.030,0.95}, {0.16,0.17,0.18,1})

    self:Text(header, "Player", "GameFontHighlightSmall", {"LEFT", header, "LEFT", 10, 0}, playerColW-10, self:UIColor("white"))
    self:Text(header, "Ruolo", "GameFontHighlightSmall", {"LEFT", header, "LEFT", playerColW, 0}, roleColW, self:UIColor("white"), "CENTER")

    local x = playerColW + roleColW
    for _, buff in ipairs(buffs) do
        self:SpellIcon(header, buff.spellID, x + 4, -5, 18)
        self:Text(header, buff.short or buff.name or "Buff", "GameFontHighlightSmall", {"LEFT", header, "LEFT", x + 26, 0}, buffColW-28, self:UIColor("white"), "CENTER")
        x = x + buffColW
    end

    local y = -34
    local players = matrix.players or {}

    for i, p in ipairs(players) do
        local row = CreateFrame("Frame", nil, child, "BackdropTemplate")
        row:SetPoint("TOPLEFT", 0, y)
        row:SetSize(child:GetWidth(), 30)
        self:SetBackdropSolid(row, i % 2 == 0 and self:UIColor("rowAlt") or self:UIColor("row"), {0.12,0.13,0.14,1})

        self:ClassIcon(row, p.class, 10, -6, 18)
        self:Text(row, p.name or "?", "GameFontNormal", {"LEFT", row, "LEFT", 36, 0}, playerColW-40, self:UIColor("accent"))
        self:Text(row, self:RoleShort(p.role), "GameFontNormalSmall", {"LEFT", row, "LEFT", playerColW, 0}, roleColW, self:UIColor("white"), "CENTER")

        x = playerColW + roleColW
        for _, buff in ipairs(buffs) do
            local has = p.buffs and p.buffs[buff.key]
            if has == true then
                self:Text(row, "●", "GameFontHighlightLarge", {"LEFT", row, "LEFT", x, 0}, buffColW, self:UIColor("green"), "CENTER")
            elseif has == false then
                self:Text(row, "X", "GameFontHighlightLarge", {"LEFT", row, "LEFT", x, 0}, buffColW, self:UIColor("red"), "CENTER")
            else
                self:Text(row, "–", "GameFontNormalLarge", {"LEFT", row, "LEFT", x, 0}, buffColW, self:UIColor("gray"), "CENTER")
            end
            x = x + buffColW
        end

        y = y - 30
    end

    if #players == 0 then
        self:Text(child, "Nessuno snapshot buff disponibile. Verrà generato al prossimo pull.", "GameFontNormal", {"TOPLEFT", child, "TOPLEFT", 14, -44}, 500, self:UIColor("gray"))
    end

    self:UpdateScrollBar(child, scroll, math.abs(y)+40)
end


function MCA:DrawHistoryPage(parent)
    local history = self.GetHistory and self:GetHistory() or (MidnightCombatAnalyticsDB.history or {})

    self:Text(parent, "Report salvati: " .. tostring(#history), "GameFontNormal", {"TOPLEFT", parent, "TOPLEFT", 20, -20}, 240, self:UIColor("gray"))

    self:Button(parent, "Cancella storico", {"TOPRIGHT", parent, "TOPRIGHT", -20, -14}, 140, 24, function()
        MCA:ClearHistory()
        MCA.activeTab = "history"
        MCA:BuildDashboard(MCA.lastReport or {boss="Storico", players={}, bosses={}, timeline={}, type="raid"})
    end, true)

    local header = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -56)
    header:SetSize(1060, 28)
    self:SetBackdropSolid(header, {0.025,0.027,0.030,0.95}, {0.16,0.17,0.18,1})

    self:Text(header, "Data", "GameFontHighlightSmall", {"LEFT", header, "LEFT", 10, 0}, 120, self:UIColor("white"))
    self:Text(header, "Tipo", "GameFontHighlightSmall", {"LEFT", header, "LEFT", 145, 0}, 70, self:UIColor("white"))
    self:Text(header, "Encounter / Dungeon", "GameFontHighlightSmall", {"LEFT", header, "LEFT", 230, 0}, 260, self:UIColor("white"))
    self:Text(header, "Modalità", "GameFontHighlightSmall", {"LEFT", header, "LEFT", 510, 0}, 130, self:UIColor("white"))
    self:Text(header, "Durata", "GameFontHighlightSmall", {"LEFT", header, "LEFT", 660, 0}, 70, self:UIColor("white"))
    self:Text(header, "Esito", "GameFontHighlightSmall", {"LEFT", header, "LEFT", 750, 0}, 70, self:UIColor("white"))
    self:Text(header, "Score", "GameFontHighlightSmall", {"LEFT", header, "LEFT", 840, 0}, 70, self:UIColor("white"))

    local y = -88
    local rowIndex = 0

    for i = #history, 1, -1 do
        local report = history[i]
        rowIndex = rowIndex + 1

        local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, y)
        row:SetSize(1060, 30)
        self:SetBackdropSolid(row, rowIndex % 2 == 0 and self:UIColor("rowAlt") or self:UIColor("row"), {0.12,0.13,0.14,1})

        local score = self.ComputeRaidScore and self:ComputeRaidScore(report) or 0
        local resultText = report.result and "Kill" or "Wipe"

        self:Text(row, report.savedAt or "?", "GameFontNormalSmall", {"LEFT", row, "LEFT", 10, 0}, 120, self:UIColor("gray"))
        self:Text(row, report.type or "?", "GameFontNormalSmall", {"LEFT", row, "LEFT", 145, 0}, 70, self:UIColor("accent"))
        self:Text(row, report.boss or "?", "GameFontNormal", {"LEFT", row, "LEFT", 230, 0}, 260, self:UIColor("white"))
        self:Text(row, self:GetModeDifficultyText(report), "GameFontNormalSmall", {"LEFT", row, "LEFT", 510, 0}, 130, self:GetDifficultyColor(report.difficulty))
        self:Text(row, self:FormatTime(report.duration or 0), "GameFontNormalSmall", {"LEFT", row, "LEFT", 660, 0}, 70, self:UIColor("white"))
        self:Text(row, resultText, "GameFontNormalSmall", {"LEFT", row, "LEFT", 750, 0}, 70, report.result and self:UIColor("green") or self:UIColor("red"))
        self:Text(row, tostring(score).."%", "GameFontNormalSmall", {"LEFT", row, "LEFT", 840, 0}, 70, score >= 75 and self:UIColor("green") or self:UIColor("orange"))

        self:Button(row, "Apri", {"RIGHT", row, "RIGHT", -84, 0}, 64, 22, function()
            MCA.activeTab = "summary"
            MCA:BuildDashboard(report)
        end)

        self:Button(row, "X", {"RIGHT", row, "RIGHT", -12, 0}, 28, 22, function()
            table.remove(MidnightCombatAnalyticsDB.history, i)
            MCA.activeTab = "history"
            MCA:BuildDashboard(MCA.lastReport or {boss="Storico", players={}, bosses={}, timeline={}, type="raid"})
        end, true)

        row:SetScript("OnClick", function()
            MCA.activeTab = "summary"
            MCA:BuildDashboard(report)
        end)

        y = y - 32
    end

    if #history == 0 then
        self:Text(parent, "Nessun report salvato. I prossimi report completati appariranno qui.", "GameFontNormal", {"TOPLEFT", parent, "TOPLEFT", 26, -94}, 620, self:UIColor("gray"))
    end

    return math.abs(y) + 80
end

function MCA:DrawFullPage(root, data)
    local _, child, scroll = self:Scroll(root, {"TOPLEFT", root, "TOPLEFT", 154, -112}, 1150, 535, {0.018,0.020,0.022,0.65})

    local titleMap = {summary="Riepilogo", players="Player", deaths="Deaths", timeline="Timeline", history="Storico", settings="Impostazioni"}
    local title = titleMap[self.activeTab] or "Riepilogo"

    self:Text(child, title, "GameFontHighlightLarge", {"TOPLEFT", child, "TOPLEFT", 16, -12}, 300, self:UIColor("accent"))

    local y = -50

    if self.activeTab == "settings" then
        local settings = {
            {"Sync", "syncEnabled"},
            {"Debug", "debug"},
            {"ElvUI Skin", "useElvUISkin"},
            {"Auto Open", "autoOpen"},
            {"Show Kill", "showAfterKill"},
            {"Show Wipe", "showAfterWipe"},
            {"Show M+ End", "showMythicEnd"}
        }

        for _, s in ipairs(settings) do
            self:Text(child, s[1]..": "..(MidnightCombatAnalyticsDB.config[s[2]] and "ON" or "OFF"), "GameFontNormal", {"TOPLEFT", child, "TOPLEFT", 20, y}, 200, MidnightCombatAnalyticsDB.config[s[2]] and self:UIColor("green") or self:UIColor("red"))
            self:Button(child, "Toggle", {"TOPLEFT", child, "TOPLEFT", 240, y+4}, 90, 22, function()
                MidnightCombatAnalyticsDB.config[s[2]] = not MidnightCombatAnalyticsDB.config[s[2]]
                MCA:BuildDashboard(data)
            end)
            y = y - 36
        end

    elseif self.activeTab == "players" then
        local panel = self:Panel(child, {"TOPLEFT", child, "TOPLEFT", 12, y}, 1100, 430)
        self:DrawPlayerTable(panel, data)
        y = y - 450

    elseif self.activeTab == "deaths" then
        local panel = self:Panel(child, {"TOPLEFT", child, "TOPLEFT", 12, y}, 1100, 430)
        self:DrawSmallPanel(panel, "Deaths", nil, "red",
            {{label="Tempo",x=10,w=55},{label="Player",x=75,w=100},{label="Boss",x=190,w=110},{label="Killer",x=320,w=90},{label="HP",x=430,w=60},{label="Def. Attiva",x=510,w=120}},
            self:BuildDeathsRows(data), "Torna al riepilogo")
        y = y - 450

    elseif self.activeTab == "buffs" then
        local panel = self:Panel(child, {"TOPLEFT", child, "TOPLEFT", 12, y}, 1100, 430)
        self:DrawSmallPanel(panel, "Buff Raid", nil, "purple",
            {{label="Icona",x=10,w=45},{label="Debuff",x=60,w=180},{label="Player",x=260,w=120},{label="Stack",x=400,w=70},{label="Durata",x=500,w=90}},
            self:BuildRaidBuffRows(data), "Torna al riepilogo")
        y = y - 450

    elseif self.activeTab == "timeline" then
        local panel = self:Panel(child, {"TOPLEFT", child, "TOPLEFT", 12, y}, 1100, 430)
        self:DrawSmallPanel(panel, "Timeline  (Eventi principali)", nil, "blue",
            {{label="Tempo",x=10,w=55},{label="Evento",x=75,w=260},{label="Player",x=360,w=120},{label="Boss",x=500,w=130}},
            self:BuildTimelineRows(data), "Torna al riepilogo")
        y = y - 450

    elseif self.activeTab == "history" then
        y = -50 - self:DrawHistoryPage(child)

    else
        local totals = self:GetTotals(data)
        local lines = {
            "Player totali: "..totals.players,
            "Player con MCA: "..totals.addon.."/"..totals.players,
            "Difensivi usati: "..totals.cds,
            "Buff raid presenti: "..totals.buffActive.."/"..totals.buffPresent,
            "Deaths totali: "..totals.deaths,
            "Punteggio: "..self:ComputeRaidScore(data).."%"
        }

        for _, line in ipairs(lines) do
            self:Text(child, line, "GameFontNormalLarge", {"TOPLEFT", child, "TOPLEFT", 24, y}, 420, self:UIColor("white"))
            y = y - 32
        end
    end

    self:UpdateScrollBar(child, scroll, math.abs(y)+80)
end




function MCA:FormatMetricValue(value)
    value = tonumber(value or 0) or 0
    if value <= 0 then return "-" end
    if value >= 1000000 then return string.format("%.2fM", value / 1000000) end
    if value >= 1000 then return string.format("%.0fk", value / 1000) end
    return tostring(math.floor(value))
end

function MCA:GetFightMetric(player)
    if not player then return 0 end

    if (player.role or "") == "HEALER" then
        if player.blizzardHps and player.blizzardHps > 0 then return player.blizzardHps end
        if player.blizzard and player.blizzard.hps and player.blizzard.hps.amountPerSecond then return player.blizzard.hps.amountPerSecond end
        return player.hps or player.fightHPS or player.healingPerSecond or 0
    end

    if player.blizzardDps and player.blizzardDps > 0 then return player.blizzardDps end
    if player.blizzard and player.blizzard.dps and player.blizzard.dps.amountPerSecond then return player.blizzard.dps.amountPerSecond end
    return player.dps or player.fightDPS or player.damagePerSecond or 0
end

function MCA:GetRatingColor(rating)
    rating = tonumber(rating or 0) or 0
    if rating >= 99 then return {0.886, 0.408, 1.000, 1} end -- pink
    if rating >= 95 then return {1.000, 0.502, 0.000, 1} end -- orange
    if rating >= 75 then return {0.639, 0.208, 0.933, 1} end -- purple
    if rating >= 50 then return {0.000, 0.439, 0.867, 1} end -- blue
    if rating >= 25 then return {0.118, 1.000, 0.000, 1} end -- green
    return {0.616, 0.616, 0.616, 1} -- gray
end

function MCA:CalculateRoleRatings(players)
    local maxDPS, maxHPS = 0, 0

    for _, p in ipairs(players or {}) do
        local value = self:GetFightMetric(p)
        if (p.role or "") == "HEALER" then
            if value > maxHPS then maxHPS = value end
        else
            if value > maxDPS then maxDPS = value end
        end
    end

    for _, p in ipairs(players or {}) do
        local value = self:GetFightMetric(p)
        local maxValue = ((p.role or "") == "HEALER") and maxHPS or maxDPS

        if maxValue and maxValue > 0 and value > 0 then
            p.mcaRating = math.floor(math.max(1, math.min(99, (value / maxValue) * 99)) + 0.5)
        else
            -- Fallback until DPS/HPS source is implemented.
            p.mcaRating = self:GetScore(p)
        end
    end
end

function MCA:BuildRoleList(data, wantHealer)
    local all = self:BuildPlayerList(data)
    local list = {}

    self:CalculateRoleRatings(all)

    for _, p in ipairs(all) do
        local isHealer = (p.role or "") == "HEALER"
        if (wantHealer and isHealer) or ((not wantHealer) and (not isHealer)) then
            table.insert(list, p)
        end
    end

    table.sort(list, function(a, b)
        local av = self:GetFightMetric(a)
        local bv = self:GetFightMetric(b)
        if av == bv then return (a.mcaRating or 0) > (b.mcaRating or 0) end
        return av > bv
    end)

    return list
end

function MCA:DrawRoleMetricTable(parent, data, title, wantHealer)
    self:Text(parent, title, "GameFontHighlightLarge", {"TOPLEFT", parent, "TOPLEFT", 14, -10}, parent:GetWidth()-28, self:UIColor("accent"))

    local outerW = parent:GetWidth() - 16
    local outerH = parent:GetHeight() - 50
    local _, child, scroll = self:Scroll(parent, {"TOPLEFT", parent, "TOPLEFT", 8, -40}, outerW, outerH, {0.018,0.020,0.022,0.55})

    local tableW = outerW - 28
    local metricLabel = wantHealer and "HPS" or "DPS"

    local cols = {
        {label="#", x=6, w=22, justify="CENTER"},
        {label="Player", x=36, w=130},
        {label="Classe", x=178, w=105},
        {label="Morti", x=292, w=44, justify="CENTER"},
        {label=metricLabel, x=348, w=72, justify="CENTER"},
        {label="Rating", x=434, w=math.max(tableW - 434, 70), justify="CENTER"}
    }

    local y = -2
    y = self:TableHeader(child, cols, y)

    local list = self:BuildRoleList(data, wantHealer)

    if #list == 0 then
        self:Text(child, "Nessun dato registrato.", "GameFontNormal", {"TOPLEFT", child, "TOPLEFT", 12, y-6}, tableW-24, self:UIColor("gray"))
    end

    for i, p in ipairs(list) do
        local row = CreateFrame("Button", nil, child, "BackdropTemplate")
        row:SetPoint("TOPLEFT", 0, y)
        row:SetSize(tableW, 28)
        self:SetBackdropSolid(row, i % 2 == 0 and self:UIColor("rowAlt") or self:UIColor("row"), {0.12,0.13,0.14,1})

        local rating = p.mcaRating or self:GetScore(p)
        local ratingColor = self:GetRatingColor(rating)

        self:Text(row, tostring(i)..".", "GameFontNormal", {"LEFT", row, "LEFT", cols[1].x, 0}, cols[1].w, self:UIColor("white"), "CENTER")

        self:ClassIcon(row, p.class, cols[2].x, -5, 18)
        self:Text(row, p.name or "?", "GameFontNormal", {"LEFT", row, "LEFT", cols[2].x + 24, 0}, cols[2].w - 24, i % 3 == 0 and self:UIColor("blue") or (i % 3 == 1 and self:UIColor("accent") or self:UIColor("orange")))

        self:ClassIcon(row, p.class, cols[3].x, -5, 18)
        self:Text(row, self:PrettyClass(p.class), "GameFontNormalSmall", {"LEFT", row, "LEFT", cols[3].x + 24, 0}, cols[3].w - 24, self:UIColor("white"))

        self:Text(row, tostring(p.deaths or 0), "GameFontNormal", {"LEFT", row, "LEFT", cols[4].x, 0}, cols[4].w, (p.deaths or 0) > 0 and self:UIColor("red") or self:UIColor("white"), "CENTER")
        self:Text(row, self:FormatMetricValue(self:GetFightMetric(p)), "GameFontNormal", {"LEFT", row, "LEFT", cols[5].x, 0}, cols[5].w, self:UIColor("white"), "CENTER")
        self:Text(row, tostring(rating), "GameFontNormal", {"LEFT", row, "LEFT", cols[6].x, 0}, cols[6].w, ratingColor, "CENTER")

        row:SetScript("OnClick", function()
            MCA.selectedPlayer = p
            MCA.activeTab = "players"
            MCA:BuildDashboard(data)
        end)

        y = y - 28
    end

    self:UpdateScrollBar(child, scroll, math.abs(y)+20)
end

function MCA:DrawDashboardPage(root, data)
    -- v4.0.16 dashboard:
    -- Top row: DPS/Tank table left, Healer/HPS table right.
    -- Bottom row: Deaths, Timeline, Boss Breakdown.
    local leftX, totalW = 154, 1152
    local gap = 16
    local topY = -106
    local topH = 330

    local halfW = math.floor((totalW - gap) / 2)

    local dpsPanel = self:Panel(root, {"TOPLEFT", root, "TOPLEFT", leftX, topY}, halfW, topH)
    self:DrawRoleMetricTable(dpsPanel, data, "DPS / Tank", false)

    local healerPanel = self:Panel(root, {"TOPLEFT", root, "TOPLEFT", leftX + halfW + gap, topY}, halfW, topH)
    self:DrawRoleMetricTable(healerPanel, data, "Healer", true)

    local cardsY = -460
    local cardH = 230
    local cardW = math.floor((totalW - (gap * 2)) / 3)

    local deathPanel = self:Panel(root, {"TOPLEFT", root, "TOPLEFT", leftX, cardsY}, cardW, cardH)
    self:DrawSmallPanel(deathPanel, "Deaths", nil, "red",
        {{label="Tempo",x=10,w=55},{label="Player",x=76,w=110},{label="Boss",x=198,w=110},{label="HP",x=320,w=38}},
        self:BuildDeathsRows(data), nil)

    local timelinePanel = self:Panel(root, {"TOPLEFT", root, "TOPLEFT", leftX + cardW + gap, cardsY}, cardW, cardH)
    self:DrawSmallPanel(timelinePanel, "Timeline  (Eventi principali)", nil, "blue",
        {{label="Tempo",x=10,w=55},{label="Evento",x=76,w=210},{label="Player",x=300,w=90}},
        self:BuildTimelineRows(data), nil)

    local bossPanel = self:Panel(root, {"TOPLEFT", root, "TOPLEFT", leftX + (cardW + gap) * 2, cardsY}, cardW, cardH)
    self:DrawBossBreakdown(bossPanel, data)
end

function MCA:GetDifficultyColor(difficulty)
    difficulty = tostring(difficulty or "")

    if difficulty:find("Mythic") then
        return self:UIColor("purple")
    elseif difficulty:find("Heroic") then
        return self:UIColor("orange")
    elseif difficulty:find("Normal") then
        return self:UIColor("green")
    elseif difficulty:find("LFR") then
        return self:UIColor("blue")
    end

    return self:UIColor("gray")
end





-- ============================================================================


-- MCA 4.0.29d restored real dashboard opener from 4.0.28
function MCA:BuildDashboard(data)
    if not data then return end
    self.lastReport = data

    local old = _G.MCAFrame
    if old then old:Hide(); old:SetParent(nil); _G.MCAFrame = nil end

    local root = self:MainFrame()
    self:DrawSidebar(root)
    self:DrawTopDashboard(root, data)

    if self.activeTab == "boss" then
        self.activeTab = "summary"
    end

    if self.activeTab == "summary" then
        self:DrawDashboardPage(root, data)
    else
        self:DrawFullPage(root, data)
    end

    self:Button(root, "Esporta Report", {"BOTTOMLEFT", root, "BOTTOMLEFT", 16, 18}, 150, 34, function() MCA:ShowExportWindow(data) end)
    self:Button(root, "Share in chat", {"BOTTOMLEFT", root, "BOTTOMLEFT", 178, 18}, 150, 34, function() MCA:ShareSummary(data) end)
    self:Button(root, "Cancella Dati", {"BOTTOMRIGHT", root, "BOTTOMRIGHT", -150, 18}, 130, 34, function()
        MCA.lastReport = nil
        if MCAFrame then MCAFrame:Hide() end
        MCA:Print("Dati report cancellati.")
    end, true)
    self:Button(root, "Chiudi", {"BOTTOMRIGHT", root, "BOTTOMRIGHT", -16, 18}, 120, 34, function() root:Hide() end)

    root:Show()
end

function MCA:ShowUI(data)
    self.selectedPlayer = nil
    self.selectedBoss = nil
    self.activeTab = self.activeTab or "summary"
    self:BuildDashboard(data)
end

