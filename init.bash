
function lpath {
    echo "${PATH//:/$'\n'}"
}

function remove-path {
    PATH=$(lpath | grep -v "^$1\$" | paste -s -d ":" -)
}
