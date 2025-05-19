-- Zone management for zk-shop-ux
local QBCore = exports['qb-core']:GetCoreObject()
local ActiveZones = {}
local ShopBlips = {}
-- Using global Shops variable from main.lua

-- Function to clean up a specific shop zone
function CleanupShopZone(shopName)
    if not shopName then return end
    
    print('[ZK-SHOPS] Cleaning up zone for shop: ' .. shopName)
    
    -- Remove the shop zone by its ID pattern
    if exports.ox_target then
        pcall(function()
            -- Try standard pattern
            local zoneId = 'shop_' .. shopName
            exports.ox_target:removeZone(zoneId)
            
            -- Try more specific pattern (for older zones that might exist)
            local oldPattern = 'shop_' .. shopName .. '_*' 
            exports.ox_target:removeZone(oldPattern)
            
            -- Also try with wildcard
            exports.ox_target:removeZone('shop_' .. shopName .. '*')
        end)
    end
    
    -- Search and remove from ActiveZones array
    for i=#ActiveZones, 1, -1 do
        if ActiveZones[i] and string.find(tostring(ActiveZones[i]), shopName) then
            table.remove(ActiveZones, i)
        end
    end
end

-- Clear all active target zones
function ClearAllZones()
    print('[ZK-SHOPS] Clearing ' .. #ActiveZones .. ' zones')
    
    -- Remove all active zones by zone object
    for i, zone in ipairs(ActiveZones) do
        if exports.ox_target then
            -- Using pcall to prevent errors if a zone doesn't exist anymore
            pcall(function()
                exports.ox_target:removeZone(zone)
            end)
        end
    end
    
    -- More aggressive cleanup - attempt to remove zones by pattern
    if exports.ox_target then
        -- Try to clear any zone with 'shop_' in the name
        pcall(function()
            exports.ox_target:removeZone('shop_*')
        end)
        
        -- Try using a loop approach for more specific patterns
        if Shops and type(Shops) == 'table' then
            for _, shop in ipairs(Shops) do
                if shop and shop.name then
                    CleanupShopZone(shop.name)
                end
            end
        end
        
        -- Brute force approach as a last resort
        pcall(function()
            if exports.ox_target.removeZone then
                for i=1, 100 do -- More reasonable limit
                    exports.ox_target:removeZone('shop_' .. i)
                end
            end
        end)
        
        -- Also try the removeZoneByName event
        pcall(function()
            TriggerEvent('ox_target:removeZoneByName', 'shop_')
        end)
    end
    
    -- Reset active zones array
    ActiveZones = {}
    
    -- Force a garbage collection to help clean up any lingering references
    collectgarbage('collect')
end

-- Clear all shop blips
function ClearAllBlips()
    for _, blip in ipairs(ShopBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    ShopBlips = {}
end

-- Create a blip for a shop
function CreateShopBlip(shop)
    if not shop or not shop.coords then return end
    
    local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
    
    SetBlipSprite(blip, Config.BlipSettings.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, Config.BlipSettings.scale)
    SetBlipColour(blip, Config.BlipSettings.color)
    SetBlipAsShortRange(blip, true)
    
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.BlipSettings.name .. ': ' .. shop.name)
    EndTextCommandSetBlipName(blip)
    
    table.insert(ShopBlips, blip)
    return blip
end

-- Create a target zone for a shop
function CreateShopZone(shop)
    if not shop or not shop.coords then return end
    if not exports.ox_target then return end
    
    local shopName = shop.name
    local coords = vector3(shop.coords.x, shop.coords.y, shop.coords.z)
    
    -- First try to remove any existing zone for this shop to prevent duplicates
    pcall(function()
        local oldZonePattern = 'shop_' .. shopName .. '*'
        exports.ox_target:removeZone(oldZonePattern)
    end)
    
    -- Create a standardized identifier for this zone (simpler format for easier cleanup)
    local zoneId = 'shop_' .. shopName
    
    -- Create the zone
    local options = {
        {
            name = zoneId,
            icon = 'fas fa-store',
            label = 'Abrir tienda',
            onSelect = function()
                TriggerServerEvent('zk-shops:openShop', shopName)
            end,
            distance = Config.MaxShopDistance
        }
    }
    
    -- If the player is the owner or an admin, add management options
    local Player = QBCore.Functions.GetPlayerData()
    if Player and (Player.citizenid == shop.owner or IsPlayerAdmin()) then
        -- Standard management option
        table.insert(options, {
            name = zoneId .. '_manage',
            icon = 'fas fa-cog',
            label = 'Gestionar tienda',
            onSelect = function()
                OpenSingleShopManagementMenu(shop)
            end,
            distance = Config.MaxShopDistance
        })
        
        -- Boss menu option eliminado - ahora se usa el comando /bosstienda
    end
    
    -- Add sphere zone with options
    local zone = exports.ox_target:addSphereZone({
        coords = coords,
        radius = 1.5,
        debug = Config.Debug,
        options = options
    })
    
    if zone then
        table.insert(ActiveZones, zone)
        return zone
    end
    
    return nil
end

-- Refresh all blips
function RefreshAllBlips(shops)
    ClearAllBlips()
    
    if not shops or type(shops) ~= 'table' then return end
    
    for _, shop in ipairs(shops) do
        CreateShopBlip(shop)
    end
end

-- Refresh all target zones
function RefreshTargetZones(shops)
    ClearAllZones()
    
    if not shops then
        shops = Shops -- Use global variable if available
    end
    
    if not shops or type(shops) ~= 'table' then return end
    
    for _, shop in ipairs(shops) do
        CreateShopZone(shop)
    end
end

-- Check if the player is an admin
function IsPlayerAdmin()
    local Player = QBCore.Functions.GetPlayerData()
    if not Player or not Player.PlayerData then return false end
    
    if Player.PlayerData.permission then
        for _, adminGroup in ipairs(Config.AdminGroups) do
            if Player.PlayerData.permission == adminGroup then
                return true
            end
        end
    end
    
    return false
end
