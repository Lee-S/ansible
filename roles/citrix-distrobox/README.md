# Citrix Distrobox Role

This role installs Citrix Workspace (ICA client) inside an Ubuntu distrobox on Fedora-based distributions. This is useful when the Citrix client is not readily available or has compatibility issues on Fedora/Nobara.

## Overview

The role performs the following tasks:
1. Verifies the system is Fedora/RedHat-based (Nobara, Fedora, RHEL, CentOS)
2. Installs distrobox if not already present
3. Creates an Ubuntu 22.04 distrobox container
4. Installs required dependencies in the distrobox:
   - GUI libraries (GTK3, WebKit2GTK, ATK)
   - X11/keyboard/cursor support (libxkbcommon, libxcursor, xcursor-themes)
   - GPU drivers (Mesa Vulkan, AMD/Intel GPU support)
   - Video acceleration (VA-API, VDPAU)
   - Audio support (PulseAudio, Speex)
   - Other Citrix dependencies (GStreamer, CUPS)
5. Installs Citrix Workspace app (icaclient) inside the distrobox
6. Creates a wrapper script (`/usr/local/bin/citrix-ica`) to launch the client
7. Sets up .desktop file for GUI integration
8. Configures .ica file associations to automatically open with Citrix Workspace

## Requirements

- Fedora-based distribution (Nobara, Fedora, RHEL, CentOS)
- Podman or Docker (distrobox dependency)
- Internet connection for downloading Ubuntu image
- **Citrix Workspace .deb file** in `~/Downloads/` (see Prerequisites section below)

## Prerequisites

Before running this role, download Citrix Workspace app:

1. Visit [Citrix Workspace Downloads](https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html)
2. Click **"Download Citrix Workspace app for Linux (x86_64)"**
3. Save the `icaclient*.deb` file to your **Downloads** folder (`~/Downloads/`)

The role will automatically find and use the latest `icaclient*.deb` file in your Downloads folder.

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `distrobox_name` | `ubuntu-citrix` | Name of the distrobox container |
| `distrobox_image` | `ubuntu:22.04` | Ubuntu image to use for distrobox |
| `create_desktop_entry` | `yes` | Whether to create desktop entry and file associations |

**Note:** The role automatically detects the actual user (via `$SUDO_USER`) and finds the latest `icaclient*.deb` file in their `~/Downloads/` directory.

## Tags

- `citrix-distrobox` - All tasks
- `distrobox-install` - Install distrobox package
- `distrobox-setup` - Create and configure distrobox
- `citrix-install` - Install Citrix Workspace in distrobox
- `citrix-wrapper` - Create wrapper script
- `citrix-desktop` - Desktop integration and file associations

## Usage

**Important:** Before running, make sure you have downloaded the Citrix Workspace .deb file to `~/Downloads/` (see Prerequisites above).

### Run the full role

```bash
ansible-playbook local_setup.yml --tags "citrix-distrobox" --ask-become-pass
```

### Run only distrobox creation

```bash
ansible-playbook local_setup.yml --tags "distrobox-setup" --ask-become-pass
```

### Run only Citrix installation

```bash
ansible-playbook local_setup.yml --tags "citrix-install" --ask-become-pass
```

## Post-Installation

After installation, .ica files should automatically open with Citrix Workspace. You can also:

### Launch manually

```bash
# Using the wrapper script
/usr/local/bin/citrix-ica /path/to/file.ica

# Entering the distrobox directly
distrobox enter ubuntu-citrix
/opt/Citrix/ICAClient/wfica /path/to/file.ica
```

### Manage the distrobox

```bash
# List distroboxes
distrobox list

# Enter the distrobox
distrobox enter ubuntu-citrix

# Stop the distrobox
distrobox stop ubuntu-citrix

# Remove the distrobox
distrobox rm ubuntu-citrix
```

## Troubleshooting

### Distrobox not found
Ensure distrobox is installed:
```bash
sudo dnf install distrobox
```

### Container creation fails
Check podman/docker status:
```bash
podman ps -a
```

### Citrix client doesn't launch
Test the distrobox manually:
```bash
distrobox enter ubuntu-citrix
/opt/Citrix/ICAClient/wfica --version
```

### File associations not working
Update the desktop database manually:
```bash
sudo update-desktop-database /usr/share/applications
sudo update-mime-database /usr/share/mime
xdg-mime default citrix-ica.desktop application/x-ica
```

## Notes

- This role is designed for Fedora-based systems only and will fail on Debian/Ubuntu
- The distrobox uses Ubuntu 22.04 as the base image for Citrix compatibility
- The first run may take several minutes to download the Ubuntu image
- The Citrix client runs in the distrobox but appears as a native application
