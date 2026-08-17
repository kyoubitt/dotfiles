# Disable greeting
set -U fish_greeting ""

# Starship prompt
if status is-interactive
    set -gx STARSHIP_CONFIG $HOME/.config/starship/starship.toml
    starship init fish | source
end

# Format man pages
set -x MANROFFOPT -c
set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"

# Source fish_profile if exists
if test -f $HOME/.fish_profile
    source $HOME/.fish_profile
end

# PATH additions (last entry ends up highest priority)
for p in $HOME/Applications/depot_tools $HOME/.local/bin /opt/node/bin
    if test -d $p
        if not contains -- $p $PATH
            set -p PATH $p
        end
    end
end

#####################
### Key Bindings  ###
#####################
# Enable vim bindings
set -U fish_key_bindings fish_vi_key_bindings

# Start every new prompt in insert mode instead of vi normal mode
# (without this, fish starts each shell in normal mode and typing does nothing until you hit `i`)
set fish_bind_mode insert

# Always block cursor (disable cursor switching)
function fish_mode_prompt
    echo -n ''
end

# !! and !$ support
function __history_previous_command
    switch (commandline -t)
        case "!"
            commandline -t $history[1]
            commandline -f repaint
        case "*"
            commandline -i !
    end
end

function __history_previous_command_arguments
    switch (commandline -t)
        case "!"
            commandline -t ""
            commandline -f history-token-search-backward
        case "*"
            commandline -i '$'
    end
end

bind ! __history_previous_command
bind '$' __history_previous_command_arguments

##################
### Functions  ###
##################
# Better history
function history
    builtin history --show-time='%F %T '
end

function backup --argument filename
    cp $filename $filename.bak
end

# Copy DIR1 DIR2
function copy
    set count (count $argv | tr -d \n)
    if test "$count" = 2; and test -d "$argv[1]"
        set from (string trim -r -c '/' $argv[1])
        set to $argv[2]
        command cp -r $from $to
    else
        command cp $argv
    end
end

# mkcd DIR
function mkcd
    mkdir -p $argv[1]; and cd $argv[1]
end

# Extract archives
function extract
    set file $argv[1]
    if test -f $file
        switch $file
            case '*.tar.bz2'
                tar xjf $file
            case '*.tar.gz'
                tar xzf $file
            case '*.bz2'
                bunzip2 $file
            case '*.rar'
                unrar x $file
            case '*.gz'
                gunzip $file
            case '*.tar'
                tar xvf $file
            case '*.tbz2'
                tar xjf $file
            case '*.tgz'
                tar xzf $file
            case '*.zip'
                unzip $file
            case '*.Z'
                uncompress $file
            case '*.7z'
                7z x $file
            case '*'
                echo "'$file' cannot be extracted via extract()"
        end
    else
        echo "'$file' is not a valid file"
    end
end

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
alias cleanup='sudo pacman -Rns (pacman -Qtdq)'

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
set -gx SHELL_CONFIG_DIR $HOME/.config
set -gx GOPATH $HOME/go
set -gx CARGO_HOME $HOME/.cargo
fish_add_path $GOPATH/bin $CARGO_HOME/bin ~/.npm-global/bin
# Auto-run fastfetch on terminal start
if status is-interactive
    fastfetch
end
set -gx XDG_DATA_DIRS $XDG_DATA_DIRS /var/lib/flatpak/exports/share $HOME/.local/share/flatpak/exports/share
alias lowy "java -Djava.awt.headless=false -Dsun.java2d.xrender=true -jar ~/LowYSwampHut/build/libs/LowYSwampHutForFixedSeedGUI-1.3.2.jar"
alias witch "xwayland-satellite & sleep 2 && DISPLAY=:2 _JAVA_AWT_WM_NONREPARENTING=1 java -Djava.awt.headless=false -Dsun.java2d.xrender=true -jar ~/LowYSwampHut/build/libs/LowYSwampHutForFixedSeedGUI-1.3.2.jar"
alias fortress "~/Downloads/unified/run-with-scoped-xwayland.sh gradle -p ~/Downloads/unified :fortress:run"
alias monument "~/Downloads/unified/run-with-scoped-xwayland.sh gradle -p ~/Downloads/unified :monument:run"
alias carpetserver='tmux attach -t carpetserver; or tmux new -s carpetserver -c ~/carpet-test-server "/usr/lib/jvm/java-8-openjdk/bin/java -jar minecraft_server.1.12.2_carpet_test.jar --nogui"'


# Added by Antigravity CLI installer
set -gx PATH "/home/zerda/.local/bin" $PATH
