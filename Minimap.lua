_G.MCA = _G.MCA or {}
MCA = _G.MCA

function MCA:RunTestReport()
    local players = {
        Coffettino = {
            name = "Coffettino",
            class = "MAGE",
            role = "DAMAGER",
            deaths = 1,
            deathTime = 136,
            hasAddon = true,
            used = {
                {name="Ice Barrier", spellID=11426, time=6},
                {name="Ice Block", spellID=45438, time=121}
            }
        },
        Tankone = {
            name = "Tankone",
            class = "WARRIOR",
            role = "TANK",
            deaths = 0,
            hasAddon = true,
            used = {
                {name="Shield Wall", spellID=871, time=55},
                {name="Last Stand", spellID=12975, time=230}
            }
        },
        Roguetest = {
            name = "Roguetest",
            class = "ROGUE",
            role = "DAMAGER",
            deaths = 1,
            deathTime = 315,
            hasAddon = false,
            used = {}
        },
        Healertwo = {
            name = "Healertwo",
            class = "DRUID",
            role = "HEALER",
            deaths = 0,
            hasAddon = true,
            used = {
                {name="Barkskin", spellID=22812, time=260}
            },
            debuffs = {
                {name="Test Debuff", spellID=209858, time=90}
            }
        }
    }

    MCA:ShowUI({
        type = "M+",
        boss = "Ara-Kara",
        result = true,
        duration = 1420,
        bosses = {
            {name="Avanoxx", success=true, startTime=20, endTime=90, duration=70},
            {name="Anub'zekt", success=true, startTime=210, endTime=280, duration=70},
            {name="Ki'katal", success=true, startTime=300, endTime=370, duration=70}
        },
        players = players,
        timeline = {
            {type="defensive", time=55, text="Tankone usa Shield Wall", spellID=871},
            {type="death", time=136, text="Coffettino muore"},
            {type="debuff", time=90, text="Healertwo prende Test Debuff", spellID=209858}
        }
    })
end

function MCA:MinimapButton_UpdatePosition()
    if not self.MinimapButton then return end

    local angle = MidnightCombatAnalyticsDB.config.minimapAngle or 225
    local radius = 80
    local rad = math.rad(angle)

    self.MinimapButton:SetPoint(
        "CENTER",
        Minimap,
        "CENTER",
        math.cos(rad) * radius,
        math.sin(rad) * radius
    )
end

function MCA:MinimapButton_SetShown(shown)
    MidnightCombatAnalyticsDB.config.minimapButtonShown = shown and true or false

    if self.MinimapButton then
        if shown then
            self.MinimapButton:Show()
            self:MinimapButton_UpdatePosition()
        else
            self.MinimapButton:Hide()
        end
    end
end

function MCA:MinimapMenu_Clear()
    if self.MinimapMenu and self.MinimapMenu.rows then
        for _, row in ipairs(self.MinimapMenu.rows) do
            row:Hide()
            row:SetParent(nil)
        end
        self.MinimapMenu.rows = {}
    end
end

function MCA:MinimapMenu_AddButton(text, y, onClick, color)
    local row = CreateFrame("Button", nil, self.MinimapMenu, "BackdropTemplate")
    row:SetPoint("TOPLEFT", 8, y)
    row:SetSize(210, 24)
    row:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1
    })
    row:SetBackdropColor(0.05, 0.05, 0.05, 0.82)
    row:SetBackdropBorderColor(0.22, 0.22, 0.22, 1)

    local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("LEFT", 8, 0)
    fs:SetWidth(190)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    if color then
        fs:SetTextColor(color[1], color[2], color[3])
    end

    row:SetScript("OnEnter", function()
        row:SetBackdropColor(0.16, 0.12, 0.03, 0.95)
        row:SetBackdropBorderColor(1, 0.75, 0, 1)
    end)

    row:SetScript("OnLeave", function()
        row:SetBackdropColor(0.05, 0.05, 0.05, 0.82)
        row:SetBackdropBorderColor(0.22, 0.22, 0.22, 1)
    end)

    row:SetScript("OnClick", function()
        if onClick then onClick() end
        if self.MinimapMenu then self.MinimapMenu:Hide() end
    end)

    table.insert(self.MinimapMenu.rows, row)
    return y - 28
end

function MCA:MinimapMenu_Rebuild()
    if not self.MinimapMenu then return end

    self:MinimapMenu_Clear()

    local y = -34

    local title = self.MinimapMenu:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetWidth(200)
    title:SetJustifyH("LEFT")
    title:SetText("Midnight Combat Analytics")
    table.insert(self.MinimapMenu.rows, title)

    y = self:MinimapMenu_AddButton("Apri UI", y, function()
        MCA:ShowUI(MCA:GetLastAvailableReport())
    end)
y = self:MinimapMenu_AddButton("Raid Buff Check", y, function()
        if MCA.ShowRaidBuffWindow then
            MCA:ShowRaidBuffWindow()
        end
    end, {0.78, 0.25, 1.0})

    y = self:MinimapMenu_AddButton("Storico", y, function()
        MCA.activeTab = "history"
        MCA:ShowUI(MCA:GetLastAvailableReport())
    end)

    y = self:MinimapMenu_AddButton("Export", y, function()
        MCA:ShowExportWindow(MCA.lastReport)
    end)

    y = self:MinimapMenu_AddButton("Share", y, function()
        MCA:ShareSummary(MCA.lastReport)
    end)

    y = y - 6

    y = self:MinimapMenu_AddButton(
        y,
        function()
            MidnightCombatAnalyticsDB.config.debug = not MidnightCombatAnalyticsDB.config.debug
            MCA:Print("Debug " .. (MidnightCombatAnalyticsDB.config.debug and "ON" or "OFF"))
        end,
        MidnightCombatAnalyticsDB.config.debug and {0.2, 1, 0.2} or {1, 0.35, 0.35}
    )

    y = self:MinimapMenu_AddButton(
        y,
        function()
            MidnightCombatAnalyticsDB.config.syncEnabled = not MidnightCombatAnalyticsDB.config.syncEnabled
            if MidnightCombatAnalyticsDB.config.syncEnabled then MCA:SendHello() end
            MCA:Print("Sync " .. (MidnightCombatAnalyticsDB.config.syncEnabled and "ON" or "OFF"))
        end,
        MidnightCombatAnalyticsDB.config.syncEnabled and {0.2, 1, 0.2} or {1, 0.35, 0.35}
    )

    y = self:MinimapMenu_AddButton(
        y,
        function()
            MidnightCombatAnalyticsDB.config.autoOpen = not MidnightCombatAnalyticsDB.config.autoOpen
            MCA:Print("Auto Open " .. (MidnightCombatAnalyticsDB.config.autoOpen and "ON" or "OFF"))
        end,
        MidnightCombatAnalyticsDB.config.autoOpen and {0.2, 1, 0.2} or {1, 0.35, 0.35}
    )

    y = self:MinimapMenu_AddButton(
        y,
        function()
            MidnightCombatAnalyticsDB.config.useElvUISkin = not MidnightCombatAnalyticsDB.config.useElvUISkin
            MCA:DetectElvUI()
            MCA:Print("ElvUI Skin " .. (MidnightCombatAnalyticsDB.config.useElvUISkin and "ON" or "OFF"))
        end,
        MidnightCombatAnalyticsDB.config.useElvUISkin and {0.2, 1, 0.2} or {1, 0.35, 0.35}
    )

    y = y - 6

        MCA:MinimapButton_SetShown(false)
        MCA:Print("Bottone minimappa nascosto. Usa /mdr minimap per riattivarlo.")
    end, {1, 0.65, 0.25})
end

function MCA:MinimapMenu_Toggle()
    if not self.MinimapMenu then return end

    if self.MinimapMenu:IsShown() then
        self.MinimapMenu:Hide()
    else
        self:MinimapMenu_Rebuild()
        self.MinimapMenu:ClearAllPoints()
        self.MinimapMenu:SetPoint("TOPRIGHT", self.MinimapButton, "BOTTOMLEFT", -4, -4)
        if self.MinimapMenu.blocker then self.MinimapMenu.blocker:Show() end
        self.MinimapMenu:Show()
    end
end

function MCA:CreateMinimapMenu()
    if self.MinimapMenu then return end

    local menu = CreateFrame("Frame", "MCAMinimapMenu", UIParent, "BackdropTemplate")
    menu:SetSize(228, 328)
    menu:SetFrameStrata("DIALOG")
    menu:SetFrameLevel(100)

    if UISpecialFrames then
        local found = false
        for _, frameName in ipairs(UISpecialFrames) do
            if frameName == "MCAMinimapMenu" then found = true break end
        end
        if not found then table.insert(UISpecialFrames, "MCAMinimapMenu") end
    end

    local blocker = CreateFrame("Button", "MCAMinimapMenuBlocker", UIParent)
    blocker:SetAllPoints(UIParent)
    blocker:SetFrameStrata("DIALOG")
    blocker:SetFrameLevel(90)
    blocker:EnableMouse(true)
    blocker:SetScript("OnClick", function()
        if MCA.MinimapMenu then MCA.MinimapMenu:Hide() end
    end)
    blocker:Hide()
    menu.blocker = blocker
    menu:SetScript("OnHide", function()
        if menu.blocker then menu.blocker:Hide() end
    end)
    menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1
    })
    menu:SetBackdropColor(0.02, 0.02, 0.02, 0.94)
    menu:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
    menu.rows = {}
    menu:Hide()

    self.MinimapMenu = menu
end

function MCA:CreateMinimapButton()
    if self.MinimapButton then return end

    local button = CreateFrame("Button", "MCAMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetPoint("TOPLEFT")
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Orb_05")

    button.icon = icon

    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            if MCA.lastReport then
                if MCA.ShowUI then MCA:ShowUI(MCA:GetLastAvailableReport()) end
            else
                MCA:Print("Nessun report disponibile.")
            end
        else
            MCA:MinimapMenu_Toggle()
        end
    end)

    button:SetScript("OnDragStart", function()
        button:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            px, py = px / scale, py / scale

            local angle = math.deg(math.atan2(py - my, px - mx))
            MidnightCombatAnalyticsDB.config.minimapAngle = angle
            MCA:MinimapButton_UpdatePosition()
        end)
    end)

    button:SetScript("OnDragStop", function()
        button:SetScript("OnUpdate", nil)
    end)

    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:SetText("Midnight Combat Analytics")
        GameTooltip:AddLine("Left click: menu", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right click: ultimo report", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Drag: sposta bottone", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self.MinimapButton = button
    self:CreateMinimapMenu()
    self:MinimapButton_UpdatePosition()

    if MidnightCombatAnalyticsDB.config.minimapButtonShown == false then
        button:Hide()
    else
        button:Show()
    end
end
