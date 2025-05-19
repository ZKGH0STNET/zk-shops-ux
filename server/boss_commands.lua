-- Implementación única del boss menu (servidor)
local QBCore = exports['qb-core']:GetCoreObject()

-- Evento para manejar la solicitud del boss menu
RegisterNetEvent('zk-shops:boss_request', function(shopName, citizenid)
    local src = source
    if not shopName then return end
    
    print('^3[ZK-SHOPS] Solicitud de boss menu para tienda: ' .. shopName .. '^7')
    
    -- Obtener la tienda directamente de la base de datos
    local result = exports.oxmysql:executeSync('SELECT * FROM shops WHERE name = ?', {shopName})
    if not result or #result == 0 then
        print('^1[ZK-SHOPS] Tienda no encontrada en la base de datos: ' .. shopName .. '^7')
        TriggerClientEvent('zk-shops:boss_response', src, nil)
        return
    end
    
    local shop = result[1]
    
    -- Comprobar si el jugador es dueño o admin
    local hasPermission = false
    
    -- Comprobar si es admin
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if xPlayer then
        for _, group in pairs(Config.AdminGroups) do
            if QBCore.Functions.HasPermission(src, group) then
                hasPermission = true
                print('^2[ZK-SHOPS] Jugador tiene permisos de admin^7')
                break
            end
        end
    end
    
    -- Comprobar si es dueño
    if not hasPermission and citizenid and shop.owner == citizenid then
        hasPermission = true
        print('^2[ZK-SHOPS] Jugador es dueño de la tienda^7')
    end
    
    if not hasPermission then
        print('^1[ZK-SHOPS] Jugador no tiene permisos para la tienda^7')
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'No tienes permiso para gestionar esta tienda',
            type = 'error'
        })
        TriggerClientEvent('zk-shops:boss_response', src, nil)
        return
    end
    
    -- Los items están almacenados como JSON en la tabla principal, no en una tabla separada
    if shop.items and type(shop.items) == 'string' then
        -- Si se almacena como string JSON, intentamos decodificarlo
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
    
    print('^2[ZK-SHOPS] Items de la tienda procesados: ' .. (type(shop.items) == 'table' and #shop.items or 'no es tabla') .. '^7')
    
    -- Enviar los datos de la tienda al cliente
    print('^2[ZK-SHOPS] Enviando datos de tienda para boss menu^7')
    TriggerClientEvent('zk-shops:boss_response', src, shop)
end)

-- Registro al iniciar el recurso
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    print('^2[ZK-SHOPS]^7 Boss menu server inicializado')
end)
