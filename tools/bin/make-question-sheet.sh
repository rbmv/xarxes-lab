# Copyright (c) 2021 
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
    echo "Usage: $0 -p (0-3)"
    echo "Generates answer sheet for specified lab assignment"
    echo "-p: means practica, takes number from 0 to 3"
    echo "Example: $0 -p 0"
    exit 1
}

checkEnv
[ "$?" = "1" ] && echo -e "\e[91mERROR:\e[39m No available student information. Complete initial configuration procedure and run again" && exit 0;
. $envFile

if [ "$#" -ne 2 ]; then
	Help
fi

while getopts "p:" OPTION; do
    case $OPTION in
    p)
        numPrac=$OPTARG
        [[ ! $numPrac =~ [0-3] ]] && {
            Help
        }
        ;;
    *)
	Help
        ;;
    esac
done

pr3_sources="echoClient.py customServer.py quoteServer.py customClient.py quoteCollector.py"
pr3_need_file="quoteCollector.py quoteServer.py customServer.py"
pr3_need_port="echoClient.py customServer.py quoteServer.py customClient.py"

ansDir="$HOME/practiques/practica$numPrac/informe"
mkdir -p $ansDir

fname="${ansDir}/InformePr${numPrac}-${GRUP}${SUBGRUP}"
template=$HOME/.updates/templates/lab$numPrac/answerTemplate-Pr$numPrac.txt

[ ! -f $template ] && echo "No template available for Practica $numPrac" && exit 1

REF=`echo 'Pr${numPrac}${GRUP}${SUBGRUP}' | sha256sum | cut -d" " -f1`

echo "Grup: $GRUP$SUBGRUP" > ${fname}
echo "NIU: $NIU1 - Alumne 1: $NOM1" >> ${fname}
echo "NIU: $NIU2 - Alumne 2: $NOM2" >> ${fname}
echo "RefCode: $REF" >> ${fname}
cat $template >> $fname

if [ -f ${fname}.docx ]; then
	read -p  "File $fname.docx already exists and will be overwriten, do you want to continue y/n (n)?" input
    [ -z $input ] || [ $input != "y" ] && echo "Assuming (No) exiting" && exit 0
fi

cd $ansdir >/dev/null
libreoffice --convert-to docx $fname --outdir $ansDir 2>/dev/null
rm $fname
if [[ $numPrac =~ [3] ]]; then
    echo -e "# Grup: $GRUP$SUBGRUP \n# NIU: $NIU1 - Alumne 1: $NOM1\n# NIU: $NIU2 - Alumne 2: $NOM2" | tee $pr3_sources > /dev/null 
    echo -e "PORT = $PORT_GRUP # Port assignat al vostre grup" | tee -a $pr3_need_port > /dev/null
    echo -e "FILE = \"quotes.json\"" | tee -a $pr3_need_file > /dev/null
fi 

cd - >/dev/null
