#!/bin/bash
cat $1 | grep "begin{exer}" | sed 's/\\begin{exer}//g' | sed 's/\\end{exer}//g' | sed 's/\\item//g' | grep -v ^% | sed 's/^ *//g' | sed 's/\\textbf//g' | sed '/^[[:space:]]*$/d' | nl > $2
