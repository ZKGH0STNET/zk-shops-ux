-- Discord Webhook Integration for ZK-Shop-UX
-- This file handles all Discord logging functionality

local webhook = "https://discord.com/api/webhooks/1373397020328460288/IP4vjaDUDoaLEy9U9RyHP8BjyEdK0QNFL4YfphdJL6RxtUkW1OlfVuydMQc_gN460GBc"

-- Mapeo de tipos de items a emojis
local itemTypeEmojis = {
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

-- Lista de prefijos de items y su tipo
local prefixMap = {
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

-- Función para obtener el emoji adecuado para un item
local function GetItemEmoji(itemName)
    -- Verificar prefijos
    for prefix, itemType in pairs(prefixMap) do
        if string.find(string.lower(itemName), prefix) then
            return itemTypeEmojis[itemType] or "💾" -- default: 💾
        end
    end
    
    return "💾" -- Emoji por defecto para items sin categoría
end

-- Función para enviar notificaciones al webhook de Discord
local function SendDiscordWebhook(title, description, color, fields)
    local embed = {
        {
            ["title"] = title,
            ["description"] = description,
            ["color"] = color or 3447003, -- Color azul por defecto
            ["footer"] = {
                ["text"] = "ZK Custom Shops | " .. os.date("%Y-%m-%d %H:%M:%S")
            }
        }
    }
    
    -- Añadir campos adicionales si se proporcionan
    if fields then
        embed[1]["fields"] = fields
    end
    
    PerformHttpRequest(webhook, function(err, text, headers) end, 'POST', json.encode({embeds = embed}), { ['Content-Type'] = 'application/json' })
end

-- Función para crear campos para los items
local function CreateItemFields(items)
    local itemFields = {}
    for _, item in ipairs(items) do
        local emoji = GetItemEmoji(item.name)
        table.insert(itemFields, {
            name = emoji .. " " .. (item.label or item.name),
            value = "Cantidad: " .. item.amount .. " | Precio: $" .. (item.price or 0),
            inline = true
        })
    end
    return itemFields
end

-- Log functions for specific shop actions
local function LogShopCreation(shopName, owner, slots, coords, items)
    local itemFields = CreateItemFields(items)
    
    SendDiscordWebhook(
        "📦 Nueva Tienda Creada", 
        "**Nombre:** " .. shopName .. "\n" ..
        "**Propietario:** " .. owner .. "\n" ..
        "**Slots:** " .. slots .. "\n" ..
        "**Coordenadas:** X: " .. coords.x .. ", Y: " .. coords.y .. ", Z: " .. coords.z,
        3066993, -- Color verde
        itemFields
    )
end

local function LogShopDeletion(shopName, owner, coords, balance)
    SendDiscordWebhook(
        "🔥 Tienda Eliminada", 
        "**Nombre de tienda:** " .. shopName .. "\n" ..
        "**Eliminada por:** " .. owner .. "\n" ..
        "**Coordenadas:** X: " .. coords.x .. ", Y: " .. coords.y .. ", Z: " .. coords.z .. "\n" ..
        "**Balance final:** $" .. (balance or 0),
        15158332 -- Color rojo
    )
end

local function LogShopItemsUpdate(shopName, owner, items)
    local itemFields = CreateItemFields(items)
    
    SendDiscordWebhook(
        "🔄 Productos Actualizados", 
        "**Tienda:** " .. shopName .. "\n" ..
        "**Actualizado por:** " .. owner,
        1752220, -- Color amarillo
        itemFields
    )
end

local function LogShopPurchase(shopName, buyer, itemName, amount, totalPrice)
    SendDiscordWebhook(
        "💸 Compra Realizada", 
        "**Tienda:** " .. shopName .. "\n" ..
        "**Comprador:** " .. buyer .. "\n" ..
        "**Item:** " .. GetItemEmoji(itemName) .. " " .. itemName .. "\n" ..
        "**Cantidad:** " .. amount .. "\n" ..
        "**Precio Total:** $" .. totalPrice,
        3447003 -- Color azul
    )
end

-- Logs para acciones del boss menu (funciones GLOBALES para usar desde otros archivos)
function LogShopTransaction(shopName, playerId, transactionType, amount)
    print('^2[ZK-SHOPS] Enviando log a Discord: ' .. transactionType .. ' - Tienda: ' .. shopName .. '^7')
    local icon = transactionType == 'withdraw' and '💸' or '💰'
    local action = transactionType == 'withdraw' and 'Retiro de Fondos' or 'Depósito de Fondos'
    local color = transactionType == 'withdraw' and 15158332 or 3066993 -- rojo para retiros, verde para depósitos
    
    SendDiscordWebhook(
        icon .. " " .. action, 
        "**Tienda:** " .. shopName .. "\n" ..
        "**Jugador:** " .. playerId .. "\n" ..
        "**Cantidad:** $" .. amount .. "\n" ..
        "**Acción:** " .. (transactionType == 'withdraw' and 'Retiró dinero' or 'Depositó dinero'),
        color
    )
end

function LogShopOwnershipTransfer(shopName, previousOwner, newOwner)
    print('^2[ZK-SHOPS] Enviando log a Discord: Transferencia - Tienda: ' .. shopName .. '^7')
    SendDiscordWebhook(
        "👑 Transferencia de Propiedad", 
        "**Tienda:** " .. shopName .. "\n" ..
        "**Propietario Anterior:** " .. previousOwner .. "\n" ..
        "**Nuevo Propietario:** " .. newOwner,
        11027200 -- Color púrpura
    )
end

-- Export the functions
return {
    LogShopCreation = LogShopCreation,
    LogShopDeletion = LogShopDeletion,
    LogShopItemsUpdate = LogShopItemsUpdate,
    LogShopPurchase = LogShopPurchase,
    LogShopTransaction = LogShopTransaction,
    LogShopOwnershipTransfer = LogShopOwnershipTransfer,
    GetItemEmoji = GetItemEmoji
}
