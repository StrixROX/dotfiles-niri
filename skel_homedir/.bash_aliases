#
# ~/.bash_aliases
#

#
# Environment variables
#

export EDITOR=nvim

#
# Aliases
#

### general stuff
alias c="clear"
alias l="ls --group-directories-first"
alias la="ls -la --group-directories-first"
alias editals="nvim ~/.bash_aliases"
alias loadbash="source ~/.bashrc"
alias explorer="nautilus . & disown"

alias ssh="kitty +kitten ssh"

alias niriconf="cd ~/.config/niri/myconfigs/ && yazi"
alias kittyconf="cd ~/.config/kitty && nvim kitty.conf"
#alias gpu-screen-recorder="prime-run gpu-screen-recorder"

alias niribasic="niri -c ~/.config/niri/config-game.kdl"

### Flatpak Stuff
alias bambuStudio="flatpak run com.bambulab.BambuStudio"
alias libreOffice="flatpak run org.libreoffice.LibreOffice"


### Audio Stuff

# ALSA -> soundcard controller
# PipeWire -> multiplexing software (basically, pulseaudio + jack). works on top of ALSA
# qpwgraph -> PipeWire patchbay. can save wire sets
# pavucontrol -> PipeWire volume control

