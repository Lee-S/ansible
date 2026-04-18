# OpenClaw VM Setup Guide — Ubuntu Edition

**Isolated AI Agent on QEMU/KVM · Ubuntu Host · Ubuntu Server VM · llama.cpp on port 8080**

---

## What this guide covers

- Install QEMU/KVM and virt-manager on Ubuntu (24.04 LTS host)
- Create a secure, isolated VM for the OpenClaw AI agent
- User account strategy — `lee` (host admin) vs `maxbot` (VM agent user)
- Install and configure OpenClaw inside the VM
- Connect OpenClaw to your llama.cpp server on port 8080
- Grant scoped access: email, GitHub, calendar, NAS files
- Write your SOUL.md and starter prompts

---

## 1. Architecture Overview

OpenClaw is a capable autonomous agent that can send email, browse the web, run code, and manage files. Running it inside a QEMU/KVM virtual machine means any prompt injection attack, runaway task, or misconfiguration is contained at the hypervisor boundary — it cannot reach your NAS, Home Assistant, or host filesystem directly.

| Host OS (Ubuntu 24.04) | VM Guest (Ubuntu Server 24.04) |
|---|---|
| llama.cpp server → port 8080 | OpenClaw agent (user: maxbot) |
| Your NAS (CIFS/NFS mounts) | Dedicated email account (IMAP) |
| Home Assistant | Read-only GitHub token |
| KVM hypervisor (user: lee) | Read-only calendar ICS |
| VirtIO-fs shared folder (read-only drop) | Isolated NAT network (no LAN access) |

> **Security:** OpenClaw can execute shell commands and send emails. The VM is your primary safety layer. Never give `maxbot` sudo, never mount NAS read-write, and read every community skill before installing it.

---

## 2. User Account Strategy

**Do you need a separate admin account?**

Yes — this separation is worth doing. Keep `lee` as your host admin and confine `maxbot` entirely inside the VM.

| Account | Location | Role & Permissions |
|---|---|---|
| `lee` | Host OS | Your day-to-day admin. Manages KVM, mounts NAS, owns llama.cpp. Add to `libvirt` and `kvm` groups. Has sudo. |
| `lee` (VM) | Inside VM | Your admin account inside the VM too. Used for installing packages and configuring the OS. Has sudo inside the VM only. |
| `maxbot` | Inside VM only | The OpenClaw agent user. **NO sudo at all.** Owns only `~/.openclaw` and its workspace. This is the account OpenClaw runs as. |

> **Note:** Do not create a `maxbot` account on the host OS. If OpenClaw ever escapes its working directory inside the VM, it still cannot reach anything on the host.

---

## 3. Installing QEMU/KVM and virt-manager

### 3.1 Install the virtualisation stack

Run these on the host as `lee`:

```bash
sudo apt update

sudo apt install -y \
  qemu-kvm \
  libvirt-daemon-system \
  libvirt-clients \
  virt-manager \
  bridge-utils \
  virtiofsd \
  ovmf
```

> **Note:** `ovmf` provides UEFI firmware for VMs. `virtiofsd` is required for VirtIO-fs shared folders (used in Section 5). On Ubuntu 22.04 `virtiofsd` may be in a separate package — check with `apt search virtiofsd`.

### 3.2 Enable and start libvirt

```bash
sudo systemctl enable --now libvirtd

# Verify it is running
sudo systemctl status libvirtd
```

### 3.3 Add lee to the required groups

This lets you manage VMs without prefixing every command with sudo:

```bash
sudo usermod -aG libvirt,kvm lee

# Log out and back in, then verify
groups
# Should include: libvirt  kvm
```

### 3.4 Verify KVM is working

```bash
ls -la /dev/kvm
# Expected:  crw-rw----  1 root  kvm  10, 232  /dev/kvm

sudo virt-host-validate
# All items should show PASS or WARN (WARN is acceptable)
```

> **Note:** If `/dev/kvm` is missing, check that virtualisation is enabled in your BIOS/UEFI (Intel VT-x or AMD-V). On a physical Ubuntu host this is usually enabled by default.

---

## 4. Creating the OpenClaw VM

### 4.1 Download the Ubuntu Server 24.04 LTS ISO

```bash
sudo mkdir -p /data/libvirt/images/isos
cd /data/libvirt/images/isos

sudo wget https://releases.ubuntu.com/24.04/ubuntu-24.04.2-live-server-amd64.iso
```

> **Note:** Ubuntu Server 24.04 LTS is lightweight, well-supported under KVM, and matches the host OS — straightforward for patching and tooling.

### 4.2 Create the VM

The following creates an isolated VM using NAT networking. OpenClaw can reach the internet and your host, but cannot reach other devices on your LAN directly:

```bash
sudo virt-install \
  --name openclaw-agent \
  --ram 8192 \
  --vcpus 4 \
  --disk path=/data/libvirt/images/openclaw-agent.qcow2,size=40,format=qcow2 \
  --os-variant ubuntu24.04 \
  --cdrom /data/libvirt/images/isos/ubuntu-24.04.2-live-server-amd64.iso \
  --network network=default \
  --graphics spice \
  --video qxl \
  --channel unix,target.type=virtio,target.name=org.qemu.guest_agent.0
```

> **Note:** Verify the correct `--os-variant` value for your system with:
> ```bash
> virt-install --osinfo list | grep ubuntu
> ```
> Use `ubuntu24.04` if listed; fall back to `ubuntu22.04` if not yet in your osinfo database.

> **Note:** If you get `unrecognized arguments` errors when pasting the multi-line command, trailing spaces after `\` are breaking line continuation. Write it to a script file instead:
> ```bash
> cat > /tmp/create-vm.sh << 'EOF'
> sudo virt-install \
>   --name openclaw-agent \
>   ...
> EOF
> bash /tmp/create-vm.sh
> ```

> **Note:** 8 GB RAM and 4 vCPUs is more than enough — OpenClaw does no local inference, it just talks to llama.cpp on your host. Bump disk to 60 GB if you plan to stage large file analysis jobs.

### 4.3 Complete the Ubuntu Server installation

virt-manager opens a graphical console to the Ubuntu Subiquity installer (text-based). During setup:

- **Language / keyboard**: English defaults are fine
- **Network**: leave as-is (DHCP from libvirt's default NAT)
- **Storage**: use the entire disk, no LVM required for this use case
- **Profile setup**:
  - Your name: `Lee` (or similar)
  - Server name: `openclaw-agent`
  - Username: `lee`
  - Password: a strong password (this is your in-VM sudo account)
- **Ubuntu Pro**: skip / decline
- **SSH**: select "Install OpenSSH server" — required for SSH access from the host
- **Snap packages**: deselect everything — OpenClaw installs via npm, not snap
- Do **NOT** create `maxbot` yet — do this after first boot

Wait for "Install complete!" then reboot.

### 4.4 First boot — update and install essentials

Log in as `lee` inside the VM and run:

```bash
sudo apt update && sudo apt upgrade -y

sudo apt install -y curl wget git

# Install Node.js 22+ via NodeSource (OpenClaw requires Node 22 or newer)
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs

# Verify Node version — must be 22+
node --version

# The QEMU guest agent is often already installed on Ubuntu Server; enable it
sudo apt install -y qemu-guest-agent
sudo systemctl enable --now qemu-guest-agent.service

# SPICE agent for copy/paste between host and VM
sudo apt install -y spice-vdagent
sudo systemctl enable --now spice-vdagentd.service

# Minimal desktop so you can use a browser inside the VM for the dashboard
sudo apt install -y ubuntu-desktop-minimal
sudo systemctl set-default graphical.target
sudo reboot
```

After reboot, verify:

```bash
node --version    # e.g. v22.x.x
systemctl status qemu-guest-agent
```

> **Tip:** Get the VM's IP address from the host with `sudo virsh domifaddr openclaw-agent` — useful for SSH access.

### 4.5 Verify host connectivity from inside the VM

With libvirt's default NAT network, the host is reachable from the VM via the `virbr0` bridge — typically `192.168.122.1`. Check the actual IP on the host first:

```bash
# On the HOST:
ip addr show virbr0
# Look for: inet 192.168.122.1/24
```

Then verify your llama.cpp server is reachable from inside the VM:

```bash
# From inside the VM:
curl http://192.168.122.1:8080/v1/models

# You should get a JSON response listing your loaded model.
```

> **Note:** `10.0.2.2` is the gateway for QEMU user-mode networking, not libvirt bridge networking. With libvirt's default network use `192.168.122.1` instead.

If the curl fails, check two things on the **host**:

**1. llama.cpp must bind to `0.0.0.0`** (not `127.0.0.1`):
```bash
# Restart llama.cpp with:
--host 0.0.0.0 --port 8080
```

**2. UFW firewall must allow port 8080 from the libvirt NAT network:**
```bash
# Allow connections from the libvirt NAT subnet only
sudo ufw allow from 192.168.122.0/24 to any port 8080
sudo ufw reload

# Verify the rule is active
sudo ufw status
```

> **Tip:** Binding llama.cpp to `0.0.0.0` makes it reachable from the VM but it remains firewalled from your wider LAN by your router and UFW rules.

---

## 5. Setting Up the maxbot User and File Access

### 5.1 Create the maxbot account (inside VM, as lee)

```bash
# Create maxbot with no sudo access
sudo useradd -m -s /bin/bash maxbot
sudo passwd maxbot

# Verify — this should say 'not allowed'
sudo -l -U maxbot
```

### 5.2 Create working directories

```bash
sudo -u maxbot mkdir -p /home/maxbot/.openclaw/workspace
sudo -u maxbot mkdir -p /home/maxbot/nas-files
```

### 5.3 Expose NAS files via VirtIO-fs (host → VM, read-only)

Rather than giving the VM any network path to your NAS, you mount the NAS on the host first, then share that mount into the VM via VirtIO-fs. The VM never sees NAS credentials.

**Step 1 — on the HOST, mount the NAS share:**

```bash
# Install CIFS utilities if not already present
sudo apt install -y cifs-utils

# Create credentials file (600 permissions)
sudo tee /etc/maxbot-nas.creds > /dev/null <<'EOF'
username=YOUR_NAS_USER
password=YOUR_NAS_PASSWORD
EOF
sudo chmod 600 /etc/maxbot-nas.creds

# Mount read-only
sudo mkdir -p /mnt/maxbot-nas
sudo mount -t cifs //192.168.X.X/your-share /mnt/maxbot-nas \
  -o credentials=/etc/maxbot-nas.creds,ro,uid=1000,gid=1000

# Add to /etc/fstab for persistence
echo '//192.168.X.X/your-share /mnt/maxbot-nas cifs credentials=/etc/maxbot-nas.creds,ro 0 0' \
  | sudo tee -a /etc/fstab
```

**Step 2 — add the VirtIO-fs device to the VM. Edit the VM XML on the host:**

```bash
sudo virsh edit openclaw-agent

# Inside <devices>, add:
#   <filesystem type='mount' accessmode='passthrough'>
#     <driver type='virtiofs'/>
#     <source dir='/mnt/maxbot-nas'/>
#     <target dir='nas-share'/>
#     <readonly/>
#   </filesystem>

# Then reboot the VM
sudo virsh reboot openclaw-agent
```

**Step 3 — inside the VM, install virtiofs support and mount:**

```bash
# Ensure virtiofs kernel module is available (it is included in Ubuntu 24.04 kernel)
sudo modprobe virtiofs

# Add to /etc/fstab inside the VM
echo 'nas-share  /home/maxbot/nas-files  virtiofs  ro,defaults  0  0' \
  | sudo tee -a /etc/fstab

sudo mount -a

# Verify
ls /home/maxbot/nas-files
```

---

## 6. Installing OpenClaw in the VM

### 6.1 Switch to maxbot and install

SSH in directly as `maxbot` rather than using `su` — this gives a proper login session with D-Bus, which OpenClaw's gateway requires:

```bash
# Set a password for maxbot first (as lee):
sudo passwd maxbot

# Then SSH in as maxbot:
ssh maxbot@localhost
```

Configure npm to install globals into the user's home directory (avoids permission issues):

```bash
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global'
echo 'export PATH="$PATH:/home/maxbot/.npm-global/bin"' >> ~/.bashrc
source ~/.bashrc
```

Install OpenClaw:

```bash
# Recommended: use the official installer (handles Node detection and onboarding)
curl -fsSL https://openclaw.ai/install.sh | bash

# OR install manually if you prefer:
# npm install -g openclaw@latest

# Confirm installation
openclaw --version
```

### 6.2 Run the setup wizard

The wizard walks you through all initial configuration. Have your dedicated email credentials and GitHub token ready:

```bash
openclaw onboard

# Wizard prompts and recommended answers:
#
# Agent name:              Maxbot
# Your name:               Lee
# Model/auth provider:     Custom Provider
# Endpoint compatibility:  OpenAI-compatible (Uses /chat/completions)
# API base URL:            http://192.168.122.1:8080/v1
# API key:                 none  (any string works, llama.cpp ignores it)
# Model name:              (paste the id from: curl http://192.168.122.1:8080/v1/models)
# Workspace directory:     /home/maxbot/.openclaw/workspace
```

### 6.3 Verify the LLM connection

```bash
# Probe the gateway and LLM connection (comprehensive debug output)
openclaw gateway probe

# Or run the built-in diagnostics tool
openclaw doctor

# The web dashboard also lets you send a test message — open in the VM's browser:
# http://127.0.0.1:18789/
# If you get a connection error, re-check that llama.cpp
# is listening on 0.0.0.0 not 127.0.0.1
```

### 6.4 Start the gateway

OpenClaw uses a systemd **user** service, which requires a proper login session. Always SSH in as `maxbot` (not `su - maxbot`) so that D-Bus is available.

Enable lingering so the user service starts at boot without an active login (run as `lee`):

```bash
sudo loginctl enable-linger maxbot
```

Then as `maxbot` (via SSH), start and enable the gateway:

```bash
openclaw gateway start
openclaw gateway status
```

The gateway binds to loopback (`127.0.0.1:18789`) by default. The dashboard is accessible at `http://127.0.0.1:18789/` from a browser **inside the VM** — open it from the GNOME desktop in the virt-manager console.

> **Tip:** This is why `ubuntu-desktop-minimal` was installed in section 4.4 — it's the simplest way to access the dashboard while keeping the VM fully isolated.

---

## 7. Granting Scoped Access

### 7.1 Dedicated email account

- Create a fresh Gmail or Fastmail account purely for OpenClaw (e.g. `lee.maxbot@gmail.com`)
- Enable IMAP in Settings, then create an app-specific password (not your main password)
- Configure in OpenClaw: `openclaw config set channels.email.imap ...`
- This account should never be linked to any other service

### 7.2 GitHub — fine-grained read-only token

In GitHub Settings → Developer Settings → Personal Access Tokens → Fine-grained:

```bash
# Token settings:
#   Name:        openclaw-readonly
#   Expiration:  90 days  (set a calendar reminder to rotate)
#   Repos:       Only the specific repos you want visible
#   Permissions:
#     Contents  → Read-only
#     Metadata  → Read-only
#     All else  → No access

# Pass the token to OpenClaw:
openclaw config set skills.github.token 'ghp_your_token_here'
```

### 7.3 Calendar — read-only ICS link

Use a static ICS share rather than full OAuth. OpenClaw can read your schedule but cannot create or modify events:

- **Google Calendar:** Settings → your calendar → Integrate Calendar → "Secret address in iCal format"
- **Proton Calendar:** Settings → Calendar → Copy link (read-only)
- Paste the URL into the OpenClaw calendar skill config — it only reads, never writes

### 7.4 NAS file access

Already handled via VirtIO-fs in Section 5. The key security properties:

- The VM has no network route to your NAS — it cannot ping or connect to it
- Files arrive only via the read-only `~/nas-files` mount
- To change what OpenClaw can see, adjust the host-side `/mnt/maxbot-nas` mount — the VM config never changes

> **Security:** Do not install community OpenClaw skills without reading their source first. Stick to first-party skills initially. Community skills run with the same permissions as OpenClaw itself.

---

## 8. Configuring SOUL.md

SOUL.md is OpenClaw's personality and permission file. It is read at startup and governs what the agent will and will not do. Edit it as `maxbot` inside the VM:

```bash
nano /home/maxbot/.openclaw/workspace/SOUL.md
```

Recommended starting configuration:

```markdown
# Maxbot — Personal AI Agent for Lee

## Identity
You are Maxbot, Lee's personal AI assistant running as an isolated agent
on a secure virtual machine. You connect to a local llama.cpp server for
all inference. You have no access to the host OS or local network.

## What you can do
- Coding: review, debug, write scripts, analyse repositories
- Read and summarise documents in ~/nas-files (read-only)
- Analyse health data exports from apps
- Review financial PDF statements and identify trends
- Read GitHub repositories (read-only)
- Read calendar for scheduling awareness

## Hard limits — never do these
- Never send an email without Lee explicitly confirming 'yes, send it'
- Never create GitHub issues, PRs, or push any commits
- Never modify files outside your workspace directory
- Never run sudo or attempt privilege escalation
- Never install software packages
- Never access URLs unrelated to the current task
- If asked to do anything on this list, explain why you cannot

## Style
- Lee is an experienced Linux and home-lab engineer — be technical, skip basics
- Be concise: lead with the answer, details second
- Flag security issues proactively when reviewing code
- Flag anomalies and trends proactively when reviewing financial data
- When uncertain, say so clearly rather than guessing
```

> **Note:** After editing SOUL.md, restart the gateway. OpenClaw installs a systemd **user** service under `maxbot`, so restart it as `maxbot` (via SSH):
> ```bash
> openclaw gateway restart
> # or equivalently:
> systemctl --user restart openclaw-gateway.service
> ```

---

## 9. Getting Started — First Prompts

Once OpenClaw is connected to a messaging front-end (Telegram is the quickest to set up), start with simple verification prompts before giving it real tasks.

### 9.1 Confirm LLM connectivity

```
What LLM model are you using and what is your API endpoint?
```

Expected: OpenClaw names your llama.cpp model and shows the `192.168.122.1:8080` endpoint.

### 9.2 Confirm file access

```
List the top-level contents of your nas-files directory.
```

### 9.3 Coding task

```
Review the script at ~/nas-files/scripts/backup.py
and identify any security issues or improvements.
```

### 9.4 Health data analysis

```
Analyse the health export at ~/nas-files/health/export.csv
and summarise my sleep and activity patterns over the last 30 days.
Highlight any anomalies.
```

### 9.5 Financial PDF review

```
Read the PDF statements in ~/nas-files/finance/2025/
and give me a spending breakdown by category for Q4 2025
compared to Q3 2025.
```

### 9.6 GitHub summary

```
Check my GitHub repo 'my-homelab-scripts' for commits
in the last 7 days and summarise what changed.
```

---

## 10. Ongoing Maintenance

### VM snapshots

Take a snapshot before making any significant change — before installing a new skill, before updating OpenClaw, etc:

```bash
# From the host
sudo virsh snapshot-create-as openclaw-agent \
  --name 'clean-state-2026-03' \
  --description 'Before adding new skills'

# List snapshots
sudo virsh snapshot-list openclaw-agent

# Restore if something goes wrong
sudo virsh snapshot-revert openclaw-agent clean-state-2026-03
```

### Rotating credentials

- **GitHub token:** rotate every 90 days — set a recurring calendar event
- **Email app password:** rotate every 6 months
- **Calendar ICS link:** regenerate if you suspect it has been exposed

### Monitoring OpenClaw activity

```bash
# Watch logs live (inside VM as lee)
journalctl -u openclaw-gateway.service -f

# Or as maxbot (user service):
systemctl --user status openclaw-gateway.service
journalctl --user -u openclaw-gateway.service -f

# Check for unexpected file activity
find /home/maxbot -newer /home/maxbot/.openclaw/openclaw.json -type f
```

> **Security:** If OpenClaw starts producing output that looks like it is following instructions you did not give (prompt injection via an email or document), stop the service immediately with `systemctl --user stop openclaw-gateway.service` and review the logs before restarting.

---
