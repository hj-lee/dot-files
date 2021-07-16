
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
