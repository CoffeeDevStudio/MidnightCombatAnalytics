-- Parse.lua
-- Computes an approximate local "parse" percentile using MCA_Benchmarks
-- (generated externally by generate_benchmarks.py from Warcraft Logs data).
--
-- The parse is an APPROXIMATION and is prefixed with "~" everywhere it is shown.
-- It matches the report's difficulty + encounter to the corresponding
-- className-specName entry in MCA_Benchmarks, then interpolates linearly
-- between the stored anchor percentiles (median = 50, p75, p95, top = 99).
-- When the player's spec is unknown we fall back to the average of all specs
-- of the same class + role available in the DB.

_G.MCA = _G.MCA or {}
MCA = _G.MCA

-- Blizzard raid difficultyID -> Warcraft Logs difficulty ID.
-- (Bliz Normal=14, Heroic=15, Mythic=16 -> WCL 3, 4, 5.)
local BLIZ_TO_WCL_DIFFICULTY = {
    [14] = 3, [15] = 4, [16] = 5,
    [23] = 5, -- Mythic dungeon end-of-run counted as mythic for reference
}

-- Difficulty NAME (as MCA stores it in the report) -> WCL difficulty ID.
local NAME_TO_WCL_DIFFICULTY = {
    ["normal"]  = 3,
    ["heroic"]  = 4,
    ["mythic"]  = 5,
    ["lfr"]     = 3, -- no LFR ranking, best fallback
}

-- Blizzard class token -> WCL className (PascalCase, no spaces).
local CLASS_TOKEN_TO_WCL = {
    DEATHKNIGHT = "DeathKnight",
    DEMONHUNTER = "DemonHunter",
    DRUID       = "Druid",
    EVOKER      = "Evoker",
    HUNTER      = "Hunter",
    MAGE        = "Mage",
    MONK        = "Monk",
    PALADIN     = "Paladin",
    PRIEST      = "Priest",
    ROGUE       = "Rogue",
    SHAMAN      = "Shaman",
    WARLOCK     = "Warlock",
    WARRIOR     = "Warrior",
}

-- Blizzard specID -> WCL specName. Not exhaustive; the fallback (class-avg)
-- kicks in for any spec not listed here.
local SPEC_ID_TO_WCL = {
    [250] = "Blood",        [251] = "Frost",         [252] = "Unholy",         -- DK
    [577] = "Havoc",        [581] = "Vengeance",                                -- DH
    [102] = "Balance",      [103] = "Feral",         [104] = "Guardian",       [105] = "Restoration",  -- Druid
    [1467] = "Devastation", [1468] = "Preservation", [1473] = "Augmentation",  -- Evoker
    [253] = "Beast Mastery",[254] = "Marksmanship",  [255] = "Survival",       -- Hunter
    [62]  = "Arcane",       [63]  = "Fire",          [64]  = "Frost",          -- Mage
    [268] = "Brewmaster",   [269] = "Windwalker",    [270] = "Mistweaver",     -- Monk
    [65]  = "Holy",         [66]  = "Protection",    [70]  = "Retribution",    -- Paladin
    [256] = "Discipline",   [257] = "Holy",          [258] = "Shadow",         -- Priest
    [259] = "Assassination",[260] = "Outlaw",        [261] = "Subtlety",       -- Rogue
    [262] = "Elemental",    [263] = "Enhancement",   [264] = "Restoration",    -- Shaman
    [265] = "Affliction",   [266] = "Demonology",    [267] = "Destruction",    -- Warlock
    [71]  = "Arms",         [72]  = "Fury",          [73]  = "Protection",     -- Warrior
}

-- Public: convert Blizzard specID to WCL specName. Nil if unknown.
function MCA:SpecIDToWCLName(specID)
    if not specID then return nil end
    return SPEC_ID_TO_WCL[tonumber(specID) or -1]
end

-- Map the report's difficulty (string or numeric) to the WCL difficulty id.
-- The string match is intentionally fuzzy (substring): the addon may store
-- difficulty as "Mythic", "Mythic+", "Raid Mythic", "Raid Mythic - Flexible
-- Raiding" (12.0.7 Sporefall flex), or localized variants — all of these
-- should still map to the correct WCL difficulty bucket.
function MCA:GetReportWCLDifficulty(data)
    if not data then return nil end
    local d = data.difficulty
    if type(d) == "number" then
        return BLIZ_TO_WCL_DIFFICULTY[d]
    end
    if type(d) == "string" then
        local lower = d:lower()

        -- Exact-match first (fast path, keeps old behavior).
        local exact = NAME_TO_WCL_DIFFICULTY[lower]
        if exact then return exact end

        -- Fuzzy: substring match, in specificity order (Mythic before Heroic
        -- before Normal, because "mythic" trumps a stray "normal" tag).
        if lower:find("mythic", 1, true) then return 5 end
        if lower:find("heroic", 1, true) then return 4 end
        if lower:find("normal", 1, true) then return 3 end
        if lower:find("lfr", 1, true) or lower:find("finder", 1, true) then return 3 end
    end
    return nil
end

-- Fetch the encounter table matching this report (raid only for now).
local function getEncounterEntry(data)
    if not MCA_Benchmarks or not MCA_Benchmarks.encounters then return nil end
    if not data or data.type ~= "raid" then return nil end
    local encID = data.encounterID
    if not encID then return nil end
    return MCA_Benchmarks.encounters[encID]
end

-- Percentile keys the v3 generator writes into each spec entry, from top to
-- bottom. Also drives the class-fallback aggregation below. The addon reads
-- MCA_Benchmarks.percentiles if present, otherwise falls back to this list.
local DEFAULT_CURVE_PERCENTILES = {99, 95, 90, 85, 75, 65, 50, 40, 30, 20, 10, 5, 1}

local function getCurvePercentiles()
    if MCA_Benchmarks and type(MCA_Benchmarks.percentiles) == "table"
       and #MCA_Benchmarks.percentiles > 0 then
        return MCA_Benchmarks.percentiles
    end
    return DEFAULT_CURVE_PERCENTILES
end

-- Detect whether a ref uses the v3 curve (multiple pXX fields) or the older
-- v2 4-anchor shape (top/p95/p75/median).
local function refHasCurve(ref)
    if not ref then return false end
    local pcts = getCurvePercentiles()
    for _, p in ipairs(pcts) do
        if ref["p" .. p] then return true end
    end
    return false
end

-- Interpolate value against a v3 percentile curve. Percentiles are in the
-- ref as keys "p99", "p95", ... in decreasing order matching decreasing DPS.
-- Returns 0..99.
local function percentileFromCurve(value, ref)
    if not ref or not value or value <= 0 then return 0 end
    local pcts = getCurvePercentiles()

    -- Build ordered anchor list [{p=99, v=top}, {p=95, v=...}, ...] using
    -- only percentiles that actually have a value in this ref.
    local anchors = {}
    -- Top anchor (>= p99 value) — always add so the "top" ceiling clamps.
    if ref.top and ref.top > 0 then
        anchors[#anchors + 1] = { p = 99, v = ref.top }
    end
    for _, p in ipairs(pcts) do
        local v = ref["p" .. p]
        if type(v) == "number" and v > 0 then
            -- Overwrite the top anchor's p99 if we also have an explicit p99.
            if p == 99 and #anchors > 0 and anchors[1].p == 99 then
                anchors[1].v = v
            else
                anchors[#anchors + 1] = { p = p, v = v }
            end
        end
    end

    if #anchors == 0 then return 0 end

    -- Anchors are ordered by descending percentile (99 first, then 95, 90,
    -- ..., 1) and each anchor's DPS should also be descending because higher
    -- percentile = better rank = higher DPS.
    if value >= anchors[1].v then
        return anchors[1].p
    end

    -- Find the bracket [hi, lo] such that lo.v <= value < hi.v.
    for i = 1, #anchors - 1 do
        local hi = anchors[i]
        local lo = anchors[i + 1]
        if value < hi.v and value >= lo.v then
            local span = hi.v - lo.v
            if span <= 0 then return lo.p end
            local t = (value - lo.v) / span
            return math.floor(lo.p + t * (hi.p - lo.p) + 0.5)
        end
    end

    -- Value is below the lowest anchor: linearly to 0 from the lowest bucket.
    local lowest = anchors[#anchors]
    if lowest.v <= 0 then return 0 end
    return math.floor(lowest.p * (value / lowest.v) + 0.5)
end

-- v2 fallback: interpolate against 4 anchors (top / p95 / p75 / median).
-- Used only if the loaded MCA_Benchmarks is an older schema.
local function percentileFromAnchors(value, ref)
    if not ref or not value or value <= 0 then return 0 end
    local median, p75, p95, top = ref.median, ref.p75, ref.p95, ref.top
    if not (median and p75 and p95 and top) then return 0 end

    if value >= top then
        return 99
    elseif value >= p95 then
        local span = top - p95
        if span <= 0 then return 95 end
        return math.floor(95 + ((value - p95) / span) * 4 + 0.5)
    elseif value >= p75 then
        local span = p95 - p75
        if span <= 0 then return 75 end
        return math.floor(75 + ((value - p75) / span) * 20 + 0.5)
    elseif value >= median then
        local span = p75 - median
        if span <= 0 then return 50 end
        return math.floor(50 + ((value - median) / span) * 25 + 0.5)
    else
        if median <= 0 then return 0 end
        return math.floor((value / median) * 50 + 0.5)
    end
end

local function computePercentile(value, ref)
    if refHasCurve(ref) then
        return percentileFromCurve(value, ref)
    end
    return percentileFromAnchors(value, ref)
end

-- Given a class token (WoW) + role, return the aggregated reference by
-- averaging every spec entry of that class in the wanted metric.
-- Used when the player's specific spec is not known. Handles both the v2
-- 4-anchor schema and the v3 percentile-curve schema transparently by
-- averaging whatever numeric fields it finds.
local function classFallbackRef(diffEntry, wclClass, wantMetric)
    if not diffEntry then return nil end
    local prefix = wclClass .. "-"
    local sums, count = {}, 0

    for key, ref in pairs(diffEntry) do
        if type(key) == "string" and key:sub(1, #prefix) == prefix and ref.metric == wantMetric then
            count = count + 1
            for k, v in pairs(ref) do
                if type(v) == "number" then
                    sums[k] = (sums[k] or 0) + v
                end
            end
        end
    end

    if count == 0 then return nil end

    local avg = { metric = wantMetric, sample = count }
    for k, total in pairs(sums) do
        avg[k] = total / count
    end
    return avg
end

-- Public: get the reference row {top,p95,p75,median,metric} for a player
-- inside a given report. Returns nil if we can't match the report to the DB.
function MCA:GetBenchmarkRef(player, data)
    if not player or not data then return nil end

    local enc = getEncounterEntry(data)
    if not enc or not enc.difficulties then return nil end

    local wclDiff = self:GetReportWCLDifficulty(data)
    if not wclDiff then return nil end

    local diffEntry = enc.difficulties[wclDiff]
    if not diffEntry then return nil end

    local wclClass = CLASS_TOKEN_TO_WCL[tostring(player.class or ""):upper()]
    if not wclClass then return nil end

    local wantMetric = (tostring(player.role or ""):upper() == "HEALER") and "hps" or "dps"

    -- Try exact spec match first.
    local specName = player.wclSpec or self:SpecIDToWCLName(player.specID)
    if specName then
        local key = wclClass .. "-" .. specName
        local ref = diffEntry[key]
        if ref and ref.metric == wantMetric then
            return ref, "spec"
        end
    end

    -- Fall back to class-average for the wanted metric.
    local ref = classFallbackRef(diffEntry, wclClass, wantMetric)
    if ref then return ref, "class-avg" end

    return nil
end

-- Public: compute the local approximate parse for a player inside a report.
-- Returns (parse, source) where source is "spec", "class-avg", or nil.
function MCA:ComputeLocalParse(player, data)
    local ref, source = self:GetBenchmarkRef(player, data)
    if not ref then return nil, nil end

    local value
    if self.GetFightMetric then
        value = self:GetFightMetric(player)
    end
    if not value or value <= 0 then return 0, source end

    return computePercentile(value, ref), source
end

-- Public: parse color, mirrors the WCL palette used by GetRatingColor.
function MCA:GetParseColor(parse)
    parse = tonumber(parse or 0) or 0
    if parse >= 99 then return {0.886, 0.408, 1.000, 1} end -- pink
    if parse >= 95 then return {1.000, 0.502, 0.000, 1} end -- orange
    if parse >= 75 then return {0.639, 0.208, 0.933, 1} end -- purple
    if parse >= 50 then return {0.000, 0.439, 0.867, 1} end -- blue
    if parse >= 25 then return {0.118, 1.000, 0.000, 1} end -- green
    return {0.616, 0.616, 0.616, 1} -- gray
end

-- Public: formatted display string. Always prefixed with "~" to signal that
-- the value is a local approximation, not a real WarcraftLogs parse.
--   "-" if we can't compute (no benchmarks for this encounter/difficulty)
--   "~72"  otherwise
function MCA:FormatParse(parse, hasRef)
    if hasRef == false then return "-" end
    if not parse then return "-" end
    return "~" .. tostring(parse)
end

-- Public one-stop helper for renderers. Returns:
--   value (number 0..99), color ({r,g,b,a}), display (string, "~NN" or NN%), source
-- Source is "benchmark" when it comes from MCA_Benchmarks, "relative" when
-- it falls back to the previous in-group relative rating.
function MCA:ResolvePlayerParse(player, data)
    -- Try real (approximate) parse first.
    local parse, source = self:ComputeLocalParse(player, data)
    if parse and source then
        local color = self:GetParseColor(parse)
        return parse, color, self:FormatParse(parse, true), "benchmark"
    end

    -- Fall back to the in-group relative rating.
    local metricValue = self.GetFightMetric and self:GetFightMetric(player) or 0
    local rating = 0
    if metricValue and metricValue > 0 then
        rating = (player.mcaRating or (self.GetScore and self:GetScore(player)) or 0)
    end
    local color = self.GetRatingColor and self:GetRatingColor(rating) or {1,1,1,1}
    return rating, color, tostring(rating), "relative"
end
