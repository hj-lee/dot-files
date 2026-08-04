####
# ssh with tmux
#
# Runs tmux on the REMOTE host, so the session outlives a dropped
# connection. (Contrast tssh-ecf in common-bash-zsh-init.sh, which runs tmux
# LOCALLY to keep an ssh-ecf Emacs forward alive.)
#
# zsh-only -- uses ${(q-)@} -- so this file is sourced from init.zsh rather
# than common-bash-zsh-init.sh.

# ssht [-h] host [tmux-args...]
#
# Each argument is shell-quoted before being handed to ssh: ssh joins its
# command words with spaces and the remote shell re-splits them, so without
# quoting `-n "my name"` would arrive as two arguments.
function ssht {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: ssht [-h] host [tmux-args...]"
        return 0
    fi
    if (( $# == 0 )); then
        echo "ssht: no host given; usage: ssht [-h] host [tmux-args...]" >&2
        return 1
    fi
    local remote="$1"
    shift
    command ssh "$remote" -t tmux ${(q-)@}
}

# sshts [-h] host [tmux-opts...] SESSION [command...]
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
#   alias sshcldzc='sshcldts -c workplace/zatanna/src/FlexZatannaCDK'
#   alias sshcldzce='sshcldzc zcke emacs'
function sshts {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: sshts [-h] host [tmux-opts...] SESSION [command...]"
        return 0
    fi
    if (( $# == 0 )); then
        echo "sshts: no host given; usage: sshts [-h] host [tmux-opts...] SESSION [command...]" >&2
        return 1
    fi
    local remote="$1"
    shift

    # Leading dashed args are new-session's; the first bare word is the
    # session name. Value-taking options must consume their value here, or it
    # would be taken for the session name.
    local -a topts
    while [[ "$1" == -* ]]; do
        case "$1" in
            -c|-n|-e|-f|-F|-t|-x|-y) topts+=("$1" "$2"); shift 2 ;;
            *)                       topts+=("$1");     shift   ;;
        esac
    done

    if (( $# == 0 )); then
        echo "sshts: SESSION is required; usage: sshts [-h] host [tmux-opts...] SESSION [command...]" >&2
        return 1
    fi
    local session="$1"
    shift

    ssht "$remote" new-session -A "${topts[@]}" -s "$session" "${@}"
}
