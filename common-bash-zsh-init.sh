# -*- Shell-script -*-

export LC_ALL=en_US.UTF-8

function add-to-path {
  if [[ ! ( $PATH == "$1":* || $PATH == *:"$1":* || $PATH == *:"$1" ) && -d "$1" ]]; then
    # echo add "$1" to path
    export PATH="$1":${PATH}
  fi
}

function add-to-path-end {
  if [[ ! ( $PATH == "$1":* || $PATH == *:"$1":* || $PATH == *:"$1" ) && -d "$1" ]]; then
    # echo add "$1" to path
    export PATH=${PATH}:"$1"
  fi
}

####
# ssh with emacsclient port forwarding
#
# From the laptop:  ssh-ecf <host>            reverse-forwards the laptop's Emacs
#                                             server socket to the remote host.
# On the remote:    emacs-remote [ssh|sshx]   routes emacsclient / $EDITOR / magit
#                                             to the forwarded (laptop) Emacs when
#                                             its socket is live, else the local one.
#                   emacs-remote off          restore local-only behaviour.
# The per-call routing lives in emacsclient-auto.sh (see that file).
#
# The same forward is available on a remote-tmux connection: `ssht --ecf`,
# `sshts --ecf` (ssh-tmux.zsh) and `sshtsf -e` all go through ecf-prepare.

export EMACSCLIENT_AUTO="$DIR/emacsclient-auto.sh"

# Where the forward lands on the remote. The laptop-side counterpart to
# EMACSCLIENT_FORWARD_SOCKET, which emacsclient-auto.sh reads on the remote to
# find it; the two default to the same path and must agree.
: "${ECF_REMOTE_SOCKET:=/tmp/emacs-remote-socket}"

# ecf-prepare <remote> [label]
#
# Ready <remote> for an Emacs socket forward, and set ECF_SSH_OPTS to the ssh
# options that establish it. Returns 1 if no local Emacs server is running;
# label prefixes that message, so it names whichever front-end was run.
#
# The options are handed back in a global array rather than on stdout because
# they must stay distinct words; `arr=(...)` / `"${arr[@]}"` behave the same in
# bash and zsh, so both callers can splice them in.
#
# Callers: ssh-ecf below, and ssht (ssh-tmux.zsh) under --ecf.
#
# One socket per host, and the cleanup below unlinks it: opening a second ecf
# connection to a host silently kills the first one's forward. Harmless in
# practice, since every forward points at the same laptop Emacs and the newest
# one wins.
function ecf-prepare {
    local remote="${1}"
    local label="${2:-ecf}"
    local server_socket
    server_socket=$(command emacsclient -e '(expand-file-name server-name server-socket-dir)' \
                    2>/dev/null | sed 's/"//g')
    if [[ -z $server_socket || ! -S $server_socket ]]; then
        echo "$label: no local Emacs server socket found; start Emacs first" >&2
        return 1
    fi
    # Remove any stale forwarded socket first: sshd here does not honour
    # StreamLocalBindUnlink, so after an ungraceful disconnect the leftover
    # file makes the -R bind (and thus the whole connection, given
    # ExitOnForwardFailure) fail. The bind happens at session setup, before any
    # remote command runs, so this must be a separate prior connection.
    command ssh "$remote" rm -f "$ECF_REMOTE_SOCKET"
    ECF_SSH_OPTS=(-o ExitOnForwardFailure=yes
                  -R "$ECF_REMOTE_SOCKET:$server_socket")
}

function ssh-ecf {
    ecf-prepare "${1}" ssh-ecf || return 1
    command ssh "${ECF_SSH_OPTS[@]}" "${@}"
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

# Toggle routing of emacsclient / $EDITOR / magit to the forwarded (laptop)
# Emacs. Default method is ssh; use sshx if TRAMP stalls on the remote prompt.
#   emacs-remote [ssh|sshx] [user@host]
#   emacs-remote off
function emacs-remote {
    if [[ "$1" == off ]]; then
        unset EMACSCLIENT_TRAMP_PREFIX
        unset -f emacsclient 2>/dev/null
        export EDITOR=emacsclient
        return
    fi
    local method="${1:-ssh}"
    local target="${2:-${EMACS_REMOTE_TARGET:-$USER@$(hostname -s)}}"
    export EMACSCLIENT_TRAMP_PREFIX="/${method}:${target}:"
    export EDITOR="$EMACSCLIENT_AUTO"
    emacsclient() { command "$EMACSCLIENT_AUTO" "$@"; }
}

####
# picker plumbing
#
# Pickers themselves live where their domain does -- e.g. bws-pick (brazil
# workspace packages) is in LapinShell's scripts/brazil.zsh.

# Run a picker, then hand what it selected to a command.
# One line of picker output becomes one argument.
#
#   with-picker [-a|-e] PICKER [PICKER_ARG...] -- COMMAND [ARG...]
#   with-picker [-a|-e] PICKER COMMAND [ARG...]
#
#   -a, --all    pass every selection to a single invocation (default)
#                  -> COMMAND [ARG...] SEL1 SEL2 ...
#   -e, --each   invoke COMMAND once per selection
#                  -> COMMAND [ARG...] SEL1 ; COMMAND [ARG...] SEL2 ; ...
#
# Both the picker and the command can take their own arguments, so `--' marks
# where the picker's end and the command begins:
#   with-picker bws-pick -1 -- magit        # picker gets -1
#   with-picker bws-pick magit              # no picker args; -- optional
# Without a `--', everything after PICKER is the command.
#
# Use --each for commands that only accept one argument. With --each, a failing
# invocation stops the run and its status is returned.
# Aborting the picker (or selecting nothing) is a no-op, not an error.
function with-picker {
    local mode=all
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--all)  mode=all;  shift ;;
            -e|--each) mode=each; shift ;;
            --)        shift; break ;;
            -*)
                echo "with-picker: unknown option: $1" >&2
                return 2 ;;
            *) break ;;
        esac
    done
    local picker="$1"
    shift 2>/dev/null
    # Split remaining args at `--': before it belongs to the picker, after it
    # is the command. With no `--', all of it is the command.
    local -a picker_args
    picker_args=()
    local seen_sep=
    while [[ $# -gt 0 ]]; do
        if [[ "$1" == -- ]]; then
            seen_sep=1
            shift
            break
        fi
        picker_args+=("$1")
        shift
    done
    if [[ -z $seen_sep ]]; then
        # No separator: what we collected was really the command.
        set -- "${picker_args[@]}"
        picker_args=()
    fi
    [[ -n $picker && $# -gt 0 ]] || {
        echo "with-picker: usage: with-picker [-a|-e] PICKER [PICKER_ARG...] -- COMMAND [ARG...]" >&2
        return 2
    }
    local sel
    sel=$("$picker" "${picker_args[@]}") || return 1
    [[ -n $sel ]] || return 0
    local -a items
    items=()
    local line
    while IFS= read -r line; do
        [[ -n $line ]] && items+=("$line")
    done <<< "$sel"
    [[ ${#items[@]} -gt 0 ]] || return 0
    if [[ $mode == each ]]; then
        local item rc
        for item in "${items[@]}"; do
            "$@" "$item" || { rc=$?; return $rc; }
        done
        return 0
    fi
    "$@" "${items[@]}"
}


###

add-to-path ~/bin
add-to-path ~/usr/bin

### ruby

export RUBYOPT='-Ku'

###

export EDITOR=emacsclient

export LESSCHARSET=utf-8

### color

# export DIFFCOLORS=always

### idea

add-to-path ~/usr/idea/bin

### android-studio

add-to-path ~/usr/android-studio/bin


# ### global

# export GTAGSLABEL=pygments


### java

# export JAVA_MEM=-Xmx4096m
# export JAVA_STACK=-Xss1m


### rust


add-to-path ~/.cargo/bin



## Nautilus open in terminal Desktop hack

[[ $PWD = "/home/hjlee/Desktop" ]] && cd


# ## CMake

# export CMAKE_GENERATOR="Ninja"


#########
## alias

# alias ls='ls -F'
alias ll='ls -l'

#alias emacs='LANG=en_US.UTF-8 /usr/bin/emacs-snapshot-x'
#alias emacs="XMODIFIERS='' /usr/bin/emacs-snapshot-x"
# alias emacs="XMODIFIERS='' /mnt/archive/usr/emacs22/bin/emacs"
# alias emacs="LANG=en_US.UTF-8 XMODIFIERS='' /usr/bin/emacs"
# alias emacs="LANG=en_US.UTF-8 XMODIFIERS='' /home/hjlee/usr/emacs/bin/emacs"
alias emacs="LANG=en_US.UTF-8 XMODIFIERS='' emacs"
alias e=emacs
alias h=history
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

# alias mem='cat /proc/meminfo'

alias la='ls -a'
alias lstl='ls -tl | less'
alias lsatl='ls -atl | less'
alias lstla='ls -atl | less'
alias lssl='ls -Sl | less'

alias dusl='du $* | sort -nr | less'

alias l='zless -i'

alias ko='LANG=ko_KR'
alias ko.utf8='LANG=ko_KR.UTF-8'
alias en='LANG=en_US'
alias en.utf8='LANG=en_US.UTF-8'

# Open magit for each given directory (default ".").
#
#   magit [-n|--no-frame] [DIR...]
#
# By default each DIR opens in its own new frame, as that frame's only window.
# With -n/--no-frame, just open the magit buffer in the current frame (the old
# behaviour) and skip all frame handling.
#
# Notes on the elisp, each learned the hard way:
#  - `non-essential' must be nil. emacsclient -e evaluates with it non-nil,
#    which tells TRAMP not to open connections for "speculative" work; TRAMP
#    then reports every remote file as nonexistent and magit silently does
#    nothing -- no error, no buffer.
#  - Create and select the frame BEFORE calling magit. magit-status-setup-buffer
#    displays via display-buffer, which acts on whichever frame is selected at
#    the time -- build the buffer first and it lands in the previous frame.
#  - make-frame fails in a headless daemon ("Unknown terminal type"), so fall
#    back to the selected frame there instead of aborting.
function magit {
    local frame=1
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--no-frame) frame=; shift ;;
            --)            shift; break ;;
            -*)
                echo "magit: unknown option: $1" >&2
                return 2 ;;
            *) break ;;
        esac
    done
    local arg d lisp
    for arg in "${@:-.}"; do
        # Absolute path: default-directory is interpreted in the Emacs that
        # evaluates this, which may be on the other side of an ssh-ecf forward.
        d=$(cd "$arg" 2>/dev/null && pwd -P) || {
            echo "magit: no such directory: $arg" >&2
            return 1
        }
        if [[ -n $frame ]]; then
            lisp="(let* ((non-essential nil)
                         (frame (or (condition-case nil (make-frame) (error nil))
                                    (selected-frame))))
                    (select-frame-set-input-focus frame)
                    (with-selected-frame frame
                      (let ((default-directory \"${EMACSCLIENT_TRAMP_PREFIX}${d}/\"))
                        (magit-status-setup-buffer default-directory)
                        (delete-other-windows (frame-selected-window frame))))
                    t)"
        else
            lisp="(let ((non-essential nil)
                        (default-directory \"${EMACSCLIENT_TRAMP_PREFIX}${d}/\"))
                    (magit-status-setup-buffer default-directory)
                    t)"
        fi
        emacsclient -e "$lisp" > /dev/null || return 1
    done
}

# ## chemacs

# alias de='\emacs --with-profile doom'
# alias den='\emacs --with-profile doom-noevil'

####
# Auto-enable emacs-remote routing on interactive ssh sessions.
#
# ssh-ecf (run from the laptop) forwards the laptop's Emacs socket to the
# remote, but routing only takes effect once emacs-remote is called. Do that
# here so it happens automatically instead of as a manual step after login.
# Safe even when the socket wasn't forwarded (e.g. a plain, non-ecf ssh):
# emacsclient-auto.sh falls back to the local Emacs whenever the forwarded
# socket isn't live.
if [[ -n $SSH_CONNECTION && $- == *i* ]]; then
    emacs-remote
fi

## local-common-init.sh

local_init=$DIR/local-common-init.sh

if [[ -e $local_init ]]; then
   source $local_init
fi
