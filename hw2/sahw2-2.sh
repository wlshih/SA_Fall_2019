#! /usr/local/bin/bash

# System Info Monitor by Waylon Shih

# Define the dialog exit status codes
: ${DIALOG_OK=0}
: ${DIALOG_CANCEL=1}
: ${DIALOG_HELP=2}
: ${DIALOG_EXTRA=3}
: ${DIALOG_ITEM_HELP=4}
: ${DIALOG_ESC=255}

# Temp files
TMP="/tmp/.sahw2.tmp"
CPU="/tmp/.cpu.sahw2.tmp"
MEM="/tmp/.mem.sahw2.tmp"
NET="/tmp/.net.sahw2.tmp"
FILE="/tmp/.file.sahw2.tmp"



cpuInfo() {
	sysctl hw.model | awk '{ print "CPU model: " $2 }' > $TMP
	sysctl hw.machine | awk '{ print "CPU machine: " $2 }' >> $TMP
	sysctl hw.ncpu | awk '{ print "CPU core: " $2 }' >> $TMP

	stty intr ^M
	
	while true; do
		cat $TMP > $CPU
		printf "\nCPU Loading\n" >> $CPU
		
		top -Pd2 | grep ^CPU | tail -n2 | awk '{ print $1$2" USER: "$3" SYST: "$7" IDLE: "$11 }' >> $CPU

		# calculate percentage and pass to dialog gauge
		declare -i count
		count=$(cat $CPU | wc -l)-5
		tail -n $count $CPU | awk -F'[\ %]' -v cnt=$count '{ idle += $9 } END{ print int(100-idle/cnt)) }' | \
		dialog	--title "CPU INFO" --gauge "$(cat $CPU)" 17 50
		
		# read input, timeout = 0.5 sec.
		read -t 1 -N 1 input
		if [ $? -eq 0 ] && [ -z $input ]; then # if exit status = 0, and input length is zero (-z)
			#mainMenu
			break
		fi
	done

	mainMenu

}

memInfo() {

	while true; do
		total=$(sysctl hw.realmem | awk '{ print $2 }')
		used=$(sysctl hw | egrep '(real|user)mem' | awk '{ if(NR == 2) used += $2; else used -= $2 } END{ print used }')
		free=$(sysctl hw.usermem | awk '{ print $2 }')
	
		echo $total | unitConvert | awk '{ print "Total: "$1" "$2 }' > $TMP
		echo $used | unitConvert | awk '{ print "Used: "$1" "$2 }' >> $TMP
		echo $free | unitConvert |  awk '{ print "Free: "$1" "$2}' >> $TMP

		# calculate progress bar percentage
		percent=$((100*used/total))

		# string handling
		text=$(awk -v ORS='\\n' '1' $TMP)
		#echo $text
	
		echo $percent | dialog	--title "Memory Info and Usage" --gauge "$text" 17 40 
		
		# read input, timeout = 0.5 sec.
		read -t 0.5 -N 1 input
		if [ $? -eq 0 ] && [ -z $input ]; then # if exit status = 0, and input length is zero (-z)
			#mainMenu
			break
		fi
	done

	mainMenu

}

netInfo() {
	
	ifconfig -a | grep -v '^[[:blank:]]' > $TMP
	awk 'BEGIN{ FS=":" } { print $1 " -" }' $TMP > $NET
	dialog	--title "Network Info" --menu "Network Interfaces" 12 35 5\
		$(cat $NET) 2>$TMP

	result=$?
	option=$(cat $TMP)
	
	if [ $result -eq $DIALOG_OK ]; then
		printf "Interface Name: $option\n\n" > $TMP
		ifconfig $option | grep -w inet | awk '{ print "IPv4___: " $2 "\nNetmask: " $4 }' >> $TMP # grep -w --> match whole word
		ifconfig $option | grep -w ether && ifconfig $option | grep -w ether | awk '{ print "Mac____: " $2 }' >> $TMP
		
		dialog --title "$(echo $option)" --msgbox "$(cat $TMP)" 17 40
		result=$?
		
		if [ $result -eq $DIALOG_OK ]; then
			netInfo
		fi
	else
		mainMenu
	fi
	
}

fileBrowser() 
{
	echo file
	# get full path
	path=$(readlink -f $1)
	
	# ls and get MIME type
	cd $path 2> /dev/null
	ls -a | awk '{ printf $1 " "; system("file " $1 " --mime-type -b") }' > $FILE
	dialog	--title "File Browser" --menu "$path" 17 50 12\
		$(cat $FILE) 2>$TMP
	
	result=$?
	option=$(cat $TMP)

	if [ $result -eq $DIALOG_OK ]; then
		dir=$(cat $FILE | grep $option -w | awk '{ if($2 ~ /^inode/) print }')
		echo $dir
		echo $option	
		if [[ ! -z $dir ]]; then
			fileBrowser $option
		else
			fileBrowser_info $option
		fi
	else
		mainMenu
	fi	
			
}

fileBrowser_info() 
{
	printf "<File Name>: $1\n" > $TMP
	printf "<File Info>: $(file $1 -b)\n" >> $TMP 
	ls -l $1 | awk '{ print $5 }' | unitConvert | awk '{ print "<File Size>: " $1 " " $2 }' >> $TMP

	dialog --title "File Browser" --msgbox "$(cat $TMP)" 17 50
	fileBrowser $(readlink -f $(dirname $1))
}

# use pipe to connect input output
unitConvert()
{
	awk '{ 
		size = $1;
		i = 0;
		while(size > 1024) {
			size /= 1024;
			i++;
		}

		if (i == 0) $1 = size" B";
		else if(i == 1) $1 = size" KB";
		else if(i == 2) $1 = size" MB";
		else if(i == 3) $1 = size" GB";
		else $1 = size" TB";

		print;
	}'
}

mainMenu() {
	
	dialog	--title "6666666" --menu "SYS INFO" 12 35 5\
		1 "CPU INFO"\
		2 "MEMORY INFO"\
		3 "NETWORK INFO"\
		4 "FILE BROWSER" 2>$TMP
	result=$?
	option=$(cat $TMP)

	if [ $result -eq $DIALOG_OK ]; then
		if [ $option == "1" ]; then
			cpuInfo
		elif [ $option == "2" ]; then
			memInfo
		elif [ $option == "3" ]; then
			netInfo
		else
			fileBrowser ./
		fi
	else
		exit 0
	fi

}

mainMenu

