rm -rf perf.data selected.txt stride stride.txt tmp.txt without-debug
clang++ stride_benchmark.cpp -g -o stride
objdump --dwarf=decodedline stride > stride.txt
awk 'NF>=3 && $2 ~ /^[0-9]+$/{print $1,$2,$3}' stride.txt > tmp.txt
mv tmp.txt stride.txt
cp stride without-debug
strip --strip-debug without-debug
# export PATH=/path/to/pmu-tools:$PATH
taskset -c 0,1 ./without-debug &
toplev.py -l1 --no-desc --core C0 -o tmp.txt sleep 1
val=$(grep Backend_Bound tmp.txt |awk '{print $6}')
if (( $(echo "$val > 9.9" |bc -l) ))
then
  toplev.py -l2 --no-desc --core C0 -o tmp.txt sleep 1
  # Backend_Bound.Memory_Bound
  val=$(grep Backend_Bound.Memory_Bound tmp.txt |awk '{print $6}')
  if (( $(echo "$val > 9.9" |bc -l) ))
  then
    toplev.py -l3 --no-desc --core C0 -o tmp.txt sleep 1
    # Backend_Bound.Memory_Bound.L1_Bound, Backend_Bound.Memory_Bound.L2_Bound, Backend_Bound.Memory_Bound.L3_Bound
    one=$(grep Backend_Bound.Memory_Bound.L1_Bound tmp.txt |awk '{print $6}')
    two=$(grep Backend_Bound.Memory_Bound.L2_Bound tmp.txt |awk '{print $6}')
    three=$(grep Backend_Bound.Memory_Bound.L3_Bound tmp.txt |awk '{print $6}')
    if (( $(echo "$one > 9.9" |bc -l) || $(echo "$two > 9.9" |bc -l) || $(echo "$three > 9.9" |bc -l) ))
    then
      rm -rf perf.data
      perf record -C 0,1 -e mem_load_retired.l1_miss -- sleep 1 # mem_load_retired.l1_miss or mem_load_retired.l3_miss
      perf script -F ip,dso|awk '{a[$1]++;c++;}END{for(i in a)if(a[i]*10>=c)printf "%d 0x%s\n",a[i],i}'|sort -rn|awk '{print $2}' |while read i; do awk -v var="$i" '$3==var{print $1,$2}' stride.txt; done > selected.txt
    fi
  fi
fi