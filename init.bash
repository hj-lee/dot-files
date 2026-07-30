# -*- Shell-script -*-
#
# No longer actively maintained: zsh is the shell in daily use, so new
# setup goes in init.zsh. This is kept working for the occasional bash
# login, but it lags behind -- e.g. mise is activated only in init.zsh,
# so anything mise provides (fzf included) is absent here.
# Shared, shell-agnostic setup belongs in common-bash-zsh-init.sh.

function lpath {
    echo "${PATH//:/$'\n'}"
}

function remove-path {
    PATH=$(lpath | grep -v "^$1\$" | paste -s -d ":" -)
}

##
## fzf shell integration (completion + key bindings)
##
## Skipped on dumb terminals (Emacs TRAMP): the key bindings install
## readline widgets that corrupt the session. Only runs when fzf is
## actually installed, so the same file stays usable on hosts without it.

if [[ $- == *i* && "$TERM" != "dumb" && -z "$INSIDE_EMACS" ]] && type fzf > /dev/null 2>&1; then
    if fzf --bash > /dev/null 2>&1; then
        # fzf >= 0.48
        eval "$(fzf --bash)"
    elif [[ -f ~/.fzf.bash ]]; then
        # git/install-script layout
        source ~/.fzf.bash
    fi
fi
