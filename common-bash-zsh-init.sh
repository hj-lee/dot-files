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
