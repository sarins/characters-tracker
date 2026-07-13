-- ====================================================================
-- CharactersTracker, All Rights Reserved unless otherwise explicitly stated.
-- ====================================================================
local addonName, addon = ...

local L = CharactersTracker_Locale
local DB_DATA_VERSION = "DB_VERSION"
local DATA_VERSION = "1.2.0"
-- local gui = CharactersTracker_GUI
-- ax:X()
-- code "\226\137\136" represent ≈ symbol

local SYMBOL_APPROX_EQ = "\226\137\136"
local SCAN_SLOTS = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 19 }

-- 装备 4 列精确布局
local COLUMN_LAYOUT = {
  [1] = { 1, 2, 3, 15, 5, 4, 19, 9 },   -- 第1列：头、颈、肩、背、胸、衬衣、战袍、腕
  [2] = { 16 },                         -- 第2列：主手
  [3] = { 17 },                         -- 第3列：副手
  [4] = { 10, 6, 7, 8, 11, 12, 13, 14 } -- 第4列：手、腰、腿、脚、指1、指2、饰1、饰2
}

-- 宏伟宝库类型映射 (1:团队副本, 2:地下城, 6:地下堡与世界)
local VAULT_TYPES = {
  { id = 1, name = L["VT_RAIDS"] },
  { id = 2, name = L["VT_DUNGEONS"] },
  { id = 6, name = L["VT_DW"] }
}

-- 声明需要追踪的常用非战网共享货币 ID 列表
local TRACKED_CURRENCIES = {
  3028, -- 修复的宝匣钥匙
  3310, -- 宝匣钥匙碎片
  2803, -- 晦幽铸币
  3356, -- 未被污染的法力水晶
  3418, -- 晦暗虚空核心
  3378, -- 黎明之光法力熔剂
  3383, -- 冒险者曙光纹章
  3341, -- 老兵曙光纹章
  3343, -- 勇士曙光纹章
  3345, -- 英雄曙光纹章
  3347, -- 神话曙光纹章
  1792, -- 荣誉点数
  1602, -- 征服点数
}

local BAG_SLOTS = { 0, 1, 2, 3, 4, 5 }
local BANK_SLOTS = { 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 }
local WARBAND_BANK_SLOT_IDX = 12

local MainFrame, DetailFrame, VaultFrame, FloatingButton, InventoryFrame
local AGGREGATED_ITEMS = {} -- 全局聚合清洗后的检索池
local FILTERED_ITEMS = {}   -- 搜索/过滤后的当前显示池

local ITEMS_PER_PAGE = 40   -- 5x8 网格布局，每页 40 个格子
local CURRENT_PAGE = 1

-- 转发前置声明，确保代码块顺序调用安全
local ToggleInventoryWindow
local isBankOpen = false
local guid

local DEBUG = true
local function DP(...)
  if DEBUG then
    print(...)
  end
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
          HIDDEN_COLUMNS = {},
          HIDDEN_CHARACTERS = {},
        },
      },
    }
    CharactersTrackerDB[DB_DATA_VERSION] = DATA_VERSION
  end
end

local function InitCharacterCache()
  local character = CharactersTrackerDB.CHARACTERS[guid] or {}

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
  character.updated = time()
  CharactersTrackerDB.CHARACTERS[guid] = character
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
  stats.secondary["LIFESTEAL"] = (GetCombatRatingBonus(CR_LIFESTEAL) or 0) +
      (GetLifesteal and GetLifesteal() or 0)                                               --吸血
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

-- local function syncLogout()
--   local character = CharactersTrackerDB.CHARACTERS[guid] or {}
--   character.level = UnitLevel("player")
--   character.faction = select(2, UnitFactionGroup("player"))
--   character.zone = GetZoneText() or character.zone or ""
--   character.subZone = GetSubZoneText() or character.subZone or ""
--   character.mScore = C_ChallengeMode.GetOverallDungeonScore() or character.mScore or 0
--   character.gold = GetMoney() or character.gold or 0
--   character.updated = time()
--   CharactersTrackerDB.CHARACTERS[guid] = character
-- end

local function ScanCharacterCurrencies()
  local character = CharactersTrackerDB.CHARACTERS[guid]
  for _, currencyID in ipairs(TRACKED_CURRENCIES) do
    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    if info and not info.isAccountWide then
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
    local itemLink = GetInventoryItemLink("player", slotId)
    if itemLink then
      local itemLevel = C_Item.GetDetailedItemLevelInfo(itemLink) or 0
      local _, enchantId = string.split(":", itemLink)
      local hasEnchant = (enchantId and enchantId ~= "" and enchantId ~= "0") and true or false

      character.gear[slotId] = {
        link = itemLink,
        level = itemLevel,
        enchant = hasEnchant
      }
      -- 过滤衬衣和战袍(4 and 19)，其余有效装备计入平均装等
      if slotId ~= 4 and slotId ~= 19 and itemLevel > 0 then
        sumLevel = sumLevel + itemLevel
        gearCount = gearCount + 1
      end
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
    for _, vType in ipairs(VAULT_TYPES) do
      local ok, activities = pcall(C_WeeklyRewards.GetActivities, vType.id)

      if ok and (not activities or #activities == 0) and vType.id == 2 then
        local history = C_MythicPlus.GetRunHistory(false, true) or {}
        local count = #history
        local maxLevel = 0
        for _, run in ipairs(history) do
          if run.level > maxLevel then maxLevel = run.level end
        end
        activities = {
          { index = 1, progress = count, threshold = 1, level = maxLevel, activityID = "Mythic" },
          { index = 2, progress = count, threshold = 4, level = maxLevel, activityID = "Mythic" },
          { index = 3, progress = count, threshold = 8, level = maxLevel, activityID = "Mythic" }
        }
      end

      if activities then
        character.vault[vType.id] = {}
        for _, activityInfo in ipairs(activities) do
          if activityInfo and activityInfo.index then
            local isValid = true
            -- 【核心修复一】精准清洗过滤：非当前大版本的团队副本格子
            if vType.id == 1 then
              if activityInfo.activityID then
                local encounterInfo = C_WeeklyRewards.GetActivityEncounterInfo(activityInfo.activityID)
                if encounterInfo and #encounterInfo > 0 then
                  local firstEncounter = encounterInfo[1]
                  if firstEncounter and firstEncounter.encounterID then
                    local _, _, _, _, _, journalInstanceID = C_EncounterJournal.GetEncounterInfo(firstEncounter
                      .encounterID)
                    if not journalInstanceID or journalInstanceID == 0 then
                      isValid = false
                    end
                  else
                    isValid = false
                  end
                else
                  isValid = false
                end
              else
                isValid = false
              end
            end
            -- 【核心修复二】精准清洗过滤：非当前有效赛季的地下城格子
            if vType.id == 2 then
              if not activityInfo.activityID or not activityInfo.threshold or activityInfo.threshold == 0 then
                isValid = false
              end

              if activityInfo.progress and activityInfo.progress > 100 then
                isValid = false
              end
            end
            -- 只有真正通过了当前大版本/当前赛季校验的数据，才允许记入本地数据库
            if isValid then
              table.insert(character.vault[vType.id], {
                index = activityInfo.index,
                progress = activityInfo.progress or 0,
                threshold = activityInfo.threshold or 0,
                level = activityInfo.level or 0,
              })
            end
          end
        end
        table.sort(character.vault[vType.id], function(a, b) return (a.index or 0) < (b.index or 0) end)
      end
    end
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

local function isLockingFor(k, s)
  local character = CharactersTrackerDB.CHARACTERS[guid]
  local now = time()
  if (now - (character[k] or 0)) < s then
    return true
  end
  character[k] = now
  return false
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
  -- DP("P: " .. guid .. ", bag: " .. bag .. " has been scan.")
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
  -- DP("P: " .. guid .. ", bank: " .. bank .. " has been scan.")
end

local function ScanCharacterBanks()
  for _, b in pairs(BANK_SLOTS) do
    ScanBankSlots(b)
  end
end

-- ==========================================
-- 通用UI窗体工厂
-- ==========================================
local function CreateBaseWindow(name, width, height, titleText, dbKey)
  local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  f:SetSize(width, height)
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if dbKey then
      local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
      CharactersTrackerDB.SETTINGS.POSITIONS[dbKey] = {
        point = point,
        relativePoint = relativePoint,
        xOfs = xOfs,
        yOfs = yOfs
      }
    end
  end)

  f:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  f:SetBackdropColor(0.05, 0.05, 0.05, 0.95)

  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.title:SetPoint("TOP", f, "TOP", 0, -12)
  f.title:SetText(titleText)

  f.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  f.closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
  f.closeBtn:SetScript("OnClick", function() f:Hide() end)

  if dbKey and CharactersTrackerDB.SETTINGS.POSITIONS[dbKey] then
    local pos = CharactersTrackerDB.SETTINGS.POSITIONS[dbKey]
    f:ClearAllPoints()
    f:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)
  else
    f:SetPoint("CENTER")
  end

  tinsert(UISpecialFrames, name)
  return f
end

-- ==========================================
-- 角色装备详情
-- ==========================================
local function CreateDetailWindow()
  if DetailFrame then return end

  DetailFrame = CreateBaseWindow("CGT_DetailFrame", 260, 360, L["GEAR_DETAIL"], "DetailFramePosition")
  DetailFrame:Hide()
  DetailFrame.slotsUI = {}
  local colXOffsets = { 25, 80, 145, 200 }

  -- 创建详细面板顶部的总装等文本显示
  DetailFrame.equippedLevelText = DetailFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  DetailFrame.equippedLevelText:SetPoint("TOP", DetailFrame, "TOP", 0, -35)

  for colIdx, slots in ipairs(COLUMN_LAYOUT) do
    local startX = colXOffsets[colIdx]
    for rowIdx, slotId in ipairs(slots) do
      local slotBtn = CreateFrame("Button", nil, DetailFrame, "BackdropTemplate")
      slotBtn:SetSize(36, 36)
      slotBtn:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
      })

      slotBtn.icon = slotBtn:CreateTexture(nil, "BACKGROUND")
      slotBtn.icon:SetAllPoints(slotBtn)
      slotBtn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

      slotBtn.itemLevelText = slotBtn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
      slotBtn.itemLevelText:SetPoint("BOTTOMRIGHT", slotBtn, "BOTTOMRIGHT", -1, 1)

      slotBtn.enchantDot = slotBtn:CreateTexture(nil, "OVERLAY")
      slotBtn.enchantDot:SetSize(6, 6)
      slotBtn.enchantDot:SetPoint("TOPLEFT", slotBtn, "TOPLEFT", 3, -3)
      slotBtn.enchantDot:SetColorTexture(0, 1, 0, 1)

      local startY = (colIdx == 2 or colIdx == 3) and (-45 - (8 - 1) * 38) or (-45 - (rowIdx - 1) * 38)
      slotBtn:SetPoint("TOPLEFT", DetailFrame, "TOPLEFT", startX, startY)

      slotBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
      slotBtn:SetScript("OnClick", function(self)
        if self.itemLink and IsShiftKeyDown() then
          local editBox = ChatEdit_GetActiveWindow()
          if editBox then editBox:Insert(self.itemLink) end
        end
      end)

      DetailFrame.slotsUI[slotId] = slotBtn
    end
  end
end

local function ShowCharacterDetail(guid)
  CreateDetailWindow()
  local data = CharactersTrackerDB.CHARACTERS[guid]
  if not data or not data.name then return end

  local classColor = RAID_CLASS_COLORS[data.class] and RAID_CLASS_COLORS[data.class].colorStr or "ffffffff"
  DetailFrame.title:SetText(string.format("|c%s%s|r", classColor, data.name))

  if data.equippedLevel and data.equippedLevel > 0 then
    if data.officialLevel then
      DetailFrame.equippedLevelText:SetText(string.format("|cffffd100%.2f|r", data.equippedLevel))
    else
      DetailFrame.equippedLevelText:SetText(string.format("|cffffd100%s%.2f|r", SYMBOL_APPROX_EQ, data.equippedLevel))
    end
  else
    DetailFrame.equippedLevelText:SetText("")
  end

  for _, slotId in ipairs(SCAN_SLOTS) do
    local btn = DetailFrame.slotsUI[slotId]
    local gear = data.gear and data.gear[slotId]

    if gear and gear.link then
      local itemTexture = C_Item.GetItemIconByID(gear.link)
      btn.icon:SetColorTexture(1, 1, 1, 1)
      btn.icon:SetTexture(itemTexture or 134400)
      btn.itemLink = gear.link
      btn.itemLevelText:SetText(gear.level > 0 and gear.level or "")

      if gear.enchant then btn.enchantDot:Show() else btn.enchantDot:Hide() end

      btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.itemLink)
        GameTooltip:Show()
      end)

      local quality = C_Item.GetItemQualityByID(gear.link)
      if quality and quality > 1 then
        local r, g, b = C_Item.GetItemQualityColor(quality)
        btn:SetBackdropBorderColor(r, g, b, 1)
      else
        btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
      end
    else
      btn.icon:SetColorTexture(0.2, 0.2, 0.2, 0.4)
      btn.itemLink = nil
      btn.itemLevelText:SetText("")
      btn.enchantDot:Hide()
      btn:SetBackdropBorderColor(0.15, 0.15, 0.15, 0.8)
      btn:SetScript("OnEnter", nil)
    end
  end
  DetailFrame:Show()
end

-- ==========================================
-- 宏伟宝库三线进度面板
-- ==========================================
local function CreateVaultWindow()
  if VaultFrame then return end

  VaultFrame = CreateBaseWindow("CGT_VaultFrame", 340, 200, L["VT_TITLE"], "VaultFramePosition")
  VaultFrame:Hide()
  VaultFrame.rows = {}

  for i, vType in ipairs(VAULT_TYPES) do
    local row = CreateFrame("Frame", nil, VaultFrame, "BackdropTemplate")
    row:SetSize(310, 42)
    row:SetPoint("TOPLEFT", VaultFrame, "TOPLEFT", 15, -45 - (i - 1) * 46)

    local rBg = row:CreateTexture(nil, "BACKGROUND")
    rBg:SetAllPoints()
    rBg:SetColorTexture(0.2, 0.2, 0.2, 0.25)

    local typeLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    typeLabel:SetPoint("LEFT", 10, 0)
    typeLabel:SetText(vType.name)

    row.slots = {}
    for j = 1, 3 do
      local slotFrame = CreateFrame("Frame", nil, row, "BackdropTemplate")
      slotFrame:SetSize(55, 24)
      slotFrame:SetPoint("RIGHT", row, "RIGHT", -10 - (3 - j) * 60, 0)

      local sBg = slotFrame:CreateTexture(nil, "BACKGROUND")
      sBg:SetAllPoints()
      slotFrame.bg = sBg

      local sText = slotFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      sText:SetPoint("CENTER", 0, 0)
      slotFrame.text = sText

      table.insert(row.slots, slotFrame)
    end
    VaultFrame.rows[vType.id] = row
  end
end

local function ShowCharacterVault(guid)
  CreateVaultWindow()
  local data = CharactersTrackerDB.CHARACTERS[guid]
  if not data or not data.name then return end

  local classColor = RAID_CLASS_COLORS[data.class] and RAID_CLASS_COLORS[data.class].colorStr or "ffffffff"
  VaultFrame.title:SetText(string.format("|c%s%s|r - " .. L["VT_TITLE"], classColor, data.name))

  for _, vType in ipairs(VAULT_TYPES) do
    local rowUI = VaultFrame.rows[vType.id]
    local typeData = data.vault and data.vault[vType.id] or {}

    for j = 1, 3 do
      local sFrame = rowUI.slots[j]
      local sData = typeData[j]

      if sData then
        if sData.progress >= sData.threshold then
          rowUI.slots[j].bg:SetColorTexture(0.1, 0.45, 0.1, 0.85)
          if vType.id == 1 then
            sFrame.text:SetText(L["VT_UNLOCKED"])
          else
            sFrame.text:SetText(string.format(L["VT_LEVEL"], sData.level or 0))
          end
        else
          sFrame.bg:SetColorTexture(0.5, 0.35, 0.05, 0.85)
          sFrame.text:SetText(string.format("%d/%d", sData.progress or 0, sData.threshold or 0))
        end
      else
        sFrame.bg:SetColorTexture(0.25, 0.25, 0.25, 0.5)
        sFrame.text:SetText(L["VT_LOCKED"])
      end
    end
  end
  VaultFrame:Show()
end

-- ==========================================
-- 独立鼠标悬浮渲染货币 Tooltip 函数
-- ==========================================
local function ShowCurrencyTooltip(ownerFrame, uid)
  if not uid then return end
  local data = CharactersTrackerDB.CHARACTERS[uid]
  if not data or not data.name then return end

  GameTooltip:SetOwner(ownerFrame, "ANCHOR_RIGHT")
  GameTooltip:ClearLines()

  local classColor = RAID_CLASS_COLORS[data.class] and RAID_CLASS_COLORS[data.class].colorStr or "ffffffff"
  GameTooltip:AddLine(string.format("|c%s%s|r - %s", classColor, data.name, data.realm or ""))
  GameTooltip:AddLine(" ")

  if data.currencies and next(data.currencies) then
    local hasAnyOutput = false
    for _, currencyID in ipairs(TRACKED_CURRENCIES) do
      local cData = data.currencies[currencyID]
      if cData then
        hasAnyOutput = true
        local iconStr = string.format("|T%d:14:14:0:0|t", cData.icon)
        local leftColumn = string.format("%s  %s", iconStr, cData.name)
        local qtyStr = string.format("|cffffffff%d|r", cData.quantity)
        local weeklyStr = ""
        if cData.maxWeeklyQuantity and cData.maxWeeklyQuantity > 0 then
          weeklyStr = string.format(L["CURR_WEEKLY_LIMIT"], cData.quantityEarnedThisWeek, cData.maxWeeklyQuantity)
        end
        if cData.maxQuantity and cData.maxQuantity > 0 then
          if cData.totalEarned and cData.totalEarned > 0 then
            weeklyStr = string.format(L["CURR_SEASON_LIMIT"], cData.totalEarned, cData.maxQuantity)
          else
            weeklyStr = string.format(L["CURR_LIMIT"], cData.quantity, cData.maxQuantity)
          end
        end

        local rightColumn = qtyStr .. weeklyStr
        GameTooltip:AddDoubleLine(leftColumn, rightColumn, 1, 1, 1, 1, 1, 1)
      end
    end

    if not hasAnyOutput then
      GameTooltip:AddLine(L["CURR_TIP_L1"], 0.5, 0.5, 0.5)
      GameTooltip:AddLine(L["CURR_TIP_L2"], 0.5, 0.5, 0.5)
    end
  else
    GameTooltip:AddLine(L["CURR_TIP_L1"], 0.5, 0.5, 0.5)
    GameTooltip:AddLine(L["CURR_TIP_L2"], 0.5, 0.5, 0.5)
  end

  GameTooltip:Show()
end

-- ==========================================
-- 一级角色列表主窗与拖拽排序核心
-- ==========================================
local function RearrangeCharacterButtons()
  if not MainFrame then return end

  local orderKeeper = CharactersTrackerDB.SETTINGS.CHARACTERS_ORDER

  local index = 0
  for _, id in ipairs(orderKeeper) do
    local btn = MainFrame.guidToButton[id]
    if btn and btn:IsShown() then
      index = index + 1
      btn:ClearAllPoints()
      if not btn.isDragging then
        btn:SetPoint("TOPLEFT", MainFrame.content, "TOPLEFT", 2, -(index - 1) * 34)
      end
      if btn.extraBtn then
        btn.extraBtn:ClearAllPoints()
        btn.extraBtn:SetPoint("LEFT", btn, "RIGHT", 4, 0)
      end
    end
  end
  MainFrame.content:SetSize(286, math.max(1, index * 34))
end

local function OnCharacterButtonUpdate(self)
  if not self.isDragging then return end
  local orderKeeper = CharactersTrackerDB.SETTINGS.CHARACTERS_ORDER

  local _, relativeTo, _, _, yOfs = self:GetPoint()
  local currentFrameY = self:GetTop()
  local parentTop = MainFrame.content:GetTop()
  if not currentFrameY or not parentTop then return end

  local relativeY = parentTop - currentFrameY
  local targetIndex = math.floor((relativeY + 17) / 34) + 1
  targetIndex = math.max(1, math.min(targetIndex, #orderKeeper))

  local oldIndex = 0
  for idx, id in ipairs(orderKeeper) do
    if id == self.guid then
      oldIndex = idx
      break
    end
  end

  if oldIndex > 0 and oldIndex ~= targetIndex then
    table.remove(orderKeeper, oldIndex)
    table.insert(orderKeeper, targetIndex, self.guid)
    RearrangeCharacterButtons()
  end
end

local function OpenMainWindow()
  if not MainFrame then
    MainFrame = CreateBaseWindow("CGT_MainFrame", 360, 360, L["CHOOSE_CHARACTER"], "MainFramePosition")
    MainFrame.scrollFrame = CreateFrame("ScrollFrame", nil, MainFrame, "UIPanelScrollFrameTemplate")
    MainFrame.scrollFrame:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 10, -40)
    MainFrame.scrollFrame:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -25, 10)

    MainFrame.content = CreateFrame("Frame", nil, MainFrame.scrollFrame)
    MainFrame.content:SetSize(200, 1)
    MainFrame.scrollFrame:SetScrollChild(MainFrame.content)
    MainFrame.buttons = {}
    MainFrame.guidToButton = {}
  end

  for _, btn in ipairs(MainFrame.buttons) do
    btn:Hide()
    if btn.extraBtn then btn.extraBtn:Hide() end
  end
  table.wipe(MainFrame.guidToButton)

  local activeGuids = {}
  for guid, data in pairs(CharactersTrackerDB.CHARACTERS) do
    if data.name then
      activeGuids[guid] = true
    end
  end

  local orderKeeper = CharactersTrackerDB.SETTINGS.CHARACTERS_ORDER

  for i = #orderKeeper, 1, -1 do
    if not activeGuids[orderKeeper[i]] then
      table.remove(orderKeeper, i)
    end
  end

  for guid in pairs(activeGuids) do
    local exists = false
    for _, orderedGuid in ipairs(orderKeeper) do
      if orderedGuid == guid then
        exists = true
        break
      end
    end
    if not exists then
      table.insert(orderKeeper, guid)
    end
  end

  local index = 0
  for _, guid in ipairs(orderKeeper) do
    local data = CharactersTrackerDB.CHARACTERS[guid]
    if data and data.name then
      index = index + 1
      local btn = MainFrame.buttons[index]
      if not btn then
        btn = CreateFrame("Button", nil, MainFrame.content, "BackdropTemplate")
        btn:SetSize(286, 30)
        btn:SetBackdrop({
          bgFile = "Interface\\Buttons\\WHITE8X8",
          edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
          edgeSize = 8,
          insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        btn:SetBackdropColor(0.15, 0.15, 0.15, 0.6)

        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.text:SetPoint("LEFT", btn, "LEFT", 8, 0)
        btn.text:SetPoint("RIGHT", btn, "RIGHT", -55, 0)
        btn.text:SetJustifyH("LEFT")

        btn.equippedLevelText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btn.equippedLevelText:SetPoint("RIGHT", btn, "RIGHT", -10, 0)
        btn.equippedLevelText:SetJustifyH("RIGHT")

        local extraBtn = CreateFrame("Button", nil, MainFrame.content, "BackdropTemplate")
        extraBtn:SetSize(32, 30)
        extraBtn:SetBackdrop({
          bgFile = "Interface\\Buttons\\WHITE8X8",
          edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
          edgeSize = 8,
          insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        extraBtn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)

        local statusDot = extraBtn:CreateTexture(nil, "OVERLAY")
        statusDot:SetSize(21, 21)
        statusDot:SetPoint("CENTER", extraBtn, "CENTER", 0, 0)
        statusDot:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")

        extraBtn.statusDot = statusDot
        btn.extraBtn = extraBtn
        MainFrame.buttons[index] = btn

        btn:SetMovable(true)
        btn:RegisterForDrag("LeftButton")

        btn:SetScript("OnDragStart", function(self)
          self.isDragging = true
          self:SetFrameStrata("TOOLTIP")
          if self.extraBtn then self.extraBtn:SetFrameStrata("TOOLTIP") end
          self:StartMoving()
          self:SetScript("OnUpdate", OnCharacterButtonUpdate)
          GameTooltip:Hide()
        end)

        btn:SetScript("OnDragStop", function(self)
          self.isDragging = false
          self:StopMovingOrSizing()
          self:SetScript("OnUpdate", nil)
          self:SetFrameStrata("MEDIUM")
          if self.extraBtn then self.extraBtn:SetFrameStrata("MEDIUM") end
          RearrangeCharacterButtons()
        end)
      end

      btn.guid = guid
      MainFrame.guidToButton[guid] = btn

      local classColor = RAID_CLASS_COLORS[data.class] and RAID_CLASS_COLORS[data.class].colorStr or "ffffffff"
      btn.text:SetText(string.format("|c%s%s|r (|cff888888%s|r)", classColor, data.name, data.realm))

      if data.equippedLevel and data.equippedLevel > 0 then
        if data.officialLevel then
          btn.equippedLevelText:SetText(string.format("|cffffd100%.2f|r", data.equippedLevel))
        else
          btn.equippedLevelText:SetText(string.format("|cffffd100%s%.2f|r", SYMBOL_APPROX_EQ, data.equippedLevel))
        end
      else
        btn.equippedLevelText:SetText("|cff888888--|r")
      end

      -- ------------------------------------------------------------
      -- 【状态同步算法】
      -- ------------------------------------------------------------
      local totalSlots = 0
      local completedSlots = 0
      local totalProgress = 0

      if data.vault then
        for _, vTypeId in ipairs({ 1, 2, 6 }) do
          local typeData = data.vault[vTypeId]
          if typeData then
            for _, sData in ipairs(typeData) do
              totalSlots = totalSlots + 1
              totalProgress = totalProgress + (sData.progress or 0)
              if sData.progress and sData.threshold and sData.progress >= sData.threshold then
                completedSlots = completedSlots + 1
              end
            end
          end
        end
      end

      if totalSlots == 0 or totalProgress == 0 then
        btn.extraBtn.statusDot:SetVertexColor(0.4, 0.4, 0.4, 0.85)
      elseif completedSlots == totalSlots and totalSlots > 0 then
        btn.extraBtn.statusDot:SetVertexColor(0.1, 0.75, 0.1, 0.95)
      else
        btn.extraBtn.statusDot:SetVertexColor(0.85, 0.65, 0.1, 0.95)
      end
      -- ------------------------------------------------------------

      btn:SetScript("OnClick", function() ShowCharacterDetail(guid) end)
      btn.extraBtn:SetScript("OnClick", function() ShowCharacterVault(guid) end)

      btn:SetScript("OnEnter", function(self)
        if not self.isDragging then
          btn:SetBackdropColor(0.25, 0.25, 0.25, 0.8)
          ShowCurrencyTooltip(self, guid)
        end
      end)

      btn:SetScript("OnLeave", function()
        btn:SetBackdropColor(0.15, 0.15, 0.15, 0.6)
        GameTooltip:Hide()
      end)

      btn:Show()
      if btn.extraBtn then btn.extraBtn:Show() end
    end
  end

  RearrangeCharacterButtons()
  MainFrame:Show()
end

-- ==========================================
-- 独立悬浮触发按钮设计
-- ==========================================
local function CreateFloatingButton()
  if FloatingButton then return end

  FloatingButton = CreateFrame("Button", "CGT_FloatingButton", UIParent)
  FloatingButton:SetSize(36, 36)
  FloatingButton:SetFrameStrata("HIGH")
  FloatingButton:SetClampedToScreen(true)
  FloatingButton:SetMovable(true)
  FloatingButton:EnableMouse(true)
  FloatingButton:RegisterForDrag("LeftButton")

  local icon = FloatingButton:CreateTexture(nil, "ARTWORK")
  icon:SetSize(26, 26)
  icon:SetPoint("CENTER", 0, 0)
  icon:SetTexture(1064187)

  FloatingButton:SetScript("OnDragStart", function(self) self:StartMoving() end)
  FloatingButton:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if CharactersTrackerDB then
      local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
      CharactersTrackerDB.SETTINGS.POSITIONS["FloatingButtonPosition"] = {
        point = point, relativePoint = relativePoint, xOfs = xOfs, yOfs = yOfs
      }
    end
  end)

  -- 改动：支持左键开启列表、右键开启战团全资产统计
  FloatingButton:RegisterForClicks("AnyUp")
  FloatingButton:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
      ToggleInventoryWindow()
    else
      if MainFrame and MainFrame:IsShown() then MainFrame:Hide() else OpenMainWindow() end
    end
  end)

  FloatingButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(L["FB_FUNC"], 1, 1, 1)
    GameTooltip:AddLine(L["FB_L1"], 0.2, 1.0, 0.2)
    GameTooltip:AddLine(L["FB_L2"], 0.4, 0.8, 0.2)
    GameTooltip:AddLine(L["FB_L3"], 0.4, 0.8, 0.2)
    GameTooltip:Show()
  end)
  FloatingButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

  if CharactersTrackerDB and CharactersTrackerDB.SETTINGS.POSITIONS["FloatingButtonPosition"] then
    local pos = CharactersTrackerDB.SETTINGS.POSITIONS["FloatingButtonPosition"]
    FloatingButton:ClearAllPoints()
    FloatingButton:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)
  else
    FloatingButton:SetPoint("CENTER", UIParent, "CENTER", -200, 0)
  end
end

-- ==========================================
-- 战团资产汇总与网格检索面板
-- ==========================================
local function GetContainerNameText(bagID)
  if bagID >= 0 and bagID <= 4 then
    return L["INV_LOC_BAG"]
  elseif bagID == 5 then
    return L["INV_LOC_REAGENT_BAG"]
  elseif bagID >= 6 and bagID <= 11 then
    return L["INV_LOC_BANK"]
  elseif bagID >= 12 and bagID <= 16 then
    return L["INV_LOC_WARBAND_BANK"]
  else
    return L["INV_LOC_OTHERS"]
  end
end

local function AggregateWarbandItems()
  table.wipe(AGGREGATED_ITEMS)
  if not CharactersTrackerDB then return end

  -- characters data
  for _, charData in pairs(CharactersTrackerDB.CHARACTERS) do
    if type(charData) == "table" and charData.name and charData.bags then
      local charNameWithRealm = string.format("%s-%s", charData.name, charData.realm or GetRealmName())
      local classColor = RAID_CLASS_COLORS[charData.class] and RAID_CLASS_COLORS[charData.class].colorStr or "ffffffff"

      for bagID, bagData in pairs(charData.bags) do
        for slotID, item in pairs(bagData) do
          if item and item.id then
            if not AGGREGATED_ITEMS[item.id] then
              AGGREGATED_ITEMS[item.id] = {
                id = item.id,
                name = item.link and (GetItemInfo(item.link) or item.link:match("%[(.-)%]")) or L["INV_LOADING"],
                icon = item.icon or 134400,
                quality = item.quality or 1,
                link = item.link,
                totalCount = 0,
                sources = {}
              }
            end

            AGGREGATED_ITEMS[item.id].totalCount = AGGREGATED_ITEMS[item.id].totalCount + item.count
            local srcKey = string.format("|c%s%s|r", classColor, charNameWithRealm)
            local locText = GetContainerNameText(bagID)
            if not AGGREGATED_ITEMS[item.id].sources[srcKey] then
              AGGREGATED_ITEMS[item.id].sources[srcKey] = {}
            end
            AGGREGATED_ITEMS[item.id].sources[srcKey][locText] = (AGGREGATED_ITEMS[item.id].sources[srcKey][locText] or 0) +
                item.count
          end
        end
      end
    end
  end
  -- warband data
  for bagID, bagData in pairs(CharactersTrackerDB.WARBAND.BAGS) do
    for slotID, item in pairs(bagData) do
      if item and item.id then
        if not AGGREGATED_ITEMS[item.id] then
          AGGREGATED_ITEMS[item.id] = {
            id = item.id,
            name = item.link and (GetItemInfo(item.link) or item.link:match("%[(.-)%]")) or L["INV_LOADING"],
            icon = item.icon or 134400,
            quality = item.quality or 1,
            link = item.link,
            totalCount = 0,
            sources = {}
          }
        end

        AGGREGATED_ITEMS[item.id].totalCount = AGGREGATED_ITEMS[item.id].totalCount + item.count
        local srcKey = L["INV_SRC_WARBAND"]
        local locText = GetContainerNameText(bagID)
        if not AGGREGATED_ITEMS[item.id].sources[srcKey] then
          AGGREGATED_ITEMS[item.id].sources[srcKey] = {}
        end
        AGGREGATED_ITEMS[item.id].sources[srcKey][locText] = (AGGREGATED_ITEMS[item.id].sources[srcKey][locText] or 0) +
            item.count
      end
    end
  end
end

local function FilterAndSortItems(searchText)
  table.wipe(FILTERED_ITEMS)
  searchText = searchText and string.lower(strtrim(searchText)) or ""

  for _, item in pairs(AGGREGATED_ITEMS) do
    local match = false
    if searchText == "" then
      match = true
    else
      local itemName = string.lower(item.name or "")
      if string.find(itemName, searchText, 1, true) or string.find(tostring(item.id), searchText, 1, true) then
        match = true
      end
    end

    if match then
      table.insert(FILTERED_ITEMS, item)
    end
  end

  table.sort(FILTERED_ITEMS, function(a, b)
    if a.quality ~= b.quality then
      return (a.quality or 0) > (b.quality or 0)
    else
      return (a.id or 0) > (b.id or 0)
    end
  end)
end

local function UpdateInventoryGrid()
  if not InventoryFrame then return end

  local totalItems = #FILTERED_ITEMS
  local maxPages = math.max(1, math.ceil(totalItems / ITEMS_PER_PAGE))
  if CURRENT_PAGE > maxPages then CURRENT_PAGE = maxPages end

  InventoryFrame.pageText:SetText(string.format("%d / %d", CURRENT_PAGE, maxPages))

  local startIndex = (CURRENT_PAGE - 1) * ITEMS_PER_PAGE

  for i = 1, ITEMS_PER_PAGE do
    local gridBtn = InventoryFrame.grids[i]
    local itemData = FILTERED_ITEMS[startIndex + i]

    if itemData then
      gridBtn.icon:SetTexture(itemData.icon)
      gridBtn.countText:SetText(itemData.totalCount)
      gridBtn.itemData = itemData
      gridBtn:Show()

      if itemData.quality and itemData.quality > 1 then
        local r, g, b = C_Item.GetItemQualityColor(itemData.quality)
        gridBtn:SetBackdropBorderColor(r, g, b, 1)
      else
        gridBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.4)
      end
    else
      gridBtn.itemData = nil
      gridBtn:Hide()
    end
  end
end

local function CreateInventoryWindow()
  if InventoryFrame then return end

  InventoryFrame = CreateBaseWindow("CGT_InventoryFrame", 640, 560, L["INV_TITLE"], "InventoryFramePosition")
  InventoryFrame:Hide()

  local searchBox = CreateFrame("EditBox", nil, InventoryFrame, "InputBoxTemplate")
  searchBox:SetSize(604, 24)
  searchBox:SetPoint("TOPLEFT", InventoryFrame, "TOPLEFT", 21, -35)
  searchBox:SetAutoFocus(false)

  local sLabel = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  sLabel:SetPoint("LEFT", searchBox, "LEFT", 5, 0)
  sLabel:SetText(L["INV_SEARCH_TIP"])

  searchBox:SetScript("OnTextChanged", function(self)
    if self:GetText() == "" then sLabel:Show() else sLabel:Hide() end
    FilterAndSortItems(self:GetText())
    CURRENT_PAGE = 1
    UpdateInventoryGrid()
  end)
  searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

  InventoryFrame.grids = {}
  local startX = 15
  local startY = -80
  local spacingX = 14
  local spacingY = 24
  local iconSide = 64

  for row = 0, 4 do
    for col = 0, 7 do
      local btn = CreateFrame("Button", nil, InventoryFrame, "BackdropTemplate")
      btn:SetSize(iconSide, iconSide)
      btn.icon = btn:CreateTexture(nil, "BACKGROUND")
      btn.icon:SetAllPoints(btn)
      -- btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

      btn.countText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      btn.countText:SetPoint("TOP", btn, "BOTTOM", 0, 0)

      btn:SetPoint("TOPLEFT", InventoryFrame, "TOPLEFT", startX + (col * (spacingX + iconSide)),
        startY - (row * (spacingY + iconSide)))

      btn:SetScript("OnClick", function(self)
        if self.itemData and self.itemData.link and IsShiftKeyDown() then
          local editBox = ChatEdit_GetActiveWindow()
          if editBox then editBox:Insert(self.itemData.link) end
        end
      end)

      btn:SetScript("OnEnter", function(self)
        if not self.itemData then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.itemData.link then
          GameTooltip:SetHyperlink(self.itemData.link)
        else
          GameTooltip:SetText(self.itemData.name)
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["INV_DETAIL"])

        for charInfo, locations in pairs(self.itemData.sources) do
          for locName, count in pairs(locations) do
            GameTooltip:AddDoubleLine("  " .. charInfo .. " [" .. locName .. "]", "|cffffffff(" .. count .. ")|r", 0.9,
              0.9, 0.9, 1, 1, 1)
          end
        end
        GameTooltip:Show()
      end)
      btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

      table.insert(InventoryFrame.grids, btn)
    end
  end

  local prevBtn = CreateFrame("Button", nil, InventoryFrame, "GameMenuButtonTemplate")
  prevBtn:SetSize(96, 24)
  prevBtn:SetPoint("BOTTOMLEFT", InventoryFrame, "BOTTOMLEFT", 64, 12)
  prevBtn:SetText("<")
  prevBtn:SetScript("OnClick", function()
    if CURRENT_PAGE > 1 then
      CURRENT_PAGE = CURRENT_PAGE - 1
      UpdateInventoryGrid()
    end
  end)

  local nextBtn = CreateFrame("Button", nil, InventoryFrame, "GameMenuButtonTemplate")
  nextBtn:SetSize(96, 24)
  nextBtn:SetPoint("BOTTOMRIGHT", InventoryFrame, "BOTTOMRIGHT", -64, 12)
  nextBtn:SetText(">")
  nextBtn:SetScript("OnClick", function()
    local maxPages = math.max(1, math.ceil(#FILTERED_ITEMS / ITEMS_PER_PAGE))
    if CURRENT_PAGE < maxPages then
      CURRENT_PAGE = CURRENT_PAGE + 1
      UpdateInventoryGrid()
    end
  end)

  local pageText = InventoryFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  pageText:SetPoint("CENTER", InventoryFrame, "BOTTOM", 0, 26)
  InventoryFrame.pageText = pageText
end

ToggleInventoryWindow = function()
  CreateInventoryWindow()
  if InventoryFrame:IsShown() then
    InventoryFrame:Hide()
  else
    AggregateWarbandItems()
    FilterAndSortItems("")
    CURRENT_PAGE = 1
    UpdateInventoryGrid()
    InventoryFrame:Show()
  end
end

-- local function ClearOldWarbandBankData()
--   for guid, charData in pairs(CharactersTrackerDB) do
--     if type(charData) == "table" and charData.name and guid ~= "order" and charData.bags then
--       for bagID, _ in pairs(charData.bags) do
--         if bagID >= WARBAND_BANK_SLOT_IDX then
--           CharactersTrackerDB[guid].bags[bagID] = nil
--         end
--       end
--     end
--   end
-- end


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
    DP("migration skip because data no need to migrate")
    return
  end
  -- if currentVersion < "1.1.2" then
  --   -- ClearOldWarbandBankData()
  --   return
  -- end
  DP("start data migration...")
  -- CharactersTrackerDB.version
  local migratedDb = {
    CHARACTERS = {},
    WARBAND = {
      BAGS = {},
    },
    -- positions = {},
    SETTINGS = {
      POSITIONS = {},
      CHARACTERS_ORDER = {},
      CLP = {
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
      DP(k)
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
-- add below when 1.2.0
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("TIME_PLAYED_MSG")
-- eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3)
  if event == "ADDON_LOADED" and arg1 == "CharactersTracker" then
    -- ==========================================
    -- Initial statement
    -- ==========================================
    DbCheck()
    guid = UnitGUID("player")
    if not guid then return end
    DP(guid)
    DataMigrationBeforeV1_2_0()
    InitCharacterCache()
    -- ClearOldWarbandBankData()
    addon:InitWorkspace()
  elseif event == "BANKFRAME_OPENED" then
    -- DP(event)
    isBankOpen = true
    ScanCharacterBanks()
  elseif event == "BANKFRAME_CLOSED" then
    -- DP(event)
    isBankOpen = false
  elseif event == "BAG_UPDATE_DELAYED" then
    -- DP(event)
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
    DP(event)
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
    DP(event)
    -- TODO
  elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
    C_Timer.After(1.5, function()
      ScanCharacterStats()
    end)
  elseif event == "PLAYER_ENTERING_WORLD" then
    InitCharacterCache()
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
    end)
    CreateFloatingButton()
  end
end)

-- ==========================================
-- 命令注册
-- ==========================================
SLASH_WBCT1 = "/wbct"
SLASH_WBCT2 = "/ct"
SlashCmdList["WBCT"] = function(msg)
  if msg == "bag" or msg == "inv" then
    ToggleInventoryWindow()
  elseif "debug" == msg then
    addon:ClpMain()
  elseif "x" == msg then
    -- addon:CreateCgp()
    addon:ShowCgp("Player-709-06D59F76")
  elseif "t" == msg then
    XXX = ScanCharacterStats()
  else
    if MainFrame and MainFrame:IsShown() then MainFrame:Hide() else OpenMainWindow() end
  end
end



-- frame:RegisterEvent("PLAYER_ENTERING_WORLD") -- 登录游戏/跨图加载
-- frame:RegisterEvent("UNIT_INVENTORY_CHANGED") -- 装备发生变化
-- frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED") -- 切换了专精/天赋
-- frame:RegisterEvent("PLAYER_LEVEL_UP") -- 角色升级
-- frame:RegisterEvent("UNIT_STATS") -- 基础主属性发生变化
-- frame:RegisterEvent("COMBAT_RATING_UPDATE") -- 二次/三次绿字属性发生变化
function addon:GetCharacterStats()
  local statsList = {}

  -- ====================================================================
  -- 1. 基础核心属性（力量、敏捷、智力、耐力、以及补全的【护甲】）
  -- ====================================================================

  -- 🟢 耐力 (Stamina)
  local currentStam = UnitStat("player", 3)
  if currentStam and currentStam > 0 then
    table.insert(statsList, { name = SPEC_FRAME_STAMINA or "耐力", value = tostring(currentStam) })
  end

  -- 🟢 补全：护甲 (Armor)
  -- UnitArmor 返回的第一个值就是当前面板最终总护甲
  -- 🟢 修正：使用全版本通用的 ARMOR 常量，且去掉多余的拦截，强制注入
  local baseArmor, effectiveArmor, armorArmor, bonusArmor = UnitArmor("player")
  -- 第二个返回值 effectiveArmor 是包含了所有天赋、光环、护甲专精加成后的最终实际护甲
  local totalArmor = effectiveArmor or baseArmor or 0

  table.insert(statsList, { name = ARMOR or "护甲", value = tostring(totalArmor) })

  -- 动态过滤其余三项主属性（力量/敏捷/智力）
  local primaryTypes = {
    { id = 1, tag = "STRENGTH", name = SPEC_FRAME_STRENGTH or "力量" },
    { id = 2, tag = "AGILITY", name = SPEC_FRAME_AGILITY or "敏捷" },
    { id = 4, tag = "INTELLECT", name = SPEC_FRAME_INTELLECT or "智力" },
  }
  for _, stat in ipairs(primaryTypes) do
    if self:IsStatEffectiveForCurrentSpec(stat.tag) then
      local val = UnitStat("player", stat.id)
      table.insert(statsList, { name = stat.name, value = tostring(val) })
    end
  end

  -- ====================================================================
  -- 2. 强化二次属性 (Secondary Stats)
  -- ====================================================================
  local critChance = GetCritChance()
  table.insert(statsList, { name = STAT_CRITICAL_STRIKE or "暴击", value = string.format("%.2f%%", critChance) })

  local hastePercent = GetHaste()
  table.insert(statsList, { name = STAT_HASTE or "急速", value = string.format("%.2f%%", hastePercent) })

  if self:IsStatEffectiveForCurrentSpec("MASTERY") then
    local masteryEffect = GetMasteryEffect()
    table.insert(statsList, { name = STAT_MASTERY or "精通", value = string.format("%.2f%%", masteryEffect) })
  end

  local versaDamageBonus = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE)
  table.insert(statsList, { name = STAT_VERSATILITY or "全能", value = string.format("%.2f%%", versaDamageBonus) })

  -- ====================================================================
  -- 3. 第三绿字/辅助属性 (包含修正后的全额吸血)
  -- ====================================================================
  -- -- 🟢 吸血 (Leech - 整合绿字与被动/附魔)
  -- local leechPercent = GetCombatRatingBonus(CR_LIFESTEAL) + (GetLifesteal and GetLifesteal() or 0)
  -- table.insert(statsList, { name = STAT_LIFESTEAL or "吸血", value = string.format("%.2f%%", leechPercent) })

  -- -- 🟢 加速 (Speed)
  -- local speedPercent = GetCombatRatingBonus(CR_SPEED)
  -- table.insert(statsList, { name = STAT_SPEED or "加速", value = string.format("%.2f%%", speedPercent or 0) })

  -- -- 🟢 闪避 (Avoidance)
  -- local avoidancePercent = GetCombatRatingBonus(CR_AVOIDANCE) + (GetAvoidance and GetAvoidance() or 0)
  -- table.insert(statsList, { name = STAT_AVOIDANCE or "闪避", value = string.format("%.2f%%", avoidancePercent) })
  -- ====================================================================
  -- 3. 第三绿字/辅助属性 (包含修正后的全额吸血)
  -- ====================================================================
  -- 🟢 吸血 (Leech - 整合绿字与被动/附魔)
  local leechPercent = GetCombatRatingBonus(CR_LIFESTEAL) + (GetLifesteal and GetLifesteal() or 0)
  table.insert(statsList, { name = STAT_LIFESTEAL or "吸血", value = string.format("%.2f%%", leechPercent) })

  -- 🟢 加速 (Speed)
  local speedPercent = GetCombatRatingBonus(CR_SPEED)
  table.insert(statsList, { name = STAT_SPEED or "加速", value = string.format("%.2f%%", speedPercent or 0) })

  -- 🟢 修正版：闪避 (Avoidance)
  -- 直接调用全局 GetAvoidance() 即可，它本身就是包含一切加成的最终全额百分比
  local avoidancePercent = GetAvoidance() or 0
  table.insert(statsList, { name = STAT_AVOIDANCE or "闪避", value = string.format("%.2f%%", avoidancePercent) })
  return statsList
end

-- 判断某个属性在当前职业/专精下是否为“核心推荐属性”
-- @param statType string: "STRENGTH", "AGILITY", "INTELLECT", "MASTERY" 等
-- @return boolean: 是否生效/是否推荐显示
function addon:IsStatEffectiveForCurrentSpec(statType)
  -- 1. 获取当前专精索引 (1 到 4)
  local currentSpec = GetSpecialization()
  if not currentSpec then return false end

  -- 2. 获取专精的详细信息
  -- id, name, description, icon, role, primaryStat = GetSpecializationInfo(currentSpec)
  -- primaryStat 返回值：1 = 力量 (LE_UNIT_STAT_STRENGTH), 2 = 敏捷 (LE_UNIT_STAT_AGILITY), 4 = 智力 (LE_UNIT_STAT_INTELLECT)
  local _, _, _, _, _, primaryStat = GetSpecializationInfo(currentSpec)

  -- 3. 校验主属性拦截
  if statType == "STRENGTH" and primaryStat ~= 1 then
    return false -- 当前专精不需求力量
  elseif statType == "AGILITY" and primaryStat ~= 2 then
    return false -- 当前专精不需求敏捷
  elseif statType == "INTELLECT" and primaryStat ~= 4 then
    return false -- 当前专精不需求智力
  end

  -- 4. 校验精通拦截 (低等级小号如果还没学会精通，官方面板会隐藏)
  if statType == "MASTERY" then
    local isMasteryKnown = IsSpellKnown(GLOBAL_M_SPELLID or 8647) -- 8647 是暴雪各职业精通的通用底层法术ID
    if not isMasteryKnown and UnitLevel("player") < 10 then
      return false
    end
  end

  -- 耐力、暴击、急速、全能、吸血、闪避、加速对所有职业都生效，默认全放行
  return true
end
