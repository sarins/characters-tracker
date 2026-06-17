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
L["FB_L1"] = "Left-Click: Toggle Warband Character List"
L["FB_L2"] = "Hold Left-Click: Drag to reposition button"
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

-- ====================================================================
-- 简体中文环境 (zhCN)
-- ====================================================================
if currentLocale == "zhCN" then
  L["FB_FUNC"] = "战团角色追踪"
  L["FB_L1"] = "左键点击: 打开/关闭战团角色列表"
  L["FB_L2"] = "按住左键拖动: 自由调整按钮位置"
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
end
