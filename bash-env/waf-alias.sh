NS3CUR="/usr/local/share/ns-3.32/"
NS3_EXTERNALS="/home/alumne/practiques/practica1/simulation-scripts"
scenario=""
seed_num=""
offset=0
extra_args=""

function read_args {
 IFS=" " read -ra args <<< "$*"
 for arg in "${args[@]}"; do
    optarg=`expr "x$arg" : 'x[^=]*=\(.*\)'`
    case $arg in
    --seed=*)
      echo "override seed with provided value"
      seed_num=$optarg;;
    externals/*)
      echo "lab 1 scenario detected"
      scenario=$(cut -d"/" -f2 <<< "$arg");;
    --default*)
      echo "using default topologies"
      seed_num=1;;
    *)
    extra_args="$extra_args $arg"
    esac
 done
}
function map_scenarios {
  case $scenario in
  hub-scenario)
    offset=1;;
  switch-scenario)
    offset=2;;
  wifi-scenario)
    offset=3;;
  tap-csma)
    offset=4;;
  inter-networks)
    offset=5;;
  esac
}
function ns3 {
CWD="$PWD"
cd $NS3CUR >/dev/null
./waf --cwd="$CWD" $*
cd - >/dev/null
}
function ns3-run-wparams {
CWD="$PWD"
read_args "$*"
if [ -n "$SEED_STRING" ] && [ -z "$seed_num" ]; then
  echo "Seeding with user configuration"
  map_scenarios
  seed_num=${SEED_STRING:$offset:1}
elif [ -z "$seed_num" ]; then
  seed_num=1
fi
seeding=" --seed=$seed_num"
cd $NS3CUR >/dev/null
./waf --cwd="$CWD" --run "externals/$scenario${seeding}" $extra_args
cd - >/dev/null
extra_args=""
seed_num=""
seeding=""
}

