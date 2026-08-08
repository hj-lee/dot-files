####
# ssh with tmux
#
# Two flavours, differing in which end runs tmux:
#
#   ssht / sshts   tmux on the REMOTE host, so the session itself outlives a
#                  dropped connection. --ecf adds the ssh-ecf Emacs forward.
#   tssh-ecf       tmux LOCALLY, for the sole purpose of keeping an ssh-ecf
#                  connection alive; the remote side is a plain login shell.
#
# --ecf largely subsumes what tssh-ecf is for: the remote session survives on
# its own, and reattaching re-binds the socket. emacsclient-auto.sh resolves
# that socket per call rather than at login, so a pane that outlived the drop
# picks the new forward up on its next emacsclient. tssh-ecf remains the way
# to get the forward without a remote tmux at all.
#
# The forward itself is set up by ecf-prepare, which stays in
# common-bash-zsh-init.sh because ssh-ecf must work under bash too.
#
# zsh-only -- ${(q-)@} in ssht, the <-> glob in tssh-ecf -- so this file is
# sourced from init.zsh rather than common-bash-zsh-init.sh.

# ssht [-h] [--ecf] host [tmux-args...]
#
# Each argument is shell-quoted before being handed to ssh: ssh joins its
# command words with spaces and the remote shell re-splits them, so without
# quoting `-n "my name"` would arrive as two arguments.
#
# tmux -u, because tmux is the ssh *command* here: the remote login shell runs
# non-interactively, never reads its .zshrc, and so never sets the LC_ALL that
# common-bash-zsh-init.sh exports. ssh does not forward the local one either
# (no SendEnv). The client then decides the terminal is not UTF-8 and prints
# every non-ASCII cell as `_'. -u asserts UTF-8 regardless of the locale,
# which also covers a remote that has no en_US.UTF-8 to fall back on.
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

    command ssh "${sshopts[@]}" "$remote" -t tmux -u ${(q-)@}
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

####
# tmux front-end for ssh-ecf: one session per remote host.
#
#   tssh-ecf <host>  attach to that host's ssh-ecf session, reconnecting if
#                    the connection dropped; create the session if absent.
#   tssh-ecf         list the existing ssh-ecf-* sessions and their state.
#
# Session names are ssh-ecf-<host> built from the alias as typed, so `cld`
# and `clouddesk` get separate sessions even though they are the same
# machine. Names must be sanitised: tmux accepts `.` and `:` in a session
# name but then cannot target it (they are the session:window.pane
# delimiters), leaving a session that can only be killed via its $id.
#
# Three tmux details drive the rest of this shape:
#   - ssh-ecf is a shell function, so tmux (which execs its argv directly)
#     cannot run it; it must be wrapped in an interactive login shell.
#   - `tmux new -A` IGNORES its shell-command when the session already
#     exists, so reconnecting has to be done explicitly via send-keys.
#   - `exec zsh -li` keeps the pane alive after ssh exits; without it the
#     session is destroyed on disconnect and there is nothing to revive.
function tssh-ecf {
    if [[ $# -eq 0 ]]; then
        local found=0 name state
        while IFS=' ' read -r name state; do
            [[ -z $name ]] && continue
            found=1
            if [[ $state == *ssh* ]]; then
                printf '  %-28s (%s, live)\n' "$name" "$state"
            else
                printf '  %-28s (%s, dropped)\n' "$name" "$state"
            fi
        done < <(tmux list-sessions -F '#{session_name} #{pane_current_command}' 2>/dev/null \
                 | grep '^ssh-ecf-')
        if (( ! found )); then
            echo "tssh-ecf: no ssh-ecf sessions; run 'tssh-ecf <host>'" >&2
            return 1
        fi
        return 0
    fi

    local host="${1}"
    # Strip any user@ prefix, keep IPs whole, otherwise keep the first DNS
    # label, then replace anything tmux cannot target.
    local tag="${host#*@}"
    if [[ $tag == <->.<->.<->.<-> ]]; then
        tag="${tag//./_}"
    else
        tag="${tag%%.*}"
    fi
    tag="${tag//[^a-zA-Z0-9_-]/_}"

    local session="ssh-ecf-${tag}"
    local cmd="ssh-ecf $host; exec zsh -li"

    if tmux has-session -t "=$session" 2>/dev/null; then
        # Revive only if ssh is gone; pane_current_command is `ssh` while live.
        if [[ "$(tmux list-panes -t "=$session" -F '#{pane_current_command}' 2>/dev/null)" != *ssh* ]]; then
            # send-keys takes a PANE target; bare "=name" is parsed as a pane
            # spec and fails to resolve, so anchor with a trailing colon.
            tmux send-keys -t "=$session:" "ssh-ecf $host" C-m
        fi
    else
        tmux new-session -d -s "$session" zsh -lic "$cmd" || return 1
    fi

    # switch-client when already inside tmux; attach otherwise.
    if [[ -n $TMUX ]]; then
        tmux switch-client -t "=$session"
    else
        tmux attach-session -t "=$session"
    fi
}
