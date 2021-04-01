# Copyright (c) 2020 
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

declare -a deps=("python" "nc" "sha256sum")
timeout="600"
short_timeout="35"
processing_timeout="2"
test_index=0
tcp_fin_timeout=`cat /proc/sys/net/ipv4/tcp_fin_timeout`
grade=0
display_grading=0
grade_collector=0
grade_server=0
grade_custom_server=0
grade_custom_client=0
collector_test=1
server_test=1
custom_server_test=1
custom_client_test=1
settings_file=".qotd-settings"
all_tests=1
package=1
conformant=1

function usage()
{
    echo "Usage: $0 [-s <collector|server|custom-server|custom-client>] [-c]" 1>&2;
    exit 1;
}

function check_test_conformance()
{
    local mandatory_result_collector=(0 0 0 0)
    local mandatory_result_server=(0 0 0 0 0)
    local mandatory_result_custom_server=(0 1 1 0 0 0 0 0 0 1 1 1 0 0 0 0)
    local mandatory_result_custom_client=(0 1 0 0 1 0 0 1)

    conformant=0
    local message=""

    print_headers " conformance checks "

    if [ ${#test_result_collector[@]} -gt 0 ]
    then
         message="Collector failed tests:\e[91m"
         for i in $(seq 0 1 ${#mandatory_result_collector[@]});
         do
             [ ${mandatory_result_collector[$i-1]} -eq 0 ] && [ ${test_result_collector[$i-1]} -ne 0 ] && conformant=1 && message="$message (Test $i)";
         done
         message="$message\e[39m\n"
    fi

    if [ ${#test_result_server[@]} -gt 0 ]
    then
        message="$message Server failed tests:\e[91m"
        for i in $(seq 1 ${#mandatory_result_server[@]});
        do
            [ ${mandatory_result_server[$i-1]} -eq 0 ] && [ ${test_result_server[$i-1]} -ne 0 ] && conformant=1 && message="$message (Test $i)";
        done
        message="$message\e[39m\n"
    fi


    if [ ${#test_result_custom_server[@]} -gt 0 ]
    then
        message="$message Custom server failed tests:\e[91m"
        for i in $(seq 1 ${#mandatory_result_custom_server[@]});
        do
            [ ${mandatory_result_custom_server[$i-1]} -eq 0 ] && [ ${test_result_custom_server[$i-1]} -ne 0 ] && conformant=1 && message="$message (Test $i)";
        done
        message="$message\e[39m\n"
    fi


    if [ ${#test_result_custom_client[@]} -gt 0 ]
    then
        message="$message Custom client failed tests:\e[91m"
        for i in $(seq 1 ${#mandatory_result_custom_client[@]});
        do
            [ ${mandatory_result_custom_client[$i-1]} -eq 0 ] && [ ${test_result_custom_client[$i-1]} -ne 0 ] && conformant=1 && message="$message (Test $i)";
        done
        message="$message\e[39m\n"
    fi

    if [ $conformant -ne 0 ]
    then
        echo -e "One or more mandatory tests have failed. \nDetails follow:\n $message"
    else
        echo -e " \e[32m All mandatory tests PASSED succesfully!\e[39m"
        echo -e "You may now re-run this tester with \e[32m-p\e[39m option to package a deliverable and submit it for evaluation."
    fi

    return $conformant
}
function display_grades()
{
    echo "#################"
    echo " GRADING TABLE   "
    echo "#################"
    [ $collector_test -eq 1 ] && echo "Quote collector: $grade_collector out of 20"
    [ $server_test -eq 1 ] && echo "QOTD server: $grade_server out of 20"
    [ $custom_server_test -eq 1 ] && echo "Custom QOTD server: $grade_custom_server out of 30"
    [ $custom_client_test -eq 1 ] && echo "Custom QOTD client: $grade_custom_client out of 15"
    echo "===================================================="
    total_grade=$((grade_collector + grade_server + grade_custom_server + grade_custom_client))
    [ $all_tests -eq 1 ] && echo -e "\e[1;93mTotal: $total_grade \e[39mout of 85"
}

function cmd_line_settings()
{
while getopts ":s:cg" o; do
    case "${o}" in
        s)
            skip=${OPTARG}
            if [[ $skip =~ ^collector$ ]]
            then
                collector_test=0
                all_tests=0
            elif [[ $skip =~ ^server$ ]]
            then
                server_test=0
                all_tests=0
            elif [[ $skip =~ ^custom-server$ ]]
            then
                custom_server_test=0
                all_tests=0
            elif [[ $skip =~ ^custom-client$ ]]
            then
                custom_client_test=0
                all_tests=0
            else
                usage
            fi
            ;;
        c)
            [ -f $settings_file ] && rm -f $settings_file
            ;;
        g)
            display_grading=1
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

}

function user_settings()
{

    [ -f "$settings_file" ] && source $settings_file

    if [ -z "$group_port" ]; then
        if [ -z "$PORT_GRUP" ]; then
            echo "Type your group's corresponding port number and press [ENTER]"
            echo "(for instance, if your were x-c11 then: grup C 3, port= 8000 + 100 * 3 + 11 = 8311)"
            echo -n "Port number: "
            read group_port
        else
            group_port=$PORT_GRUP
        fi
    fi

    if [ -z "$pythonv" ]; then

        p2_path=`which python2`
        py2=$?
        p3_path=`which python3`
        py3=$?

        if [ $py2 -eq 0 ] && [ $py3 -eq 0 ]; then

            echo "The system has multiple python versions. \
                  Choose which one shall be used to run your scripts and press [ENTER]:"
            echo " (1) $p2_path"
            echo " (2) $p3_path"

            read -p "Number (1-2):" pyop
            while [[ ! $pyop =~ ^[1-2]{1}$ ]] ; do
                read -p "Number (1-2):" pyop
            done;

            [ $pyop -eq 1 ] && pythonv="$p2_path"
            [ $pyop -eq 2 ] && pythonv="$p3_path"

        else

            [ $py2 -eq 0 ] && pythonv="$p2_path"
            [ $py3 -eq 0 ] && pythonv="$p3_path"

        fi

    fi

    declare -p group_port pythonv | sed 's/--/-g/g'  > $settings_file

    echo "##########################"
    echo "USER SETTINGS:           #"
    echo "##########################"
    echo -e "Group port: $group_port"
    echo -e "Python version: $pythonv"
}

function grade()
{
 if [ ! -z $1 ]
 then
    grade=$((grade + $1))
 fi
}
function check_deppends()
{
    print_headers "Software deppendencies"
    for dep in "${deps[@]}"
    do
        cmd="which $dep"
        msg="Testing dependency $dep"
        exec_test "${cmd}"
        print_critical_testcase "$msg" $? "Dependency $dep is missing" "Use \e[32m\"sudo apt-get install python netcat coreutils\"\e[39m to install all dependencies and execute tester again"
    done
}
function check_network()
{
    test_index=0;
    print_headers "Network"

    cmd="[ `netstat -lt | grep :$group_port | wc -l` -eq 0 ]"
    msg="Listening port is not in use"
    exec_test "${cmd}"
    ex=$?
    print_test_case "$msg" $ex "N/A" "warn"

    if [ $ex != 0 ]
    then
        echo -e "Passive wait - resources are being released \e[91m(DO NOT CANCEL EXECUTION) \e[39m"

        pid_quoteServer=`ps aux | grep quoteServer.py | grep python | grep -v grep | awk '{print $2}'`
        [  ! -z $pid_quoteServer ] && echo -e "Quote Server is running .... kill signal issued " && kill -9 $pid_quoteServer && sleep $processing_timeout
        pid_customServer=`ps aux | grep customServer.py | grep python | grep -v grep | awk '{print $2}'`
        [  ! -z $pid_customServer ] && echo -e "Custom Server is running .... kill signal issued " && kill -9 $pid_customServer && sleep $processing_timeout
        pid_ncserver=`ps aux | grep "nc -l $group_port" | grep -v grep | awk '{print $2}'`
        [  ! -z $pid_ncserver ] && echo -e "NC Server is running .... kill signal issued " && kill -9 $pid_ncserver && sleep $processing_timeout

        sleep $short_timeout
        msg="RETRY: Listening port is not in use"
        cmd="[ `netstat -lt | grep :$group_port | wc -l` -eq 0 ]"
        exec_test "${cmd}"
        print_critical_testcase "$msg" $? "port may be taken by another process" "Free or change the port manually, then execute the tester again" 
    fi

    msg="Previous connections terminated"
    cmd="[ `netstat -alt | grep :$group_port | wc -l` -eq 0 ]"
    exec_test "${cmd}"
    ex=$?
    print_test_case "$msg" $ex "N/A" "warn"
    if [ $ex != 0 ]
    then
        echo -e "Passive wait - resources are being released \e[91m(DO NOT CANCEL EXECUTION)\e[39m"
        sleep $tcp_fin_timeout   
        msg="RETRY: Previous connections terminated"
        cmd="[ `netstat -alt | grep :$group_port | wc -l` -eq 0 ]"
        exec_test "${cmd}"
        print_critical_testcase "$msg" $? "detected active connections from a previous run" "Wait a few seconds and execute again" 
    fi 
}
function print_headers()
{
echo "##########################"
echo "TESTING: $1"
echo "##########################"
}

function print_critical_testcase()
{
    res="\e[32mOK\e[39m"
    [ $2 -ne 0 ] && res="\e[91mFAIL\e[39m"
    echo -e "Test $test_index - $1 : $res"
    [ $2 -ne 0 ] && echo -e "\e[91mABORTING: $3\e[39m" && echo -e $4 && exit 1
    grade $5
}
function print_test_case()
{
    level="err"

    if [ -z $3 ] || [[ $3 == "N/A" ]]
    then
        points=0
    else
        points=$3
    fi

    if [ ! -z $4 ]
    then
        level=$4s
    fi

    if [ $level == "warn" ]
    then
        res="\e[93mWARNING\e[39m"
    else
        res="\e[91mFAIL\e[39m"
    fi

    if [ $2 -eq 0 ] 
    then
        res="\e[32mOK\e[39m"
        grade $points
    else
        points=0
    fi

    [ -z $3 ] || [[ $3 == "N/A" ]] && points="N/A"

    [ $display_grading -eq 1 ] && res="$res \e[1;93m ($points points)\e[39m"

    echo -e "Test $test_index - $1 : $res"
}

function still_executing()
{
    if [ ! -z $1 ]
    then 
        pid=$1 
        [ `ps aux | grep $pid | grep -v grep | wc -l` -eq 0 ] && print_critical_testcase "$2" 1 "server died unexpectedly during test" && exit 1
    fi
}

function exec_test()
{
    let "test_index++"
    eval $1 >> /dev/null
    res=$?
    [ ! -z $2 ] && still_executing $2 "$3"
    [ $res -ne 0 ] && return 1
    return 0
}

function init()
{
 echo "##########################"
 echo "RUNNING PRELIMINARY CHECKS"
 echo "##########################"
 
 cmd="[[ $group_port =~ ^[0-9]+$ ]] && [ $group_port -gt 8000 ] && [ $group_port -lt 65535 ]"
 msg="Valid port"
 exec_test "${cmd}"
 print_critical_testcase "$msg" $? "provide a numeric port above 8000"
 
 
 cmd="ls customServer.py quoteServer.py customClient.py quoteCollector.py"
 msg="Checking if all source files are present in execution directory"
 exec_test "${cmd}"
 print_critical_testcase "$msg" $? "can not perform test if source files are missing"

 if [ $collector_test -eq 1 ] && [ -e quotes.json ]
 then
    cmd="mv -f quotes.json quotes.json.bk"
    msg="Removing quotes.json (backup has been stored in quotes.json.bk)"
    exec_test "${cmd}"
    print_test_case "$msg" $?
 fi

 check_deppends
}

### QUESTION 6
function test_collector()
{
    test_index=0;
    test_result_collector=(0 0 0 0)
    print_headers "quoteCollector.py"

    tmpout="$(mktemp)"
    # Launch monitor
    timeout $timeout bash -c -- 'while true; do netstat -tn | grep :17 >> $0; sleep 1; done' $tmpout & 2>/dev/null
    pid_mon=$!

    msg="Proper execution and termination"
    cmd="timeout --preserve-status -k $timeout $timeout $pythonv quoteCollector.py"
    exec_test "${cmd}"
    ex_res=$?
    test_result_collector[$test_index-1]=$ex_res
    print_critical_testcase "$msg" $ex_res "We cannot continue if no quotes were collected"

    msg="quotes.json was created"
    cmd="[ -e quotes.json ]"
    exec_test "${cmd}"
    ex_res=$?
    test_result_collector[$test_index-1]=$ex_res
    print_critical_testcase "$msg" $ex_res "We cannot continue without the quotes.json file"

    msg="Number of collected quotes equals 31"
    cmd="cat quotes.json | $pythonv -c \"import sys, json; print (len(json.load(sys.stdin)))\" | grep 31"
    exec_test "${cmd}"
    ex_res=$?
    test_result_collector[$test_index-1]=$ex_res
    print_test_case "$msg" $ex_res 5

    kill -9 $pid_mon 
    wait $pid_mon 2>/dev/null
    msg="Program established connections with QOTD servers"
    cmd="cat $tmpout | grep :17"
    exec_test "${cmd}"
    ex_res=$?
    test_result_collector[$test_index-1]=$ex_res
    print_test_case "$msg" $ex_res 15
    rm -f $tmpout
    
    grade_collector=$grade
    grade=0;

}

### QUESTION 7
function test_server()
{
    test_index=0;
    test_result_server=(0 0 0 0 0)

    print_headers "quoteServer.py"

    $pythonv quoteServer.py > /dev/null & 
    pid_server=$!
    sleep $processing_timeout

    msg="Server executed and listening"
    cmd="netstat -lt | grep :$group_port"
    exec_test "${cmd}"
    ex_res=$?
    test_result_server[$test_index-1]=$ex_res
    print_test_case "$msg" $ex_res

    if [ $ex_res != 0 ]
    then
        echo -e "\e[91mAborting: server failed to run in specified port\e[39m"
        kill -9 $pid_server
        exit 1
    fi

    msg="Test connection"
    cmd="nc -w 5 localhost $group_port"
    exec_test "${cmd}" $pid_server "$msg"
    ex_res=$?
    test_result_server[$test_index-1]=$ex_res
    print_test_case "$msg" $ex_res 10

    quote=`nc -w 5 localhost $group_port`

    let "test_index++"
    msg="Test quote format - Contains only ASCII printable chars"
    echo $quote | grep -v -P -n '[^\x00-\x7F]' > /dev/null
    ex_res=$?
    test_result_server[$test_index-1]=$ex_res
    print_test_case "$msg" $ex_res 3

    msg="Test quote format - smaller than 512 characters"
    cmd="[ `echo $quote | wc -m` -lt 512 ]"
    exec_test "${cmd}" $pid_server "$msg"
    ex_res=$?
    test_result_server[$test_index-1]=$ex_res
    print_test_case "$msg" $ex_res 2

    quote1=`nc -w 5 localhost $group_port | sha256sum | cut -f1 -d" "`
    quote2=`nc -w 5 localhost $group_port | sha256sum | cut -f1 -d" "`
    cmd="[ "$quote1" != "$quote2" ]"
    msg="Offers changing quotes"
    exec_test "${cmd}" $pid_server "$msg"
    ex_res=$?
    test_result_server[$test_index-1]=$ex_res
    print_test_case "$msg" $ex_res 5

    grade_server=$grade
    grade=0

    kill -9 $pid_server
    wait $pid_server 2>/dev/null
}

function test_custom_server()
{

    test_index=0
    test_result_custom_server=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)

    print_headers "customServer.py"

    $pythonv customServer.py > /dev/null & 
    pid_server=$!
    sleep $processing_timeout
    
    err_str="{\"res\":\"KO\"}"
    ok_str="{\"res\":\"OK\"}"
    
    msg="Server executed and listening"
    cmd="netstat -lt | grep :$group_port"
    exec_test "${cmd}"
    ex_res=$?
    test_result_custom_server[$test_index-1]=$ex_res
    print_test_case "$msg" $ex_res

    if [ $ex_res != 0 ]
    then
        echo -e "\e[91mAborting: server failed to run in specified port\e[39m"
        kill -9 $pid_server
        exit 1
    fi

    msg="Wrong Operation {\"op\":\"put\", \"mode\":\"random\"}"
    quote=`echo "{\"op\":\"put\", \"mode\":\"random\"}" | nc -w 5 localhost $group_port`
    quote=`echo $quote | sed 's/ //g'`
    cmd="[ '$quote' == '$err_str' ]"
    exec_test "${cmd}" $pid_server "$msg"
    ex_res=$?
    test_result_custom_server[$test_index-1]=$ex_res
    print_test_case "$msg" $ex_res 1

    msg="Valid operation with no mode {\"op\":\"get\"}"
    quote=`echo "{\"op\":\"get\"}" | nc -w 5 localhost $group_port`
    quote=`echo $quote | sed 's/ //g'`
    cmd="[ '$quote' == '$err_str' ]"
    exec_test "${cmd}" $pid_server "$msg"
    ex_res=$?
    test_result_custom_server[$test_index-1]=$ex_res
    print_test_case "$msg" $ex_res 1 

    msg="Random mode {\"op\":\"get\", \"mode\":\"random\"} - Check Format:"
    quote=`echo "{\"op\":\"get\", \"mode\":\"random\"}" | nc -w 5 localhost $group_port`
    cmd="[ `echo $quote | wc -m` -gt 10 ] &&  [ `echo $quote | wc -m` -lt 512 ]"
    exec_test "${cmd}" $pid_server "$msg"
    ex_res=$?
    test_result_custom_server[$test_index-1]=$ex_res
    print_test_case "$msg" $ex_res 1

    quote1=`echo $quote | sha256sum | cut -f1 -d" "`
    quote2=`echo "{\"op\":\"get\", \"mode\":\"random\"}" | nc -w 5 localhost $group_port | sha256sum | cut -f1 -d" "`
    cmd="[ "$quote1" != "$quote2" ]"
    msg="Random mode {\"op\":\"get\", \"mode\":\"random\"} - Changing quotes"
    exec_test "${cmd}" $pid_server "$msg"
    ex_res=$?
    test_result_custom_server[$test_index-1]=$ex_res
    print_test_case "$msg" $ex_res 3

    msg="Day mode {\"op\":\"get\", \"mode\":\"day\"} - Check Format:"
    quote=`echo "{\"op\":\"get\", \"mode\":\"day\"}" | nc -w 5 localhost $group_port`
    cmd="[ `echo $quote | wc -m` -gt 10 ] &&  [ `echo $quote | wc -m` -lt 512 ]"
    exec_test "${cmd}" $pid_server "$msg"
    ex_res=$?
    test_result_custom_server[$test_index-1]=$ex_res
    print_test_case "$msg" $ex_res 1

    quote1=`echo "{\"op\":\"get\", \"mode\":\"day\"}" | nc -w 5 localhost $group_port | sha256sum | cut -f1 -d" "`
    quote2=`echo "{\"op\":\"get\", \"mode\":\"day\"}" | nc -w 5 localhost $group_port | sha256sum | cut -f1 -d" "`
    cmd="[ "$quote1" == "$quote2" ]"
    msg="Day mode {\"op\":\"get\", \"mode\":\"day\"} - Unchanging quotes"
    exec_test "${cmd}" $pid_server "$msg"
    ex_res=$?
    test_result_custom_server[$test_index-1]=$ex_res
    print_test_case "$msg" $ex_res 3

    msg="Index mode {\"op\":\"get\", \"mode\":\"index\", \"index\":1} - Check Format:"
    quote=`echo "{\"op\":\"get\", \"mode\":\"index\", \"index\":1}" | nc -w 5 localhost $group_port`
    cmd="[ `echo $quote | wc -m` -gt 10 ] &&  [ `echo $quote | wc -m` -lt 512 ]"
    exec_test "${cmd}" $pid_server "$msg"
    ex_res=$?
    test_result_custom_server[$test_index-1]=$ex_res
    print_test_case "$msg" $ex_res 1

    quote1=`echo "{\"op\":\"get\", \"mode\":\"index\", \"index\":1}" | nc -w 5 localhost $group_port | sha256sum | cut -f1 -d" "`
    quote2=`echo "{\"op\":\"get\", \"mode\":\"index\", \"index\":1}" | nc -w 5 localhost $group_port | sha256sum | cut -f1 -d" "`
    quote3=`echo "{\"op\":\"get\", \"mode\":\"index\", \"index\":2}" | nc -w 5 localhost $group_port | sha256sum | cut -f1 -d" "`
    cmd="[ "$quote1" == "$quote2" ] && [ "$quote1" != "$quote3" ]"
    msg="Index mode - Proper Indexing"
    exec_test "${cmd}" $pid_server "$msg"
    ex_res=$?
    test_result_custom_server[$test_index-1]=$ex_res
    print_test_case "$msg" $ex_res 3

    quote=`echo "{\"op\":\"get\", \"mode\":\"index\", \"index\":\"1\"}" | nc -w 5 localhost $group_port | sha256sum | cut -f1 -d" "`
    quote=`echo $quote | sed 's/ //g'`
    msg="Index mode - {\"op\":\"get\", \"mode\":\"index\", \"index\":\"1\"} - Non-numeric JSON index: "
    cmd="[ '$quote' == '$err_str' ]"
    exec_test "${cmd}" $pid_server "$msg"
    ex_res=$?
    test_result_custom_server[$test_index-1]=$ex_res
    print_test_case "$msg" $ex_res  1
    
    msg="Index mode {\"op\":\"get\", \"mode\":\"index\", \"index\":100} - Out of bounds"
    quote=`echo "{\"op\":\"get\", \"mode\":\"index\", \"index\":100}" | nc -w 5 localhost $group_port`
    quote=`echo $quote | sed 's/ //g'`
    cmd="[ '$quote' == '$err_str' ]"
    exec_test "${cmd}" $pid_server "$msg"
    ex_res=$?
    test_result_custom_server[$test_index-1]=$ex_res
    print_test_case "$msg" $ex_res 2
   
    msg="Valid operation - wrong mode {\"op\":\"get\", \"mode\":\"wrong\"}"
    quote=`echo "{\"op\":\"get\", \"mode\":\"wrong\"}" | nc -w 5 localhost $group_port`
    quote=`echo $quote | sed 's/ //g'`
    cmd="[ '$quote' == '$err_str' ]"
    exec_test "${cmd}" $pid_server "$msg"
    ex_res=$?
    test_result_custom_server[$test_index-1]=$ex_res
    print_test_case "$msg" $ex_res 1
    
    msg="Count operation {\"op\":\"count\"}"
    count_val=`echo "{\"op\":\"count\"}" | nc -w 5 localhost $group_port`
    cmd="[[ $count_val =~ ^[0-9]+$ ]]"
    exec_test "${cmd}" $pid_server "$msg"
    ex_res=$?
    test_result_custom_server[$test_index-1]=$ex_res
    print_test_case "$msg" $ex_res 3

    if [ $ex_res -eq 0 ]
    then
        let "count_val++"
    fi
    
    msg="Add operation {\"op\":\"add\", \"quote\":\"Text de la cita\"}"
    quote=`echo "{\"op\":\"add\", \"quote\":\"Text de la cita\"}" | nc -w 5 localhost $group_port`
    quote=`echo $quote | sed 's/ //g'`
    cmd="[ '$quote' == '$ok_str' ]"
    exec_test "${cmd}" $pid_server "$msg"
    ex_res=$?
    test_result_custom_server[$test_index-1]=$ex_res
    print_test_case "$msg" $ex_res 3
    
    msg="Count after addition (should be +1)"
    new_count=`echo "{\"op\":\"count\"}" | nc -w 5 localhost $group_port`
    cmd="[[ $new_count =~ ^[0-9]+$ ]] && [ $new_count -eq $count_val ]"
    exec_test "${cmd}" $pid_server "$msg"
    ex_res=$?
    test_result_custom_server[$test_index-1]=$ex_res
    print_test_case "$msg" $ex_res 3
    
    msg="Adding repeated should fail"
    quote=`echo "{\"op\":\"add\", \"quote\":\"Text de la cita\"}" | nc -w 5 localhost $group_port`
    quote=`echo $quote | sed 's/ //g'`
    cmd="[ '$quote' == '$err_str' ]"
    exec_test "${cmd}" $pid_server "$msg"
    ex_res=$?
    test_result_custom_server[$test_index-1]=$ex_res
    print_test_case "$msg" $ex_res 3

    grade_custom_server=$grade
    grade=0

    kill -9 $pid_server
    wait $pid_server 2>/dev/null
}

function test_custom_client()
{
   test_index=0;
   test_result_custom_client=(0 0 0 0 0 0 0 0)

   print_headers "customClient.py"

   tmpout="$(mktemp)"
   timeout -k $short_timeout $short_timeout bash -c -- 'while true; do echo "" | nc -l $1 >> $0; done' $tmpout $group_port & 2>/dev/null  

   sz_msg=`echo "{\"op\":\"get\",\"mode\":\"random\"}" | wc -m`
   timeout $processing_timeout $pythonv customClient.py -op get -mode random > /dev/null

   cmp=`tail -n 1 $tmpout | sed 's/ //g' | grep "\"op\":\"get\"" | grep "\"mode\":\"random\""  | wc -l`
   cnt=`tail -n 1 $tmpout | sed 's/ //g' | grep "\"mode\":\"random\"" | wc -m`   
   cmd="[ $cmp -eq 1 ] && [ $cnt -eq $sz_msg ]" 
   msg="Get mode random: customClient.py -op get -mode random"
   exec_test "${cmd}"
   ex_res=$?
   test_result_custom_client[$test_index-1]=$ex_res
   print_test_case "$msg" $ex_res 2
   echo "" >> $tmpout

   sz_msg=`echo "{\"op\":\"get\",\"mode\":\"random\"}" | wc -m`
   timeout $processing_timeout $pythonv customClient.py -mode random -op get > /dev/null

   cmp=`tail -n 1 $tmpout | sed 's/ //g' | grep "\"op\":\"get\"" | grep "\"mode\":\"random\""  | wc -l`
   cnt=`tail -n 1 $tmpout | sed 's/ //g' | grep "\"mode\":\"random\"" | wc -m`   
   cmd="[ $cmp -eq 1 ] && [ $cnt -eq $sz_msg ]" 
   msg="Shuffle parameters mode random: customClient.py -mode random -op get"
   exec_test "${cmd}"
   ex_res=$?
   test_result_custom_client[$test_index-1]=$ex_res
   print_test_case "$msg" $ex_res 1
   echo "" >> $tmpout

   sz_msg=`echo "{\"op\":\"get\",\"mode\":\"day\"}" | wc -m`;
   timeout $processing_timeout $pythonv customClient.py -op get -mode day > /dev/null
   cmp=`tail -n 1 $tmpout | sed 's/ //g' | grep "\"op\":\"get\"" | grep "\"mode\":\"day\"" | wc -l`
   cnt=`tail -n 1 $tmpout | sed 's/ //g' | grep "\"mode\":\"day\"" | wc -m`   
   cmd="[ $cmp -eq 1 ] && [ $cnt -eq $sz_msg ]" 
   msg="Get mode day: customClient.py -op get -mode day"
   exec_test "${cmd}"
   ex_res=$?
   test_result_custom_client[$test_index-1]=$ex_res
   print_test_case "$msg" $ex_res 2
   echo "" >> $tmpout

   # index may be a numeric json-type or a string
   sz_msg=`echo "{\"op\":\"get\",\"mode\":\"index\",\"index\":1}" | wc -m`;
   sz_msg_str=`echo "{\"op\":\"get\",\"mode\":\"index\",\"index\":\"1\"}" | wc -m`;
   timeout $processing_timeout $pythonv customClient.py -op get -mode index -index 1 > /dev/null
   cmp=`tail -n 1 $tmpout | sed 's/ //g' | grep "\"op\":\"get\"" | grep "\"mode\":\"index\"" | grep "\"index\":1" | wc -l`
   cmp_str=`tail -n 1 $tmpout | sed 's/ //g' | grep "\"op\":\"get\"" | grep "\"mode\":\"index\"" | grep "\"index\":\"1\"" | wc -l`
   cnt=`tail -n 1 $tmpout | sed 's/ //g' | grep "\"mode\":\"index\"" | wc -m`
   cmd="([ $cmp -eq 1 ] && [ $cnt -eq $sz_msg ]) || ([ $cmp_str -eq 1 ] && [ $cnt -eq $sz_msg_str ])"
   msg="Get mode index: customClient.py -op get -mode index -index 1"
   exec_test "${cmd}"
   ex_res=$?
   test_result_custom_client[$test_index-1]=$ex_res
   print_test_case "$msg" $ex_res 2
   echo "" >> $tmpout

   # index must be a numeric json-type
   timeout $processing_timeout $pythonv customClient.py -op get -mode index -index 1 > /dev/null
   cmp=`tail -n 1 $tmpout | sed 's/ //g' | grep "\"op\":\"get\"" | grep "\"mode\":\"index\"" | grep "\"index\":1" | wc -l`
   cnt=`tail -n 1 $tmpout | sed 's/ //g' | grep "\"mode\":\"index\"" | wc -m`
   cmd="[ $cmp -eq 1 ] && [ $cnt -eq $sz_msg ]"
   msg="Get mode index: customClient.py -op get -mode index -index 1 (index value must be numeric JSON-type)"
   exec_test "${cmd}"
   ex_res=$?
   test_result_custom_client[$test_index-1]=$ex_res
   print_test_case "$msg" $ex_res 2
   echo "" >> $tmpout

   sz_msg=`echo "{\"op\":\"count\"}" | wc -m`;
   timeout $processing_timeout $pythonv customClient.py -op count > /dev/null
   cnt=`tail -n 1 $tmpout | sed 's/ //g' | grep "{\"op\":\"count\"}" | wc -m`
   cmd="[ $cnt -eq $sz_msg ]"
   msg="Op count: -op count"
   exec_test "${cmd}"
   ex_res=$?
   test_result_custom_client[$test_index-1]=$ex_res
   print_test_case "$msg" $ex_res 2
   echo "" >> $tmpout 

   sz_msg=`echo "{\"op\":\"add\",\"quote\":\"TesterQuote.\"}" | wc -m`;
   timeout $processing_timeout $pythonv customClient.py -op add -quote "TesterQuote." > /dev/null
   cnt=`tail -n 1 $tmpout | sed 's/ //g' | grep "\"op\":\"add\"" | wc -m`
   cmd="[ $cnt -eq $sz_msg ]"
   msg="Op add: -op add -quote \"TesterQuote.\""
   exec_test "${cmd}"
   ex_res=$?
   test_result_custom_client[$test_index-1]=$ex_res
   print_test_case "$msg" $ex_res 3
   echo "" >> $tmpout 

   sz_msg=`echo "{\"op\":\"add\",\"quote\":\"TesterQuote.\"}" | wc -m`;
   timeout $processing_timeout $pythonv customClient.py -op add -quote TesterQuote. > /dev/null
   cnt=`tail -n 1 $tmpout | sed 's/ //g' | grep "\"op\":\"add\"" | wc -m`
   cmd="[ $cnt -eq $sz_msg ]"
   msg="Op add (quote not surrrounded by quotes \"\" is OK too): -op add -quote TesterQuote."
   exec_test "${cmd}"
   ex_res=$?
   test_result_custom_client[$test_index-1]=$ex_res
   print_test_case "$msg" $ex_res 1
   echo "" >> $tmpout 

   grade_custom_client=$grade
   grade=0

   pid_server=`ps aux | grep "nc -l \$1"  | grep -v grep | awk '{print $2}'`
   kill -9 $pid_server
   wait $pid_server 2>/dev/null
}



cmd_line_settings "$@"
user_settings
init
[ $collector_test -eq 1 ] && test_collector
[ $server_test -eq 1 ] && check_network && test_server
sleep $processing_timeout
[ $custom_server_test -eq 1 ] && check_network && test_custom_server 
sleep $processing_timeout
[ $custom_client_test -eq 1 ] && check_network && test_custom_client
[ $display_grading -eq 1 ] && display_grades
[ $all_tests -eq 1 ] && check_test_conformance
