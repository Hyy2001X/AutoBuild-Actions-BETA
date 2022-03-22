#!/bin/bash

coremark > /tmp/coremark.log
Scores=$(cat /tmp/coremark.log 2> /dev/null | grep "CoreMark 1.0" | awk '{print $4}')
Processer=$(awk -F ':[ ]' '/model name/{printf ($2);exit}' /proc/cpuinfo)

[[ -n ${Processer} ]] && echo -e "\nProcesser: ${Processer}"
echo -e "Score: ${Scores}\nTime costs: $(grep "Total time" /tmp/coremark.log | awk '{print $4}')"
echo "(CPU Mark: ${Scores} Scores)" > /etc/bench.log

if [ -f /etc/bench.log ]; then
	sed -i '/coremark/d' /etc/crontabs/root
	crontab /etc/crontabs/root
fi
