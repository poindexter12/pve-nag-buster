## pve-nag-buster
https://github.com/poindexter12/pve-nag-buster

`pve-nag-buster` is a dpkg hook script that persistently removes license nags
from Proxmox VE 6.x through 9.x. Install it once and you won't see another license
nag until the Proxmox team changes their web-ui code in a way that breaks the patch.

Please support the Proxmox team by [buying a subscription](https://www.proxmox.com/en/proxmox-ve/pricing) if it's within your
means. High quality open source software like Proxmox needs our support!

### Compatibility

| PVE Version | Status | Notes |
|-------------|--------|-------|
| 9.x | ✅ Supported | Function wrapper injection + deb822 repos |
| 8.x | ✅ Supported | Function wrapper injection + deb822 repos |
| 7.x | ✅ Supported | Function wrapper injection |
| 6.x | ✅ Supported | Legacy conditional replacement |

Last updated: December 2025

### How does it work?

The hook script patches `/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js`
to disable the subscription check popup. It uses two strategies:

1. **Function wrapper injection** (PVE 7+): Injects an early return into the
   subscription check callback, bypassing the check entirely
2. **Legacy conditional replacement** (PVE 6): Replaces the status check
   conditional with `false`

The installer also:
- Disables the enterprise repository (both `.list` and `.sources` formats)
- Sets up Proxmox, Ceph, and Debian no-subscription repositories
- Installs a dpkg hook that reapplies the patch after `proxmox-widget-toolkit` or `pve-manager` updates

No external dependencies beyond the base PVE installation.

### Installation

```sh
wget https://raw.githubusercontent.com/poindexter12/pve-nag-buster/master/install.sh

# Always read scripts downloaded from the internet before running them with sudo
sudo bash install.sh
```

With Git:
```sh
git clone https://github.com/poindexter12/pve-nag-buster.git
cd pve-nag-buster && sudo ./install.sh
```

### Uninstall

```sh
sudo ./install.sh --uninstall
```

The uninstaller removes the hook script and dpkg configuration but leaves the
apt sources files intact. Delete them manually if desired:
- `/etc/apt/sources.list.d/pve-no-subscription.sources`
- `/etc/apt/sources.list.d/ceph-no-subscription.sources`
- `/etc/apt/sources.list.d/debian.sources`

### Project Structure

```
source/
├── base.sh              # Installer logic
├── buster.sh            # Hook script (nag removal + repo disabling)
├── apt.sources.proxmox  # Proxmox no-subscription repo template
├── apt.sources.ceph     # Ceph no-subscription repo template
├── apt.sources.debian   # Debian repo template
├── apt.conf.buster      # dpkg hook configuration
└── build.sh             # Assembles install.sh from components
```

To rebuild `install.sh` after modifying source files:
```sh
./source/build.sh
```

### Thanks to

- John McLaren for his [blog post](https://mclarendatasystems.com/remove-proxmox51-subscription-notice/) documenting the web GUI patch
- [Marlin Sööse](https://github.com/msoose) for the PVE 6.3+ update
- [diamondpete](https://github.com/diamondpete/pve-nag-buster) for the modular source structure

### Contact

[Open an issue](https://github.com/poindexter12/pve-nag-buster/issues) on GitHub

Please get in touch if you find a way to improve anything, otherwise enjoy!
