NS3CUR="/usr/local/share/ns-3.32/"
NS3_EXTERNALS="/home/alumne/practiques/practica1/simulation-scripts"

function read_args {
 IFS=" " read -ra args <<< "$*"
 for arg in "${args[@]}"; do
    optarg=`expr "x$arg" : 'x[^=]*=\(.*\)'`
    case $arg in
    --seed=*)
      echo "override seed with provided value"
      seed_num=$optarg;;
    externals/*) # only allowing execution of scripts from externals dir
      echo "lab 1 scenario detected"
      scenario=$(cut -d"/" -f2 <<< "$arg");;
    --default*)
      echo "using default topologies"
      seed_num=1;;
    --equalize*)
      echo "equalize seed in all scenarios"
      equalize=1;;
    -printChannelState | -tapMode)
      inner_args="${inner_args}${arg}";;
    *)
    outer_args="$outer_args $arg"
    esac
 done
 inner_args="externals/$scenario ${inner_args}"
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
function init_vals {
  outer_args=""
  inner_args=""
  seed_num=""
  seeding=""
  scenario=""
  offset=0
  equalize=0
}
function ns3 {
CWD="$PWD"
cd $NS3CUR >/dev/null
./waf --cwd="$CWD" $*
cd - >/dev/null
}
function ns3-run-wparams {
init_vals
CWD="$PWD"
read_args "$*"
if [ -n "$SEED_STRING" ] && [ -z "$seed_num" ]; then
  echo "Seeding with user configuration"
  map_scenarios
  [ $equalize -eq 1 ] && offset=6
  seed_num=${SEED_STRING:$offset:1}
elif [ -z "$seed_num" ]; then
  seed_num=1
fi
seeding=" --seed=$seed_num"
inner_args="${inner_args}${seeding}"

cd $NS3CUR >/dev/null
./waf --cwd="$CWD" --run "$inner_args" $outer_args
cd - >/dev/null
}

