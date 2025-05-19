-- Teleport functionality for zk-shop-ux
local QBCore = exports['qb-core']:GetCoreObject()

-- Función para abrir el menú de teletransporte con lista de tiendas (GLOBAL)
OpenTeleportMenu = function()
    -- Comprobar si hay tiendas disponibles
    if not Shops or #Shops == 0 then
        lib.notify({
            title = 'Error',
            description = 'No hay tiendas disponibles',
            type = 'error'
        })
        return
    end
    
    -- Crear opciones del menú con todas las tiendas
    local options = {}
    
    -- Hacer debug para ver estructura de datos
    print('[ZK-SHOPS] Teleport Menu - Shops data type: ' .. type(Shops))
    print('[ZK-SHOPS] Teleport Menu - Number of shops: ' .. (type(Shops) == 'table' and #Shops or 'not a table'))
    
    -- Agregar directamente todas las tiendas disponibles
    local allShops = {}
    
    -- Si es array
    if type(Shops) == 'table' then
        if #Shops > 0 then  -- Si es array numérico
            for i=1, #Shops do
                if Shops[i] and Shops[i].name then
                    table.insert(allShops, Shops[i])
                    print('[ZK-SHOPS] Teleport Menu - Added shop from array: ' .. Shops[i].name)
                end
            end
        else  -- Si es tabla asociativa
            for name, shop in pairs(Shops) do
                if shop and shop.name then
                    table.insert(allShops, shop)
                    print('[ZK-SHOPS] Teleport Menu - Added shop from table: ' .. shop.name)
                end
            end
        end
    end
    
    -- Debug opcional - listar todas las tiendas encontradas
    print('[ZK-SHOPS] Teleport Menu - Total shops found: ' .. #allShops)
    
    -- Ordenar tiendas por nombre para facilitar la búsqueda
    table.sort(allShops, function(a, b) return a.name < b.name end)
    
    for _, shop in ipairs(allShops) do
        local shopName = shop.name or 'Sin nombre'
        local ownerText = ''
        
        -- Mostrar información del propietario si existe
        if shop.owner and shop.owner ~= '' then
            ownerText = ' | Dueño: ' .. shop.owner
        end
        
        table.insert(options, {
            title = shopName,
            description = ownerText,
            icon = 'fas fa-store',
            onSelect = function()
                -- Teletransportar al jugador a las coordenadas de la tienda
                SetEntityCoords(PlayerPedId(), shop.coords.x, shop.coords.y, shop.coords.z)
                lib.notify({
                    title = 'Teletransporte',
                    description = 'Has sido teletransportado a ' .. shopName,
                    type = 'success'
                })
            end
        })
    end
    
    -- Registrar y mostrar el menú de contexto
    lib.registerContext({
        id = 'teleport_shops_menu',
        title = 'Teletransporte a Tiendas',
        options = options
    })
    
    lib.showContext('teleport_shops_menu')
end
