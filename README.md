## pve-nag-buster
https://github.com/foundObjects/pve-nag-buster

`pve-nag-buster` is a dpkg hook script that persistently removes license nags
from Proxmox VE 6.x through 9.x. Install it once and you won't see another license
nag until the Proxmox team changes their web-ui code in a way that breaks the patch.

Please support the Proxmox team by [buying a subscription](https://www.proxmox.com/en/proxmox-ve/pricing) if it's within your
means. High quality open source software like Proxmox needs our support!

### Compatibility:

| PVE Version | Status | Notes |
|-------------|--------|-------|
| 9.x | ✅ Supported | Function wrapper injection + deb822 repos |
| 8.x | ✅ Supported | Function wrapper injection + deb822 repos |
| 7.x | ✅ Supported | Function wrapper injection |
| 6.x | ✅ Supported | Legacy conditional replacement |

Last updated: December 2025 (v05)

### How does it work?

The hook script patches `/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js`
to disable the subscription check popup. It uses two strategies:

1. **Function wrapper injection** (PVE 7+): Injects an early return into the
   subscription check callback, bypassing the check entirely
2. **Legacy conditional replacement** (PVE 6): Replaces the status check
   conditional with `false`

The script also disables the enterprise repository (both `.list` and `.sources` formats)
and sets up the no-subscription repository.

A dpkg hook ensures the patch is automatically reapplied whenever `proxmox-widget-toolkit`
or `pve-manager` packages are updated. No external dependencies beyond the base
PVE installation.

### Installation
```sh
wget https://raw.githubusercontent.com/foundObjects/pve-nag-buster/master/install.sh

# Always read scripts downloaded from the internet before running them with sudo
sudo bash install.sh

# or ..
chmod +x install.sh && sudo ./install.sh
```

With Git:
```sh
git clone https://github.com/foundObjects/pve-nag-buster.git

# Always read scripts downloaded from the internet before running them with sudo
cd pve-nag-buster && sudo ./install.sh
```

### Uninstall:
```sh
sudo ./install.sh --uninstall
# remove /etc/apt/sources.list.d/pve-no-subscription.list if desired
```

### Notes:

#### Why is there base64 in my peanut-butter?

For convenience the install script also contains a base64 encoded copy of the
hook script, this makes installation possible without access to github or a
full clone of the project directory.

To inspect the base64 encoded script run `./install.sh --emit`; this dumps the
encoded copy to stdout and quits. To install using the stored copy just run
`sudo ./install.sh --offline`, no internet required.

### Thanks to:

- John McLaren for his [blog post](https://www.reddit.com/user/seaqueue) documenting the web gui patch.
- [Marlin Sööse](https://github.com/msoose) for the update for PVE 6.3+

### Contact:

[Open an issue](https://github.com/foundObjects/pve-nag-buster/issues) on GitHub

Please get in touch if you find a way to improve anything, otherwise enjoy!

