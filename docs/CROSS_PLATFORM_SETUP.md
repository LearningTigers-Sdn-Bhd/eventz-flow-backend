# Cross-Platform Setup Guide

## Overview

This guide covers setting up the image processing environment for the EventzFlow backend across different operating systems and development environments.

**Important Note**: The application works without libvips! Installing it enables optimized WebP image variants, but the app functions normally without it.

---

## Requirements

### System Dependencies
- **libvips** 8.18.0+ (optional - enables WebP variants, app works without it)
- **Ruby** 3.4.7
- **PostgreSQL** (for database)

### Ruby Gems
```ruby
gem "image_processing", "~> 1.2"
gem "ruby-vips", "~> 2.3"  # Automatically used if libvips is available
```

### Automatic Detection

The application automatically:
- ✅ Detects if libvips is installed
- ✅ Configures library paths for Homebrew/Linuxbrew installations
- ✅ Gracefully falls back if vips is not available
- ✅ Adapts image variant generation based on availability

You'll see in the Rails logs on startup:
- `✅ Vips library is available for image processing (version: X.X.X)` - Success!
- `⚠️ Vips library not available: ...` - App works, but without variants

---

## Platform-Specific Setup

### 🐧 Linux (Fedora/RHEL)

#### With System Packages
```bash
# Install libvips
sudo dnf install vips vips-devel

# Verify installation
vips --version
```

#### With Homebrew on Linux
```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add to shell profile
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
source ~/.bashrc

# Install libvips
brew install vips

# Verify installation
vips --version
```

**Environment Setup:**
```bash
cd eventz-flow-backend
direnv allow  # If using direnv
# OR
source .envrc  # Manual activation
```

---

### 🐧 Linux (Ubuntu/Debian)

#### With System Packages
```bash
# Install libvips
sudo apt update
sudo apt install libvips-dev

# Verify installation
vips --version
```

#### With Homebrew on Linux
```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add to shell profile
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
source ~/.bashrc

# Install libvips
brew install vips

# Verify installation
vips --version
```

**Environment Setup:**
```bash
cd eventz-flow-backend
direnv allow  # If using direnv
# OR
source .envrc  # Manual activation
```

---

### 🐧 Linux (Arch/Manjaro)

```bash
# Install libvips
sudo pacman -S libvips

# Verify installation
vips --version
```

---

### 🍎 macOS

#### With Homebrew (Recommended)
```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install libvips
brew install vips

# Verify installation
vips --version
```

**Homebrew Paths:**
- **Apple Silicon (M1/M2/M3):** `/opt/homebrew`
- **Intel:** `/usr/local`

**Environment Setup:**
```bash
cd eventz-flow-backend
direnv allow  # If using direnv
```

---

### 🪟 Windows

#### With WSL2 (Recommended)
```bash
# Inside WSL2 Ubuntu
sudo apt update
sudo apt install libvips-dev

# Verify installation
vips --version
```

#### With MSYS2 (Alternative)
```bash
# In MSYS2 terminal
pacman -S mingw-w64-x86_64-libvips

# Verify installation
vips --version
```

---

## 🐳 Docker Setup

Docker environments automatically have libvips installed - no additional setup needed!

### Dockerfile Configuration
```dockerfile
# Build stage
RUN apt-get install --no-install-recommends -y \
    build-essential \
    libvips \
    pkg-config

# Runtime stage
RUN apt-get install --no-install-recommends -y \
    libvips \
    postgresql-client
```

### Docker Compose
```bash
# Start with Docker Compose
docker-compose up

# No .envrc needed - libvips is in standard paths
```

**Note:** The `.envrc` file is automatically ignored in Docker containers.

---

## Environment Configuration

### The `.envrc` File

The project includes a `.envrc` file that automatically configures environment variables for local development.

```bash
# Homebrew environment for libvips (cross-platform)
# Automatically detects Homebrew location on Linux/macOS

if command -v brew >/dev/null 2>&1; then
  # Homebrew is installed - use it
  export HOMEBREW_PREFIX="$(brew --prefix)"
  export LD_LIBRARY_PATH="$HOMEBREW_PREFIX/lib:$LD_LIBRARY_PATH"
  export PKG_CONFIG_PATH="$HOMEBREW_PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"
else
  # No Homebrew - assume system packages
  echo "Note: Homebrew not found. Using system libvips if available."
fi
```

### How It Works

| Platform | Detection | Library Path |
|----------|-----------|--------------|
| **Homebrew (Linux)** | `brew --prefix` | `/home/linuxbrew/.linuxbrew/lib` |
| **Homebrew (macOS M1)** | `brew --prefix` | `/opt/homebrew/lib` |
| **Homebrew (macOS Intel)** | `brew --prefix` | `/usr/local/lib` |
| **System packages** | No Homebrew | `/usr/lib` or `/usr/lib64` |
| **Docker** | N/A | `/usr/lib/x86_64-linux-gnu` |

---

## Activation Methods

### Option 1: direnv (Recommended)

**Automatic activation when entering directory:**

```bash
# Install direnv
brew install direnv  # macOS/Homebrew Linux
sudo apt install direnv  # Ubuntu/Debian
sudo dnf install direnv  # Fedora/RHEL

# Add to shell profile
# For bash:
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc

# For zsh:
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc

# For fish:
echo 'direnv hook fish | source' >> ~/.config/fish/config.fish

# Reload shell
source ~/.bashrc  # or ~/.zshrc

# Allow .envrc in project
cd eventz-flow-backend
direnv allow
```

**Usage:**
```bash
# Just cd into directory - environment auto-loads
cd eventz-flow-backend
# direnv: loading .envrc
# direnv: export +HOMEBREW_PREFIX ~LD_LIBRARY_PATH ~PKG_CONFIG_PATH

# Start Rails
bin/rails server
```

---

### Option 2: Manual Activation

**Load environment manually each time:**

```bash
cd eventz-flow-backend
source .envrc
bin/rails server
```

---

### Option 3: Global Shell Configuration

**Add Homebrew to shell permanently (if not using direnv):**

```bash
# Add to ~/.bashrc or ~/.zshrc
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"  # Linux
eval "$(/opt/homebrew/bin/brew shellenv)"                # macOS M1
eval "$(/usr/local/bin/brew shellenv)"                   # macOS Intel
```

---

## Verification

### Check libvips Installation

```bash
# Check version
vips --version

# Check library file
ls -la $(brew --prefix)/lib/libvips.so*    # Linux/Homebrew
ls -la $(brew --prefix)/lib/libvips.dylib  # macOS/Homebrew
ldconfig -p | grep libvips                  # Linux/System

# Check pkg-config
pkg-config --modversion vips
pkg-config --libs vips
```

### Test with Rails

```bash
cd eventz-flow-backend
source .envrc  # If not using direnv

# Test in Rails console
bin/rails console
```

```ruby
# In Rails console:
require 'vips'
puts "Vips version: #{Vips::LIBRARY_VERSION}"
# => Vips version: 8.18.0

# Test image processing
resource = Resource.first
resource.header_img.variant(:thumbnail) if resource.header_img.attached?
# => Should work without errors
```

### Common Issues

#### Issue: "Could not open library 'libvips.so.42'"

**Solution:**
```bash
# Ensure LD_LIBRARY_PATH is set
echo $LD_LIBRARY_PATH
# Should include: /home/linuxbrew/.linuxbrew/lib or similar

# If empty, load .envrc:
source .envrc
```

#### Issue: "uninitialized constant Vips"

**Solution:**
```bash
# Ensure image_processing gem is installed
cd eventz-flow-backend
bundle install

# Check Gemfile has:
# gem "image_processing", "~> 1.2"
```

#### Issue: "No such file or directory @ rb_sysopen"

**Solution:**
```bash
# Check Active Storage is configured
ls -la storage/  # Should exist

# In config/storage.yml, verify:
# local:
#   service: Disk
#   root: <%= Rails.root.join("storage") %>
```

---

## Team Setup Checklist

### For New Developers

- [ ] Clone repository
- [ ] Install Ruby 3.4.7 (via mise/rbenv/rvm)
- [ ] Install libvips (via Homebrew or system package manager)
- [ ] Run `bundle install`
- [ ] Install direnv (optional but recommended)
- [ ] Run `direnv allow` in project directory
- [ ] Verify with `vips --version`
- [ ] Test with `bin/rails console` and check Vips loads

### For CI/CD Pipelines

```yaml
# GitHub Actions Example
- name: Install libvips
  run: |
    sudo apt-get update
    sudo apt-get install -y libvips-dev

- name: Verify libvips
  run: vips --version

- name: Bundle install
  run: bundle install

- name: Run tests
  run: bundle exec rspec
```

---

## Production Deployment

### With Docker

✅ **No additional setup needed** - libvips included in Dockerfile

```bash
docker-compose -f docker-compose.staging.yaml up
```

### With System Packages

```bash
# On production server
sudo apt install libvips-dev  # Ubuntu/Debian
sudo dnf install vips-devel   # Fedora/RHEL

# Verify
vips --version

# Deploy and start
bundle install
bin/rails server -e production
```

---

## Platform Comparison

| Feature | Homebrew | System Packages | Docker |
|---------|----------|-----------------|--------|
| **Installation** | `brew install vips` | `apt/dnf install` | Pre-configured |
| **Version** | Latest (8.18.0+) | System default | Controlled |
| **Updates** | `brew upgrade` | `apt/dnf upgrade` | Rebuild image |
| **Path Setup** | `.envrc` required | Usually automatic | Automatic |
| **Cross-platform** | ✅ Yes | ❌ Linux only | ✅ Yes |
| **Isolation** | User-space | System-wide | Container-isolated |

---

## Troubleshooting

### App Works Without libvips

**Good news**: The application is designed to work without libvips installed. You can:
- Upload and store images ✅
- Serve original images ✅
- Update resources ✅
- Access the API normally ✅

**Without libvips**: Image variants (thumbnail, medium, large) won't be generated. All image URLs will point to the original image, but the API structure remains the same for frontend compatibility.

**With libvips**: You get optimized WebP variants for better performance and bandwidth usage.

### Library Not Found (Homebrew/Linuxbrew)

If you see `Could not open library 'libvips.so.42'` errors:

1. **Verify vips is installed:**
   ```bash
   vips --version  # Should show version
   brew list vips  # Check if installed via Homebrew
   ```

2. **Check library location:**
   ```bash
   # Linuxbrew
   ls -la /home/linuxbrew/.linuxbrew/lib/libvips.so.42

   # macOS Homebrew
   ls -la /opt/homebrew/lib/libvips.dylib
   ```

3. **Ensure environment is loaded:**
   ```bash
   cd eventz-flow-backend

   # Option 1: Using direnv (recommended)
   direnv allow

   # Option 2: Manually source .envrc
   source .envrc

   # Verify LD_LIBRARY_PATH includes Homebrew lib
   echo $LD_LIBRARY_PATH | grep -i homebrew
   ```

4. **The app auto-detects Homebrew**, but you may need to restart Rails server:
   ```bash
   # Stop current server (Ctrl+C)
   # Restart with environment loaded
   source .envrc  # If not using direnv
   rails server
   ```

5. **Check Rails logs** for vips initialization:
   - Look for: `✅ Vips library is available for image processing (version: X.X.X)`
   - Or: `⚠️ Vips library not available: ...` (app still works!)

### Rails Server Can't Find Library

The initializer (`config/initializers/active_storage_vips_fallback.rb`) automatically:
- Detects Homebrew installation
- Adds library path to `LD_LIBRARY_PATH`
- Attempts to load vips on startup

If it still doesn't work:
1. Ensure you're starting Rails from the project directory
2. If using systemd or a process manager, ensure environment variables are passed
3. Check that `brew` command is accessible when Rails starts

### Debug Environment

### Debug Environment

```bash
# Check all relevant environment variables
echo "HOMEBREW_PREFIX: $HOMEBREW_PREFIX"
echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
echo "PKG_CONFIG_PATH: $PKG_CONFIG_PATH"
echo "PATH: $PATH"

# Check if brew is available
which brew

# Check if libvips is installed
brew list vips  # Homebrew
dpkg -l | grep libvips  # Debian/Ubuntu
rpm -qa | grep vips  # Fedora/RHEL

# Check library location
find /usr -name "libvips.so*" 2>/dev/null
find /opt -name "libvips.dylib" 2>/dev/null
find /home/linuxbrew -name "libvips.so*" 2>/dev/null
```

### Rails Logs

```bash
# Check Rails logs for image processing errors
tail -f log/development.log

# Look for errors like:
# - LoadError: Could not open library
# - Vips::Error: unable to load
# - ActiveStorage::InvariableError
```

---

## Support

### Documentation
- [libvips Documentation](https://www.libvips.org/)
- [image_processing Gem](https://github.com/janko/image_processing)
- [Active Storage Guide](https://guides.rubyonrails.org/active_storage_overview.html)

### Project-Specific
- Check `docs/IMAGE_PROCESSING.md` for usage
- Check `docs/IMAGE_UPLOAD_OPTIMIZATIONS.md` for features
- Run tests: `bundle exec rspec spec/models/resource_spec.rb -e "image processing"`

---

## Quick Reference

### Start Development

```bash
# Linux/macOS with Homebrew
cd eventz-flow-backend
direnv allow  # First time only
bin/rails server

# Docker
docker-compose up
```

### Install libvips

```bash
# Homebrew (macOS/Linux)
brew install vips

# Ubuntu/Debian
sudo apt install libvips-dev

# Fedora/RHEL
sudo dnf install vips-devel

# Arch
sudo pacman -S libvips
```

### Verify Setup

```bash
vips --version
bin/rails runner "require 'vips'; puts Vips::LIBRARY_VERSION"
```

That's it! Your image processing environment should now be ready to go. 🚀
