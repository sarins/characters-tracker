-- ====================================================================
-- CharactersTracker, All Rights Reserved unless otherwise explicitly stated.
-- ====================================================================

local _namespace, addon = ...
local L = CharactersTracker_Locale

-- ====================================================================
-- Prefix of naming
-- CLP = Characters List Panel
-- CGP = Character Gear Panel
-- ====================================================================

-- ITEM_QUALITY_COLORS[0].color ：垃圾灰（适合做离线很久、或者未激活的号）。
-- ITEM_QUALITY_COLORS[2].color ：优秀绿（适合做正常、安全的指标）。
-- ITEM_QUALITY_COLORS[3].color ：精良蓝（适合做高亮）。
-- ITEM_QUALITY_COLORS[4].color ：史诗紫（适合做满级、或者大米高分数的号）。
-- ITEM_QUALITY_COLORS[5].color ：传说橙（适合做最核心、最显眼的数据）。

-- /dump x = ITEM_QUALITY_COLORS[3].color:GenerateHexColorString()

local MAX_LEVEL_OF_CHARACTER = GetMaxLevelForPlayerExpansion()

local BASIC_STATS_LAYOUT = { "STRENGTH", "AGILITY", "INTELLECT", "STAMINA", "ARMOR" }
local SECONDARY_STATS_LAYOUT = { "CRITICAL_STRIKE", "HASTE", "MASTERY", "VERSATILITY", "LIFESTEAL", "SPEED", "AVOIDANCE" }

local GEAR_SLOTS_LAYOUT = {
  [1] = { 1, 2, 3, 15, 5, 4, 19, 9 },   -- 第1列：头、颈、肩、背、胸、衬衣、战袍、腕
  [2] = { 16 },                         -- 第2列：主手
  [3] = { 17 },                         -- 第3列：副手
  [4] = { 10, 6, 7, 8, 11, 12, 13, 14 } -- 第4列：手、腰、腿、脚、指1、指2、饰1、饰2
}
local GEAR_SLOTS_MAPPING = { 1, 2, 3, 15, 5, 4, 19, 9, 16, 17, 10, 6, 7, 8, 11, 12, 13, 14 }

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

StaticPopupDialogs["CONFIRM_PURE_CHARACTER_DATA"] = {
  text = L["CT_CONFIRM_REMOVE_CHARACTER_DATA"],
  button1 = L["CT_CONFIRM_Y"],
  button2 = L["CT_CONFIRM_N"],
  OnAccept = function(self, c) addon:PureCharacterData(c) end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
}

-- SecondsToTimeAbbrev
local function S2TA(c, f)
  if c and c[f] and "number" == type(c[f]) then
    local delta = time() - c[f]
    if (delta < 60) then
      return "< 1m"
    end
    return string.format(SecondsToTimeAbbrev(delta))
  end
  return ""
end

local FORMATTERS = {
  NAME = function(c)
    if c and c.name and c.class then
      local cc = RAID_CLASS_COLORS[c.class] and RAID_CLASS_COLORS[c.class].colorStr or "ffffffff"
      return string.format("|c%s%s|r", cc, c.name)
    end
    return ""
  end,
  CLASS = function(c)
    if c and c.class then
      local cc = RAID_CLASS_COLORS[c.class] and RAID_CLASS_COLORS[c.class].colorStr or "ffffffff"
      local cn = LOCALIZED_CLASS_NAMES_MALE[c.class]
      return string.format("|c%s%s|r", cc, cn or c.class)
    end
    return ""
  end,
  CLASS_COLOR = function(c, s)
    if c and c.class then
      local cc = RAID_CLASS_COLORS[c.class] and RAID_CLASS_COLORS[c.class].colorStr or "ffffffff"
      return string.format("|c%s%s|r", cc, s)
    end
    return ""
  end,
  REALM = function(c)
    return c and c.realm or ""
  end,
  LEVEL = function(c)
    if c and c.level and c.level > 0 then
      if c.level < MAX_LEVEL_OF_CHARACTER then
        return string.format("%s", c.level)
      end
      return string.format("|cffffd100%s|r", c.level)
    end
    return ""
  end,
  FACTION = function(c)
    if c and c.faction then
      if "Alliance" == c.faction or "联盟" == c.faction then
        return string.format("|cff0070de%s|r", c.faction)
      elseif "Horde" == c.faction or "部落" == c.faction then
        return string.format("|cffc41f3b%s|r", c.faction)
      else
      end
    end
    return ""
  end,
  ZONE = function(c)
    return c and c.zone or ""
  end,
  ITEM_LEVEL_FLOOR = function(c)
    if c and "number" == type(c.equippedLevel) then
      local equippedLevel = math.floor(c.equippedLevel)
      if equippedLevel > 233 then
        return string.format("%s%s|r", ITEM_QUALITY_COLORS[4].hex, equippedLevel)
      elseif equippedLevel > 220 then
        return string.format("%s%s|r", ITEM_QUALITY_COLORS[3].hex, equippedLevel)
      elseif equippedLevel > 130 then
        return string.format("%s%s|r", ITEM_QUALITY_COLORS[2].hex, equippedLevel)
      else
        return string.format("%s%s|r", ITEM_QUALITY_COLORS[1].hex, equippedLevel)
      end
    end
    return ""
  end,
  ITEM_LEVEL = function(c)
    return c and c.equippedLevel or 0
  end,
  VAULT = function(c)
  end,
  M_SCORE = function(c)
    return string.format("%d", c and c.mScore or 0)
  end,
  PLAYED = function(c)
    return string.format(
      "%s / %s",
      string.format(SecondsToTimeAbbrev(c.levelPlayed or 0)),
      string.format(SecondsToTimeAbbrev(c.played or 0))
    )
  end,
  GOLD_FLOOR = function(c)
    local gold = math.abs(c and c.gold or 0)
    return FormatLargeNumber(math.floor(gold / 10000))
  end,
  GOLD = function(c)
    return c and ((c.gold or 0) / 10000)
  end,
  UPDATED2TA = function(c)
    return S2TA(c, "updated")
  end,
}

local CT_THEME = {
  -- 1. 主窗体 (Main Frame) 尺寸与颜色
  FONTS = {
    TTF      = "Interface\\AddOns\\CharactersTracker\\font\\MicrosoftYaHeiUI-02.ttf",
    SETTINGS = {
      TINY       = { 10, "OUTLINE" },
      MINI       = { 11, "OUTLINE" },
      SMALL      = { 12, "OUTLINE" },
      SMALL_BOLD = { 12, "THICKOUTLINE" },
      NORMAL     = { 14, "OUTLINE" },
      BIG        = { 18, "OUTLINE" },
      HUGE       = { 22, "OUTLINE" },
    },
  },
  CLP = {
    HEIGHT             = 600,
    SCROLL_BAR_PADDING = 23,
    BG                 = {
      COLOR = { 0.08, 0.09, 0.11, 0.95 },
    },
    BANNER             = {
      HEIGHT = 32,
      BG = {
        -- COLOR = { 0.06, 0.06, 0.06 },
        COLOR = { 0.04, 0.05, 0.06, 0.95 },
      },
      LINE = {
        HEIGHT = 1,
        COLOR = { 0.16, 0.18, 0.22, 1.00 },
      },
      ICON = {
        TEXTURE = "Interface\\AddOns\\CharactersTracker\\media\\icon.tga",
        SIZE = { 24, 24 },
        POINT = { 8, 0 },
      },
      TITLE = {
        COLOR = { 1.0, 0.82, 0.0 },
        POINT = { 36, 0 }
      },
      CHOICE = {
        TEXTURE = "Interface\\AddOns\\CharactersTracker\\media\\characters.tga",
        SIZE = { 16, 16 },
        POINT = { -136, 0 }
      },
      COLUMNS = {
        TEXTURE = "Interface\\AddOns\\CharactersTracker\\media\\detail.tga",
        SIZE = { 16, 16 },
        POINT = { -112, 0 }
      },
      SETTINGS = {
        TEXTURE = "Interface\\AddOns\\CharactersTracker\\media\\gear.tga",
        SIZE = { 16, 16 },
        POINT = { -88, 0 }
      },
      LOCKER = {
        TEXTURE = "Interface\\AddOns\\CharactersTracker\\media\\lock.tga",
        SIZE = { 16, 16 },
        POINT = { -64, 0 }
      },
      CLOSE = {
        TEXTURE = "Interface\\AddOns\\CharactersTracker\\media\\close.tga",
        SIZE = { 24, 24 },
        POINT = { -8, 0 }
      },
    },
    GRID               = {
      HEADER = {
        HEIGHT = 32,
        BG = {
          -- COLOR = { 0.04, 0.05, 0.06, 0.95 },
          COLOR = { 0.06, 0.06, 0.06 },
        },
        LINE = {
          HEIGHT = 1,
          COLOR = { 0.16, 0.18, 0.22, 1.00 },
        },
        TEXT = {
          COLOR = { 0.55, 0.57, 0.61 },
        },
      },
      ROW = {
        HEIGHT  = 26,
        SPACING = 1,                         -- 行间距
        BG      = {
          ODD  = { 0.11, 0.12, 0.15, 0.45 }, -- 奇数行背景
          EVEN = { 0.07, 0.08, 0.10, 0.25 },
        },
      },
      CELL = {
        PADDING = 24,
        CHECKER = {
          SIZE            = { 12, 12 },
          CHECKED_COLOR   = { 0.20, 0.75, 0.40, 1.00 }, -- 已勾选绿
          UNCHECKED_COLOR = { 0.18, 0.21, 0.26, 0.8 },  -- 未勾选灰
        },
        CURRENCIES = {
          TEXTURE = "Interface\\AddOns\\CharactersTracker\\media\\storage.tga",
          SIZE = { 16, 16 },
        },
        REMOVE = {
          TEXTURE = "Interface\\AddOns\\CharactersTracker\\media\\close.tga",
          SIZE = { 16, 16 },
        },
      },
    },
    FOOTER             = {
      HEIGHT = 32,
      BG = {
        COLOR = { 0.04, 0.05, 0.06, 0.95 },
      },
      LINE = {
        HEIGHT = 1,
        COLOR = { 0.16, 0.18, 0.22, 1.00 },
      },
      TEXT = {
        COLOR = { 0.50, 0.50, 0.50 },
      }
    },
    MENU               = {
      WIDTH = 180,
      BG = {
        COLOR = { 0.04, 0.05, 0.06, 0.6 },
      },
      BORDER = {
        COLOR = { 0.18, 0.20, 0.24, 0.40 },
      },
      ITEM = {
        HEIGHT  = 24,
        SPACING = 8,
        CHECKER = {
          SIZE            = { 12, 12 },
          CHECKED_COLOR   = { 0.20, 0.75, 0.40, 1.00 }, -- 已勾选绿
          UNCHECKED_COLOR = { 0.25, 0.25, 0.25, 1.00 }, -- 未勾选灰
        },
        TEXT    = {
          CHECKED_COLOR = { 0.9, 0.9, 0.9 },
          UNCHECKED_COLOR = { 0.5, 0.5, 0.5 },
        },
        HL      = {
          COLOR = { 0.16, 0.18, 0.22, 0.50 },
        }, -- Highlight
      },
    },
  },
  CGP = {
    WIDTH  = 280,
    HEIGHT = 480,
    BG     = {
      COLOR = { 0.08, 0.09, 0.11, 0.95 },
    },
    BANNER = {
      HEIGHT = 32,
      BG = {
        COLOR = { 0.04, 0.05, 0.06, 0.95 },
      },
      LINE = {
        HEIGHT = 1,
        COLOR = { 0.16, 0.18, 0.22, 1.00 },
      },
      ICON = {
        TEXTURE = "Interface\\AddOns\\CharactersTracker\\media\\icon.tga",
        SIZE = { 24, 24 },
        POINT = { 8, 0 },
      },
      TITLE = {
        COLOR = { 1.0, 0.82, 0.0 },
        POINT = { 36, 0 }
      },
      CLOSE = {
        TEXTURE = "Interface\\AddOns\\CharactersTracker\\media\\close.tga",
        SIZE = { 24, 24 },
        POINT = { -8, 0 }
      },
    },
    DETAIL = {
      HEADLINE = {
        HEIGHT = 40,
        FONT = "BIG",
      },
      BAR      = {
        HEIGHT = 24,
        BG = {
          COLOR = { 0.2, 0.2, 0.2, 0.95 },
        },
        LINE = {
          HEIGHT = 1,
          COLOR = { 0.16, 0.18, 0.22, 1.00 },
        },
        TITLE = {
          COLOR = { 0.9, 0.9, 0.9 },
          FONT = "MINI"
        },
      },
      PROP     = {
        HEIGHT = 20,
        BG = {
          ODD  = { 0.1, 0.1, 0.1, 0.8 }, -- 奇数行背景
          EVEN = { 0.15, 0.15, 0.15, 0.9 },
        },
        TEXT_COLOR = { 1.0, 0.82, 0.0 },
        VALUE_COLOR = { 0.9, 0.9, 0.9 },
        FONT = "TINY",
        PADDING = 4,
      },
    },
    SLOT   = {
      ICON = {
        COLOR = { 0, 0, 0 },
      },
      QUALITY = {
        SIZE = { 8, 8 },
        COLOR = { 1, 1, 1 },
        POINT = { 0, 0 },
      },
      ITEM_LEVEL = {
        FONT = "MINI",
        PADDING = 2,
        COLOR = { 1, 1, 1 },
      }
    }
  },
  CGP2 = {},
}

local META = {
  CLP = {
    COLS = {
      { id = "VISIBLE",    label = L["CLP_LABEL_VISIBLE"],    formatter = "",                          fixed = true,  align = "CENTER", width = 80 },
      { id = "NAME",       label = L["CLP_LABEL_NAME"],       formatter = FORMATTERS.NAME,             fixed = true,  align = "CENTER" },
      { id = "CLASS",      label = L["CLP_LABEL_CLASS"],      formatter = FORMATTERS.CLASS,            fixed = false, align = "CENTER" },
      { id = "REALM",      label = L["CLP_LABEL_REALM"],      formatter = FORMATTERS.REALM,            fixed = false, align = "CENTER" },
      { id = "LEVEL",      label = L["CLP_LABEL_LEVEL"],      formatter = FORMATTERS.LEVEL,            fixed = false, align = "CENTER" },
      { id = "FACTION",    label = L["CLP_LABEL_FACTION"],    formatter = FORMATTERS.FACTION,          fixed = false, align = "CENTER" },
      { id = "ZONE",       label = L["CLP_LABEL_ZONE"],       formatter = FORMATTERS.ZONE,             fixed = false, align = "CENTER" },
      { id = "ITEM_LEVEL", label = L["CLP_LABEL_ITEM_LEVEL"], formatter = FORMATTERS.ITEM_LEVEL_FLOOR, fixed = false, align = "CENTER" },
      { id = "RV",         label = L["CLP_LABEL_RV"],         formatter = "",                          fixed = false, align = "CENTER" },
      { id = "DV",         label = L["CLP_LABEL_DV"],         formatter = "",                          fixed = false, align = "CENTER" },
      { id = "WV",         label = L["CLP_LABEL_WV"],         formatter = "",                          fixed = false, align = "CENTER" },
      { id = "M_SCORE",    label = L["CLP_LABEL_M_SCORE"],    formatter = FORMATTERS.M_SCORE,          fixed = false, align = "CENTER" },
      { id = "PLAYED",     label = L["CLP_LABEL_PLAYED"],     formatter = FORMATTERS.PLAYED,           fixed = false, align = "CENTER" },
      { id = "GOLD",       label = L["CLP_LABEL_GOLD"],       formatter = FORMATTERS.GOLD_FLOOR,       fixed = false, align = "RIGHT" },
      { id = "CURRENCIES", label = L["CLP_LABEL_CURRENCIES"], formatter = "",                          fixed = false, align = "CENTER", width = 64 },
      { id = "PVP",        label = L["CLP_LABEL_PVP"],        formatter = "",                          fixed = false, align = "CENTER" },
      { id = "UPDATED",    label = L["CLP_LABEL_UPDATED"],    formatter = FORMATTERS.UPDATED2TA,       fixed = false, align = "CENTER" },
      { id = "OPERATION",  label = L["CLP_LABEL_OPERATION"],  formatter = "",                          fixed = true,  align = "CENTER", width = 64 },
    },
  },
}

function addon:X()
  print("Gui X() calling...")
end

function addon:InitWorkspace()
  self.GUI_FONTS = {}
  self.GUI_FONTS_MEASURMENT = {}
  self.CONFIGURABLE_META = {}

  for fn, f in pairs(CT_THEME.FONTS.SETTINGS) do
    local font = CreateFont("CT_THEME_FONT_" .. fn)
    font:SetFont(CT_THEME.FONTS.TTF, f[1], f[2])
    self.GUI_FONTS[fn] = font
    local measurment = UIParent:CreateFontString(nil, "OVERLAY")
    measurment:SetFontObject(font)
    measurment:Hide()
    self.GUI_FONTS_MEASURMENT[fn] = measurment
  end

  for _, meta in ipairs(META.CLP.COLS) do
    if not meta.fixed then
      table.insert(self.CONFIGURABLE_META, meta)
    end
  end
end

-- function addon:Util_FrameMarginAll(child, parent, margin)
--   child:SetPoint("TOPLEFT", parent, "TOPLEFT", margin, -margin)
--   child:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -margin, margin)
-- end

-- Base moveable window factory
function addon:Util_CreateBaseWindow(name, parent)
  local positions = CharactersTrackerDB.SETTINGS.POSITIONS
  local f = CreateFrame("Frame", name, parent, "BackdropTemplate")

  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  local posKey = string.format("%s_%s", name, "Position")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
    positions[posKey] = { point = point, relativePoint = relativePoint, xOfs = xOfs, yOfs = yOfs }
  end)

  local pos = positions[posKey]
  if pos and "table" == type(pos) then
    f:ClearAllPoints()
    f:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)
  else
    f:SetPoint("CENTER")
  end

  tinsert(UISpecialFrames, name)
  return f
end

function addon:Util_CreateBanner(name, parent, title, theme)
  local banner = CreateFrame("Frame", name, parent)
  banner:SetWidth(parent:GetWidth())
  banner:SetHeight(theme.HEIGHT)
  banner:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)

  local bg = banner:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(unpack(theme.BG.COLOR))

  local line = banner:CreateTexture(nil, "OVERLAY")
  line:SetHeight(theme.LINE.HEIGHT)
  line:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", 0, 0)
  line:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", 0, 0)
  line:SetColorTexture(unpack(theme.LINE.COLOR))

  local icon = banner:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("LEFT", unpack(theme.ICON.POINT))
  icon:SetSize(unpack(theme.ICON.SIZE))
  icon:SetTexture(theme.ICON.TEXTURE)

  local t = banner:CreateFontString(nil, "OVERLAY")
  t:SetFontObject(self.GUI_FONTS["NORMAL"])
  t:SetPoint("LEFT", banner, "LEFT", unpack(theme.TITLE.POINT))
  t:SetTextColor(unpack(theme.TITLE.COLOR))
  t:SetText(title)

  local close = addon:Util_CreateButton(nil, banner, theme.CLOSE.TEXTURE, unpack(theme.CLOSE.SIZE))
  close:SetPoint("RIGHT", banner, "RIGHT", unpack(theme.CLOSE.POINT))
  close:SetScript("OnClick", function()
    parent:Hide()
  end)
  return banner
end

-- Dropdown menu
function addon:HideAllMenus()
  if self.L1Menu then self.L1Menu:Hide() end
  if self.L2Menu then self.L2Menu:Hide() end
  self:CancelMenuDimissTimer()
end

function addon:PureCharacterData(character)
  -- TODO delete
  print(character.name .. " has been data deleted.")
  addon:ClpRefreshGrid()
end

-- 智能缓冲器：当鼠标离开菜单群落后，提供 0.2 秒的缓冲期防止滑出误触闭合
function addon:StartMenuDismissTimer(target)
  if not self.DismissTimerFrame then
    self.DismissTimerFrame = CreateFrame("Frame")
  end
  local elapsed = 0
  self.DismissTimerFrame:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed >= 0.2 then
      if target then target:Hide() end
      addon.DismissTimerFrame:SetScript("OnUpdate", nil)
    end
  end)
end

function addon:CancelMenuDimissTimer()
  if self.DismissTimerFrame then
    self.DismissTimerFrame:SetScript("OnUpdate", nil)
  end
end

-- Unsafe, for ShowSettingsMenu use only
function addon:CreateDropdownMenu(parent, frameLevel)
  local menu = CreateFrame("Frame", nil, parent, "VerticalLayoutFrame")
  menu:SetFrameStrata("DIALOG")
  menu:SetFrameLevel(frameLevel)
  menu:SetWidth(CT_THEME.CLP.MENU.WIDTH)
  menu:SetClampedToScreen(true)
  menu:EnableMouse(true)

  local bg = menu:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(unpack(CT_THEME.CLP.MENU.BG.COLOR))

  local border = menu:CreateTexture(nil, "OVERLAY")
  border:SetAllPoints()
  border:SetColorTexture(unpack(CT_THEME.CLP.MENU.BORDER.COLOR))

  -- Mouse entering and leaving events
  menu:SetScript("OnEnter", function() addon:CancelMenuDimissTimer() end)
  menu:SetScript("OnLeave", function() addon:StartMenuDismissTimer(menu) end)

  return menu
end

function addon:ShowSettingsMenu(anchor)
  local font = self.GUI_FONTS["SMALL_BOLD"]
  local hiddenColumns = CharactersTrackerDB.SETTINGS.CLP.HIDDEN_COLUMNS
  local settingsItems = self.CT_CLP_STATUS.settingsItems

  if not self.CT_CLP_SEETINGS_MENU then
    self.CT_CLP_SEETINGS_MENU = addon:CreateDropdownMenu(self.CT_CLP, 110)
  end

  self.CT_CLP_SEETINGS_MENU:ClearAllPoints()
  self.CT_CLP_SEETINGS_MENU:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", CT_THEME.CLP.BANNER.SETTINGS.POINT[1], -4)

  for _, item in ipairs(settingsItems) do item:Hide() end

  for i, meta in ipairs(self.CONFIGURABLE_META) do
    local settingsItem = settingsItems[i]
    if not settingsItem then
      settingsItem = CreateFrame("Button", nil, self.CT_CLP_SEETINGS_MENU)
      settingsItem:SetHeight(CT_THEME.CLP.MENU.ITEM.HEIGHT)

      local cb = settingsItem:CreateTexture(nil, "ARTWORK")
      cb:SetSize(unpack(CT_THEME.CLP.MENU.ITEM.CHECKER.SIZE))
      cb:SetPoint("LEFT", settingsItem, "LEFT", CT_THEME.CLP.MENU.ITEM.SPACING, 0)
      settingsItem.cb = cb

      local text = settingsItem:CreateFontString(nil, "OVERLAY")
      text:SetFontObject(font)
      text:SetPoint("LEFT", cb, "RIGHT", CT_THEME.CLP.MENU.ITEM.SPACING, 0)
      settingsItem.text = text

      local hl = settingsItem:CreateTexture(nil, "BACKGROUND")
      hl:SetAllPoints()
      hl:SetColorTexture(unpack(CT_THEME.CLP.MENU.ITEM.HL.COLOR))
      hl:Hide()
      settingsItem.hl = hl

      settingsItems[i] = settingsItem
    end

    settingsItem.layoutIndex = i
    settingsItem:SetWidth(self.CT_CLP_SEETINGS_MENU:GetWidth())
    settingsItem.text:SetText(meta.label)

    if hiddenColumns[meta.id] then
      settingsItem.cb:SetColorTexture(unpack(CT_THEME.CLP.MENU.ITEM.CHECKER.UNCHECKED_COLOR))
      settingsItem.text:SetTextColor(unpack(CT_THEME.CLP.MENU.ITEM.TEXT.UNCHECKED_COLOR))
    else
      settingsItem.cb:SetColorTexture(unpack(CT_THEME.CLP.MENU.ITEM.CHECKER.CHECKED_COLOR))
      settingsItem.text:SetTextColor(unpack(CT_THEME.CLP.MENU.ITEM.TEXT.CHECKED_COLOR))
    end

    settingsItem:SetScript("OnEnter", function(this)
      addon:CancelMenuDimissTimer()
      this.hl:Show()
    end)
    settingsItem:SetScript("OnLeave", function(this)
      this.hl:Hide()
      addon:StartMenuDismissTimer(self.CT_CLP_SEETINGS_MENU)
    end)

    settingsItem:SetScript("OnClick", function()
      hiddenColumns[meta.id] = not hiddenColumns[meta.id] or nil
      addon:ClpRefreshGrid()
      addon:ShowSettingsMenu(anchor)
    end)

    settingsItem:Show()
  end
  self.CT_CLP_SEETINGS_MENU:Layout()
  self.CT_CLP_SEETINGS_MENU:Show()
end

function addon:Util_CreateButton(name, parent, texture, width, height)
  local btn = CreateFrame("Button", name, parent)
  btn:SetSize(width, height)
  local icon = btn:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("CENTER")
  icon:SetSize(width, height)
  icon:SetTexture(texture)
  return btn
end

function addon:ClpDynamicWidths()
  local hiddenColumns = CharactersTrackerDB.SETTINGS.CLP.HIDDEN_COLUMNS
  local hiddenCharacters = CharactersTrackerDB.SETTINGS.CLP.HIDDEN_CHARACTERS
  local widths = self.CT_CLP_STATUS.widths
  local measurment = self.GUI_FONTS_MEASURMENT["SMALL"]
  local measurmentBold = self.GUI_FONTS_MEASURMENT["SMALL_BOLD"]

  local totalWidth = 0
  for _, meta in ipairs(META.CLP.COLS) do
    if meta.id == "VISIBLE" and not self.CT_CLP_STATUS.choosable then
      widths[meta.id] = 0
    elseif meta.id == "OPERATION" and not self.CT_CLP_STATUS.operationable then
      widths[meta.id] = 0
    elseif hiddenColumns[meta.id] then
      widths[meta.id] = 0
    elseif meta.width and meta.width > 0 then
      widths[meta.id] = meta.width
    else
      measurmentBold:SetText(meta.label)
      local w = measurmentBold:GetStringWidth()

      for _id, character in pairs(CharactersTrackerDB.CHARACTERS) do
        if not self.CT_CLP_STATUS.choosable and hiddenCharacters[_id] then
          -- CONTINUE, because hidden while not choosable status
        else
          if "function" == type(meta.formatter) then
            local content = meta.formatter(character) -- make sure the formatter always safe return
            measurment:SetText(content)
            local tw = measurment:GetStringWidth()
            w = math.max(tw, w)
          end
        end
      end
      widths[meta.id] = w + CT_THEME.CLP.GRID.CELL.PADDING
    end
    totalWidth = totalWidth + widths[meta.id]
  end

  totalWidth = totalWidth + CT_THEME.CLP.SCROLL_BAR_PADDING

  addon.CT_CLP:SetWidth(totalWidth)
  addon.CT_CLP_BANNER:SetWidth(totalWidth)
  addon.CT_CLP_FOOTER:SetWidth(totalWidth)
  addon.CT_CLP_GRID_HEADER:SetWidth(totalWidth)
  addon.CT_CLP_GRID_SCROLL_CHILD:SetWidth(totalWidth)

  print(totalWidth)
  return totalWidth
end

function addon:ClpBanner()
  local banner = CreateFrame("Frame", "CT_CHARACTERS_LIST_PANEL_BANNER", self.CT_CLP)
  self.CT_CLP_BANNER = banner
  banner:SetHeight(CT_THEME.CLP.BANNER.HEIGHT)
  banner:SetPoint("TOPLEFT", self.CT_CLP, "TOPLEFT", 0, 0)

  local bg = banner:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(unpack(CT_THEME.CLP.BANNER.BG.COLOR))

  local line = banner:CreateTexture(nil, "OVERLAY")
  line:SetHeight(CT_THEME.CLP.BANNER.LINE.HEIGHT)
  line:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", 0, 0)
  line:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", 0, 0)
  line:SetColorTexture(unpack(CT_THEME.CLP.BANNER.LINE.COLOR))

  local icon = banner:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("LEFT", unpack(CT_THEME.CLP.BANNER.ICON.POINT))
  icon:SetSize(unpack(CT_THEME.CLP.BANNER.ICON.SIZE))
  icon:SetTexture(CT_THEME.CLP.BANNER.ICON.TEXTURE)

  local title = banner:CreateFontString(nil, "OVERLAY")
  title:SetFontObject(self.GUI_FONTS["NORMAL"])
  title:SetPoint("LEFT", banner, "LEFT", unpack(CT_THEME.CLP.BANNER.TITLE.POINT))
  title:SetTextColor(unpack(CT_THEME.CLP.BANNER.TITLE.COLOR))
  title:SetText(L["CT_TITLE"])

  local close = addon:Util_CreateButton(
    nil,
    banner,
    CT_THEME.CLP.BANNER.CLOSE.TEXTURE,
    unpack(CT_THEME.CLP.BANNER.CLOSE.SIZE)
  )
  close:SetPoint("RIGHT", banner, "RIGHT", unpack(CT_THEME.CLP.BANNER.CLOSE.POINT))
  close:SetScript("OnClick", function()
    self.CT_CLP:Hide()
  end)

  local choice = addon:Util_CreateButton(
    nil,
    banner,
    CT_THEME.CLP.BANNER.CHOICE.TEXTURE,
    unpack(CT_THEME.CLP.BANNER.CHOICE.SIZE)
  )
  choice:SetPoint("RIGHT", banner, "RIGHT", unpack(CT_THEME.CLP.BANNER.CHOICE.POINT))
  choice:SetScript("OnClick", function()
    addon.CT_CLP_STATUS.choosable = not addon.CT_CLP_STATUS.choosable
    addon:ClpRefreshGrid()
  end)

  local columns = addon:Util_CreateButton(
    nil,
    banner,
    CT_THEME.CLP.BANNER.COLUMNS.TEXTURE,
    unpack(CT_THEME.CLP.BANNER.COLUMNS.SIZE)
  )
  columns:SetPoint("RIGHT", banner, "RIGHT", unpack(CT_THEME.CLP.BANNER.COLUMNS.POINT))
  -- menu at here

  local settings = addon:Util_CreateButton(
    nil,
    banner,
    CT_THEME.CLP.BANNER.SETTINGS.TEXTURE,
    unpack(CT_THEME.CLP.BANNER.SETTINGS.SIZE)
  )
  settings:SetPoint("RIGHT", banner, "RIGHT", unpack(CT_THEME.CLP.BANNER.SETTINGS.POINT))
  -- Mouse action setup for settings button
  settings:SetScript("OnEnter", function()
    addon:CancelMenuDimissTimer()
    addon:ShowSettingsMenu(settings)
  end)
  settings:SetScript("OnLeave", function()
    addon:StartMenuDismissTimer(addon.CT_CLP_SEETINGS_MENU)
  end)

  local locker = addon:Util_CreateButton(
    nil,
    banner,
    CT_THEME.CLP.BANNER.LOCKER.TEXTURE,
    unpack(CT_THEME.CLP.BANNER.LOCKER.SIZE)
  )
  locker:SetPoint("RIGHT", banner, "RIGHT", unpack(CT_THEME.CLP.BANNER.LOCKER.POINT))
  locker:SetScript("OnClick", function()
    addon.CT_CLP_STATUS.operationable = not addon.CT_CLP_STATUS.operationable
    addon:ClpRefreshGrid()
  end)
end

function addon:ClpFooter()
  local footer = CreateFrame("Frame", "CT_CHARACTERS_LIST_PANEL_FOOTER", self.CT_CLP)
  self.CT_CLP_FOOTER = footer
  footer:SetHeight(CT_THEME.CLP.FOOTER.HEIGHT)
  footer:SetPoint("BOTTOMLEFT", self.CT_CLP, "BOTTOMLEFT", 0, 0)

  local bg = footer:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(unpack(CT_THEME.CLP.FOOTER.BG.COLOR))

  local line = footer:CreateTexture(nil, "OVERLAY")
  line:SetHeight(CT_THEME.CLP.FOOTER.LINE.HEIGHT)
  line:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, 0)
  line:SetPoint("TOPRIGHT", footer, "TOPRIGHT", 0, 0)
  line:SetColorTexture(unpack(CT_THEME.CLP.FOOTER.LINE.COLOR))
end

function addon:ClpGrid()
  local header = CreateFrame("Frame", "CT_CHARACTERS_LIST_PANEL_GRID_HEADER", self.CT_CLP, "HorizontalLayoutFrame")
  self.CT_CLP_GRID_HEADER = header
  header:SetHeight(CT_THEME.CLP.GRID.HEADER.HEIGHT)
  header:SetPoint("TOPLEFT", self.CT_CLP_BANNER, "BOTTOMLEFT", 0, 0)

  local bg = header:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(unpack(CT_THEME.CLP.GRID.HEADER.BG.COLOR))

  local line = header:CreateTexture(nil, "OVERLAY")
  line:SetHeight(CT_THEME.CLP.GRID.HEADER.LINE.HEIGHT)
  line:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
  line:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
  line:SetColorTexture(unpack(CT_THEME.CLP.GRID.HEADER.LINE.COLOR))

  -- local scroll = CreateFrame("ScrollFrame", "CT_CHARACTERS_LIST_PANEL_SCROLL", self.CT_CLP, "ScrollFrameTemplate")
  local scroll = CreateFrame("ScrollFrame", "CT_CHARACTERS_LIST_PANEL_SCROLL", self.CT_CLP, "UIPanelScrollFrameTemplate")
  self.CT_CLP_GRID_SCROLL = scroll
  scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
  scroll:SetPoint("BOTTOMRIGHT", self.CT_CLP_FOOTER, "TOPRIGHT", -CT_THEME.CLP.SCROLL_BAR_PADDING, 0)

  local scrollChild = CreateFrame("Frame", nil, scroll, "VerticalLayoutFrame")
  self.CT_CLP_GRID_SCROLL_CHILD = scrollChild
  scrollChild.spacing = CT_THEME.CLP.GRID.ROW.SPACING -- 每行之间的纵向间距
  scroll:SetScrollChild(scrollChild)
end

function addon:ClpRefreshGridHeader()
  local font = self.GUI_FONTS["SMALL_BOLD"]
  local widths = self.CT_CLP_STATUS.widths
  local labels = self.CT_CLP_STATUS.labels
  for _, l in pairs(labels) do l:Hide() end

  local idx = 0
  for _, meta in ipairs(META.CLP.COLS) do
    local w = widths[meta.id] or 0
    if w > 0 then
      local label = labels[meta.id] -- label is frame object
      if not label then
        label = CreateFrame("Frame", nil, self.CT_CLP_GRID_HEADER, "BackdropTemplate")
        labels[meta.id] = label
        label:SetSize(w, CT_THEME.CLP.GRID.HEADER.HEIGHT)
        label.text = label:CreateFontString(nil, "OVERLAY")
      end
      label.text:SetPoint("CENTER")
      label.text:SetFontObject(font)
      label.text:SetTextColor(unpack(CT_THEME.CLP.GRID.HEADER.TEXT.COLOR))
      label.text:SetText(meta.label)
      label:Show()
      label.layoutIndex = idx
      idx = idx + 1
    end
  end
  self.CT_CLP_GRID_HEADER:Layout()
end

function addon:ClpGridCell()
end

function addon:ClpGridRow()
end

function addon:ClpRefreshGrid()
  local xw = self:ClpDynamicWidths()
  addon:ClpRefreshGridHeader()

  local widths = self.CT_CLP_STATUS.widths
  local hiddenColumns = CharactersTrackerDB.SETTINGS.CLP.HIDDEN_COLUMNS
  local hiddenCharacters = CharactersTrackerDB.SETTINGS.CLP.HIDDEN_CHARACTERS
  local font = self.GUI_FONTS["SMALL"]
  local rows = self.CT_CLP_STATUS.rows
  local grid = self.CT_CLP_STATUS.grid
  for _, r in pairs(rows) do r:Hide() end

  for _rid, row in pairs(grid) do
    for _cid, cell in pairs(row) do
      cell:Hide()
    end
  end

  local rowIdx = 0
  local goldSummary = 0

  local orderKeeper = CharactersTrackerDB.SETTINGS.CHARACTERS_ORDER

  for _, _rid in ipairs(orderKeeper) do
    if not self.CT_CLP_STATUS.choosable and hiddenCharacters[_rid] then
      -- CONTINUE, because hidden while not choosable status
    else
      local character = CharactersTrackerDB.CHARACTERS[_rid]
      local row = rows[_rid]
      if not row then
        row = CreateFrame("Frame", nil, self.CT_CLP_GRID_SCROLL_CHILD, "HorizontalLayoutFrame")
        rows[_rid] = row
        row.bg = row:CreateTexture(nil, "BACKGROUND")
      end
      row.layoutIndex = rowIdx
      row.spacing = 0
      row:SetHeight(CT_THEME.CLP.GRID.ROW.HEIGHT)
      -- background
      row.bg:SetAllPoints()
      if bit.band(rowIdx, 1) == 0 then
        row.bg:SetColorTexture(unpack(CT_THEME.CLP.GRID.ROW.BG.ODD))
      else
        row.bg:SetColorTexture(unpack(CT_THEME.CLP.GRID.ROW.BG.EVEN))
      end

      local columnIdx = 0
      local cells = grid[_rid] or {}
      grid[_rid] = cells

      for _, meta in ipairs(META.CLP.COLS) do
        local w = widths[meta.id] or 0
        if w > 0 then
          local cell = cells[meta.id]
          if "VISIBLE" == meta.id then
            if not cell then
              cell = CreateFrame("Frame", nil, row, "BackdropTemplate")
              cells[meta.id] = cell
              cell.cb = CreateFrame("CheckButton", nil, cell)
              cell.cb:SetSize(unpack(CT_THEME.CLP.GRID.CELL.CHECKER.SIZE))
              local unchecked = cell.cb:CreateTexture(nil, "BACKGROUND")
              unchecked:SetAllPoints()
              unchecked:SetColorTexture(unpack(CT_THEME.CLP.GRID.CELL.CHECKER.UNCHECKED_COLOR))
              local checked = cell.cb:CreateTexture(nil, "OVERLAY")
              checked:SetAllPoints()
              checked:SetColorTexture(unpack(CT_THEME.CLP.GRID.CELL.CHECKER.CHECKED_COLOR))
              cell.cb:SetCheckedTexture(checked)
            end
            cell:SetSize(widths[meta.id], CT_THEME.CLP.GRID.ROW.HEIGHT)
            cell.cb:SetPoint("CENTER")
            cell.cb:SetChecked(hiddenCharacters[_rid] or false)
            cell.cb:SetScript("OnClick", function(selfBtn)
              hiddenCharacters[_rid] = selfBtn:GetChecked() and true or nil
            end)
            cell:Show()
          elseif "CURRENCIES" == meta.id then
            if not cell then
              cell = CreateFrame("Frame", nil, row, "BackdropTemplate")
              cells[meta.id] = cell
              cell.currencies = addon:Util_CreateButton(
                nil,
                cell,
                CT_THEME.CLP.GRID.CELL.CURRENCIES.TEXTURE,
                unpack(CT_THEME.CLP.GRID.CELL.CURRENCIES.SIZE)
              )
            end
            cell:SetSize(widths[meta.id], CT_THEME.CLP.GRID.ROW.HEIGHT)
            cell.currencies:SetPoint("CENTER")
            cell.currencies:SetScript("OnEnter", function(self)
              addon:ShowCurrenciesTooltip(self, character)
            end)
            cell.currencies:SetScript("OnLeave", function()
              GameTooltip:Hide()
            end)
            cell:Show()
          elseif "OPERATION" == meta.id then
            if not cell then
              cell = CreateFrame("Frame", nil, row, "BackdropTemplate")
              cells[meta.id] = cell
              cell.del = addon:Util_CreateButton(
                nil,
                cell,
                CT_THEME.CLP.GRID.CELL.REMOVE.TEXTURE,
                unpack(CT_THEME.CLP.GRID.CELL.REMOVE.SIZE)
              )
            end
            cell:SetSize(widths[meta.id], CT_THEME.CLP.GRID.ROW.HEIGHT)
            cell.del:SetPoint("CENTER")
            cell.del:SetScript("OnClick", function()
              local dialog = StaticPopup_Show("CONFIRM_PURE_CHARACTER_DATA", character.name)
              if dialog then dialog.data = character end
            end)
            cell:Show()
          else
            if not cell then
              cell = CreateFrame("Frame", nil, row, "BackdropTemplate")
              cells[meta.id] = cell
              cell.text = cell:CreateFontString(nil, "OVERLAY")
            end
            cell:SetSize(widths[meta.id], CT_THEME.CLP.GRID.ROW.HEIGHT)
            cell.text:SetPoint(meta.align)
            cell.text:SetFontObject(font)
            if "function" == type(meta.formatter) then
              cell.text:SetText(meta.formatter(character))
            else
              -- do nothing
              cell.text:SetText("")
            end
            if "NAME" == meta.id then
              cell:EnableMouse(true)
              cell:SetScript("OnMouseDown", function(self, button)
                if button == "LeftButton" then
                  addon:ShowCgp(_rid)
                end
              end)
            end
            cell:Show()
          end
          cell.layoutIndex = columnIdx
          columnIdx = columnIdx + 1
        end
      end
      row:Layout()
      row:Show()
      rowIdx = rowIdx + 1
    end
  end
  self.CT_CLP_STATUS.grid = grid
  self.CT_CLP_GRID_SCROLL_CHILD:Layout()
  -- self:UpdateFixedFooter(totalGold, rowIndex)
end

function addon:ClpMain()
  if self.CT_CLP then
    addon:ClpRefreshGrid()
    self.CT_CLP:Show()
    return
  end

  self.CT_CLP_STATUS = {
    choosable = false,
    operationable = false,
    widths = {},
    labels = {},
    rows = {},
    grid = {},
    settingsItems = {},
    currenciesItems = {},
  }

  -- local clp = CreateFrame("Frame", "CT_CHARACTERS_LIST_PANEL", UIParent, "BackdropTemplate")
  local clp = addon:Util_CreateBaseWindow("CT_CHARACTERS_LIST_PANEL", UIParent)
  self.CT_CLP = clp

  clp:SetHeight(CT_THEME.CLP.HEIGHT)
  clp:SetFrameStrata("MEDIUM")
  -- clp:SetPoint("CENTER", UIParent, "CENTER")
  -- clp:SetClampedToScreen(true)
  -- clp:EnableMouse(true)
  -- clp:SetMovable(true)
  -- clp:RegisterForDrag("LeftButton")
  -- clp:SetScript("OnDragStart", clp.StartMoving)
  -- clp:SetScript("OnDragStop", clp.StopMovingOrSizing)
  clp:SetScript("OnHide", function()
    -- addon:HideAllMenus()
  end)

  local bg = clp:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(unpack(CT_THEME.CLP.BG.COLOR))

  addon:ClpBanner()
  addon:ClpFooter()
  addon:ClpGrid()
  addon:ClpRefreshGrid()
end

-- ==========================================
-- Currencies Tooltip
-- ==========================================
function addon:ShowCurrenciesTooltip(anchor, character)
  if not anchor or not character or not character.currencies then return end

  GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
  GameTooltip:ClearLines()

  GameTooltip:AddLine(FORMATTERS.NAME(character))
  GameTooltip:AddLine(" ")

  if character.currencies and next(character.currencies) then
    local hasAnyOutput = false
    for _, currencyID in ipairs(TRACKED_CURRENCIES) do
      local cData = character.currencies[currencyID]
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
-- Mini CLP
-- ==========================================
function addon:ClpMiniMain()
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
-- Characters Gear Detail
-- ==========================================
function addon:CpgDetailHeadline(name, parent)
  local container = CreateFrame("Frame", name, parent)
  container:SetWidth(parent:GetWidth())
  container:SetHeight(CT_THEME.CGP.DETAIL.HEADLINE.HEIGHT)
  container:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)

  container.text = container:CreateFontString(nil, "OVERLAY")
  container.text:SetFontObject(self.GUI_FONTS[CT_THEME.CGP.DETAIL.HEADLINE.FONT])
  container.text:SetPoint("CENTER")
  return container
end

function addon:CpgDetailBar(name, parent)
  local bar = CreateFrame("Frame", name, parent)
  bar:SetWidth(parent:GetWidth())
  bar:SetHeight(CT_THEME.CGP.DETAIL.BAR.HEIGHT)
  bar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)

  bar.bg = bar:CreateTexture(nil, "BACKGROUND")
  bar.bg:SetAllPoints()
  bar.bg:SetColorTexture(unpack(CT_THEME.CGP.DETAIL.BAR.BG.COLOR))

  bar.line = bar:CreateTexture(nil, "OVERLAY")
  bar.line:SetHeight(CT_THEME.CGP.DETAIL.BAR.LINE.HEIGHT)
  bar.line:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
  bar.line:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
  bar.line:SetColorTexture(unpack(CT_THEME.CGP.DETAIL.BAR.LINE.COLOR))

  bar.text = bar:CreateFontString(nil, "OVERLAY")
  bar.text:SetFontObject(self.GUI_FONTS[CT_THEME.CGP.DETAIL.BAR.TITLE.FONT])
  bar.text:SetPoint("CENTER")
  bar.text:SetTextColor(unpack(CT_THEME.CGP.DETAIL.BAR.TITLE.COLOR))

  return bar
end

function addon:CpgDetailProperty(name, parent)
  local prop = CreateFrame("Frame", name, parent)
  prop:SetWidth(parent:GetWidth())
  prop:SetHeight(CT_THEME.CGP.DETAIL.PROP.HEIGHT)
  prop:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)

  prop.bg = prop:CreateTexture(nil, "BACKGROUND")
  prop.bg:SetAllPoints()
  -- if odd then
  --   prop.bg:SetColorTexture(unpack(CT_THEME.CGP.DETAIL.PROP.BG.ODD))
  -- else
  --   prop.bg:SetColorTexture(unpack(CT_THEME.CGP.DETAIL.PROP.BG.EVEN))
  -- end

  prop.text = prop:CreateFontString(nil, "OVERLAY")
  prop.text:SetFontObject(self.GUI_FONTS[CT_THEME.CGP.DETAIL.PROP.FONT])
  prop.text:SetPoint("LEFT", CT_THEME.CGP.DETAIL.PROP.PADDING, 0)
  prop.text:SetTextColor(unpack(CT_THEME.CGP.DETAIL.PROP.TEXT_COLOR))

  prop.value = prop:CreateFontString(nil, "OVERLAY")
  prop.value:SetFontObject(self.GUI_FONTS[CT_THEME.CGP.DETAIL.PROP.FONT])
  prop.value:SetPoint("RIGHT", -CT_THEME.CGP.DETAIL.PROP.PADDING, 0)
  prop.value:SetTextColor(unpack(CT_THEME.CGP.DETAIL.PROP.VALUE_COLOR))

  return prop
end

function addon:CreateCgp()
  -- Make sure ONLY Create it once to avoid OOM
  if self.CT_CGP then
    return
  end
  --
  local cgp = addon:Util_CreateBaseWindow("CT_CHARACTER_GEAR_PANEL", self.CT_CLP)
  self.CT_CGP = cgp
  cgp:Hide()

  cgp:SetFrameStrata("DIALOG")
  cgp:SetSize(CT_THEME.CGP.WIDTH, CT_THEME.CGP.HEIGHT)

  local bg = cgp:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(unpack(CT_THEME.CGP.BG.COLOR))

  local banner = addon:Util_CreateBanner(
    "CT_CHARACTER_GEAR_PANEL_BANNER",
    self.CT_CGP,
    L["CGP_BANNER"],
    CT_THEME.CGP.BANNER
  )
  self.CT_CGP_BANNER = banner

  local content = CreateFrame("Frame", "CT_CHARACTER_GEAR_PANEL_CONTENT", self.CT_CGP, "BackdropTemplate")
  self.CT_CGP_CONTENT = content
  content:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 0, 0)
  content:SetPoint("BOTTOMRIGHT", self.CT_CGP, "BOTTOMRIGHT", 0, 0)

  content.slots = {}
  local W = content:GetWidth()
  local H = content:GetHeight()
  local w = 48 -- 基础列宽
  local h = 48 -- 基础行高
  local spaceX = (W - (4 * w)) / 5
  local spaceY = (H - (8 * h)) / 9

  -- 巨型格子的左上角坐标，正好是（第2列的横向偏移，第1行的纵向偏移）
  local bigOffsetX = (2 * spaceX) + ((2 - 1) * w)
  local bigOffsetY = (1 * spaceY) + ((1 - 1) * h)

  -- 巨型格子的宽度 = 2个列宽 + 中间夹着的那 1 个横向空白 (spaceX)
  local detailWidth = (2 * w) + spaceX
  -- 巨型格子的高度 = 7个行高 + 中间夹着的那 6 个纵向空白 (spaceY)
  local detailHeight = (7 * h) + (6 * spaceY)

  -- Name, item level bar, item level, prop bar, props, enhanced prop bar, enhanced props
  local detail = CreateFrame("Frame", "CT_CHARACTER_GEAR_PANEL_DETAIL", content, "VerticalLayoutFrame")
  self.CT_CGP_DETAIL = detail
  detail:SetSize(detailWidth, detailHeight)
  detail:SetPoint("TOPLEFT", content, "TOPLEFT", bigOffsetX, -bigOffsetY)

  -- Player
  detail.name = addon:CpgDetailHeadline(nil, detail)
  detail.name.layoutIndex = 0

  -- Equipped Level
  detail.equippedLevelBar = addon:CpgDetailBar(nil, detail)
  detail.equippedLevelBar.layoutIndex = 1
  detail.equippedLevelBar.text:SetText(L["CGP_ITEM_LEVEL"])

  detail.equippedLevel = addon:CpgDetailHeadline(nil, detail)
  detail.equippedLevel.layoutIndex = 2

  -- Basic Stat
  detail.basicStatBar = addon:CpgDetailBar(nil, detail)
  detail.basicStatBar.layoutIndex = 3
  detail.basicStatBar.text:SetText(L["CGP_ATTRIBUTES"])

  detail.STRENGTH = addon:CpgDetailProperty(nil, detail)
  detail.STRENGTH.layoutIndex = 31
  detail.STRENGTH.text:SetText(L["CGP_STAT_STRENGTH"])
  detail.AGILITY = addon:CpgDetailProperty(nil, detail)
  detail.AGILITY.layoutIndex = 32
  detail.AGILITY.text:SetText(L["CGP_STAT_AGILITY"])
  detail.INTELLECT = addon:CpgDetailProperty(nil, detail)
  detail.INTELLECT.layoutIndex = 33
  detail.INTELLECT.text:SetText(L["CGP_STAT_INTELLECT"])

  detail.STAMINA = addon:CpgDetailProperty(nil, detail)
  detail.STAMINA.layoutIndex = 38
  detail.STAMINA.text:SetText(L["CGP_STAT_STAMINA"])

  detail.ARMOR = addon:CpgDetailProperty(nil, detail)
  detail.ARMOR.layoutIndex = 39
  detail.ARMOR.text:SetText(L["CGP_STAT_ARMOR"])

  -- Secondary Stat
  detail.secondaryStatsBar = addon:CpgDetailBar(nil, detail)
  detail.secondaryStatsBar.layoutIndex = 40
  detail.secondaryStatsBar.text:SetText(L["CGP_ENHANCEMENTS"])

  detail.CRITICAL_STRIKE = addon:CpgDetailProperty(nil, detail)
  detail.CRITICAL_STRIKE.layoutIndex = 41
  detail.CRITICAL_STRIKE.text:SetText(L["CGP_STAT_CRITICAL_STRIKE"])

  detail.HASTE = addon:CpgDetailProperty(nil, detail)
  detail.HASTE.layoutIndex = 42
  detail.HASTE.text:SetText(L["CGP_STAT_HASTE"])

  detail.MASTERY = addon:CpgDetailProperty(nil, detail)
  detail.MASTERY.layoutIndex = 43
  detail.MASTERY.text:SetText(L["CGP_STAT_MASTERY"])

  detail.VERSATILITY = addon:CpgDetailProperty(nil, detail)
  detail.VERSATILITY.layoutIndex = 44
  detail.VERSATILITY.text:SetText(L["CGP_STAT_VERSATILITY"])

  detail.LIFESTEAL = addon:CpgDetailProperty(nil, detail)
  detail.LIFESTEAL.layoutIndex = 45
  detail.LIFESTEAL.text:SetText(L["CGP_STAT_LIFESTEAL"])

  detail.SPEED = addon:CpgDetailProperty(nil, detail)
  detail.SPEED.layoutIndex = 46
  detail.SPEED.text:SetText(L["CGP_STAT_SPEED"])

  detail.AVOIDANCE = addon:CpgDetailProperty(nil, detail)
  detail.AVOIDANCE.layoutIndex = 47
  detail.AVOIDANCE.text:SetText(L["CGP_STAT_AVOIDANCE"])

  detail.spec = addon:CpgDetailBar(nil, detail)
  detail.spec.layoutIndex = 100

  detail:Layout()
  -- 将大格子挂载在你的索引结构里，方便以后调用它
  content.detail = detail
  -- ====================================================================
  -- 生成常规小格子，并跳过合并区域
  -- ====================================================================
  for colIdx = 1, 4 do
    local offsetX = (colIdx * spaceX) + ((colIdx - 1) * w)

    for rowIdx = 1, 8 do
      -- 如果是第2列 或 第3列，且行数在 1 到 7 之间，直接跳过不创建。
      if (colIdx == 2 or colIdx == 3) and (rowIdx >= 1 and rowIdx <= 7) then
        -- CONTINUE
      else
        -- 创建正常的独立小格子
        -- local slot = CreateFrame("Frame", nil, content, "BackdropTemplate")
        local slot = CreateFrame("Button", nil, content, "BackdropTemplate")
        slot:SetSize(w, h)

        local offsetY = (rowIdx * spaceY) + ((rowIdx - 1) * h)
        slot:SetPoint("TOPLEFT", content, "TOPLEFT", offsetX, -offsetY)

        slot.icon = slot:CreateTexture(nil, "BACKGROUND")
        slot.icon:SetAllPoints(slot)
        slot.icon:SetColorTexture(unpack(CT_THEME.CGP.SLOT.ICON.COLOR))

        slot.quality = slot:CreateTexture(nil, "OVERLAY")
        slot.quality:SetSize(unpack(CT_THEME.CGP.SLOT.QUALITY.SIZE))
        slot.quality:SetPoint("TOPLEFT", slot, "TOPLEFT", unpack(CT_THEME.CGP.SLOT.QUALITY.POINT))
        slot.quality:SetColorTexture(unpack(CT_THEME.CGP.SLOT.QUALITY.COLOR))

        slot.itemLevel = slot:CreateFontString(nil, "OVERLAY")
        slot.itemLevel:SetFontObject(self.GUI_FONTS[CT_THEME.CGP.SLOT.ITEM_LEVEL.FONT])
        slot.itemLevel:SetTextColor(unpack(CT_THEME.CGP.SLOT.ITEM_LEVEL.COLOR))
        slot.itemLevel:SetPoint(
          "BOTTOMRIGHT",
          slot,
          "BOTTOMRIGHT",
          -CT_THEME.CGP.SLOT.ITEM_LEVEL.PADDING,
          CT_THEME.CGP.SLOT.ITEM_LEVEL.PADDING
        )
        slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
        slot:SetScript("OnClick", function(self)
          if self.itemLink and IsShiftKeyDown() then
            local editBox = ChatEdit_GetActiveWindow()
            if editBox then editBox:Insert(self.itemLink) end
          end
        end)

        table.insert(content.slots, slot)
      end
    end
  end
end

function addon:ShowCgp(id)
  addon:CreateCgp()
  local character = CharactersTrackerDB.CHARACTERS[id]
  if not character or not character.name then return end

  self.CT_CGP:Hide()
  local detail = self.CT_CGP_DETAIL

  detail.name.text:SetText(FORMATTERS.NAME(character))
  detail.equippedLevel.text:SetText(FORMATTERS.ITEM_LEVEL_FLOOR(character))

  local stats = character.stats or { basic = {}, secondary = {} }
  local effected = 0
  for _, k in ipairs(BASIC_STATS_LAYOUT) do
    local stat = stats.basic[k]
    if "number" == type(stat) and stat > 0 then
      detail[k].value:SetText(stat)
      if bit.band(effected, 1) == 0 then
        detail[k].bg:SetColorTexture(unpack(CT_THEME.CGP.DETAIL.PROP.BG.EVEN))
      else
        detail[k].bg:SetColorTexture(unpack(CT_THEME.CGP.DETAIL.PROP.BG.ODD))
      end
      detail[k]:Show()
      effected = effected + 1
    else
      detail[k]:Hide()
    end
  end

  if effected > 0 then
    detail.basicStatBar:Show()
  else
    detail.basicStatBar:Hide()
  end

  effected = 0
  for _, k in ipairs(SECONDARY_STATS_LAYOUT) do
    local stat = stats.secondary[k]
    if "number" == type(stat) and stat > 0 then
      detail[k].value:SetText(string.format("%.2f%%", stat))
      if bit.band(effected, 1) == 0 then
        detail[k].bg:SetColorTexture(unpack(CT_THEME.CGP.DETAIL.PROP.BG.EVEN))
      else
        detail[k].bg:SetColorTexture(unpack(CT_THEME.CGP.DETAIL.PROP.BG.ODD))
      end
      detail[k]:Show()
      effected = effected + 1
    else
      detail[k]:Hide()
    end
  end

  if effected > 0 then
    detail.secondaryStatsBar:Show()
  else
    detail.secondaryStatsBar:Hide()
  end

  if stats.specialization then
    detail.spec.text:SetText(FORMATTERS.CLASS_COLOR(character, stats.specialization))
    detail.spec:Show()
  else
    detail.spec.text:SetText("")
    detail.spec:Hide()
  end

  detail:Layout()

  local content = self.CT_CGP_CONTENT
  for idx, _ in ipairs(content.slots) do
    local slotId = GEAR_SLOTS_MAPPING[idx]

    local slot = content.slots[idx]
    local gear = character.gear[slotId]

    if gear and gear.link then
      local texture = C_Item.GetItemIconByID(gear.link)
      slot.icon:SetTexture(texture or 134400)
      slot.itemLink = gear.link

      local quality = C_Item.GetItemQualityByID(gear.link)
      if quality and quality > 1 then
        local r, g, b = C_Item.GetItemQualityColor(quality)
        slot.quality:SetColorTexture(r, g, b, 1)
      else
        slot.quality:SetColorTexture(unpack(CT_THEME.CGP.SLOT.QUALITY.COLOR))
      end
      slot.quality:Show()
      slot.itemLevel:SetTextColor(unpack(CT_THEME.CGP.SLOT.ITEM_LEVEL.COLOR))
      slot.itemLevel:SetText(gear.level or "")

      slot:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.itemLink)
        GameTooltip:Show()
      end)
    else
      slot.icon:SetColorTexture(unpack(CT_THEME.CGP.SLOT.ICON.COLOR))
      slot.itemLink = nil
      slot.quality:SetColorTexture(unpack(CT_THEME.CGP.SLOT.QUALITY.COLOR))
      slot.quality:Hide()
      slot.itemLevel:SetTextColor(unpack(CT_THEME.CGP.SLOT.ITEM_LEVEL.COLOR))
      slot.itemLevel:SetText("")
      slot:SetScript("OnEnter", nil)
    end
  end
  self.CT_CGP:Show()
end

-- addon:X()
-- addon:InitWorkspace()
-- addon:ClpMain()
-- addon.CT_CLP:SetWidth(1000)
-- addon.CT_CLP_BANNER:SetWidth(1000)
-- addon.CT_CLP_FOOTER:SetWidth(1000)
