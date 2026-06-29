-- ====================================================================
-- CharactersTracker Locale
-- ====================================================================

-- 1. 获取当前游戏客户端语言
local currentLocale = GetLocale()

-- 2. 默认语言包（基准语言，如果找不到对应语言则隐式继承英文，防止报错空指针）
local L = setmetatable({}, {
  __index = function(t, k)
    return k -- 如果某个词条没翻译，直接返回键名本身
  end
})

-- 注册全局或 addon 内部局部变量（这里我们直接绑定到 L 方便调用）
CharactersTracker_Locale = L

L["FB_FUNC"] = "Warband Characters Tracker"
L["FB_L1"] = "Hold Left-Click: Drag to reposition button"
L["FB_L2"] = "Left-Click: Toggle Warband Character List"
L["FB_L3"] = "Right-Click: Toggle Warband Inventory Summary"
L["VT_TITLE"] = "Great Vault Weekly Progress"
L["VT_RAIDS"] = "Raids"
L["VT_DUNGEONS"] = "Dungeons"
L["VT_DW"] = "Delves/World"
L["VT_UNLOCKED"] = "Unlocked"
L["VT_LEVEL"] = "Tier %d"
L["VT_LOCKED"] = "N/A"
L["CHOOSE_CHARACTER"] = "Characters"
L["GEAR_DETAIL"] = "Gear Detail"
L["CURR_TIP_L1"] = "No local currency data available"
L["CURR_TIP_L2"] = "Log in to this character to sync"
L["CURR_WEEKLY_LIMIT"] = " |cff0070dd(%d/%d) Weekly|r"
L["CURR_SEASON_LIMIT"] = " |cffff8000(%d/%d) Season|r"
L["CURR_LIMIT"] = " |cffffd100(%d/%d)|r"
L["INV_TITLE"] = "Inventory Summary"
L["INV_LOADING"] = "Loading..."
L["INV_SEARCH_TIP"] = "Search..."
L["INV_DETAIL"] = "|cffffd100Inventory Detail:|r"
L["INV_SRC_WARBAND"] = "|cff66bbffWarband|r"
L["INV_LOC_BAG"] = "Bag"
L["INV_LOC_REAGENT_BAG"] = "Reagent Bag"
L["INV_LOC_BANK"] = "Bank"
L["INV_LOC_WARBAND_BANK"] = "Warband Bank"
L["INV_LOC_OTHERS"] = "Others"

-- ====================================================================
-- 简体中文环境 (zhCN)
-- ====================================================================
if currentLocale == "zhCN" then
  L["FB_FUNC"] = "战团角色追踪"
  L["FB_L1"] = "按住左键拖动: 自由调整按钮位置"
  L["FB_L2"] = "左键点击: 打开/关闭战团角色列表"
  L["FB_L3"] = "右键点击: 开启/关闭战团物品汇总"
  L["VT_TITLE"] = "宏伟宝库进度"
  L["VT_RAIDS"] = "团队副本"
  L["VT_DUNGEONS"] = "地下城"
  L["VT_DW"] = "地下堡/世界"
  L["VT_UNLOCKED"] = "已解锁"
  L["VT_LEVEL"] = "%d层"
  L["VT_LOCKED"] = "未开始"
  L["CHOOSE_CHARACTER"] = "角色选择"
  L["GEAR_DETAIL"] = "详细装备"
  L["CURR_TIP_L1"] = "暂无该角色的非战网共享货币数据"
  L["CURR_TIP_L2"] = "请切换登录该角色以同步数据"
  L["CURR_WEEKLY_LIMIT"] = " |cff0070dd(%d/%d) 每周|r"
  L["CURR_SEASON_LIMIT"] = " |cffff8000(%d/%d) 赛季|r"
  L["CURR_LIMIT"] = " |cffffd100(%d/%d)|r"
  L["INV_TITLE"] = "战团物品汇总"
  L["INV_LOADING"] = "加载中..."
  L["INV_SEARCH_TIP"] = "搜索..."
  L["INV_DETAIL"] = "|cffffd100物品存储明细:|r"
  L["INV_SRC_WARBAND"] = "|cff66bbff战团|r"
  L["INV_LOC_BAG"] = "背包"
  L["INV_LOC_REAGENT_BAG"] = "材料包"
  L["INV_LOC_BANK"] = "银行"
  L["INV_LOC_WARBAND_BANK"] = "战团银行"
  L["INV_LOC_OTHERS"] = "其他"
end
