_G.MCA = _G.MCA or {}
MCA = _G.MCA

function MCA:DetectElvUI()
    self.ElvUI = nil
    self.ElvUISkins = nil

    if ElvUI then
        local ok, E = pcall(function()
            return unpack(ElvUI)
        end)

        if ok then
            self.ElvUI = E
            self.ElvUISkins = E and E.GetModule and E:GetModule("Skins", true)
        end
    end
end

function MCA:IsElvUIAvailable()
    return MidnightCombatAnalyticsDB.config.useElvUISkin and self.ElvUI ~= nil
end

function MCA:ApplyFrameStyle(frame)
    if self:IsElvUIAvailable() and frame.SetTemplate then
        frame:SetTemplate("Transparent")
        return
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1
    })
    frame:SetBackdropColor(0.02, 0.02, 0.02, 0.88)
    frame:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
end

function MCA:ApplyInsetStyle(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1
    })
    frame:SetBackdropColor(0.03, 0.03, 0.03, 0.84)
    frame:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
end

function MCA:ApplyButtonStyle(button)
    if self:IsElvUIAvailable() and self.ElvUISkins and self.ElvUISkins.HandleButton then
        self.ElvUISkins:HandleButton(button)
    end
end

function MCA:ApplyScrollBarStyle(scrollBar)
    if self:IsElvUIAvailable() and self.ElvUISkins and self.ElvUISkins.HandleScrollBar then
        self.ElvUISkins:HandleScrollBar(scrollBar)
    end
end
