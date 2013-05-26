#!/bin/bash


# TODO {s sync|a ll|m odified|p reserve} L inks d irectories h iddenFiles
# TODO make script posix compatible
#
# check dependency - ftp command
#
command -v ftp > /dev/null 2>&1 || { echo >&2 "Required dependency is missing - ftp.  Aborting."; exit 1; }

#
# timeout for waiting for a response of a ftp server
#
timeout=3

#
# echoes everything from the output pipe until eof
#
print_outPipe()
{
	DONE=false
	until $DONE; do
		read -t $timeout line || DONE=true

		# continue if the line is empty / white space only
		[ -z `echo "$line" | tr -d "[[:space:]]"` ] && continue

		# stop reading on simulated EOF -> output of a pwd command
		[ `echo "$line" | sed -n '/^Remote directory: /p' | wc -l` -gt 0 ] && return

		echo "$line"
	done < $outPipe
}

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
# if password is empty after removing whitespace and third parameter does not contain letter n
#
if [ -z `echo "$password" | tr -d "[[:space:]]"` ] && [ "$3" = "${3/n/foo}" ]; then
	read -s -p "Password: " password		
	echo ""	
fi

#
# create a named pipes and attach file descriptors
#
inPipe="/tmp/inpipe.$$"
mkfifo $inPipe
exec 3<>$inPipe

outPipe="/tmp/outpipe.$$"
mkfifo $outPipe
exec 4<>$outPipe

# remember the current location
OPWD=`pwd`
# change location
cd $localPath
# change location and remove pipes on exit
trap  "rm -f $inPipe $outPipe; cd $OPWD; exit;" EXIT

#
# establish connection to remote location via a pipe
#
ftp -i -f -n < $inPipe > $outPipe 2>&1 &

#
# try to log in
#
echo -e "
open $server
user $user $password
mkdir $path
cd $path
ls -R
pwd
" > $inPipe

# read ftp output
ftpOutput=$( print_outPipe ) 
# remove top two lines caused by mkdir
ftpOutput=`echo "$ftpOutput" | sed -n '1!p'`

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
remoteFiles=`echo -e "$ftpOutput" | sed -n '1!p' | awk '
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

#
# fetch modification times from remote server 
# if option m is used
#
if [ "$3" != "${3/m/foo}" ]; then 
	# prepare ftp command
	ftpCommand=""

	while read name ftype x ; do
		if [ -n "$name" ] && [ ! "$ftype" = "d" ]; then
			ftpCommand="${ftpCommand}modtime $name\n"			
		fi
	done <<< "$remoteFiles"

	# insert simulated eof
	ftpCommand="${ftpCommand}pwd\n"
	
	# translate \n into new lines and send it to ftp process
	echo -e "$ftpCommand" > $inPipe
		
	# fetch modification times
	remoteModTimes=$( print_outPipe )
fi

#
# get a list of local files
#

# if links should be followed
if [ "$3" = "${3/L/foo}" ]; then
	findParameters="-L"
fi

findParameters="$findParameters ."

localFiles=`find $findParameters | sed -n '1!p' | sed 's/\.\/\(.*\)/\1/'`

# if hidden files should be ignored
if [ "$3" = "${3/L/foo}" ]; then
	# exclude files starting with dot
	localFiles=`echo -e "$localFiles" | awk '/^[^\.]/'`
fi

#
# prepare command for uploading/downloading
#
ftpCommand=""
if $upload; then
	# build set of commands to manipulate files
	echo "remote files:"
	echo -e "$remoteFiles"
	echo
	
	while read localFilename ; do
		
		if [ -d "$localFilename" ] ; then
			# it is a directory
			echo -e "Local directory: $localFilename"
			
			# if the remote directory does not exist
			# if this is not an empty directory or if empty directories should be created as well			
			if [ `echo -e "$remoteFiles" | awk '{ print $1 }' | awk "/^${localFilename}$/" | wc -l` -eq 0 ] && [ `echo -e "$localFiles" | awk '{ print $1 }' | grep $localFilename | wc -l` -gt 1 -o "$3" != "${3/d/foo}" ]; then
				ftpCommand="${ftpCommand}mkdir $localFilename\n"
			elif [ `echo -e "$remoteFiles" | awk '{ print $1 }' | awk "/^${localFilename}$/" | wc -l` -gt 0 ] ; then
				# there is a file or a directory on a remote machine with the same name

				# if we need to remove it
				if [ "$3" != "${3/m/foo}" -o "$3" != "${3/s/foo}" -o "$3" != "${3/a/foo}"]; then	
					cat > /dev/null
				fi
			fi
		else
			echo > /dev/null
			# it is a file
			if [ "$3" != "${3/a/foo}" ]; then
				# if all fiels should be rewrited
				echo > /dev/null
			fi			
		fi
		
	done <<< "$localFiles"

else
	ftpCommand="mget *"
fi

# translate \n into new lines
ftpCommand=`echo -e "$ftpCommand"`

echo 
echo -e "$ftpCommand"
exit 1;

echo "Transferring files..."
echo
echo "Ftp output:"

#
# attempt to transfer files
#
ftp -i -f -n -v <<EOF
open $server
user $user $password
mkdir $path
cd $path
lcd $localPath
${ftpCommand}
EOF
	
echo "Finished."; 
