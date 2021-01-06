NS3CUR="/usr/local/share/ns-3.32/"

function waf {
CWD="$PWD"
cd $NS3CUR >/dev/null
./waf --cwd="$CWD" $*
cd - >/dev/null
}

function wafr {
waf --run "$*"
}

