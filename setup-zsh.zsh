#!/usr/bin/env zsh
####
# Wire this repo into a host's zsh: install oh-my-zsh if it is missing, clone
# the custom plugins, point ~/.zshrc at dot-zshrc.zsh, and link
# ~/.claude/CLAUDE.md and (on macOS) ~/.config/cmux/cmux.json to the copies here.
#
#   setup-zsh.zsh [-n|--dry-run] [-u|--update] [-h|--help]
#
# Safe to re-run: every step is guarded, so a second run reports what it found
# and changes nothing. Nothing is ever deleted: the only file this rewrites is
# ~/.zshrc, and the previous version is always kept as ~/.zshrc.bak-<n>.
#
# `command cp' / `command mv', because common-bash-zsh-init.sh aliases both to
# their -i forms -- which would sit waiting for an answer if this file were ever
# sourced from an interactive shell rather than run.
#
# What it deliberately does NOT do: install packages. The optional tools are
# reported, not fetched, so this script has no opinion about the host's package
# manager. See the prerequisites table in README.md.

emulate -L zsh
setopt no_unset warn_create_global

# ${0:A:h} -- absolute, symlinks resolved, so the path written into ~/.zshrc is
# right even when this was run as ./setup-zsh.zsh or through a symlink.
typeset -g REPO=${0:A:h}
typeset -g DRY_RUN=0 UPDATE=0
typeset -g -a CHANGED=() SKIPPED=()

# Derived from $HOME, deliberately ignoring any inherited $ZSH / $ZSH_CUSTOM:
# run from an already-configured shell, those name the LAUNCHING user's
# oh-my-zsh, and every step below would then act on that instead of on the
# $HOME being set up. dot-zshrc.zsh:8 defines $ZSH the same way, so nothing is
# lost by not honouring it here.
typeset -g OMZ=$HOME/.oh-my-zsh
typeset -g ZSH_CUSTOM=$OMZ/custom

function usage {
    cat <<'EOF'
Usage: setup-zsh.zsh [-n|--dry-run] [-u|--update] [-h|--help]

  -n, --dry-run  print what would happen; change nothing
  -u, --update   also fast-forward already-cloned oh-my-zsh plugins
EOF
}

function say   { print -r -- "$*" }
function note  { print -r -- "  $*" }
function warn  { print -r -- "  ! $*" >&2 }
function field { printf '  %-12s %s\n' "$1:" "$2" }

# The plugin installer, given the environment it needs explicitly rather than
# whatever the launching shell exported.
function omz-plugins {
    ZSH=$OMZ ZSH_CUSTOM=$ZSH_CUSTOM "$REPO/omz-plugins-install.zsh" "$@"
}

# Every write goes through here, so --dry-run needs no second code path.
function run {
    if (( DRY_RUN )); then
        note "would run: $*"
        return 0
    fi
    "$@"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run) DRY_RUN=1; shift ;;
        -u|--update)  UPDATE=1;  shift ;;
        -h|--help)    usage; exit 0 ;;
        *)
            print -r -- "setup-zsh: unknown option: $1" >&2
            usage >&2
            exit 2 ;;
    esac
done

(( DRY_RUN )) && say "dry run -- nothing will be changed" && say ""

##
## 1. preflight
##
## Required tools are fatal; everything else is a warning naming what stays
## broken without it, since each one only affects the feature that uses it.

say "== preflight"
field repo "$REPO"
field zsh "$ZSH_VERSION"

if (( ! $+commands[git] )); then
    warn "git not found -- required, both to install oh-my-zsh and to clone plugins"
    exit 1
fi

# mise first: it is the reason pre-omz-init.zsh exists. oh-my-zsh plugins probe
# for their command as they load, so a tool mise provides (fzf here) has to be
# on PATH before oh-my-zsh, and is absent entirely without mise.
if (( $+commands[mise] )) || [[ -x ~/.local/bin/mise ]]; then
    field mise found
else
    warn "mise not found -- the fzf/mise oh-my-zsh plugins will silently do nothing"
fi

# Reported as "python3 >= 3.11" rather than just "python3": sshtsf needs
# tomllib and says so itself, but only once you run it.
if (( $+commands[python3] )) && python3 -c 'import sys; sys.exit(sys.version_info < (3, 11))' 2>/dev/null; then
    field python3 "$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')"
else
    warn "no python3 >= 3.11 -- bin/sshtsf needs tomllib (mise use -g python@latest)"
fi

typeset -A OPTIONAL_TOOLS=(
    tmux        "ssht / sshts / sshtsf"
    emacsclient "ssh-ecf, emacs-remote, magit, \$EDITOR"
    pass        "the oh-my-zsh pass plugin"
    waypipe     "sshtsf -w (Wayland forwarding)"
)
typeset -g tool=
for tool in ${(ko)OPTIONAL_TOOLS}; do
    if (( $+commands[$tool] )); then
        field "$tool" found
    else
        warn "$tool not found -- affects: $OPTIONAL_TOOLS[$tool]"
    fi
done

# Not detectable from a script: whether the terminal's font has the glyphs
# ZSH_THEME="agnoster" draws with.
field note "agnoster (the theme in dot-zshrc.zsh) needs a powerline/Nerd font"

##
## 2. oh-my-zsh
##
## Before the ~/.zshrc step, not after: the installer rewrites ~/.zshrc from
## its own template unless told otherwise, which would throw away a source line
## we had just added. Doing it first also means a failed install aborts before
## ~/.zshrc has been touched -- a shell whose rc sources dot-zshrc.zsh without
## oh-my-zsh present complains on every start.

say ""
say "== oh-my-zsh"

# Noted BEFORE the install, because KEEP_ZSHRC only makes the installer keep an
# ~/.zshrc that already exists; with none there it writes its template. So if
# the file is absent now and present later, the installer authored it, and step
# 4 replaces it rather than appending to it -- otherwise its `source
# $ZSH/oh-my-zsh.sh' plus ours in dot-zshrc.zsh would load oh-my-zsh twice.
typeset -g ZSHRC=$HOME/.zshrc
typeset -g ZSHRC_EXISTED=0
[[ -e $ZSHRC ]] && ZSHRC_EXISTED=1

if [[ -r $OMZ/oh-my-zsh.sh ]]; then
    # The sentinel file, not the directory: a first run that died midway leaves
    # the directory behind, and a directory test would call that installed for
    # ever after.
    note "already installed: $OMZ"
    SKIPPED+=("oh-my-zsh (already installed)")
elif [[ -e $OMZ ]]; then
    warn "$OMZ exists but has no oh-my-zsh.sh -- an interrupted install?"
    warn "remove it and re-run; not deleting it here"
    exit 1
else
    note "installing into $OMZ"
    # KEEP_ZSHRC=yes is the whole point: without it the installer moves the
    # existing ~/.zshrc aside and writes its template, discarding this host's
    # own lines. RUNZSH=no keeps it from exec'ing a shell and abandoning the
    # rest of this script; CHSH=no leaves the login shell alone.
    if ! run env RUNZSH=no KEEP_ZSHRC=yes CHSH=no ZSH=$OMZ \
         sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"; then
        warn "oh-my-zsh install failed"
        exit 1
    fi
    CHANGED+=("installed oh-my-zsh into $OMZ")
fi

##
## 3. custom plugins
##
## Executed, not sourced. Sourcing would give us its OMZ_PLUGIN_REPOS directly,
## but `source' prefers a sibling foo.zwc whenever that file is not older --
## which is how this step once silently ran a years-old compiled copy of the
## script. Running it as a program ignores .zwc entirely, and --list gets the
## names across, so the clone list still lives in exactly one file (the same one
## dot-zshrc.zsh's plugins=(...) array has to agree with).

say ""
say "== custom plugins"

typeset -g PLUGIN_DIR=$ZSH_CUSTOM/plugins

typeset -g -a plugin_args=()
(( UPDATE )) && plugin_args+=(--update)

typeset -g -a names=() missing=()
names=("${(@f)$(omz-plugins --list)}")
typeset -g name=
for name in "${names[@]}"; do
    [[ -e $PLUGIN_DIR/$name ]] || missing+=("$name")
done

if (( DRY_RUN )); then
    if (( ${#missing} )); then
        note "would clone: ${(j:, :)missing}"
    else
        note "all present: nothing to clone"
    fi
elif omz-plugins "${plugin_args[@]}"; then
    if (( ${#missing} )); then
        CHANGED+=("cloned: ${(j:, :)missing}")
    else
        SKIPPED+=("custom plugins (already present)")
    fi
else
    warn "one or more plugins could not be installed (see above)"
fi

##
## 4. ~/.zshrc
##

say ""
say "== ~/.zshrc"

# ~/dot-files/... rather than the absolute path when the repo sits in $HOME, so
# the line survives being copied to a host with a different login name -- the
# ~user/ form does not.
#
# Compared against ${HOME:A}, since $REPO is already resolved: with a symlinked
# home (/home/x -> /export/home/x, or macOS /tmp -> /private/tmp) the raw $HOME
# never prefixes it, and every such host would silently get an absolute path.
typeset -g SOURCE_PATH=$REPO
[[ $REPO == ${HOME:A}/* ]] && SOURCE_PATH="~${REPO#${HOME:A}}"
typeset -g SOURCE_LINE="source $SOURCE_PATH/dot-zshrc.zsh"
typeset -g backup=

# Matches ~/, ~user/, $HOME/ and absolute forms alike -- the filename is what
# identifies the line. Comments are skipped on purpose: someone who commented
# the line out must not be told it is still wired up.
function zshrc-is-wired {
    grep -Eq '^[[:space:]]*(\.|source)[[:space:]].*dot-zshrc\.zsh' "$ZSHRC"
}

# The whole of the file we write from scratch: dot-zshrc.zsh is the config, and
# anything host-specific belongs in the gitignored local files it sources, not
# here. Same content as minimal.zshrc, but with the repo's real path -- that
# file hardcodes ~/dot-files, which is only right when the repo lives there.
function write-minimal-zshrc {
    if (( DRY_RUN )); then
        note "would write: $SOURCE_LINE"
    else
        print -r -- "$SOURCE_LINE" > "$ZSHRC"
    fi
}

# Numbered rather than timestamped, so the sequence reads in order and a run
# that changes nothing adds nothing.
function next-backup {
    local target=$1 n=1
    while [[ -e $target.bak-$n ]]; do (( n++ )); done
    print -r -- "$target.bak-$n"
}

if [[ ! -e $ZSHRC ]]; then
    note "no ~/.zshrc -- creating one"
    write-minimal-zshrc
    CHANGED+=("created ~/.zshrc sourcing $SOURCE_PATH/dot-zshrc.zsh")
elif (( ! ZSHRC_EXISTED )); then
    # Absent before step 2, present now: this is oh-my-zsh's template. Replace
    # it rather than appending -- it sources $ZSH/oh-my-zsh.sh with a theme and
    # plugin list of its own, and dot-zshrc.zsh does that properly a second
    # time. Kept as a backup, since it is the reference for what omz supports.
    backup=$(next-backup "$ZSHRC")
    note "oh-my-zsh wrote its template -- replacing it (kept as $backup)"
    run command mv "$ZSHRC" "$backup" || exit 1
    write-minimal-zshrc
    CHANGED+=("created ~/.zshrc sourcing $SOURCE_PATH/dot-zshrc.zsh (omz template kept as $backup)")
elif zshrc-is-wired; then
    note "already sources dot-zshrc.zsh -- leaving it alone"
    note "$(grep -En '^[[:space:]]*(\.|source)[[:space:]].*dot-zshrc\.zsh' "$ZSHRC")"
    # No backup on this path: taking one before the check would drop a fresh
    # ~/.zshrc.bak-<n> on every re-run.
    SKIPPED+=("~/.zshrc (already wired)")
else
    backup=$(next-backup "$ZSHRC")
    note "backing up to $backup"
    run command cp -p "$ZSHRC" "$backup" || exit 1

    note "appending: $SOURCE_LINE"
    if (( DRY_RUN )); then
        note "would append the line above to $ZSHRC"
    else
        print -r -- "" >> "$ZSHRC"
        print -r -- "# dot-files (setup-zsh.zsh)" >> "$ZSHRC"
        print -r -- "$SOURCE_LINE" >> "$ZSHRC"
    fi
    CHANGED+=("appended the source line to ~/.zshrc (backup: $backup)")
fi

##
## 5. ~/.claude/CLAUDE.md
##
## A symlink rather than a copy, so editing either path edits the tracked file
## and there is no second version to drift.
##
## The tracked file ends with `@~/.claude/CLAUDE.local.md', a path this script
## deliberately leaves alone: that is where work-specific guidance goes, and on
## a given host it is usually itself a symlink into some other checkout. Claude
## Code skips an import it cannot resolve, so a host without one is fine.

say ""
say "== ~/.claude/CLAUDE.md"

typeset -g CLAUDE_SRC=$REPO/claude/CLAUDE.md
typeset -g CLAUDE_LINK=$HOME/.claude/CLAUDE.md

if [[ ! -r $CLAUDE_SRC ]]; then
    note "no claude/CLAUDE.md in the repo -- nothing to link"
    SKIPPED+=("~/.claude/CLAUDE.md (nothing to link)")
elif [[ -L $CLAUDE_LINK && ${CLAUDE_LINK:A} == ${CLAUDE_SRC:A} ]]; then
    note "already linked to ${CLAUDE_SRC/#$HOME/~}"
    SKIPPED+=("~/.claude/CLAUDE.md (already linked)")
elif [[ -L $CLAUDE_LINK ]]; then
    # Someone pointed this somewhere on purpose; say where and leave it. The
    # regular-file case below is different -- that is just a file, and keeping a
    # copy of it loses nothing.
    warn "$CLAUDE_LINK already links to ${CLAUDE_LINK:A}"
    warn "remove it and re-run to link this repo's copy instead"
    SKIPPED+=("~/.claude/CLAUDE.md (links elsewhere)")
else
    run mkdir -p "${CLAUDE_LINK:h}" || exit 1
    if [[ -e $CLAUDE_LINK ]]; then
        backup=$(next-backup "$CLAUDE_LINK")
        note "backing up the existing file to $backup"
        run command mv "$CLAUDE_LINK" "$backup" || exit 1
        CHANGED+=("linked ~/.claude/CLAUDE.md (previous file kept as $backup)")
    else
        CHANGED+=("linked ~/.claude/CLAUDE.md -> ${CLAUDE_SRC/#$HOME/~}")
    fi
    note "linking to $CLAUDE_SRC"
    run command ln -s "$CLAUDE_SRC" "$CLAUDE_LINK" || exit 1
fi

##
## 6. ~/.config/cmux/cmux.json
##
## Same shape as step 5, and macOS-only: cmux ships as a Mac app, so on any other
## host there is nothing to point at.
##
## The file this replaces is cmux's own all-commented template, which the app
## rewrites whenever the path is missing -- so the backup below is a courtesy,
## not the only copy. Settings absent from the tracked file keep whatever value
## the app has saved; `cmux reload-config' picks up an edit without a restart.

say ""
say "== ~/.config/cmux/cmux.json"

typeset -g CMUX_SRC=$REPO/cmux/cmux.json
typeset -g CMUX_LINK=$HOME/.config/cmux/cmux.json

if [[ $OSTYPE != darwin* ]]; then
    note "not macOS -- cmux does not run here"
    SKIPPED+=("~/.config/cmux/cmux.json (not macOS)")
elif [[ ! -r $CMUX_SRC ]]; then
    note "no cmux/cmux.json in the repo -- nothing to link"
    SKIPPED+=("~/.config/cmux/cmux.json (nothing to link)")
elif [[ -L $CMUX_LINK && ${CMUX_LINK:A} == ${CMUX_SRC:A} ]]; then
    note "already linked to ${CMUX_SRC/#$HOME/~}"
    SKIPPED+=("~/.config/cmux/cmux.json (already linked)")
elif [[ -L $CMUX_LINK ]]; then
    warn "$CMUX_LINK already links to ${CMUX_LINK:A}"
    warn "remove it and re-run to link this repo's copy instead"
    SKIPPED+=("~/.config/cmux/cmux.json (links elsewhere)")
else
    run mkdir -p "${CMUX_LINK:h}" || exit 1
    if [[ -e $CMUX_LINK ]]; then
        backup=$(next-backup "$CMUX_LINK")
        note "backing up the existing file to $backup"
        run command mv "$CMUX_LINK" "$backup" || exit 1
        CHANGED+=("linked ~/.config/cmux/cmux.json (previous file kept as $backup)")
    else
        CHANGED+=("linked ~/.config/cmux/cmux.json -> ${CMUX_SRC/#$HOME/~}")
    fi
    note "linking to $CMUX_SRC"
    run command ln -s "$CMUX_SRC" "$CMUX_LINK" || exit 1
fi

##
## 7. summary
##

say ""
say "== summary"

typeset -g item=
if (( ${#CHANGED} )); then
    for item in "${CHANGED[@]}"; do note "changed: $item"; done
else
    note "nothing to change"
fi
for item in "${SKIPPED[@]}"; do note "skipped: $item"; done

say ""
if (( DRY_RUN )); then
    note "dry run -- re-run without -n to apply"
else
    note "next: exec zsh"
fi
note "host-specific PATH/env belongs in the gitignored pre-omz-local-init.zsh,"
note "local-zsh-init.zsh or local-common-init.sh -- see README.md"
