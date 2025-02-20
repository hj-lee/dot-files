
alias emacs=/Applications/Emacs.app/Contents/MacOS/Emacs
add-to-path-end /Applications/Emacs.app//Contents/MacOS/bin

add-to-path /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/
add-to-path /Applications/Xcode.app/Contents/Developer/usr/bin

# export SYSTEM_FRAMEWORK_SEARCH_PATHS=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library

export ANDROID_HOME=~/Library/Android/sdk
export ANDROID_SDK_ROOT=~/Library/Android/sdk
add-to-path-end ${ANDROID_SDK_ROOT}/tools
add-to-path-end ${ANDROID_SDK_ROOT}/platform-tools

add-to-path /Applications/Android\ Studio.app/Contents/MacOS/

# homebrew ruby 
add-to-path /opt/homebrew/opt/ruby/bin
# export LDFLAGS="-L/opt/homebrew/opt/ruby/lib"
# export CPPFLAGS="-I/opt/homebrew/opt/ruby/include"
