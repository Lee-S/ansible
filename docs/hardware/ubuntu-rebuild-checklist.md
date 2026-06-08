# Ubuntu Rebuild Checklist

**Date:** 2026-06-08

---

## Drives

| Device | Model | Size | Role |
|---|---|---|---|
| nvme0n1 | Kingston OM8TAP42048K1-A00 (OEM) | 1.9TB | Windows (keep p1–p4) + `/data/models` |
| nvme1n1 | Crucial CT2000P310SSD8 (P310) | 1.8TB | Linux (all partitions) |

---

## Target Partition Layout

### nvme1n1 — Crucial P310 (wipe everything, create fresh)

| Partition | Size | FS | Mount |
|---|---|---|---|
| p1 | 1GB | vfat | `/boot/efi` |
| p2 | 100GB | btrfs | `/` |
| p3 | 500GB | btrfs | `/home` |
| p4 | ~1.2TB (remainder) | btrfs | `/data/vms` |

### nvme0n1 — Kingston (keep p1–p4, delete p5–p8, add new p5)

| Partition | Size | FS | Mount | Action |
|---|---|---|---|---|
| p1 | 1GB | vfat | — | **KEEP** — Windows EFI |
| p2 | 16MB | — | — | **KEEP** — Windows MSR |
| p3 | 538GB | ntfs | — | **KEEP** — Windows |
| p4 | 1.3GB | ntfs | — | **KEEP** — Windows recovery |
| p5 | ~1.35TB (remainder) | btrfs | `/data/models` | **CREATE NEW** |

---

## Step 1 — Pre-Install

- [ ] Back up anything important from old Linux partitions
- [ ] Note WiFi password (installer needs network for updates)
- [ ] Boot Ubuntu USB installer

---

## Step 2 — Partition Disks (Ubuntu Installer — Manual/Custom layout)

### nvme1n1 — Crucial (full wipe)

- [ ] Delete all existing partitions on nvme1n1
- [ ] Create p1: 1GB, vfat, mount `/boot/efi`
- [ ] Create p2: 100GB, btrfs, mount `/`
- [ ] Create p3: 500GB, btrfs, mount `/home`
- [ ] Create p4: remaining space (~1.2TB), btrfs, mount `/data/vms`

### nvme0n1 — Kingston (partial — Windows side untouched)

- [ ] **DO NOT touch p1, p2, p3, p4** (Windows partitions)
- [ ] Delete p5, p6, p7, p8, p9 (old Linux partitions — currently p5=swap, p6=Nobara root, p7=/boot, p8=old EFI, p9=data)
- [ ] Create p5: remaining space (~1.35TB), btrfs — **do not assign a mount point in the installer**
  - This will be mounted manually after install via fstab

### EFI

- [ ] Set installer EFI target to **nvme1n1p1** (the new vfat partition)
- [ ] **Do NOT format nvme0n1p1** — that is the Windows EFI

---

## Step 3 — Install Ubuntu

- [ ] Complete the Ubuntu installer (username, timezone, etc.)
- [ ] Let installer finish and reboot — remove USB when prompted

---

## Step 4 — Post-Install: Mount `/data/models`

Open a terminal and find the UUID of the new Kingston data partition:

```bash
sudo blkid /dev/nvme0n1p5
```

Add the mount to fstab:

```bash
sudo mkdir -p /data/models
sudo nano /etc/fstab
```

Add this line (replace `YOUR-UUID` with the UUID from blkid):

```
UUID=YOUR-UUID  /data/models  btrfs  defaults  0  2
```

Test it:

```bash
sudo mount -a
df -h /data/models
```

---

## Step 5 — Post-Install: Restore Windows in GRUB

```bash
sudo apt install os-prober
sudo nano /etc/default/grub
```

Set (or add):

```
GRUB_DISABLE_OS_PROBER=false
```

Save, then:

```bash
sudo update-grub
```

Confirm output includes a line like:
`Found Windows Boot Manager on /dev/nvme0n1p1`

---

## Step 6 — Post-Install: Run Ansible Playbook

```bash
cd ~/repos/ansible
./validate.sh
ansible-playbook local_setup.yml --ask-vault-pass --ask-become-pass
```

---

## Notes

- Swap: Ubuntu creates a swapfile in `/` by default — no swap partition needed
- `/data` directory is created automatically when both partitions mount under it
- btrfs compression can be enabled later with `mount -o compress=zstd` if desired
