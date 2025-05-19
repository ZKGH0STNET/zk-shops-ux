-- Implementación única del comando de Boss Menu
local QBCore = exports['qb-core']:GetCoreObject()

-- Registrar comando
RegisterCommand('bosstienda', function(source, args)
    if not args[1] then
        lib.notify({
            title = 'Error',
            description = 'Debes especificar un nombre de tienda',
            type = 'error'
        })
        return
    end
    
    -- Solicitar los datos de la tienda directamente al servidor
    TriggerServerEvent('zk-shops:requestBossMenu', args[1])
end, false)

-- Server response with shop data
RegisterNetEvent('zk-shops:boss_response', function(shop)
    if not shop then
        lib.notify({
            title = 'Error',
            description = 'Tienda no encontrada o no tienes permiso',
            type = 'error'
        })
        return
    end
    
    print('^2[ZK-SHOPS] Abriendo boss menu para: ' .. shop.name .. '^7')
    
    -- Variables necesarias para el boss menu
    CurrentShop = shop
    
    -- Usar la función de OpenShopBossMenu en bossmenu.lua que ya usa ox_lib:context
    OpenShopBossMenu(shop)
end)
