-- Script de comprobación y corrección de base de datos
local QBCore = exports['qb-core']:GetCoreObject()

-- Verificar la base de datos al iniciar el recurso
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    print('^2[ZK-SHOPS]^7 Verificando estado de la base de datos...')
    
    Citizen.Wait(1000) -- Esperar a que oxmysql esté listo
    
    -- Primero verificamos que exista la tabla shops
    local tableExists = exports.oxmysql:executeSync("SHOW TABLES LIKE 'shops'")
    
    if not tableExists or #tableExists == 0 then
        print('^1[ZK-SHOPS] TABLA SHOPS NO ENCONTRADA! Creando tabla...^7')
        
        -- Crear la tabla shops si no existe
        local success = exports.oxmysql:executeSync([[
            CREATE TABLE IF NOT EXISTS `shops` (
                `name` VARCHAR(50) NOT NULL PRIMARY KEY,
                `coords_x` FLOAT NOT NULL,
                `coords_y` FLOAT NOT NULL,
                `coords_z` FLOAT NOT NULL,
                `slots` INT DEFAULT 30,
                `items` LONGTEXT,
                `balance` INT DEFAULT 0,
                `owner` VARCHAR(50)
            )
        ]])
        
        if success then
            print('^2[ZK-SHOPS] ÉXITO! Tabla shops creada correctamente^7')
        else
            print('^1[ZK-SHOPS] ERROR! No se pudo crear la tabla shops^7')
        end
    else
        print('^2[ZK-SHOPS] Tabla shops existe en la base de datos^7')
        
        -- Verificar que la estructura sea correcta
        local columns = exports.oxmysql:executeSync("SHOW COLUMNS FROM shops")
        
        if columns and #columns > 0 then
            print('^2[ZK-SHOPS] Estructura de tabla verificada: ' .. #columns .. ' columnas^7')
            
            -- Verificar las tiendas existentes
            local shops = exports.oxmysql:executeSync("SELECT COUNT(*) as count FROM shops")
            if shops and shops[1] and shops[1].count then
                print('^2[ZK-SHOPS] Tiendas encontradas en la base de datos: ' .. shops[1].count .. '^7')
            else
                print('^3[ZK-SHOPS] No se encontraron tiendas en la base de datos^7')
            end
        else
            print('^1[ZK-SHOPS] Error al verificar la estructura de la tabla^7')
        end
    end
end)

-- Comando para crear una tienda de prueba
RegisterCommand('creartiendaprueba', function(source, args)
    if source > 0 then -- Solo permitir desde consola del servidor
        local player = QBCore.Functions.GetPlayer(source)
        if not player or not QBCore.Functions.HasPermission(source, 'admin') then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Error',
                description = 'No tienes permisos para usar este comando',
                type = 'error'
            })
            return
        end
    end
    
    print('^3[ZK-SHOPS] Creando tienda de prueba...^7')
    
    -- Datos de prueba para una tienda
    local testShop = {
        name = 'tiendaprueba' .. math.random(1000, 9999),
        coords = {
            x = -1222.26,
            y = -906.79,
            z = 12.33
        },
        slots = 30,
        items = {
            {
                name = 'water',
                label = 'Agua',
                price = 10,
                amount = 50
            },
            {
                name = 'sandwich',
                label = 'Sandwich',
                price = 15,
                amount = 30
            }
        },
        balance = 5000,
        owner = nil
    }
    
    -- Intentar insertar la tienda directamente en la base de datos
    local itemsJson = json.encode(testShop.items)
    
    -- Eliminar la tienda si ya existe (para evitar errores de clave duplicada)
    exports.oxmysql:executeSync('DELETE FROM shops WHERE name = ?', {testShop.name})
    
    -- Insertar la tienda
    local result = exports.oxmysql:executeSync('INSERT INTO shops (name, coords_x, coords_y, coords_z, slots, items, balance, owner) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        testShop.name,
        testShop.coords.x,
        testShop.coords.y,
        testShop.coords.z,
        testShop.slots,
        itemsJson,
        testShop.balance,
        testShop.owner
    })
    
    if result and result.affectedRows and result.affectedRows > 0 then
        print('^2[ZK-SHOPS] ÉXITO! Tienda de prueba "' .. testShop.name .. '" creada correctamente^7')
        
        if source > 0 then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Éxito',
                description = 'Tienda de prueba creada: ' .. testShop.name,
                type = 'success'
            })
        end
        
        -- Cargar las tiendas para actualizar la memoria caché
        exports['zk-shop-ux']:loadShops()
    else
        print('^1[ZK-SHOPS] ERROR al crear tienda de prueba^7')
        
        if source > 0 then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Error',
                description = 'No se pudo crear la tienda de prueba',
                type = 'error'
            })
        end
    end
end, true) -- true = comando restringido a admins
