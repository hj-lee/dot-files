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
# The tmux front-ends -- tssh-ecf, and ssht/sshts under --ecf -- are zsh-only
# and live in ssh-tmux.zsh; sshtsf -e is the same forward again, in Python.

export EMACSCLIENT_AUTO="$DIR/bin/emacsclient-auto.sh"

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
# Callers: ssh-ecf below, and ssht (ssh-tmux.zsh) under --ecf. Kept here
# rather than in ssh-tmux.zsh because ssh-ecf must work under bash too.
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

# Toggle routing of emacsclient / $EDITOR / $BROWSER / magit to the forwarded
# (laptop) Emacs. Default method is ssh; use sshx if TRAMP stalls on the remote
# prompt.
#   emacs-remote [ssh|sshx] [user@host]
#   emacs-remote off
function emacs-remote {
    if [[ "$1" == off ]]; then
        unset EMACSCLIENT_TRAMP_PREFIX
        unset -f emacsclient 2>/dev/null
        export EDITOR=emacsclient
        unset BROWSER
        return
    fi
    local method="${1:-ssh}"
    local target="${2:-${EMACS_REMOTE_TARGET:-$USER@$(hostname -s)}}"
    export EMACSCLIENT_TRAMP_PREFIX="/${method}:${target}:"
    export EDITOR="$EMACSCLIENT_AUTO"
    emacsclient() { command "$EMACSCLIENT_AUTO" "$@"; }
    # Send URLs to the laptop's browser via its Emacs. Absolute path because
    # $BROWSER is exec'd by other tools, which may not share our PATH.
    [[ -x $DIR/bin/ec-browse ]] && export BROWSER="$DIR/bin/ec-browse"
}

####
# keeping a pane's environment current across reconnections
#
# tmux copies the variables named in update-environment out of the attaching
# client and into the session, on every attach and not just on create --
# WAYLAND_DISPLAY among them, which is what lets `sshtsf -w' leave waypipe's
# randomly-named per-connection socket alone. So a session reattached over a
# fresh connection is already right, and so is every window and pane opened
# after that.
#
# What is not right is a shell that was ALREADY running in a pane: it still
# holds the values it inherited whenever it started, so a GUI application it
# launches goes looking for the socket of a connection that is gone. This hook
# is the fix. tmux emits the new values as shell syntax itself, so there is
# nothing to write anywhere -- just re-read them each prompt.
function tmux-env-refresh {
    # Costs one string test outside tmux, which is the laptop's usual case.
    [ -n "$TMUX" ] || return 0

    local out line
    # One call, not one per variable: show-environment takes at most one name,
    # so asking for five would mean five forks a prompt. Read the lot and
    # filter here.
    out=$(command tmux show-environment -s 2>/dev/null) || return 0

    while IFS= read -r line; do
        # A `case' pattern rather than a loop over a list of names: zsh does
        # not word-split unquoted parameters and bash does, and this file has
        # to behave identically under both.
        #
        # Only the assignments. show-environment also emits `unset FOO;' for
        # anything the attaching client lacks, and honouring that would strip
        # SSH_AUTH_SOCK out of every pane the moment you attach from a machine
        # with no agent. The price is that a dead WAYLAND_DISPLAY lingers after
        # attaching from a non-Wayland client rather than being cleared, which
        # is much the cheaper of the two failures.
        case $line in
            WAYLAND_DISPLAY=*|DISPLAY=*|SSH_AUTH_SOCK=*|SSH_CONNECTION=*|XAUTHORITY=*)
                eval "$line" ;;
        esac
    done <<< "$out"
}

# Registered once. A guard variable rather than testing membership of
# precmd_functions, because zsh's ${array[(I)name]} would still have to PARSE
# under bash, where it does not mean anything.
if [ -z "$TMUX_ENV_REFRESH_HOOKED" ]; then
    TMUX_ENV_REFRESH_HOOKED=1
    if [ -n "$ZSH_VERSION" ]; then
        precmd_functions+=(tmux-env-refresh)
    elif [ -n "$BASH_VERSION" ]; then
        PROMPT_COMMAND="tmux-env-refresh${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
    fi
fi

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


####
# Claude Code retry-watchdog mode
#
# CLAUDE_CODE_RETRY_WATCHDOG is the mode Claude Code sets for its own remote
# runners. It is undocumented, so all of the below is read out of the shipped
# binary rather than the docs, and an update could change it:
#
#  - the default retry count becomes 300 instead of 10, and an explicit
#    CLAUDE_CODE_MAX_RETRIES stops being clamped to 15;
#  - 429 and overload (529 / "overloaded_error") no longer count against that
#    limit at all, so those two never exhaust;
#  - a computed backoff over 60s no longer aborts the request -- waits are
#    honoured up to a 6-hour ceiling;
#  - repeated 529s stop raising the "overloaded" error, and a 529 on a
#    non-interactive caller stops being dropped.
#
# Which is to say: it trades failing fast for eventually succeeding, on the
# assumption nobody is watching. Two reasons it is a toggle rather than an
# export from this file: it also stops a plain 5xx from falling back to
# `fallbackModel', and a turn can sit for hours with nothing on screen.
#
#   claude-watchdog [-q] [on] [RETRIES]   export it into this shell
#   claude-watchdog [-q] off              unset both variables again
#   claude-watchdog status                report what this shell has set
#   claude-watchdog -q status             no output; exit 0 if on, 1 if off
#
# RETRIES sets CLAUDE_CODE_MAX_RETRIES as well; omit it to take the 300.
#
# -q silences the report, for an init file or a script. Since that leaves
# `status' with no way to answer, quiet status answers with its exit status
# instead -- `grep -q' rather than a mute `grep'. The loud form keeps returning
# 0 whatever the state: a bare claude-watchdog is something you type, and
# agnoster would paint the 1 as a failed command in the next prompt. Errors are
# on stderr either way, and -q does not suppress them.
function claude-watchdog {
    local quiet=
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -q|--quiet) quiet=1; shift ;;
            --)         shift; break ;;
            -*)
                echo "claude-watchdog: unknown option: $1" >&2
                return 2 ;;
            *) break ;;
        esac
    done
    local mode="${1:-status}"
    local retries
    case "$mode" in
        on)
            retries="$2"
            if [[ -n $retries ]]; then
                # A non-numeric value parses to NaN and is silently ignored,
                # leaving the 300 default -- so reject it here instead.
                case "$retries" in
                    *[!0-9]*)
                        echo "claude-watchdog: RETRIES must be a non-negative integer: $retries" >&2
                        return 2 ;;
                esac
                export CLAUDE_CODE_MAX_RETRIES="$retries"
            fi
            export CLAUDE_CODE_RETRY_WATCHDOG=1
            # Skip the report rather than passing -q down to it: quiet status
            # returns 1 when off, and `claude-watchdog -q off' handing that back
            # would read as a failed toggle.
            [[ -n $quiet ]] || claude-watchdog status
            ;;
        off)
            unset CLAUDE_CODE_RETRY_WATCHDOG CLAUDE_CODE_MAX_RETRIES
            [[ -n $quiet ]] || claude-watchdog status
            ;;
        status)
            # Read as a boolean on the other side, so 0 and false are off --
            # which `off' above reaches by unsetting, but a hand-set value
            # should still report honestly.
            case "${CLAUDE_CODE_RETRY_WATCHDOG:-}" in
                ''|0|false)
                    # Not quiet: the && falls through, and the echo below resets
                    # $? to 0.
                    [[ -n $quiet ]] && return 1
                    echo "claude-watchdog: off, max retries ${CLAUDE_CODE_MAX_RETRIES:-10}" ;;
                *)
                    [[ -n $quiet ]] || echo "claude-watchdog: on, max retries ${CLAUDE_CODE_MAX_RETRIES:-300} -- no fallbackModel on 5xx" ;;
            esac
            ;;
        *)
            echo "claude-watchdog: usage: claude-watchdog [-q] [on [RETRIES]|off|status]" >&2
            return 2 ;;
    esac
}

# One claude run with the watchdog on, leaving the shell alone. Prefer this to
# the toggle: an export outlives the run, and is inherited by every claude --
# and every MCP server -- started from the shell afterwards.
function claude-wd {
    CLAUDE_CODE_RETRY_WATCHDOG=1 command claude "$@"
}


###
## Mirrors pre-omz-init.zsh, which does this for zsh before oh-my-zsh; see the
## note there on why $DIR/bin is listed first and so ranks lowest.

add-to-path $DIR/bin
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


### cmux
##
## The remote CLI that talks back to the app (new-workspace, list-panes, ...).
## `cmux ssh' hands the remote a generated ZDOTDIR whose .zshrc is what puts
## this directory on PATH; `cmux ssh-tmux' gives the connection to tmux
## instead, so no such shell ever runs and the panes are left without the
## command. The directory is the same either way, and the wrapper in it reads
## the live relay address from ~/.cmux/socket_addr on every call, so PATH is
## the whole of what is missing -- reconnecting on a new port needs nothing
## re-sourced.
##
## Only PATH, though: the app's per-terminal CMUX_WORKSPACE_ID / CMUX_PANEL_ID
## do not reach a tmux pane either, so commands that mean "here" resolve to
## whatever the app has focused instead of to the calling pane.

add-to-path ~/.cmux/bin



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
alias dusls='du -s * .??* | sort -nr'

alias l='zless -i'

alias st=sshtsf

alias cddf='cd ~/dot-files'
alias cdhe='cd ~/hjlee-emacs-init'

# 

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
