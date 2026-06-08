# Fedora Workstation Tweaks: Nobara & Ultramarine Analysis

What Nobara and Ultramarine Linux distributions add over stock Fedora Workstation, and how each tweak could be implemented with Ansible.

## Repositories & Package Sources

### RPM Fusion (Free + Nonfree)
**What:** Third-party repository providing packages Fedora won't ship due to licensing (codecs, proprietary drivers, patent-encumbered software). Both Nobara and Ultramarine enable this by default.

**Why:** Fedora's strict FOSS policy means no MP3/H.264/H.265 playback, no NVIDIA drivers, no Steam, etc. RPM Fusion fills these gaps and is the de facto standard third-party repo for Fedora.

**Ansible implementation:**
```yaml
- name: Enable RPM Fusion Free
  dnf:
    name: "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-{{ ansible_distribution_major_version }}.noarch.rpm"
    state: present
    disable_gpg_check: yes

- name: Enable RPM Fusion Nonfree
  dnf:
    name: "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-{{ ansible_distribution_major_version }}.noarch.rpm"
    state: present
    disable_gpg_check: yes
```

### Flatpak + Flathub
**What:** Flatpak sandboxed app framework with the Flathub repository enabled. Fedora ships Flatpak but only enables its own filtered Flathub remote (Fedora Flatpaks), which has fewer packages.

**Why:** Full Flathub access provides thousands of additional apps (Discord, Spotify, OBS Studio, etc.) in sandboxed containers with automatic updates.

**Ansible implementation:**
```yaml
- name: Install Flatpak
  dnf:
    name: flatpak
    state: present

- name: Add Flathub repository
  command: flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

- name: Remove filtered Fedora Flatpak remote (optional)
  command: flatpak remote-delete --force fedora
  ignore_errors: yes
```

### Terra Repository (Ultramarine-specific)
**What:** Ultramarine's custom package repository with additional packages not in Fedora or RPM Fusion.

**Why:** Provides packages like System76 Scheduler and other utilities. However, this repo is maintained by the Ultramarine team and may not be suitable for use on stock Fedora. Better to source individual packages from COPR repos instead.

**Ansible implementation:** Not recommended. Use COPR repos for individual packages instead.

---

## Multimedia & Codecs

### Full Multimedia Codec Support
**What:** H.264, H.265/HEVC, AAC, MP3, VP9, AV1 decoders/encoders plus GStreamer plugins for system-wide media playback. Both distros ship these pre-installed.

**Why:** Fedora ships without patent-encumbered codecs. Without these, videos won't play in browsers (hardware decode), media players won't handle common formats, and screen recording produces incompatible files.

**Ansible implementation:**
```yaml
- name: Install multimedia codecs
  dnf:
    name:
      - ffmpeg
      - gstreamer1-plugins-base
      - gstreamer1-plugins-good
      - gstreamer1-plugins-bad-free
      - gstreamer1-plugins-ugly
      - gstreamer1-plugin-openh264
      - mozilla-openh264
      - ffmpeg-libs
      - libva-utils
      - mesa-va-drivers        # AMD VA-API
      # - intel-media-driver   # Intel VA-API (if applicable)
    state: present

- name: Install FFmpeg for full codec support
  dnf:
    name: ffmpeg
    state: present
  # Requires RPM Fusion to be enabled
```

### Hardware Video Acceleration (VA-API)
**What:** GPU-accelerated video decode/encode for AMD, Intel, and NVIDIA GPUs.

**Why:** Without this, video playback uses CPU (higher power draw, worse battery life, choppy 4K). Firefox and Chromium can use VA-API for hardware-accelerated video.

**Ansible implementation:**
```yaml
- name: Install VA-API drivers (AMD)
  dnf:
    name:
      - mesa-va-drivers
      - libva-utils
    state: present
  when: "'AMD' in ansible_facts['processor'] | join(' ')"

- name: Install VA-API drivers (Intel)
  dnf:
    name:
      - intel-media-driver
      - libva-utils
    state: present
  when: "'Intel' in ansible_facts['processor'] | join(' ')"
```

---

## GPU Drivers

### NVIDIA Proprietary Drivers
**What:** NVIDIA's proprietary GPU drivers with CUDA support, replacing the open-source nouveau driver. Both Nobara and Ultramarine ship these pre-installed.

**Why:** Nouveau has poor performance and no hardware acceleration for modern NVIDIA GPUs. The proprietary driver is required for gaming, CUDA workloads, and proper multi-monitor support.

**Ansible implementation:**
```yaml
- name: Install NVIDIA drivers from RPM Fusion
  dnf:
    name:
      - akmod-nvidia          # Kernel module (auto-rebuilds on kernel updates)
      - xorg-x11-drv-nvidia-cuda  # CUDA support
      - nvidia-vaapi-driver   # VA-API video acceleration
    state: present
  # Requires RPM Fusion nonfree to be enabled
  # Note: Reboot required after install

- name: Blacklist nouveau driver
  copy:
    dest: /etc/modprobe.d/blacklist-nouveau.conf
    content: |
      blacklist nouveau
      options nouveau modeset=0
```

**Caveats:** NVIDIA driver installation can break on kernel updates if akmod doesn't rebuild in time. Secure Boot requires signing the kernel module. This is a higher-risk automation target.

### AMD GPU Drivers
**What:** AMD's open-source Mesa drivers are already in Fedora, but Nobara/Ultramarine add additional firmware and performance tweaks.

**Why:** Stock Fedora Mesa drivers work well for AMD. The extras provide firmware for newer GPUs and enable features like VP9/AV1 hardware decode.

**Ansible implementation:**
```yaml
- name: Install AMD GPU extras
  dnf:
    name:
      - mesa-dri-drivers
      - mesa-vulkan-drivers
      - mesa-va-drivers
      - mesa-vdpau-drivers
    state: present
```

---

## Gaming Stack

### Steam, Lutris, Wine
**What:** Gaming platform (Steam), game launcher/manager (Lutris), and Windows compatibility layer (Wine/Proton). Nobara ships all of these; Ultramarine focuses on enabling the repos to install them.

**Why:** Linux gaming requires these tools. Steam uses Proton (Wine fork) to run Windows games. Lutris manages non-Steam games with optimized Wine configurations.

**Ansible implementation:**
```yaml
- name: Install gaming packages
  dnf:
    name:
      - steam                 # Requires RPM Fusion nonfree
      - lutris
      - wine
      - winetricks
      - gamemode              # Feral GameMode for performance
      - mangohud              # FPS overlay
    state: present

# Or via Flatpak for sandboxed versions:
- name: Install Steam via Flatpak
  flatpak:
    name: com.valvesoftware.Steam
    state: present
    remote: flathub
```

### Proton-GE (GloriousEggroll's Proton)
**What:** Community Proton fork with additional game fixes, newer Wine, and patches not yet upstream. Nobara ships this by default.

**Why:** Fixes games that don't work with official Proton. Often has support for new games before Valve's releases.

**Ansible implementation:**
```yaml
- name: Install ProtonUp-Qt for managing Proton versions
  flatpak:
    name: net.davidotek.pupgui2
    state: present
    remote: flathub
# ProtonUp-Qt allows easy installation/management of Proton-GE versions
```

---

## Desktop Environment Tweaks

### GNOME Extensions (Ultramarine)
**What:** Pre-installed GNOME Shell extensions including AppIndicator (system tray), Pop Shell (tiling), and window navigation improvements.

**Why:** Stock GNOME lacks a system tray (breaks Discord, Steam, etc.), has no tiling window management, and has limited window navigation. These extensions fix the most common complaints.

**Ansible implementation:**
```yaml
- name: Install GNOME extensions
  dnf:
    name:
      - gnome-shell-extension-appindicator    # System tray support
      - gnome-shell-extension-pop-shell       # Tiling window management (if available)
      - gnome-shell-extension-dash-to-dock    # Persistent dock
    state: present

- name: Enable extensions via dconf
  become_user: "{{ target_user }}"
  dconf:
    key: "/org/gnome/shell/enabled-extensions"
    value: "['appindicatorsupport@rgcjonas.gmail.com']"
    state: present
```

**Caveat:** GNOME extension management via Ansible is fragile. Extensions break across GNOME versions. The `dconf` approach requires the user's D-Bus session. Consider using a script run as the user instead.

### Desktop Layout Customization (Nobara)
**What:** Pre-configured desktop layouts mimicking Windows 7, Windows 11, Unity, GNOME 2, etc.

**Why:** Lowers barrier for users coming from other OSes.

**Ansible implementation:** Not practical to automate. These are complex combinations of extensions, themes, and dconf settings. Better handled manually or with a dotfiles repo.

---

## Security Framework

### AppArmor Instead of SELinux (Nobara)
**What:** Nobara replaces Fedora's SELinux with AppArmor, claiming it's simpler to manage and less likely to silently break applications.

**Why:** SELinux is powerful but notoriously complex. It frequently causes mysterious permission denials, especially for gaming, Wine, and third-party apps. AppArmor uses simpler path-based rules.

**Ansible implementation:**
```yaml
# WARNING: This is a significant system change. Not recommended for automation.
- name: Disable SELinux
  selinux:
    state: disabled

- name: Install AppArmor
  dnf:
    name:
      - apparmor
      - apparmor-utils
      - apparmor-profiles
    state: present

- name: Set AppArmor as default LSM in GRUB
  lineinfile:
    path: /etc/default/grub
    regexp: '^GRUB_CMDLINE_LINUX='
    line: 'GRUB_CMDLINE_LINUX="... apparmor=1 security=apparmor"'
  notify: rebuild grub
```

**Recommendation:** Don't automate this. The risk of bricking the system or creating security gaps is high. If SELinux is problematic, setting it to permissive mode is safer:
```yaml
- name: Set SELinux to permissive
  selinux:
    policy: targeted
    state: permissive
```

---

## Kernel & Performance

### Custom Kernel (Nobara Zen Patches / Ultramarine CachyOS)
**What:** Performance-tuned kernels with lower latency, better scheduling, and additional hardware support. Nobara patches the stock kernel with Zen scheduler, laptop support, and DRM fixes. Ultramarine offers CachyOS kernels.

**Why:** Stock Fedora kernel prioritizes stability and broad compatibility. Gaming and desktop responsiveness benefit from schedulers optimized for interactivity (BORE, Zen) and reduced latency.

**Ansible implementation:**
```yaml
# CachyOS kernel via COPR (closest to what Ultramarine offers)
- name: Enable CachyOS kernel COPR
  command: dnf copr enable -y bieszczaders/kernel-cachyos

- name: Install CachyOS kernel
  dnf:
    name:
      - kernel-cachyos
      - kernel-cachyos-devel
    state: present
```

**Caveats:** Third-party kernels can break NVIDIA drivers, ZFS, and other out-of-tree modules. Not recommended unless you have a specific performance need. The CachyOS COPR may lag behind Fedora kernel updates.

### System76 Scheduler (Ultramarine)
**What:** User-space process scheduler that automatically prioritizes the focused application and its sub-processes.

**Why:** Improves desktop responsiveness by giving more CPU time to the window you're actively using. Particularly noticeable on lower-end hardware or when running background tasks.

**Ansible implementation:**
```yaml
- name: Enable System76 Scheduler COPR
  command: dnf copr enable -y kylegospo/system76-scheduler

- name: Install System76 Scheduler
  dnf:
    name: system76-scheduler
    state: present

- name: Enable and start System76 Scheduler
  systemd:
    name: com.system76.Scheduler
    enabled: yes
    state: started
```

### Sysctl Performance Tweaks
**What:** Kernel parameter tuning for network performance, gaming, and desktop responsiveness. Ultramarine enables IP MTU probing; both distros apply various sysctl tweaks.

**Why:** Default kernel parameters are conservative. Tweaks like MTU probing fix connectivity issues in games, and vm.swappiness adjustments improve responsiveness.

**Ansible implementation:**
```yaml
- name: Apply performance sysctl tweaks
  sysctl:
    name: "{{ item.key }}"
    value: "{{ item.value }}"
    state: present
    sysctl_file: /etc/sysctl.d/99-performance.conf
  loop:
    - { key: "net.ipv4.tcp_mtu_probing", value: "1" }           # Fix MTU issues in games
    - { key: "vm.swappiness", value: "10" }                       # Prefer RAM over swap
    - { key: "vm.vfs_cache_pressure", value: "50" }               # Keep filesystem cache longer
    - { key: "net.core.default_qdisc", value: "fq" }             # Better network queuing
    - { key: "net.ipv4.tcp_congestion_control", value: "bbr" }   # Google BBR congestion control
```

### GameMode (Feral Interactive)
**What:** Daemon that applies performance optimizations when games are running (CPU governor, I/O priority, GPU performance mode).

**Why:** Automatically boosts system performance during gaming without permanent changes. Steam and Lutris can trigger it automatically.

**Ansible implementation:**
```yaml
- name: Install GameMode
  dnf:
    name:
      - gamemode
      - lib32-gamemode   # 32-bit support for 32-bit games
    state: present

- name: Enable GameMode service for user
  become_user: "{{ target_user }}"
  systemd:
    name: gamemoded
    scope: user
    enabled: yes
```

---

## Shell & Terminal

### Zsh as Default Shell (Ultramarine)
**What:** Ultramarine uses Zsh instead of Bash as the default interactive shell, with a pre-configured setup.

**Why:** Zsh offers better tab completion, syntax highlighting, auto-suggestions, and a richer plugin ecosystem (Oh My Zsh). More pleasant interactive experience.

**Ansible implementation:**
```yaml
- name: Install Zsh and plugins
  dnf:
    name:
      - zsh
      - zsh-autosuggestions
      - zsh-syntax-highlighting
    state: present

- name: Set Zsh as default shell
  user:
    name: "{{ target_user }}"
    shell: /bin/zsh
```

---

## Popular Applications

### Pre-installed Apps (Both Distros)
**What:** Both distros ship popular apps that Fedora leaves out: Discord, OBS Studio, Brave/Chrome, media players (VLC/mpv), office suites, etc.

**Why:** Saves users from hunting down repos, Flatpaks, or RPMs for common applications.

**Ansible implementation:**
```yaml
# Via DNF (requires RPM Fusion)
- name: Install common desktop apps
  dnf:
    name:
      - vlc
      - obs-studio
    state: present

# Via Flatpak (sandboxed, always up to date)
- name: Install Flatpak apps
  flatpak:
    name: "{{ item }}"
    state: present
    remote: flathub
  loop:
    - com.discordapp.Discord
    - com.obsproject.OBSStudio
    - com.brave.Browser
    - org.videolan.VLC
    - com.spotify.Client

# Brave browser via its own repo
- name: Add Brave browser repo
  yum_repository:
    name: brave-browser
    description: Brave Browser
    baseurl: https://brave-browser-rpm-release.s3.brave.com/x86_64/
    gpgkey: https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
    gpgcheck: yes

- name: Install Brave browser
  dnf:
    name: brave-browser
    state: present
```

---

## Btrfs Filesystem Tweaks (Ultramarine)

### Transparent Compression
**What:** Ultramarine enables `compress=zstd` on Btrfs by default, which transparently compresses files on disk.

**Why:** Reduces disk usage by 20-40% with negligible CPU overhead (zstd is fast). Also improves I/O performance on slower drives since less data needs to be read/written.

**Ansible implementation:**
```yaml
# Must modify fstab - ideally done at install time
- name: Enable Btrfs compression in fstab
  mount:
    path: /
    src: "{{ ansible_mounts | selectattr('mount', 'equalto', '/') | map(attribute='device') | first }}"
    fstype: btrfs
    opts: "subvol=root,compress=zstd:1"
    state: present
  # WARNING: Changing fstab mount options requires careful testing.
  # Existing files won't be compressed; only new/modified files benefit.
  # Run `btrfs filesystem defragment -r -czstd /` to compress existing files.
```

**Caveat:** Modifying root fstab entries is risky to automate. A mistake can render the system unbootable. Best done manually or at OS install time.

---

## Summary: Implementation Priority

### Tier 1 - Easy & High Value (recommended)
- RPM Fusion repositories
- Multimedia codecs
- Flatpak + Flathub
- Sysctl performance tweaks
- Common desktop applications (Flatpak)

### Tier 2 - Medium Effort, Good Value
- NVIDIA driver installation
- Gaming stack (Steam, Lutris, Wine, GameMode)
- System76 Scheduler
- Zsh setup
- VA-API hardware video acceleration

### Tier 3 - High Effort or Risk
- CachyOS/custom kernel (risk of breaking drivers)
- GNOME extensions (fragile across versions)
- AppArmor swap (high risk, low reward)
- Btrfs compression (dangerous fstab changes)

### Not Worth Automating
- Custom kernel patches (Nobara's kernel is bespoke)
- Desktop layout presets (too complex, subjective)
- Distro-specific tools (post-install wizards, Hop)
