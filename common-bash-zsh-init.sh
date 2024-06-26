# -*- Shell-script -*-

function add-to-path {
  if [[ ! ( $PATH == "$1":* || $PATH == *:"$1":* || $PATH == *:"$1" ) && -d "$1" ]]; then
    # echo add "$1" to path
    export PATH="$1":${PATH}
  fi
}

function add-to-path-end {
  if [[ ! ( $PATH == "$1":* || $PATH == *:"$1":* || $PATH == *:"$1" ) && -d "$1" ]]; then
    # echo add "$1" to path
    export PATH=${PATH}:"$1"
  fi
}


# ###
# # place /snap/bin before other paths

# export PATH="/snap/bin":${PATH}

###

add-to-path .

add-to-path-end ~/bin
add-to-path-end ~/usr/bin

### ruby

export RUBYOPT='-Ku'

###

export EDITOR=emacsclient

export LESSCHARSET=utf-8

### color

export DIFFCOLORS=always

###

export LD_LIBRARY_PATH=~/usr/lib

### idea

add-to-path ~/usr/idea/bin

### android-studio

add-to-path ~/usr/android-studio/bin


### global

export GTAGSLABEL=pygments


###
### java
###

export JAVA_MEM=-Xmx4096m
export JAVA_STACK=-Xss1m


###
### scala
###

export JAVA_OPTS="-Xmx4096m -Xss1m -Xms256m"


###
### react-native
###

export ANDROID_HOME=~/Android/Sdk
add-to-path-end ${ANDROID_HOME}/tools
add-to-path-end ${ANDROID_HOME}/platform-tools

## kscript

add-to-path ~/other-src/kscript/build/libs

##
## julia
##

add-to-path ~/usr/julia/bin


##
## python
##

add-to-path ~/.local/bin

##
## rust
##

add-to-path ~/.cargo/bin


##
## yarn
##

add-to-path ~/.yarn/bin

##
## swift
##

add-to-path-end ~/usr/swift/bin


##
## Nautilus open in terminal Desktop hack
##

[[ $PWD = "/home/hjlee/Desktop" ]] && cd


##
## CMake
##

export CMAKE_GENERATOR="Ninja"


#########
## alias

# alias ls='ls -F'
alias ll='ls -l'

#alias emacs='LANG=en_US.UTF-8 /usr/bin/emacs-snapshot-x'
#alias emacs="XMODIFIERS='' /usr/bin/emacs-snapshot-x"
# alias emacs="XMODIFIERS='' /mnt/archive/usr/emacs22/bin/emacs"
# alias emacs="LANG=en_US.UTF-8 XMODIFIERS='' /usr/bin/emacs"
# alias emacs="LANG=en_US.UTF-8 XMODIFIERS='' /home/hjlee/usr/emacs/bin/emacs"
alias emacs="LANG=en_US.UTF-8 XMODIFIERS='' emacs"
alias e=emacs
alias h=history
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

# alias mem='cat /proc/meminfo'

alias la='ls -a'
alias lstl='ls -tl | less'
alias lsatl='ls -atl | less'
alias lstla='ls -atl | less'
alias lssl='ls -Sl | less'

alias dusl='du $* | sort -nr | less'

alias l='zless -i'

alias ko='LANG=ko_KR'
alias ko.utf8='LANG=ko_KR.UTF-8'
alias en='LANG=en_US'
alias en.utf8='LANG=en_US.UTF-8'

alias magit='emacsclient -e "(magit-status \".\")"'

##
## chemacs
## 

alias de='\emacs --with-profile doom'
alias den='\emacs --with-profile doom-noevil'

##
## local-common-init.sh
##

local_init=$DIR/local-common-init.sh

if [[ -e $local_init ]]; then
   source $local_init
fi
