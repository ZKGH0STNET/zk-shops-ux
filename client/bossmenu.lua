-- Boss menu functionality usando ox_lib:context
local QBCore = exports['qb-core']:GetCoreObject()
local CurrentShop = nil

-- Función global para abrir el boss menu
OpenShopBossMenu = function(shop)
    print('^3[ZK-SHOPS] Abriendo menú de gestión para tienda: ' .. (shop and shop.name or 'desconocida') .. '^7')
    
    -- Validar que los datos de la tienda sean correctos
    if not shop or not shop.name then
        lib.notify({
            title = 'Error',
            description = 'Datos de la tienda inválidos',
            type = 'error'
        })
        return
    end
    
    -- Guardar referencia a la tienda actual
    CurrentShop = shop
    
    -- Solicitar datos actualizados al servidor
    TriggerServerEvent('zk-shops:getBossMenuData', shop.name)
end

-- Función para mostrar el menú con datos actualizados
function ShowBossMenu(shop, salesHistory)
    if not shop then return end
    
    -- Formatear el saldo para mostrarlo
    local formattedBalance = '$' .. (shop.balance and shop.balance > 0 and shop.balance or 0)
    
    -- Formatear historial de ventas para el menú
    local salesItems = {}
    if salesHistory and #salesHistory > 0 then
        -- Ordenar por fecha, más reciente primero
        table.sort(salesHistory, function(a, b) 
            return a.date > b.date 
        end)
        
        -- Limitar a 10 ventas más recientes
        local count = math.min(10, #salesHistory)
        for i=1, count do
            local sale = salesHistory[i]
            table.insert(salesItems, {
                title = sale.item .. ' x' .. sale.quantity,
                description = '$' .. sale.price .. ' - ' .. sale.date,
                colorScheme = 'green'
            })
        end
    else
        table.insert(salesItems, {
            title = 'No hay ventas registradas',
            disabled = true
        })
    end
    
    -- Crear submenú de productos
    local inventoryItems = {}
    if shop.items and #shop.items > 0 then
        for i, item in ipairs(shop.items) do
            -- Compatibilidad con diferentes formatos de items
            local itemQty = item.amount or item.quantity or 0
            local itemPrice = item.price or 0
            local itemName = item.name or item.label or 'Desconocido'
            
            print('^3[ZK-SHOPS] Item en inventario - Nombre: ' .. itemName .. ', Cantidad: ' .. itemQty .. ', Precio: $' .. itemPrice .. '^7')
            
            table.insert(inventoryItems, {
                title = itemName .. ' (' .. itemQty .. ' disponibles)',
                description = '$' .. itemPrice,
                icon = 'box',
                onSelect = function()
                    OpenItemEditMenu(shop, i, item)
                end
            })
        end
    else
        table.insert(inventoryItems, {
            title = 'No hay productos en esta tienda',
            disabled = true
        })
    end

    -- Estructura del menú principal
    lib.registerContext({
        id = 'shop_boss_menu',
        title = 'Gestión de Tienda: ' .. shop.name,
        options = {
            {
                title = 'Información de la Tienda',
                description = 'Balance: ' .. formattedBalance,
                icon = 'info-circle',
                disabled = true,
                progress = shop.balance > 0 and (shop.balance / 10000) * 100 or 0, -- Barra de progreso basada en el balance
                colorScheme = 'blue'
            },
            {
                title = 'Gestionar Finanzas',
                description = 'Depositar o retirar dinero',
                icon = 'money-bill-wave',
                onSelect = function()
                    OpenFinanceMenu(shop)
                end
            },
            {
                title = 'Inventario de Productos',
                description = shop.items and #shop.items .. ' productos disponibles',
                icon = 'boxes-stacked',
                menu = 'shop_inventory_menu'
            },
            {
                title = 'Ventas Recientes',
                description = salesHistory and #salesHistory .. ' ventas registradas',
                icon = 'chart-line',
                menu = 'shop_sales_menu'
            },
            {
                title = 'Transferir Propiedad',
                description = 'Cambiar el dueño de la tienda',
                icon = 'user-edit',
                onSelect = function()
                    OpenTransferMenu(shop)
                end
            }
        }
    })
    
    -- Submenú de historial de ventas
    lib.registerContext({
        id = 'shop_sales_menu',
        title = 'Historial de Ventas',
        menu = 'shop_boss_menu',
        options = salesItems
    })
    
    -- Submenú de inventario
    lib.registerContext({
        id = 'shop_inventory_menu',
        title = 'Inventario de la Tienda',
        menu = 'shop_boss_menu',
        options = inventoryItems
    })
    
    -- Mostrar el menú principal
    lib.showContext('shop_boss_menu')
end

-- Menú para editar un producto
function OpenItemEditMenu(shop, itemIndex, item)
    -- Compatibilidad con diferentes formatos de items
    local itemQty = item.amount or item.quantity or 0
    local itemPrice = item.price or 0
    local itemName = item.name or item.label or 'Desconocido'
    
    lib.registerContext({
        id = 'shop_item_edit_menu',
        title = 'Editar Producto: ' .. itemName,
        menu = 'shop_inventory_menu',
        options = {
            {
                title = 'Información del Producto',
                description = 'Precio: $' .. itemPrice .. ' | Cantidad: ' .. itemQty,
                disabled = true,
                icon = 'tag'
            },
            {
                title = 'Cambiar Cantidad',
                description = 'Modificar el stock disponible',
                icon = 'edit',
                onSelect = function()
                    local input = lib.inputDialog('Cambiar Cantidad', {
                        {type = 'number', label = 'Nueva cantidad', default = itemQty, min = 0}
                    })
                    
                    if input and input[1] then
                        local newQuantity = math.floor(tonumber(input[1]))
                        if newQuantity >= 0 then
                            -- Actualizar en el servidor
                            TriggerServerEvent('zk-shops:bossmenu_action', {
                                action = 'update_item',
                                shopName = shop.name,
                                itemIndex = itemIndex - 1, -- Restar 1 porque Lua usa índices desde 1 pero el servidor espera desde 0 (JavaScript)
                                newQuantity = newQuantity
                            })
                            
                            -- Notificar al usuario
                            lib.notify({
                                title = 'Éxito',
                                description = 'Cantidad actualizada a ' .. newQuantity,
                                type = 'success'
                            })
                        else
                            lib.notify({
                                title = 'Error',
                                description = 'La cantidad debe ser mayor o igual a 0',
                                type = 'error'
                            })
                        end
                    end
                end
            }
        }
    })
    
    lib.showContext('shop_item_edit_menu')
end

-- Menú para gestionar finanzas
function OpenFinanceMenu(shop)
    lib.registerContext({
        id = 'shop_finance_menu',
        title = 'Finanzas de la Tienda',
        menu = 'shop_boss_menu',
        options = {
            {
                title = 'Balance Actual',
                description = '$' .. (shop.balance or 0),
                disabled = true,
                icon = 'piggy-bank'
            },
            {
                title = 'Depositar Dinero',
                description = 'Añadir fondos a la tienda',
                icon = 'hand-holding-dollar',
                onSelect = function()
                    local input = lib.inputDialog('Depositar Dinero', {
                        {type = 'number', label = 'Cantidad a depositar', default = 1000, min = 1}
                    })
                    
                    if input and input[1] then
                        local amount = math.floor(tonumber(input[1]))
                        if amount > 0 then
                            TriggerServerEvent('zk-shops:depositMoney', shop.name, amount)
                        else
                            lib.notify({
                                title = 'Error',
                                description = 'La cantidad debe ser mayor a 0',
                                type = 'error'
                            })
                        end
                    end
                end
            },
            {
                title = 'Retirar Dinero',
                description = 'Sacar fondos de la tienda',
                icon = 'money-bill-transfer',
                onSelect = function()
                    local max = shop.balance or 0
                    local input = lib.inputDialog('Retirar Dinero', {
                        {type = 'number', label = 'Cantidad a retirar', default = max > 1000 and 1000 or max, min = 1, max = max}
                    })
                    
                    if input and input[1] then
                        local amount = math.floor(tonumber(input[1]))
                        if amount > 0 and amount <= max then
                            TriggerServerEvent('zk-shops:withdrawMoney', shop.name, amount)
                        else
                            lib.notify({
                                title = 'Error',
                                description = 'Cantidad inválida',
                                type = 'error'
                            })
                        end
                    end
                end
            }
        }
    })
    
    lib.showContext('shop_finance_menu')
end

-- Menú para transferir propiedad
function OpenTransferMenu(shop)
    lib.registerContext({
        id = 'shop_transfer_menu',
        title = 'Transferir Propiedad',
        menu = 'shop_boss_menu',
        options = {
            {
                title = 'Dueño Actual',
                description = shop.owner or 'Sin dueño',
                disabled = true,
                icon = 'user'
            },
            {
                title = 'Transferir a Otro Jugador',
                description = 'Cambiar el dueño de la tienda',
                icon = 'user-plus',
                onSelect = function()
                    local input = lib.inputDialog('Transferir Tienda', {
                        {type = 'number', label = 'ID del jugador', description = 'Ingresa el Server ID del nuevo dueño'}
                    })
                    
                    if input and input[1] then
                        local targetId = tonumber(input[1])
                        if targetId and targetId > 0 then
                            TriggerServerEvent('zk-shops:transferOwnership', shop.name, targetId)
                        else
                            lib.notify({
                                title = 'Error',
                                description = 'ID de jugador inválido',
                                type = 'error'
                            })
                        end
                    end
                end
            }
        }
    })
    
    lib.showContext('shop_transfer_menu')
end

-- Evento para recibir datos del boss menu desde el servidor
RegisterNetEvent('zk-shops:receiveBossMenuData', function(shop, salesHistory)
    if not shop then return end
    
    -- Actualizar referencia a la tienda actual
    CurrentShop = shop
    
    -- Mostrar el menú con datos actualizados
    ShowBossMenu(shop, salesHistory)
end)

-- Evento para actualizar el boss menu después de acciones
RegisterNetEvent('zk-shops:updateBossMenu', function(success, message, type)
    -- Mostrar notificación
    lib.notify({
        title = success and 'Éxito' or 'Error',
        description = message,
        type = type or (success and 'success' or 'error')
    })
    
    -- Actualizar datos si la acción fue exitosa
    if success and CurrentShop then
        TriggerServerEvent('zk-shops:getBossMenuData', CurrentShop.name)
    end
end)

-- Register event handler for opening boss menu
RegisterNetEvent('zk-shops:openBossMenu', function(shop)
    OpenShopBossMenu(shop)
end)

-- Comando para abrir el boss menu directamente (para pruebas)
RegisterCommand('bosstienda', function(source, args)
    local shopName = args[1]
    if not shopName then
        lib.notify({
            title = 'Error',
            description = 'Debes especificar el nombre de la tienda',
            type = 'error'
        })
        return
    end
    
    TriggerServerEvent('zk-shops:requestBossMenu', shopName)
end, false)

-- Evento para cerrar el menú de jefe cuando se transfiere la tienda
RegisterNetEvent('zk-shops:closeBossMenu', function()
    lib.hideContext()
    lib.notify({
        title = 'Tienda Transferida',
        description = 'Has transferido la tienda exitosamente',
        type = 'success'
    })
    CurrentShop = nil
end)

-- Export function to open boss menu from other resources
exports('OpenShopBossMenu', OpenShopBossMenu)
