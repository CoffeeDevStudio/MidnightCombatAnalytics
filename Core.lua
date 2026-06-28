
-- v4.0.0 rebrand compatibility / saved variable migration
_G.MidnightCombatAnalyticsDB = _G.MidnightCombatAnalyticsDB or _G.MidnightDefensiveReviewDB or {}
MCA = _G.MCA or MCA or {}
_G.MCA = MCA

-- Temporary compatibility alias for old external references during transition.
_G.MDR = _G.MDR or MCA

MCA.VERSION = "4.0.30"
MCA.PREFIX = "MCA40"

_G.MCA = _G.MCA or {}
MCA = _G.MCA

MCA.VERSION = "4.0.30"
MCA.PREFIX = "MCA40"

MCA.session = nil
MCA.roster = {}
MCA.guidToName = {}
MCA.lastReport = nil
MCA.selectedPlayer = nil
MCA.activeTab = "summary"

MidnightCombatAnalyticsDB = MidnightCombatAnalyticsDB or {}
MidnightCombatAnalyticsDB.history = MidnightCombatAnalyticsDB.history or {}
MidnightCombatAnalyticsDB.config = MidnightCombatAnalyticsDB.config or {}

local defaults = {
    showAfterKill = true,
    showAfterWipe = true,
    showMythicEnd = true,
    syncEnabled = true,
    debug = false,
    useElvUISkin = true,
    autoOpen = true,
    minimapButtonShown = true,
    minimapAngle = 225,
    historyLimit = 50
}

for k, v in pairs(defaults) do
    if MidnightCombatAnalyticsDB.config[k] == nil then
        MidnightCombatAnalyticsDB.config[k] = v
    end
end

function MCA:Print(msg)
    print("|cff00ccff[MCA]|r " .. tostring(msg))
end

function MCA:Debug(msg)
    if MidnightCombatAnalyticsDB.config.debug then
        print("|cffffaa00[MCA DEBUG]|r " .. tostring(msg))
    end
end


SLASH_MIDNIGHTCOMBATANALYTICS1 = "/mca"
SlashCmdList["MIDNIGHTCOMBATANALYTICS"] = function(msg)
    msg = string.lower(tostring(msg or ""))

    if msg == "raidbuff" or msg == "buff" then
        if MCA and MCA.ShowRaidBuffWindow then MCA:ShowRaidBuffWindow() end
        return
    end

    if MCA and MCA.ShowUI then
        if MCA.GetLastAvailableReport then
            MCA:ShowUI(MCA:GetLastAvailableReport())
        else
            MCA:ShowUI(MCA.lastReport)
        end
    end
end





