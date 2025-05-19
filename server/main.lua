-- Main server file for zk-shop-ux
local QBCore = exports['qb-core']:GetCoreObject()
local Shops = {}
local ShopsLoaded = false

-- Initialize the resource
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    print('^2[ZK-SHOPS]^7 Initializing...')
    InitializeDatabase()
end)

-- Load shops from database and keep in memory
function LoadShops()
    local success, shops = pcall(GetAllShops)
    
    if success and shops then
        Shops = shops
        ShopsLoaded = true
        print('^2[ZK-SHOPS]^7 Loaded ' .. #Shops .. ' shops from database')
        return true
    else
        print('^1[ZK-SHOPS]^7 Failed to load shops: ' .. tostring(shops))
        return false
    end
end

-- Get a specific shop by name
function GetShop(shopName)
    if not ShopsLoaded then
        LoadShops()
    end
    
    for _, shop in ipairs(Shops) do
        if shop.name == shopName then
            return shop
        end
    end
    
    return nil
end

-- Broadcast shop data to all clients or a specific client
function BroadcastShops(target)
    if not ShopsLoaded then
        LoadShops()
    end
    
    if target then
        TriggerClientEvent('zk-shops:syncShops', target, Shops)
    else
        TriggerClientEvent('zk-shops:syncShops', -1, Shops)
    end
end

-- Export to get shop data
function getShopData(shopName)
    return GetShop(shopName)
end

-- Export to check if shops are loaded
function getShopsLoaded()
    return ShopsLoaded
end

-- Export to load shops
function loadShops()
    LoadShops()
    return true
end

-- Export to create a shop
function createShop(data)
    if not data or not data.name then return false, 'Invalid shop data' end
    
    local success, result = pcall(InsertShop, data)
    if success and result then
        LoadShops() -- Reload shops from database
        BroadcastShops() -- Update all clients
        return true, 'Shop created successfully'
    else
        return false, 'Failed to create shop: ' .. tostring(result)
    end
end

-- Export to delete a shop
function deleteShop(shopName)
    if not shopName then return false, 'No shop name provided' end
    
    -- Send zone cleanup event to all clients BEFORE deleting from database
    TriggerClientEvent('zk-shops:cleanupShopZone', -1, shopName)
    Wait(200) -- Give clients time to clean up zones
    
    local success, result = pcall(DeleteShop, shopName)
    if success and result then
        LoadShops() -- Reload shops from database
        BroadcastShops() -- Update all clients
        
        -- Additional zone cleanup after deletion to ensure no orphaned zones remain
        TriggerClientEvent('zk-shops:forceZoneCleanup', -1)
        return true, 'Shop deleted successfully'
    else
        return false, 'Failed to delete shop: ' .. tostring(result)
    end
end

-- Export to update shop items
function updateShopItems(shopName, items)
    if not shopName or not items then return false, 'Invalid parameters' end
    
    local success, result = pcall(UpdateShopItems, shopName, items)
    if success and result then
        LoadShops() -- Reload shops from database
        BroadcastShops() -- Update all clients
        return true, 'Shop items updated successfully'
    else
        return false, 'Failed to update shop items: ' .. tostring(result)
    end
end

-- Event handler for client requesting all shops
RegisterNetEvent('zk-shops:requestShops', function()
    local src = source
    BroadcastShops(src)
end)

-- Event handler for creating a shop
RegisterNetEvent('zk-shops:createShop', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Check if player has permission
    if not IsPlayerAdmin(src) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'No tienes permiso para crear tiendas',
            type = 'error'
        })
        return
    end
    
    -- Add owner info
    data.owner = Player.PlayerData.citizenid
    
    local success, message = createShop(data)
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = success and 'Éxito' or 'Error',
        description = message,
        type = success and 'success' or 'error'
    })
    
    if success then
        LogShopCreation(data.name, data.owner, data.slots or Config.DefaultSlots, data.coords, data.items or {})
    end
end)

-- Event handler for deleting a shop
RegisterNetEvent('zk-shops:deleteShop', function(shopName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Check if player has permission (admin or shop owner)
    local shop = GetShop(shopName)
    if not shop then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'La tienda no existe',
            type = 'error'
        })
        return
    end
    
    if not IsPlayerAdmin(src) and shop.owner ~= Player.PlayerData.citizenid then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'No eres el dueño de esta tienda',
            type = 'error'
        })
        return
    end
    
    -- Log before deletion
    LogShopDeletion(shopName, Player.PlayerData.citizenid, shop.coords, shop.balance or 0)
    
    local success, message = deleteShop(shopName)
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = success and 'Éxito' or 'Error',
        description = message,
        type = success and 'success' or 'error'
    })
end)

-- Event handler for updating shop items
RegisterNetEvent('zk-shops:updateShopItems', function(shopName, items)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Check if player has permission (admin or shop owner)
    local shop = GetShop(shopName)
    if not shop then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'La tienda no existe',
            type = 'error'
        })
        return
    end
    
    if not IsPlayerAdmin(src) and shop.owner ~= Player.PlayerData.citizenid then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'No eres el dueño de esta tienda',
            type = 'error'
        })
        return
    end
    
    local success, message = updateShopItems(shopName, items)
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = success and 'Éxito' or 'Error',
        description = message,
        type = success and 'success' or 'error'
    })
    
    if success then
        LogShopItemsUpdate(shopName, Player.PlayerData.citizenid, items)
    end
end)

-- Event handler for opening a shop
RegisterNetEvent('zk-shops:openShop', function(shopName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not shopName then return end
    
    local shop = GetShop(shopName)
    if not shop then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'La tienda no existe',
            type = 'error'
        })
        return
    end
    
    TriggerClientEvent('zk-shops:openShopMenu', src, shop)
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Tienda',
        description = 'Abriendo ' .. shop.name,
        type = 'success'
    })
end)

-- Event handler for buying an item
RegisterNetEvent('zk-shops:buyItem', function(shopName, itemName, amount, price)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not shopName or not itemName then return end
    
    -- Validate inputs
    amount = tonumber(amount) or 1
    if amount <= 0 then amount = 1 end
    
    -- Get shop data
    local shop = GetShop(shopName)
    if not shop then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'La tienda no existe',
            type = 'error'
        })
        return
    end
    
    -- Find the item
    local foundItem = nil
    for _, item in ipairs(shop.items or {}) do
        if item.name == itemName then
            foundItem = item
            break
        end
    end
    
    if not foundItem then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'El item no existe en esta tienda',
            type = 'error'
        })
        return
    end
    
    -- Check stock
    if foundItem.amount < amount then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'No hay suficiente stock. Disponible: ' .. foundItem.amount,
            type = 'error'
        })
        return
    end
    
    -- Calculate total price
    local totalPrice = (foundItem.price or price) * amount
    
    -- Check if player has enough money
    if Player.PlayerData.money.cash < totalPrice then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'No tienes suficiente dinero. Necesitas $' .. totalPrice,
            type = 'error'
        })
        return
    end
    
    -- Process the purchase
    Player.Functions.RemoveMoney('cash', totalPrice)
    Player.Functions.AddItem(itemName, amount)
    
    -- Update shop stock and balance
    foundItem.amount = foundItem.amount - amount
    shop.balance = (shop.balance or 0) + totalPrice
    
    -- Update the database
    UpdateShopItems(shopName, shop.items)
    UpdateShopBalance(shopName, totalPrice) -- Usamos el monto de la compra directamente
    
    -- Registrar la venta en el historial de ventas
    if foundItem.label then
        -- Si el item tiene una etiqueta descriptiva, la usamos
        RecordSale(shopName, foundItem.label, amount, totalPrice)
    else
        -- Si no, usamos el nombre del item
        RecordSale(shopName, itemName, amount, totalPrice)
    end
    
    -- Log the purchase
    LogShopPurchase(shopName, Player.PlayerData.citizenid, itemName, amount, totalPrice)
    
    -- Notify the player
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Compra exitosa',
        description = 'Has comprado ' .. amount .. 'x ' .. itemName .. ' por $' .. totalPrice,
        type = 'success'
    })
    
    -- Refresh shop data for player
    TriggerClientEvent('zk-shops:updateShopData', src, shop)
    
    -- Reload shops for all clients
    LoadShops()
    BroadcastShops()
end)

-- Check if player is admin
function IsPlayerAdmin(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    
    for _, group in ipairs(Config.AdminGroups) do
        if QBCore.Functions.HasPermission(src, group) then
            return true
        end
    end
    
    return false
end

-- Nuevo evento para verificar permisos de administrador desde el cliente
RegisterNetEvent('zk-shops:checkAdminPermission', function(action)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Comprobar si el jugador es administrador
    local hasPermission = IsPlayerAdmin(src)
    
    -- Mostrar mensajes de debug
    print('^3[ZK-SHOPS] Verificando permisos para ' .. GetPlayerName(src) .. ' (ID:' .. src .. '), Acción: ' .. action .. ', Es admin: ' .. tostring(hasPermission) .. '^7')
    
    if hasPermission then
        if action == 'create' then
            -- Iniciar creación de tienda
            TriggerClientEvent('zk-shops:startShopCreation', src)
        elseif action == 'manage' then
            -- Abrir menú de gestión de tiendas
            TriggerClientEvent('zk-shops:openShopManagementMenu', src)
        end
    else
        -- Notificar que no tiene permisos
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Sin permiso',
            description = 'No tienes permiso para realizar esta acción',
            type = 'error'
        })
        
        -- Verificar si es dueño de alguna tienda para boss menu
        if action == 'manage' then
            for _, shop in pairs(Shops) do
                if shop.owner == Player.PlayerData.citizenid then
                    TriggerClientEvent('zk-shops:openShopManagementMenu', src)
                    return
                end
            end
        end
    end
end)

-- Initialize the module
CreateThread(function()
    Wait(1000) -- Wait for MySQL to be ready
    InitializeDatabase()
    Wait(500)
    LoadShops()
end)
