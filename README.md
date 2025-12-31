# pve-nag-buster

Persistently removes the "No valid subscription" popup from Proxmox VE 6.x–9.x.

Install once and the nag stays gone—even after package updates. A dpkg hook automatically reapplies the patch when `proxmox-widget-toolkit` or `pve-manager` is upgraded.

> **Note**: Please [buy a subscription](https://www.proxmox.com/en/proxmox-ve/pricing) if it's within your means. Proxmox is excellent open source software that deserves support.

## Compatibility

| PVE Version | Status | Method |
|-------------|--------|--------|
| 9.x | ✅ | Function wrapper injection |
| 8.x | ✅ | Function wrapper injection |
| 7.x | ✅ | Function wrapper injection |
| 6.x | ✅ | Legacy conditional replacement |

## Installation

```sh
# Clone and install
git clone https://github.com/poindexter12/pve-nag-buster.git
cd pve-nag-buster
sudo ./install.sh
```

Or download directly:
```sh
wget https://raw.githubusercontent.com/poindexter12/pve-nag-buster/master/install.sh
sudo bash install.sh
```

## Usage

```
sudo ./install.sh [OPTION]

Options:
  --install     Install pve-nag-buster (default)
  --uninstall   Remove hook script and dpkg hooks
  --restore     Restore proxmoxlib.js from backup
  --check       Dry-run mode: show what would change
  --help        Show help
  --version     Show version
```

## Makefile

For development, use the Makefile:

```sh
make help       # Show available commands
make build      # Build install.sh from source
make lint       # Run ShellCheck
make check      # Dry-run (requires root)
make install    # Install (requires root)
make uninstall  # Uninstall (requires root)
make restore    # Restore backup (requires root)
```

## How It Works

The script patches `/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js` to disable the subscription popup:

- **PVE 7–9**: Injects `orig_cmd(); return;` into the subscription callback wrapper
- **PVE 6**: Replaces `data.status.toLowerCase() !== 'active'` with `false`

The installer also:
- Disables enterprise repositories (`.list` and `.sources` formats)
- Configures Proxmox, Ceph, and Debian no-subscription repos
- Installs a dpkg hook for automatic re-patching after updates

## Project Structure

```
├── install.sh               # Built installer (run this)
├── Makefile                 # Development commands
└── source/
    ├── build.sh             # Assembles install.sh
    ├── base.sh              # Installer logic
    ├── colors.sh            # Terminal colors and messaging
    ├── buster.sh            # Hook script (patching logic)
    ├── apt.sources.proxmox  # Repo template
    ├── apt.sources.ceph     # Repo template
    ├── apt.sources.debian   # Repo template
    └── apt.conf.buster      # dpkg hook config
```

The build system concatenates source files and wraps templates in heredoc functions. No base64 encoding or external dependencies—the resulting `install.sh` is human-readable.

## Credits

- John McLaren for documenting the [original patch method](https://mclarendatasystems.com/remove-proxmox51-subscription-notice/)
- [Marlin Sööse](https://github.com/msoose) for PVE 6.3+ updates
- [diamondpete](https://github.com/diamondpete/pve-nag-buster) for the modular build structure

## License

GPL-2.0
