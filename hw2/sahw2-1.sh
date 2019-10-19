ls -lAR | egrep "^(d|-)" | sort -k 5 -nr | awk '{ if(NR <= 5) print NR": "$5" "$9; } $1 ~ /^d/{ dir ++; } $1 ~ /^-/{ file ++; tot += $5 } END{ print "Dir num: "dir"\nFile num: "file"\nTotal: "tot; }'
