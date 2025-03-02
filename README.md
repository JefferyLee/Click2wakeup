# Click2wakeup

A macOS app for Wake-on-LAN functionality

A macOS status bar button, click it to wake up other mac by sending wake-on-lan packet.
The name of the added device will show when click the button on status bar, then click the device name to wake it up.
Two more menu items to manage device list showing below the device list:

- "Add Device" to add a device mac address with a name
- "Manage Device" to delete a device.

## Features

- Lightweight macOS menu bar application
- Store and manage multiple devices
- Send Wake-on-LAN packets with a single click
- Notification feedback when wake packets are sent
- Simple device management interface

## Requirements

- macOS 11.0 or later

## Usage

1. Add devices by selecting "Add Device" from the menu
2. Enter a name and MAC address for the device
3. Click on a device name in the menu to send a Wake-on-LAN packet
4. Manage your devices with "Manage Devices" option

## Notes

For Wake-on-LAN to work properly:

- The target device must support and have Wake-on-LAN enabled in its BIOS/firmware
- The target device must be on the same network (or accessible through your router)
- Some routers may block Wake-on-LAN packets - check your router settings if needed

## License

MIT
