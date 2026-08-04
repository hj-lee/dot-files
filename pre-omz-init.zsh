####
# Setup that must run BEFORE oh-my-zsh.
#
# Two reasons something belongs here rather than in init.zsh:
#
# 1. oh-my-zsh plugins probe for commands at load time and silently do nothing
#    when they are missing -- fzf.plugin.zsh opens with
#
#        (( ${+commands[fzf]} )) || return 1
#
#    and fzf is a mise-managed tool here. Activating mise afterwards left the
#    plugin dead on any host whose ambient PATH lacked mise's dirs: it happened
#    to work on the Mac, which already had them, and failed on the cloud
#    desktop.
#
# 2. A dumb terminal / Emacs subshell returns from dot-zshrc.zsh before
#    oh-my-zsh loads, so anything such a shell needs -- PATH above all -- has
#    to be in place by the time we get there.
#
# Keep this file to PATH and environment only: it runs before oh-my-zsh sets up
# the line editor, so no ZLE widgets, no prompt, no precmd hooks. Aliases and
# functions belong in common-bash-zsh-init.sh, which is deliberately sourced
# *after* oh-my-zsh so its ll/la/l override oh-my-zsh's versions.

##
## PATH helpers
##
## Defined here, not in common-bash-zsh-init.sh, because the PATH settings
## below need them and that file is sourced later. It redefines both
## identically, which is harmless.

function add-to-path {
  if [[ ! ( $PATH == "$1":* || $PATH == *:"$1":* || $PATH == *:"$1" ) && -d "$1" ]]; then
    export PATH="$1":${PATH}
  fi
}

function add-to-path-end {
  if [[ ! ( $PATH == "$1":* || $PATH == *:"$1":* || $PATH == *:"$1" ) && -d "$1" ]]; then
    export PATH=${PATH}:"$1"
  fi
}

##
## mise

if type mise > /dev/null 2>&1; then
    # brew mise
    eval "$(mise activate zsh)"
elif [[ -f ~/.local/bin/mise ]]; then
    # self install mise -- absolute path, as ~/.local/bin may not be on PATH yet
    eval "$(~/.local/bin/mise activate zsh)"
fi

##
## PATH
##
## Also set in common-bash-zsh-init.sh for bash's benefit; add-to-path is
## idempotent, so doing it twice costs nothing.

add-to-path ~/bin
add-to-path ~/usr/bin

##
## pre-omz-local-init.zsh
##
## Per-host PATH/env that must also precede oh-my-zsh. Gitignored, like
## local-zsh-init.zsh.

pre_omz_local_init=$DIR/pre-omz-local-init.zsh

if [[ -r $pre_omz_local_init ]]; then
    source $pre_omz_local_init
fi
unset pre_omz_local_init
