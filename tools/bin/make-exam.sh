# Copyright (c) 2022 
# Ruben Martínez <ruben.martinez.vidal@uab.cat>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

#!/bin/bash
. $HOME/.uab-env/student-env-checks.sh

function Help()
{
    echo "Incorrect options provided"
    echo "Usage: $0 -p (0-3) -niu (8 digits) -pass (12 alphanumeric values) -r (4 digits)"
    echo "Generates answer sheet for specified lab assignment"
    echo "-p: means practica, takes number from 0 to 3"
    echo "-n: means niu, takes 7 digit number "
    echo "-k: means key, will be provided in class "
    echo "-r: means round, will be provided in class "
    echo "Example: $0 -p 0"
    exit 1
}

checkEnv
[ "$?" = "1" ] && echo -e "\e[91mERROR:\e[39m No available student information. Complete initial configuration procedure and run again" && exit 0;
. $envFile

if [ "$#" -ne 8 ]; then
	echo "Wrong number of parameters"
	Help
fi

while getopts "p:n:k:r:" OPTION; do
    case $OPTION in
    p)
        numPrac=$OPTARG
        [[ ! $numPrac =~ [0-3] ]] && {
            echo "wrong p option"
            Help
        }
        ;;
    n)
        niu=$OPTARG
        pattern="^[0-9]{7}$"
        [[ ! $niu =~ $pattern ]] && {
            echo "wrong n option"
            Help
        }
        ;;
    k)
        key=$OPTARG
        #pattern="^[a-zA-Z0-9]{12}$"
        #[[ ! $key =~ $pattern ]] &&{
        #    echo "wrong k option"
        #    Help
        #}
        ;;
    r)
        round=$OPTARG
        pattern="^[0-9]{4}$"
        [[ ! $round =~ $pattern ]] &&{
            echo "wrong r option"
            Help
        }
        ;;
    *)
	echo "others"
	Help
        ;;
    esac
done

ansDir="$HOME/practiques/practica$numPrac/exam"

rm -rf $ansDir
mkdir -p $ansDir

fname="${ansDir}/ExamenPr${numPrac}-${niu}"
template=$(ls -v $HOME/.updates/templates/lab$numPrac/*-examTemplate-Pr$numPrac 2>/dev/null | tail -n 1)
openTemplate="/tmp/openExam"

seed=$(($niu+$round))

RANDOM=$seed
node=$(((RANDOM%4)+1))

get_seeded_random()
{
  seed="$1"
  openssl enc -aes-256-ctr -pass pass:"$seed" -nosalt </dev/zero 2>/dev/null
}

if [ $numPrac -ne 3 ]; then

  [ ! -f $template ] && echo "No template available for Practica $numPrac" && exit 1
  openssl aes-256-cbc -d -pbkdf2 -out $openTemplate -in $template -pass pass:$key
  [ $? -ne 0 ] && echo "Wrong key: key will be provided in class" && exit 1

  echo "NIU: $niu" >> ${fname}
  echo "ROUND: $round" >> ${fname}
  echo "Nom: " >> ${fname}

  total_questions=5
  num_picks=3

  if [ $numPrac -eq 1 ]; then
     mt_file="${ansDir}/.metadata"
     random_source=$((get_seeded_random $seed) | head -c 1000 | hexdump -v -e '4/1 "%3u"'  | tr -s ' ' | tr -d '\n')
     python_script=$(cat <<EOF
import json
import random
import base64
with open("$openTemplate", "r") as file:
    base64_exam_json = file.read()
data = json.loads(base64.b64decode(base64_exam_json).decode('utf-8'))
random.seed('$random_source')
selected_questions = random.sample(data['questions'], min($num_picks, len(data['questions'])))
for question in selected_questions:
  if "input" in question and question["input"] == "node":
      question["input"] = "00:00:00:00:00:0$node"
data= json.dumps({ 'student': $niu, 'round': $round, 'questions': selected_questions }, indent=2)
base64_output_json = base64.b64encode(data.encode('utf-8')).decode('utf-8')
open("$mt_file", 'w').write(base64_output_json)
EOF
)
     python3 -c "$python_script" "$random_source" "$num_picks" "$mt_file"
     echo -e "\n\n1. Analitza les captures de tràfic (arxius pcap) que trobaràs a la carpeta $ansDir. \n" >> ${fname}
     echo -e "\n\n2. Respon a les preguntes que apareixeran en executar la comanda: make-exam-delivery.sh -p $numPrac -n $niu. \n" >> ${fname}
     echo -e "\n\n3. Lliura el fitxer: $ansDir/ExamenPr$numPrac-$niu.tar al lliurament corresponent de Campus Virtual \n" >> ${fname}

  elif [ $numPrac -eq 2 ]; then
    total_questions=6
    num_picks=2
    choices=$(shuf --random-source=<(get_seeded_random $seed) -i 1-${total_questions} -n ${num_picks} | sort)
    open="________"
    break="\n"
    for i in $choices; do
        d=$(sed -n ${i}p $openTemplate)
        eval "echo -e \"$d\"" >> ${fname}
    done
  fi

  rm $openTemplate

  if [ -f ${fname}.docx ]; then
   	 read -p  "File $fname.docx already exists and will be overwriten, do you want to continue y/n (n)?" input
     [ -z $input ] || [ $input != "y" ] && echo "Assuming (No) exiting" && exit 0
  fi
fi

if [ $numPrac -eq 1 ]; then

  RANDOM=$seed
  script=$((RANDOM%3))

  source $HOME/.uab-env/waf-alias.sh

  cd $ansDir
  if [ $script -eq 0 ]; then
     ns3-run-wparams "externals/hub-scenario.cc" --seed=$seed
  elif [ $script -eq 1 ]; then
     ns3-run-wparams "externals/switch-scenario.cc" --seed=$seed
  else
     ns3-run-wparams "externals/wifi-scenario.cc" --seed=$seed
  fi
elif [ $numPrac -eq 2 ]; then

    RANDOM=$seed
    script=$((RANDOM%3))
    nc -v -z -w 1 localhost 8100-8200 > /dev/null 2>&1

    if [ $script -eq 0 ]; then
       RANDOM=$seed
       port=$((RANDOM%100))
       port=$((8100+$port))
       echo "single test" | nc -l $port &
       echo -e " Aquesta màquina virtual (nom de domini: localhost) té un servidor amb un port TCP en escolta a l'interval 8100-8200, digues de quin port es tracta: ${break}${open}" >> ${fname}
    elif [ $script -eq 1 ]; then  
       RANDOM=$seed
       ifnum=$(tail -n +3 /proc/net/dev | cut -d: -f1 | wc -l)
       pick=$(((RANDOM%$ifnum)+3))
       ifname=$(tail -n +$pick /proc/net/dev | head -n 1| cut -d: -f1 | xargs)
       declare -a options=("MTU" "IP" "MAC")
       RANDOM=$seed
       pick=$((RANDOM%3))
       echo -e "(En referència a aquesta màquina virtual) Quina és la ${options[$pick]} de la interfície: $ifname?${break}${open}" >> ${fname}
    else
       declare -a options=("deic.uab.cat" "ubuntu.com" "stallman.org" "gnu.org" "kernel.org")
       RANDOM=$seed
       pick=$((RANDOM%5))
       echo -e " Quina és l'adreça IP que correspon al següent nom de domini: ${options[$pick]}: ${break}${open}" >> ${fname}
    fi
elif [ $numPrac -eq 3 ]; then
    RANDOM=$seed
    template=$((RANDOM%3))
    if [ $round -lt 1500 ]; then
        temp_base=1
        num_temp=$(($temp_base+$template))
    elif [ $round -lt 2000 ]; then
        temp_base=4
        num_temp=$(($temp_base+$template))
    elif [ $round -lt 2500 ]; then
        num_temp=7
    elif [ $round -lt 3000 ]; then
        num_temp=8
    elif [ $round -lt 3500 ]; then
        num_temp=9
    elif [ $round -lt 4000 ]; then
        num_temp=10
    elif [ $round -lt 4500 ]; then
        num_temp=11
    elif [ $round -lt 5000 ]; then
        num_temp=12
    elif [ $round -lt 5500 ]; then
        num_temp=13
    elif [ $round -lt 5516 ]; then
        num_temp=15
    elif [ $round -lt 5517 ]; then
        num_temp=16
    elif [ $round -lt 5518 ]; then
        num_temp=17
    elif [ $round -lt 5519 ]; then
        num_temp=18
    elif [ $round -lt 5520 ]; then
        num_temp=19
    elif [ $round -lt 5521 ]; then
        num_temp=20
    else
        num_temp=14
    fi
    template=$HOME/.updates/templates/lab$numPrac/${num_temp}.tar.gz
    openTemplate=${ansDir}/${num_temp}.tar.gz
    [ ! -f $template ] && echo "No template available for Practica $numPrac" && exit 1
    openssl aes-256-cbc -d -pbkdf2 -out $openTemplate -in $template -pass pass:$key
    
    if [ $? -ne 0 ]; then
       echo "Wrong key: key will be provided in class" 
       rm -f $openTemplate 
       exit 1
    fi
fi

if [ $numPrac -eq 3 ]; then
  cd $ansDir >/dev/null
  tar xvzf ${openTemplate} 2>/dev/null
  #mv $num_temp/* .
  rm -rf $num_temp
  rm $openTemplate
  cp $HOME/.updates/lab-assigments/lab3/python-3.10.5.library.pdf . || true
else
  cd $ansDir >/dev/null
  libreoffice --convert-to docx $fname --outdir $ansDir 2>/dev/null
  rm $fname
  cd - >/dev/null
fi
