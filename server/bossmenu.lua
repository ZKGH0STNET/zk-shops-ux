-- Boss menu functionality for zk-shop-ux
local QBCore = exports['qb-core']:GetCoreObject()

-- Sales history table (in-memory storage)
local SalesHistory = {}

-- Evento para solicitar el boss menu directamente
RegisterNetEvent('zk-shops:requestBossMenu', function(shopName)
    local src = source
    if not shopName then return end
    
    print('^3[ZK-SHOPS] Solicitando boss menu para tienda: ' .. shopName .. '^7')
    
    -- Obtener los datos de la tienda directamente
    local shopData = exports.oxmysql:executeSync('SELECT * FROM shops WHERE name = ?', {shopName})
    
    if not shopData or #shopData == 0 then
        lib.notify(src, {
            title = 'Error',
            description = 'Tienda no encontrada: ' .. shopName,
            type = 'error'
        })
        return
    end
    
    -- Enviar la tienda al cliente para abrir el menu
    local shop = shopData[1]
    TriggerClientEvent('zk-shops:openBossMenu', src, shop)
end)

-- Initialize boss menu variables
local ShopsLoaded = nil

-- Referencia a las funciones de main.lua
local function GetShopsLoaded()
    return ShopsLoaded or exports['zk-shop-ux']:getShopsLoaded()
end

-- Importación de la función LoadShops desde main.lua
local LoadShopsFromMain = nil

AddEventHandler('onServerResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Esperar un momento para asegurarnos de que main.lua ya se cargó
        Citizen.Wait(500)
        -- Obtener la referencia a la función LoadShops de main.lua
        LoadShopsFromMain = _G.LoadShops
        print('^3[ZK-SHOPS] Referencia a función LoadShops obtenida: ' .. tostring(LoadShopsFromMain ~= nil) .. '^7')
    end
end)

local function LoadShops()
    if LoadShopsFromMain then
        -- Usar la función de main.lua si está disponible
        LoadShopsFromMain()
    else
        -- Fallback: Cargar tiendas directamente desde la base de datos
        local shops = exports.oxmysql:executeSync('SELECT * FROM shops')
        if shops then
            -- Actualizar la lista de tiendas en main.lua usando _G
            if _G.Shops then
                _G.Shops = shops
                _G.ShopsLoaded = true
                print('^2[ZK-SHOPS] Tiendas recargadas desde bossmenu (' .. #shops .. ' tiendas)^7')
                
                -- Transmitir las tiendas a todos los clientes
                TriggerClientEvent('zk-shops:syncShops', -1, shops)
            else
                print('^1[ZK-SHOPS] Error: No se puede acceder a la variable global Shops^7')
            end
        else
            print('^1[ZK-SHOPS] Error al cargar tiendas desde la base de datos^7')
        end
    end
end

local function GetShop(shopName)
    return exports['zk-shop-ux']:getShopData(shopName)
end

-- Get shop data for boss menu
RegisterNetEvent('zk-shops:getBossMenuData', function(shopName)
    local src = source
    if not shopName then 
        print('^1[ZK-SHOPS] Error: No shop name provided for getBossMenuData^7')
        return 
    end
    
    print('^3[ZK-SHOPS] Getting boss menu data for shop: ' .. shopName .. '^7')
    
    -- Obtenemos los datos de la tienda directamente de la base de datos usando la tabla correcta
    local shopData = exports.oxmysql:executeSync('SELECT * FROM shops WHERE name = ?', {shopName})
    
    if not shopData or #shopData == 0 then
        print('^1[ZK-SHOPS] Shop not found in database: ' .. shopName .. '^7')
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'Tienda no encontrada en la base de datos',
            type = 'error'
        })
        return
    end
    
    -- Construimos el objeto de tienda manualmente
    local shop = shopData[1]
    print('^2[ZK-SHOPS] Shop found in database: ' .. shop.name .. '^7')
    
    -- Los items están almacenados como JSON en la tabla principal, no en una tabla separada
    if shop.items then
        if type(shop.items) == 'string' then
            -- Si está almacenado como string JSON, intentamos decodificarlo
            local success, items = pcall(json.decode, shop.items)
            if success and items then
                shop.items = items
            else
                -- Si falla el decode, inicializamos como array vacío
                print('^1[ZK-SHOPS] Error al decodificar items de la tienda^7')
                shop.items = {}
            end
        elseif not shop.items then
            -- Si no hay items, inicializamos como array vacío
            shop.items = {}
        end
    else
        shop.items = {}
    end
    
    print('^2[ZK-SHOPS] Items de la tienda procesados correctamente^7')
    
    if not shop then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'Tienda no encontrada',
            type = 'error'
        })
        return
    end
    
    -- Check if player owns this shop
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or (Player.PlayerData.citizenid ~= shop.owner and not IsPlayerAdmin(src)) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'No eres el dueño de esta tienda',
            type = 'error'
        })
        return
    end
    
    -- Get sales history for this shop
    local history = SalesHistory[shopName] or {}
    
    -- Send data to client
    TriggerClientEvent('zk-shops:receiveBossMenuData', src, shop, history)
end)

-- Record a sale in the history
function RecordSale(shopName, itemName, quantity, price)
    if not shopName or not itemName then return end
    
    -- Initialize history for this shop if it doesn't exist
    if not SalesHistory[shopName] then
        SalesHistory[shopName] = {}
    end
    
    -- Add sale record
    table.insert(SalesHistory[shopName], {
        item = itemName,
        quantity = quantity,
        price = price,
        date = os.date('%Y-%m-%d %H:%M:%S')
    })
    
    -- Limit history to 50 entries per shop
    if #SalesHistory[shopName] > 50 then
        table.remove(SalesHistory[shopName], 1)
    end
end

-- Manejar las acciones del boss menu
RegisterNetEvent('zk-shops:bossmenu_action', function(data)
    local src = source
    
    if not data or not data.action then
        print('^1[ZK-SHOPS] Error: datos inválidos recibidos en bossmenu_action^7')
        return
    end
    
    -- El nombre de la tienda debe estar presente en todas las acciones
    if not data.shopName then
        print('^1[ZK-SHOPS] Error: falta el nombre de la tienda en bossmenu_action^7')
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'Datos incompletos',
            type = 'error'
        })
        return
    end
    
    print('^3[ZK-SHOPS] Procesando acción de boss menu: ' .. data.action .. ' para tienda: ' .. data.shopName .. '^7')
    
    -- Verificar si la tienda existe
    local shop = exports.oxmysql:executeSync('SELECT * FROM shops WHERE name = ?', {data.shopName})
    
    if not shop or #shop == 0 then
        print('^1[ZK-SHOPS] Error: tienda no encontrada en la base de datos: ' .. data.shopName .. '^7')
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'Tienda no encontrada',
            type = 'error'
        })
        return
    end
    
    shop = shop[1]
    
    -- Procesar los items si es necesario
    if shop.items and type(shop.items) == 'string' then
        local success, items = pcall(json.decode, shop.items)
        if success and items then
            shop.items = items
        else
            print('^1[ZK-SHOPS] Error al decodificar items de la tienda^7')
            shop.items = {}
        end
    elseif not shop.items then
        shop.items = {}
    end
    
    -- Verificar si el jugador tiene permisos para esta tienda
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or (Player.PlayerData.citizenid ~= shop.owner and not IsPlayerAdmin(src)) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'No tienes permisos para esta acción',
            type = 'error'
        })
        return
    end
    
    -- Manejar diferentes tipos de acciones
    if data.action == 'update_item' then
        -- Actualizar cantidad de un item
        if not data.itemIndex or not data.newQuantity then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Error',
                description = 'Datos inválidos para actualizar item',
                type = 'error'
            })
            return
        end
        
        local itemIndex = tonumber(data.itemIndex)
        local newQuantity = tonumber(data.newQuantity)
        
        if not itemIndex or not newQuantity or itemIndex < 0 or newQuantity < 0 then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Error',
                description = 'Valores inválidos',
                type = 'error'
            })
            return
        end
        
        -- Verificar que el índice sea válido
        if not shop.items[itemIndex + 1] then -- +1 porque Lua usa índices desde 1 pero JS usa desde 0
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Error',
                description = 'Item no encontrado',
                type = 'error'
            })
            return
        end
        
        -- Actualizar la cantidad
        shop.items[itemIndex + 1].quantity = newQuantity
        
        -- Guardar en la base de datos
        local success = SaveShopItems(data.shopName, shop.items)
        
        if success then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Éxito',
                description = 'Cantidad actualizada correctamente',
                type = 'success'
            })
            
            -- Actualizar los datos en el cliente
            TriggerClientEvent('zk-shops:receiveBossMenuData', src, shop, SalesHistory[data.shopName] or {})
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Error',
                description = 'Error al guardar cambios',
                type = 'error'
            })
        end
    else
        print('^1[ZK-SHOPS] Acción de boss menu no implementada: ' .. data.action .. '^7')
    end
end)

-- Guardar los items de una tienda en la base de datos
function SaveShopItems(shopName, items)
    if not shopName or not items then 
        print('^1[ZK-SHOPS] Error: datos inválidos para guardar items^7')
        return false 
    end
    
    -- Convertir la tabla de items a JSON
    local itemsJson = json.encode(items)
    
    -- Actualizar en la base de datos
    local result = exports.oxmysql:executeSync('UPDATE shops SET items = ? WHERE name = ?', {itemsJson, shopName})
    
    if result and result.affectedRows and result.affectedRows > 0 then
        print('^2[ZK-SHOPS] Items actualizados correctamente para la tienda: ' .. shopName .. '^7')
        return true
    else
        print('^1[ZK-SHOPS] Error al actualizar items para la tienda: ' .. shopName .. '^7')
        return false
    end
end

-- Withdraw money from shop
RegisterNetEvent('zk-shops:withdrawMoney', function(shopName, amount)
    local src = source
    if not shopName or not amount then return end
    
    amount = tonumber(amount)
    if not amount or amount <= 0 then
        TriggerClientEvent('zk-shops:updateBossMenu', src, false, 'Cantidad inválida', 'error')
        return
    end
    
    local shop = GetShop(shopName)
    if not shop then
        TriggerClientEvent('zk-shops:updateBossMenu', src, false, 'Tienda no encontrada', 'error')
        return
    end
    
    -- Check if player owns this shop
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    if not IsPlayerAdmin(src) and shop.owner ~= Player.PlayerData.citizenid then
        TriggerClientEvent('zk-shops:updateBossMenu', src, false, 'No eres el dueño de esta tienda', 'error')
        return
    end
    
    -- Check if shop has enough money
    if shop.balance < amount then
        TriggerClientEvent('zk-shops:updateBossMenu', src, false, 'No hay suficiente dinero en la tienda', 'error')
        return
    end
    
    -- Calcular el nuevo balance
    local newBalance = shop.balance - amount
    print('^3[ZK-SHOPS] Retirando $' .. amount .. ' - Balance actual: $' .. shop.balance .. ' - Nuevo balance: $' .. newBalance .. '^7')
    
    -- Consulta directa para actualizar el balance
    local result = exports.oxmysql:executeSync('UPDATE shops SET balance = ? WHERE name = ?', {
        newBalance,
        shopName
    })
    
    if result and result.affectedRows and result.affectedRows > 0 then
        -- Give money to player
        Player.Functions.AddMoney('cash', amount)
        
        -- Log transaction to server console
        print('^2[ZK-SHOPS] Transacción: ^7' .. Player.PlayerData.citizenid .. ' retiró $' .. amount .. ' de ' .. shopName)
        
        -- Log transaction to Discord directamente al webhook
        local webhook = "https://discord.com/api/webhooks/1373397020328460288/IP4vjaDUDoaLEy9U9RyHP8BjyEdK0QNFL4YfphdJL6RxtUkW1OlfVuydMQc_gN460GBc"
        
        -- Formatear para Discord
        local embeds = {
            {
                ["title"] = '💸 Retiro de Fondos',
                ["description"] = "**Tienda:** " .. shopName .. "\n" ..
                               "**Jugador:** " .. Player.PlayerData.citizenid .. "\n" ..
                               "**Cantidad:** $" .. amount .. "\n" ..
                               "**Acción:** Retiró dinero de la tienda",
                ["color"] = 15158332, -- Rojo para retiros
                ["footer"] = { ["text"] = "ZK-Shops | " .. os.date("%d/%m/%Y %H:%M:%S") }
            }
        }
        
        -- Enviar al webhook
        PerformHttpRequest(webhook, function(err, text, headers) end, 'POST',
            json.encode({ username = "ZK-Shops - Boss Menu", embeds = embeds }),
            { ['Content-Type'] = 'application/json' }
        )
        
        -- Notify player
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Éxito',
            description = 'Has retirado $' .. amount .. ' de la tienda',
            type = 'success'
        })
        
        -- Update boss menu
        TriggerClientEvent('zk-shops:updateBossMenu', src, true, 'Retiraste $' .. amount .. ' exitosamente', 'success')
    else
        print('^1[ZK-SHOPS] Error al actualizar el balance de la tienda: ' .. shopName .. '^7')
        TriggerClientEvent('zk-shops:updateBossMenu', src, false, 'Error al procesar el retiro', 'error')
    end
    
    -- Update all bossmenu instances that are open
    TriggerEvent('zk-shops:updateAllBossMenus')
end)

-- Deposit money to shop
RegisterNetEvent('zk-shops:depositMoney', function(shopName, amount)
    local src = source
    if not shopName or not amount then return end
    
    amount = tonumber(amount)
    if not amount or amount <= 0 then
        TriggerClientEvent('zk-shops:updateBossMenu', src, false, 'Cantidad inválida', 'error')
        return
    end
    
    local shop = GetShop(shopName)
    if not shop then
        TriggerClientEvent('zk-shops:updateBossMenu', src, false, 'Tienda no encontrada', 'error')
        return
    end
    
    -- Check if player owns this shop
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    if not IsPlayerAdmin(src) and shop.owner ~= Player.PlayerData.citizenid then
        TriggerClientEvent('zk-shops:updateBossMenu', src, false, 'No eres el dueño de esta tienda', 'error')
        return
    end
    
    -- Check if player has enough money
    if Player.PlayerData.money.cash < amount then
        TriggerClientEvent('zk-shops:updateBossMenu', src, false, 'No tienes suficiente dinero', 'error')
        return
    end
    
    -- Calcular el nuevo balance
    local newBalance = shop.balance + amount
    print('^3[ZK-SHOPS] Depositando $' .. amount .. ' - Balance actual: $' .. shop.balance .. ' - Nuevo balance: $' .. newBalance .. '^7')
    
    -- Remove money from player
    Player.Functions.RemoveMoney('cash', amount)
    
    -- Consulta directa para actualizar el balance
    local result = exports.oxmysql:executeSync('UPDATE shops SET balance = ? WHERE name = ?', {
        newBalance,
        shopName
    })
    
    if result and result.affectedRows and result.affectedRows > 0 then
        -- Log transaction to server console
        print('^2[ZK-SHOPS] Transacción: ^7' .. Player.PlayerData.citizenid .. ' depositó $' .. amount .. ' en ' .. shopName)
        
        -- Log transaction to Discord directamente al webhook
        local webhook = "https://discord.com/api/webhooks/1373397020328460288/IP4vjaDUDoaLEy9U9RyHP8BjyEdK0QNFL4YfphdJL6RxtUkW1OlfVuydMQc_gN460GBc"
        
        -- Formatear para Discord
        local embeds = {
            {
                ["title"] = '💰 Depósito de Fondos',
                ["description"] = "**Tienda:** " .. shopName .. "\n" ..
                               "**Jugador:** " .. Player.PlayerData.citizenid .. "\n" ..
                               "**Cantidad:** $" .. amount .. "\n" ..
                               "**Acción:** Depositó dinero en la tienda",
                ["color"] = 3066993, -- Verde para depósitos
                ["footer"] = { ["text"] = "ZK-Shops | " .. os.date("%d/%m/%Y %H:%M:%S") }
            }
        }
        
        -- Enviar al webhook
        PerformHttpRequest(webhook, function(err, text, headers) end, 'POST',
            json.encode({ username = "ZK-Shops - Boss Menu", embeds = embeds }),
            { ['Content-Type'] = 'application/json' }
        )
        
        -- Notify player
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Éxito',
            description = 'Has depositado $' .. amount .. ' en la tienda',
            type = 'success'
        })
        
        -- Update boss menu
        TriggerClientEvent('zk-shops:updateBossMenu', src, true, 'Depositaste $' .. amount .. ' exitosamente', 'success')
    else
        -- Refund player if shop update fails
        Player.Functions.AddMoney('cash', amount)
        print('^1[ZK-SHOPS] Error al actualizar el balance de la tienda: ' .. shopName .. '^7')
        TriggerClientEvent('zk-shops:updateBossMenu', src, false, 'Error al procesar el depósito', 'error')
    end
    
    -- Update all bossmenu instances that are open
    TriggerEvent('zk-shops:updateAllBossMenus')
end)

-- Transfer shop ownership
RegisterNetEvent('zk-shops:transferOwnership', function(shopName, targetId)
    local src = source
    if not shopName or not targetId then return end
    
    local shop = GetShop(shopName)
    if not shop then
        TriggerClientEvent('zk-shops:updateBossMenu', src, false, 'Tienda no encontrada', 'error')
        return
    end
    
    -- Check if player owns this shop
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or (Player.PlayerData.citizenid ~= shop.owner and not IsPlayerAdmin(src)) then
        TriggerClientEvent('zk-shops:updateBossMenu', src, false, 'No eres el dueño de esta tienda', 'error')
        return
    end
    
    -- Get target player
    local targetPlayer = QBCore.Functions.GetPlayer(tonumber(targetId))
    if not targetPlayer then
        TriggerClientEvent('zk-shops:updateBossMenu', src, false, 'Jugador no encontrado', 'error')
        return
    end
    
    -- Update shop owner
    local success, message = UpdateShopOwner(shopName, targetPlayer.PlayerData.citizenid)
    if not success then
        TriggerClientEvent('zk-shops:updateBossMenu', src, false, message, 'error')
        return
    end
    
    -- Log ownership transfer directamente al webhook
    local webhook = "https://discord.com/api/webhooks/1373397020328460288/IP4vjaDUDoaLEy9U9RyHP8BjyEdK0QNFL4YfphdJL6RxtUkW1OlfVuydMQc_gN460GBc"
    
    -- Formatear para Discord
    local embeds = {
        {
            ["title"] = '👑 Transferencia de Propiedad',
            ["description"] = "**Tienda:** " .. shopName .. "\n" ..
                          "**Propietario Anterior:** " .. Player.PlayerData.citizenid .. "\n" ..
                          "**Nuevo Propietario:** " .. targetPlayer.PlayerData.citizenid,
            ["color"] = 11027200, -- Púrpura para transferencias
            ["footer"] = { ["text"] = "ZK-Shops | " .. os.date("%d/%m/%Y %H:%M:%S") }
        }
    }
    
    -- Enviar al webhook
    PerformHttpRequest(webhook, function(err, text, headers) end, 'POST',
        json.encode({ username = "ZK-Shops - Boss Menu", embeds = embeds }),
        { ['Content-Type'] = 'application/json' }
    )
    
    -- Send success messages
    TriggerClientEvent('zk-shops:updateBossMenu', src, true, 'Has transferido la tienda a ' .. targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname, 'success')
    
    -- Notify new owner
    TriggerClientEvent('ox_lib:notify', targetPlayer.PlayerData.source, {
        title = '¡Nueva Propiedad!',
        description = 'Has recibido la propiedad de la tienda ' .. shopName,
        type = 'success'
    })
    
    -- Close boss menu and refresh shops for all players
    TriggerClientEvent('zk-shops:closeBossMenu', src)
    BroadcastShops()
end)

-- Update shop balance
function UpdateShopBalance(shopName, amount)
    if not shopName or not amount then 
        print('^1[ZK-SHOPS] UpdateShopBalance: Datos inválidos^7')
        return false, 'Datos inválidos' 
    end
    
    -- Obtener los datos de la tienda directamente de la base de datos
    local shopData = exports.oxmysql:executeSync('SELECT * FROM shops WHERE name = ?', {shopName})
    
    if not shopData or #shopData == 0 then
        print('^1[ZK-SHOPS] UpdateShopBalance: Tienda no encontrada: ' .. shopName .. '^7')
        return false, 'Tienda no encontrada'
    end
    
    local shop = shopData[1]
    
    -- Calcular el nuevo balance - amount puede ser positivo (deposito) o negativo (retiro)
    local currentBalance = tonumber(shop.balance) or 0
    local newBalance = currentBalance + tonumber(amount)
    
    -- Verificar que el balance no sea negativo
    if newBalance < 0 then 
        print('^1[ZK-SHOPS] UpdateShopBalance: Fondos insuficientes ' .. shopName .. ' - Balance: ' .. currentBalance .. ', Intento de retiro: ' .. math.abs(amount) .. '^7')
        return false, 'Fondos insuficientes' 
    end
    
    -- Actualizar el balance en la base de datos directamente
    print('^3[ZK-SHOPS] UpdateShopBalance: Actualizando balance de ' .. shopName .. ' de $' .. currentBalance .. ' a $' .. newBalance .. '^7')
    
    local result = exports.oxmysql:executeSync('UPDATE shops SET balance = ? WHERE name = ?', {
        newBalance, 
        shopName
    })
    
    if result and result.affectedRows and result.affectedRows > 0 then
        print('^2[ZK-SHOPS] UpdateShopBalance: Balance actualizado con éxito para ' .. shopName .. '^7')
        return true, 'Balance actualizado'
    else
        print('^1[ZK-SHOPS] UpdateShopBalance: Error al actualizar balance para ' .. shopName .. '^7')
        return false, 'Error al actualizar la base de datos'
    end
end

-- Update shop owner
function UpdateShopOwner(shopName, newOwner)
    if not shopName or not newOwner then 
        print('^1[ZK-SHOPS] UpdateShopOwner: Datos inválidos^7')
        return false, 'Datos inválidos' 
    end
    
    -- Obtener los datos de la tienda directamente de la base de datos
    local shopData = exports.oxmysql:executeSync('SELECT * FROM shops WHERE name = ?', {shopName})
    
    if not shopData or #shopData == 0 then
        print('^1[ZK-SHOPS] UpdateShopOwner: Tienda no encontrada: ' .. shopName .. '^7')
        return false, 'Tienda no encontrada'
    end
    
    -- Actualizar el dueño en la base de datos directamente
    print('^3[ZK-SHOPS] UpdateShopOwner: Actualizando dueño de ' .. shopName .. ' a ' .. newOwner .. '^7')
    
    local result = exports.oxmysql:executeSync('UPDATE shops SET owner = ? WHERE name = ?', {
        newOwner, 
        shopName
    })
    
    if result and result.affectedRows and result.affectedRows > 0 then
        print('^2[ZK-SHOPS] UpdateShopOwner: Dueño actualizado con éxito para ' .. shopName .. '^7')
        
        -- Actualizar la memoria global a través de la función loadShops
        LoadShops()
        
        return true, 'Dueño actualizado'
    else
        print('^1[ZK-SHOPS] UpdateShopOwner: Error al actualizar dueño para ' .. shopName .. '^7')
        return false, 'Error al actualizar la base de datos'
    end
end

-- Evento para transferir la propiedad de una tienda a otro jugador
RegisterNetEvent('zk-shops:transferOwnership', function(shopName, targetId)
    local src = source
    if not shopName or not targetId then return end
    
    print('^3[ZK-SHOPS] Intento de transferencia de tienda ' .. shopName .. ' al jugador ID: ' .. targetId .. '^7')
    
    -- Verificar si la tienda existe
    local shopData = exports.oxmysql:executeSync('SELECT * FROM shops WHERE name = ?', {shopName})
    
    if not shopData or #shopData == 0 then
        TriggerClientEvent('zk-shops:updateBossMenu', src, false, 'Tienda no encontrada', 'error')
        return
    end
    
    local shop = shopData[1]
    
    -- Verificar si el jugador origen es el dueño
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or (Player.PlayerData.citizenid ~= shop.owner and not IsPlayerAdmin(src)) then
        TriggerClientEvent('zk-shops:updateBossMenu', src, false, 'No eres el dueño de esta tienda', 'error')
        return
    end
    
    -- Verificar si el jugador destino existe
    local targetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not targetPlayer then
        TriggerClientEvent('zk-shops:updateBossMenu', src, false, 'Jugador destino no encontrado', 'error')
        return
    end
    
    -- Actualizar el dueño
    local success, message = UpdateShopOwner(shopName, targetPlayer.PlayerData.citizenid)
    
    if not success then
        TriggerClientEvent('zk-shops:updateBossMenu', src, false, message or 'Error al transferir la tienda', 'error')
        return
    end
    
    -- Registrar la transferencia en el webhook si está configurado
    local webhookUrl = Config and Config.WebhookURL
    if webhookUrl then
        local embeds = {
            {
                title = "Transferencia de Tienda",
                description = "Se ha transferido la propiedad de una tienda",
                color = 65280, -- Verde
                fields = {
                    {name = "Tienda", value = shopName, inline = true},
                    {name = "Dueño Anterior", value = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname, inline = true},
                    {name = "Nuevo Dueño", value = targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname, inline = true}
                },
                footer = {text = "ZK-Shops | " .. os.date("%Y-%m-%d %H:%M:%S")}
            }
        }
        
        PerformHttpRequest(
            webhookUrl,
            function(err, text, headers) end,
            'POST',
            json.encode({ username = "ZK-Shops - Boss Menu", embeds = embeds }),
            { ['Content-Type'] = 'application/json' }
        )
    end
    
    -- Enviar mensajes de éxito
    TriggerClientEvent('zk-shops:updateBossMenu', src, true, 'Has transferido la tienda a ' .. targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname, 'success')
    
    -- Notificar al nuevo dueño
    TriggerClientEvent('ox_lib:notify', targetPlayer.PlayerData.source, {
        title = '¡Nueva Propiedad!',
        description = 'Has recibido la propiedad de la tienda ' .. shopName,
        type = 'success'
    })
    
    -- Cerrar el menú de jefe y actualizar las tiendas para todos los jugadores
    TriggerClientEvent('zk-shops:closeBossMenu', src)
    
    -- Refrescar las tiendas para todos, si la función existe
    if BroadcastShops then
        BroadcastShops()
    else
        LoadShops()
    end
end)

-- Esta función ya no es necesaria, ahora enviamos los logs directamente en cada función
