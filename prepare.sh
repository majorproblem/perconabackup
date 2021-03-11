#!/bin/bash -
#title          :prepare.sh
#description    :automates the prepare procedure for incremental backups
#author         :Karl-Konig Konigsson
#usage          :./prepare.sh
#notes          :
#============================================================================

LOGFILE=/tmp/prepare.$$.log

###########
# FUNCTIONS
###########

###########
# verify that the latest xtrabackup command went OK
#
check_for_errors () {
  if ! tail $1 -n 1 | grep completed.OK
  then
    echo "ERROR: command failed! (log: "$1")"
    exit 1
  fi
  rm $1
}

###########
# handle the case with a single, full, backup
#
prepare_single () {
    if [ -d full ]
    then
        echo "Preparing single full backup"
        xtrabackup --prepare --target-dir=full > $LOGFILE 2>&1
        check_for_errors $LOGFILE
    else
        echo Error: no full backup found
        exit 1
    fi
}

###########
# handle one full backup and one or more incremental ones
#
prepare_many () {
  echo "Preparing full and incremental backups"

  # the number of incremental backups is one less than the total
  # because "full" does not count, and then one less for the last one
  # which is a special case - all in all minus two
  let num_of_incr=$1-2

  # begin by preparing the full backup
  echo -n "full "
  xtrabackup --prepare --apply-log-only --target-dir=full > $LOGFILE 2>&1
  check_for_errors $LOGFILE

  let count=1
  while [ $count -le $num_of_incr ]
  do
    echo -n "inc${count} "
    xtrabackup --prepare --apply-log-only --target-dir=full --incremental-dir="inc${count}" > $LOGFILE 2>&1
    check_for_errors $LOGFILE
    let count=$count+1
  done
}

###########
# runs "xtrabackup --prepare" on the last backup in a set, as that is a special case
#
prepare_last () {
  # the number of the last incremental backups is one less than the total
  let the_last_incr=$1-1

  echo -n "inc${the_last_incr} "
  xtrabackup --prepare --target-dir=full --incremental-dir="inc${the_last_incr}" > $LOGFILE 2>&1
  check_for_errors $LOGFILE
}

###########
# decompress all directories in the backup set
#
do_decompress () {
    # iterate over all directories in the backup set
    echo Decompressing directories
    for A_DIR in *
    do
        echo -n "$A_DIR "
        xtrabackup --decompress --remove_original --parallel=4 --target-dir=$A_DIR > $LOGFILE 2>&1
        check_for_errors $LOGFILE
    done
    echo
}

###########
#   MAIN
###########

# check that we are in a backup directory, i.e., there is a dorectory named "full"
if [ ! -d "full" ]
then
    echo Error: No backup found in current directory
    exit
fi

# begin the process with decompressing all directories in the current backup set
do_decompress

# count how many directories there are in the set
shopt -s nullglob
num_in_set=(*)
num_in_set=${#num_in_set[@]}

# prepare the backup set for restore taking into account that a single full backup
# is one case and a set of backups is another
if [ $num_in_set == 1 ]
then
    prepare_single
else
    prepare_many $num_in_set
    prepare_last $num_in_set
fi
