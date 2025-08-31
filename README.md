# Welcome-Art

A modular bash script package that displays beautiful ASCII art welcome messages on SSH/VPS login using figlet and lolcat.

## Features

- 🎨 Beautiful ASCII art with customizable colors and animations
- 🔧 Modular configuration system (system-wide and per-user)
- 📦 Multiple art templates with easy switching
- 🚀 Auto-execution on SSH login
- 🛠️ Comprehensive CLI with subcommands
- 📋 Easy installation and management
- 🎯 Debian package support

## Quick Installation

```bash
# Quick install (recommended)
sudo ./quickinstall.sh

# Or full installation with options
sudo ./install.sh

# Or install from .deb package
sudo dpkg -i welcome-art_1.0.0_all.deb
```

## Quick Start

```bash
# Display welcome art
welcome-art

# List available templates
welcome-art list

# Set a different template
welcome-art set --template modern

# Configure user settings
welcome-art config --user

# Show help
welcome-art --help
```

## Package Structure

```
welcome-art/
├── usr/local/bin/
│   └── welcome-art                 # Main executable
├── etc/welcome-art/
│   ├── config                      # System configuration
│   ├── welcome-artrc.template      # User config template
│   ├── art/                        # Art templates
│   │   ├── default.art
│   │   ├── modern.art
│   │   └── classic.art
│   └── scripts/                    # Subcommand scripts
│       ├── update.sh
│       ├── config.sh
│       ├── list.sh
│       └── set.sh
├── etc/profile.d/
│   └── welcome-art.sh              # Auto-execution script
├── DEBIAN/                         # Package metadata
│   ├── control
│   ├── postinst
│   ├── prerm
│   └── postrm
├── install.sh                      # Full installer
├── quickinstall.sh                 # Quick installer
├── quickuninstall.sh               # Quick uninstaller
├── set-permissions.sh              # Permissions setup
└── README.md                       # This file
```

## Configuration

### System Configuration

Edit `/etc/welcome-art/config` for system-wide settings:

```bash
# Display settings
DEFAULT_TEMPLATE="default"
WELCOME_TEXT="Welcome to %HOSTNAME%"
ENABLE_COLOR="true"
ENABLE_ANIMATION="true"

# Template repository
TEMPLATE_REPO="https://github.com/welcome-art/templates"
AUTO_UPDATE_TEMPLATES="false"

# Logging
LOG_LEVEL="INFO"
LOG_FILE="/var/log/welcome-art/welcome-art.log"
```

### User Configuration

Create `~/.welcome-artrc` for personal settings:

```bash
# Copy template and edit
cp /etc/welcome-art/welcome-artrc.template ~/.welcome-artrc
vim ~/.welcome-artrc

# Or use the config command
welcome-art config --user
```

## CLI Commands

### Main Command

```bash
welcome-art [OPTIONS] [SUBCOMMAND]

Options:
  -h, --help           Show help message
  -v, --version        Show version
  -t, --template NAME  Use specific template
  -w, --welcome TEXT   Set welcome text
  -c, --color          Enable colors
  -n, --no-color       Disable colors
  -q, --quiet          Suppress output
  --test               Test mode (no auto-execution)
```

### Subcommands

#### List Templates

```bash
welcome-art list [OPTIONS]

Options:
  -a, --all            Show all templates (system + user)
  -s, --system         Show system templates only
  -u, --user           Show user templates only
  -d, --detailed       Show detailed information
  -j, --json           Output in JSON format
  -p, --preview        Show template previews
```

#### Set Template/Configuration

```bash
welcome-art set [OPTIONS]

Options:
  -t, --template NAME  Set active template
  -w, --welcome TEXT   Set welcome text
  -c, --color          Enable colors
  -n, --no-color       Disable colors
  -s, --system         Apply to system config
  -u, --user           Apply to user config
  --show               Show current settings
```

#### Update Templates

```bash
welcome-art update [OPTIONS]

Options:
  -f, --force          Force update (overwrite existing)
  -r, --repo URL       Use custom repository
  -l, --list           List remote templates
  -c, --check          Check for updates only
```

#### Configuration Management

```bash
welcome-art config [OPTIONS]

Options:
  -s, --system         Edit system configuration
  -u, --user           Edit user configuration
  --show               Show current configuration
  --reset              Reset user configuration
  --validate           Validate configuration files
```

## Art Templates

### Template Format

Art templates are simple configuration files:

```bash
# Template metadata
TITLE="Modern Style"
DESCRIPTION="Clean modern ASCII art with plasma colors"
AUTHOR="Welcome-Art Team"
VERSION="1.0"

# Figlet settings
FIGLET_FONT="big"
FIGLET_ALIGNMENT="center"

# Lolcat settings
LOLCAT_STYLE="plasma"
LOLCAT_ANIMATION="true"
LOLCAT_SPEED="500"

# Content placeholders
WELCOME_PREFIX="╔══════════════════════════════════════╗"
WELCOME_SUFFIX="╚══════════════════════════════════════╝"
WELCOME_MESSAGE="Welcome to %HOSTNAME%!"
```

### Available Placeholders

- `%HOSTNAME%` - System hostname
- `%USERNAME%` - Current username
- `%DATE%` - Current date
- `%TIME%` - Current time
- `%UPTIME%` - System uptime
- `%LOAD%` - System load average
- `%USERS%` - Number of logged-in users

### Creating Custom Templates

1. Create a new `.art` file in `/etc/welcome-art/art/` (system) or `~/.welcome-art/art/` (user)
2. Use the template format above
3. Test with: `welcome-art --template your-template`
4. Set as default: `welcome-art set --template your-template`

## Dependencies

### Required

- `figlet` - ASCII art text generator
- `lolcat` - Colorful text output
- `bash` 4.0+ - Shell interpreter

### Optional

- `git` - For template updates from repositories
- `wget` or `curl` - For downloading templates
- `unzip` - For extracting template archives

### Installation

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install figlet lolcat git wget unzip

# CentOS/RHEL
sudo yum install figlet git wget unzip
# Note: lolcat may need to be installed via gem or pip

# Arch Linux
sudo pacman -S figlet git wget unzip
# Note: lolcat available in AUR
```

## Auto-Execution

Welcome-Art automatically displays on SSH login via `/etc/profile.d/welcome-art.sh`.

### Disable Auto-Execution

```bash
# System-wide
sudo rm /etc/profile.d/welcome-art.sh

# Per-user (add to ~/.bashrc or ~/.profile)
export WELCOME_ART_DISABLE=1
```

### Enable for Local Logins

```bash
# Edit system config
sudo welcome-art config --system

# Set ENABLE_LOCAL_EXECUTION="true"
```

## Building from Source

### Create .deb Package

```bash
# Set proper permissions
sudo ./set-permissions.sh

# Build package
dpkg-deb --build . welcome-art_1.0.0_all.deb

# Install package
sudo dpkg -i welcome-art_1.0.0_all.deb
```

### Manual Installation

```bash
# Run full installer
sudo ./install.sh

# Or quick install
sudo ./quickinstall.sh
```

## Troubleshooting

### Common Issues

1. **Command not found**: Ensure `/usr/local/bin` is in your PATH
2. **Permission denied**: Run `sudo ./set-permissions.sh`
3. **Missing dependencies**: Install figlet and lolcat
4. **No colors**: Check terminal 256-color support
5. **Auto-execution not working**: Verify `/etc/profile.d/welcome-art.sh` exists

### Debug Mode

```bash
# Enable verbose logging
welcome-art --test --verbose

# Check logs
sudo tail -f /var/log/welcome-art/welcome-art.log

# Validate configuration
welcome-art config --validate
```

### Reset Configuration

```bash
# Reset user config
welcome-art config --reset

# Reset system config (reinstall)
sudo ./install.sh --force
```

## Uninstallation

```bash
# Quick uninstall
sudo ./quickuninstall.sh

# Full uninstall with options
sudo ./install.sh --uninstall

# Remove package
sudo dpkg -r welcome-art

# Purge all data
sudo ./quickuninstall.sh --purge
```

## Development

### File Permissions

- Executables: `755` (rwxr-xr-x)
- Configuration files: `644` (rw-r--r--)
- Directories: `755` (rwxr-xr-x)
- Scripts: `755` (rwxr-xr-x)

### Testing

```bash
# Test installation
sudo ./install.sh --test

# Test permissions
sudo ./set-permissions.sh --dry-run

# Test templates
welcome-art list --preview
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Support

- GitHub Issues: https://github.com/welcome-art/welcome-art/issues
- Documentation: https://github.com/welcome-art/welcome-art/wiki
- Templates: https://github.com/welcome-art/templates

## Changelog

### v1.0.0

- Initial release
- Modular architecture
- Multiple art templates
- Auto-execution support
- Debian package support
- Comprehensive CLI
- Configuration management
- Template update system