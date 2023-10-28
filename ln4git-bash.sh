
function ln {
    while [[ $1 =~ ^-.* ]]; do
	  shift
    done

    src=$1
    dest=$2

    if   [[ ! -e $src ]]; then
	echo "$src not found"
	return 1
    elif [[ ! -d $src ]]; then
	echo "$src is not directory"
	return 1
    fi

    [[ -d $dest ]] && dest=$dest/$(basename $src)

    MSYS_NO_PATHCONV=1 cmd /c"mklink /J $(cygpath -w $dest) $(cygpath -w $src)"
}
