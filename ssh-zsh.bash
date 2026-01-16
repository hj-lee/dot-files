
# for immutable linux
# using chsh is not practical

if [ -n "$SSH_CLIENT" ] && type zsh >/dev/null 2>&1 && shopt -q login_shell; then
    zsh
    exit
fi
