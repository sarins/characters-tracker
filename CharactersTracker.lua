-- ====================================================================
-- CharactersTracker, All Rights Reserved unless otherwise explicitly stated.
-- ====================================================================
local L = CharactersTracker_Locale

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

local DEBUG = false
local function DP(...)
  if DEBUG then
    print(...)
  end
end

local function DbCheck()
  if not CharactersTrackerDB then CharactersTrackerDB = {} end
end

local function InitCharacterCache()
  if not CharactersTrackerDB[guid] then CharactersTrackerDB[guid] = {} end
  CharactersTrackerDB[guid].name = UnitName("player")
  CharactersTrackerDB[guid].realm = GetRealmName()
  CharactersTrackerDB[guid].class = select(2, UnitClass("player"))
  CharactersTrackerDB[guid].gear = CharactersTrackerDB[guid].gear or {}
  CharactersTrackerDB[guid].vault = CharactersTrackerDB[guid].vault or {}
  CharactersTrackerDB[guid].bags = CharactersTrackerDB[guid].bags or {}
  CharactersTrackerDB.bags = CharactersTrackerDB.bags or {}
  CharactersTrackerDB[guid].currencies = {}
end

local function ScanCharacterCurrencies()
  for _, currencyID in ipairs(TRACKED_CURRENCIES) do
    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    if info and not info.isAccountWide then
      CharactersTrackerDB[guid].currencies[currencyID] = {
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

  local sumLevel = 0
  local gearCount = 0

  for _, slotId in ipairs(SCAN_SLOTS) do
    local itemLink = GetInventoryItemLink("player", slotId)
    if itemLink then
      local itemLevel = C_Item.GetDetailedItemLevelInfo(itemLink) or 0
      local _, enchantId = string.split(":", itemLink)
      local hasEnchant = (enchantId and enchantId ~= "" and enchantId ~= "0") and true or false

      CharactersTrackerDB[guid].gear[slotId] = {
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
      CharactersTrackerDB[guid].gear[slotId] = {}
    end
  end
  -- save avg level of items
  if officialEquippedLevel and officialEquippedLevel > 0 then
    CharactersTrackerDB[guid].equippedLevel = officialEquippedLevel
    CharactersTrackerDB[guid].officialLevel = true
  else
    if gearCount > 0 then
      CharactersTrackerDB[guid].equippedLevel = tonumber(string.format("%.2f", sumLevel / gearCount)) or 0
    else
      CharactersTrackerDB[guid].equippedLevel = 0
    end
    CharactersTrackerDB[guid].officialLevel = false
  end
end

local function ScanCharacterRewards()
  if C_WeeklyRewards and C_WeeklyRewards.GetActivities then
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
        CharactersTrackerDB[guid].vault[vType.id] = {}
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
              table.insert(CharactersTrackerDB[guid].vault[vType.id], {
                index = activityInfo.index,
                progress = activityInfo.progress or 0,
                threshold = activityInfo.threshold or 0,
                level = activityInfo.level or 0,
              })
            end
          end
        end
        table.sort(CharactersTrackerDB[guid].vault[vType.id], function(a, b) return (a.index or 0) < (b.index or 0) end)
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

local function ScanBagSlots(bag)
  local numSlots = C_Container.GetContainerNumSlots(bag) or 0
  if numSlots > 0 then
    CharactersTrackerDB[guid].bags[bag] = {}
    for s = 1, numSlots do
      local info = C_Container.GetContainerItemInfo(bag, s)
      if info and info.itemID then
        CharactersTrackerDB[guid].bags[bag][s] = ConvertBagInfo(info)
      end
    end
  end
  DP("P: " .. guid .. ", bag: " .. bag .. " has been scan.")
end

local function ScanCharacterBags()
  for _, b in pairs(BAG_SLOTS) do
    ScanBagSlots(b)
  end
end

local function ScanBankSlots(bank)
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
      CharactersTrackerDB[guid].bags[bank] = bankSlots
    else
      CharactersTrackerDB.bags[bank] = bankSlots
    end
  end
  DP("P: " .. guid .. ", bank: " .. bank .. " has been scan.")
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
    if dbKey and CharactersTrackerDB then
      local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
      CharactersTrackerDB[dbKey] = {
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

  if dbKey and CharactersTrackerDB and CharactersTrackerDB[dbKey] then
    local pos = CharactersTrackerDB[dbKey]
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
  local data = CharactersTrackerDB[guid]
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
  local data = CharactersTrackerDB[guid]
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
local function ShowCurrencyTooltip(ownerFrame, guid)
  if not guid or not CharactersTrackerDB then return end
  local data = CharactersTrackerDB[guid]
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
  if not MainFrame or not CharactersTrackerDB or not CharactersTrackerDB.order then return end

  local index = 0
  for _, guid in ipairs(CharactersTrackerDB.order) do
    local btn = MainFrame.guidToButton[guid]
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

  local _, relativeTo, _, _, yOfs = self:GetPoint()
  local currentFrameY = self:GetTop()
  local parentTop = MainFrame.content:GetTop()
  if not currentFrameY or not parentTop then return end

  local relativeY = parentTop - currentFrameY
  local targetIndex = math.floor((relativeY + 17) / 34) + 1
  targetIndex = math.max(1, math.min(targetIndex, #CharactersTrackerDB.order))

  local oldIndex = 0
  for idx, guid in ipairs(CharactersTrackerDB.order) do
    if guid == self.guid then
      oldIndex = idx
      break
    end
  end

  if oldIndex > 0 and oldIndex ~= targetIndex then
    table.remove(CharactersTrackerDB.order, oldIndex)
    table.insert(CharactersTrackerDB.order, targetIndex, self.guid)
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

  if not CharactersTrackerDB then CharactersTrackerDB = {} end
  if not CharactersTrackerDB.order then CharactersTrackerDB.order = {} end

  local activeGuids = {}
  for guid, data in pairs(CharactersTrackerDB) do
    if type(data) == "table" and data.name and guid ~= "order" then
      activeGuids[guid] = true
    end
  end

  for i = #CharactersTrackerDB.order, 1, -1 do
    if not activeGuids[CharactersTrackerDB.order[i]] then
      table.remove(CharactersTrackerDB.order, i)
    end
  end

  for guid in pairs(activeGuids) do
    local exists = false
    for _, orderedGuid in ipairs(CharactersTrackerDB.order) do
      if orderedGuid == guid then
        exists = true
        break
      end
    end
    if not exists then
      table.insert(CharactersTrackerDB.order, guid)
    end
  end

  local index = 0
  for _, guid in ipairs(CharactersTrackerDB.order) do
    local data = CharactersTrackerDB[guid]
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
      CharactersTrackerDB["FloatingButtonPosition"] = {
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

  if CharactersTrackerDB and CharactersTrackerDB["FloatingButtonPosition"] then
    local pos = CharactersTrackerDB["FloatingButtonPosition"]
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
  for guid, charData in pairs(CharactersTrackerDB) do
    if type(charData) == "table" and charData.name and guid ~= "order" and charData.bags then
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
  for bagID, bagData in pairs(CharactersTrackerDB.bags) do
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

local function ClearOldWarbandBankData()
  for guid, charData in pairs(CharactersTrackerDB) do
    if type(charData) == "table" and charData.name and guid ~= "order" and charData.bags then
      for bagID, _ in pairs(charData.bags) do
        if bagID >= WARBAND_BANK_SLOT_IDX then
          CharactersTrackerDB[guid].bags[bagID] = nil
        end
      end
    end
  end
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

eventFrame:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" and arg1 == "CharactersTracker" then
    -- ==========================================
    -- Initial statement
    -- ==========================================
    DbCheck()
    guid = UnitGUID("player")
    if not guid then return end
    DP(guid)
    InitCharacterCache()
    ClearOldWarbandBankData()
  elseif event == "BANKFRAME_OPENED" then
    DP(event)
    isBankOpen = true
    ScanCharacterBanks()
  elseif event == "BANKFRAME_CLOSED" then
    DP(event)
    isBankOpen = false
  elseif event == "BAG_UPDATE_DELAYED" then
    DP(event)
    ScanCharacterBags()
    if isBankOpen then
      ScanCharacterBanks()
    end
  elseif event == "WEEKLY_REWARDS_UPDATE" then
    C_Timer.After(1.5, function() ScanCharacterRewards() end)
  elseif event == "PLAYER_EQUIPMENT_CHANGED" then
    C_Timer.After(1.5, function() ScanCharacterGears() end)
  elseif event == "CURRENCY_DISPLAY_UPDATE" then
    ScanCharacterCurrencies()
  elseif event == "PLAYER_ENTERING_WORLD" then
    -- ==========================================
    -- Try to Triggering weekly rewards notify.
    -- ==========================================
    if C_WeeklyRewards and C_WeeklyRewards.RequestActivityInfo then
      pcall(C_WeeklyRewards.RequestActivityInfo)
    end
    C_Timer.After(1.5, function()
      ScanCharacterGears()
      ScanCharacterRewards()
    end)
    CreateFloatingButton()
  end
end)

-- ==========================================
-- 8. 命令注册
-- ==========================================
SLASH_WBCT1 = "/wbct"
SLASH_WBCT2 = "/ct"
SlashCmdList["WBCT"] = function(msg)
  if msg == "bag" or msg == "inv" then
    ToggleInventoryWindow()
  else
    if MainFrame and MainFrame:IsShown() then MainFrame:Hide() else OpenMainWindow() end
  end
end
