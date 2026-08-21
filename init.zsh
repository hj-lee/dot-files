
alias lpath='echo "${PATH//:/\n}"'

function remove-path {
    PATH=$(lpath | grep -v "^$1\$" | paste -s -d ":" -)
}


unsetopt AUTO_CD

# . /etc/zsh_command_not_found

# global aliases

alias -g G='| grep'
alias -g Gi='| grep -i'

alias -g L='| less'
alias -g W='| wc'

# PROMPT="%{%f%b%k%}$(build_prompt) " 
# PROMPT=$'%D %*\n%{%f%b%k%}$(build_prompt) '
# PROMPT=$'%F{cyan}%D %*\n%{%f%b%k%}$(build_prompt) '
RPROMPT='%F{green}%D %*'

## agnoster's prompt_context prints %n@%m, and on a dev desktop %m is a
## 26-character dev-dsk-<user>-<az>-<id>. Substitute $PROMPT_HOST for the host
## part when a host sets one (local-zsh-init.zsh), %m otherwise -- the condition
## and colours are the theme's, so a machine with no $PROMPT_HOST keeps the stock
## prompt exactly. Read at prompt time, not here, because local-zsh-init.zsh is
## sourced at the end of this file.
prompt_context() {
    if [[ "$USERNAME" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]; then
        prompt_segment "$AGNOSTER_CONTEXT_BG" "$AGNOSTER_CONTEXT_FG" \
            "%(!.%{%F{$AGNOSTER_STATUS_ROOT_FG}%}.)%n@${PROMPT_HOST:-%m}"
    fi
}

if [[ -n "$CONTAINER_ID" ]]; then
    PROMPT='%{%f%b%k%}%S[$CONTAINER_ID]%s$(build_prompt) '
fi

##
## Mac OS X
##

if [[ "$OSTYPE" == "darwin"* ]]; then
    source $DIR/darwin-zsh-init.zsh
fi


## mise and the PATH basics are set from dot-zshrc.zsh, before oh-my-zsh --
## see pre-omz-init.zsh. The dumb-terminal guard lives there too, and returns
## before oh-my-zsh loads, so nothing below here runs in such a shell.

##
## ssht / sshts
##
## zsh-only, so it lives here rather than in common-bash-zsh-init.sh.

source $DIR/ssh-tmux.zsh

##
## local-zsh-init.zsh
##

local_init=$DIR/local-zsh-init.zsh

if [[ -e $local_init ]]; then
   source $local_init
fi
