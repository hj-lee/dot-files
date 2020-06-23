
function ln() {
    # echo $*
    while [[ $1 =~ ^-.* ]]; do
	  shift
    done
    # echo $*
    cmd /c"mklink /J $(cygpath -w $2) $(cygpath -w $1)"
}
