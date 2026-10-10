# Starship prompt
if [[ -o interactive ]]; then
    export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
    eval "$(starship init zsh)"
fi

# Format man pages
export MANROFFOPT=-c
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# PATH additions
for p in "$HOME/Applications/depot_tools" "$HOME/.local/bin" "/opt/node/bin"; do
    if [[ -d "$p" && ":$PATH:" != *":$p:"* ]]; then
        export PATH="$p:$PATH"
    fi
done

##################
### Key Bindings #
##################
# Enable vim bindings
bindkey -v
# Cut the Esc mode-switch delay from ~400ms to near-instant
export KEYTIMEOUT=1

# Start every new prompt in insert mode instead of vi normal mode
# (without this, zsh starts each shell in normal mode and typing does nothing until you hit `i`)
function zle-line-init() {
    zle -K viins
}
zle -N zle-line-init

# Word-jump (Alt+Left/Right) stops at each path segment instead of
# skipping a whole /path/like/this in one hop, like fish does
WORDCHARS=${WORDCHARS//\/}

# History settings (!! and !$ work natively in zsh)
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt SHARE_HISTORY

# cd by just typing a directory name, like fish
setopt AUTO_CD

######################
### Completion     ###
######################
autoload -Uz compinit
compinit

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' cache-path "$HOME/.cache/zsh/zcompcache"
zstyle ':completion:*' use-cache on

# Up/Down arrows filter history by what you've already typed (fish-style)
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey -M vicmd '^[[A' up-line-or-beginning-search
bindkey -M vicmd '^[[B' down-line-or-beginning-search
bindkey -M viins '^[[A' up-line-or-beginning-search
bindkey -M viins '^[[B' down-line-or-beginning-search

######################
### Fish-like feel ###
######################
# Ghost-text history/completion suggestions, accept with -> or End
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
bindkey -M viins '^F' autosuggest-accept

# Fuzzy history/file search: Ctrl-R history, Ctrl-T file finder, Alt-C fuzzy-cd
if [[ -r /usr/share/fzf/completion.zsh ]]; then
    # fzf saves/restores `$options` around setup, and `zle` is a read-only
    # pseudo-option, so restoring it throws a harmless "can't change option:
    # zle" on every shell start. Silence just that.
    source /usr/share/fzf/completion.zsh 2>/dev/null
fi
if [[ -r /usr/share/fzf/key-bindings.zsh ]]; then
    source /usr/share/fzf/key-bindings.zsh 2>/dev/null
fi

# Smarter cd: `z foo` jumps to your most-used dir matching "foo"
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
fi

# Command syntax highlighting — must be sourced last
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

##################
### Functions  ###
##################
backup() {
    cp "$1" "$1.bak"
}

copy() {
    if [[ $# -eq 2 && -d "$1" ]]; then
        local from="${1%/}"
        command cp -r "$from" "$2"
    else
        command cp "$@"
    fi
}

mkcd() {
    mkdir -p "$1" && cd "$1"
}

extract() {
    local file="$1"
    if [[ -f "$file" ]]; then
        case "$file" in
            *.tar.bz2) tar xjf "$file" ;;
            *.tar.gz)  tar xzf "$file" ;;
            *.bz2)     bunzip2 "$file" ;;
            *.rar)     unrar x "$file" ;;
            *.gz)      gunzip "$file" ;;
            *.tar)     tar xvf "$file" ;;
            *.tbz2)    tar xjf "$file" ;;
            *.tgz)     tar xzf "$file" ;;
            *.zip)     unzip "$file" ;;
            *.Z)       uncompress "$file" ;;
            *.7z)      7z x "$file" ;;
            *) echo "'$file' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$file' is not a valid file"
    fi
}

##################
### Aliases    ###
##################
# ls replacements
alias ls='eza -al --color=always --group-directories-first --icons=always'
alias la='eza -a --color=always --group-directories-first --icons=always'
alias ll='eza -l --color=always --group-directories-first --icons=always'
alias lt='eza -aT --color=always --group-directories-first --icons=always'
alias l.='eza -a | grep -e "^\."'

# System helpers
alias grubup="sudo grub-mkconfig -o /boot/grub/grub.cfg"
alias fixpacman="sudo rm /var/lib/pacman/db.lck"
alias tarnow='tar -acf '
alias untar='tar -zxvf '
alias wget='wget -c '
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'

# Arch helpers
alias gitpkg='pacman -Q | grep -i "\-git" | wc -l'
alias mirror="sudo cachyos-rate-mirrors"
alias cleanup='sudo pacman -Rns $(pacman -Qtdq)'

# Shortcuts
alias apt='man pacman'
alias apt-get='man pacman'
alias please='sudo'
alias jctl="journalctl -p 3 -xb"
alias nf='neofetch'
alias ff='fastfetch'
alias q='exit'
alias h='history'
alias c='clear'

# Git shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gcl='git clone'
alias gl='git log --oneline'
alias gd='git diff'
alias gpush='git push'
alias gpull='git pull'

# System control
alias wifi='nmtui'
alias install='yay -S'
alias update='yay -Syu'
alias search='yay -Ss'
alias lsearch='yay -Qs'
alias remove='yay -Rns'
alias shutdown='systemctl poweroff'
alias du='dust'

###################
### Environment ###
###################
export SHELL_CONFIG_DIR="$HOME/.config"
export GOPATH="$HOME/go"
export CARGO_HOME="$HOME/.cargo"
for p in "$GOPATH/bin" "$CARGO_HOME/bin" "$HOME/.npm-global/bin"; do
    if [[ -d "$p" && ":$PATH:" != *":$p:"* ]]; then
        export PATH="$PATH:$p"
    fi
done
export XDG_DATA_DIRS="$XDG_DATA_DIRS:/var/lib/flatpak/exports/share:$HOME/.local/share/flatpak/exports/share"

# Auto-run fastfetch on terminal start
if [[ -o interactive ]]; then
    fastfetch
fi
