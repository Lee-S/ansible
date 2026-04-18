#!/bin/bash
# start-openclaw.sh
# Run after reboot to start llama-server (in distrobox) + openclaw VM + openclaw gateway.
#
# Usage:  ./start-openclaw.sh
# Attach to llama-server output:  tmux attach -t llama-server

set -euo pipefail

DISTROBOX_NAME="llama-rocm-7.2"
VM_NAME="openclaw-agent"
OPENCLAW_USER="maxbot"
MODEL="/home/lee/models/qwen3.5-122B-A10B/Q4_K_M/Qwen3.5-122B-A10B-Q4_K_M-00001-of-00003.gguf"
TMUX_SESSION="llama-server"

# ── 1. Start llama-server inside the distrobox ───────────────────────────────
echo "==> Starting llama-server in distrobox '$DISTROBOX_NAME'..."

if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    echo "    tmux session '$TMUX_SESSION' already exists — skipping."
else
    tmux new-session -d -s "$TMUX_SESSION" \
        "distrobox enter --name $DISTROBOX_NAME -- \
            llama-server \
              -m $MODEL \
              -c 32768 \
              -ngl 999 \
              -fa 1 \
              --no-mmap \
              --host 0.0.0.0 \
              --port 8080 \
        ; echo ''; echo '--- llama-server exited (code: '$?') ---'; read -r -p 'Press Enter to close...'"
    echo "    llama-server started. Attach with: tmux attach -t $TMUX_SESSION"
fi

# ── 2. Start the openclaw VM ─────────────────────────────────────────────────
echo "==> Starting VM '$VM_NAME'..."

VM_STATE=$(virsh domstate "$VM_NAME" 2>/dev/null || echo "unknown")
if [ "$VM_STATE" = "running" ]; then
    echo "    VM is already running."
else
    virsh start "$VM_NAME"
fi

# ── 3. Get VM IP from virsh ───────────────────────────────────────────────────
echo "==> Resolving IP for VM '$VM_NAME'..."

IP_TIMEOUT=60
IP_ELAPSED=0
OPENCLAW_IP=""
until [ -n "$OPENCLAW_IP" ]; do
    if [ "$IP_ELAPSED" -ge "$IP_TIMEOUT" ]; then
        echo "ERROR: Timed out waiting for VM to get an IP after ${IP_TIMEOUT}s." >&2
        exit 1
    fi
    OPENCLAW_IP=$(virsh domifaddr "$VM_NAME" 2>/dev/null \
        | awk '/ipv4/ {split($4, a, "/"); print a[1]}' | head -1)
    if [ -z "$OPENCLAW_IP" ]; then
        echo "    ...waiting for DHCP lease (${IP_ELAPSED}s)"
        sleep 5
        IP_ELAPSED=$((IP_ELAPSED + 5))
    fi
done
echo "    VM IP: $OPENCLAW_IP"

# ── 4. Wait for SSH to be ready ──────────────────────────────────────────────
echo "==> Waiting for $OPENCLAW_USER@$OPENCLAW_IP to accept SSH..."

TIMEOUT=120
ELAPSED=0
until ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no \
        "$OPENCLAW_USER@$OPENCLAW_IP" "echo ready" &>/dev/null; do
    if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
        echo "ERROR: Timed out waiting for SSH after ${TIMEOUT}s." >&2
        exit 1
    fi
    echo "    ...retrying (${ELAPSED}s)"
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done
echo "    SSH ready."

# ── 5. Start openclaw gateway ────────────────────────────────────────────────
echo "==> Starting openclaw gateway..."

ssh -o BatchMode=yes -o StrictHostKeyChecking=no \
    "$OPENCLAW_USER@$OPENCLAW_IP" \
    "systemctl --user start openclaw-gateway.service && \
     systemctl --user status openclaw-gateway.service --no-pager"

echo ""
echo "==> Done."
echo "    llama-server:  tmux attach -t $TMUX_SESSION"
echo "    openclaw logs: ssh $OPENCLAW_USER@$OPENCLAW_IP 'journalctl --user -u openclaw-gateway.service -f'"
