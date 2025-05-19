-- Discord integration for zk-shop-ux
local webhook = "https://discord.com/api/webhooks/1373397020328460288/IP4vjaDUDoaLEy9U9RyHP8BjyEdK0QNFL4YfphdJL6RxtUkW1OlfVuydMQc_gN460GBc"

-- Get item emoji based on category
local function GetItemEmoji(itemName)
    -- Check for item prefixes to determine category
    for prefix, category in pairs(Config.ItemPrefixes) do
        if string.find(string.lower(itemName), prefix) then
            return Config.ItemCategories[category] or "💾" -- Default emoji if category exists but no emoji
        end
    end
    
    return "💾" -- Default emoji for uncategorized items
end

-- Create Discord webhook embed fields for items
local function CreateItemFields(items)
    local fields = {}
    for _, item in ipairs(items) do
        local emoji = GetItemEmoji(item.name)
        table.insert(fields, {
            name = emoji .. " " .. (item.label or item.name),
            value = "Cantidad: " .. item.amount .. " | Precio: $" .. (item.price or 0),
            inline = true
        })
    end
    return fields
end

-- Send a webhook to Discord
local function SendDiscordWebhook(title, description, color, fields)
    local embed = {
        {
            ["title"] = title,
            ["description"] = description,
            ["color"] = color or 3447003, -- Default blue color
            ["footer"] = {
                ["text"] = "ZK Custom Shops | " .. os.date("%Y-%m-%d %H:%M:%S")
            }
        }
    }
    
    if fields then
        embed[1]["fields"] = fields
    end
    
    PerformHttpRequest(webhook, function(err, text, headers) end, 'POST', json.encode({embeds = embed}), { ['Content-Type'] = 'application/json' })
end

-- Log shop creation
function LogShopCreation(shopName, owner, slots, coords, items)
    local itemFields = CreateItemFields(items)
    
    SendDiscordWebhook(
        "📦 Nueva Tienda Creada", 
        "**Nombre:** " .. shopName .. "\n" ..
        "**Propietario:** " .. owner .. "\n" ..
        "**Slots:** " .. slots .. "\n" ..
        "**Coordenadas:** X: " .. coords.x .. ", Y: " .. coords.y .. ", Z: " .. coords.z,
        3066993, -- Green color
        itemFields
    )
end

-- Log shop deletion
function LogShopDeletion(shopName, owner, coords, balance)
    SendDiscordWebhook(
        "🔥 Tienda Eliminada", 
        "**Nombre de tienda:** " .. shopName .. "\n" ..
        "**Eliminada por:** " .. owner .. "\n" ..
        "**Coordenadas:** X: " .. coords.x .. ", Y: " .. coords.y .. ", Z: " .. coords.z .. "\n" ..
        "**Balance final:** $" .. (balance or 0),
        15158332 -- Red color
    )
end

-- Log shop items update
function LogShopItemsUpdate(shopName, owner, items)
    local itemFields = CreateItemFields(items)
    
    SendDiscordWebhook(
        "🔄 Productos Actualizados", 
        "**Tienda:** " .. shopName .. "\n" ..
        "**Actualizado por:** " .. owner,
        1752220, -- Yellow color
        itemFields
    )
end

-- Log shop purchase
function LogShopPurchase(shopName, buyer, itemName, amount, totalPrice)
    SendDiscordWebhook(
        "💸 Compra Realizada", 
        "**Tienda:** " .. shopName .. "\n" ..
        "**Comprador:** " .. buyer .. "\n" ..
        "**Item:** " .. GetItemEmoji(itemName) .. " " .. itemName .. "\n" ..
        "**Cantidad:** " .. amount .. "\n" ..
        "**Precio Total:** $" .. totalPrice,
        3447003 -- Blue color
    )
end
