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
        pattern="^[a-zA-Z0-9]{12}$"
        [[ ! $key =~ $pattern ]] &&{
            echo "wrong k option"
            Help
        }
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
template=$HOME/.updates/templates/lab$numPrac/examTemplate-Pr$numPrac.txt
openTemplate="/tmp/openExam"

[ ! -f $template ] && echo "No template available for Practica $numPrac" && exit 1

openssl aes-256-cbc -d -pbkdf2 -out $openTemplate -in $template -pass pass:$key
[ $? -ne 0 ] && echo "Wrong key: key will be provided in class" && exit 1


echo "NIU: $niu" >> ${fname}
echo "ROUND: $round" >> ${fname}
echo "Nom: " >> ${fname}

echo -e "\n\nAnalitza les captures de tràfic (arxius pcap) que trobaràs a la carpeta $ansDir i respon a les següents preguntes:\n" >> ${fname}

seed=$(($niu+$round))

RANDOM=$seed
node=$(((RANDOM%4)+1))

get_seeded_random()
{
  seed="$1"
  openssl enc -aes-256-ctr -pass pass:"$seed" -nosalt </dev/zero 2>/dev/null
}

total_questions=5
num_picks=3

if [ $numPrac -eq 2 ]; then
    total_questions=6
    num_picks=2
fi

choices=$(shuf --random-source=<(get_seeded_random $seed) -i 1-${total_questions} -n ${num_picks} | sort)
open="________"
break="\n"
for i in $choices; do
    d=$(sed -n ${i}p $openTemplate)
    eval "echo -e \"$d\"" >> ${fname}
done

rm $openTemplate

if [ -f ${fname}.docx ]; then
	read -p  "File $fname.docx already exists and will be overwriten, do you want to continue y/n (n)?" input
    [ -z $input ] || [ $input != "y" ] && echo "Assuming (No) exiting" && exit 0
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
else if [ $numPrac -eq 2 ]; then
    RANDOM=$seed
    ifnum=$(tail -n +3 /proc/net/dev | cut -d: -f1 | wc -l)
    pick=$((RANDOM%$ifnum+)+3)
    ifname=$(tail -n +$pick /proc/net/dev | cut -d: -f1)
    echo -e "Quina és la MTU de la interficie $ifname?\n _______" >> ${fname}
fi



cd $ansDir >/dev/null
libreoffice --convert-to docx $fname --outdir $ansDir 2>/dev/null
rm $fname
cd - >/dev/null
