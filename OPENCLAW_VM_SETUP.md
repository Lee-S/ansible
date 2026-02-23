# OpenClaw VM Setup Guide

**Isolated AI Agent on QEMU/KVM · Nobara Linux · llama.cpp on port 8080**

---

## What this guide covers

- Install QEMU/KVM and virt-manager on Nobara Linux
- Create a secure, isolated VM for the OpenClaw AI agent
- User account strategy — `lee` (host admin) vs `maxbot` (VM agent user)
- Install and configure OpenClaw inside the VM
- Connect OpenClaw to your llama.cpp server on port 8080
- Grant scoped access: email, GitHub, calendar, NAS files
- Write your SOUL.md and starter prompts

---

## 1. Architecture Overview

OpenClaw is a capable autonomous agent that can send email, browse the web, run code, and manage files. Running it inside a QEMU/KVM virtual machine means any prompt injection attack, runaway task, or misconfiguration is contained at the hypervisor boundary — it cannot reach your NAS, Home Assistant, or host filesystem directly.

| Host OS (Nobara Linux) | VM Guest (Fedora Server) |
|---|---|
| llama.cpp server → port 8080 | OpenClaw agent (user: max-ai) |
| Your NAS (CIFS/NFS mounts) | Dedicated email account (IMAP) |
| Home Assistant | Read-only GitHub token |
| KVM hypervisor (user: lee) | Read-only calendar ICS |
| VirtIO-fs shared folder (read-only drop) | Isolated NAT network (no LAN access) |

> 🔒 **Security:** OpenClaw can execute shell commands and send emails. The VM is your primary safety layer. Never give `max-ai` sudo, never mount NAS read-write, and read every community skill before installing it.

---

## 2. User Account Strategy

**Do you need a separate admin account?**

Yes — this separation is worth doing. Keep `lee` as your host admin and confine `max-ai` entirely inside the VM.

| Account | Location | Role & Permissions |
|---|---|---|
| `lee` | Host OS | Your day-to-day admin. Manages KVM, mounts NAS, owns llama.cpp. Add to `libvirt` and `kvm` groups. Has sudo. |
| `lee` (VM) | Inside VM | Your admin account inside the VM too. Used for installing packages and configuring the OS. Has sudo inside the VM only. |
| `max-ai` | Inside VM only | The OpenClaw agent user. **NO sudo at all.** Owns only `~/.openclaw` and its workspace. This is the account OpenClaw runs as. |

> ⚠️ **Note:** Do not create a `max-ai` account on the host OS. If OpenClaw ever escapes its working directory inside the VM, it still cannot reach anything on the host.

---

## 3. Installing QEMU/KVM and virt-manager

### 3.1 Install the virtualisation stack

Nobara is Fedora-based so all standard Fedora virtualisation packages apply. Run these on the host as `lee`:

```bash
# Install the full virtualisation group
sudo dnf install @virtualization

# This pulls in: qemu-kvm  libvirt  virt-manager  virt-install
#                libvirt-client  bridge-utils  virtiofsd
```

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

> ⚠️ **Note:** On your Ryzen AI Max+ 395 with Nobara, KVM works out of the box. If `virt-host-validate` warns about IOMMU, that is fine for this use case — IOMMU passthrough is not needed for a pure software VM.

---

## 4. Creating the OpenClaw VM

### 4.1 Download a guest OS ISO

Fedora Server (minimal install) is the best choice — lightweight, matches your host ecosystem, and has first-class virtio support. Ubuntu Server 24.04 LTS is also fine.

```bash
sudo mkdir -p /var/lib/libvirt/images/isos
cd /var/lib/libvirt/images/isos

# Fedora 41 Server netinstall (~800 MB)
sudo wget https://download.fedoraproject.org/pub/fedora/linux/releases/41/Server/x86_64/iso/Fedora-Server-netinst-x86_64-41-1.4.iso

# OR Ubuntu Server 24.04 LTS
# sudo wget https://releases.ubuntu.com/24.04/ubuntu-24.04.2-live-server-amd64.iso
```

### 4.2 Create the VM

The following creates an isolated VM using NAT networking. OpenClaw can reach the internet and your host, but cannot reach other devices on your LAN directly:

```bash
sudo virt-install \
  --name openclaw-agent \
  --ram 8192 \
  --vcpus 4 \
  --disk path=/var/lib/libvirt/images/openclaw-agent.qcow2,size=40,format=qcow2 \
  --os-variant fedora41 \
  --cdrom /var/lib/libvirt/images/isos/Fedora-Server-netinst-x86_64-41-1.4.iso \
  --network network=default \
  --graphics spice \
  --video qxl \
  --channel unix,target.type=virtio,target.name=org.qemu.guest_agent.0
```

> ⚠️ **Note:** 8 GB RAM and 4 vCPUs is more than enough — OpenClaw does no local inference, it just talks to llama.cpp on your host. Bump disk to 60 GB if you plan to stage large file analysis jobs.

### 4.3 Complete the Fedora installation

virt-manager opens a graphical console to the installer. During setup:

- Choose **Minimal Install** — no desktop required
- Set hostname to `openclaw-agent`
- Create user `lee` inside the VM, mark as Administrator (this is your in-VM sudo account — separate from host `lee`)
- Do **NOT** create `max-ai` yet — do this after first boot
- Set a root password (emergency use only)

### 4.4 First boot — update and install essentials

Log in as `lee` inside the VM and run:

```bash
sudo dnf update -y

sudo dnf install -y curl wget git nodejs npm qemu-guest-agent

# Enable guest agent (allows clean shutdown from host)
sudo systemctl enable --now qemu-guest-agent

# Check Node version — OpenClaw needs 18+
node --version
```

### 4.5 Verify host connectivity from inside the VM

The KVM NAT default gateway — your host — is always reachable at `10.0.2.2`. Verify your llama.cpp server is reachable before going any further:

```bash
# From inside the VM:
curl http://10.0.2.2:8080/v1/models

# You should get a JSON response listing your loaded model.
# If this fails, check that llama.cpp is bound to 0.0.0.0
# (not 127.0.0.1) on the host.
```

> ✅ **Tip:** If llama.cpp only listens on `127.0.0.1`, restart it with `--host 0.0.0.0 --port 8080`. This makes it reachable from the VM but it remains firewalled from your wider LAN by your router.

---

## 5. Setting Up the max-ai User and File Access

### 5.1 Create the max-ai account (inside VM, as lee)

```bash
# Create maxbot with no sudo access
sudo useradd -m -s /bin/bash maxbot
sudo passwd max-ai

# Verify — this should say 'not allowed'
sudo -l -U max-ai
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

**Step 3 — inside the VM, mount it as max-ai's read-only folder:**

```bash
# Add to /etc/fstab inside the VM
echo 'nas-share  /home/max-ai/nas-files  virtiofs  ro,defaults  0  0' \
  | sudo tee -a /etc/fstab

sudo mount -a

# Verify
ls /home/max-ai/nas-files
```

---

## 6. Installing OpenClaw in the VM

### 6.1 Switch to max-ai and install

```bash
# Inside the VM — switch to max-ai
sudo su - max-ai

# Install OpenClaw
npm install -g @openclaw/openclaw

# Confirm installation
openclaw --version
```

### 6.2 Run the setup wizard

The wizard walks you through all initial configuration. Have your dedicated email credentials and GitHub token ready:

```bash
openclaw wizard

# Wizard prompts and recommended answers:
#
# Agent name:           Maxbot
# Your name:            Lee
# LLM provider:         OpenAI Compatible
# API base URL:         http://10.0.2.2:8080/v1
# API key:              none  (any string works, llama.cpp ignores it)
# Model name:           (paste the model name from curl /v1/models above)
# Workspace directory:  /home/max-ai/.openclaw/workspace
```

### 6.3 Verify the LLM connection

```bash
# Quick connectivity test
openclaw chat 'What model are you running? Reply in one sentence.'

# Should respond using your llama.cpp model.
# If you get a connection error, re-check that llama.cpp
# is listening on 0.0.0.0 not 127.0.0.1
```

### 6.4 Run as a systemd service (back as lee in VM)

Exit `maxbot` back to `lee`, then create a systemd unit so OpenClaw starts automatically:

```bash
exit   # back to lee

sudo tee /etc/systemd/system/openclaw.service > /dev/null <<'EOF'
[Unit]
Description=OpenClaw AI Agent Gateway
After=network.target

[Service]
Type=simple
User=maxbot
WorkingDirectory=/home/max-ai/.openclaw
ExecStart=/usr/local/bin/openclaw gateway
Restart=on-failure
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now openclaw

# Check it came up cleanly
sudo journalctl -u openclaw -n 30
```

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

> 🔒 **Security:** Do not install community OpenClaw skills without reading their source first. Stick to first-party skills initially. Community skills run with the same permissions as OpenClaw itself.

---

## 8. Configuring SOUL.md

SOUL.md is OpenClaw's personality and permission file. It is read at startup and governs what the agent will and will not do. Edit it as `max-ai` inside the VM:

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

> ⚠️ **Note:** After editing SOUL.md, restart the service: `sudo systemctl restart openclaw` (run as `lee` in the VM)

---

## 9. Getting Started — First Prompts

Once OpenClaw is connected to a messaging front-end (Telegram is the quickest to set up), start with simple verification prompts before giving it real tasks.

### 9.1 Confirm LLM connectivity

```
What LLM model are you using and what is your API endpoint?
```

Expected: OpenClaw names your llama.cpp model and shows the `10.0.2.2:8080` endpoint.

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
  --name 'clean-state-2025-02' \
  --description 'Before adding new skills'

# List snapshots
sudo virsh snapshot-list openclaw-agent

# Restore if something goes wrong
sudo virsh snapshot-revert openclaw-agent clean-state-2025-02
```

### Rotating credentials

- **GitHub token:** rotate every 90 days — set a recurring calendar event
- **Email app password:** rotate every 6 months
- **Calendar ICS link:** regenerate if you suspect it has been exposed

### Monitoring OpenClaw activity

```bash
# Watch logs live (inside VM as lee)
sudo journalctl -u openclaw -f

# Check for unexpected file activity
find /home/max-ai -newer /home/max-ai/.openclaw/openclaw.json -type f
```

> 🔒 **Security:** If OpenClaw starts producing output that looks like it is following instructions you did not give (prompt injection via an email or document), stop the service immediately with `sudo systemctl stop openclaw` and review the logs before restarting.

---

