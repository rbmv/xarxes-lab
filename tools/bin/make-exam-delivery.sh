# Copyright (c) 2024
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
#. $HOME/.uab-env/student-env-checks.sh

language=${LNG:-"ca"}
current_date=$(date +'%Y-%m-%d %H:%M:%S')

function readInput()
{
    read -p "$text" input
	while [[ ! $input =~ $pattern ]] ; do
        read -p "$text" input
    done;
}

function Help()
{
    echo "Incorrect options provided"
    echo "Usage: $0 -p (0-3) -niu (8 digits) -pass (12 alphanumeric values) -r (4 digits)"
    echo "Generates answer sheet for specified lab assignment"
    echo "-p: means practica, takes number from 0 to 3"
    echo "-n: means niu, takes 7 digit number "
    echo "Example: $0 -p 1 -n 1111111"
    exit 1
}

#checkEnv
#[ "$?" = "1" ] && echo -e "\e[91mERROR:\e[39m No available student information. Complete initial configuration procedure and run again" && exit 0;
#. $envFile

if [ "$#" -ne 4 ]; then
	echo "Wrong number of parameters"
	Help
fi

while getopts "p:n:" OPTION; do
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
    *)
	echo "others"
	Help
        ;;
    esac
done

deliverable="ExamenPr${numPrac}-${niu}.tar"
ansDir="$HOME/practiques/practica$numPrac/exam"
mf_file="$ansDir"/".manifest"
mt_file="$ansDir"/".metadata"
[ -d $ansDir ] || ( echo "Can not create delivery, exam for lab $numPrac does not exist, you need to run the make-exam.sh first"; exit 1 )
pcaps=$(ls "$ansDir"/*".pcap" 2>/dev/null)
[ -n "$pcaps" ] || (echo "pcap capture files not detected, did you remove them?, run make-exam.sh to restore"; exit 1)
[ -f "$mt_file" ] || (echo "missing metada for your examen questions, did you remove it?, run make-exam.sh to restore"; exit 1 )


rm -rf $mf_file

python_script=$(cat <<EOF
import json
import sys
import base64
green_color = '\033[32m'
dark_yellow_color = '\033[33m'
bold_text = '\033[1m'
reset_color = '\033[0m'

user_answers = []
file_path = sys.argv[1]
output_path = sys.argv[2]
# Read the contents of the file
with open(file_path, 'r', encoding='utf-8') as file:
    base64_encoded_json = file.read()

# Decode base64 to get the JSON content
json_content = base64.b64decode(base64_encoded_json).decode('utf-8')
data = json.loads(json_content)

if data['student'] != $niu:
   print ("Error: provided NIU does not match the generated exam")
   sys.exit(1)

print ("===============================================================")
print (f"{bold_text}Exam n: {dark_yellow_color}{data['round']} {reset_color}{bold_text}for Student: {dark_yellow_color}$niu{reset_color}")
print ("===============================================================")

for question in data['questions']:
    has_input=False
    is_open_question = len(question['options']) == 1 and len(question['options'][0]['text']['$language']) == 0
    if "input" in question:
        question['text']['$language']= question['text']['$language'].replace("\$input", question['input'] )
        has_input=True
    print(f"{green_color}Question {question['number']}: {question['text']['$language']}{reset_color}")
    if is_open_question:
        user_input = input("Your answer: ")
        if has_input:
           answer={"number": question['number'], "input": question['input'], "answer": user_input}
        else:
           answer={"number": question['number'], "answer": user_input}
        user_answers.append(answer)
        print(f"{bold_text}{dark_yellow_color}You entered: {user_input}{reset_color}")
    else:
        for idx, option in enumerate(question['options'], 1):
            prefix = chr(96 + idx) + '.'
            print(f"{prefix}) {option['text']['$language']}")
        msg="Enter your choice [a-" + chr(96 + len(question['options'])) +"]: "
        user_choice = input(msg)
        while user_choice not in [chr(96 + i) for i in range(1, len(question['options']) + 1)]:
            print("Invalid choice. Please select a valid option.")
            user_choice = input(msg)
        selected_option = question['options'][ord(user_choice) - 97]['text']['$language']
        if has_input:
           answer={"number": question['number'], "input": question['input'], "answer": selected_option}
        else:
           answer={"number": question['number'], "answer": selected_option}
        user_answers.append(answer)
        print(f"You selected: {dark_yellow_color}{bold_text}{user_choice}{reset_color}\n")

with open(output_path, 'a', encoding='utf-8') as temp_file:
  temp_file.write(json.dumps({ 'student': data['student'], 'round': data['round'], 'language': '$language', 'date': '$current_date', 'answers': user_answers }))
EOF
)

# Execute the Python script
python3 -c "$python_script" "$mt_file" "$mf_file" || exit 1

tmp_file=$(mktemp)
base64 $mf_file > $tmp_file && mv $tmp_file $mf_file 
tar -cf "$deliverable" -C "$ansDir" --transform 's#.*/##' "$ansDir"/*.pcap "$mf_file" 2>/dev/null || exit 1
mv $deliverable $ansDir || true
rm -f $mt_file
