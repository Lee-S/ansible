# NVMe Benchmark & Partition Plan

**Date:** 2026-03-01

---

## Drives

| Device | Model | Size |
|---|---|---|
| nvme1n1 | Kingston OM8TAP42048K1-A00 (OEM) | 1.9TB |
| nvme0n1 | Crucial CT2000P310SSD8 (P310) | 1.8TB |

---

## Benchmark Results (fio, direct I/O)

| Test | Kingston (nvme1n1) | Crucial P310 (nvme0n1) | Winner |
|---|---|---|---|
| Sequential Write | 2,154 MB/s | 1,101 MB/s | Kingston +96% |
| Sequential Read | 1,985 MB/s | 1,440 MB/s | Kingston +38% |
| Random 4K Write | 452 MB/s | 562 MB/s | Crucial +24% |
| Random 4K Read | 184 MB/s | 319 MB/s | Crucial +73% |

- Sequential tests: 4GB file, 1M block size, QD8, 1 job, 30s
- Random tests: 4GB file, 4K block size, QD32, 4 jobs, 20s

### Why Crucial wins random despite lower sequential

Sequential speed = raw bandwidth (large contiguous transfers).
Random 4K speed = controller latency + NAND parallelism (many small scattered requests).
These are independent axes. The Kingston is an OEM drive tuned for sustained sequential
throughput, not peak random IOPS.

---

## Partition Layout

### nvme1n1 — Kingston (faster sequential, slower random)

| Partition | Size | FS | Mount | Status |
|---|---|---|---|---|
| p1 | 1GB | vfat | — | Windows EFI |
| p2 | 16MB | — | — | Windows MSR |
| p3 | 538GB | ntfs | — | Windows |
| p4 | 1.3GB | ntfs | — | Windows recovery |
| p5 | 31GB | swap | [SWAP] | Shared swap |
| p6 | 150GB | btrfs | `/` | Nobara root (30G used) |
| p7 | 1GB | ext4 | `/boot` | **72% full — clean old kernels** |
| p8 | 600MB | vfat | `/boot/efi` | Linux EFI (shared) |
| — | ~1.2TB | — | — | Unallocated |

### nvme0n1 — Crucial P310 (faster random, slower sequential)

| Partition | Size | FS | Mount | Status |
|---|---|---|---|---|
| p1 | 500GB | btrfs | `/home` | Nobara home (14G used) |
| p2 | 466GB | btrfs | `/data` | VMs + LLM models (94G used) |
| p3 | 150GB | btrfs | `/` | **Ubuntu root — NEW** |
| p4 | 350GB | btrfs | `/home` | **Ubuntu home — NEW** |
| — | ~397GB | — | — | Unallocated |

---

## Workload Assessment

| Workload | Drive | Verdict |
|---|---|---|
| Nobara root `/` | Kingston | Suboptimal — OS is random I/O heavy, Crucial would be better |
| Windows | Kingston | Correct |
| Nobara `/home` | Crucial | Correct |
| Ubuntu root `/` | Crucial | Correct — better random I/O |
| Ubuntu `/home` | Crucial | Correct |
| VMs (`/data`) | Crucial | Correct — VMs need random I/O |
| LLM models (`/data`) | Crucial | Suboptimal — loading is sequential, Kingston would be ~38% faster |

---

## Boot Management

- **Bootloader:** GRUB, installed by Ubuntu (install Ubuntu last)
- **EFI:** Ubuntu uses existing `/boot/efi` on nvme1n1p8
- GRUB will auto-detect Nobara and Windows via `os-prober`
- Enable os-prober in Ubuntu after install: set `GRUB_DISABLE_OS_PROBER=false` in `/etc/default/grub`, then run `sudo update-grub`

---

## Action Items

- [ ] Clean Nobara old kernels before installing Ubuntu (`sudo dnf remove --oldinstallonly`) — `/boot` is 72% full
- [ ] Create nvme0n1p3 (150GB btrfs) — Ubuntu root
- [ ] Create nvme0n1p4 (350GB btrfs) — Ubuntu home
- [ ] Install Ubuntu, point installer at p3 for `/` and p4 for `/home`, use nvme1n1p8 for EFI (do not format it)
- [ ] After Ubuntu install: enable os-prober and run `sudo update-grub`
- [ ] Future: move LLM models to Kingston unallocated space for faster sequential loads
