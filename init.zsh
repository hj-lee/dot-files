
alias lpath='echo "${PATH//:/\n}"'

unsetopt AUTO_CD

# . /etc/zsh_command_not_found

# global aliases

alias -g G='| grep'
alias -g Gi='| grep -i'

alias -g L='| less'

# PROMPT="%{%f%b%k%}$(build_prompt) " 
# PROMPT=$'%D %*\n%{%f%b%k%}$(build_prompt) '
# PROMPT=$'%F{cyan}%D %*\n%{%f%b%k%}$(build_prompt) '
RPROMPT='%F{green}%D %*'

##
## Mac OS X
##

if [[ "$OSTYPE" == "darwin"* ]]; then
    source $DIR/darwin-zsh-init.zsh
fi

##
## Emacs tramp
if [[ "$TERM" == "dumb" ]]; then
    unsetopt zle
    unsetopt prompt_cr
    unsetopt prompt_subst
    unfunction precmd
    unfunction preexec
    PS1='$ '
fi

##
## local-zsh-init.zsh
##

local_init=$DIR/local-zsh-init.zsh

if [[ -e $local_init ]]; then
   source $local_init
fi
