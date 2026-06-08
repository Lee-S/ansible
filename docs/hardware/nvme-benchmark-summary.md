# NVMe Benchmark & Partition Plan

**Updated:** 2026-06-08 (original: 2026-03-01)

---

## Drives

| Device | Model | Size |
|---|---|---|
| nvme0n1 | Kingston OM8TAP42048K1-A00 (OEM) | 1.9TB |
| nvme1n1 | Crucial CT2000P310SSD8 (P310) | 1.8TB |

> **Note:** The original doc had nvme0n1 and nvme1n1 swapped — confirmed wrong by `lsblk` and `/sys/class/nvme/nvme*/model`.

> **Warning — device names are not stable:** `nvme0n1`/`nvme1n1` are assigned by kernel probe order at boot and can change after BIOS updates, kernel updates, or hardware changes. Never use these paths in fstab or scripts. Use UUIDs (per partition) or the stable by-id paths instead:
> - Kingston: `/dev/disk/by-id/nvme-KINGSTON_OM8TAP42048K1-A00_50026B73842AC518`
> - Crucial:  `/dev/disk/by-id/nvme-CT2000P310SSD8_253652B8226F`

---

## Benchmark Results

### 2026-06-08 (corrected — libaio, proper queue depth)

Test parameters match original intent: sequential = 4GB file, 1M block, QD8, 1 job, 30s; random = 4GB file, 4K block, QD32, 4 jobs, 20s.
All tests run via `--ioengine=libaio --direct=1` on btrfs partitions (`/datas` for Kingston, `/home/lee` for Crucial).

| Test | Kingston (nvme0n1) | Crucial P310 (nvme1n1) | Winner |
|---|---|---|---|
| Sequential Write | 837 MB/s | 1,018 MB/s | Crucial +22% |
| Sequential Read | 6,097 MB/s | 1,718 MB/s | Kingston +255% |
| Random 4K Write | 508 MB/s | 671 MB/s | Crucial +32% |
| Random 4K Read | 2,396 MB/s | 1,708 MB/s | Kingston +40% |

Kingston sequential read of ~6 GB/s is consistent with its PCIe 4.0 x4 spec (rated up to 7 GB/s).
Kingston sequential write of 837 MB/s reflects sustained speed after SLC cache exhaustion under a 30s continuous write.

### 2026-03-01 (original — DO NOT USE for decisions)

| Test | "nvme1n1" (was mislabelled Kingston) | "nvme0n1" (was mislabelled Crucial) | Winner claimed |
|---|---|---|---|
| Sequential Write | 2,154 MB/s | 1,101 MB/s | "Kingston" |
| Sequential Read | 1,985 MB/s | 1,440 MB/s | "Kingston" |
| Random 4K Write | 452 MB/s | 562 MB/s | "Crucial" |
| Random 4K Read | 184 MB/s | 319 MB/s | "Crucial" |

Problems with original benchmarks:
1. Device labels were wrong (nvme0n1 ↔ nvme1n1 swapped)
2. Used default `psync` ioengine, which caps queue depth at 1 regardless of `--iodepth` setting — random read/write numbers are especially unreliable

---

## What the New Numbers Mean

**Kingston (nvme0n1) strengths:** Sequential read is dominant (3.5× faster than Crucial). Random read also faster. This drive is the right choice for read-heavy large-file workloads: LLM model loading, VM disk images, OS serving executables.

**Kingston (nvme0n1) weakness:** Sustained sequential write is slower than Crucial (SLC cache exhausts quickly under continuous write).

**Crucial P310 (nvme1n1) strengths:** Better sustained write throughput (sequential and random). Suitable for workloads with frequent writes: home directory, active VM working sets, temp data.

**Revised workload assessment:**

| Workload | Drive | Verdict |
|---|---|---|
| Windows | Kingston (nvme0n1) | Correct — Windows is on this drive |
| `/data/models` (LLM weights) | Kingston (nvme0n1) | Correct — Kingston sequential read is 3.5× faster |
| Linux `/` (OS) | Crucial (nvme1n1) | Acceptable — Kingston is by necessity occupied by Windows; Kingston actually wins random read at QD32 but the practical difference at OS-level queue depths is small |
| Linux `/home` | Crucial (nvme1n1) | Correct — write-heavy, Crucial wins write |
| `/data/vms` (VM disks) | Crucial (nvme1n1) | Correct — VMs write frequently, Crucial wins write |

---

## Current Partition State (2026-06-08)

### nvme0n1 — Kingston (1.9TB)

| Partition | Size | FS | Mount | Notes |
|---|---|---|---|---|
| p1 | 1GB | vfat | `/boot/efi` | Windows EFI (currently also used by Linux GRUB) |
| p2 | 16MB | — | — | Windows MSR |
| p3 | 538GB | ntfs | — | Windows |
| p4 | 1.3GB | ntfs | — | Windows recovery |
| p5 | 31GB | swap | — | Old Nobara swap |
| p6 | 150GB | btrfs | — | Old Nobara root |
| p7 | 1GB | ext4 | — | Old Nobara /boot |
| p8 | 600MB | vfat | — | Old Linux EFI |
| p9 | 244GB | btrfs | `/datas` | Current data partition |
| — | ~1.1TB | — | — | Unallocated |

### nvme1n1 — Crucial P310 (1.8TB)

| Partition | Size | FS | Mount | Notes |
|---|---|---|---|---|
| p1 | 500GB | btrfs | — | Old Nobara /home |
| p2 | 466GB | btrfs | `/datar` | Current data partition |
| p3 | 140GB | btrfs | `/` | Current Ubuntu root |
| p4 | 279GB | btrfs | `/home` | Current Ubuntu /home |

---

## Boot Management

- **Bootloader:** GRUB, installed by Ubuntu
- **EFI:** Currently using nvme0n1p1 (Windows EFI partition, shared)
- GRUB detects Windows via `os-prober`; set `GRUB_DISABLE_OS_PROBER=false` in `/etc/default/grub` and run `sudo update-grub`
- Target rebuild plan moves Linux EFI to a dedicated partition on nvme1n1 (see ubuntu-rebuild-checklist.md)

---

## Rebuild Target Layout

See `ubuntu-rebuild-checklist.md` for the full step-by-step plan. Summary:

- **nvme0n1 (Kingston):** Keep Windows p1–p4, delete p5–p9, create new p5 (~1.35TB btrfs) → `/data/models`
- **nvme1n1 (Crucial):** Wipe everything, create p1 (1GB EFI), p2 (100GB `/`), p3 (500GB `/home`), p4 (~1.2TB `/data/vms`)
