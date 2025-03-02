# Click2wakeup Troubleshooting Guide

## Common Errors and Solutions

### 1. Core Data Error: "Context in environment is not connected to a persistent store coordinator"

**Problem Description**: This error occurs when the application starts, indicating that the app cannot properly connect to the Core Data store.

**Solutions**:

- Make sure the application has permission to access the documents directory
- Check the logs in the Console app for detailed error information
- If the problem persists, try deleting the app and reinstalling, or manually delete the Core Data store with the following steps:
  ```
  defaults delete com.yourdomain.Click2wakeup
  rm -rf ~/Library/Containers/com.yourdomain.Click2wakeup/Data/Library/Application\ Support/Click2wakeup
  ```

### 2. Network Error: "Error sending Wake-on-LAN packet: POSIXErrorCode(rawValue: 89): Operation canceled"

**Problem Description**: This error occurs when trying to send a wake-up packet, indicating that the application does not have sufficient network permissions.

**Solutions**:

1. Ensure all required network permission items are added to Info.plist:

   - `LSUIElement` = `YES`
   - `NSLocalNetworkUsageDescription` = Appropriate description text
   - `NSBonjourServices` = `_wol._udp`
   - `NSAllowsLocalNetworking` = `YES`
   - `NSAllowsBroadcasting` = `YES`

2. Make sure the application is allowed to connect in System Preferences > Security & Privacy > Firewall

3. Try opening the application using the right-click menu instead of double-clicking, as this can sometimes trigger the correct permission request dialog

4. Ensure your network configuration allows broadcast packets (some enterprise or secured networks may block them)

### 3. Status Bar Icon Not Visible

**Problem Description**: The application seems to be running, but the icon is not visible in the status bar.

**Solutions**:

- Make sure `LSUIElement` = `YES` is set in Info.plist
- Check if the application process is running in Activity Monitor
- Restart the application
- If the status bar is full, you may need to expand it or close some other applications

### 4. Wake-up Command Fails to Wake the Device

**Problem Description**: The application sends a wake-up packet, but the target device does not wake up.

**Solutions**:

1. Confirm the target device is properly configured to support Wake-on-LAN:

   - Enable WoL functionality in BIOS/UEFI
   - Configure the network adapter to allow waking the computer in the operating system
   - Some devices may require specific wake-up settings (such as NAS devices)

2. Confirm the MAC address format is correct, the XX:XX:XX:XX:XX:XX format is recommended

3. Make sure the device and the computer sending the wake-up packet are on the same local network

4. Some routers may block broadcast packets, check your router settings

## Debugging Tips

### View Detailed Logs

The application outputs detailed debug information to the system log. To view these logs:

1. Open the Console application (located in /Applications/Utilities)
2. Enter "Click2wakeup" in the search box
3. View related messages for more error details

### Test Network Connection

To test if your network allows sending Wake-on-LAN packets:

```bash
# Install the wakeonlan tool
brew install wakeonlan

# Try sending a wake-up packet
wakeonlan XX:XX:XX:XX:XX:XX
```

If the wakeonlan tool works properly but Click2wakeup does not, it may be an application permission issue.

### Application Reset

If the application has serious issues, try a complete reset:

1. Quit the application
2. Delete application data:
   ```
   defaults delete com.yourdomain.Click2wakeup
   rm -rf ~/Library/Containers/com.yourdomain.Click2wakeup
   rm -rf ~/Library/Application\ Support/Click2wakeup
   ```
3. Restart the application

## Contact Support

If you have tried all the above methods and still cannot solve the problem, please provide the following information when contacting support:

1. macOS version
2. Application version
3. Detailed error messages
4. Relevant logs from the Console application
5. Solutions you have tried

---

We hope this guide helps you solve problems you encounter when using Click2wakeup. We will continuously update this document to cover more common issues.
