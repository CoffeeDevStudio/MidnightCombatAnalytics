_G.MCA = _G.MCA or {}
MCA = _G.MCA

function MCA:IsRaidLeadOrAssist()
    if not IsInGroup or not IsInGroup() then return true end
    if UnitIsGroupLeader and UnitIsGroupLeader("player") then return true end
    if UnitIsGroupAssistant and UnitIsGroupAssistant("player") then return true end
    return false
end

function MCA:DoRaidReadyCheck()
    if not self:IsRaidLeadOrAssist() then
        self:Print("Devi essere Raid Leader o Assist.")
        return
    end

    if DoReadyCheck then
        DoReadyCheck()
    end
end

function MCA:DoPullCountdown10()
    if not self:IsRaidLeadOrAssist() then
        self:Print("Devi essere Raid Leader o Assist.")
        return
    end

    if C_PartyInfo and C_PartyInfo.DoCountdown then
        C_PartyInfo.DoCountdown(10)
        return
    end

    if SlashCmdList then
        if SlashCmdList.DBMPULL then
            SlashCmdList.DBMPULL("10")
            return
        end

        if SlashCmdList.DEADLYBOSSMODS then
            SlashCmdList.DEADLYBOSSMODS("pull 10")
            return
        end

        if SlashCmdList.BIGWIGS then
            SlashCmdList.BIGWIGS("pull 10")
            return
        end

        if SlashCmdList.BW then
            SlashCmdList.BW("pull 10")
            return
        end
    end

    if IsInRaid and IsInRaid() then
        SendChatMessage("Pull in 10", "RAID")
    elseif IsInGroup and IsInGroup() then
        SendChatMessage("Pull in 10", "PARTY")
    else
        self:Print("Pull in 10")
    end
end


function MCA:HideRaidBuffWindowForPull()
    self:StopRaidBuffLiveTracking(true)

    if self.RaidBuffFrame then
        self.RaidBuffFrame:Hide()
    end
end

function MCA:CloseRaidBuffWindow()
    self:StopRaidBuffLiveTracking(false)

    if self.RaidBuffFrame then
        self.RaidBuffFrame:Hide()
    end
end

function MCA:StartRaidBuffLiveTracking()
    if self.RaidBuffLiveFrame then
        self.RaidBuffLiveFrame:Show()
        return
    end

    local f = CreateFrame("Frame")
    f.elapsed = 0

    f:SetScript("OnUpdate", function(frame, elapsed)
        frame.elapsed = (frame.elapsed or 0) + elapsed
        if frame.elapsed < 1.0 then return end
        frame.elapsed = 0

        if InCombatLockdown and InCombatLockdown() then
            MCA:StopRaidBuffLiveTracking(true)
            return
        end

        if not MCA.RaidBuffFrame or not MCA.RaidBuffFrame:IsShown() then
            MCA:StopRaidBuffLiveTracking(false)
            return
        end

        MCA:RefreshRaidBuffWindowLive()
    end)

    self.RaidBuffLiveFrame = f
end

function MCA:StopRaidBuffLiveTracking(markStopped)
    if self.RaidBuffLiveFrame then
        self.RaidBuffLiveFrame:Hide()
    end

    self.raidBuffLiveStopped = markStopped and true or false

    if self.RaidBuffStatusText then
        if markStopped then
            self.RaidBuffStatusText:SetText("Live tracking fermato: pull iniziato")
            self.RaidBuffStatusText:SetTextColor(1, 0.55, 0)
        else
            self.RaidBuffStatusText:SetText("Live tracking fermato")
            self.RaidBuffStatusText:SetTextColor(0.68, 0.68, 0.68)
        end
    end
end

function MCA:ShowRaidBuffWindow()
    if InCombatLockdown and InCombatLockdown() then
        self:Print("Buff Raid disponibile solo fuori combat.")
        return
    end

    self.raidBuffLiveStopped = false

    local buffs, matrix = self:CaptureRaidBuffs()
    self.liveRaidBuffs = buffs or {}
    self.liveRaidBuffMatrix = matrix or { buffs = {}, players = {} }

    self:BuildRaidBuffWindow(self.liveRaidBuffMatrix)
    self:StartRaidBuffLiveTracking()

end
function MCA:RefreshRaidBuffWindowLive()
    if InCombatLockdown and InCombatLockdown() then
        self:StopRaidBuffLiveTracking(true)
        return
    end

    local buffs, matrix = self:CaptureRaidBuffs()
    self.liveRaidBuffs = buffs or {}
    self.liveRaidBuffMatrix = matrix or { buffs = {}, players = {} }

    if self.RaidBuffFrame and self.RaidBuffFrame:IsShown() then
        self:RedrawRaidBuffMatrix(self.liveRaidBuffMatrix)
    end

end
function MCA:BuildRaidBuffWindow(matrix)
    if self.RaidBuffFrame then
        self.RaidBuffFrame:Hide()
        self.RaidBuffFrame:SetParent(nil)
        self.RaidBuffFrame = nil
    end

    local f = CreateFrame("Frame", "MCARaidBuffFrame", UIParent, "BackdropTemplate")
    f:SetSize(1180, 640)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(120)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    self:SetBackdropSolid(f, self:UIColor("bg"), {0.28, 0.28, 0.30, 1})

    self:Text(f, "Raid Buff Check", "GameFontHighlightLarge", {"TOP", f, "TOP", 0, -12}, 360, self:UIColor("accent"), "CENTER")
    self:Text(f, "Live pre-pull: class buffs + consumables. Stop automatico al pull.", "GameFontNormalSmall", {"TOP", f, "TOP", 0, -34}, 700, self:UIColor("gray"), "CENTER")

    if self:IsRaidLeadOrAssist() then
        self:Button(f, "Ready Check", {"TOPLEFT", f, "TOPLEFT", 20, -16}, 120, 28, function()
            MCA:DoRaidReadyCheck()
        end)

        self:Button(f, "Pull 10", {"TOPLEFT", f, "TOPLEFT", 148, -16}, 90, 28, function()
            MCA:DoPullCountdown10()
        end)
    end

    self.RaidBuffSummaryText = self:Text(f, "", "GameFontNormal", {"TOPLEFT", f, "TOPLEFT", 20, -58}, 520, self:UIColor("green"))
    self.RaidBuffStatusText = self:Text(f, "Live tracking attivo", "GameFontNormal", {"TOPRIGHT", f, "TOPRIGHT", -20, -58}, 360, self:UIColor("green"), "RIGHT")

    local _, child, scroll = self:Scroll(f, {"TOPLEFT", f, "TOPLEFT", 18, -84}, 1144, 490, {0.018, 0.020, 0.022, 0.55})
    self.RaidBuffScrollChild = child
    self.RaidBuffScroll = scroll
    self.RaidBuffFrame = f

    self:RedrawRaidBuffMatrix(matrix)

    self:Button(f, "Chiudi", {"BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 16}, 120, 30, function()
        MCA:CloseRaidBuffWindow()
    end)

    f:Show()

end
function MCA:BuffStatusIcon(parent, x, y, size, hasBuff)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", x, y)
    tex:SetSize(size or 18, size or 18)

    if hasBuff == true then
        tex:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        tex:SetVertexColor(0.1, 1.0, 0.1, 1)
    elseif hasBuff == false then
        tex:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
        tex:SetVertexColor(1.0, 0.1, 0.1, 1)
    else
        tex:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
        tex:SetVertexColor(0.45, 0.45, 0.45, 0.55)
    end

    return tex
end

function MCA:ClearRaidBuffRows()
    if not self.RaidBuffRows then return end

    for _, frame in ipairs(self.RaidBuffRows) do
        if frame then
            frame:Hide()
            frame:SetParent(nil)
        end
    end

    self.RaidBuffRows = {}
end

function MCA:RedrawRaidBuffMatrix(matrix)
    if not self.RaidBuffScrollChild then return end

    self:ClearRaidBuffRows()
    self.RaidBuffRows = {}

    local summary = self:GetLiveRaidBuffSummary(matrix)

    if self.RaidBuffSummaryText then
        self.RaidBuffSummaryText:SetText("Checklist OK: " .. summary.ok .. "/" .. summary.total .. "    Missing: " .. summary.missing)
        if summary.missing > 0 then
            self.RaidBuffSummaryText:SetTextColor(1, 0.55, 0)
        else
            self.RaidBuffSummaryText:SetTextColor(0.2, 1, 0.2)
        end
    end

    if self.RaidBuffStatusText and not self.raidBuffLiveStopped then
        self.RaidBuffStatusText:SetText("Live tracking attivo")
        self.RaidBuffStatusText:SetTextColor(0.2, 1, 0.2)
    end

    self:DrawRaidBuffMatrixContent(self.RaidBuffScrollChild, self.RaidBuffScroll, matrix, 1144)
end

function MCA:GetLiveRaidBuffSummary(matrix)
    local total, ok, missing = 0, 0, 0

    for _, player in ipairs((matrix and matrix.players) or {}) do
        for _, buff in ipairs((matrix and matrix.buffs) or {}) do
            if buff.classPresent then
                total = total + 1
                local has = player.buffs and player.buffs[buff.key]
                if has == true then
                    ok = ok + 1
                elseif has == false then
                    missing = missing + 1
                end
            end
        end
    end

    return {
        total = total,
        ok = ok,
        missing = missing
    }
end

function MCA:DrawRaidBuffMatrixContent(child, scroll, matrix, width)
    matrix = matrix or { buffs = {}, players = {} }

    local buffs = {}
    for _, buff in ipairs(matrix.buffs or {}) do
        if buff.classPresent then
            table.insert(buffs, buff)
        end
    end

    local playerColW = 220
    local roleColW = 58
    local availableW = math.max((width or 1144) - 34, 780)
    local fixedW = playerColW + roleColW + 20
    local buffColW = 42

    if #buffs > 0 then
        buffColW = math.floor((availableW - fixedW) / #buffs)
        if buffColW < 36 then buffColW = 36 end
        if buffColW > 46 then buffColW = 46 end
    end

    local tableW = playerColW + roleColW + (#buffs * buffColW) + 20
    child:SetWidth(math.max(tableW, availableW))

    local header = CreateFrame("Frame", nil, child, "BackdropTemplate")
    header:SetPoint("TOPLEFT", 0, -2)
    header:SetSize(child:GetWidth(), 34)
    self:SetBackdropSolid(header, {0.025, 0.027, 0.030, 0.95}, {0.16, 0.17, 0.18, 1})
    table.insert(self.RaidBuffRows, header)

    self:Text(header, "Player", "GameFontHighlightSmall", {"LEFT", header, "LEFT", 10, 0}, playerColW - 10, self:UIColor("white"))
    self:Text(header, "Ruolo", "GameFontHighlightSmall", {"LEFT", header, "LEFT", playerColW, 0}, roleColW, self:UIColor("white"), "CENTER")

    local x = playerColW + roleColW
    for _, buff in ipairs(buffs) do
        local cell = CreateFrame("Frame", nil, header)
        cell:SetPoint("TOPLEFT", x, 0)
        cell:SetSize(buffColW, 34)

        local icon = cell:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOP", cell, "TOP", 0, -2)
        icon:SetSize(18, 18)
        icon:SetTexture(buff.icon or "Interface\\Icons\\INV_Misc_QuestionMark")

        self:Text(cell, buff.short or buff.name or "Buff", "GameFontNormalSmall", {"BOTTOM", cell, "BOTTOM", 0, 1}, buffColW, buff.optional and self:UIColor("gray") or self:UIColor("white"), "CENTER")

        x = x + buffColW
    end

    local y = -38
    local players = matrix.players or {}

    table.sort(players, function(a, b)
        local ar = a.role or ""
        local br = b.role or ""
        if ar == br then
            return (a.name or "") < (b.name or "")
        end
        return ar < br
    end)

    for i, player in ipairs(players) do
        local row = CreateFrame("Frame", nil, child, "BackdropTemplate")
        row:SetPoint("TOPLEFT", 0, y)
        row:SetSize(child:GetWidth(), 30)
        self:SetBackdropSolid(row, i % 2 == 0 and self:UIColor("rowAlt") or self:UIColor("row"), {0.12, 0.13, 0.14, 1})
        table.insert(self.RaidBuffRows, row)

        self:ClassIcon(row, player.class, 10, -6, 18)
        self:Text(row, player.name or "?", "GameFontNormal", {"LEFT", row, "LEFT", 36, 0}, playerColW - 40, self:UIColor("accent"))
        self:Text(row, self:RoleShort(player.role), "GameFontNormalSmall", {"LEFT", row, "LEFT", playerColW, 0}, roleColW, self:UIColor("white"), "CENTER")

        x = playerColW + roleColW
        for _, buff in ipairs(buffs) do
            local has = player.buffs and player.buffs[buff.key]
            self:BuffStatusIcon(row, x + math.floor((buffColW - 16) / 2), -7, 16, has)
            x = x + buffColW
        end

        y = y - 30
    end

    if #players == 0 then
        local empty = self:Text(child, "Nessun player rilevato. Entra in party/raid.", "GameFontNormal", {"TOPLEFT", child, "TOPLEFT", 14, -44}, 500, self:UIColor("gray"))
        table.insert(self.RaidBuffRows, empty)
    end

    self:UpdateScrollBar(child, scroll, math.abs(y) + 48)
end


