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
group_port=8999
tcp_fin_timeout=`cat /proc/sys/net/ipv4/tcp_fin_timeout`
grade=0


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
    print_headers "Network"

    cmd="[ `netstat -lt | grep :$group_port | wc -l` -eq 0 ]"
    msg="Listening port is not in use"
    exec_test "${cmd}"
    ex=$?
    print_test_case "$msg" $ex 0 "warn"

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
    print_test_case "$msg" $ex 0 "warn"
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
    
    [ $2 -eq 0 ] && res="\e[32mOK\e[39m" && grade $3
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
 
 if [ -e quotes.json ]
 then
    cmd="mv -f quotes.json quotes.json.bk"
    msg="Removing quotes.json (backup has been stored in quotes.json.bk)"
    exec_test "${cmd}"
    print_test_case "$msg" $? 
 fi 
  
 check_deppends
 check_network 
}

### QUESTION 6
function test6()
{

    test_index=0;
    print_headers "quoteCollector.py"

    tmpout="$(mktemp)"
    # Launch monitor
    timeout $timeout bash -c -- 'while true; do netstat -tn | grep :17 >> $0; sleep 1; done' $tmpout & 2>/dev/null
    pid_mon=$!

    msg="Proper execution and termination"
    cmd="timeout --preserve-status -k $timeout $timeout python quoteCollector.py"
    exec_test "${cmd}"
    print_critical_testcase "$msg" $? "We cannot continue if no quotes were collected"
    
    msg="quotes.json was created"
    cmd="[ -e quotes.json ]"
    exec_test "${cmd}"
    print_critical_testcase "$msg" $? "We cannot continue without the quotes.json file"
    

    msg="Number of collected quotes equals 31"
    cmd="cat quotes.json | python -c \"import sys, json; print (len(json.load(sys.stdin)))\" | grep 31"
    exec_test "${cmd}"
    print_test_case "$msg" $? 5
    

    kill -9 $pid_mon 
    wait $pid_mon 2>/dev/null
    msg="Program established connections with QOTD servers"
    cmd="cat $tmpout | grep :17"
    exec_test "${cmd}"
    print_test_case "$msg" $? 15
    rm -f $tmpout
    
    echo "Grade: $grade"

}

### QUESTION 7
function test7()
{
    test_index=0;
    print_headers "quoteServer.py"

    python quoteServer.py > /dev/null & 
    pid_server=$!
    sleep $processing_timeout

    msg="Server executed and listening"
    cmd="netstat -lt | grep :$group_port"
    exec_test "${cmd}"
    ex_res=$?
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
    print_test_case "$msg" $? 10    
    
    quote=`nc -w 5 localhost $group_port`
    
    let "test_index++"
    msg="Test quote format - Contains only ASCII printable chars"
    echo $quote | grep -v -P -n '[^\x00-\x7F]' > /dev/null
    print_test_case "$msg" $? 3
    
    msg="Test quote format - smaller than 512 characters"
    cmd="[ `echo $quote | wc -m` -lt 512 ]"
    exec_test "${cmd}" $pid_server "$msg"
    print_test_case "$msg" $? 2
    
    quote1=`nc -w 5 localhost $group_port | sha256sum | cut -f1 -d" "`
    quote2=`nc -w 5 localhost $group_port | sha256sum | cut -f1 -d" "`
    cmd="[ "$quote1" != "$quote2" ]"
    msg="Offers changing quotes"
    exec_test "${cmd}" $pid_server "$msg"
    print_test_case "$msg" $? 5
    
    echo "Grade: $grade"       
    kill -9 $pid_server
    wait $pid_server 2>/dev/null
}

function test8()
{
    
    test_index=0
    print_headers "customServer.py"

    python3 customServer.py > /dev/null & 
    pid_server=$!
    sleep $processing_timeout    
    
    err_str="{\"res\":\"KO\"}"
    ok_str="{\"res\":\"OK\"}"
    
    msg="Server executed and listening"
    cmd="netstat -lt | grep :$group_port"
    exec_test "${cmd}"
    ex_res=$?
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
    print_test_case "$msg" $? 1
    
    
    msg="Valid operation with no mode {\"op\":\"get\"}"
    quote=`echo "{\"op\":\"get\"}" | nc -w 5 localhost $group_port`
    quote=`echo $quote | sed 's/ //g'`
    cmd="[ '$quote' == '$err_str' ]"
    exec_test "${cmd}" $pid_server "$msg"
    print_test_case "$msg" $? 1 
    
    msg="Random mode {\"op\":\"get\", \"mode\":\"random\"} - Check Format:"
    quote=`echo "{\"op\":\"get\", \"mode\":\"random\"}" | nc -w 5 localhost $group_port`
    cmd="[ `echo $quote | wc -m` -gt 10 ] &&  [ `echo $quote | wc -m` -lt 512 ]"
    exec_test "${cmd}" $pid_server "$msg"
    print_test_case "$msg" $res 1
    
    quote1=`echo $quote | sha256sum | cut -f1 -d" "`
    quote2=`echo "{\"op\":\"get\", \"mode\":\"random\"}" | nc -w 5 localhost $group_port | sha256sum | cut -f1 -d" "`
    cmd="[ "$quote1" != "$quote2" ]"
    msg="Random mode {\"op\":\"get\", \"mode\":\"random\"} - Changing quotes"
    exec_test "${cmd}" $pid_server "$msg"
    print_test_case "$msg" $? 3
    
    msg="Day mode {\"op\":\"get\", \"mode\":\"day\"} - Check Format:"
    quote=`echo "{\"op\":\"get\", \"mode\":\"day\"}" | nc -w 5 localhost $group_port`
    cmd="[ `echo $quote | wc -m` -gt 10 ] &&  [ `echo $quote | wc -m` -lt 512 ]"
    exec_test "${cmd}" $pid_server "$msg"
    print_test_case "$msg" $res 1
    
 
    quote1=`echo "{\"op\":\"get\", \"mode\":\"day\"}" | nc -w 5 localhost $group_port | sha256sum | cut -f1 -d" "`
    quote2=`echo "{\"op\":\"get\", \"mode\":\"day\"}" | nc -w 5 localhost $group_port | sha256sum | cut -f1 -d" "`
    cmd="[ "$quote1" == "$quote2" ]"
    msg="Day mode {\"op\":\"get\", \"mode\":\"day\"} - Unchanging quotes"
    exec_test "${cmd}" $pid_server "$msg"
    print_test_case "$msg" $? 3
    
    msg="Index mode {\"op\":\"get\", \"mode\":\"index\", \"index\":1} - Check Format:"
    quote=`echo "{\"op\":\"get\", \"mode\":\"index\", \"index\":1}" | nc -w 5 localhost $group_port`
    cmd="[ `echo $quote | wc -m` -gt 10 ] &&  [ `echo $quote | wc -m` -lt 512 ]"
    exec_test "${cmd}" $pid_server "$msg"
    print_test_case "$msg" $res 1
    
    quote1=`echo "{\"op\":\"get\", \"mode\":\"index\", \"index\":1}" | nc -w 5 localhost $group_port | sha256sum | cut -f1 -d" "`
    quote2=`echo "{\"op\":\"get\", \"mode\":\"index\", \"index\":1}" | nc -w 5 localhost $group_port | sha256sum | cut -f1 -d" "`
    quote3=`echo "{\"op\":\"get\", \"mode\":\"index\", \"index\":2}" | nc -w 5 localhost $group_port | sha256sum | cut -f1 -d" "`
    cmd="[ "$quote1" == "$quote2" ] && [ "$quote1" != "$quote3" ]"
    msg="Index mode - Proper Indexing"
    exec_test "${cmd}" $pid_server "$msg"
    print_test_case "$msg" $? 3
    
    
    quote=`echo "{\"op\":\"get\", \"mode\":\"index\", \"index\":\"1\"}" | nc -w 5 localhost $group_port | sha256sum | cut -f1 -d" "`
    quote=`echo $quote | sed 's/ //g'`
    msg="Index mode - {\"op\":\"get\", \"mode\":\"index\", \"index\":\"1\"} - Non-numeric JSON index: "
    cmd="[ '$quote' == '$err_str' ]"
    exec_test "${cmd}" $pid_server "$msg"
    print_test_case "$msg" $?  1
    
    msg="Index mode {\"op\":\"get\", \"mode\":\"index\", \"index\":100} - Out of bounds"
    quote=`echo "{\"op\":\"get\", \"mode\":\"index\", \"index\":100}" | nc -w 5 localhost $group_port`
    quote=`echo $quote | sed 's/ //g'`
    cmd="[ '$quote' == '$err_str' ]"
    exec_test "${cmd}" $pid_server "$msg"
    print_test_case "$msg" $? 2
   
    msg="Valid operation - wrong mode {\"op\":\"get\", \"mode\":\"wrong\"}"
    quote=`echo "{\"op\":\"get\", \"mode\":\"wrong\"}" | nc -w 5 localhost $group_port`
    quote=`echo $quote | sed 's/ //g'`
    cmd="[ '$quote' == '$err_str' ]"
    exec_test "${cmd}" $pid_server "$msg"
    print_test_case "$msg" $? 1
    
    msg="Count operation {\"op\":\"count\"}"
    count_val=`echo "{\"op\":\"count\"}" | nc -w 5 localhost $group_port`
    cmd="[[ $count_val =~ ^[0-9]+$ ]]"
    exec_test "${cmd}" $pid_server "$msg"
    r=$?
    print_test_case "$msg" $r 3

    if [ $r == 0 ]
    then
        let "count_val++"
    fi
    
    msg="Add operation {\"op\":\"add\", \"quote\":\"Text de la cita\"}"
    quote=`echo "{\"op\":\"add\", \"quote\":\"Text de la cita\"}" | nc -w 5 localhost $group_port`
    quote=`echo $quote | sed 's/ //g'`
    cmd="[ '$quote' == '$ok_str' ]"
    exec_test "${cmd}" $pid_server "$msg"
    print_test_case "$msg" $? 3
    
    msg="Count after addition (should be +1)"
    new_count=`echo "{\"op\":\"count\"}" | nc -w 5 localhost $group_port`
    cmd="[[ $new_count =~ ^[0-9]+$ ]] && [ $new_count -eq $count_val ]"
    exec_test "${cmd}" $pid_server "$msg"
    rest=$?
    print_test_case "$msg" $res 3
    
    msg="Adding repeated should fail"
    quote=`echo "{\"op\":\"add\", \"quote\":\"Text de la cita\"}" | nc -w 5 localhost $group_port`
    quote=`echo $quote | sed 's/ //g'`
    cmd="[ '$quote' == '$err_str' ]"
    exec_test "${cmd}" $pid_server "$msg"
    print_test_case "$msg" $? 3
    
    echo "Grade: $grade"    
    kill -9 $pid_server
    wait $pid_server 2>/dev/null
}

function test9()
{
   test_index=0;
   print_headers "customClient.py"
   
   tmpout="$(mktemp)"
   timeout -k $short_timeout $short_timeout bash -c -- 'while true; do echo "" | nc -l $1 >> $0; done' $tmpout $group_port & 2>/dev/null  
   
   sz_msg=`echo "{\"op\":\"get\",\"mode\":\"random\"}" | wc -m`
   timeout $processing_timeout python customClient.py -op get -mode random > /dev/null
   
   cmp=`tail -n 1 $tmpout | sed 's/ //g' | grep "\"op\":\"get\"" | grep "\"mode\":\"random\""  | wc -l`
   cnt=`tail -n 1 $tmpout | sed 's/ //g' | grep "\"mode\":\"random\"" | wc -m`   
   cmd="[ $cmp -eq 1 ] && [ $cnt -eq $sz_msg ]" 
   msg="Get mode random: customClient.py -op get -mode random"
   exec_test "${cmd}"
   print_test_case "$msg" $? 3
   echo "" >> $tmpout
   
   sz_msg=`echo "{\"op\":\"get\",\"mode\":\"random\"}" | wc -m`
   timeout $processing_timeout python customClient.py -mode random -op get > /dev/null
      
   cmp=`tail -n 1 $tmpout | sed 's/ //g' | grep "\"op\":\"get\"" | grep "\"mode\":\"random\""  | wc -l`
   cnt=`tail -n 1 $tmpout | sed 's/ //g' | grep "\"mode\":\"random\"" | wc -m`   
   cmd="[ $cmp -eq 1 ] && [ $cnt -eq $sz_msg ]" 
   msg="Shuffle parameters mode random: customClient.py -mode random -op get"
   exec_test "${cmd}"
   print_test_case "$msg" $? 1
   echo "" >> $tmpout
   
   sz_msg=`echo "{\"op\":\"get\",\"mode\":\"day\"}" | wc -m`;
   timeout $processing_timeout python customClient.py -op get -mode day > /dev/null
   cmp=`tail -n 1 $tmpout | sed 's/ //g' | grep "\"op\":\"get\"" | grep "\"mode\":\"day\"" | wc -l`
   cnt=`tail -n 1 $tmpout | sed 's/ //g' | grep "\"mode\":\"day\"" | wc -m`   
   cmd="[ $cmp -eq 1 ] && [ $cnt -eq $sz_msg ]" 
   msg="Get mode day: customClient.py -op get -mode day"
   exec_test "${cmd}"
   print_test_case "$msg" $? 2
   echo "" >> $tmpout
   
   # index must be a numeric json-type 
   sz_msg=`echo "{\"op\":\"get\",\"mode\":\"index\",\"index\":1}" | wc -m`;
   timeout $processing_timeout python customClient.py -op get -mode index -index 1 > /dev/null
   cmp=`tail -n 1 $tmpout | sed 's/ //g' | grep "\"op\":\"get\"" | grep "\"mode\":\"index\"" | grep "\"index\":1" | wc -l`
   cnt=`tail -n 1 $tmpout | sed 's/ //g' | grep "\"mode\":\"index\"" | wc -m`  
   cmd="[ $cmp -eq 1 ] && [ $cnt -eq $sz_msg ]"
   msg="Get mode index: customClient.py -op get -mode index -index 1"
   exec_test "${cmd}"
   print_test_case "$msg" $? 3
   echo "" >> $tmpout
      
   sz_msg=`echo "{\"op\":\"count\"}" | wc -m`;
   timeout $processing_timeout python customClient.py -op count > /dev/null
   cnt=`tail -n 1 $tmpout | sed 's/ //g' | grep "{\"op\":\"count\"}" | wc -m`
   cmd="[ $cnt -eq $sz_msg ]"
   msg="Op count: -op count"
   exec_test "${cmd}"
   print_test_case "$msg" $? 2
   echo "" >> $tmpout 
   
   sz_msg=`echo "{\"op\":\"add\",\"quote\":\"TesterQuote.\"}" | wc -m`;
   timeout $processing_timeout python customClient.py -op add -quote "TesterQuote." > /dev/null
   cnt=`tail -n 1 $tmpout | sed 's/ //g' | grep "\"op\":\"add\"" | wc -m`
   cmd="[ $cnt -eq $sz_msg ]"
   msg="Op add: -op add -quote \"TesterQuote.\""
   exec_test "${cmd}"
   print_test_case "$msg" $? 3
   echo "" >> $tmpout 
   
   sz_msg=`echo "{\"op\":\"add\",\"quote\":\"TesterQuote.\"}" | wc -m`;
   timeout $processing_timeout python customClient.py -op add -quote TesterQuote. > /dev/null
   cnt=`tail -n 1 $tmpout | sed 's/ //g' | grep "\"op\":\"add\"" | wc -m`
   cmd="[ $cnt -eq $sz_msg ]"
   msg="Op add (quote not surrrounded by quotes \"\" is OK too): -op add -quote TesterQuote."
   exec_test "${cmd}"
   print_test_case "$msg" $? 1
   echo "" >> $tmpout 
     
       echo "Grade: $grade"   
   pid_server=`ps aux | grep "nc -l \$1"  | grep -v grep | awk '{print $2}'`
   kill -9 $pid_server
   wait $pid_server 2>/dev/null
}

echo "Type your group's corresponding port number and press [ENTER]"
echo "(for instance, if your were x-c11 then: grup C 3, port= 8000 + 100 * 3 + 11 = 8311)"
echo -n "Port number: " 
read group_port

init
test6
test7
sleep $processing_timeout
check_network
test8
sleep $processing_timeout
check_network
test9