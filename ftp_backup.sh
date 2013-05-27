#!/bin/bash


# TODO {s sync|a ll|m odified|p reserve} L inks d irectories h iddenFiles
# TODO make script posix compatible

#
# check dependencies
#
command -v ftp > /dev/null 2>&1 || { echo >&2 "Required dependency is missing - ftp.  Aborting."; exit 1; }
date --version >/dev/null 2>&1 || { echo >&2 "Required dependency is missing - GNU date.  Aborting."; exit 1; }

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
# resursively removes remote file or a directory
#
ftp_rm_r()
{
	escapedLocalFilename=`echo "$1" | sed 's/[^[:alnum:]_-]/\\&/g'`
			
	filesToDelete=`echo -e "$remoteFiles" |  awk "/^$escapedLocalFilename/"`
	remoteFiles=`echo -e "$remoteFiles" |  awk "!/^$escapedLocalFilename/"`
	remoteModTimes=`echo -e "$remoteModTimes" |  awk "!/^$escapedLocalFilename/"`
	
	# remove all files
	while read name ftype x ; do
		if [ "$ftype" = "-" ]; then
			echo -e "del $name\n" > $inPipe
		fi
	done <<< "$filesToDelete"

	# remove all directories
	while read name ftype x ; do
		if [ "$ftype" = "d" ]; then
			echo -e "rmdir $name\n" > $inPipe
		fi
	done <<< "$filesToDelete"
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
pwd
" > $inPipe

# read ftp output
ftpOutput=$( print_outPipe ) 

#
# parse output - look for failure
#
if [[ "$ftpOutput" = *"Login failed"* ]]; then
	echo "Logging into the remote location failed. Aborting."; exit 1;		
fi

load_remote_files()
{
	#
	# list all remote files
	#
	echo -e "
	ls -R
	pwd
	" > $inPipe

	#
	# get a list of remote files
	# -> translates the output of ls -R from ftp into a list of paths to files with the file type (-/d/l etc)
	#
	remoteFiles=`echo -e "\`print_outPipe\`" | awk '
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

	if ! upload; do
		# if hidden files should be ignored
		if [ "$3" = "${3/h/foo}" ]; then
			# exclude files starting with dot
			remoteFiles=`echo -e "$remoteFiles" | awk '/^[^\.]/'`
		fi

		# if links should be ignored
		if [ "$3" = "${3/L/foo}" ]; then
			# exclude files ending with l
			remoteFiles=`echo -e "$remoteFiles" | awk '/.*[^l]$/'`
		fi
	fi


	#
	# fetch modification times from remote server 
	# if option m is used
	#
	if [ "$3" != "${3/m/foo}" ] || [ "$3" != "${3/s/foo}" ]; then 
		while read name ftype x ; do
			if [ -n "$name" ] && [ ! "$ftype" = "d" ]; then
				echo -e "modtime $name\n" > $inPipe
			fi
		done <<< "$remoteFiles"

		# insert simulated eof
		echo -e "pwd\n" > $inPipe
		
		# fetch modification times
		remoteModTimes=$( print_outPipe )
	fi	
}

# do load remote files
load_remote_files $1 $2 $3

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
if [ "$3" = "${3/h/foo}" ]; then
	# exclude files starting with dot
	localFiles=`echo -e "$localFiles" | awk '/^[^\.]/'`
fi

#
# prepare command for uploading/downloading
#
if $upload; then

	# if we need to synchronize
	if [ "$3" != "${3/s/foo}" ] ; then
		# we want to remove remote files and directories that are no longer present in local version
		remoteTemp=$( mktemp )
		localTemp=$( mktemp )
		echo -e "$remoteFiles" | awk '{ print $1 }' | sort > $remoteTemp
		echo -e "$localFiles" | awk '{ print $1 }' | sort > $localTemp
		
		# get files only on remote location
		difference=`comp -2 $localTemp $remoteTemp`

		# remove different files
		while read fileName; do
			ftp_rm_r "$fileName"
		done <<< $difference

		# clean up
		rm $localTemp $remoteTemp > /dev/null 2>&1

		# do load remote files
		load_remote_files $1 $2 $3
	fi

	# process each file
	while read localFilename ; do

		if [ -d "$localFilename" ] ; then
			# it is a directory

			# if the remote directory does not exist
			# if this is not an empty directory or if empty directories should be created as well			
			if [ `echo -e "$remoteFiles" | awk '{ print $1 }' | awk "/^${localFilename}$/" | wc -l` -eq 0 ] && [ `echo -e "$localFiles" | awk '{ print $1 }' | grep $localFilename | wc -l` -gt 1 -o "$3" != "${3/d/foo}" ]; then
				echo -e "mkdir $localFilename\n" > $inPipe
			elif [ `echo -e -n "$remoteFiles" | awk "/^${localFilename}/" | head -1 | cut -d" " -f2` = "-" ]; then
				# there is a file on a remote machine with the same name as our directory

				if [ "$3" != "${3/m/foo}" ] || [ "$3" != "${3/s/foo}" ] || [ "$3" != "${3/a/foo}" ]; then
					# if we want to remove the file

					# remove the file and create a directory with such name
					echo  "
					del $localFilename
					mkdir $localFilename
					pwd
					" > $inPipe
					ftpOutput=$( print_outPipe )
				else
					# if we want to preserve the file

					# do not upload any files that were supposed to be in this directory
					remoteFiles=`echo -e "$remoteFiles" | sed -n "/^[^$localFilename]/p"`
				fi
				# do remove it
			fi
		else
			# it is a file

			# if a remote file or a directory with such name exists
			escapedLocalFilename=`echo "$localFilename" | sed 's/[^[:alnum:]_-]/\\&/g'`
			if [ `echo -e "$remoteFiles" | awk "/^$escapedLocalFilename/" | wc -l` -gt 0 ]; then

				# if we might want to overwrite it
				if [ "$3" != "${3/m/foo}" ] || [ "$3" != "${3/s/foo}" ] || [ "$3" != "${3/a/foo}" ]; then

					# if it is a directory
					if [ `echo -e "$remoteFiles" | awk "/^$escapedLocalFilename/" | head -1 | cut -d" " -f2` = "d" ]; then
						# remove it recursively
						ftp_rm_r $localFilename
					fi

					localModTime=`date +%s -r $localFilename`
					remoteModTime=`date +%s -d "\`echo -e "$remoteModTimes" | awk "/^$escapedLocalFilename/" | head -1 | tr -s " " | cut -d" " -f 2-8\`"`

					# if we want to overwrite it
					if [ "$3" != "${3/a/foo}" ] || { { [ "$3" != "${3/m/foo}" ] || [ "$3" != "${3/s/foo}" ]; } && [ "$localModTime" -gt "$remoteModTime" ] ; }; then 
						echo -e "put $localFilename\n" > $inPipe
					fi
				fi
			else
				# transfer file
				echo -e "put $localFilename\n" > $inPipe
			fi			
		fi
		
	done <<< "$localFiles"

else
	echo -e "mget *\n" > $inPipe
fi

echo "Finished."; 
