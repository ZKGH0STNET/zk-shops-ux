-- Main client file for zk-shop-ux
local QBCore = exports['qb-core']:GetCoreObject()
Shops = {} -- Declared as global for other files to access
local CreatingShop = false

-- Initialize client
CreateThread(function()
    Wait(1000)
    -- Clean up any orphaned zones from previous sessions
    print('[ZK-SHOPS] Performing startup cleanup')
    ClearAllZones()
    Wait(500)
    -- Request shops from server when player is fully loaded
    TriggerServerEvent('zk-shops:requestShops')
end)

-- Handle resource start event
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    -- Perform immediate cleanup on resource start
    print('[ZK-SHOPS] Resource started, cleaning up any orphaned zones')
    ClearAllZones()
end)

-- Event for syncing shops from server
RegisterNetEvent('zk-shops:syncShops', function(shops)
    print('[ZK-SHOPS] Received ' .. #shops .. ' shops from server')
    Shops = shops -- Directly update the global Shops table
    RefreshAllBlips(shops)
    RefreshTargetZones(shops)
end)

-- Nuevo evento para abrir el menú de gestión de tiendas
RegisterNetEvent('zk-shops:openShopManagementMenu', function()
    -- Comprobar si la función OpenShopManagementMenu existe
    if OpenShopManagementMenu then
        OpenShopManagementMenu()
    else
        -- Si no existe, usamos la función que sabemos que sí existe
        print('^3[ZK-SHOPS] OpenShopManagementMenu no existe, intentando usar BossMenu^7')
        local Player = QBCore.Functions.GetPlayerData()
        if not Player then return end
        
        -- Buscar tiendas que son propiedad del jugador
        local ownedShops = {}
        for _, shop in ipairs(Shops) do
            if shop.owner == Player.citizenid then
                table.insert(ownedShops, shop)
            end
        end
        
        if #ownedShops > 0 then
            -- Usar la función de boss menu para las tiendas propias
            if OpenBossMenu then
                OpenBossMenu(ownedShops)
            else
                -- Último recurso, activar el evento directamente para la primera tienda
                TriggerServerEvent('zk-shops:requestBossMenuData', ownedShops[1].name)
            end
        else
            lib.notify({
                title = 'Sin tiendas',
                description = 'No tienes tiendas para gestionar',
                type = 'error'
            })
        end
    end
end)

-- Initialize when player is loaded
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000) -- Wait for player to fully load
    TriggerServerEvent('zk-shops:requestShops')
end)

-- Event to clear zones on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print('[ZK-SHOPS] Resource stopping, cleaning up all zones and blips')
        ClearAllBlips()
        ClearAllZones()
        
        -- Additional cleanup for persistent zones
        if exports.ox_target then
            pcall(function()
                for i=1, 100 do
                    local pattern = 'shop_*'
                    exports.ox_target:removeZone(pattern)
                end
            end)
        end
    end
end)

-- Export function for external zone cleanup
exports('cleanupShopZones', function()
    print('[ZK-SHOPS] External cleanup requested')
    ClearAllZones()
    return true
end)

-- Event handler for cleaning up a specific shop zone
RegisterNetEvent('zk-shops:cleanupShopZone', function(shopName)
    if not shopName then return end
    
    -- Use the specialized shop zone cleanup function
    CleanupShopZone(shopName)
    
    -- Refresh all zones to ensure everything is in a consistent state
    Wait(200)
    RefreshTargetZones(Shops)
end)

-- Event handler for forcing a complete zone cleanup
RegisterNetEvent('zk-shops:forceZoneCleanup', function()
    print('[ZK-SHOPS] Force cleanup requested by server')
    ClearAllZones()
end)

-- Event for starting shop creation process
RegisterNetEvent('zk-shops:startShopCreation', function()
    if CreatingShop then return end
    CreatingShop = true
    
    -- Show TextUI
    lib.showTextUI('[E] Colocar tienda aquí', {
        position = 'top-center',
        icon = 'store',
        style = { backgroundColor = '#222E50', color = '#fff' }
    })
    
    -- Notify in chat
    TriggerEvent('chat:addMessage', {
        args = { 'Sistema de Tiendas', 'Camina al lugar deseado y presiona [E] para colocar la tienda.' }
    })
    
    -- Handle placement
    CreateThread(function()
        while CreatingShop do
            Wait(0)
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            
            -- Draw marker
            DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0, 0, 0, 0, 0, 0, 
                      1.2, 1.2, 0.6, 0, 120, 255, 200, false, false, 2, false, nil, nil, false)
            
            -- Check for input
            if IsControlJustReleased(0, 38) then -- E key
                CreatingShop = false
                lib.hideTextUI()
                OpenShopCreationMenu(coords)
            end
        end
        
        lib.hideTextUI()
    end)
end)

-- Function to open shop creation menu
function OpenShopCreationMenu(coords)
    -- Get shop name and slots
    local input = lib.inputDialog('Información de la Tienda', {
        {type = 'input', label = 'Nombre de la tienda (ID)', placeholder = 'ej: armeria_paleto', required = true},
        {type = 'number', label = 'Slots del inventario', placeholder = 'ej: 50', required = true, default = Config.DefaultSlots}
    })
    
    if not input then return end
    
    local shopName = input[1]
    local slots = tonumber(input[2])
    local items = {}
    
    -- Sanitize shop name (letters, numbers, underscores only)
    shopName = shopName:gsub('[^%w_]', '')
    
    -- Add products in a loop
    while true do
        local itemInput = lib.inputDialog('Agregar producto a la tienda', {
            {type = 'input', label = 'Nombre del item (ej: agua)', required = true},
            {type = 'input', label = 'Label del item (ej: Agua)', required = true},
            {type = 'number', label = 'Cantidad', required = true, default = 10},
            {type = 'number', label = 'Precio', required = true, default = 100}
        })
        
        if not itemInput then break end
        
        table.insert(items, {
            name = itemInput[1],
            label = itemInput[2],
            amount = tonumber(itemInput[3]),
            price = tonumber(itemInput[4])
        })
        
        -- Mostrar el menú de opciones
        -- Primero, mostrar alerta informativa con la cantidad de productos
        lib.notify({
            title = 'Productos añadidos',
            description = 'Has agregado ' .. #items .. ' productos a la tienda',
            type = 'info'
        })
        
        -- Para agregar el botón "Terminar", usamos un diálogo personalizado con 3 botones
        Citizen.Wait(500) -- Espera para que se vea la notificación anterior
        
        -- Usamos dos alertas separadas para simular los tres botones
        local firstChoice = lib.alertDialog({
            header = '¿Qué deseas hacer ahora?',
            content = 'Has agregado ' .. #items .. ' productos a la tienda',
            centered = true,
            labels = {
                confirm = 'Terminar',
                cancel = 'Más opciones'
            }
        })
        
        -- Si presiona "Terminar", terminamos el bucle
        if firstChoice == 'confirm' then
            print('^2[ZK-SHOPS] Usuario eligió terminar la creación con ' .. #items .. ' productos^7')
            break
        end
        
        -- Si presionó "Más opciones", mostramos otro diálogo
        if firstChoice == 'cancel' then
            local secondChoice = lib.alertDialog({
                header = 'Opciones adicionales',
                content = '¿Qué deseas hacer con la tienda?',
                centered = true,
                labels = {
                    confirm = 'Agregar más productos',
                    cancel = 'Cancelar creación'
                }
            })
            
            -- Si presiona "Cancelar creación", terminamos el bucle
            if secondChoice == 'cancel' then
                print('^1[ZK-SHOPS] Usuario canceló la creación de la tienda^7')
                break
            end
            -- Si presiona "Agregar más productos" continua el bucle
        end
    end
    
    -- Create shop
    if #items > 0 then
        TriggerServerEvent('zk-shops:createShop', {
            name = shopName,
            slots = slots,
            coords = coords,
            items = items,
            balance = 0
        })
    else
        lib.notify({
            title = 'Error',
            description = 'La tienda debe tener al menos un producto',
            type = 'error'
        })
    end
end

-- Open shop menu
RegisterNetEvent('zk-shops:openShopMenu', function(shop)
    print('[ZK-SHOPS] Received openShopMenu event for shop: ' .. (shop and shop.name or 'unknown'))
    if not shop then 
        print('[ZK-SHOPS] ERROR: Shop data is nil!')
        return 
    end
    
    if not OpenShopInterface then
        print('[ZK-SHOPS] ERROR: OpenShopInterface function not found!')
        return
    end
    
    OpenShopInterface(shop)
end)

-- Event to update shop data (after purchase)
RegisterNetEvent('zk-shops:updateShopData', function(shop)
    if not shop then return end
    
    -- Update local shop data
    for i, existingShop in ipairs(Shops) do
        if existingShop.name == shop.name then
            Shops[i] = shop
            break
        end
    end
    
    -- Refresh UI if open
    RefreshShopInterface(shop)
end)

-- Open shop management menu
function OpenShopManagementMenu()
    if #Shops == 0 then
        lib.notify({
            title = 'Sin tiendas',
            description = 'No hay tiendas disponibles para gestionar',
            type = 'error'
        })
        return
    end
    
    local options = {}
    
    for _, shop in ipairs(Shops) do
        table.insert(options, {
            title = shop.name,
            description = 'Coords: ' .. math.floor(shop.coords.x) .. ', ' .. 
                         math.floor(shop.coords.y) .. ', ' .. math.floor(shop.coords.z),
            icon = 'fas fa-store',
            onSelect = function()
                OpenSingleShopManagementMenu(shop)
            end
        })
    end
    
    lib.registerContext({
        id = 'shop_management_menu',
        title = 'Gestión de Tiendas',
        options = options
    })
    
    lib.showContext('shop_management_menu')
end

-- Open management menu for a single shop
function OpenSingleShopManagementMenu(shop)
    local options = {
        {
            title = 'Gestionar Productos',
            description = 'Añadir, editar o eliminar productos',
            icon = 'fas fa-boxes',
            onSelect = function()
                OpenProductsManagementMenu(shop)
            end
        },
        {
            title = 'Eliminar Tienda',
            description = '¡CUIDADO! Esta acción no se puede deshacer',
            icon = 'fas fa-trash',
            iconColor = 'red',
            onSelect = function()
                ConfirmShopDeletion(shop)
            end
        },
        -- Opción de teletransporte eliminada
    }
    
    lib.registerContext({
        id = 'single_shop_management_' .. shop.name,
        title = 'Gestión: ' .. shop.name,
        menu = 'shop_management_menu',
        options = options
    })
    
    lib.showContext('single_shop_management_' .. shop.name)
end

-- Open products management menu
function OpenProductsManagementMenu(shop)
    local options = {
        {
            title = 'Añadir Producto',
            description = 'Agregar un nuevo producto a la tienda',
            icon = 'fas fa-plus',
            onSelect = function()
                AddProductToShop(shop)
            end
        }
    }
    
    for i, item in ipairs(shop.items or {}) do
        table.insert(options, {
            title = item.label .. ' (' .. item.name .. ')',
            description = 'Cantidad: ' .. item.amount .. ' | Precio: $' .. item.price,
            icon = 'fas fa-box',
            onSelect = function()
                EditShopProduct(shop, i)
            end
        })
    end
    
    lib.registerContext({
        id = 'products_management_' .. shop.name,
        title = 'Productos: ' .. shop.name,
        menu = 'single_shop_management_' .. shop.name,
        options = options
    })
    
    lib.showContext('products_management_' .. shop.name)
end

-- Add product to shop
function AddProductToShop(shop)
    local input = lib.inputDialog('Añadir Producto', {
        {type = 'input', label = 'Nombre del item', required = true},
        {type = 'input', label = 'Label', required = true},
        {type = 'number', label = 'Cantidad', required = true, default = 10},
        {type = 'number', label = 'Precio', required = true, default = 100}
    })
    
    if not input then return end
    
    local items = shop.items or {}
    table.insert(items, {
        name = input[1],
        label = input[2],
        amount = tonumber(input[3]),
        price = tonumber(input[4])
    })
    
    TriggerServerEvent('zk-shops:updateShopItems', shop.name, items)
    Wait(500) -- Wait for DB update
    TriggerServerEvent('zk-shops:requestShops') -- Refresh shop data
end

-- Edit shop product
function EditShopProduct(shop, index)
    local item = shop.items[index]
    
    local options = {
        {
            title = 'Editar Producto',
            description = 'Modificar detalles del producto',
            icon = 'fas fa-edit',
            onSelect = function()
                EditProductDetails(shop, index)
            end
        },
        {
            title = 'Eliminar Producto',
            description = 'Quitar este producto de la tienda',
            icon = 'fas fa-trash',
            iconColor = 'red',
            onSelect = function()
                ConfirmProductDeletion(shop, index)
            end
        }
    }
    
    lib.registerContext({
        id = 'product_options_' .. shop.name .. '_' .. index,
        title = item.label,
        menu = 'products_management_' .. shop.name,
        options = options
    })
    
    lib.showContext('product_options_' .. shop.name .. '_' .. index)
end

-- Edit product details
function EditProductDetails(shop, index)
    local item = shop.items[index]
    
    local input = lib.inputDialog('Editar Producto', {
        {type = 'input', label = 'Nombre del item', default = item.name, required = true},
        {type = 'input', label = 'Label', default = item.label, required = true},
        {type = 'number', label = 'Cantidad', default = item.amount, required = true},
        {type = 'number', label = 'Precio', default = item.price, required = true}
    })
    
    if not input then return end
    
    shop.items[index] = {
        name = input[1],
        label = input[2],
        amount = tonumber(input[3]),
        price = tonumber(input[4])
    }
    
    TriggerServerEvent('zk-shops:updateShopItems', shop.name, shop.items)
    Wait(500) -- Wait for DB update
    TriggerServerEvent('zk-shops:requestShops') -- Refresh shop data
end

-- Confirm product deletion
function ConfirmProductDeletion(shop, index)
    local item = shop.items[index]
    
    local confirm = lib.alertDialog({
        header = 'Confirmar eliminación',
        content = '¿Estás seguro que deseas eliminar ' .. item.label .. '?',
        centered = true,
        cancel = true
    })
    
    if confirm == 'confirm' then
        table.remove(shop.items, index)
        TriggerServerEvent('zk-shops:updateShopItems', shop.name, shop.items)
        
        lib.notify({
            title = 'Producto eliminado',
            description = 'El producto ha sido eliminado de la tienda',
            type = 'success'
        })
        
        Wait(500) -- Wait for DB update
        TriggerServerEvent('zk-shops:requestShops') -- Refresh shop data
    end
end

-- Confirm shop deletion
function ConfirmShopDeletion(shop)
    local confirm = lib.alertDialog({
        header = 'ELIMINAR TIENDA',
        content = '¿Estás SEGURO que deseas eliminar la tienda "' .. shop.name .. 
                '"? Esta acción NO SE PUEDE DESHACER.',
        centered = true,
        cancel = true
    })
    
    if confirm == 'confirm' then
        -- Second confirmation
        local input = lib.inputDialog('Confirmar eliminación', {
            {type = 'input', label = 'Escribe el nombre de la tienda para confirmar', 
             description = 'Escribe "' .. shop.name .. '" para confirmar', required = true}
        })
        
        if input and input[1] == shop.name then
            TriggerServerEvent('zk-shops:deleteShop', shop.name)
            
            lib.notify({
                title = 'Tienda eliminada',
                description = 'La tienda "' .. shop.name .. '" ha sido eliminada',
                type = 'success'
            })
            
            Wait(1000) -- Wait for DB update
            TriggerServerEvent('zk-shops:requestShops') -- Refresh shop data
        else
            lib.notify({
                title = 'Acción cancelada',
                description = 'El nombre no coincide, la tienda no ha sido eliminada',
                type = 'error'
            })
        end
    end
end

-- Register command for shop creation
RegisterCommand('creartienda', function()
    TriggerEvent('zk-shops:startShopCreation')
end)

-- Register command for shop management
RegisterCommand('gestiontiendas', function()
    OpenShopManagementMenu()
end)
