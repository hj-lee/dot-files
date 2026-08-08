#!/bin/sh
#
# emacsclient-auto.sh -- route emacsclient to a forwarded (laptop) Emacs when
# its socket is live, otherwise fall back to the local Emacs server.
#
# Used both as $EDITOR (git execs it directly, so this must be a real script,
# not a shell function) and behind the `emacsclient` override installed by the
# `emacs-remote` shell function (see common-bash-zsh-init.sh).
#
# Env knobs (all optional):
#   EMACSCLIENT_TRAMP_PREFIX   e.g. /ssh:hwjlee@cld:  -- empty => never route remote
#   EMACSCLIENT_FORWARD_SOCKET forwarded socket path  -- default /tmp/emacs-remote-socket
#   EMACSCLIENT_BIN            explicit path to the real emacsclient
#   EMACSCLIENT_AUTO_DEBUG=1   print which branch was taken, to stderr

socket="${EMACSCLIENT_FORWARD_SOCKET:-/tmp/emacs-remote-socket}"

# Resolve this script's own canonical path, to skip it when scanning PATH.
self=$(command -v -- "$0" 2>/dev/null || printf '%s' "$0")
self=$(readlink -f -- "$self" 2>/dev/null || printf '%s' "$self")

# Resolve the real emacsclient binary.
real="${EMACSCLIENT_BIN:-}"
if [ -z "$real" ]; then
    IFS=:
    for dir in $PATH; do
        [ -n "$dir" ] || dir=.
        cand="$dir/emacsclient"
        [ -x "$cand" ] || continue
        canon=$(readlink -f -- "$cand" 2>/dev/null || printf '%s' "$cand")
        [ "$canon" = "$self" ] && continue   # skip ourselves (recursion guard)
        real="$cand"
        break
    done
    unset IFS
fi
if [ -z "$real" ]; then
    echo "emacsclient-auto: could not find the real emacsclient on PATH" >&2
    exit 127
fi

debug() { [ -n "$EMACSCLIENT_AUTO_DEBUG" ] && echo "emacsclient-auto: $1" >&2; }

# EMACSCLIENT_TRAMP rewrites *file* arguments into TRAMP paths, but it hangs
# --eval invocations. So detect eval calls and route them via the socket only,
# without the prefix -- eval strings (e.g. the `magit` alias) carry their own
# TRAMP path already.
is_eval=
for arg in "$@"; do
    case "$arg" in
        -e|--eval|--eval=*) is_eval=1; break ;;
    esac
done

# Route to the forwarded Emacs only if the socket exists, a prefix is set, and
# the server actually answers (an ungraceful disconnect leaves a stale socket).
if [ -S "$socket" ] && [ -n "$EMACSCLIENT_TRAMP_PREFIX" ] && \
   EMACS_SOCKET_NAME="$socket" timeout 2 "$real" -e t >/dev/null 2>&1; then
    if [ -n "$is_eval" ]; then
        debug "remote eval via $socket (no tramp prefix)"
        EMACS_SOCKET_NAME="$socket" exec "$real" "$@"
    fi
    debug "remote via $socket (prefix $EMACSCLIENT_TRAMP_PREFIX)"
    EMACS_SOCKET_NAME="$socket" EMACSCLIENT_TRAMP="$EMACSCLIENT_TRAMP_PREFIX" \
        exec "$real" "$@"
fi

debug "local ($real)"
exec "$real" "$@"
