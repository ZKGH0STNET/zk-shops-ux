local QBCore = exports['qb-core']:GetCoreObject()
local oxmysql = exports['oxmysql']

-- Ruta relativa a la carpeta DEV
local configPath = "./config.lua"

-- Discord Webhook
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

-- Función para obtener el emoji adecuado para un item
local function GetItemEmoji(itemName)
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

local function guardarTiendasEnConfig()
    oxmysql:execute('SELECT * FROM tiendas', {}, function(result)
        local tiendas = {}
        for _, row in ipairs(result) do
            table.insert(tiendas, {
                name = row.name,
                coords = { x = row.coords_x, y = row.coords_y, z = row.coords_z },
                slots = row.slots,
                items = json.decode(row.items or '{}')
            })
        end

        -- Añadir manejo de errores para operaciones de archivo
        local file, errMsg = io.open(configPath, "w+")
        if not file then
            print("[ERROR] No se pudo abrir config.lua para escritura: " .. tostring(errMsg))
            return
        end
        
        -- Ahora que sabemos que el archivo está abierto, podemos escribir en él
        file:write("Config = {}\n")
        file:write("Config.Tiendas = ")
        file:write(json.encode(tiendas, { indent = true }))
        file:write("\n")
        file:close()
        print("[DEBUG] Tiendas guardadas en config.lua")
    end)
end

RegisterNetEvent("tienda:crearNuevaTienda", function(shopName, slots, coords, items)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    local identifier = xPlayer.PlayerData.citizenid
    
    print("[DEBUG] Creando nueva tienda: " .. shopName)
    print("[DEBUG] Items para la tienda: " .. json.encode(items))
    print("[DEBUG] Coordenadas: " .. json.encode(coords))

    oxmysql:execute('INSERT INTO tiendas (name, coords_x, coords_y, coords_z, slots, items, owner) VALUES (?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE coords_x=VALUES(coords_x), coords_y=VALUES(coords_y), coords_z=VALUES(coords_z), slots=VALUES(slots), items=VALUES(items), owner=VALUES(owner)', {
        shopName, coords.x, coords.y, coords.z, slots, json.encode(items or {}), identifier
    }, function(result)
        -- Registramos inmediatamente la tienda para que funcione con ox_inventory
        local shopInventory = {}
        for i=1, #items do
            local item = items[i]
            table.insert(shopInventory, {
                name = item.name,
                price = item.price
            })
        end
        
        -- Registramos la tienda con ox_inventory directamente al crearla
        exports.ox_inventory:RegisterShop(shopName, {
            name = 'Tienda: ' .. shopName,
            inventory = shopInventory,
            locations = {
                vec3(coords.x, coords.y, coords.z)
            },
            groups = {}
        })
        
        print("[DEBUG] Tienda registrada con ox_inventory: " .. shopName)
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Tienda creada',
            description = 'La tienda fue creada correctamente.',
            type = 'success'
        })
        cargarYEnviarTiendas()
        
        -- Crear campos de items para webhook
        local itemFields = {}
        for _, item in ipairs(items) do
            local emoji = GetItemEmoji(item.name)
            table.insert(itemFields, {
                name = emoji .. " " .. (item.label or item.name),
                value = "Cantidad: " .. item.amount .. " | Precio: $" .. (item.price or 0),
                inline = true
            })
        end
        
        -- Notificar a Discord
        SendDiscordWebhook(
            "📦 Nueva Tienda Creada", 
            "**Nombre:** " .. shopName .. "\n" ..
            "**Propietario:** " .. identifier .. "\n" ..
            "**Slots:** " .. slots,
            3066993, -- Color verde
            itemFields
        )
    end)
end)

RegisterNetEvent("tienda:guardarItems", function(shopName, items)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    
    oxmysql:execute('UPDATE tiendas SET items = ? WHERE name = ?', {
        json.encode(items), shopName
    }, function()
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Items guardados',
            description = 'La tienda ya está lista.',
            type = 'success'
        })
        cargarYEnviarTiendas()
        guardarTiendasEnConfig()
        
        -- Crear campos de items para webhook
        local itemFields = {}
        for _, item in ipairs(items) do
            local emoji = GetItemEmoji(item.name)
            table.insert(itemFields, {
                name = emoji .. " " .. (item.label or item.name),
                value = "Cantidad: " .. item.amount .. " | Precio: $" .. (item.price or 0),
                inline = true
            })
        end
        
        -- Notificar a Discord
        SendDiscordWebhook(
            "🔄 Productos Actualizados", 
            "**Tienda:** " .. shopName .. "\n" ..
            "**Actualizado por:** " .. xPlayer.PlayerData.citizenid,
            1752220, -- Color amarillo
            itemFields
        )
    end)
end)

RegisterNetEvent("tienda:abrirTienda", function(shopName)
    local src = source
    print("[DEBUG] Intentando abrir tienda: " .. shopName .. " para el jugador " .. src)
    
    oxmysql:execute('SELECT * FROM tiendas WHERE name = ?', {shopName}, function(result)
        if result and result[1] then
            local tienda = result[1]
            local items = json.decode(tienda.items or '{}')
            print("[DEBUG] Items cargados: " .. json.encode(items))
            
            -- Preparar los datos de la tienda para enviar al cliente
            local shopData = {
                name = tienda.name,
                slots = tienda.slots,
                items = items,
                coords = {
                    x = tienda.coords_x,
                    y = tienda.coords_y,
                    z = tienda.coords_z
                }
            }
            
            -- Enviar un evento al cliente para abrir la tienda con nuestra interfaz personalizada
            TriggerClientEvent('zk-shops:openShopInventory', src, shopName, shopData)
            
            -- Notificar al jugador
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Tienda',
                description = 'Abriendo tienda...',
                type = 'success'
            })
        else
            print("[DEBUG] No se encontró la tienda: " .. shopName)
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Error',
                description = 'La tienda no existe.',
                type = 'error'
            })
        end
    end)
end)

-- Nuevo evento para procesar la compra de un item
RegisterNetEvent('tienda:comprarItem', function(shopName, itemName, cantidad, precio)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    
    if not xPlayer then
        print("[ERROR] No se pudo obtener el Player para el source " .. src)
        return
    end
    
    -- Verificar cantidad y precio
    cantidad = tonumber(cantidad) or 1
    precio = tonumber(precio) or 0
    local totalPrecio = precio * cantidad
    
    print("[DEBUG] Compra solicitada: " .. shopName .. " - Item: " .. itemName .. " - Cantidad: " .. cantidad .. " - Precio total: $" .. totalPrecio)
    
    -- Verificar si el jugador tiene dinero suficiente
    if xPlayer.PlayerData.money.cash < totalPrecio then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'No tienes suficiente dinero. Necesitas $' .. totalPrecio,
            type = 'error'
        })
        return
    end
    
    -- Buscar la tienda y verificar disponibilidad
    oxmysql:execute('SELECT * FROM tiendas WHERE name = ?', {shopName}, function(result)
        if result and result[1] then
            local tienda = result[1]
            local items = json.decode(tienda.items or '{}')
            
            -- Encontrar el item en la tienda
            local encontrado = false
            local itemIndex = nil
            
            for i, item in ipairs(items) do
                if item.name == itemName then
                    encontrado = true
                    itemIndex = i
                    
                    -- Verificar cantidad disponible
                    if (item.amount or 0) < cantidad then
                        TriggerClientEvent('ox_lib:notify', src, {
                            title = 'Error',
                            description = 'No hay suficiente stock. Solo quedan ' .. (item.amount or 0) .. ' unidades.',
                            type = 'error'
                        })
                        return
                    end
                    
                    -- Todo está bien, proceder con la compra
                    break
                end
            end
            
            if not encontrado then
                TriggerClientEvent('ox_lib:notify', src, {
                    title = 'Error',
                    description = 'El producto ya no está disponible en la tienda.',
                    type = 'error'
                })
                return
            end
            
            -- Realizar la compra
            -- 1. Quitar el dinero al jugador
            xPlayer.Functions.RemoveMoney('cash', totalPrecio)
            
            -- 2. Dar el item al jugador usando QBCore
            xPlayer.Functions.AddItem(itemName, cantidad)
            
            -- 3. Actualizar el inventario de la tienda
            items[itemIndex].amount = (items[itemIndex].amount or 0) - cantidad
            
            -- 4. Guardar cambios en la base de datos
            oxmysql:execute('UPDATE tiendas SET items = ?, balance = balance + ? WHERE name = ?', {
                json.encode(items), totalPrecio, shopName
            })
            
            -- 5. Notificar al jugador
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Compra completada',
                description = 'Has comprado ' .. cantidad .. 'x ' .. itemName .. ' por $' .. totalPrecio,
                type = 'success'
            })
            
            -- Obtener emoji para el item
            local emoji = GetItemEmoji(itemName)
            
            -- Notificar a Discord si está configurado
            if SendDiscordWebhook then
                SendDiscordWebhook(
                    "💰 Compra Realizada", 
                    "**Tienda:** " .. shopName .. "\n" ..
                    "**Cliente:** " .. xPlayer.PlayerData.citizenid .. "\n" ..
                    "**Item:** " .. emoji .. " " .. itemName .. "\n" ..
                    "**Cantidad:** " .. cantidad .. "\n" ..
                    "**Precio total:** $" .. totalPrecio,
                    3447003 -- Color azul
                )
            end
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Error',
                description = 'La tienda no existe.',
                type = 'error'
            })
        end
    end)
end)

RegisterNetEvent("tienda:solicitarTiendas", function()
    local src = source
    cargarYEnviarTiendas(src)
end)

RegisterNetEvent("tienda:solicitarTiendasGestion", function()
    local src = source
    oxmysql:execute('SELECT * FROM tiendas', {}, function(result)
        local tiendas = {}
        for _, row in ipairs(result) do
            table.insert(tiendas, {
                name = row.name,
                coords = { x = row.coords_x, y = row.coords_y, z = row.coords_z },
                slots = row.slots,
                items = json.decode(row.items or '{}'),
                balance = row.balance or 0,
                owner = row.owner or nil
            })
        end
        TriggerClientEvent("tienda:abrirMenuGestionTiendas", src, tiendas)
    end)
end)

RegisterNetEvent("tienda:guardarItemsGestion", function(shopName, items)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    
    oxmysql:execute('UPDATE tiendas SET items = ? WHERE name = ?', {
        json.encode(items), shopName
    }, function()
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Gestión de Tienda',
            description = 'Productos actualizados correctamente.',
            type = 'success'
        })
        cargarYEnviarTiendas()
        guardarTiendasEnConfig()
        
        -- Crear campos de items para webhook
        local itemFields = {}
        for _, item in ipairs(items) do
            local emoji = GetItemEmoji(item.name)
            table.insert(itemFields, {
                name = emoji .. " " .. (item.label or item.name),
                value = "Cantidad: " .. item.amount .. " | Precio: $" .. (item.price or 0),
                inline = true
            })
        end
        
        -- Notificar a Discord
        SendDiscordWebhook(
            "⚙️ Productos Gestionados", 
            "**Tienda:** " .. shopName .. "\n" ..
            "**Administrador:** " .. xPlayer.PlayerData.citizenid,
            7419530, -- Color azul oscuro
            itemFields
        )
    end)
end)

-- Registro del evento para eliminar tiendas
RegisterNetEvent("tienda:eliminarTienda", function(shopName)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    
    if not shopName then return end
    
    -- Primero recuperar los datos de la tienda para el webhook
    oxmysql:execute('SELECT * FROM tiendas WHERE name = ?', {shopName}, function(result)
        if result and result[1] then
            local tiendaEliminada = result[1]
            local itemsJson = tiendaEliminada.items or '{}'
            local items = json.decode(itemsJson)
            
            -- Eliminar la tienda de la base de datos
            oxmysql:execute('DELETE FROM tiendas WHERE name = ?', {shopName}, function(deleteResult)
                if deleteResult and deleteResult.affectedRows > 0 then
                    TriggerClientEvent('ox_lib:notify', src, {
                        title = 'Tienda eliminada',
                        description = 'La tienda "' .. shopName .. '" ha sido eliminada.',
                        type = 'success'
                    })
                    cargarYEnviarTiendas()  -- Actualizar tiendas para todos los jugadores
                    guardarTiendasEnConfig() -- Actualizar config.lua
                    
                    -- Notificar a Discord
                    SendDiscordWebhook(
                        "🔥 Tienda Eliminada", 
                        "**Nombre de tienda:** " .. shopName .. "\n" ..
                        "**Eliminada por:** " .. xPlayer.PlayerData.citizenid .. "\n" ..
                        "**Coordenadas:** X: " .. tiendaEliminada.coords_x .. ", Y: " .. tiendaEliminada.coords_y .. ", Z: " .. tiendaEliminada.coords_z .. "\n" ..
                        "**Balance final:** $" .. (tiendaEliminada.balance or 0),
                        15158332 -- Color rojo
                    )
                else
                    TriggerClientEvent('ox_lib:notify', src, {
                        title = 'Error',
                        description = 'No se pudo eliminar la tienda.',
                        type = 'error'
                    })
                end
            end)
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Error',
                description = 'La tienda no existe.',
                type = 'error'
            })
        end
    end)
end)

function cargarYEnviarTiendas(target)
    oxmysql:execute('SELECT * FROM tiendas', {}, function(result)
        local tiendas = {}
        if result and #result > 0 then
            for _, row in ipairs(result) do
                table.insert(tiendas, {
                    name = row.name,
                    coords = { x = row.coords_x, y = row.coords_y, z = row.coords_z },
                    slots = row.slots,
                    items = json.decode(row.items or '{}'),
                    balance = row.balance or 0,
                    owner = row.owner or nil
                })
            end
        else
            -- Si no hay tiendas en la base de datos, intenta cargar desde config.lua
            -- Usamos Config que debe estar definido en config.lua y cargado por FiveM
            if Config and Config.Tiendas then
                tiendas = Config.Tiendas
                print("[DEBUG] Tiendas cargadas desde config.lua")
            end
        end
        if target then
            TriggerClientEvent("tienda:cargarTiendas", target, tiendas)
        else
            TriggerClientEvent("tienda:cargarTiendas", -1, tiendas)
        end
    end)
end

RegisterCommand("pruebaconfig", function(source, args, raw)
    local file, err = io.open("./config.lua", "w+")
    if not file then
        print("[PRUEBA CONFIG] Error al abrir config.lua para escribir: " .. tostring(err))
        return
    end
    file:write("-- Prueba de escritura exitosa\n")
    file:close()
    print("[PRUEBA CONFIG] Escritura en config.lua completada correctamente.")
end, true)
