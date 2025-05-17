local creandoTienda = false
local tiendasRegistradas = {}
local tiendaTextUIActive = false
local tiendaTextUIZone = nil
local lastTiendaCercana = nil
local puedeAbrirTienda = false
local shopBlips = {}

RegisterCommand("creartienda", function()
    if creandoTienda then return end
    creandoTienda = true
    if lib and lib.showTextUI then
        lib.showTextUI('[E] Colocar tienda aquí', {
            position = 'top-center',
            icon = 'store',
            style = { backgroundColor = '#222E50', color = '#fff' }
        })
    end
    TriggerEvent('chat:addMessage', { args = { 'Sistema de Tiendas', 'Camina al lugar deseado y presiona [E] para colocar la tienda.' } })
    CreateThread(function()
        while creandoTienda do
            Wait(0)
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0, 0, 0, 0, 0, 0, 1.2, 1.2, 0.6, 0, 120, 255, 200, false, false, 2, false, nil, nil, false)
            if IsControlJustReleased(0, 38) then -- E
                creandoTienda = false
                if lib and lib.hideTextUI then lib.hideTextUI() end
                abrirMenuInfoTienda(coords)
            end
        end
        if lib and lib.hideTextUI then lib.hideTextUI() end
    end)
end)

function abrirMenuInfoTienda(coords)
    -- Primer input: nombre y slots
    local input = lib.inputDialog('Información de la Tienda', {
        {type = 'input', label = 'Nombre de la tienda (ID)', placeholder = 'ej: armeria_paleto', required = true},
        {type = 'number', label = 'Slots del inventario', placeholder = 'ej: 50', required = true}
    })
    if not input then return end

    local shopName = input[1]
    local slots = tonumber(input[2])
    local items = {}

    -- Segundo input: agregar productos
    while true do
        local itemInput = lib.inputDialog('Agregar producto a la tienda', {
            {type = 'input', label = 'Nombre del item (ej: agua)', required = true},
            {type = 'input', label = 'Label del item (ej: Agua)', required = true},
            {type = 'number', label = 'Cantidad', required = true},
            {type = 'number', label = 'Precio', required = true}
        })
        if not itemInput then break end
        table.insert(items, {
            name = itemInput[1],
            label = itemInput[2],
            amount = tonumber(itemInput[3]),
            price = tonumber(itemInput[4])
        })
        -- Preguntar si quiere agregar otro producto
        local continuar = lib.alertDialog({
            header = '¿Agregar otro producto?',
            content = '¿Quieres agregar otro producto a la tienda?',
            centered = true,
            cancel = true
        })
        if continuar == 'cancel' then break end
    end

    -- Crear la tienda y guardar los productos
    TriggerServerEvent("tienda:crearNuevaTienda", shopName, slots, coords, items)
end

RegisterNetEvent("tienda:cargarTiendas", function(tiendas)
    tiendasRegistradas = tiendas
    setupQbTargetShops()

    -- Remove old blips
    for _, blip in ipairs(shopBlips) do
        RemoveBlip(blip)
    end
    shopBlips = {}

    -- Add new blips for each shop
    for _, tienda in ipairs(tiendasRegistradas or {}) do
        local coords = tienda.coords
        if type(coords) == "table" then
            coords = vector3(coords.x, coords.y, coords.z)
        end
        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, 52) -- 52 = Store icon, change if you want a different icon
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.8)
        SetBlipColour(blip, 2) -- 2 = Green, change if you want a different color
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(tienda.name or "Tienda")
        EndTextCommandSetBlipName(blip)
        table.insert(shopBlips, blip)
    end
end)

function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(true)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

-- QBCore Target integration
local createdZones = {}

function mostrarTextUITienda(tienda)
    if lib and lib.showTextUI and not tiendaTextUIActive then
        lib.showTextUI('[E] Abrir tienda: ' .. tienda.name, {
            position = 'top-center',
            icon = 'store',
            style = { backgroundColor = '#222E50', color = '#fff' }
        })
        tiendaTextUIActive = true
    end
end

function ocultarTextUITienda()
    if lib and lib.hideTextUI and tiendaTextUIActive then
        lib.hideTextUI()
        tiendaTextUIActive = false
    end
end

CreateThread(function()
    while true do
        Wait(0)
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local tiendaCercana = nil
        for _, tienda in pairs(tiendasRegistradas or {}) do
            local tCoords = tienda.coords
            if type(tCoords) == "table" then
                tCoords = vector3(tCoords.x, tCoords.y, tCoords.z)
            end
            if #(coords - tCoords) < 2.5 then
                tiendaCercana = tienda
                break
            end
        end
        if tiendaCercana and (not lastTiendaCercana or lastTiendaCercana.name ~= tiendaCercana.name) then
            if lib and lib.showTextUI and not tiendaTextUIActive then
                lib.showTextUI('[E] Abrir tienda: ' .. tiendaCercana.name, {
                    position = 'top-center',
                    icon = 'store',
                    style = { backgroundColor = '#222E50', color = '#fff' }
                })
                tiendaTextUIActive = true
            end
            lastTiendaCercana = tiendaCercana
            puedeAbrirTienda = true
        elseif not tiendaCercana and lastTiendaCercana then
            if lib and lib.hideTextUI and tiendaTextUIActive then
                lib.hideTextUI()
                tiendaTextUIActive = false
            end
            lastTiendaCercana = nil
            puedeAbrirTienda = false
        end
        -- Detectar pulsación de E para abrir tienda
        if puedeAbrirTienda and lastTiendaCercana and IsControlJustReleased(0, 38) then -- E
            TriggerServerEvent("tienda:abrirTienda", lastTiendaCercana.name)
            Wait(500) -- Evita doble apertura
        end
    end
end)

function setupQbTargetShops()
    -- Eliminar zonas anteriores si existen
    for _, zone in ipairs(createdZones) do
        exports.ox_target:removeZone(zone)
    end
    createdZones = {}

    for _, tienda in pairs(tiendasRegistradas or {}) do
        local coords = tienda.coords
        if type(coords) == "table" then
            coords = vector3(coords.x, coords.y, coords.z)
        end

        local tiendaName = tienda.name
        -- Crear una zona usando ox_target
        local zoneId = exports.ox_target:addSphereZone({
            coords = coords,
            radius = 1.5,
            debug = false,
            options = {
                {
                    name = 'tienda_' .. tiendaName,
                    icon = 'fas fa-store',
                    label = 'Abrir tienda',
                    onSelect = function()
                        print("[DEBUG] Intentando abrir tienda desde ox_target:", tiendaName)
                        TriggerServerEvent("tienda:abrirTienda", tiendaName)
                    end,
                    distance = 2.5
                }
            }
        })
        table.insert(createdZones, zoneId)
    end
end

-- Si quieres mantener el marker y texto 3D para debug, puedes dejar el bucle, pero ya no es necesario con qb-target.

RegisterNetEvent("tienda:abrirEditorItems", function(shopName)
    if lib and lib.showTextUI then
        lib.showTextUI('Edita los ítems de la tienda: ' .. shopName .. '\nUsa el comando /guardaritems cuando termines.', {
            position = 'top-center',
            icon = 'box',
            style = { backgroundColor = '#222E50', color = '#fff' }
        })
        SetTimeout(7000, function()
            if lib and lib.hideTextUI then lib.hideTextUI() end
        end)
    else
        TriggerEvent('chat:addMessage', { args = { 'Sistema de Tiendas', 'Edita los ítems de la tienda: ' .. shopName } })
    end
end)

RegisterNetEvent("tienda:mostrarMenuTienda", function(tienda)
    print("[DEBUG] Recibido tienda para mostrar menú:", json.encode(tienda))
    local options = {}

    if not tienda.items or #tienda.items == 0 then
        table.insert(options, { title = "Sin productos", description = "Esta tienda no tiene productos aún.", icon = "ban" })
    else
        for _, item in ipairs(tienda.items) do
            table.insert(options, {
                title = item.label or item.name or "Item",
                description = "Cantidad: " .. (item.amount or 1) .. " | Precio: $" .. (item.price or 0),
                icon = "box",
                image = "nui://ox_inventory/web/images/" .. item.name .. ".png",
                onSelect = function()
                    local cantidad = lib.inputDialog('Comprar ' .. (item.label or item.name), {
                        {type = 'number', label = 'Cantidad a comprar', required = true, min = 1, max = item.amount or 1}
                    })
                    if cantidad and cantidad[1] and cantidad[1] > 0 then
                        local precio = item.price or 0
                        local totalPrecio = precio * cantidad[1]
                        local confirm = lib.alertDialog({
                            header = 'Confirmar compra',
                            content = ('¿Comprar %sx %s por $%s?'):format(cantidad[1], item.label or item.name, totalPrecio),
                            centered = true,
                            cancel = true
                        })
                        if confirm == 'confirm' then
                            TriggerServerEvent("tienda:comprarItem", tienda.name, item.name, cantidad[1], precio)
                        end
                    end
                end
            })
        end
    end

    lib.registerContext({
        id = 'menu_tienda_' .. tienda.name,
        title = 'Tienda: ' .. tienda.name,
        options = options
    })
    lib.showContext('menu_tienda_' .. tienda.name)
end)

CreateThread(function()
    Wait(2000) -- Espera a que el jugador esté completamente cargado
    TriggerServerEvent("tienda:solicitarTiendas")
end)

RegisterCommand("gestiontiendas", function()
    TriggerServerEvent("tienda:solicitarTiendasGestion")
end)

RegisterNetEvent("tienda:abrirMenuGestionTiendas", function(tiendas)
    local opcionesTiendas = {}
    for _, tienda in ipairs(tiendas) do
        table.insert(opcionesTiendas, {
            title = tienda.name,
            description = "Slots: " .. tienda.slots .. " | Productos: " .. #tienda.items,
            onSelect = function()
                -- Submenú de opciones para la tienda
                lib.registerContext({
                    id = 'menu_tienda_opciones_' .. tienda.name,
                    title = 'Opciones para ' .. tienda.name,
                    menu = 'menu_gestion_tiendas',
                    options = {
                        {
                            title = "Gestionar productos",
                            description = "Añadir, editar o eliminar productos",
                            icon = "box",
                            onSelect = function()
                                abrirMenuGestionProductos(tienda)
                            end
                        },
                        {
                            title = "Eliminar tienda",
                            description = "Eliminar completamente esta tienda",
                            icon = "trash",
                            onSelect = function()
                                eliminarTienda(tienda)
                            end
                        }
                    }
                })
                lib.showContext('menu_tienda_opciones_' .. tienda.name)
            end
        })
    end

    lib.registerContext({
        id = 'menu_gestion_tiendas',
        title = 'Gestión de Tiendas',
        options = opcionesTiendas
    })
    lib.showContext('menu_gestion_tiendas')
end)

function abrirMenuGestionProductos(tienda)
    local opcionesProductos = {}
    
    -- Añadir cada producto como una opción
    for idx, item in ipairs(tienda.items) do
        table.insert(opcionesProductos, {
            title = (item.label or item.name) .. " (" .. (item.amount or 1) .. ")",
            description = "Precio: $" .. (item.price or 0),
            image = "nui://ox_inventory/web/images/" .. item.name .. ".png",
            onSelect = function()
                -- Mostrar submenú para editar o eliminar
                lib.registerContext({
                    id = 'menu_item_opciones_' .. tienda.name .. '_' .. idx,
                    title = 'Opciones para ' .. (item.label or item.name),
                    menu = 'menu_gestion_productos_' .. tienda.name,
                    options = {
                        {
                            title = "Editar producto",
                            description = "Modificar nombre, cantidad y precio",
                            icon = "edit",
                            onSelect = function()
                                editarProductoTienda(tienda, idx)
                            end
                        },
                        {
                            title = "Eliminar producto",
                            description = "Quitar este producto de la tienda",
                            icon = "trash",
                            onSelect = function()
                                eliminarProductoTienda(tienda, idx)
                            end
                        }
                    }
                })
                lib.showContext('menu_item_opciones_' .. tienda.name .. '_' .. idx)
            end
        })
    end

    -- Agregar opciones adicionales
    table.insert(opcionesProductos, {
        title = "Agregar nuevo producto",
        icon = "plus",
        onSelect = function()
            agregarProductoTienda(tienda)
        end
    })

    table.insert(opcionesProductos, {
        title = "Guardar cambios",
        icon = "save",
        onSelect = function()
            TriggerServerEvent("tienda:guardarItemsGestion", tienda.name, tienda.items)
        end
    })

    lib.registerContext({
        id = 'menu_gestion_productos_' .. tienda.name,
        title = 'Productos de ' .. tienda.name,
        options = opcionesProductos
    })
    lib.showContext('menu_gestion_productos_' .. tienda.name)
end

function editarProductoTienda(tienda, idx)
    local item = tienda.items[idx]
    local input = lib.inputDialog('Editar producto', {
        {type = 'input', label = 'Nombre del item', default = item.name, required = true},
        {type = 'input', label = 'Label', default = item.label, required = true},
        {type = 'number', label = 'Cantidad', default = item.amount or 1, required = true},
        {type = 'number', label = 'Precio', default = item.price or 0, required = true}
    })
    if input then
        tienda.items[idx] = {
            name = input[1],
            label = input[2],
            amount = tonumber(input[3]),
            price = tonumber(input[4])
        }
        abrirMenuGestionProductos(tienda)
    else
        abrirMenuGestionProductos(tienda)
    end
end

function agregarProductoTienda(tienda)
    local input = lib.inputDialog('Agregar producto', {
        {type = 'input', label = 'Nombre del item', required = true},
        {type = 'input', label = 'Label', required = true},
        {type = 'number', label = 'Cantidad', required = true},
        {type = 'number', label = 'Precio', required = true}
    })
    if input then
        table.insert(tienda.items, {
            name = input[1],
            label = input[2],
            amount = tonumber(input[3]),
            price = tonumber(input[4])
        })
        abrirMenuGestionProductos(tienda)
    else
        abrirMenuGestionProductos(tienda)
    end
end

function eliminarProductoTienda(tienda, idx)
    local item = tienda.items[idx]
    local confirmDelete = lib.alertDialog({
        header = 'Confirmar eliminación',
        content = '¿Estás seguro que deseas eliminar ' .. (item.label or item.name) .. '?',
        centered = true,
        cancel = true
    })
    
    if confirmDelete == 'confirm' then
        table.remove(tienda.items, idx)
        lib.notify({
            title = 'Producto eliminado',
            description = 'El producto ha sido eliminado de la tienda',
            type = 'success'
        })
        abrirMenuGestionProductos(tienda)
    else
        abrirMenuGestionProductos(tienda)
    end
end

function eliminarTienda(tienda)
    local confirmDelete = lib.alertDialog({
        header = 'Confirmar eliminación de tienda',
        content = '¿Estás seguro que deseas eliminar completamente la tienda "' .. tienda.name .. '"? Esta acción no se puede deshacer.',
        centered = true,
        cancel = true
    })
    
    if confirmDelete == 'confirm' then
        -- Confirmar eliminación con un segundo prompt para mayor seguridad
        local secondConfirm = lib.inputDialog('Confirmar eliminación', {
            {type = 'input', label = 'Escribe el nombre de la tienda para confirmar', description = 'Escribe "' .. tienda.name .. '" para confirmar', required = true},
        })
        
        if secondConfirm and secondConfirm[1] == tienda.name then
            TriggerServerEvent("tienda:eliminarTienda", tienda.name)
            lib.notify({
                title = 'Tienda eliminada',
                description = 'La tienda "' .. tienda.name .. '" ha sido eliminada',
                type = 'success'
            })
            Wait(500) -- Esperar a que se actualice la base de datos
            TriggerServerEvent("tienda:solicitarTiendasGestion") -- Actualizar lista de tiendas
        else
            lib.notify({
                title = 'Acción cancelada',
                description = 'El nombre no coincide, la tienda no ha sido eliminada',
                type = 'error'
            })
            Wait(500)
            TriggerServerEvent("tienda:solicitarTiendasGestion")
        end
    else
        TriggerServerEvent("tienda:solicitarTiendasGestion")
    end
end

