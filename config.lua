Config = {}

-- General settings
Config.Debug = false
Config.UseTarget = true  -- Use ox_target for interaction
Config.AdminGroups = {'admin', 'mod', 'god'} -- Groups that can manage shops

-- Database settings
Config.DatabaseTable = 'shops'

-- Shop settings
Config.DefaultSlots = 30
Config.MaxShopDistance = 2.5
Config.BlipSettings = {
    sprite = 52,
    color = 2,
    scale = 0.7,
    name = 'Tienda'
}

-- UI settings
Config.ShopTitle = 'Tienda'
Config.DefaultImage = 'https://cfx-nui-ox_inventory/web/images/%s.png' -- Fallback to ox_inventory images
Config.FallbackImage = 'https://i.imgur.com/uYMkWxZ.png' -- If item image not found

-- Default categories and their emojis
Config.ItemCategories = {
    -- Armas
    weapon = "🔫", -- 🔫
    ammo = "🌎", -- 🌎 (munición)
    
    -- Comida/bebida
    food = "🍔", -- 🍔
    drink = "🥤", -- 🥤
    alcohol = "🍻", -- 🍻
    
    -- Medicamentos
    medicine = "💊", -- 💊
    medkit = "🟥", -- 🟥
    bandage = "🧦", -- 🧦
    
    -- Ropa
    clothing = "👕", -- 👕
    helmet = "🧢", -- 🧢
    accessory = "👗", -- 👗
    
    -- Herramientas
    tool = "🔧", -- 🔧
    equipment = "🔨", -- 🔨
    electronic = "📱", -- 📱
    
    -- Drogas
    drug = "🍃", -- 🍃
    chemical = "🧪", -- 🧪
    
    -- Misc
    valuable = "💰", -- 💰
    key = "🔑", -- 🔑
    radio = "📻", -- 📻
    bag = "🎒", -- 🎒
    repair = "🛠️", -- 🛠️
    lockpick = "🔓", -- 🔓
    crafting = "📜", -- 📜
    collectible = "🎁", -- 🎁
}

-- Item prefixes for categorization
Config.ItemPrefixes = {
    ["weapon_"] = "weapon",
    ["ammo"] = "ammo",
    ["food"] = "food",
    ["sandwich"] = "food",
    ["burger"] = "food",
    ["taco"] = "food",
    ["water"] = "drink",
    ["cola"] = "drink",
    ["beer"] = "alcohol",
    ["whisky"] = "alcohol",
    ["wine"] = "alcohol",
    ["vodka"] = "alcohol",
    ["bandage"] = "bandage",
    ["medkit"] = "medkit",
    ["pill"] = "medicine",
    ["phone"] = "electronic",
    ["laptop"] = "electronic",
    ["radio"] = "radio",
    ["money"] = "valuable",
    ["gold"] = "valuable",
    ["lockpick"] = "lockpick",
    ["repairkit"] = "repair",
    ["clothes"] = "clothing",
    ["hat"] = "helmet",
    ["bag"] = "bag",
    ["weed"] = "drug",
    ["coke"] = "drug",
    ["meth"] = "drug",
    ["key"] = "key",
    ["craft"] = "crafting",
}
