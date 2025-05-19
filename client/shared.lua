-- Shared variables between client files
QBCore = exports['qb-core']:GetCoreObject()
Shops = {}

-- Expose the Shops variable to other files (global function)
_G.GetShops = function()
    return Shops
end

-- Update the Shops variable (global function)
_G.UpdateShops = function(newShops)
    Shops = newShops
    return Shops
end
