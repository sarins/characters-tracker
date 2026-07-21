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

local CT_CLP_FRAME_LEVEL = 120

local CT_INVENTORY_PANEL_LEVEL = 110

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

local TRACKED_CURRENCIES_CACHE = {}

local COLORS = {
  DARK_GOLD = "E6CC80",
  GOLD = "ffd100",
  WHITE = "ffffff",
  PROGRESS = {
    DONE = "22C55E",
    UNLOCKED = "EAB308",
    LOCKED = "FFFFFF",
  },
  TIPS = {
    ERROR = "FF2020",
    WARN = "FF8000",
    SUCCESS = "1EFF00",
    INFO = "0070DD",
  },
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

local function LIMIT_COLORFUL(c, l)
  if "number" == type(c) and "number" == type(l) then
    local count = math.abs(c)
    local limit = math.abs(l)
    local p = count / limit
    if p > 0.9 then
      return string.format("|cff%s%s|r", COLORS.TIPS.ERROR, count)
    elseif p > 0.75 then
      return string.format("|cff%s%s|r", COLORS.TIPS.WARN, count)
    elseif p > 0.5 then
      return string.format("|cff%s%s|r", COLORS.TIPS.SUCCESS, count)
    else
      return string.format("|cff%s%s|r", COLORS.WHITE, count)
    end
  end
  return ""
end

local function VAULTS_PROGRESS(c, t)
  if c and t and "table" == type(c.vaults) and "table" == type(c.vaults.rewards) then
    local progress = c.vaults.rewards[t] or 0
    local target = 3
    if progress < 1 then
      return string.format("|cff%s%s / %s|r", COLORS.PROGRESS.LOCKED, math.abs(progress), target)
    elseif progress > 2 then
      return string.format("|cff%s%s / %s|r", COLORS.PROGRESS.DONE, progress, target)
    else
      return string.format("|cff%s%s / %s|r", COLORS.PROGRESS.UNLOCKED, progress, target)
    end
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
    if c and c.realm then
      return string.format("|cffffd100%s|r", c.realm)
    end
    return ""
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
  RV = function(c)
    return VAULTS_PROGRESS(c, 3)
  end,
  DV = function(c)
    return VAULTS_PROGRESS(c, 1)
  end,
  WV = function(c)
    return VAULTS_PROGRESS(c, 6)
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
  PVP = function(c)
    return ""
  end,
  UPDATED2TA = function(c)
    return S2TA(c, "updated")
  end,
}

local CT_THEME = {
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
  FB = {
    SIZE = { 36, 36 },
    ICON = {
      TEXTURE = "Interface\\AddOns\\CharactersTracker\\media\\icon.tga",
      SIZE = { 32, 32 },
    },
  },
  CLP = {
    HEIGHT             = 400,
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
        TEXTURE_ACTIVE = "Interface\\AddOns\\CharactersTracker\\media\\characters-active.tga",
        SIZE = { 16, 16 },
        POINT = { -136, 0 }
      },
      CURRENCIES = {
        TEXTURE = "Interface\\AddOns\\CharactersTracker\\media\\detail.tga",
        TEXTURE_ACTIVE = "Interface\\AddOns\\CharactersTracker\\media\\detail-active.tga",
        SIZE = { 16, 16 },
        POINT = { -112, 0 }
      },
      SETTINGS = {
        TEXTURE = "Interface\\AddOns\\CharactersTracker\\media\\gear.tga",
        TEXTURE_ACTIVE = "Interface\\AddOns\\CharactersTracker\\media\\gear-active.tga",
        SIZE = { 16, 16 },
        POINT = { -88, 0 }
      },
      LOCKER = {
        TEXTURE = "Interface\\AddOns\\CharactersTracker\\media\\lock.tga",
        TEXTURE_ACTIVE = "Interface\\AddOns\\CharactersTracker\\media\\lock-active.tga",
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
        DRAG = {
          TEXTURE = "Interface\\AddOns\\CharactersTracker\\media\\drag.tga",
          SIZE = { 16, 16 },
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
          CHECKED_COLOR   = { 0.20, 0.75, 0.40, 1.00 }, -- 已勾选绿 #33BF66
          UNCHECKED_COLOR = { 0.25, 0.25, 0.25, 1.00 }, -- 未勾选灰
        },
        ICON    = {
          SIZE = { 14, 14 },
          SPACING = 2,
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
        -- COLOR = { 0.90, 0.80, 0.50 },
        COLOR = { 1, 1, 1 },
      }
    }
  },
  INVENTORY_PANEL = {
    WIDTH  = 640,
    HEIGHT = 560,
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
  },
}

local META = {
  CLP = {
    COLS = {
      { id = "VISIBLE",    label = L["CLP_LABEL_VISIBLE"],    formatter = "",                          fixed = true,  align = "CENTER", width = 80 },
      { id = "DRAG",       label = L["CLP_LABEL_DRAG"],       formatter = "",                          fixed = true,  align = "CENTER", width = 64 },
      { id = "NAME",       label = L["CLP_LABEL_NAME"],       formatter = FORMATTERS.NAME,             fixed = true,  align = "LEFT",   padding = 16 },
      { id = "CLASS",      label = L["CLP_LABEL_CLASS"],      formatter = FORMATTERS.CLASS,            fixed = false, align = "CENTER" },
      { id = "REALM",      label = L["CLP_LABEL_REALM"],      formatter = FORMATTERS.REALM,            fixed = false, align = "CENTER" },
      { id = "LEVEL",      label = L["CLP_LABEL_LEVEL"],      formatter = FORMATTERS.LEVEL,            fixed = false, align = "CENTER" },
      { id = "FACTION",    label = L["CLP_LABEL_FACTION"],    formatter = FORMATTERS.FACTION,          fixed = false, align = "CENTER" },
      { id = "ZONE",       label = L["CLP_LABEL_ZONE"],       formatter = FORMATTERS.ZONE,             fixed = false, align = "CENTER" },
      { id = "ITEM_LEVEL", label = L["CLP_LABEL_ITEM_LEVEL"], formatter = FORMATTERS.ITEM_LEVEL_FLOOR, fixed = false, align = "CENTER" },
      { id = "RV",         label = L["CLP_LABEL_RV"],         formatter = FORMATTERS.RV,               fixed = false, align = "CENTER" },
      { id = "DV",         label = L["CLP_LABEL_DV"],         formatter = FORMATTERS.DV,               fixed = false, align = "CENTER" },
      { id = "WV",         label = L["CLP_LABEL_WV"],         formatter = FORMATTERS.WV,               fixed = false, align = "CENTER" },
      { id = "M_SCORE",    label = L["CLP_LABEL_M_SCORE"],    formatter = FORMATTERS.M_SCORE,          fixed = false, align = "CENTER" },
      { id = "PLAYED",     label = L["CLP_LABEL_PLAYED"],     formatter = FORMATTERS.PLAYED,           fixed = false, align = "CENTER" },
      { id = "GOLD",       label = L["CLP_LABEL_GOLD"],       formatter = FORMATTERS.GOLD_FLOOR,       fixed = false, align = "RIGHT",  padding = -16 },
      { id = "CURRENCIES", label = L["CLP_LABEL_CURRENCIES"], formatter = "",                          fixed = false, align = "CENTER", width = 64 },
      { id = "PVP",        label = L["CLP_LABEL_PVP"],        formatter = FORMATTERS.PVP,              fixed = false, align = "CENTER" },
      { id = "UPDATED",    label = L["CLP_LABEL_UPDATED"],    formatter = FORMATTERS.UPDATED2TA,       fixed = false, align = "CENTER" },
      { id = "OPERATION",  label = L["CLP_LABEL_OPERATION"],  formatter = "",                          fixed = true,  align = "CENTER", width = 64 },
    },
  },
}

addon.TRACKED_CURRENCIES = {
  -- Midnight
  3319, -- Twilight's Blade Insignia
  3316, -- Voidlight Marl
  3376, -- Shard of Dundun
  3377, -- Unalloyed Abundance
  3379, -- Brimming Arcana
  3385, -- Luminous Dust
  3392, -- Remnant of Anguish
  3400, -- Uncontaminated Void Sample
  3373, -- Angler Pearls
  3393, -- Illusionary Coin
  3405, -- Field Accolade
  3256, -- Artisan Alchemist's Moxie
  3257, -- Artisan Blacksmith's Moxie
  3258, -- Artisan Enchanter's Moxie
  3259, -- Artisan Engineer's Moxie
  3260, -- Artisan Herbalist's Moxie
  3261, -- Artisan Scribe's Moxie
  3262, -- Artisan Jewelcrafter's Moxie
  3263, -- Artisan Leatherworker's Moxie
  3264, -- Artisan Miner's Moxie
  3265, -- Artisan Skinner's Moxie
  3266, -- Artisan Tailor's Moxie
  3028, -- Restored Coffer Key
  3310, -- Coffer Key Shards
  3212, -- Radiant Spark Dust
  3378, -- Dawnlight Manaflux
  3383, -- Adventurer Dawncrest
  3341, -- Veteran Dawncrest
  3343, -- Champion Dawncrest
  3345, -- Hero Dawncrest
  3347, -- Myth Dawncrest
  3418, -- Nebulous Voidcore
  --- below are PvP currencies
  1792, -- 荣誉点数
  1602, -- 征服点数
}

-- stage 1 init, not sure for player has load
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

-- stage 2 init, the player has been entering into the world.
function addon:InitEnteringWorld()
  -- Cache the currencies name and icon for the dropdown menu
  for _, currencyID in ipairs(addon.TRACKED_CURRENCIES) do
    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    if info then
      TRACKED_CURRENCIES_CACHE[currencyID] = {
        name = info.name,
        icon = info.iconFileID,
      }
    end
  end
end

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
-- function addon:HideAllMenus()
--   if self.L1Menu then self.L1Menu:Hide() end
--   if self.L2Menu then self.L2Menu:Hide() end
--   -- self:CancelMenuDimissTimer()
-- end

function addon:PureCharacterData(character)
  -- TODO delete
  print(character.name ..
    " has been data deleted. [For 2.0.0 version, there will not delete character data, because data structuration issue, this functionality will release in following versions.]")
  addon:ClpRefreshGrid()
end

-- 智能缓冲器：当鼠标离开菜单群落后，提供 0.2 秒的缓冲期防止滑出误触闭合
function addon:StartMenuDismissTimer(button)
  local k = button:GetName()
  if not self.CT_CLP_STATUS.dismissers[k] then
    self.CT_CLP_STATUS.dismissers[k] = CreateFrame("Frame")
  end

  local dissmisser = self.CT_CLP_STATUS.dismissers[k]
  local elapsed = 0
  dissmisser:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed >= 0.2 then
      if button then
        button.icon:SetTexture(button.iconTexture)
        button.menu:Hide()
      end
      dissmisser:SetScript("OnUpdate", nil)
    end
  end)
end

function addon:CancelMenuDimissTimer(button)
  local k = button:GetName()
  if self.CT_CLP_STATUS.dismissers[k] then
    self.CT_CLP_STATUS.dismissers[k]:SetScript("OnUpdate", nil)
  end
end

-- Unsafe, for ShowSettingsMenu use only
function addon:CreateDropdownMenu(name, parent, frameLevel)
  local menu = CreateFrame("Frame", name, parent, "VerticalLayoutFrame")
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

  return menu
end

function addon:ShowSettingsMenu(anchor)
  local font = self.GUI_FONTS["SMALL_BOLD"]
  local hiddenColumns = CharactersTrackerDB.SETTINGS.CLP.HIDDEN_COLUMNS
  local settingsItems = self.CT_CLP_STATUS.settingsItems

  if not self.CT_CLP_SEETINGS_MENU then
    self.CT_CLP_SEETINGS_MENU = addon:CreateDropdownMenu("CT_CHARACTERS_LIST_PANEL_SETTINGS_MENU", self.CT_CLP, 110)
    anchor.menu = self.CT_CLP_SEETINGS_MENU
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
      addon:CancelMenuDimissTimer(anchor)
      this.hl:Show()
    end)
    settingsItem:SetScript("OnLeave", function(this)
      this.hl:Hide()
      addon:StartMenuDismissTimer(anchor)
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

function addon:ShowCurrenciesMenu(anchor)
  local font = self.GUI_FONTS["SMALL_BOLD"]
  local hiddenCurrencies = CharactersTrackerDB.SETTINGS.CLP.HIDDEN_CURRENCIES
  local currenciesItems = self.CT_CLP_STATUS.currenciesItems

  if not self.CT_CLP_CURRENCIES_MENU then
    self.CT_CLP_CURRENCIES_MENU = addon:CreateDropdownMenu("CT_CHARACTERS_LIST_PANEL_CURRENCIES_MENU", self.CT_CLP, 110)
    anchor.menu = self.CT_CLP_CURRENCIES_MENU
  end

  self.CT_CLP_CURRENCIES_MENU:ClearAllPoints()
  self.CT_CLP_CURRENCIES_MENU:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", CT_THEME.CLP.BANNER.CURRENCIES.POINT[1], -4)

  for _, item in ipairs(currenciesItems) do item:Hide() end

  for i, currencyId in ipairs(addon.TRACKED_CURRENCIES) do
    local currenciesItem = currenciesItems[i]
    if not currenciesItem then
      currenciesItem = CreateFrame("Button", nil, self.CT_CLP_CURRENCIES_MENU)
      currenciesItem:SetHeight(CT_THEME.CLP.MENU.ITEM.HEIGHT)

      local cb = currenciesItem:CreateTexture(nil, "ARTWORK")
      cb:SetSize(unpack(CT_THEME.CLP.MENU.ITEM.CHECKER.SIZE))
      cb:SetPoint("LEFT", currenciesItem, "LEFT", CT_THEME.CLP.MENU.ITEM.SPACING, 0)
      currenciesItem.cb = cb

      local icon = currenciesItem:CreateTexture(nil, "OVERLAY")
      icon:SetSize(unpack(CT_THEME.CLP.MENU.ITEM.ICON.SIZE))
      icon:SetPoint("LEFT", cb, "RIGHT", CT_THEME.CLP.MENU.ITEM.SPACING, 0)
      currenciesItem.icon = icon

      local text = currenciesItem:CreateFontString(nil, "OVERLAY")
      text:SetFontObject(font)
      text:SetPoint("LEFT", icon, "RIGHT", CT_THEME.CLP.MENU.ITEM.ICON.SPACING, 0)
      currenciesItem.text = text

      local hl = currenciesItem:CreateTexture(nil, "BACKGROUND")
      hl:SetAllPoints()
      hl:SetColorTexture(unpack(CT_THEME.CLP.MENU.ITEM.HL.COLOR))
      hl:Hide()
      currenciesItem.hl = hl

      currenciesItems[i] = currenciesItem
    end

    currenciesItem.layoutIndex = i
    currenciesItem:SetWidth(self.CT_CLP_CURRENCIES_MENU:GetWidth())
    currenciesItem.icon:SetTexture(TRACKED_CURRENCIES_CACHE[currencyId].icon)
    currenciesItem.text:SetText(TRACKED_CURRENCIES_CACHE[currencyId].name)

    if hiddenCurrencies[currencyId] then
      currenciesItem.cb:SetColorTexture(unpack(CT_THEME.CLP.MENU.ITEM.CHECKER.UNCHECKED_COLOR))
      currenciesItem.text:SetTextColor(unpack(CT_THEME.CLP.MENU.ITEM.TEXT.UNCHECKED_COLOR))
    else
      currenciesItem.cb:SetColorTexture(unpack(CT_THEME.CLP.MENU.ITEM.CHECKER.CHECKED_COLOR))
      currenciesItem.text:SetTextColor(unpack(CT_THEME.CLP.MENU.ITEM.TEXT.CHECKED_COLOR))
    end

    currenciesItem:SetScript("OnEnter", function(this)
      addon:CancelMenuDimissTimer(anchor)
      this.hl:Show()
    end)
    currenciesItem:SetScript("OnLeave", function(this)
      this.hl:Hide()
      addon:StartMenuDismissTimer(anchor)
    end)

    currenciesItem:SetScript("OnClick", function()
      hiddenCurrencies[currencyId] = not hiddenCurrencies[currencyId] or nil
      addon:ClpRefreshGrid()
      addon:ShowCurrenciesMenu(anchor)
    end)

    currenciesItem:Show()
  end
  self.CT_CLP_CURRENCIES_MENU:Layout()
  self.CT_CLP_CURRENCIES_MENU:Show()
end

function addon:Util_CreateButton(name, parent, texture, width, height)
  local btn = CreateFrame("Button", name, parent)
  btn:SetSize(width, height)
  btn.icon = btn:CreateTexture(nil, "ARTWORK")
  btn.icon:SetPoint("CENTER")
  btn.icon:SetSize(width, height)
  btn.icon:SetTexture(texture)
  return btn
end

function addon:Util_CreateActiveButton(name, parent, texture, textureActive, width, height)
  local btn = CreateFrame("Button", name, parent)
  btn:SetSize(width, height)
  btn.icon = btn:CreateTexture(nil, "ARTWORK")
  btn.icon:SetPoint("CENTER")
  btn.icon:SetSize(width, height)
  btn.icon:SetTexture(texture)
  btn.iconTexture = texture
  btn.iconTextureActive = textureActive
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
    if (meta.id == "VISIBLE" or meta.id == "DRAG") and not self.CT_CLP_STATUS.choosable then
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
            w = math.max(tw + ((meta.padding and math.abs(meta.padding)) or 0), w)
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
    "CT_CHARACTERS_LIST_PANEL_BANNER_CLOSE",
    banner,
    CT_THEME.CLP.BANNER.CLOSE.TEXTURE,
    unpack(CT_THEME.CLP.BANNER.CLOSE.SIZE)
  )
  close:SetPoint("RIGHT", banner, "RIGHT", unpack(CT_THEME.CLP.BANNER.CLOSE.POINT))
  close:SetScript("OnClick", function()
    self.CT_CLP:Hide()
  end)

  local choice = addon:Util_CreateActiveButton(
    "CT_CHARACTERS_LIST_PANEL_BANNER_CHOICE",
    banner,
    CT_THEME.CLP.BANNER.CHOICE.TEXTURE,
    CT_THEME.CLP.BANNER.CHOICE.TEXTURE_ACTIVE,
    unpack(CT_THEME.CLP.BANNER.CHOICE.SIZE)
  )
  choice:SetPoint("RIGHT", banner, "RIGHT", unpack(CT_THEME.CLP.BANNER.CHOICE.POINT))
  choice:SetScript("OnClick", function()
    addon.CT_CLP_STATUS.choosable = not addon.CT_CLP_STATUS.choosable
    if addon.CT_CLP_STATUS.choosable then
      choice.icon:SetTexture(choice.iconTextureActive)
    else
      choice.icon:SetTexture(choice.iconTexture)
    end
    addon:ClpRefreshGrid()
  end)

  local currencies = addon:Util_CreateActiveButton(
    "CT_CHARACTERS_LIST_PANEL_BANNER_CURRENCIES",
    banner,
    CT_THEME.CLP.BANNER.CURRENCIES.TEXTURE,
    CT_THEME.CLP.BANNER.CURRENCIES.TEXTURE_ACTIVE,
    unpack(CT_THEME.CLP.BANNER.CURRENCIES.SIZE)
  )
  currencies:SetPoint("RIGHT", banner, "RIGHT", unpack(CT_THEME.CLP.BANNER.CURRENCIES.POINT))
  -- menu at here
  currencies:SetScript("OnEnter", function()
    addon:CancelMenuDimissTimer(currencies)
    addon:ShowCurrenciesMenu(currencies)
    currencies.icon:SetTexture(currencies.iconTextureActive)
  end)
  currencies:SetScript("OnLeave", function()
    addon:StartMenuDismissTimer(currencies)
  end)

  local settings = addon:Util_CreateActiveButton(
    "CT_CHARACTERS_LIST_PANEL_BANNER_SETTINGS",
    banner,
    CT_THEME.CLP.BANNER.SETTINGS.TEXTURE,
    CT_THEME.CLP.BANNER.SETTINGS.TEXTURE_ACTIVE,
    unpack(CT_THEME.CLP.BANNER.SETTINGS.SIZE)
  )
  settings:SetPoint("RIGHT", banner, "RIGHT", unpack(CT_THEME.CLP.BANNER.SETTINGS.POINT))
  -- Mouse action setup for settings button
  settings:SetScript("OnEnter", function()
    addon:CancelMenuDimissTimer(settings)
    addon:ShowSettingsMenu(settings)
    settings.icon:SetTexture(settings.iconTextureActive)
  end)
  settings:SetScript("OnLeave", function()
    addon:StartMenuDismissTimer(settings)
  end)

  local locker = addon:Util_CreateActiveButton(
    "CT_CHARACTERS_LIST_PANEL_BANNER_LOCKER",
    banner,
    CT_THEME.CLP.BANNER.LOCKER.TEXTURE,
    CT_THEME.CLP.BANNER.LOCKER.TEXTURE_ACTIVE,
    unpack(CT_THEME.CLP.BANNER.LOCKER.SIZE)
  )
  locker:SetPoint("RIGHT", banner, "RIGHT", unpack(CT_THEME.CLP.BANNER.LOCKER.POINT))
  locker:SetScript("OnClick", function()
    addon.CT_CLP_STATUS.operationable = not addon.CT_CLP_STATUS.operationable
    if addon.CT_CLP_STATUS.operationable then
      locker.icon:SetTexture(locker.iconTextureActive)
    else
      locker.icon:SetTexture(locker.iconTexture)
    end
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

function addon:ClpOnRowDropped(sourceRow)
  local rows = self.CT_CLP_STATUS.rows
  local orderKeeper = CharactersTrackerDB.SETTINGS.CHARACTERS_ORDER

  local _, mouseY = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  mouseY = mouseY / scale
  local targetRow = nil
  local isBefore = false

  for _, row in pairs(rows) do
    if row ~= sourceRow and row:IsVisible() then
      local _, yAxisOfRow, _, rowHeight = row:GetRect()
      if yAxisOfRow then
        if mouseY >= yAxisOfRow and mouseY <= (yAxisOfRow + rowHeight) then
          targetRow = row
          local centerY = yAxisOfRow + (rowHeight / 2)
          if mouseY > centerY then
            isBefore = true  -- 偏上，插到它前面
          else
            isBefore = false -- 偏下，插到它后面
          end
          break
        end
      end
    end
  end

  if targetRow then
    local sourceIdx = tIndexOf(orderKeeper, sourceRow.characterId)
    local targetIdx = tIndexOf(orderKeeper, targetRow.characterId)

    if sourceIdx and targetIdx then
      local characterId = table.remove(orderKeeper, sourceIdx)
      local newIdx = targetIdx
      if isBefore then
        newIdx = targetIdx - 1
      else
        newIdx = targetIdx + 1
      end

      if newIdx < 1 then newIdx = 1 end
      if newIdx > #orderKeeper + 1 then newIdx = #orderKeeper + 1 end

      table.insert(orderKeeper, newIdx, characterId)
    end
    addon:ClpRefreshGrid()
  end
end

function addon:ClpRefreshGrid()
  local xw = self:ClpDynamicWidths()
  addon:ClpRefreshGridHeader()

  local widths = self.CT_CLP_STATUS.widths
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
        row.characterId = _rid
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
          elseif "DRAG" == meta.id then
            if not cell then
              cell = CreateFrame("Frame", nil, row, "BackdropTemplate")
              cells[meta.id] = cell
              cell.drag = addon:Util_CreateButton(
                nil,
                cell,
                CT_THEME.CLP.GRID.CELL.DRAG.TEXTURE,
                unpack(CT_THEME.CLP.GRID.CELL.DRAG.SIZE)
              )
              cell.drag:RegisterForDrag("LeftButton")
            end
            cell:SetSize(widths[meta.id], CT_THEME.CLP.GRID.ROW.HEIGHT)
            cell.drag:SetPoint("CENTER")
            cell.drag:SetScript("OnDragStart", function(_self)
              local shadowRow = self.CT_CLP_DRAG_SHADOW_ROW
              shadowRow:SetWidth(widths[meta.id] + widths["NAME"])
              shadowRow.text:SetText(FORMATTERS.NAME(character))
              shadowRow:Show()
              row:SetAlpha(0.15)
              self.CT_CLP_STATUS.isDragging = true
            end)
            cell.drag:SetScript("OnDragStop", function(_self)
              local shadowRow = self.CT_CLP_DRAG_SHADOW_ROW
              shadowRow:Hide()
              row:SetAlpha(1.0)
              if addon.CT_CLP_STATUS.isDragging then
                self.CT_CLP_STATUS.isDragging = false
                addon:ClpOnRowDropped(row)
              end
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
            cell.currencies:SetScript("OnEnter", function(_self)
              addon:ShowCurrenciesTooltip(_self, character)
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
            -- cell.text:SetPoint(meta.align)
            cell.text:SetPoint(meta.align, cell, meta.align, (meta.padding or 0), 0)
            cell.text:SetFontObject(font)
            if "function" == type(meta.formatter) then
              cell.text:SetText(meta.formatter(character))
            else
              -- do nothing
              cell.text:SetText("")
            end
            if "NAME" == meta.id then
              cell:EnableMouse(true)
              cell:SetScript("OnMouseDown", function(_self, button)
                if button == "LeftButton" then
                  addon:ShowCgp(_rid)
                end
              end)
            end
            if "RV" == meta.id or "DV" == meta.id or "WV" == meta.id then
              cell:EnableMouse(true)
              cell:SetScript("OnEnter", function(_self)
                if "RV" == meta.id then
                  addon:ShowVaultsTooltip(_self, character, 3, meta.label)
                elseif "DV" == meta.id then
                  addon:ShowVaultsTooltip(_self, character, 1, meta.label)
                else
                  addon:ShowVaultsTooltip(_self, character, 6, meta.label)
                end
              end)
              cell:SetScript("OnLeave", function()
                GameTooltip:Hide()
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
    dismissers = {},
    isDragging = false,
  }

  local clp = addon:Util_CreateBaseWindow("CT_CHARACTERS_LIST_PANEL", UIParent)
  self.CT_CLP = clp

  clp:SetHeight(CT_THEME.CLP.HEIGHT)
  clp:SetFrameStrata("MEDIUM")
  clp:SetFrameLevel(CT_CLP_FRAME_LEVEL)
  -- clp:SetScript("OnHide", function()
  --   addon:HideAllMenus()
  -- end)

  local bg = clp:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(unpack(CT_THEME.CLP.BG.COLOR))

  -- dragable shadow row begin
  local shadowRow = CreateFrame("Frame", "CT_CHARACTERS_LIST_PANEL_DRAG_SHADOW_ROW", UIParent, "BackdropTemplate")
  self.CT_CLP_DRAG_SHADOW_ROW = shadowRow
  shadowRow:SetFrameStrata("TOOLTIP")
  shadowRow:SetHeight(CT_THEME.CLP.GRID.ROW.HEIGHT)
  shadowRow:Hide()

  shadowRow.bg = shadowRow:CreateTexture(nil, "BACKGROUND")
  shadowRow.bg:SetAllPoints()
  shadowRow.bg:SetColorTexture(unpack(CT_THEME.CLP.BG.COLOR))

  shadowRow.drag = addon:Util_CreateButton(
    nil,
    shadowRow,
    CT_THEME.CLP.GRID.CELL.DRAG.TEXTURE,
    unpack(CT_THEME.CLP.GRID.CELL.DRAG.SIZE)
  )
  shadowRow.drag:SetPoint("LEFT", shadowRow, "LEFT", 16, 0)
  shadowRow.text = shadowRow:CreateFontString(nil, "OVERLAY")
  shadowRow.text:SetFontObject(self.GUI_FONTS["SMALL"])
  shadowRow.text:SetPoint("LEFT", shadowRow, "LEFT", 64, 0)

  shadowRow:SetScript("OnUpdate", function(_self)
    local mouseX, mouseY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    _self:ClearAllPoints()
    _self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", mouseX / scale, mouseY / scale)
  end)
  -- dragable shadow row end

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

  local hiddenCurrencies = CharactersTrackerDB.SETTINGS.CLP.HIDDEN_CURRENCIES

  GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
  GameTooltip:ClearLines()

  GameTooltip:AddLine(FORMATTERS.NAME(character))
  GameTooltip:AddLine(" ")

  if character.currencies and next(character.currencies) then
    local hasAnyOutput = false
    for _, currencyId in ipairs(addon.TRACKED_CURRENCIES) do
      local currency = character.currencies[currencyId]
      if not hiddenCurrencies[currencyId] and currency then
        hasAnyOutput = true
        local icon = string.format("|T%d:14:14:0:0|t", currency.icon)
        local leftColumn = string.format("%s  %s", icon, currency.name)
        local qty = string.format("|cff%s%d|r", COLORS.GOLD, currency.quantity)
        local limit = ""
        if currency.maxWeeklyQuantity and currency.maxWeeklyQuantity > 0 then
          limit = string.format(
            L["CURR_WEEKLY_LIMIT"],
            LIMIT_COLORFUL(currency.quantityEarnedThisWeek, currency.maxWeeklyQuantity),
            currency.maxWeeklyQuantity
          )
        end
        if currency.maxQuantity and currency.maxQuantity > 0 then
          if currency.totalEarned and currency.totalEarned > 0 then
            limit = string.format(
              L["CURR_SEASON_LIMIT"],
              LIMIT_COLORFUL(currency.totalEarned, currency.maxQuantity),
              currency.maxQuantity
            )
          else
            limit = string.format(
              L["CURR_LIMIT"],
              LIMIT_COLORFUL(currency.quantity, currency.maxQuantity),
              currency.maxQuantity
            )
          end
        end
        local rightColumn = qty .. limit
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
-- Vaults Tooltip
-- ==========================================
function addon:ShowVaultsTooltip(anchor, character, t, label)
  if not anchor or not character or not character.vaults then return end

  GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
  GameTooltip:ClearLines()

  GameTooltip:AddLine(FORMATTERS.NAME(character))
  GameTooltip:AddLine(label)

  local activities = character.vaults.activities and character.vaults.activities[t] or {}
  local difficulties = character.vaults.difficulties and character.vaults.difficulties[t] or {}
  local rewardItemLevels = character.vaults.rewardItemLevels and character.vaults.rewardItemLevels[t] or {}

  for idx, slot in ipairs(activities) do
    if "table" == type(slot) then
      if slot.progress >= slot.threshold then
        local difficulty = difficulties[idx]
        local rewardItemLevel = rewardItemLevels[idx]
        local name = ""
        if difficulty and difficulty.name then
          if difficulty.isChallengeMode or difficulty.displayMythic then
            name = string.format("%s%s|r", ITEM_QUALITY_COLORS[4].hex, difficulty.name)
          elseif difficulty.isHeroic or difficulty.displayHeroic then
            name = string.format("%s%s|r", ITEM_QUALITY_COLORS[3].hex, difficulty.name)
          else
            name = difficulty.name
          end
        end
        local level = ""
        if slot.level > 0 then
          level = string.format(L["VT_LEVEL"], slot.level)
        end
        local itemLevel = ""
        if rewardItemLevel and rewardItemLevel > 0 then
          itemLevel = string.format("|cff%s%s|r", COLORS.GOLD, rewardItemLevel)
        end
        local left = strtrim(string.format("%s %s %s", name, level, itemLevel))
        local right = string.format("|cff%s(%s/%s)|r", COLORS.PROGRESS.DONE, slot.threshold, slot.threshold)
        GameTooltip:AddDoubleLine(left, right, 1, 1, 1, 1, 1, 1)
      elseif slot.progress < 1 then
        local right = string.format("(%d/%d)", math.abs(slot.progress), slot.threshold)
        GameTooltip:AddDoubleLine(L["VT_LOCKED"], right, 1, 1, 1, 1, 1, 1)
      else
        local right = string.format("|cff%s(%s/%s)|r", COLORS.PROGRESS.UNLOCKED, slot.progress, slot.threshold)
        GameTooltip:AddDoubleLine(L["VT_LOCKED"], right, 1, 1, 1, 1, 1, 1)
      end
    end
  end
  GameTooltip:Show()
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
      slot.icon:SetTexture(gear.icon)
      slot.itemLink = gear.link

      if gear.quality and gear.color then
        slot.quality:SetColorTexture(unpack(gear.color))
        slot.quality:Show()
      else
        slot.quality:SetColorTexture(unpack(CT_THEME.CGP.SLOT.QUALITY.COLOR))
        slot.quality:Hide()
      end

      if gear.level and gear.level > 0 then
        slot.itemLevel:SetTextColor(unpack(CT_THEME.CGP.SLOT.ITEM_LEVEL.COLOR))
        slot.itemLevel:SetText(gear.level or "")
        slot.itemLevel:Show()
      else
        slot.itemLevel:Hide()
      end

      slot:SetScript("OnEnter", function(_self)
        GameTooltip:SetOwner(_self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(_self.itemLink)
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

-- ==========================================
-- Inventory functionality
-- ==========================================
function addon:GetContainerName(id)
  if id >= 0 and id <= 4 then
    return L["INV_LOC_BAG"]
  elseif id == 5 then
    return L["INV_LOC_REAGENT_BAG"]
  elseif id >= 6 and id <= 11 then
    return L["INV_LOC_BANK"]
  elseif id >= 12 and id <= 16 then
    return L["INV_LOC_WARBAND_BANK"]
  else
    return L["INV_LOC_OTHERS"]
  end
end

function addon:AggregateWarbandItems()
  local AGGREGATED_ITEMS = self.CT_IP_STATUS.AGGREGATED_ITEMS
  table.wipe(AGGREGATED_ITEMS)

  for _, character in pairs(CharactersTrackerDB.CHARACTERS) do
    if type(character) == "table" and character.name and character.bags then
      local storage = string.format("%s-%s", FORMATTERS.NAME(character), FORMATTERS.REALM(character))
      for bagId, bag in pairs(character.bags) do
        for _, item in pairs(bag) do
          if item and item.id then
            if not AGGREGATED_ITEMS[item.id] then
              AGGREGATED_ITEMS[item.id] = {
                id = item.id,
                name = item.link and (C_Item.GetItemInfo(item.link) or item.link:match("%[(.-)%]")),
                icon = item.icon or 134400,
                quality = item.quality or 1,
                link = item.link,
                totalCount = 0,
                sources = {}
              }
            end
            AGGREGATED_ITEMS[item.id].totalCount = AGGREGATED_ITEMS[item.id].totalCount + item.count
            local container = addon:GetContainerName(bagId)
            if not AGGREGATED_ITEMS[item.id].sources[storage] then
              AGGREGATED_ITEMS[item.id].sources[storage] = {}
            end
            AGGREGATED_ITEMS[item.id].sources[storage][container] =
                (AGGREGATED_ITEMS[item.id].sources[storage][container] or 0) + item.count
          end
        end
      end
    end
  end
  -- warband data
  for bagId, bag in pairs(CharactersTrackerDB.WARBAND.BAGS) do
    for _, item in pairs(bag) do
      if item and item.id then
        if not AGGREGATED_ITEMS[item.id] then
          AGGREGATED_ITEMS[item.id] = {
            id = item.id,
            name = item.link and (C_Item.GetItemInfo(item.link) or item.link:match("%[(.-)%]")),
            icon = item.icon or 134400,
            quality = item.quality or 1,
            link = item.link,
            totalCount = 0,
            sources = {}
          }
        end

        AGGREGATED_ITEMS[item.id].totalCount = AGGREGATED_ITEMS[item.id].totalCount + item.count
        local storage = L["INV_SRC_WARBAND"]
        local container = addon:GetContainerName(bagId)
        if not AGGREGATED_ITEMS[item.id].sources[storage] then
          AGGREGATED_ITEMS[item.id].sources[storage] = {}
        end
        AGGREGATED_ITEMS[item.id].sources[storage][container] =
            (AGGREGATED_ITEMS[item.id].sources[storage][container] or 0) + item.count
      end
    end
  end
end

function addon:FilterAndSortItems(searchText)
  local FILTERED_ITEMS = self.CT_IP_STATUS.FILTERED_ITEMS
  local AGGREGATED_ITEMS = self.CT_IP_STATUS.AGGREGATED_ITEMS

  table.wipe(FILTERED_ITEMS)
  searchText = searchText and string.lower(strtrim(searchText)) or ""

  for _, item in pairs(AGGREGATED_ITEMS) do
    local match = false
    if "" == searchText then
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

  table.sort(
    FILTERED_ITEMS,
    function(a, b)
      if a.quality ~= b.quality then
        return (a.quality or 0) > (b.quality or 0)
      else
        return (a.id or 0) > (b.id or 0)
      end
    end
  )
end

function addon:UpdateInventoryGrid()
  if not self.CT_INVENTORY_PANEL then return end

  local FILTERED_ITEMS = self.CT_IP_STATUS.FILTERED_ITEMS

  local totalItems = #FILTERED_ITEMS
  local maxPages = math.max(1, math.ceil(totalItems / self.CT_IP_STATUS.ITEMS_PER_PAGE))
  if self.CT_IP_STATUS.CURRENT_PAGE > maxPages then self.CT_IP_STATUS.CURRENT_PAGE = maxPages end

  self.CT_INVENTORY_PANEL.paging:SetText(string.format("%d / %d", self.CT_IP_STATUS.CURRENT_PAGE, maxPages))

  local startIndex = (self.CT_IP_STATUS.CURRENT_PAGE - 1) * self.CT_IP_STATUS.ITEMS_PER_PAGE

  for i = 1, self.CT_IP_STATUS.ITEMS_PER_PAGE do
    local btn = self.CT_INVENTORY_PANEL.grids[i]
    local item = FILTERED_ITEMS[startIndex + i]

    if item then
      btn.icon:SetTexture(item.icon)
      btn.counter:SetText(item.totalCount)
      btn.item = item
      btn:Show()
    else
      btn.item = nil
      btn:Hide()
    end
  end
end

function addon:CreateInventoryPanel()
  if self.CT_INVENTORY_PANEL then
    return
  end

  self.CT_IP_STATUS = {
    CURRENT_PAGE = 1,
    ITEMS_PER_PAGE = 40,
    AGGREGATED_ITEMS = {},
    FILTERED_ITEMS = {},
  }

  local inventoryPanel = addon:Util_CreateBaseWindow("CT_INVENTORY_PANEL", UIParent)
  self.CT_INVENTORY_PANEL = inventoryPanel
  inventoryPanel:Hide()

  inventoryPanel:SetFrameStrata("MEDIUM")
  inventoryPanel:SetFrameLevel(CT_INVENTORY_PANEL_LEVEL)
  inventoryPanel:SetSize(CT_THEME.INVENTORY_PANEL.WIDTH, CT_THEME.INVENTORY_PANEL.HEIGHT)

  inventoryPanel.bg = inventoryPanel:CreateTexture(nil, "BACKGROUND")
  inventoryPanel.bg:SetAllPoints()
  inventoryPanel.bg:SetColorTexture(unpack(CT_THEME.INVENTORY_PANEL.BG.COLOR))

  inventoryPanel.banner = addon:Util_CreateBanner(
    "CT_INVENTORY_PANEL_BANNER",
    self.CT_INVENTORY_PANEL,
    L["INV_TITLE"],
    CT_THEME.INVENTORY_PANEL.BANNER
  )
  self.CT_INVENTORY_PANEL_BANNER = inventoryPanel.banner

  local searchBox = CreateFrame("EditBox", nil, self.CT_INVENTORY_PANEL, "InputBoxTemplate")
  inventoryPanel.searchBox = searchBox
  searchBox:SetSize(604, 24)
  searchBox:SetPoint("TOPLEFT", self.CT_INVENTORY_PANEL, "TOPLEFT", 21, -44)
  searchBox:SetAutoFocus(false)

  local sLabel = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  sLabel:SetPoint("LEFT", searchBox, "LEFT", 5, 0)
  sLabel:SetText(L["INV_SEARCH_TIP"])

  searchBox:SetScript("OnTextChanged", function(_self)
    if _self:GetText() == "" then sLabel:Show() else sLabel:Hide() end
    addon:FilterAndSortItems(_self:GetText())
    addon.CT_IP_STATUS.CURRENT_PAGE = 1
    addon:UpdateInventoryGrid()
  end)
  searchBox:SetScript("OnEscapePressed", function(_self) _self:ClearFocus() end)

  self.CT_INVENTORY_PANEL.grids = {}
  local startX = 15
  local startY = -80
  local spacingX = 14
  local spacingY = 24
  local iconSide = 64

  for row = 0, 4 do
    for col = 0, 7 do
      local btn = CreateFrame("Button", nil, self.CT_INVENTORY_PANEL, "BackdropTemplate")
      btn:SetSize(iconSide, iconSide)
      btn.icon = btn:CreateTexture(nil, "BACKGROUND")
      btn.icon:SetAllPoints(btn)

      btn.counter = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      btn.counter:SetPoint("TOP", btn, "BOTTOM", 0, 0)

      btn:SetPoint(
        "TOPLEFT",
        self.CT_INVENTORY_PANEL,
        "TOPLEFT",
        startX + (col * (spacingX + iconSide)),
        startY - (row * (spacingY + iconSide))
      )

      btn:SetScript("OnClick", function(_self)
        if _self.item and _self.item.link and IsShiftKeyDown() then
          local editBox = ChatEdit_GetActiveWindow()
          if editBox then
            editBox:Insert(_self.item.link)
          end
        end
      end)

      btn:SetScript(
        "OnEnter",
        function(_self)
          if not _self.item then return end
          GameTooltip:SetOwner(_self, "ANCHOR_RIGHT")
          if _self.item.link then
            GameTooltip:SetHyperlink(_self.item.link)
          else
            -- GameTooltip:SetText(self.item.name)
            GameTooltip:AddLine(_self.item.name)
          end

          GameTooltip:AddLine(" ")
          GameTooltip:AddLine(L["INV_DETAIL"])

          for character, locations in pairs(_self.item.sources) do
            for container, count in pairs(locations) do
              GameTooltip:AddDoubleLine(
                string.format(" %s [%s]", character, container),
                string.format("(%d)", count),
                1, 1, 1, 1, 1, 1
              )
            end
          end
          GameTooltip:Show()
        end
      )
      btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

      table.insert(self.CT_INVENTORY_PANEL.grids, btn)
    end
  end

  local FILTERED_ITEMS = self.CT_IP_STATUS.FILTERED_ITEMS

  local prevBtn = CreateFrame("Button", nil, self.CT_INVENTORY_PANEL, "GameMenuButtonTemplate")
  prevBtn:SetSize(96, 24)
  prevBtn:SetPoint("BOTTOMLEFT", self.CT_INVENTORY_PANEL, "BOTTOMLEFT", 64, 12)
  prevBtn:SetText("<")
  prevBtn:SetScript("OnClick", function()
    if self.CT_IP_STATUS.CURRENT_PAGE > 1 then
      self.CT_IP_STATUS.CURRENT_PAGE = self.CT_IP_STATUS.CURRENT_PAGE - 1
      addon:UpdateInventoryGrid()
    end
  end)

  local nextBtn = CreateFrame("Button", nil, self.CT_INVENTORY_PANEL, "GameMenuButtonTemplate")
  nextBtn:SetSize(96, 24)
  nextBtn:SetPoint("BOTTOMRIGHT", self.CT_INVENTORY_PANEL, "BOTTOMRIGHT", -64, 12)
  nextBtn:SetText(">")
  nextBtn:SetScript("OnClick", function()
    local maxPages = math.max(1, math.ceil(#FILTERED_ITEMS / self.CT_IP_STATUS.ITEMS_PER_PAGE))
    if self.CT_IP_STATUS.CURRENT_PAGE < maxPages then
      self.CT_IP_STATUS.CURRENT_PAGE = self.CT_IP_STATUS.CURRENT_PAGE + 1
      addon:UpdateInventoryGrid()
    end
  end)

  local paging = self.CT_INVENTORY_PANEL:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  paging:SetPoint("CENTER", self.CT_INVENTORY_PANEL, "BOTTOM", 0, 26)
  self.CT_INVENTORY_PANEL.paging = paging
end

function addon:ToggleInventoryPanel()
  addon:CreateInventoryPanel()
  if self.CT_INVENTORY_PANEL:IsShown() then
    self.CT_INVENTORY_PANEL:Hide()
  else
    addon:AggregateWarbandItems()
    addon:FilterAndSortItems(self.CT_INVENTORY_PANEL.searchBox:GetText() or "")
    self.CT_IP_STATUS.CURRENT_PAGE = 1
    addon:UpdateInventoryGrid()
    self.CT_INVENTORY_PANEL:Show()
  end
end

-- ==========================================
-- Floating button
-- ==========================================
function addon:CreateFloatingButton()
  if self.CT_FB then
    return
  end

  local fb = CreateFrame("Button", "CT_FLOATING_BUTTON_STUB", UIParent)
  self.CT_FB = fb
  fb:SetSize(unpack(CT_THEME.FB.SIZE))
  fb:SetFrameStrata("HIGH")
  fb:SetClampedToScreen(true)
  fb:SetMovable(true)
  fb:EnableMouse(true)
  fb:RegisterForDrag("LeftButton")

  fb.icon = fb:CreateTexture(nil, "ARTWORK")
  fb.icon:SetSize(unpack(CT_THEME.FB.ICON.SIZE))
  fb.icon:SetPoint("CENTER", 0, 0)
  fb.icon:SetTexture(CT_THEME.FB.ICON.TEXTURE)

  fb:SetScript("OnDragStart", function(_self) _self:StartMoving() end)
  fb:SetScript("OnDragStop", function(_self)
    _self:StopMovingOrSizing()
    if CharactersTrackerDB then
      local point, _, relativePoint, xOfs, yOfs = _self:GetPoint()
      CharactersTrackerDB.SETTINGS.POSITIONS["FloatingButtonPosition"] = {
        point = point, relativePoint = relativePoint, xOfs = xOfs, yOfs = yOfs
      }
    end
  end)

  fb:RegisterForClicks("AnyUp")
  fb:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
      addon:ToggleInventoryPanel()
    else
      addon:Main()
    end
  end)

  fb:SetScript("OnEnter", function(_self)
    GameTooltip:SetOwner(_self, "ANCHOR_LEFT")
    GameTooltip:SetText(L["FB_FUNC"], 1, 1, 1)
    GameTooltip:AddLine(L["FB_L1"], 0.2, 1.0, 0.2)
    GameTooltip:AddLine(L["FB_L2"], 0.4, 0.8, 0.2)
    GameTooltip:AddLine(L["FB_L3"], 0.4, 0.8, 0.2)
    GameTooltip:Show()
  end)
  fb:SetScript("OnLeave", function() GameTooltip:Hide() end)

  if CharactersTrackerDB and CharactersTrackerDB.SETTINGS.POSITIONS["FloatingButtonPosition"] then
    local pos = CharactersTrackerDB.SETTINGS.POSITIONS["FloatingButtonPosition"]
    fb:ClearAllPoints()
    fb:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)
  else
    fb:SetPoint("CENTER", UIParent, "CENTER", -200, 0)
  end
end
