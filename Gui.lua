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

-- ITEM_QUALITY_COLORS[0].color
-- FACTION_BAR_COLORS
-- /dump print(FACTION_BAR_COLORS[1].color) -- issue
-- /dump print(ITEM_QUALITY_COLORS[0].color)

-- ITEM_QUALITY_COLORS[0].color ：垃圾灰（适合做离线很久、或者未激活的号）。
-- ITEM_QUALITY_COLORS[2].color ：优秀绿（适合做正常、安全的指标）。
-- ITEM_QUALITY_COLORS[3].color ：精良蓝（适合做高亮）。
-- ITEM_QUALITY_COLORS[4].color ：史诗紫（适合做满级、或者大米高分数的号）。
-- ITEM_QUALITY_COLORS[5].color ：传说橙（适合做最核心、最显眼的数据）。

-- /dump print(HORDE_COLOR)

local MAX_LEVEL_OF_CHARACTER = GetMaxLevelForPlayerExpansion()

local GEAR_SLOTS_LAYOUT = {
  [1] = { 1, 2, 3, 15, 5, 4, 19, 9 },   -- 第1列：头、颈、肩、背、胸、衬衣、战袍、腕
  [2] = { 16 },                         -- 第2列：主手
  [3] = { 17 },                         -- 第3列：副手
  [4] = { 10, 6, 7, 8, 11, 12, 13, 14 } -- 第4列：手、腰、腿、脚、指1、指2、饰1、饰2
}
local GEAR_SLOTS_MAPPING = { 1, 2, 3, 15, 5, 4, 19, 9, 16, 17, 10, 6, 7, 8, 11, 12, 13, 14 }

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
local S2TA = function(c, f)
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
  REALM = function(c)
    return c and c.realm or ""
  end,
  LEVEL = function(c)
    if c and c.level and c.level > 0 then
      if c.level < MAX_LEVEL_OF_CHARACTER then
        return c.level
      end
      return c.level
    end
    return ""
  end,
  FACTION = function(c)
    return c and c.faction or ""
  end,
  ZONE = function(c)
    return c and c.zone or ""
  end,
  ITEM_LEVEL_FLOOR = function(c)
    return c and math.floor(c.equippedLevel or 0)
  end,
  ITEM_LEVEL = function(c)
    return c and c.equippedLevel or 0
  end,
  VAULT = function(c)
  end,
  M_SCORE = function(c)
    return c and c.mScore or 0
  end,
  PLAYED = function(c)
    return string.format(SecondsToTimeAbbrev(c.levelPlayed or 0)) ..
        " / " .. string.format(SecondsToTimeAbbrev(c.played or 0))
  end,
  GOLD_FLOOR = function(c)
    return c and math.floor((c.gold or 0) / 10000)
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
        HEIGHT = 48,
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
        TEXT_COLOR = { 0.9, 0.9, 0.9 },
        VALUE_COLOR = { 0.9, 0.9, 0.9 },
        FONT = "TINY",
        PADDING = 4,
      },
    },
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
      { id = "GOLD",       label = L["CLP_LABEL_GOLD"],       formatter = FORMATTERS.GOLD_FLOOR,       fixed = false, align = "CENTER" },
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

function addon:Util_FrameMarginAll(child, parent, margin)
  child:SetPoint("TOPLEFT", parent, "TOPLEFT", margin, -margin)
  child:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -margin, margin)
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
            -- TODO
            cell.currencies:SetScript("OnClick", function()
              local dialog = StaticPopup_Show("CONFIRM_PURE_CHARACTER_DATA", character.name)
              if dialog then dialog.data = character end
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
  local clp = addon:CreateBaseWindow("CT_CHARACTERS_LIST_PANEL")
  self.CT_CLP = clp

  clp:SetHeight(CT_THEME.CLP.HEIGHT)
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

-- Base moveable window factory
function addon:CreateBaseWindow(name)
  local positions = CharactersTrackerDB.SETTINGS.POSITIONS
  local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")

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

function addon:CpgDetailBar(name, parent, title)
  local bar = CreateFrame("Frame", name, parent)
  bar:SetWidth(parent:GetWidth())
  bar:SetHeight(CT_THEME.CGP.DETAIL.BAR.HEIGHT)
  bar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)

  local bg = bar:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(unpack(CT_THEME.CGP.DETAIL.BAR.BG.COLOR))

  local line = bar:CreateTexture(nil, "OVERLAY")
  line:SetHeight(CT_THEME.CGP.DETAIL.BAR.LINE.HEIGHT)
  line:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
  line:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
  line:SetColorTexture(unpack(CT_THEME.CGP.DETAIL.BAR.LINE.COLOR))

  local t = bar:CreateFontString(nil, "OVERLAY")
  t:SetFontObject(self.GUI_FONTS[CT_THEME.CGP.DETAIL.BAR.TITLE.FONT])
  t:SetPoint("CENTER")
  t:SetTextColor(unpack(CT_THEME.CGP.DETAIL.BAR.TITLE.COLOR))
  t:SetText(title)

  return bar
end

function addon:CpgDetailProperty(name, parent, text, value, odd)
  local prop = CreateFrame("Frame", name, parent)
  prop:SetWidth(parent:GetWidth())
  prop:SetHeight(CT_THEME.CGP.DETAIL.PROP.HEIGHT)
  prop:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)

  prop.bg = prop:CreateTexture(nil, "BACKGROUND")
  prop.bg:SetAllPoints()
  if odd then
    prop.bg:SetColorTexture(unpack(CT_THEME.CGP.DETAIL.PROP.BG.ODD))
  else
    prop.bg:SetColorTexture(unpack(CT_THEME.CGP.DETAIL.PROP.BG.EVEN))
  end

  prop.t = prop:CreateFontString(nil, "OVERLAY")
  prop.t:SetFontObject(self.GUI_FONTS[CT_THEME.CGP.DETAIL.PROP.FONT])
  prop.t:SetPoint("LEFT", CT_THEME.CGP.DETAIL.PROP.PADDING, 0)
  prop.t:SetTextColor(unpack(CT_THEME.CGP.DETAIL.PROP.TEXT_COLOR))
  prop.t:SetText(text)

  prop.v = prop:CreateFontString(nil, "OVERLAY")
  prop.v:SetFontObject(self.GUI_FONTS[CT_THEME.CGP.DETAIL.PROP.FONT])
  prop.v:SetPoint("RIGHT", -CT_THEME.CGP.DETAIL.PROP.PADDING, 0)
  prop.v:SetTextColor(unpack(CT_THEME.CGP.DETAIL.PROP.VALUE_COLOR))
  prop.v:SetText(value)

  return prop
end

function addon:CgpMain()
  -- Make sure ONLY Create it once to avoid OOM
  if self.CT_CGP then
    self.CT_CGP:Show()
    -- self.CT_CGP_DETAIL.bg:Show()
    return
  end
  --
  local cgp = addon:CreateBaseWindow("CT_CHARACTER_GEAR_PANEL")
  self.CT_CGP = cgp

  cgp:SetSize(CT_THEME.CGP.WIDTH, CT_THEME.CGP.HEIGHT)

  local bg = cgp:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(unpack(CT_THEME.CGP.BG.COLOR))

  local banner = addon:Util_CreateBanner(
    "CT_CHARACTER_GEAR_PANEL_BANNER",
    self.CT_CGP,
    L["GEAR_DETAIL"],
    CT_THEME.CGP.BANNER
  )
  self.CT_CGP_BANNER = banner

  local content = CreateFrame("Frame", "CT_CHARACTER_GEAR_PANEL_CONTENT", self.CT_CGP, "BackdropTemplate")
  self.CT_CGP_CONTENT = content
  content:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 0, 0)
  content:SetPoint("BOTTOMRIGHT", self.CT_CGP, "BOTTOMRIGHT", 0, 0)

  -- local xbg = detail:CreateTexture(nil, "BACKGROUND")
  -- xbg:SetAllPoints()
  -- xbg:SetColorTexture(1, 1, 1)

  content.cells = {}
  local W = content:GetWidth()
  local H = content:GetHeight()
  local w = 48 -- 基础列宽
  local h = 48 -- 基础行高
  local spaceX = (W - (4 * w)) / 5
  local spaceY = (H - (8 * h)) / 9

  -- ====================================================================
  -- 🌟 核心步骤 1：单独创建中间合并的巨型大格子
  -- ====================================================================
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

  -- 给巨型大格子涂上一个显眼的醒目底色（比如深灰色）
  -- detail.bg = detail:CreateTexture(nil, "BACKGROUND")
  -- detail.bg:SetAllPoints()
  -- detail.bg:SetColorTexture(0.2, 0.2, 0.2, 0.9)
  detail.name = addon:CpgDetailHeadline(nil, detail)
  detail.name.layoutIndex = 0

  -- detail.name.name:SetText("名字长了怎么")
  detail.name.text:SetText("Zooooooooooo")

  -- name bar
  detail.nameBar = addon:CpgDetailBar(nil, detail, "物品等级")
  detail.nameBar.layoutIndex = 1

  detail.itemLv = addon:CpgDetailHeadline(nil, detail)
  detail.itemLv.layoutIndex = 2
  detail.itemLv.text:SetText("290")

  detail.propBar = addon:CpgDetailBar(nil, detail, "属性")
  detail.propBar.layoutIndex = 3

  detail.prop1 = addon:CpgDetailProperty(nil, detail, "力量", "102", true)
  detail.prop1.layoutIndex = 4
  detail.prop2 = addon:CpgDetailProperty(nil, detail, "耐力", "12202", false)
  detail.prop2.layoutIndex = 5
  detail.prop3 = addon:CpgDetailProperty(nil, detail, "护甲", "1202", true)
  detail.prop3.layoutIndex = 6

  detail.exPorpBar = addon:CpgDetailBar(nil, detail, "强化属性")
  detail.exPorpBar.layoutIndex = 7

  detail.prop11 = addon:CpgDetailProperty(nil, detail, "力量", "102", true)
  detail.prop11.layoutIndex = 8
  detail.prop21 = addon:CpgDetailProperty(nil, detail, "耐力", "12202", false)
  detail.prop21.layoutIndex = 9
  detail.prop31 = addon:CpgDetailProperty(nil, detail, "护甲", "1202", true)
  detail.prop31.layoutIndex = 10

  -- 1. 创建你的属性详情面板 (承载容器)
  -- local myInfoPanel = CreateFrame("Frame", "CT_InfoRowPanel", detail, "BackdropTemplate")
  -- myInfoPanel:SetSize(detailWidth - 20, detailHeight - 20) -- 比你的中间大格子稍微缩一点边距
  -- myInfoPanel:SetPoint("TOPLEFT", self.CT_CGP_DETAIL, "TOPLEFT", 10, -10)

  -- myInfoPanel.rows = {}

  -- 2. 动态添加“双端对齐文本行”的函数
  -- function myInfoPanel:AddDataRow(leftText, rightText)
  --   local idx = #self.rows + 1
  --   local rowHeight = 20 -- 每一行的高度
  --   local rowSpacing = 6 -- 行与行之间的间距

  --   -- 创建一行的透明外壳
  --   local row = CreateFrame("Frame", nil, self)
  --   row:SetHeight(rowHeight)

  --   -- 🟢 核心排版：横向把左右两端拉满贴住父容器，纵向实施链式锚定
  --   if idx == 1 then
  --     -- 第一行，死死贴住大父壳子的顶部
  --     row:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
  --     row:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)
  --   else
  --     -- 后续的行，哥哥贴弟弟，永远钉在上一行的屁股后面
  --     local previousRow = self.rows[idx - 1]
  --     row:SetPoint("TOPLEFT", previousRow, "BOTTOMLEFT", 0, -rowSpacing)
  --     row:SetPoint("TOPRIGHT", previousRow, "BOTTOMRIGHT", 0, -rowSpacing)
  --   end

  --   -- 3. 创建左侧文字（居左对齐）
  --   row.leftFS = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  --   row.leftFS:SetPoint("LEFT", row, "LEFT", 0, 0)
  --   row.leftFS:SetJustifyH("LEFT")
  --   row.leftFS:SetText(leftText)

  --   -- 4. 创建右侧文字（居右对齐）
  --   row.rightFS = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  --   row.rightFS:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  --   row.rightFS:SetJustifyH("RIGHT")
  --   row.rightFS:SetText(rightText)

  --   -- 存入数组，方便以后动态更新内容
  --   table.insert(self.rows, row)
  -- end

  -- bigCell.text = bigCell:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  -- bigCell.text:SetPoint("CENTER", bigCell, "CENTER", 0, 0)
  -- bigCell.text:SetText("中间合并大格子\n(装等成就展示区)")

  detail:Layout()
  -- 将大格子挂载在你的索引结构里，方便以后调用它
  content.detail = detail
  -- ====================================================================
  -- 🌟 核心步骤 2：生成常规小格子，并无情跳过合并区域
  -- ====================================================================
  for colIdx = 1, 4 do
    -- detail.cells[colIdx] = {}
    local offsetX = (colIdx * spaceX) + ((colIdx - 1) * w)

    for rowIdx = 1, 8 do
      -- 🔍 核心拦截：如果是第 2 或第 3 列，且行数在 1 到 7 之间，直接跳过不创建！
      if (colIdx == 2 or colIdx == 3) and (rowIdx >= 1 and rowIdx <= 7) then
        -- CONTINUE
      else
        -- 创建正常的独立小格子
        local cell = CreateFrame("Frame", nil, content, "BackdropTemplate")
        cell:SetSize(w, h)

        local offsetY = (rowIdx * spaceY) + ((rowIdx - 1) * h)
        cell:SetPoint("TOPLEFT", content, "TOPLEFT", offsetX, -offsetY)

        local cbg = cell:CreateTexture(nil, "BACKGROUND")
        cbg:SetAllPoints()
        cbg:SetColorTexture(1 / colIdx, 1 / rowIdx, 0.4, 0.8)

        cell.text = cell:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        cell.text:SetPoint("CENTER", cell, "CENTER", 0, 0)
        cell.text:SetText(string.format("%d,%d", colIdx, rowIdx))

        table.insert(content.cells, cell)
      end
    end
  end

  for idx, _ in ipairs(content.cells) do
    print(string.format("%d - %d", idx, GEAR_SLOTS_MAPPING[idx]))
  end
  pxxxx = addon:GetCharacterStats()
end

-- function addon:GetCharacterStats()
--   local statsList = {}

--   -- ====================================================================
--   -- 1. 修正版：基础核心属性（直接读取真实的当前总值）
--   -- ====================================================================
--   local primaryStats = {
--     { id = 3, name = SPEC_FRAME_STAMINA or "耐力" },
--     { id = 1, name = SPEC_FRAME_STRENGTH or "力量" },
--     { id = 2, name = SPEC_FRAME_AGILITY or "敏捷" },
--     { id = 4, name = SPEC_FRAME_INTELLECT or "智力" }
--   }

--   for _, stat in ipairs(primaryStats) do
--     -- 🟢 现代魔兽核心：第一个返回值 base 已经是包含大部分装备和被动计算后的当前实际总值了！
--     local currentTotal = UnitStat("player", stat.id)

--     if currentTotal and currentTotal > 0 then
--       -- 耐力永远显示；其余主属性只有在它属于当前职业（大于基础十几点）时才显示
--       if stat.id == 3 or currentTotal > 50 then
--         table.insert(statsList, { name = stat.name, value = tostring(currentTotal) })
--       end
--     end
--   end

--   -- ====================================================================
--   -- 2. 强化二次属性（Secondary Stats）
--   -- ====================================================================
--   local critChance = GetCritChance()
--   table.insert(statsList, { name = STAT_CRITICAL_STRIKE or "暴击", value = string.format("%.2f%%", critChance) })

--   local hastePercent = GetHaste()
--   table.insert(statsList, { name = STAT_HASTE or "急速", value = string.format("%.2f%%", hastePercent) })

--   local masteryEffect = GetMasteryEffect()
--   table.insert(statsList, { name = STAT_MASTERY or "精通", value = string.format("%.2f%%", masteryEffect) })

--   local versaDamageBonus = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE)
--   table.insert(statsList, { name = STAT_VERSATILITY or "全能", value = string.format("%.2f%%", versaDamageBonus) })

--   -- ====================================================================
--   -- 3. 辅助属性（第三绿字，这次移除了 > 0 的拦截限制，确保 0% 也能稳定显示）
--   -- ====================================================================
--   -- 🟢 吸血 (Leech)
--   -- local leechPercent = GetCombatRatingBonus(CR_LIFESTEAL)
--   -- table.insert(statsList, { name = STAT_LIFESTEAL or "吸血", value = string.format("%.2f%%", leechPercent or 0) })
--   -- 🟢 修正：使用全局 GetLeech() 抓取包含天赋、附魔、绿字在内的全额最终吸血
--   -- 🟢 终极修正：使用暴雪官方属性面板底层一致的 Rating 计算方法
--   local leechPercent = GetCombatRatingBonus(CR_LIFESTEAL) + (GetLifesteal and GetLifesteal() or 0)
--   table.insert(statsList, { name = STAT_LIFESTEAL or "吸血", value = string.format("%.2f%%", leechPercent) })

--   -- 🟢 加速 (Speed)
--   local speedPercent = GetCombatRatingBonus(CR_SPEED)
--   table.insert(statsList, { name = STAT_SPEED or "加速", value = string.format("%.2f%%", speedPercent or 0) })

--   -- 🟢 闪避 (Avoidance)
--   local avoidancePercent = GetCombatRatingBonus(CR_AVOIDANCE)
--   table.insert(statsList, { name = STAT_AVOIDANCE or "闪避", value = string.format("%.2f%%", avoidancePercent or 0) })

--   return statsList
-- end


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

function addon:ShowCharacterDetail(guid)
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

-- addon:X()
-- addon:InitWorkspace()
-- addon:ClpMain()
-- addon.CT_CLP:SetWidth(1000)
-- addon.CT_CLP_BANNER:SetWidth(1000)
-- addon.CT_CLP_FOOTER:SetWidth(1000)
