# ZK-SHOP-UX

## Overview
ZK-SHOP-UX is a custom shop management system for FiveM servers that utilizes the ox_inventory interface. This resource allows server administrators to easily create and manage various shops throughout the game world, providing players with a seamless shopping experience through the ox_inventory UI.

## Features
- Integration with ox_inventory for a consistent user interface
- Easy configuration of multiple shops with custom inventories
- Support for item limits and shop customization
- Boss menu functionality for shop management
- Optimized performance with low resource usage

## Dependencies
- [ox_inventory](https://github.com/overextended/ox_inventory) - Required for the inventory interface
- [es_extended](https://github.com/esx-framework/esx-legacy) (ESX) or compatible framework

## Installation
1. Ensure you have the required dependencies installed and properly configured
2. Place the `zk-shop-ux` folder in your server's `resources/[interfaz]` directory
3. Add `ensure zk-shop-ux` to your server.cfg file
4. Configure the shops in the `config.lua` file
5. Start or restart your server

## Configuration

All shop configurations are managed in the `config.lua` file. Here's an example configuration:

```lua
Config = {}

Config.Tiendas = {
  {
    name = "burger",                       -- Unique shop identifier
    coords = { x = 123.4, y = 456.7, z = 78.9 }, -- Shop location
    slots = 10,                           -- Inventory slots
    items = {
      { name = "agua", label = "Agua", amount = 10 },
      { name = "pan", label = "Pan", amount = 5 }
    }
  },
  -- Add more shops here
}
```

For each shop, you must specify:
- `name`: A unique identifier for the shop
- `coords`: The x, y, z coordinates where the shop can be accessed
- `slots`: The number of inventory slots available in the shop
- `items`: An array of items available in the shop, each with name, label, and amount

## Usage

Players can approach configured shop locations to open the shop interface. The shop will display in the familiar ox_inventory UI, allowing players to easily purchase items.

Shop owners with the appropriate permissions can access the boss menu to manage inventory, prices, and other shop settings.

## License

This resource is protected under copyright law. Unauthorized distribution, modification, or commercial use is prohibited without explicit permission.

## Credits

Developed by ZK GHOST NET (ZKGH0STNET)
