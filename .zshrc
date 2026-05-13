HISTFILE=~/.histfile
HISTSIZE=10000
SAVEHIST=10000
bindkey -e

# History behaviour: share across sessions, drop consecutive dups, ignore
# space-prefixed commands, normalise whitespace, confirm !! expansions.
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS HIST_VERIFY

# Completion: run the full security audit at most once a day; otherwise
# skip it (compinit -C) so new shells open ~100ms faster.
zstyle :compinstall filename '~/.zshrc'
autoload -Uz compinit
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi

# Tab completion: navigable menu + case-insensitive / partial-word matching.
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*'

# GPG configuration
export GPG_TTY=$(tty)

# Git integration
autoload -Uz vcs_info
precmd_vcs_info() { vcs_info }
precmd_functions+=( precmd_vcs_info )
setopt prompt_subst

# Prompt configuration
PROMPT='${vcs_info_msg_0_} %~ $ '
zstyle ':vcs_info:git:*' formats '%b'

# PATH additions (shared across machines; per-machine extras live in ~/.miscrc).
PATH=$HOME/.juliaup/bin:$PATH        # juliaup
PATH=$HOME/.julia/bin:$PATH          # Julia-installed apps
PATH=$HOME/.opencode/bin:$PATH       # opencode
PATH=$HOME/.npm-global/bin:$PATH     # user-global npm
PATH=$PATH:$HOME/.local/bin
export PATH

# Helium browser as the Chrome executable for tools that probe $CHROME_EXECUTABLE.
export CHROME_EXECUTABLE=/usr/bin/helium-browser

# nvm — load system node by default
source /usr/share/nvm/init-nvm.sh
nvm use system >/dev/null

alias sway='sway --unsupported-gpu'
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

source ~/.miscrc
