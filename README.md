# dot-files

Shell configuration for zsh, plus the ssh/tmux/Emacs plumbing that goes with it. zsh is the shell in
daily use; the bash entry points still work but lag behind (see the note at the top of
`dot-bashrc.bash`).

`~/.zshrc` is expected to be nearly empty — one line sourcing `dot-zshrc.zsh` from this repo, as in
`minimal.zshrc`. Anything that is true of one host only goes in a gitignored local file, not in a
tracked one; see [Host-specific overrides](#host-specific-overrides).

## Quick start

```sh
git clone <this repo> ~/dot-files
~/dot-files/setup-zsh.zsh
exec zsh
```

`setup-zsh.zsh` installs oh-my-zsh if it is missing, clones the two custom plugins, wires `~/.zshrc`,
and symlinks `~/.claude/CLAUDE.md` — and, on macOS, `~/.config/cmux/cmux.json` — to the copies here.
It is safe to re-run: every step is guarded, so
a second run reports what it found and changes nothing — no repeated backups, and no git calls once
everything is in place.

```
setup-zsh.zsh [-n|--dry-run] [-u|--update] [-h|--help]

  -n, --dry-run  print what would happen; change nothing
  -u, --update   also fast-forward already-cloned oh-my-zsh plugins
```

It reports missing optional tools but never installs anything beyond oh-my-zsh and the plugins, so
it has no opinion about the host's package manager. Install what you want from
[Prerequisites](#prerequisites) yourself.

### By hand

```sh
# 1. oh-my-zsh. KEEP_ZSHRC=yes is essential once ~/.zshrc exists: without it the
#    installer moves your file aside and writes its own template.
RUNZSH=no KEEP_ZSHRC=yes CHSH=no \
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# 2. The plugins that do not ship with oh-my-zsh.
~/dot-files/omz-plugins-install.zsh

# 3. Point ~/.zshrc at this repo (this is all minimal.zshrc contains).
echo 'source ~/dot-files/dot-zshrc.zsh' >> ~/.zshrc

# 4. Claude Code's user-scope instructions.
ln -s ~/dot-files/claude/CLAUDE.md ~/.claude/CLAUDE.md

# 5. macOS only: cmux settings. The file already there is cmux's commented
#    template, which the app rewrites whenever the path is missing.
mv ~/.config/cmux/cmux.json ~/.config/cmux/cmux.json.bak-1
ln -s ~/dot-files/cmux/cmux.json ~/.config/cmux/cmux.json
cmux reload-config
```

On a host with no `~/.zshrc` at all, oh-my-zsh's installer writes its template — which sources
`$ZSH/oh-my-zsh.sh` with a theme and plugin list of its own, and `dot-zshrc.zsh` then does that
again. Replace the template rather than appending to it. `setup-zsh.zsh` handles this, keeping the
template as `~/.zshrc.bak-1`.

## Prerequisites

Required:

| Tool | Why |
|---|---|
| `zsh` | 5.x; the config uses `typeset -U path`, `${(%):-%N}`, glob qualifiers |
| `git` | to install oh-my-zsh and clone plugins |
| oh-my-zsh | `dot-zshrc.zsh` sources `$ZSH/oh-my-zsh.sh` unconditionally |

Optional, each affecting only what it names:

| Tool | Missing means |
|---|---|
| a powerline/Nerd font | `ZSH_THEME="agnoster"` draws boxes instead of glyphs |
| [mise](https://mise.jdx.dev) | no `fzf` (it is mise-managed here), so the `fzf` and `mise` oh-my-zsh plugins silently do nothing |
| `tmux` | no `ssht` / `sshts` / `sshtsf` / `tssh-ecf` |
| `emacs`, `emacsclient` | no `ssh-ecf`, `emacs-remote`, `magit`; `$EDITOR` is set to `emacsclient` regardless |
| python 3.11+ | `bin/sshtsf` needs `tomllib` (`mise use -g python@latest`) |
| `pass` | the `pass` oh-my-zsh plugin does nothing |
| `waypipe` | no `sshtsf -w` (Wayland forwarding) |

An oh-my-zsh plugin whose command is absent disables itself quietly, so a thin host is not an error
— it just has fewer features.

## Load order

Position matters at every step here; the reason is given inline in each file.

```
~/.zshrc                    host-specific lines, then one source line
└── dot-zshrc.zsh           $ZSH, theme, plugins=(...)
    ├── pre-omz-init.zsh    mise + PATH, BEFORE oh-my-zsh
    │                       ── dumb terminal / Emacs TRAMP returns here ──
    │   └── pre-omz-local-init.zsh      (gitignored)
    ├── $ZSH/oh-my-zsh.sh   theme, plugins, ZLE widgets, precmd hooks
    ├── common-bash-zsh-init.sh         shared with bash: aliases, ssh-ecf, magit
    │   └── local-common-init.sh        (gitignored)
    └── init.zsh            zsh-only: prompt, global aliases
        ├── darwin-zsh-init.zsh         macOS only
        ├── ssh-tmux.zsh                ssht / sshts / tssh-ecf
        └── local-zsh-init.zsh          (gitignored)
```

- **mise before oh-my-zsh.** Plugins probe for their command as they load — `fzf.plugin.zsh` opens
  with `(( ${+commands[fzf]} )) || return 1` — so a mise-managed tool has to be on `PATH` by then, or
  the plugin is dead for the life of the shell.
- **The dumb-terminal guard returns before oh-my-zsh.** Under `TERM=dumb` or `$INSIDE_EMACS`,
  `dot-zshrc.zsh` sets a bare `PS1` and returns, rather than loading oh-my-zsh and undoing it: TRAMP
  cannot match a prompt built from theme escapes. `~/.zshrc` continues past the `source`, so its own
  lines still run.
- **`common-bash-zsh-init.sh` after oh-my-zsh.** Deliberate, so its `ll`/`la`/`l` win over
  oh-my-zsh's. The cost is that it must not need anything oh-my-zsh sets up later.
- **Functions and aliases never go in `pre-omz-init.zsh`.** It runs before the line editor exists.

## File map

Entry points:

| File | |
|---|---|
| `dot-zshrc.zsh` | the zsh entry point: theme, plugin list, and the load order above |
| `dot-bashrc.bash` | the bash entry point; unmaintained, kept working |
| `minimal.zshrc`, `minimal.bashrc` | the one-line `~/.zshrc` / `~/.bashrc` this repo expects |
| `setup-zsh.zsh` | bootstrap: oh-my-zsh, plugins, `~/.zshrc`, `~/.claude/CLAUDE.md`, `~/.config/cmux/cmux.json` |
| `omz-plugins-install.zsh` | clones the plugins oh-my-zsh does not ship; `--list`, `-u` |
| `claude/CLAUDE.md` | Claude Code user-scope instructions, symlinked to `~/.claude/CLAUDE.md` |
| `cmux/cmux.json` | cmux settings, symlinked to `~/.config/cmux/cmux.json` (macOS) |

Sourced in turn:

| File | |
|---|---|
| `pre-omz-init.zsh` | mise, `PATH`, and the `add-to-path` helpers — everything that must precede oh-my-zsh |
| `common-bash-zsh-init.sh` | shared with bash: aliases, `ssh-ecf`, `emacs-remote`, `magit`, `with-picker`, `tmux-env-refresh` |
| `init.zsh` | zsh-only: prompt, global aliases, `remove-path` |
| `init.bash` | the bash counterpart, including its own fzf integration |
| `darwin-zsh-init.zsh` | macOS: Emacs.app, Android SDK, `~/.local/bin` |
| `ssh-tmux.zsh` | `ssht`, `sshts`, `tssh-ecf` (zsh-only syntax, hence not in the shared file) |

`bin/`, which `pre-omz-init.zsh` puts on `PATH` — ranked *below* `~/bin`, so an untracked script
there can shadow a committed one:

| File | |
|---|---|
| `bin/sshtsf` | config-driven front-end for `sshts`; python 3.11+ |
| `bin/emacsclient-auto.sh` | routes `emacsclient` to a forwarded Emacs when its socket is live |
| `bin/ec-browse` | opens URLs in the browser of whichever Emacs `emacsclient` reaches; usable as `$BROWSER` |

Odd corners:

| File | |
|---|---|
| `ssh-zsh.bash` | re-exec zsh on a login where `chsh` is not available (immutable Linux) |
| `ln4git-bash.sh` | git-bash only: makes `ln -s` a `mklink /J` junction |
| `caps-lock2ctrl.ahk` | Windows AutoHotkey: Caps Lock as Control |

## Host-specific overrides

Three gitignored files, each sourced if it exists. Pick by *when* the content has to run and *which
shell* needs it:

| File | Sourced from | Use for |
|---|---|---|
| `pre-omz-local-init.zsh` | `pre-omz-init.zsh`, before oh-my-zsh | per-host `PATH`/env that plugins or a dumb-terminal shell depend on |
| `local-zsh-init.zsh` | `init.zsh`, after oh-my-zsh | zsh-only: prompt, widgets, functions |
| `local-common-init.sh` | `common-bash-zsh-init.sh` | anything bash must see too |

`DEFAULT_USER`, a Homebrew `shellenv`, and a build system's shell completion are all examples of what
belongs in one of these rather than in a tracked file. `setup-zsh.zsh` does not create them; add one
when you need it.

## Claude Code

`claude/CLAUDE.md` holds the user-scope instructions, and `setup-zsh.zsh` symlinks it to
`~/.claude/CLAUDE.md` — a link, not a copy, so editing either path edits the tracked file.

Its last line imports `~/.claude/CLAUDE.local.md`, which this repo does not track and setup does not
create. That is where work-specific guidance goes — build system, code-review tooling, anything tied
to one employer or machine — usually as a symlink to a file in some other checkout:

```sh
ln -s /path/to/some/other/repo/CLAUDE.local.md ~/.claude/CLAUDE.local.md
```

Two reasons for the indirection rather than importing the other checkout directly: the path is
host-specific, and this repo is public, so even the name of the other repo stays out of it. Claude
Code resolves `@` imports up to four hops and skips one it cannot find, so a host without the local
file loads the tracked half on its own.

## cmux

`cmux/cmux.json` is symlinked to `~/.config/cmux/cmux.json`, and holds only the settings worth
carrying between hosts — currently `app.globalFontMagnification`, the one knob that scales terminals,
tab titles, sidebar, and chrome together. It is a percentage rather than a point size: 50–200 in
steps of 10, where 100 is the design size. Any key left out of the file falls back to whatever the
app's Settings has saved, so there is no need to track cmux's full commented template. `cmux
reload-config` applies an edit — no restart.

Anything the terminal itself owns — font family and size, transparency, theme, keybinds — is Ghostty
configuration, which cmux reads from `~/.config/ghostty/config` and this repo does not track. Set
`font-size` there to size terminal text alone, leaving the rest of the app where it is.

## Command reference

Synopses only — the authoritative documentation is the header comment above each definition.

### ssh + tmux

tmux runs on the **remote** in `ssht`/`sshts`/`sshtsf`, so the session outlives a dropped connection.
`--ecf` adds the Emacs socket forward described below.

| | |
|---|---|
| `ssht [--ecf] HOST [tmux-args...]` | ssh to `HOST` and run tmux there. `ssh-tmux.zsh` |
| `sshts [--ecf] HOST [tmux-opts...] SESSION [command...]` | attach to `SESSION` there, creating it if absent (`new-session -A`) |
| `sshtsf [HOST [SESSION]]` | remembers host, session, folder and command in `~/.config/sshtsf/config.toml`, so a two-word invocation replaces an alias per session. Picks with fzf when present, else a numbered menu. `-n` registers a new session; `-e`/`-E` and `-w`/`-W` override ecf and waypipe for one call; `--dry-run` prints the ssh command |
| `sshtsf list \| live \| add \| rm \| set \| default \| remote \| config-path` | manage that config, and `sshtsf remote [HOST]` adds a git remote for the current repo on another host. `sshtsf --help` and the docstring in `bin/sshtsf` carry the detail |
| `tssh-ecf [HOST]` | tmux **locally**, purely to keep an `ssh-ecf` connection alive; no argument lists the existing sessions |

### Emacs routing

With the forward live, `emacsclient` / `$EDITOR` / `magit` on a remote host open in the laptop's
Emacs. Resolution is per call, not per login, so a pane that outlived a disconnect picks up the new
forward on its next invocation.

| | |
|---|---|
| `ssh-ecf HOST [args...]` | ssh with the laptop's Emacs server socket reverse-forwarded |
| `emacs-remote [ssh\|sshx] [user@host]` | route `emacsclient`/`$EDITOR`/`$BROWSER`/`magit` through the forward. `off` restores local-only. Enabled automatically on interactive ssh logins |
| `ecf-prepare REMOTE [label]` | the shared plumbing: clears a stale socket and fills `$ECF_SSH_OPTS` |
| `emacsclient-auto.sh` | the router itself. Knobs: `EMACSCLIENT_TRAMP_PREFIX`, `EMACSCLIENT_FORWARD_SOCKET`, `EMACSCLIENT_BIN`, `EMACSCLIENT_AUTO_DEBUG` |
| `ec-browse URL...` | open URLs via that Emacs. Knobs: `EC_BROWSE_EMACSCLIENT`, `EC_BROWSE_FUNCTION` |

### Shell helpers

| | |
|---|---|
| `magit [-n] [DIR...]` | open magit for each directory, each in its own new frame; `-n` uses the current frame. Works through the Emacs forward |
| `with-picker [-a\|-e] PICKER [ARGS...] -- CMD [ARGS...]` | run a picker and hand its selection to a command; `-e` invokes once per selection |
| `add-to-path DIR`, `add-to-path-end DIR` | prepend/append if absent and a directory; idempotent |
| `lpath`, `remove-path DIR` | list `$PATH` one entry per line; drop one entry |
| `tmux-env-refresh` | re-reads `DISPLAY`/`WAYLAND_DISPLAY`/`SSH_AUTH_SOCK`/… from tmux each prompt, so a shell that predates a reconnect stops pointing at a dead socket |

Global aliases (zsh), usable at the end of any command: `G` `Gi` → `| grep`, `| grep -i`;
`L` → `| less`; `W` → `| wc`.

Note that `rm`, `mv` and `cp` are aliased to their `-i` forms, so a script that means the plain
command should call `command rm` (or `\rm`).

## Notes

- The plugin *list* is `plugins=(...)` in `dot-zshrc.zsh`; the *clones* for the two that oh-my-zsh
  does not ship are in `omz-plugins-install.zsh`. The two have to agree: a clone with no entry is
  dead weight, an entry with no clone makes oh-my-zsh warn on every shell start.
- `zsh` can leave compiled `*.zwc` files next to these scripts (gitignored). `source` prefers one
  whenever it is not older than its source file, so a stale `.zwc` is normally inert — but anything
  that rewrites mtimes, `cp -R` included, can make a years-old copy win. Delete them if a change to
  a file appears to have no effect.
