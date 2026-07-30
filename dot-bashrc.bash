# -*- Shell-script -*-
#
# Entry point for bash (source this from ~/.bashrc; see minimal.bashrc).
#
# No longer actively maintained: zsh is the shell in daily use, so new
# setup goes in dot-zshrc.zsh / init.zsh. This is kept working for the
# occasional bash login, but it lags behind.
# Shared, shell-agnostic setup belongs in common-bash-zsh-init.sh.

DIR=$(dirname "${BASH_SOURCE[0]}")

source $DIR/common-bash-zsh-init.sh
source $DIR/init.bash
