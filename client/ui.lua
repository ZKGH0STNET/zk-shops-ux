-- UI handling for zk-shop-ux
local QBCore = exports['qb-core']:GetCoreObject()
local ShopOpen = false
local CurrentShop = nil

-- Open shop interface (definida como global para que sea accesible desde otros archivos)
OpenShopInterface = function(shop)
    print('[ZK-SHOPS] Opening shop interface for: ' .. (shop and shop.name or 'unknown'))
    if ShopOpen then return end
    
    CurrentShop = shop
    ShopOpen = true
    
    -- If no items, show error
    if not shop.items or #shop.items == 0 then
        lib.notify({
            title = 'Tienda vacía',
            description = 'Esta tienda no tiene productos disponibles',
            type = 'error'
        })
        ShopOpen = false
        CurrentShop = nil
        return
    end
    
    -- Format items for UI
    local formattedItems = {}
    for _, item in ipairs(shop.items) do
        if item.amount > 0 then
            table.insert(formattedItems, {
                name = item.name,
                label = item.label,
                amount = item.amount,
                price = item.price
            })
        end
    end
    
    -- Obtener dinero del jugador (inicialmente del cache)
    local Player = QBCore.Functions.GetPlayerData()
    local playerMoney = 0
    
    if Player and Player.money then
        playerMoney = Player.money.cash or 0
        print('^3[ZK-SHOPS] Dinero inicial del jugador: $' .. playerMoney .. '^7')
    end
    
    -- IMPORTANTE: Primero abrimos la interfaz inmediatamente con los datos que tenemos
    -- Abrir la interfaz NUI
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        shopName = shop.name,
        items = formattedItems,
        money = playerMoney
    })
    
    -- Disable controls while shop is open
    CreateControlsThread()
    
    -- Luego actualizamos el saldo en segundo plano (esto no bloqueará la apertura de la tienda)
    Citizen.CreateThread(function()
        -- Esperar un breve momento para evitar sobrecarga
        Citizen.Wait(500)
        
        -- Actualizar los datos del jugador para mostrar el saldo más reciente
        QBCore.Functions.TriggerCallback('QBCore:GetPlayerData', function(PlayerData)
            if not ShopOpen then return end -- Si la tienda ya se cerró, no actualizamos
            
            if PlayerData and PlayerData.money then
                local updatedMoney = PlayerData.money.cash or 0
                print('^2[ZK-SHOPS] Actualizando dinero del jugador: $' .. updatedMoney .. '^7')
                
                -- Solo actualizar el dinero en la UI, no reabrir toda la interfaz
                SendNUIMessage({
                    action = 'updateMoney',
                    money = updatedMoney
                })
            end
        end)
    end)
    
    -- SetNuiFocus será llamado por RefreshUI
    -- La UI se actualizará después de obtener el dinero del jugador
    
    -- Disable controls while shop is open
    CreateControlsThread()
end

-- Función auxiliar para actualizar la UI con los datos correctos
function RefreshUI(shopName, items, money)
    -- Enviar datos actualizados a la UI sin abrir de nuevo (solo refrescar)
    SendNUIMessage({
        action = 'refresh',
        shopName = shopName,
        items = items,
        money = money
    })
    
    print('^2[ZK-SHOPS] UI actualizada con dinero: $' .. money .. '^7')
end

-- Refresh shop interface if open
function RefreshShopInterface(shop)
    if not ShopOpen or not CurrentShop or CurrentShop.name ~= shop.name then return end
    
    CurrentShop = shop
    
    -- Format items for UI
    local formattedItems = {}
    for _, item in ipairs(shop.items) do
        if item.amount > 0 then
            table.insert(formattedItems, {
                name = item.name,
                label = item.label,
                amount = item.amount,
                price = item.price
            })
        end
    end
    
    -- Update UI
    SendNUIMessage({
        action = 'update',
        shopName = shop.name,
        items = formattedItems
    })
end

-- Close shop interface
function CloseShopInterface()
    if not ShopOpen then return end
    
    ShopOpen = false
    CurrentShop = nil
    
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'close'
    })
end

-- Create thread to handle controls while shop is open
function CreateControlsThread()
    CreateThread(function()
        while ShopOpen do
            Wait(0)
            
            -- Disable controls
            DisableControlAction(0, 1, true) -- LookLeftRight
            DisableControlAction(0, 2, true) -- LookUpDown
            DisableControlAction(0, 142, true) -- MeleeAttackAlternate
            DisableControlAction(0, 106, true) -- VehicleMouseControlOverride
            
            -- Close on ESC key
            if IsControlJustReleased(0, 177) then -- 177 = ESC
                CloseShopInterface()
            end
        end
    end)
end

-- NUI Callbacks
RegisterNUICallback('closeShop', function(data, cb)
    CloseShopInterface()
    cb({})
end)

RegisterNUICallback('purchaseItem', function(data, cb)
    if not CurrentShop then 
        cb({ success = false, message = 'No shop open' })
        return
    end
    
    local itemName = data.item
    local quantity = data.quantity or 1
    local price = data.price
    
    TriggerServerEvent('zk-shops:buyItem', CurrentShop.name, itemName, quantity, price)
    
    cb({ success = true })
end)

-- Commands and keybinds
RegisterCommand('closeshop', function()
    if ShopOpen then
        CloseShopInterface()
    end
end)

RegisterKeyMapping('closeshop', 'Cerrar tienda abierta', 'keyboard', 'ESCAPE')
