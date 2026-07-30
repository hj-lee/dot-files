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

export EMACSCLIENT_AUTO="$DIR/emacsclient-auto.sh"

function ssh-ecf {
    local remote="${1}"
    local server_socket
    server_socket=$(command emacsclient -e '(expand-file-name server-name server-socket-dir)' \
                    2>/dev/null | sed 's/"//g')
    if [[ -z $server_socket || ! -S $server_socket ]]; then
        echo "ssh-ecf: no local Emacs server socket found; start Emacs first" >&2
        return 1
    fi
    # Remove any stale forwarded socket first: sshd here does not honour
    # StreamLocalBindUnlink, so after an ungraceful disconnect the leftover
    # file makes the -R bind (and thus the whole connection, given
    # ExitOnForwardFailure) fail. The bind happens at session setup, before any
    # remote command runs, so this must be a separate prior connection.
    command ssh "$remote" rm -f /tmp/emacs-remote-socket
    command ssh -o ExitOnForwardFailure=yes \
                -R "/tmp/emacs-remote-socket:$server_socket" "${@}"
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

add-to-path-end ~/bin
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

# Open magit for each given directory (default "."), each in its own new
# frame, as that frame's only window.
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
    local arg d
    for arg in "${@:-.}"; do
        # Absolute path: default-directory is interpreted in the Emacs that
        # evaluates this, which may be on the other side of an ssh-ecf forward.
        d=$(cd "$arg" 2>/dev/null && pwd -P) || {
            echo "magit: no such directory: $arg" >&2
            return 1
        }
        emacsclient -e "(let* ((non-essential nil)
                               (frame (or (condition-case nil (make-frame) (error nil))
                                          (selected-frame))))
                          (select-frame-set-input-focus frame)
                          (with-selected-frame frame
                            (let ((default-directory \"${EMACSCLIENT_TRAMP_PREFIX}${d}/\"))
                              (magit-status-setup-buffer default-directory)
                              (delete-other-windows (frame-selected-window frame))))
                          t)" > /dev/null || return 1
    done
}

# ## chemacs

# alias de='\emacs --with-profile doom'
# alias den='\emacs --with-profile doom-noevil'

## local-common-init.sh

local_init=$DIR/local-common-init.sh

if [[ -e $local_init ]]; then
   source $local_init
fi
