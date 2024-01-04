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

function readInput()
{
    read -p "$text" input
	while [[ ! $input =~ $pattern ]] ; do
        read -p "$text" input
    done;
}

function help()
{
    echo "Usage:"
    echo "$0 [param]"
    echo "Acquires student information and stores it for environment sourcing"
    echo " -p | --purge: removes user information."
    echo " -h | --help: display this help"
}


if  [ ! -z "$1" ] && ([ $1 = "-p" ] ||  [ $1 = "--purge" ]); then
    rm -f $envFile
elif  [ ! -z "$1" ] && ([ $1 = "-h" ] ||  [ $1 = "--help" ]); then
    help
else

checkEnv
[ "$?" = "0" ] && exit 0;

echo    "================================================================"
echo -e "\e[91mInitial configuration:\e[39m Provide the requested student information"
echo    "================================================================"
pattern="[a-eA-E]{1}$"
text="GROUP (Valid range: A-E): "
readInput $text $pattern
GRUP=$input;
pattern="^[a-zA-Z]+(([',. -][a-zA-Z ])?[a-zA-Z]*)*$"
text="Name (Student 1):"
readInput $text $pattern
NOM1=$input;
text="Name (Student 2):"
readInput $text $pattern
NOM2=$input;
pattern="^[0-9]{7}$"
text="NIU (Student 1) - (7 digits):"
readInput $text $pattern
NIU1=$input;
text="NIU (Student 2) - (7 digits):"
readInput $text $pattern
NIU2=$input;
pattern="^[0-9]{1,2}$"
text="Subgroup Number (Valid range: 1-15):"
readInput $text $pattern
SUBGRUP=$input;

GRUP=`echo "$GRUP" | tr '[:upper:]' '[:lower:]'`
GRUPN=`echo $GRUP | tr '[a-c]' '[1-3]'`
let "PORT_GRUP = 8000 + (100 * $GRUPN) + $SUBGRUP"

SEED_STRING=""
while IFS="" read -n1 char; do
  num=$(printf '%d\n' "'$char'")
  num=$((num % 5 + 2 ))
  SEED_STRING="${SEED_STRING}${num}"
done <<< $(echo "$NIU1$NIU2$GRUP$SUBGRUP" | sha256sum | cut -d" " -f1)

STORAGE_ENV_VERSION=$STUDENT_ENV_VERSION

declare -p STORAGE_ENV_VERSION GRUP SUBGRUP NOM1 NOM2 NIU1 NIU2 PORT_GRUP SEED > $envFile && chmod u+x-w $envFile
[ "$?" = "0" ] && echo -e "\e[32m [SUCCESS] \e[39m: settings have been stored in UAB Lab environment"

fi
