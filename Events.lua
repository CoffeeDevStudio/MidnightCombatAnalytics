_G.MCA = _G.MCA or {}
MCA = _G.MCA

local f = CreateFrame("Frame")
MCA.EventFrame = f

local events = {
    "PLAYER_LOGIN",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_LEAVING_WORLD",
    "GROUP_ROSTER_UPDATE",
    "ENCOUNTER_START",
    "ENCOUNTER_END",
    "CHALLENGE_MODE_START",
    "CHALLENGE_MODE_COMPLETED",
    "CHALLENGE_MODE_RESET",
    "CHAT_MSG_ADDON",
    "PLAYER_DEAD",
    "UNIT_HEALTH",
    "UNIT_SPELLCAST_SUCCEEDED"
}

for _, event in ipairs(events) do
    f:RegisterEvent(event)
end

f:SetScript("OnEvent", function(_, event, ...)
    if MCA[event] then
        local ok, err = pcall(MCA[event], MCA, ...)
        if not ok then
            MCA:Debug("Event error in " .. tostring(event) .. ": " .. tostring(err))
        end
    end
end)

-- SafeFight:
-- No OnUpdate aura/debuff polling in combat.
-- This avoids raid-wide Lua error spam on Midnight aura APIs.

function MCA:PLAYER_LOGIN()
    self:InitSync()
    self:DetectElvUI()
    self:UpdateRoster()
    if self.CreateMinimapButton then self:CreateMinimapButton() end
    self:Print("Loaded v" .. self.VERSION .. " SafeFight")
end

function MCA:PLAYER_ENTERING_WORLD()
    self:UpdateRoster()

    C_Timer.After(2, function()
        if MCA and MCA.SendHello then
            MCA:SendHello()
        end
    end)
end

function MCA:GROUP_ROSTER_UPDATE()
    self:UpdateRoster()
    self:SendHello()
end

function MCA:ENCOUNTER_START(id, name)
    if self.HideRaidBuffWindowForPull then self:HideRaidBuffWindowForPull() end
    self:StartRaidEncounter(id, name)
end

function MCA:ENCOUNTER_END(id, name, diff, size, success)
    -- 4.0.28: wait briefly so Blizzard Damage Meter finalizes the encounter data.
    C_Timer.After(1.0, function()
        if MCA and MCA.FinishRaidEncounter then
            MCA:FinishRaidEncounter(id, name, success)
        end
    end)
end

function MCA:CHALLENGE_MODE_START()
    if self.HideRaidBuffWindowForPull then self:HideRaidBuffWindowForPull() end
    self:StartMythicPlusSession()
end

function MCA:CHALLENGE_MODE_COMPLETED()
    -- 4.0.28: wait briefly so Blizzard Damage Meter finalizes the run data.
    C_Timer.After(1.0, function()
        if MCA and MCA.FinishMythicPlusSession then
            MCA:FinishMythicPlusSession(true)
        end
    end)
end

function MCA:CHALLENGE_MODE_RESET()
    -- MCA: fires both on key abandon/surrender and on normal key reset.
    -- The run is over either way, so close it out as a completed (failed)
    -- session and show the report immediately, instead of waiting on a
    -- combat-lockdown check that may never resolve before the instance
    -- teleports the player out.
    self:FinishMythicPlusSession(false, true)
end

function MCA:PLAYER_LEAVING_WORLD()
    -- MCA: safety net for the "vote to abandon" feature. A successful abandon
    -- vote teleports the whole group out of the instance and does NOT reliably
    -- fire CHALLENGE_MODE_RESET (or fires it after the player has already left
    -- the challenge map), so the run was never being closed and the report
    -- only surfaced when the next key started. If we still have an active M+
    -- session when we leave the world, finalize it as a failed run now.
    --
    -- Guard: skip if the challenge mode is still active on this map (e.g. the
    -- player just did a /reload inside the dungeon), so we don't wrongly close
    -- a run that is actually still going.
    if not (self.session and self.session.type == "M+") then return end

    local stillActive = false
    if C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID then
        local ok, mapID = pcall(C_ChallengeMode.GetActiveChallengeMapID)
        if ok and mapID then stillActive = true end
    end

    if not stillActive then
        self:FinishMythicPlusSession(false, true)
    end
end


function MCA:PLAYER_REGEN_DISABLED()
    if self.HideRaidBuffWindowForPull then self:HideRaidBuffWindowForPull() elseif self.StopRaidBuffLiveTracking then self:StopRaidBuffLiveTracking(true) end
end
