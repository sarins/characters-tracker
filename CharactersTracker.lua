-- ====================================================================
-- CharactersTracker, All Rights Reserved unless otherwise explicitly stated.
-- ====================================================================
local L = CharactersTracker_Locale

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

local MainFrame, DetailFrame, VaultFrame, FloatingButton

-- ==========================================
-- 1. 数据收集核心 (加入当前大版本/当前赛季双重安全过滤)
-- ==========================================
local function ScanCurrentCharacter()
  if not CharactersTrackerDB then CharactersTrackerDB = {} end
  local guid = UnitGUID("player")
  if not guid then return end

  -- 安全初始化角色节点
  if not CharactersTrackerDB[guid] then CharactersTrackerDB[guid] = {} end
  CharactersTrackerDB[guid].name = UnitName("player")
  CharactersTrackerDB[guid].realm = GetRealmName()
  CharactersTrackerDB[guid].class = select(2, UnitClass("player"))
  CharactersTrackerDB[guid].lastUpdate = time()
  CharactersTrackerDB[guid].gear = CharactersTrackerDB[guid].gear or {}
  CharactersTrackerDB[guid].vault = CharactersTrackerDB[guid].vault or {}

  -- A. 扫描当前装备与装等计算
  local _, officialIlvlEquipped = GetAverageItemLevel()

  local totalIlvl = 0
  local gearCount = 0

  for _, slotId in ipairs(SCAN_SLOTS) do
    local itemLink = GetInventoryItemLink("player", slotId)
    if itemLink then
      local ilvl = C_Item.GetDetailedItemLevelInfo(itemLink) or 0
      local _, enchantId = string.split(":", itemLink)
      local hasEnchant = (enchantId and enchantId ~= "" and enchantId ~= "0") and true or false

      CharactersTrackerDB[guid].gear[slotId] = {
        link = itemLink,
        level = ilvl,
        enchant = hasEnchant
      }

      -- 过滤衬衣和战袍(4 and 19)，其余有效装备计入平均装等
      -- print("NO. "..slotId..itemLink)
      if slotId ~= 4 and slotId ~= 19 and ilvl > 0 then
        totalIlvl = totalIlvl + ilvl
        gearCount = gearCount + 1
      end
    else
      CharactersTrackerDB[guid].gear[slotId] = {}
    end
  end

  -- save avg level of items
  if officialIlvlEquipped and officialIlvlEquipped > 0 then
    CharactersTrackerDB[guid].avgIlvl = officialIlvlEquipped
  else
    CharactersTrackerDB[guid].avgIlvl = gearCount > 0 and tonumber(string.format("%.2f", totalIlvl / gearCount)) or 0
  end

  -- B. 扫描三线宏伟宝库数据（带当前大版本有效性拦截）
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

            -- ------------------------------------------------------------
            -- 【核心修复一】精准清洗过滤：非当前大版本的团队副本格子
            -- ------------------------------------------------------------
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

            -- ------------------------------------------------------------
            -- 【核心修复二】精准清洗过滤：非当前有效赛季的地下城格子
            -- ------------------------------------------------------------
            if vType.id == 2 then
              if not activityInfo.activityID or not activityInfo.threshold or activityInfo.threshold == 0 then
                isValid = false
              end

              if activityInfo.progress and activityInfo.progress > 100 then
                isValid = false
              end
            end

            -- ------------------------------------------------------------
            -- 只有真正通过了当前大版本/当前赛季校验的数据，才允许记入本地数据库
            -- ------------------------------------------------------------
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

-- ==========================================
-- 2. 通用 UI 窗体工厂
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
-- 3. 创建二级纯色/图标混合面板 (角色装备详情)
-- ==========================================
local function CreateDetailWindow()
  if DetailFrame then return end

  DetailFrame = CreateBaseWindow("CGT_DetailFrame", 260, 360, L["GEAR_DETAIL"], "DetailFramePosition")
  DetailFrame:Hide()
  DetailFrame.slotsUI = {}
  local colXOffsets = { 25, 80, 145, 200 }

  -- 创建详细面板顶部的总装等文本显示（定位于中间两列的顶部区域）
  DetailFrame.avgIlvlText = DetailFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  DetailFrame.avgIlvlText:SetPoint("TOP", DetailFrame, "TOP", 0, -35)

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

      slotBtn.ilvlText = slotBtn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
      slotBtn.ilvlText:SetPoint("BOTTOMRIGHT", slotBtn, "BOTTOMRIGHT", -1, 1)

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

  -- 动态更新面板顶部的平均物品等级
  if data.avgIlvl and data.avgIlvl > 0 then
    -- DetailFrame.avgIlvlText:SetText(string.format("|cffffffff%d|r", data.avgIlvl))
    DetailFrame.avgIlvlText:SetText(string.format("|cffffd100%.2f|r", data.avgIlvl))
  else
    DetailFrame.avgIlvlText:SetText("")
  end

  for _, slotId in ipairs(SCAN_SLOTS) do
    local btn = DetailFrame.slotsUI[slotId]
    local gear = data.gear and data.gear[slotId]

    if gear and gear.link then
      local itemTexture = C_Item.GetItemIconByID(gear.link)
      btn.icon:SetColorTexture(1, 1, 1, 1)
      btn.icon:SetTexture(itemTexture or 134400)
      btn.itemLink = gear.link
      btn.ilvlText:SetText(gear.level > 0 and gear.level or "")

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
      btn.ilvlText:SetText("")
      btn.enchantDot:Hide()
      btn:SetBackdropBorderColor(0.15, 0.15, 0.15, 0.8)
      btn:SetScript("OnEnter", nil)
    end
  end
  DetailFrame:Show()
end

-- ==========================================
-- 4. 创建第三窗口 (宏伟宝库三线进度面板)
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
          sFrame.bg:SetColorTexture(0.1, 0.45, 0.1, 0.85)
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
-- 5. 一级角色列表主窗
-- ==========================================
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
  end

  for _, btn in ipairs(MainFrame.buttons) do
    btn:Hide()
    if btn.extraBtn then btn.extraBtn:Hide() end
  end

  local index = 0
  if CharactersTrackerDB then
    for guid, data in pairs(CharactersTrackerDB) do
      if type(data) == "table" and data.name then
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

          -- 名字组件：向右限制宽度，给右侧装等留出安全对齐空间，避免长文本重叠
          btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
          btn.text:SetPoint("LEFT", btn, "LEFT", 8, 0)
          btn.text:SetPoint("RIGHT", btn, "RIGHT", -55, 0)
          btn.text:SetJustifyH("LEFT")

          -- 新增：右侧装等组件，居右对齐
          btn.ilvlText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
          btn.ilvlText:SetPoint("RIGHT", btn, "RIGHT", -10, 0)
          btn.ilvlText:SetJustifyH("RIGHT")

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
        end

        btn:SetPoint("TOPLEFT", MainFrame.content, "TOPLEFT", 2, -(index - 1) * 34)
        btn.extraBtn:SetPoint("LEFT", btn, "RIGHT", 4, 0)

        local classColor = RAID_CLASS_COLORS[data.class] and RAID_CLASS_COLORS[data.class].colorStr or "ffffffff"
        btn.text:SetText(string.format("|c%s%s|r (|cff888888%s|r)", classColor, data.name, data.realm))

        -- 动态显示角色的平均物品等级
        if data.avgIlvl and data.avgIlvl > 0 then
          -- btn.ilvlText:SetText(string.format("|cffffd100%d|r", data.avgIlvl))
          btn.ilvlText:SetText(string.format("|cffffd100%.2f|r", data.avgIlvl))
        else
          btn.ilvlText:SetText("|cff888888--|r")
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

        btn:Show()
        btn.extraBtn:Show()
      end
    end
  end
  MainFrame:Show()
end

-- ==========================================
-- 6. 独立悬浮触发按钮设计
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

  FloatingButton:SetScript("OnClick", function()
    if MainFrame and MainFrame:IsShown() then MainFrame:Hide() else OpenMainWindow() end
  end)

  FloatingButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(L["FB_FUNC"], 1, 1, 1)
    GameTooltip:AddLine(L["FB_L1"], 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L["FB_L2"], 0.8, 0.8, 0.8)
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
-- 7. 后台监听自动记录
-- ==========================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("WEEKLY_REWARDS_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" and arg1 == "CharactersTracker" then
    if not CharactersTrackerDB then CharactersTrackerDB = {} end

    if MainFrame and CharactersTrackerDB["MainFramePosition"] then
      local pos = CharactersTrackerDB["MainFramePosition"]
      MainFrame:ClearAllPoints()
      MainFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)
    end
    if DetailFrame and CharactersTrackerDB["DetailFramePosition"] then
      local pos = CharactersTrackerDB["DetailFramePosition"]
      DetailFrame:ClearAllPoints()
      DetailFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)
    end
    if VaultFrame and CharactersTrackerDB["VaultFramePosition"] then
      local pos = CharactersTrackerDB["VaultFramePosition"]
      VaultFrame:ClearAllPoints()
      VaultFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)
    end
  elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_EQUIPMENT_CHANGED" or event == "WEEKLY_REWARDS_UPDATE" then
    if C_WeeklyRewards and C_WeeklyRewards.RequestActivityInfo then
      pcall(C_WeeklyRewards.RequestActivityInfo)
    end

    if event == "PLAYER_ENTERING_WORLD" then
      CreateFloatingButton()
    end

    -- 留出 1.5 秒安全等待延迟，确保暴雪服务器完整下发角色低保元数据后再执行清洗提取
    C_Timer.After(1.5, function() ScanCurrentCharacter() end)
  end
end)

-- ==========================================
-- 8. 命令注册
-- ==========================================
SLASH_WBCT1 = "/wbct"
SLASH_WBCT2 = "/ct"
SlashCmdList["WBCT"] = function()
  if MainFrame and MainFrame:IsShown() then MainFrame:Hide() else OpenMainWindow() end
end
