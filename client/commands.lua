-- Commands for zk-shop-ux
local QBCore = exports['qb-core']:GetCoreObject()
-- Config should be loaded globally from config.lua
-- Using global Shops variable from main.lua

-- Register all commands
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    -- Register create shop command (admin only)
    RegisterCommand('creartienda', function()
        -- No verificamos permisos en el cliente, lo enviamos al servidor para verificar
        TriggerServerEvent('zk-shops:checkAdminPermission', 'create')
    end)
    
    -- Register shop management command
    RegisterCommand('gestiontiendas', function()
        -- No verificamos permisos en el cliente, lo enviamos al servidor para verificar
        TriggerServerEvent('zk-shops:checkAdminPermission', 'manage')
    end)
    
    -- Register boss menu for shop owners
    RegisterCommand('bossmenu', function()
        local Player = QBCore.Functions.GetPlayerData()
        if not Player then return end
        
        -- Find shops owned by this player
        local ownedShops = {}
        for _, shop in ipairs(Shops) do
            if shop.owner == Player.citizenid then
                table.insert(ownedShops, shop)
            end
        end
        
        if #ownedShops == 0 then
            lib.notify({
                title = 'Sin tiendas',
                description = 'No eres dueño de ninguna tienda',
                type = 'error'
            })
            return
        end
        
        OpenBossMenu(ownedShops)
    end)
end)

-- Boss menu for shop owners
function OpenBossMenu(shops)
    if #shops == 1 then
        -- If only one shop, open it directly
        OpenSingleShopBossMenu(shops[1])
    else
        -- If multiple shops, show selection menu
        local options = {}
        
        for _, shop in ipairs(shops) do
            table.insert(options, {
                title = shop.name,
                description = 'Balance: $' .. shop.balance,
                icon = 'fas fa-store',
                onSelect = function()
                    OpenSingleShopBossMenu(shop)
                end
            })
        end
        
        lib.registerContext({
            id = 'boss_menu_shop_selection',
            title = 'Selecciona una tienda',
            options = options
        })
        
        lib.showContext('boss_menu_shop_selection')
    end
end

-- Boss menu for a single shop
function OpenSingleShopBossMenu(shop)
    local options = {
        {
            title = 'Retirar dinero',
            description = 'Balance: $' .. shop.balance,
            icon = 'fas fa-money-bill',
            onSelect = function()
                WithdrawShopMoney(shop)
            end,
            disabled = shop.balance <= 0
        },
        {
            title = 'Ver productos',
            description = 'Ver los productos disponibles',
            icon = 'fas fa-boxes',
            onSelect = function()
                OpenProductsManagementMenu(shop)
            end
        }
    }
    
    lib.registerContext({
        id = 'boss_menu_' .. shop.name,
        title = 'Boss Menu: ' .. shop.name,
        options = options
    })
    
    lib.showContext('boss_menu_' .. shop.name)
end

-- Withdraw money from shop
function WithdrawShopMoney(shop)
    local input = lib.inputDialog('Retirar dinero', {
        {
            type = 'number',
            label = 'Cantidad a retirar',
            default = shop.balance,
            min = 1,
            max = shop.balance,
            required = true
        }
    })
    
    if not input or not input[1] then return end
    
    local amount = tonumber(input[1])
    if amount <= 0 or amount > shop.balance then
        lib.notify({
            title = 'Error',
            description = 'Cantidad inválida',
            type = 'error'
        })
        return
    end
    
    -- Trigger event to withdraw money
    TriggerServerEvent('zk-shops:withdrawMoney', shop.name, amount)
end
