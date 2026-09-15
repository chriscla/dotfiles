#!/usr/bin/env bash
#
# Bridge Bitwarden's SSH agent from the Windows host into WSL2.
#
# Bitwarden Desktop is a Windows app under WSL2, and serves its agent on the
# named pipe \\.\pipe\openssh-ssh-agent. WSL2 cannot connect to a named pipe
# directly, so socat listens on a Unix socket and relays each connection
# through npiperelay.exe. The socket is created at the same path Bitwarden uses
# natively on macOS and Linux, which is what lets ~/.ssh/config name one path
# for all three platforms.
#
# Idempotent and cheap on the warm path -- safe to call from every shell start.

set -uo pipefail

SOCK="$HOME/.bitwarden-ssh-agent.sock"
PIPE='//./pipe/openssh-ssh-agent'

# Only meaningful under WSL. Guard so a stray run on native Linux (where
# Bitwarden owns this socket itself) cannot clobber the real socket.
if ! grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
    exit 0
fi

# Warm path: is a relay already listening and answering? ssh-add exits 2 when
# it cannot reach an agent, and 0/1 when it can (1 just means "no keys yet"),
# so anything other than 2 means the existing socket is live.
if [ -S "$SOCK" ]; then
    SSH_AUTH_SOCK="$SOCK" ssh-add -l >/dev/null 2>&1
    [ $? -ne 2 ] && exit 0
fi

command -v socat >/dev/null 2>&1 || {
    echo "bw-ssh-agent-relay: socat not installed (brew install socat)" >&2
    exit 1
}

# WSL interop puts the Windows PATH on $PATH, so a scoop/winget shim is usually
# found directly; fall back to the default scoop location.
NPIPERELAY="$(command -v npiperelay.exe 2>/dev/null || true)"
if [ -z "$NPIPERELAY" ]; then
    for candidate in /mnt/c/Users/*/scoop/shims/npiperelay.exe; do
        [ -x "$candidate" ] && NPIPERELAY="$candidate" && break
    done
fi
[ -n "$NPIPERELAY" ] || {
    echo "bw-ssh-agent-relay: npiperelay.exe not found (scoop install npiperelay)" >&2
    exit 1
}

# Stale socket from a previous boot -- the liveness probe above already proved
# nothing is answering on it.
rm -f "$SOCK"

setsid socat "UNIX-LISTEN:$SOCK,fork,mode=0600" \
    "EXEC:\"$NPIPERELAY\" -ei -s $PIPE,nofork" >/dev/null 2>&1 &
