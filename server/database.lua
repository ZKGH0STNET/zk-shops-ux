-- Database handling for zk-shop-ux
local oxmysql = exports['oxmysql']

-- Initialize the database
function InitializeDatabase()
    print('^2[ZK-SHOPS]^7 Initializing database...')
    
    -- Create the shops table if it doesn't exist
    oxmysql:execute([[
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
    ]], {}, function(result)
        if result then
            print('^2[ZK-SHOPS]^7 Database initialized successfully')
        else
            print('^1[ZK-SHOPS]^7 Failed to initialize database')
        end
    end)
end

-- Get all shops from the database
function GetAllShops()
    local promise = promise.new()
    
    oxmysql:execute('SELECT * FROM `shops`', {}, function(result)
        local shops = {}
        
        if result and #result > 0 then
            for _, row in ipairs(result) do
                if row and row.name and row.coords_x and row.coords_y and row.coords_z then
                    table.insert(shops, {
                        name = row.name,
                        coords = {
                            x = tonumber(row.coords_x),
                            y = tonumber(row.coords_y),
                            z = tonumber(row.coords_z)
                        },
                        slots = tonumber(row.slots) or Config.DefaultSlots,
                        items = json.decode(row.items or '[]'),
                        balance = tonumber(row.balance) or 0,
                        owner = row.owner
                    })
                end
            end
        end
        
        promise:resolve(shops)
    end)
    
    return Citizen.Await(promise)
end

-- Insert a new shop into the database
function InsertShop(data)
    print('^1[ZK-SHOPS] INTENTANDO CREAR TIENDA (MÉTODO DIRECTO)^7')
    
    if not data or not data.name or not data.coords then
        print('^1[ZK-SHOPS] Error: Datos inválidos para crear tienda - falta nombre o coordenadas^7')
        return false, 'Datos inválidos para crear tienda'
    end
    
    -- Simplificar el nombre y eliminar caracteres no válidos
    data.name = tostring(data.name):gsub('[^%w_]', '')
    
    -- Crear la tabla si no existe
    oxmysql:executeSync([[
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
    
    -- Verificar que el nombre no esté vacío después de sanitizar
    if data.name == '' then
        print('^1[ZK-SHOPS] Error: Nombre de tienda inválido después de sanitizar^7')
        return false, 'Nombre de tienda inválido (solo letras, números y guiones bajos)'
    end
    
    -- Convertir items a JSON
    local itemsJson = '[]'
    if data.items and #data.items > 0 then
        itemsJson = json.encode(data.items)
    end
    
    print('^3[ZK-SHOPS] Inserción directa:^7')
    print('  Nombre: ' .. data.name)
    print('  Coordenadas: X=' .. data.coords.x .. ', Y=' .. data.coords.y .. ', Z=' .. data.coords.z)
    print('  Items: ' .. #(data.items or {}) .. ' productos')
    
    -- Método directo forzando un DELETE antes del INSERT para evitar problemas de clave duplicada
    oxmysql:executeSync('DELETE FROM shops WHERE name = ?', {data.name})
    
    -- Insertar tienda
    local result = oxmysql:executeSync('INSERT INTO shops (name, coords_x, coords_y, coords_z, slots, items, balance, owner) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        data.name,
        data.coords.x,
        data.coords.y,
        data.coords.z,
        data.slots or 30,
        itemsJson,
        data.balance or 0,
        data.owner or nil
    })
    
    if result and result.affectedRows and result.affectedRows > 0 then
        print('^2[ZK-SHOPS] ÉXITO! Tienda "' .. data.name .. '" creada correctamente^7')
        return true, 'Tienda creada correctamente'
    else
        print('^1[ZK-SHOPS] ERROR al crear tienda "' .. data.name .. '"^7')
        return false, 'Error al crear tienda en la base de datos'
    end
end

-- Delete a shop from the database
function DeleteShop(shopName)
    local promise = promise.new()
    
    oxmysql:execute('DELETE FROM `shops` WHERE name = ?', {
        shopName
    }, function(result)
        if result and result.affectedRows > 0 then
            promise:resolve(true)
        else
            promise:resolve(false)
        end
    end)
    
    return Citizen.Await(promise)
end

-- Update shop items
function UpdateShopItems(shopName, items)
    local promise = promise.new()
    
    print('^3[ZK-SHOPS] Actualizando items para tienda: ' .. shopName .. '^7')
    
    oxmysql:execute('UPDATE `shops` SET items = ? WHERE name = ?', {
        json.encode(items),
        shopName
    }, function(result)
        if result and result.affectedRows > 0 then
            print('^2[ZK-SHOPS] Items actualizados correctamente para tienda: ' .. shopName .. '^7')
            promise:resolve(true)
        else
            print('^1[ZK-SHOPS] Error al actualizar items para tienda: ' .. shopName .. '^7')
            promise:resolve(false)
        end
    end)
    
    return Citizen.Await(promise)
end

-- Update shop balance
function UpdateShopBalance(shopName, balance)
    local promise = promise.new()
    
    print('^3[ZK-SHOPS] Actualizando balance para tienda: ' .. shopName .. ' - Nuevo balance: ' .. balance .. '^7')
    
    oxmysql:execute('UPDATE `shops` SET balance = ? WHERE name = ?', {
        balance,
        shopName
    }, function(result)
        if result and result.affectedRows > 0 then
            print('^2[ZK-SHOPS] Balance actualizado correctamente para tienda: ' .. shopName .. '^7')
            promise:resolve(true)
        else
            print('^1[ZK-SHOPS] Error al actualizar balance para tienda: ' .. shopName .. '^7')
            promise:resolve(false)
        end
    end)
    
    return Citizen.Await(promise)
end

-- Get shops owned by a specific player
function GetPlayerOwnedShops(citizenId)
    local promise = promise.new()
    
    print('^3[ZK-SHOPS] Consultando tiendas del jugador: ' .. citizenId .. '^7')
    
    oxmysql:execute('SELECT * FROM `shops` WHERE owner = ?', {
        citizenId
    }, function(result)
        local shops = {}
        
        if result and #result > 0 then
            for _, row in ipairs(result) do
                if row and row.name then
                    table.insert(shops, {
                        name = row.name,
                        coords = {
                            x = tonumber(row.coords_x),
                            y = tonumber(row.coords_y),
                            z = tonumber(row.coords_z)
                        },
                        slots = tonumber(row.slots) or Config.DefaultSlots,
                        items = json.decode(row.items or '[]'),
                        balance = tonumber(row.balance) or 0,
                        owner = row.owner
                    })
                end
            end
            print('^2[ZK-SHOPS] Se encontraron ' .. #shops .. ' tiendas para el jugador: ' .. citizenId .. '^7')
        else
            print('^3[ZK-SHOPS] No se encontraron tiendas para el jugador: ' .. citizenId .. '^7')
        end
        
        promise:resolve(shops)
    end)
    
    return Citizen.Await(promise)
end
