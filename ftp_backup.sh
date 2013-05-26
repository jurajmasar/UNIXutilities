#!/bin/bash

# {s|a|m|n} Ld
#
# check dependency - ftp command
#
command -v ftp > /dev/null 2>&1 || { echo >&2 "Required dependency is missing - ftp.  Aborting."; exit 1; }

#
# prints usage instructions
#
print_usage() 
{
	# TODO
	echo "Usage: $0 {--help}"
}

#
# check for special arguments
#
if [ "$1" == "--help" ]; then
	print_usage
	# options are present
fi

#
# determine the direction of the transfer
#
if [[ $1 == *"@"* ]]; then
	upload=false
	localPath=$2
	remotePath=$1
elif [[ $2 == *"@"* ]]; then
	upload=true
	localPath=$1
	remotePath=$2
else
	echo "Invalid arguments. Aborting."
	print_usage
	exit 1
fi

#
# prepare local path
#
if [ ! `echo "$localPath" | head -c1` = "/" ]; then
	# prepend path to script directory
	localPath="`pwd`/$localPath"
fi

#
# validate local path
#
if [ ! -d "$localPath" ]; then
	echo "The local path you have provided is invalid. Aborting."; exit 1;
fi

#
# prepare remote path - parse the path into fields
#
user=`echo $remotePath | awk '{split($0,a,"@"); split(a[1],b,":"); print b[1]}'`
password=`echo $remotePath | awk '{split($0,a,"@"); split(a[1],b,":"); print b[2]}'`
server=`echo $remotePath | awk '{split($0,a,"@"); split(a[2],b,":"); print b[1]}'`
path=`echo $remotePath | awk '{split($0,a,"@"); split(a[2],b,":"); print b[2]}'`

# set path to . if empty
if [ -z `echo "path" | tr -d "[[:space:]]"` ]; then
	path="."
fi

#
# check for options
#

# if password is empty after removing whitespace and third parameter does not contain letter n
if [ -z `echo "$password" | tr -d "[[:space:]]"` ] && [ "$3" = "${3/n/foo}" ]; then
	read -s -p "Password: " password		
	echo ""	
fi

#
# establish connection to remote location and try to log in
#
ftpOutput=$( 
ftp -i -f -n 2>&1 <<EOF
open $server
user $user $password
ls -R
EOF
)

#
# parse output - look for failure
#
if [[ "$ftpOutput" = *"Login failed"* ]]; then
	echo "Logging into the remote location failed. Aborting."; exit 1;		
fi

#
# get a list of remote files
# -> translates the output of ls -R from ftp into a list of paths to files with the file type (-/d/l etc)
#
remoteFiles=`echo -e "$ftpOutput" | awk '
BEGIN{
	prefix=""
}; 
{
	if (NF == 0 || $9 == "." || $9 == "..")
	{
		next;
	} else if (NF == 1) 
	{
		sub(/:/, "/", $1);
		prefix=$1;
	} else {
		printf("%s%s %s\n", prefix, $9, substr($1, 1, 1)); 
	} 
};
'`

echo -e "$remoteFiles" | while read name ftype x ; do
	echo "$name"
done

exit 0;

#
# prepare command for uploading
#
if $upload; then
	ftpCommand="mput *"
else
	ftpCommand="mget *"
fi

echo "Transferring files..."

#
# attempt to transfer files
#
ftpOutput=$( 
ftp -i -f -n 2>&1 <<EOF
open $server
user $user $password
mkdir $path
cd $path
lcd $localPath
${ftpCommand}
EOF
)	

#
# print summary and exit
#
if [[ "$ftpOutput" = *"fail"* ]]; then
	echo "Transferring files failed. Aborting."; exit 1;		
else
	echo "Finished successfully."; exit 0;
fi

