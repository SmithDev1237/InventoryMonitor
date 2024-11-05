# InventoryMonitor

**Author**: Fyayu  
**Version**: 0.8  
**Description**: Monitor your inventory and wardrobes to ensure you never run out of supplies.

## Overview

`InventoryMonitor` is an Ashita V4 addon for Final Fantasy XI that helps players keep track of their inventory items and equipment charges. This is particularly useful for monitoring consumable items such as shihei or bolts, preventing any surprises during critical moments in the game.

## Features

- **Inventory Tracking**: Monitors item counts across multiple containers (including the main inventory, mog satchel, and wardrobes).
- **Charge Monitoring**: Keeps track of equipment charges, showing their status and remaining time.
- **Configurable Limits**: Allows users to set critical and warning limits for items, with color-coded alerts for easy monitoring.
- **Dynamic UI**: Built with ImGui for an interactive and customizable user interface.

## Installation

To install the `InventoryMonitor` addon:

1. **Download the addon**: Clone or download the repository.
2. **Place the addon**: Move the `InventoryMonitor` folder into your Ashita V4 `addons` directory.
3. **Load the addon**: Start Final Fantasy XI and use the command `/addon load InventoryMonitor` in the chat.

## Usage

### Configuring Items

1. **Add New Item**: In the configuration section, enter the Item ID, Critical Limit, and Warning Limit.
2. **Remove Item**: Click the "X" button next to the item name to remove it from tracking.

### Monitoring Items and Charges

- The main window will display tracked items along with their inventory counts and satchel counts.
- Charges for equipment will also be displayed with their current status and time remaining until they are ready to use.

### Toggle Configuration

- Use the **Config** button to toggle the visibility of the configuration section, allowing you to add or remove items and adjust settings dynamically.

### Example UI

| ![Example of the monitor](https://github.com/SmithDev1237/InventoryMonitor/blob/main/img/Example.jpg) | ![Config Mode](https://github.com/SmithDev1237/InventoryMonitor/blob/main/img/Config.jpg) |
|-----------------------------------------------------|----------------------------------------------|
| Example of item monitoring                          | Configuration interface                      |

## Item IDs

To find Item IDs for your inventory, you can use resources like [FFXIAH](https://www.ffxiah.com/ "FFXIAH").

## Configuration

The addon maintains a configuration file where it stores tracked items and their limits. It also saves the font size for the display. The default font size is set to 1.0 (100% scale).

## Additional Information

- The addon has been tested on the HorizonXI server; compatibility with retail servers may vary.
- Feel free to modify and contribute to the code as it is open source!

## License

This addon is released under the MIT License. You are free to use, modify, and distribute this software as you see fit.

## Acknowledgements

Thanks to the FFXI community for their ongoing support and contributions, which have helped shape this addon.
