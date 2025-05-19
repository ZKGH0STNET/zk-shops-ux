fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'zk-shop-ux'
author 'ZK-GHOST'
description 'Advanced shop system with ox_inventory-like UI'
version '2.0.0'

-- Dependencies
dependency 'ox_lib'
dependency 'oxmysql'
dependency 'qb-core'

-- Shared scripts
shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

-- Client scripts
client_scripts {
    'client/main.lua',
    'client/ui.lua',
    'client/zones.lua',
    'client/commands.lua',
    'client/bossmenu.lua',
    'client/teleport.lua',
    'client/boss_commands.lua'
}

-- Server scripts
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/database.lua',
    'server/discord.lua',
    'server/bossmenu.lua',
    'server/boss_commands.lua',
    'server/dbcheck.lua'
}

-- UI resources
ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/script.js',
    'web/images/*.png'
}

-- Make sure data gets reset on resource restart
server_exports {
    'getShopData',
    'createShop',
    'deleteShop',
    'updateShopItems'
}

-- Client exports
client_exports {
    'OpenShopBossMenu'
}
