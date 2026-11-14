# FunctionKeysSwitcher

FunctionKeysSwitcher automatically switches macOS between standard
F1-F12 keys and media keys depending on the currently active application.

It runs silently in the background as a native macOS LaunchAgent.

No polling, GUI scripting, Automator workflow, or Accessibility permission
is required.

## How it works

FunctionKeysSwitcher listens for:

    NSWorkspaceDidActivateApplicationNotification

macOS therefore informs the application whenever the foreground application
changes.

If the active application's Bundle Identifier is listed in `apps.conf`,
standard F1-F12 keys are enabled.

For all other applications, macOS media keys are enabled.

Changes are applied using:

    defaults write -g com.apple.keyboard.fnState

followed by:

    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

This causes the keyboard setting to take effect immediately.

## Requirements

- macOS
- Apple Command Line Tools
- clang

If necessary, install the Command Line Tools with:

    xcode-select --install

## Installation

Clone the repository:

    git clone https://github.com/HerrHaseGermany/FunctionKeysSwitcher.git

Enter the directory:

    cd FunctionKeysSwitcher

Make the scripts executable:

    chmod +x install.sh update.sh uninstall.sh

Install:

    ./install.sh

The installer compiles the native Objective-C application and installs it to:

    ~/Library/Application Support/FunctionKeysSwitcher/

The LaunchAgent is installed to:

    ~/Library/LaunchAgents/de.raudzis.function-keys-switcher.plist

## Configuration

Edit:

    ~/Library/Application Support/FunctionKeysSwitcher/apps.conf

Add one macOS Bundle Identifier per line.

Example:

    com.blizzard.worldofwarcraft

Applications listed here will use standard F1-F12 keys.

All other applications will use the normal macOS media-key behavior.

After changing the configuration, restart the service:

    launchctl kickstart -k gui/$(id -u)/de.raudzis.function-keys-switcher

## Finding Bundle Identifiers

While FunctionKeysSwitcher is running, application changes are written to:

    ~/Library/Logs/FunctionKeysSwitcher.log

Watch the log with:

    tail -f ~/Library/Logs/FunctionKeysSwitcher.log

Example:

    Active application: Wow | Bundle ID: com.blizzard.worldofwarcraft

You can then add the Bundle Identifier to `apps.conf`.

## Version

    ~/Library/Application\ Support/FunctionKeysSwitcher/function-keys-switcher --version

## List configured applications

    ~/Library/Application\ Support/FunctionKeysSwitcher/function-keys-switcher --list

## Status

    launchctl print gui/$(id -u)/de.raudzis.function-keys-switcher

## Restart

    launchctl kickstart -k gui/$(id -u)/de.raudzis.function-keys-switcher

## Update

From the cloned repository:

    ./update.sh

The existing user configuration is preserved.

## Uninstall

    ./uninstall.sh

The configuration file is intentionally preserved.

## Important note

FunctionKeysSwitcher uses Apple's private `activateSettings` utility located
inside `SystemAdministration.framework`.

This is not a public macOS API and Apple may change or remove it in a future
macOS release.

The current implementation has been tested on macOS 26.

## Karabiner-Elements and F4

A Karabiner rule that opens Launchpad with F4 takes precedence over the
macOS function-key setting. Add a `frontmost_application_unless` condition
to that rule's Launchpad manipulators to keep F4 available in WoW:

```json
{
    "type": "frontmost_application_unless",
    "bundle_identifiers": ["^com\\.blizzard\\.worldofwarcraft$"]
}
```

## Development check

Run the regression check for overlapping application activations and failed
settings commands without changing the keyboard settings:

```sh
clang -fobjc-arc -fblocks -framework Cocoa tests/switching-reentrancy.m -o /tmp/fks-test
/tmp/fks-test
```

## License

MIT