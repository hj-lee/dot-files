#!/usr/bin/env zsh
####
# Clone the oh-my-zsh plugins that do not ship with oh-my-zsh itself.
#
# Run it, or source it; either works. Called by setup-zsh.zsh, which keeps no
# plugin list of its own -- this file is the one place the clones are named.
#
# The plugin NAMES must stay in step with the plugins=(...) array in
# dot-zshrc.zsh: a clone with no entry there is dead weight, and an entry with
# no clone makes oh-my-zsh warn on every shell start.
#
#   omz-plugins-install.zsh [-u|--update]
#   omz-plugins-install.zsh --list          just print the plugin names
#
# Without -u an already-cloned plugin is left alone, so a re-run makes no
# network calls at all. -u fast-forwards each one.
#
# --list is how setup-zsh.zsh learns the names without keeping a copy of this
# list: it needs them to report which plugins it actually cloned.

# $ZSH_CUSTOM is set by oh-my-zsh.sh, so it is empty when this file runs
# outside a shell that loaded oh-my-zsh -- which, executed as a script, is
# always. Defaulting it here is what lets this be a script rather than
# something that has to be sourced from a live interactive shell.
: ${ZSH_CUSTOM:=${ZSH:-$HOME/.oh-my-zsh}/custom}

typeset -a OMZ_PLUGIN_REPOS=(
    https://github.com/zsh-users/zsh-syntax-highlighting.git
    https://github.com/zsh-users/zsh-autosuggestions.git
)

function omz-plugins-install {
    local update=0 list=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -u|--update) update=1; shift ;;
            -l|--list)   list=1;   shift ;;
            -h|--help)
                echo "Usage: omz-plugins-install.zsh [-u|--update|-l|--list]"
                return 0 ;;
            *)
                echo "omz-plugins-install: unknown option: $1" >&2
                return 2 ;;
        esac
    done

    local repo
    if (( list )); then
        for repo in "${OMZ_PLUGIN_REPOS[@]}"; do
            print -r -- "${${repo:t}%.git}"
        done
        return 0
    fi

    local dest="$ZSH_CUSTOM/plugins"
    if ! mkdir -p "$dest" 2>/dev/null; then
        echo "omz-plugins-install: cannot create $dest" >&2
        echo "                     is oh-my-zsh installed? (see setup-zsh.zsh)" >&2
        return 1
    fi

    # Report every plugin's outcome and only fail on a clone that did not
    # happen: one unreachable repo, or one hand-made directory, should not stop
    # the others from being installed.
    local failed=0 name dir
    for repo in "${OMZ_PLUGIN_REPOS[@]}"; do
        name="${${repo:t}%.git}"
        dir="$dest/$name"

        if [[ ! -e $dir ]]; then
            echo "$name: cloning"
            git clone --depth=1 "$repo" "$dir" || failed=1
        elif [[ ! -d $dir/.git ]]; then
            echo "$name: present but not a git checkout; leaving it alone" >&2
            failed=1
        elif (( update )); then
            echo "$name: updating"
            # --ff-only: refuse rather than merge if the checkout has local
            # commits, so a hand-patched plugin is never quietly rewritten.
            git -C "$dir" pull --ff-only || failed=1
        else
            echo "$name: present"
        fi
    done

    return $failed
}

# Only run when executed. Sourced, this leaves the function defined so it can
# be called by hand -- $ZSH_CUSTOM is real in that case.
#
# zsh_eval_context, not a $0 test: with FUNCTION_ARGZERO on (the default) $0 is
# the file's own name whether it was run or sourced, so comparing it to %N
# cannot tell the two apart. The context stack gains a `file' entry per source.
if [[ ${zsh_eval_context[-1]} != file ]]; then
    omz-plugins-install "$@"
fi
