-- ====================================================================
-- CharactersTracker, All Rights Reserved unless otherwise explicitly stated.
-- ====================================================================
local addonName, addon = ...
_G["CharactersTrackerStub"] = addon

local L = CharactersTracker_Locale

BINDING_NAME_CHARACTERS_TRACKER = L["CT_BINDING_DESC"]
BINDING_HEADER_CHARACTERS_TRACKER = addonName

local DB_DATA_VERSION = "DB_VERSION"
local DATA_VERSION = "2.0.0"

local SCAN_SLOTS = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 19 }

local BAG_SLOTS = { 0, 1, 2, 3, 4, 5 }
local BANK_SLOTS = { 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 }
local WARBAND_BANK_SLOT_IDX = 12

local SUB_SKILL_LINE_IDS = {
  [171] = { 2485, 2484, 2483, 2482, 2481, 2480, 2479, 2478, 2750, 2823, 2871, 2906 }, -- Alchemy/炼金
  [164] = { 2477, 2476, 2475, 2474, 2473, 2472, 2454, 2437, 2751, 2822, 2872, 2907 }, -- Blacksmithing/锻造
  [185] = { 2548, 2547, 2546, 2545, 2544, 2543, 2542, 2541, 2752, 2824, 2873, 2908 }, -- Cooking/烹饪
  [333] = { 2494, 2493, 2492, 2491, 2489, 2488, 2487, 2486, 2753, 2825, 2874, 2909 }, -- Enchanting/附魔
  [202] = { 2506, 2505, 2504, 2503, 2502, 2501, 2500, 2499, 2755, 2827, 2875, 2910 }, -- Engineering/工程
  [356] = { 2592, 2591, 2590, 2589, 2588, 2587, 2586, 2585, 2754, 2826, 2876, 2911 }, -- Fishing/钓鱼
  [182] = { 2556, 2555, 2554, 2553, 2552, 2551, 2550, 2549, 2760, 2832, 2877, 2912 }, -- Herbalism/草药
  [773] = { 2514, 2513, 2512, 2511, 2510, 2509, 2508, 2507, 2756, 2828, 2878, 2913 }, -- Inscription/铭文
  [755] = { 2524, 2523, 2522, 2521, 2520, 2519, 2518, 2517, 2757, 2829, 2879, 2914 }, -- Jewelcrafting/珠宝
  [165] = { 2532, 2531, 2530, 2529, 2528, 2527, 2526, 2525, 2758, 2830, 2880, 2915 }, -- Leatherworking/制皮
  [186] = { 2572, 2571, 2570, 2569, 2568, 2567, 2566, 2565, 2761, 2833, 2881, 2916 }, -- Mining/采矿
  [393] = { 2564, 2563, 2562, 2561, 2560, 2559, 2558, 2557, 2762, 2834, 2882, 2917 }, -- Skinning/剥皮
  [197] = { 2540, 2539, 2538, 2537, 2536, 2535, 2534, 2533, 2759, 2831, 2883, 2918 }, -- Tailoring/裁缝
}

local SKILL_LINE_CONCENTRATION_ENABLE = {
  2871, 2906, -- Alchemy/炼金
  2872, 2907, -- Blacksmithing/锻造
  2874, 2909, -- Enchanting/附魔
  2875, 2910, -- Engineering/工程
  2878, 2913, -- Inscription/铭文
  2879, 2914, -- Jewelcrafting/珠宝
  2880, 2915, -- Leatherworking/制皮
  2883, 2918, -- Tailoring/裁缝
}

-- tIndexOf
local SKILL_LINE_OVERLOAD_SPELLS = {
  -- Mining/采矿
  [2916] = C_Spell.GetSpellInfo(1225392),
  [2881] = C_Spell.GetSpellInfo(423394),
  -- Herbalism/草药
  [2912] = C_Spell.GetSpellInfo(1223014),
  [2877] = C_Spell.GetSpellInfo(423395),
}

local isBankOpen = false
local guid

function addon:DP(...)
  if CharactersTrackerDB.DEBUG then
    print(...)
  end
end

local function isLockingFor(k, s)
  local character = CharactersTrackerDB.CHARACTERS[guid]
  local now = time()
  if (now - (character[k] or 0)) < s then
    return true
  end
  character[k] = now
  return false
end

local function DbCheck()
  if not CharactersTrackerDB then
    CharactersTrackerDB = {
      CHARACTERS = {},
      WARBAND = {
        BAGS = {},
      },
      SETTINGS = {
        POSITIONS = {},
        CHARACTERS_ORDER = {},
        CLP = {
          HIDDEN_CURRENCIES = {},
          HIDDEN_COLUMNS = {},
          HIDDEN_CHARACTERS = {},
        },
      },
      DEBUG = false,
    }
  else
    CharactersTrackerDB.CHARACTERS = CharactersTrackerDB.CHARACTERS or {}
    CharactersTrackerDB.WARBAND = CharactersTrackerDB.WARBAND or {}
    CharactersTrackerDB.WARBAND.BAGS = CharactersTrackerDB.WARBAND.BAGS or {}
    CharactersTrackerDB.SETTINGS = CharactersTrackerDB.SETTINGS or {}
    CharactersTrackerDB.SETTINGS.POSITIONS = CharactersTrackerDB.SETTINGS.POSITIONS or {}
    CharactersTrackerDB.SETTINGS.CHARACTERS_ORDER = CharactersTrackerDB.SETTINGS.CHARACTERS_ORDER or {}
    CharactersTrackerDB.SETTINGS.CLP = CharactersTrackerDB.SETTINGS.CLP or {}
    CharactersTrackerDB.SETTINGS.CLP.HIDDEN_CURRENCIES = CharactersTrackerDB.SETTINGS.CLP.HIDDEN_CURRENCIES or {}
    CharactersTrackerDB.SETTINGS.CLP.HIDDEN_COLUMNS = CharactersTrackerDB.SETTINGS.CLP.HIDDEN_COLUMNS or {}
    CharactersTrackerDB.SETTINGS.CLP.HIDDEN_CHARACTERS = CharactersTrackerDB.SETTINGS.CLP.HIDDEN_CHARACTERS or {}
  end
  CharactersTrackerDB[DB_DATA_VERSION] = DATA_VERSION
end

local function InitCharacterCache()
  local character = CharactersTrackerDB.CHARACTERS[guid] or {}
  local orderKeeper = CharactersTrackerDB.SETTINGS.CHARACTERS_ORDER

  character.name = UnitName("player")
  character.class = select(2, UnitClass("player"))
  character.realm = GetRealmName()
  character.level = UnitLevel("player")
  character.faction = select(2, UnitFactionGroup("player"))
  character.zone = GetZoneText() or character.zone or ""
  character.subZone = GetSubZoneText() or character.subZone or ""
  character.mScore = C_ChallengeMode.GetOverallDungeonScore() or character.mScore or 0
  character.played = character.played or 0
  character.levelPlayed = character.levelPlayed or 0
  character.gold = GetMoney() or character.gold or 0
  character.gear = character.gear or {}
  character.vault = character.vault or {}
  character.bags = character.bags or {}
  character.currencies = character.currencies or {}
  character.stats = character.stats or { basic = {}, secondary = {} }
  character.professions = character.professions or {}
  character.updated = time()
  CharactersTrackerDB.CHARACTERS[guid] = character

  if not tIndexOf(orderKeeper, guid) then
    table.insert(orderKeeper, guid)
  end
end

local function ScanCharacterStats()
  local stats = {
    basic = {},
    secondary = {}
  }
  -- Stats
  stats.basic["STAMINA"] = UnitStat("player", 3) or 0 -- 耐力

  local baseArmor, effectiveArmor, _, _ = UnitArmor("player")
  stats.basic["ARMOR"] = effectiveArmor or baseArmor or 0 -- 护甲

  local spec = GetSpecialization()
  if spec then
    local _, specialization, _, _, _, primaryStat = GetSpecializationInfo(spec)
    stats.specialization = specialization --专精
    if 1 == primaryStat then
      stats.basic["STRENGTH"] = UnitStat("player", primaryStat) or 0
    elseif 2 == primaryStat then
      stats.basic["AGILITY"] = UnitStat("player", primaryStat) or 0
    elseif 4 == primaryStat then
      stats.basic["INTELLECT"] = UnitStat("player", primaryStat) or 0
    else
      -- CONTINUE
    end
  end
  -- Secondary Stats
  stats.secondary["CRITICAL_STRIKE"] = (GetCritChance() or 0)                              --暴击
  stats.secondary["HASTE"] = (GetHaste() or 0)                                             --急速
  stats.secondary["MASTERY"] = (GetMasteryEffect() or 0)                                   --精通
  stats.secondary["VERSATILITY"] = (GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) or 0) --全能
  stats.secondary["LIFESTEAL"] = (GetCombatRatingBonus(CR_LIFESTEAL) or 0)                 --吸血
  stats.secondary["SPEED"] = (GetCombatRatingBonus(CR_SPEED) or 0)                         --加速
  stats.secondary["AVOIDANCE"] = (GetAvoidance() or 0)                                     --闪避

  CharactersTrackerDB.CHARACTERS[guid].stats = stats
  return stats
end

local function sync(f)
  local character = CharactersTrackerDB.CHARACTERS[guid] or {}
  if "function" == type(f) then
    f(character)
  end
  character.updated = time()
  CharactersTrackerDB.CHARACTERS[guid] = character
end

local function ScanCharacterCurrencies()
  local character = CharactersTrackerDB.CHARACTERS[guid]
  for _, currencyID in ipairs(addon.TRACKED_CURRENCIES) do
    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    if info then
      character.currencies[currencyID] = {
        name = info.name,
        quantity = info.quantity,
        icon = info.iconFileID,
        maxWeeklyQuantity = info.maxWeeklyQuantity or 0,
        quantityEarnedThisWeek = info.quantityEarnedThisWeek or 0,
        maxQuantity = info.maxQuantity or 0,
        totalEarned = info.totalEarned or 0,
      }
    end
  end
end

local function ScanCharacterGears()
  -- Try to get official equipped item level
  local _, officialEquippedLevel = GetAverageItemLevel()
  local character = CharactersTrackerDB.CHARACTERS[guid]

  local sumLevel = 0
  local gearCount = 0

  for _, slotId in ipairs(SCAN_SLOTS) do
    local link = GetInventoryItemLink("player", slotId)
    if link then
      local item = Item:CreateFromItemLink(link)
      item:ContinueOnItemLoad(function()
        local level = item:GetCurrentItemLevel() or 0
        local icon = item:GetItemIcon()
        local quality = item:GetItemQuality()
        local r, g, b, _ = C_Item.GetItemQualityColor(quality)
        local color = { r, g, b, 1 }

        character.gear[slotId] = {
          link = link,
          level = level,
          icon = icon,
          quality = quality,
          color = color,
        }
        -- 过滤衬衣和战袍(4 and 19)，其余有效装备计入平均装等
        if slotId ~= 4 and slotId ~= 19 and level > 0 then
          sumLevel = sumLevel + level
          gearCount = gearCount + 1
        end
      end)
    else
      character.gear[slotId] = {}
    end
  end
  -- save avg level of items
  if officialEquippedLevel and officialEquippedLevel > 0 then
    character.equippedLevel = officialEquippedLevel
    character.officialLevel = true
  else
    if gearCount > 0 then
      character.equippedLevel = tonumber(string.format("%.2f", sumLevel / gearCount)) or 0
    else
      character.equippedLevel = 0
    end
    character.officialLevel = false
  end
end

local function ScanCharacterRewards()
  if C_WeeklyRewards and C_WeeklyRewards.GetActivities then
    local character = CharactersTrackerDB.CHARACTERS[guid]

    local ok, activities = pcall(C_WeeklyRewards.GetActivities)
    if ok and activities then
      local vaults = {
        activities = {},
        difficulties = {},
        rewardItemLevels = {},
        rewards = {},
        levels = {}
      }
      for _, slot in ipairs(activities) do
        if slot and slot.type and slot.index then
          -- init
          vaults.activities[slot.type] = vaults.activities[slot.type] or {}
          vaults.difficulties[slot.type] = vaults.difficulties[slot.type] or {}
          vaults.rewardItemLevels[slot.type] = vaults.rewardItemLevels[slot.type] or {}
          vaults.rewards[slot.type] = vaults.rewards[slot.type] or 0
          vaults.levels[slot.type] = vaults.levels[slot.type] or {}
          -- assign
          vaults.activities[slot.type][slot.index] = slot
          if slot.progress >= slot.threshold then
            vaults.rewards[slot.type] = vaults.rewards[slot.type] + 1
            vaults.levels[slot.type][vaults.rewards[slot.type]] = slot.level
            -- try to explain when vault unlocked but the level is 0 situation.
            if slot.activityTierID > 0 then
              local difficultyId = C_WeeklyRewards.GetDifficultyIDForActivityTier(slot.activityTierID)
              if difficultyId and difficultyId > 0 then
                -- name               string - Difficulty name, e.g. "10 Player (Heroic)"
                -- groupType          string - Group type appropriate for this difficulty; "party" or "raid".
                -- isHeroic           boolean - true if this is a heroic difficulty, false otherwise.
                -- isChallengeMode    boolean - true if this is challenge mode difficulty, false otherwise.
                -- displayHeroic      boolean - display the Heroic skull icon on the instance banner of the minimap
                -- displayMythic      boolean - display the Mythic skull icon on the instance banner of the minimap
                -- toggleDifficultyID number - difficulty ID of the corresponding heroic/non-heroic difficulty for 10/25-man raids, if one exists.
                -- isLFR              boolean - true if this is looking for raid difficulty, false otherwise.
                -- minPlayers         number - minimum players needed.
                -- maxPlayers         number - maximum players allowed.
                -- isUserSelectable   boolean
                local name, groupType,
                isHeroic, isChallengeMode,
                displayHeroic, displayMythic,
                toggleDifficultyID, isLFR,
                minPlayers, maxPlayers, isUserSelectable = GetDifficultyInfo(difficultyId)
                if name then
                  vaults.difficulties[slot.type][slot.index] = {
                    name = name,
                    groupType = groupType,
                    isHeroic = isHeroic,
                    isChallengeMode = isChallengeMode,
                    displayHeroic = displayHeroic,
                    displayMythic = displayMythic,
                    toggleDifficultyID = toggleDifficultyID,
                    isLFR = isLFR,
                    minPlayers = minPlayers,
                    maxPlayers = maxPlayers,
                    isUserSelectable = isUserSelectable,
                  }
                end
              end
              -- try to get item level of rewards, slot id may not be empty
              local exampleLink = C_WeeklyRewards.GetExampleRewardItemHyperlinks(slot.id)
              if exampleLink then
                local _, _, _, itemLevel = C_Item.GetItemInfo(exampleLink)
                vaults.rewardItemLevels[slot.type][slot.index] = itemLevel
              end
            end
          end
        end
      end
      character.vaults = vaults
    end
  end
end

local function LookupProfessionDetial(idx)
  if idx then
    local name, icon, _, _, _, _, skillLineId = GetProfessionInfo(idx)

    if not name or not skillLineId then
      return false
    end

    local professionInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineId)
    if not professionInfo or not professionInfo.profession then
      return false
    end

    local profession = professionInfo.profession

    -- if professionInfo.maxSkillLevel < 1 then
    -- end

    local subSkillLines = {}
    if SUB_SKILL_LINE_IDS[skillLineId] then
      ------------------------------------------------------------------------------------------------------------------
      -- Force open trade skill panel for retrieve skill data, I can not understand why design like that by Blizzard. --
      ------------------------------------------------------------------------------------------------------------------
      -- C_TradeSkillUI.OpenTradeSkill(skillLineId)
      -- C_TradeSkillUI.CloseTradeSkill()
      -- End Force open trade skill panel

      local subSkillLineIds = SUB_SKILL_LINE_IDS[skillLineId]

      for _idx, subSkillLineId in ipairs(subSkillLineIds) do
        subSkillLines[_idx] = C_TradeSkillUI.GetProfessionInfoBySkillLineID(subSkillLineId)
        if tIndexOf(SKILL_LINE_CONCENTRATION_ENABLE, subSkillLineId) then
          -- do lookup concentration
          local ccid = C_TradeSkillUI.GetConcentrationCurrencyID(subSkillLineId)
          if ccid then
            local currency = C_CurrencyInfo.GetCurrencyInfo(ccid)
            if currency then
              subSkillLines[_idx].concentration = {
                id = currency.currencyID,
                name = currency.name,
                discovered = currency.discovered,
                quantity = currency.quantity or 0,
                maxQuantity = currency.maxQuantity or 0,
                rechargingAmountPerCycle = currency.rechargingAmountPerCycle or 0,
                rechargingCycle = (currency.rechargingCycleDurationMS or 0) / 1000,
                updated = time(),
              }
            end
          end
        end

        local overloadSpell = SKILL_LINE_OVERLOAD_SPELLS[subSkillLineId]
        if overloadSpell and overloadSpell.spellID and C_SpellBook.IsSpellInSpellBook(overloadSpell.spellID) then
          -- do lookup overload spell
          subSkillLines[_idx].overload = {
            spell = overloadSpell,
            charges = C_Spell.GetSpellCharges(overloadSpell.spellID),
          }
        end
      end
    end

    -- lookup slots
    local slots = {}
    local professionSlots = C_TradeSkillUI.GetProfessionSlots(profession)
    if professionSlots then
      for _idx, professionSlot in ipairs(professionSlots) do
        local link = GetInventoryItemLink("player", professionSlot)
        if link then
          table.insert(slots, link)
        end
      end
    end

    return {
      idx = idx,
      icon = icon,
      name = name,
      profession = profession,
      skillLineId = skillLineId,
      subSkillLines = subSkillLines,
      slots = slots,
    }
  end
  return false
end

local function ScanCharacterProfessions()
  if isLockingFor("lastTimeScanCharacterProfessions", 5) then return end
  local character = CharactersTrackerDB.CHARACTERS[guid]

  for k, p in pairs(character.professions) do
    if p and p.idx then
      local profession = LookupProfessionDetial(p.idx)
      if profession then
        character.professions[k] = profession
      end
    end
  end
end

local function LookupProfessionInfo(idx)
  if idx then
    local name, icon, _, _, _, _, skillLineId = GetProfessionInfo(idx)

    if not name or not skillLineId then
      return false
    end

    local professionInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineId)
    if not professionInfo or not professionInfo.profession then
      return false
    end

    return {
      idx = idx,
      icon = icon,
      name = name,
      profession = professionInfo.profession,
      skillLineId = skillLineId,
    }
  end
  return false
end

local function CheckCharacterProfessions()
  local character = CharactersTrackerDB.CHARACTERS[guid]

  local p1, p2, archaeology, fishing, cooking = GetProfessions()

  if not character.professions.p1 or p1 ~= character.professions.p1.idx then
    character.professions.p1 = LookupProfessionInfo(p1)
  end

  if not character.professions.p2 or p2 ~= character.professions.p2.idx then
    character.professions.p2 = LookupProfessionInfo(p2)
  end

  if not character.professions.archaeology or archaeology ~= character.professions.archaeology.idx then
    character.professions.archaeology = LookupProfessionInfo(archaeology)
  end

  if not character.professions.fishing or fishing ~= character.professions.fishing.idx then
    character.professions.fishing = LookupProfessionInfo(fishing)
  end

  if not character.professions.cooking or cooking ~= character.professions.cooking.idx then
    character.professions.cooking = LookupProfessionInfo(cooking)
  end
end

-- unsafe function, check info valid before use.
local function ConvertBagInfo(info)
  return {
    id = info.itemID,
    count = info.stackCount,
    link = info.hyperlink,
    icon = info.iconFileID,
    quality = info.quality
  }
end

local function ScanBagSlots(bag)
  local numSlots = C_Container.GetContainerNumSlots(bag) or 0
  local character = CharactersTrackerDB.CHARACTERS[guid]
  if numSlots > 0 then
    character.bags[bag] = {}
    for s = 1, numSlots do
      local info = C_Container.GetContainerItemInfo(bag, s)
      if info and info.itemID then
        character.bags[bag][s] = ConvertBagInfo(info)
      end
    end
  end
  -- addon:DP("P: " .. guid .. ", bag: " .. bag .. " has been scan.")
end

local function ScanCharacterBags()
  if isLockingFor("lastTimeUpdateBag", 30) then return end
  for _, b in pairs(BAG_SLOTS) do
    ScanBagSlots(b)
  end
end

local function ScanBankSlots(bank)
  local character = CharactersTrackerDB.CHARACTERS[guid]
  if not isBankOpen then
    return
  end
  local numSlots = C_Container.GetContainerNumSlots(bank) or 0
  if numSlots > 0 then
    local bankSlots = {}
    for s = 1, numSlots do
      if not isBankOpen then
        break
      end
      local info = C_Container.GetContainerItemInfo(bank, s)
      if info and info.itemID then
        bankSlots[s] = ConvertBagInfo(info)
      end
    end
    if bank < WARBAND_BANK_SLOT_IDX then
      character.bags[bank] = bankSlots
    else
      CharactersTrackerDB.WARBAND.BAGS[bank] = bankSlots
    end
  end
  -- addon:DP("P: " .. guid .. ", bank: " .. bank .. " has been scan.")
end

local function ScanCharacterBanks()
  for _, b in pairs(BANK_SLOTS) do
    ScanBankSlots(b)
  end
end

local function StringStartWith(str, prefix)
  return string.find(str, prefix, 1, true) == 1
end

local function StringEndWith(str, suffix)
  if suffix == "" then return true end
  return string.sub(str, -string.len(suffix)) == suffix
end

local function DataMigrationBeforeV1_2_0()
  -- local currentVersion = C_AddOns.GetAddOnMetadata(addonName, "Version") or ""
  local dataVersion = CharactersTrackerDB[DB_DATA_VERSION] or ""
  if dataVersion >= DATA_VERSION or "table" ~= type(CharactersTrackerDB) or next(CharactersTrackerDB) == nil then
    addon:DP("migration skip because data no need to migrate")
    return
  end
  -- if currentVersion < "1.1.2" then
  --   -- ClearOldWarbandBankData()
  --   return
  -- end
  addon:DP("start data migration...")
  -- CharactersTrackerDB.version
  local migratedDb = {
    CHARACTERS = {},
    WARBAND = {
      BAGS = {},
    },
    SETTINGS = {
      POSITIONS = {},
      CHARACTERS_ORDER = {},
      CLP = {
        HIDDEN_CURRENCIES = {},
        HIDDEN_COLUMNS = {},
        HIDDEN_CHARACTERS = {},
      },
    },
  }
  for k, d in pairs(CharactersTrackerDB) do
    if StringStartWith(k, "Player-") then
      migratedDb.CHARACTERS[k] = d
    elseif StringEndWith(k, "Position") then
      migratedDb.SETTINGS.POSITIONS[k] = d
    elseif "bags" == k then
      migratedDb.WARBAND.BAGS = d or {}
    elseif "order" == k then
      migratedDb.SETTINGS.CHARACTERS_ORDER = d or {}
    else
      -- nothing
      addon:DP(k)
    end
  end
  migratedDb[DB_DATA_VERSION] = DATA_VERSION
  CharactersTrackerDB = migratedDb
end

-- All jobs: Rewards/Equipped/Currencies/Bags/Banks
-- ==========================================
-- 后台监听自动记录
-- ==========================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("WEEKLY_REWARDS_UPDATE")
eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("BANKFRAME_CLOSED")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
-- add below when 2.0.0
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("TIME_PLAYED_MSG")
-- eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
-- add below when 2.0.3
eventFrame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3)
  if event == "ADDON_LOADED" and arg1 == "CharactersTracker" then
    -- ==========================================
    -- Initial statement
    -- ==========================================
    DbCheck()
    guid = UnitGUID("player")
    if not guid then return end
    addon:DP(guid)
    DataMigrationBeforeV1_2_0()
    InitCharacterCache()
    addon:InitWorkspace()
  elseif event == "BANKFRAME_OPENED" then
    -- addon:DP(event)
    isBankOpen = true
    ScanCharacterBanks()
  elseif event == "BANKFRAME_CLOSED" then
    -- addon:DP(event)
    isBankOpen = false
  elseif event == "BAG_UPDATE_DELAYED" then
    -- addon:DP(event)
    ScanCharacterBags()
    if isBankOpen then
      ScanCharacterBanks()
    end
  elseif event == "WEEKLY_REWARDS_UPDATE" then
    C_Timer.After(1.5, function() ScanCharacterRewards() end)
  elseif event == "PLAYER_EQUIPMENT_CHANGED" then
    C_Timer.After(1.5, function()
      ScanCharacterGears()
      ScanCharacterStats()
    end)
  elseif event == "CURRENCY_DISPLAY_UPDATE" then
    ScanCharacterCurrencies()
  elseif event == "CHALLENGE_MODE_MAPS_UPDATE" then
    sync(
      function(c)
        c.mScore = C_ChallengeMode.GetOverallDungeonScore() or c.mScore or 0
      end
    )
  elseif event == "ZONE_CHANGED_NEW_AREA" then
    sync(
      function(c)
        c.zone = GetZoneText() or c.zone or ""
        c.subZone = GetSubZoneText() or c.subZone or ""
      end
    )
  elseif event == "TIME_PLAYED_MSG" then
    sync(
      function(c)
        c.played = arg1 or c.played or 0
        c.levelPlayed = arg2 or c.levelPlayed or 0
      end
    )
  elseif event == "PLAYER_LEVEL_UP" then
    addon:DP(event)
    C_Timer.After(
      2,
      function()
        sync(
          function(c)
            c.level = UnitLevel("player")
          end
        )
        ScanCharacterStats()
      end
    )
  elseif event == "PLAYER_LOGOUT" then
    addon:DP(event)
    -- TODO: because there will make not sure for the processing to completely finished, so keep there blank maybe the best choice.
  elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
    C_Timer.After(1.5, function()
      ScanCharacterStats()
    end)
  elseif event == "TRADE_SKILL_LIST_UPDATE" then
    addon:DP(event)
    C_Timer.After(2, function()
      ScanCharacterProfessions()
    end)
  elseif event == "PLAYER_ENTERING_WORLD" then
    addon:DP(event)
    InitCharacterCache()
    addon:InitEnteringWorld()
    -- ==========================================
    -- Try to Triggering weekly rewards notify.
    -- ==========================================
    if C_WeeklyRewards and C_WeeklyRewards.RequestActivityInfo then
      pcall(C_WeeklyRewards.RequestActivityInfo)
    end
    C_Timer.After(1.5, function()
      ScanCharacterGears()
      ScanCharacterRewards()
      ScanCharacterStats()
      CheckCharacterProfessions()
    end)
    addon:CreateFloatingButton()
  end
end)

function addon:Main()
  if addon.CT_CLP and addon.CT_CLP:IsShown() then
    addon.CT_CLP:Hide()
  else
    addon:ClpMain()
  end
end

-- ==========================================
-- 命令注册
-- ==========================================
SLASH_WBCT1 = "/wbct"
SLASH_WBCT2 = "/ct"
SlashCmdList["WBCT"] = function(msg)
  if "bag" == msg then
    addon:ToggleInventoryPanel()
  elseif "debug" == msg then
    CharactersTrackerDB.DEBUG = not CharactersTrackerDB.DEBUG
    print(string.format("Debug Switcher: %s", CharactersTrackerDB.DEBUG and "On" or "Off"))
  -- elseif "p" == msg then
  --   ScanCharacterProfessions()
  else
    addon:Main()
  end
end
