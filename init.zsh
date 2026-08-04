
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

if [[ -n "$CONTAINER_ID" ]]; then
    PROMPT='%{%f%b%k%}%S[$CONTAINER_ID]%s$(build_prompt) '
fi

##
## Mac OS X
##

if [[ "$OSTYPE" == "darwin"* ]]; then
    source $DIR/darwin-zsh-init.zsh
fi


##
## mise

if type mise > /dev/null; then
    # brew mise
    eval "$(mise activate zsh)"
elif [[ -f ~/.local/bin/mise ]]; then
    # self install mise
    eval "$(~/.local/bin/mise activate zsh)"
fi

 ##
 ## Emacs tramp / dumb-terminal guard.
 ## Must strip precmd_functions/preexec_functions arrays -- Kiro CLI (sourced from
 ## .zprofile, i.e. BEFORE this file) registers fig_precmd/fig_preexec there and they
 ## emit OSC 697 escapes that TRAMP's prompt matcher can never match.
if [[ "$TERM" == "dumb" || -n "$INSIDE_EMACS" ]]; then
    unsetopt zle 2>/dev/null
    unsetopt prompt_cr 2>/dev/null
    unsetopt prompt_subst 2>/dev/null

    precmd_functions=()
    preexec_functions=()
    unfunction precmd 2>/dev/null
    unfunction preexec 2>/dev/null

    unset RPS1 RPROMPT
    PS1='$ '
    PROMPT='$ '

    # Disable line-editor plugins that corrupt the stream.
    unset ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE
    return
fi

##
## local-zsh-init.zsh
##

local_init=$DIR/local-zsh-init.zsh

if [[ -e $local_init ]]; then
   source $local_init
fi
