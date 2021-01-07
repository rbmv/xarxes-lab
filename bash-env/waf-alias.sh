NS3CUR="/usr/local/share/ns-3.32/"
NS3_EXTERNALS="/home/alumne/practiques/practica1/simulation-scripts"

function ns3 {
CWD="$PWD"
cd $NS3CUR >/dev/null
./waf --cwd="$CWD" $*
cd - >/dev/null
}
