####
# ssh with tmux
#
# Runs tmux on the REMOTE host, so the session outlives a dropped
# connection. (Contrast tssh-ecf in common-bash-zsh-init.sh, which runs tmux
# LOCALLY for the sole purpose of keeping an ssh-ecf Emacs forward alive.)
#
# --ecf adds that same forward here, which subsumes what tssh-ecf is for: the
# remote session survives on its own, and reattaching re-binds the socket.
# emacsclient-auto.sh resolves the socket per call rather than at login, so a
# long-lived pane picks the new forward up on its next emacsclient.
#
# zsh-only -- uses ${(q-)@} -- so this file is sourced from init.zsh rather
# than common-bash-zsh-init.sh.

# ssht [-h] [--ecf] host [tmux-args...]
#
# Each argument is shell-quoted before being handed to ssh: ssh joins its
# command words with spaces and the remote shell re-splits them, so without
# quoting `-n "my name"` would arrive as two arguments.
#
# --ecf reverse-forwards the laptop's Emacs socket (see ecf-prepare in
# common-bash-zsh-init.sh). It has to precede the host, since everything after
# the host is tmux's.
function ssht {
    local ecf=0
    while [[ "$1" == -* ]]; do
        case "$1" in
            -h|--help)
                echo "Usage: ssht [-h] [--ecf] host [tmux-args...]"
                return 0 ;;
            --ecf) ecf=1; shift ;;
            *)     break ;;
        esac
    done
    if (( $# == 0 )); then
        echo "ssht: no host given; usage: ssht [-h] [--ecf] host [tmux-args...]" >&2
        return 1
    fi
    local remote="$1"
    shift

    local -a sshopts
    if (( ecf )); then
        ecf-prepare "$remote" ssht || return 1
        sshopts=("${ECF_SSH_OPTS[@]}")
    fi

    command ssh "${sshopts[@]}" "$remote" -t tmux ${(q-)@}
}

# sshts [-h] [--ecf] host [tmux-opts...] SESSION [command...]
#
# Attach to SESSION on host, creating it if absent (tmux new-session -A).
#
# SESSION is mandatory: -s is synthesized here rather than passed in, because
# without it tmux names the session after its default (0) and -A then matches
# *that*, so every invocation would silently share one session.
#
# tmux options come before the name, which keeps the layered aliases in
# local-zsh-init.zsh working -- they build a command up in stages, binding -c
# early and naming the session only in the final alias:
#
#   alias sshcldts='sshts cld'
#   alias sshcldzc='sshcldts --ecf -c workplace/zatanna/src/FlexZatannaCDK'
#   alias sshcldzce='sshcldzc zcke emacs'
#
# --ecf is accepted among those options as well as before the host, so an
# alias can add it at whatever stage it is decided. It is spelled long only:
# tmux's own -e (new-session -e VAR=VALUE) is taken, and tmux has no long
# options to collide with.
function sshts {
    local ecf=0
    while [[ "$1" == -* ]]; do
        case "$1" in
            -h|--help)
                echo "Usage: sshts [-h] [--ecf] host [tmux-opts...] SESSION [command...]"
                return 0 ;;
            --ecf) ecf=1; shift ;;
            *)     break ;;
        esac
    done
    if (( $# == 0 )); then
        echo "sshts: no host given; usage: sshts [-h] [--ecf] host [tmux-opts...] SESSION [command...]" >&2
        return 1
    fi
    local remote="$1"
    shift

    # Leading dashed args are new-session's; the first bare word is the
    # session name. Value-taking options must consume their value here, or it
    # would be taken for the session name. --ecf is ours, so it is pulled out
    # rather than collected -- tmux must never see it.
    local -a topts
    while [[ "$1" == -* ]]; do
        case "$1" in
            --ecf)                   ecf=1;             shift   ;;
            -c|-n|-e|-f|-F|-t|-x|-y) topts+=("$1" "$2"); shift 2 ;;
            *)                       topts+=("$1");     shift   ;;
        esac
    done

    if (( $# == 0 )); then
        echo "sshts: SESSION is required; usage: sshts [-h] [--ecf] host [tmux-opts...] SESSION [command...]" >&2
        return 1
    fi
    local session="$1"
    shift

    local -a ecfopt
    (( ecf )) && ecfopt=(--ecf)

    ssht "${ecfopt[@]}" "$remote" new-session -A "${topts[@]}" -s "$session" "${@}"
}
