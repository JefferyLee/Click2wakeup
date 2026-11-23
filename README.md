# Click2wakeup

A macOS menu bar app that wakes up other computers on your network with one click.

Click the ⏻ icon in the menu bar, then click a device name. Each device uses one of two methods:

| Method | Use it for | How it works |
|---|---|---|
| 🖥 **Turn On Display** | A Mac that's awake but has its screen off (e.g. so you can move your mouse to it with Universal Control) | Logs in over SSH and runs `caffeinate -u`, which acts like someone touched the mouse. The screen stays on for 60 seconds, enough time to move your mouse over. |
| ⏻ **Wake-on-LAN** | A computer that's asleep | Broadcasts a Wake-on-LAN "magic packet" to its MAC address. |

## Requirements

- macOS 15.2 or later
- For **Turn On Display**: see [Setting up a Mac for "Turn On Display"](#setting-up-a-mac-for-turn-on-display)
- For **Wake-on-LAN**: the target must support Wake-on-LAN and be on the same network

## Usage

1. Menu bar ⏻ → **Add Device**
2. Pick a method:
   - **Turn On Display**: click **Find Macs on Network…** and choose the Mac (or type its host name, e.g. `Ada.local`). Click **Test** to check it works.
   - **Wake-on-LAN**: enter the device's MAC address.
3. Click **Add**. The device now appears in the menu. Click it to wake it.
4. **Manage Devices** lists and deletes devices.

If something fails, a notification explains why (e.g. "Remote Login is turned off on Ada.local").

## Setting up a Mac for "Turn On Display"

You do this once for each Mac you want to turn on.

**On the target Mac** (e.g. the Mac mini):
- System Settings → General → Sharing → turn on **Remote Login**.

**On this Mac**, set up password-free SSH login to it:
```sh
# Only if you don't already have a key (ls ~/.ssh/id_ed25519.pub):
ssh-keygen -t ed25519

# Copy your key to the target Mac (asks for its password once):
ssh-copy-id jeff@Ada.local

# Check: this should print "ok" without asking for a password:
ssh -o BatchMode=yes Ada.local echo ok
```

If your user name on the target Mac is different, enter the host as `username@Ada.local`. Host aliases from `~/.ssh/config` work too.

## Wake-on-LAN notes

- The target must have Wake-on-LAN enabled (on a Mac: System Settings → Energy → **Wake for network access**).
- On Macs, wired Ethernet is much more reliable than Wi-Fi for Wake-on-LAN.
- Wake-on-LAN only wakes a *sleeping* computer. It does not turn on the screen of a Mac that's already awake. Use **Turn On Display** for that.
- Apple Silicon Macs can't be woken from a full shutdown, only from sleep.

## Why the app isn't sandboxed

**Turn On Display** runs `/usr/bin/ssh` with your existing SSH keys and `~/.ssh/config`, which a sandboxed app can't read. The first launch of this version copies saved devices over from the old sandboxed location.

## Troubleshooting

Logs are in Console.app: filter by subsystem `com.satosium.Click2wakeup` (categories: `wake`, `discovery`, `persistence`, `app`). See also `Click2wakeup/TROUBLESHOOTING.md`.

## Development

Open `Click2wakeup.xcodeproj` in Xcode. Unit tests:
```sh
xcodebuild -project Click2wakeup.xcodeproj -scheme Click2wakeup -destination 'platform=macOS' test -only-testing:Click2wakeupTests
```

## License

MIT
