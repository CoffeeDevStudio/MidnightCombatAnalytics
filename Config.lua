SLASH_MCA1 = "/mca"
SLASH_MCA2 = "/mdr"
SlashCmdList["MCA"] = function(msg) if MCA and MCA.HandleSlash then MCA:HandleSlash(msg) end end

_G.MCA = _G.MCA or {}
MCA = _G.MCA

SLASH_MDR1 = "/mdr"

SlashCmdList["MCA"] = function(msg)
    msg = msg or ""

    if msg == "test" or msg == "mplus test" then
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
            difficulty = "Mythic+",
            result = true,
            duration = 1420,
            bosses = {
                {name="Avanoxx", success=true, startTime=20, endTime=90, duration=70},
                {name="Anub'zekt", success=true, startTime=210, endTime=280, duration=70},
                {name="Ki'katal", success=true, startTime=300, endTime=370, duration=70}
            },
            players = players,
            raidBuffs = {
                {key="arcane_intellect", class="MAGE", spellID=1459, name="Arcane Intellect", short="Int", classPresent=true, total=4, missing=0, active=true},
                {key="battle_shout", class="WARRIOR", spellID=6673, name="Battle Shout", short="BS", classPresent=true, total=4, missing=0, active=true},
                {key="mark_of_the_wild", class="DRUID", spellID=1126, name="Mark of the Wild", short="Mark", classPresent=true, total=4, missing=1, active=false},
                {key="power_word_fortitude", class="PRIEST", spellID=21562, name="Power Word: Fortitude", short="Fort", classPresent=false, total=4, missing=4, active=false}
            },
            raidBuffMatrix = {
                buffs = {
                    {key="arcane_intellect", class="MAGE", spellID=1459, name="Arcane Intellect", short="Int", classPresent=true},
                    {key="battle_shout", class="WARRIOR", spellID=6673, name="Battle Shout", short="BS", classPresent=true},
                    {key="mark_of_the_wild", class="DRUID", spellID=1126, name="Mark of the Wild", short="Mark", classPresent=true},
                    {key="power_word_fortitude", class="PRIEST", spellID=21562, name="Power Word: Fortitude", short="Fort", classPresent=false}
                },
                players = {
                    {name="Coffettino", class="MAGE", role="DAMAGER", buffs={arcane_intellect=true,battle_shout=true,mark_of_the_wild=false,power_word_fortitude=nil}},
                    {name="Tankone", class="WARRIOR", role="TANK", buffs={arcane_intellect=true,battle_shout=true,mark_of_the_wild=true,power_word_fortitude=nil}},
                    {name="Roguetest", class="ROGUE", role="DAMAGER", buffs={arcane_intellect=true,battle_shout=true,mark_of_the_wild=true,power_word_fortitude=nil}},
                    {name="Healertwo", class="DRUID", role="HEALER", buffs={arcane_intellect=true,battle_shout=true,mark_of_the_wild=true,power_word_fortitude=nil}}
                }
            },
            timeline = {
                {type="defensive", time=55, text="Tankone usa Shield Wall", spellID=871},
                {type="death", time=136, text="Coffettino muore"},
                {type="debuff", time=90, text="Healertwo prende Test Debuff", spellID=209858}
            }
        })

    elseif msg == "show" then
        if MCA.lastReport then MCA:ShowUI(MCA.lastReport) else MCA:Print("Nessun report disponibile.") end
    elseif msg == "buffs" or msg == "raidbuffs" then
        if MCA.ShowRaidBuffWindow then MCA:ShowRaidBuffWindow() end
    elseif msg == "minimap" then
        if MCA.CreateMinimapButton then MCA:CreateMinimapButton() end
        if MCA.MinimapButton_SetShown then MCA:MinimapButton_SetShown(true) end
        MCA:Print("Bottone minimappa attivo.")
    elseif msg == "debug on" then
        MidnightCombatAnalyticsDB.config.debug = true
        MCA:Print("debug ON")
    elseif msg == "debug off" then
        MidnightCombatAnalyticsDB.config.debug = false
        MCA:Print("debug OFF")
    elseif msg == "sync on" then
        MidnightCombatAnalyticsDB.config.syncEnabled = true
        MCA:SendHello()
        MCA:Print("sync ON")
    elseif msg == "sync off" then
        MidnightCombatAnalyticsDB.config.syncEnabled = false
        MCA:Print("sync OFF")
    elseif msg == "export" then
        MCA:ShowExportWindow(MCA.lastReport)
    elseif msg == "share" then
        MCA:ShareSummary(MCA.lastReport)
    else
        MCA:Print("Commands: /mdr test, /mdr show, /mdr minimap, /mdr debug on/off, /mdr sync on/off, /mdr export, /mdr share")
    end
end
