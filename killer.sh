#!/bin/bash

#
#	Killer 1.0
#
#	Small bash script for killing processes.
#
#	Author: Juraj Masar <mail@jurajmasar.com> (30th April 2013)	
#

# prints the usage schema
printUsage () {
	echo "usage: $0 {-v|-h|file_name|regular_expression}"
}

# prints the version
printVersion() {
	echo "Killer 1.0"
}

# prints usage instructions and description
printHelp() {
	printVersion
	echo ""
	printUsage
	echo ""
	
read -d '' description <<"BLOCK"
Small script for killing processes.

Options:
  -v         # Display script version number and quit
  -h         # Display this help message and quit
	
  file_name  # Read the file and kill all processes with such PIDs
             # PIDs have to be separated by new lines
             # and belong to the current user
			 
  regex      # Kill all processes of the current user that match 
             # the regular expression provided
BLOCK

echo "$description"

}

# kills a proccess with given PID 
# if it is running and being owned by the current user
killProcess() {
	echo -n "Killing process $1... "

	# test if the process is running
	kill -0 $1 2> /dev/null
	if [ $? -ne 0 ];
	then
		echo "fail. Process is not running."
		return
	fi
	
	# test if the process is owned by the current user
	if [ `ps up $1 | tail -1 | tr -s ' ' | cut -d " " -f1` != `whoami` ];
	then
		echo "fail. Process is not owned by the current user."
		return
	fi

	# send SIGTERM
	echo -n "sending SIGTERM..."	
	kill -15 $1
	
	# wait for 5 seconds
	sleep 5
	
	# if the process is still running, send SIGKILL
	kill -0 $1 2> /dev/null

	if [ $? -eq 0 ];
	then
		echo "fail. Sending SIGKILL."
		kill -9 $1 2> /dev/null
	else
		echo "success."
	fi
}

# check that a valid number of parameters has been provided
test ! $# -eq 1 && echo "Invalid number of parameters." && printUsage && exit 1
	
if [ "$1" == "-v" ];
then
	printVersion
fi
	
if [ "$1" == "-h" ];
then
	printHelp
fi

# if the first parameter is a name of a local file
if [ -f "$1" ];
then
	# verify that every line of the file contains a number only
	DONE=false
	until $DONE; 
	do
		read line || DONE=true		
		
		{ test -z "$line" || [[ $line =~ ^-?[0-9]+$ ]]; } || { echo "Invalid input file."; exit 1; }		
	done < $1

	# iterate over individual processes and kill them
	DONE=false
	until $DONE; 
	do
		read line || DONE=true		
		test -n "$line" && killProcess $line		
	done < $1
else
	# interpret the first argument as a regular expression
	ps -u `whoami` | sed '1d' | tr -s ' ' | while read line ;
	do
		# if line matches the regular expression
		command=`cat<<< "$line" | cut -d" " -f 5`

		if [[ "$command" =~ $1 ]];
		then
			echo "Expression match: $command"
			echo -n "..."
			
			killProcess `cat<<< "$line" | cut -d" " -f 2`
		fi
	done
fi