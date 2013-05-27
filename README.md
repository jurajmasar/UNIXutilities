UNIX utilities
==============

Small bash utilities created as assignments for my Introduction to UNIX class at Charles University in Prague.

They demonstrate the usage of awk, sed, named pipes and file descriptors as well as other basic UNIX tools.

FTPmirror 1.0
-------------

  Utility for mirroring contents of folders via FTP, created as a project for Introduction to UNIX class at Charles University in Prague.

    usage: ./FTPmirror.sh sourcePath destinationPath [{s|a|m}|d|L|h]

    Parameters:

      $0 sourcePath destinationPath options

      sourcePath       # Location of the folder to be mirrored
                       #
                       # Examples:
                       #   .
                       #   backups/
                       #   /var/backups/
                       #   user@example.com # will be asked for password interactively
                       #   user:password@example.com:path/

      destinationPath  # Destination of mirroring
                       # Examples:
                       #   .
                       #   backups/
                       #   /var/backups/
                       #   user@example.com # will be asked for password interactively
                       #   user:password@example.com:path/

      # Important:
      # One of sourcePath or destinationPath must be local and the other must be remote

      options:         # Set of complementary options passed together as a third parameter

        d              # Create empty directories
        L              # Follow symlinks
        h              # Ignore hidden files
        n              # Do not ask for password interactively when password is not given

        mode:          # Files in destination folder DO NOT get overwritten by default.
                       # This behavior can be changed using following flags:
          
                       s # Synchronize - In case of a conflict only files with older 
                         #               modification date overwrite files with similar
                         #               names in destionationPath. 
                         #               Moreover, all files that are present in 
                         #               destinationPath but are not present in 
                         #               sourcePath are removed.
                         #               
                       a # All - In case of a conflict all files in destination become
                         #       overwritten by their versions from sourcePath
                         #
                       m # Modified -  In case of a conflict only files with older 
                         #             modification date overwrite files with similar
                         #             names in destionationPath
        
    Special parameters:
      -v         # Display script version number and quit
      -h         # Display this help message and quit

    Dependencies:
      ftp        # Internet file transfer program that is typically included with UNIX-like OS
      date (GNU) # GNU version of the date utility

    Examples:
      ./FTPmirror.sh backups/ juraj@cuni.cz:backups/
      ./FTPmirror.sh backups/ juraj@cuni.cz:backups/ sdL
      ./FTPmirror.sh juraj@cuni.cz:backups/ backups/ s
      ./FTPmirror.sh backups/ juraj:password@cuni.cz:backups/ sdL # CRON job example
      
    Author:
      Juraj Masar
      mail@jurajmasar.com
      www.jurajmasar.com

    Release date:
      27 May 2013

    Copyright:
    (c) Copyright Juraj Masar 2013.

----------

Killer 1.0
----------
  
  Small script for killing processes.

    usage: ./killer.sh {-v|-h|file_name|regular_expression}

    Options:
      -v         # Display script version number and quit
      -h         # Display this help message and quit
      
      file_name  # Read the file and kill all processes with such PIDs
                 # PIDs have to be separated by new lines
                 # and belong to the current user
           
      regex      # Kill all processes of the current user that match 
                 # the regular expression provided

------------

License
-------

    Released under MIT license.

    Permission is hereby granted, free of charge, to any person obtaining
    a copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:

    The above copyright notice and this permission notice shall be
    included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
    NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
    LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
    OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
    WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


