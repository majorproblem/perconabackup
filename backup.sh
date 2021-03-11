#!/bin/bash -
#title          :backup.sh
#description    :creates backups of a MySQL database using xtrabackup
#author         :Karl-Konig Konigsson
#usage          :./backup.sh
#notes          :
#============================================================================

CONFIG=`dirname $0`/backup.conf
. $CONFIG

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
        return 1
    else
        rm $1
        return 0
    fi
}

###########
# remove all but the GENERATIONS number of generations of backups
#
prune_backups () {
    dir=$BASEDIR

    while [ `ls -1 $dir| wc -l` -gt $GENERATIONS ]; do
        oldest=`ls -1 $dir| head -1`
        TARGET=$BASEDIR/$oldest
        echo "$(date '+%y%m%d %H:%M:%S') Pruning old backup $TARGET"
        rm -rf $TARGET
    done
}

###########
# perform a full and compressed backup of the database
#
do_full_backup() {
    # this is the first backup in the set - create a backup directory for it
    mkdir -p $BACKUPDIR/full

    echo "------"
    echo "$(date '+%y%m%d %H:%M:%S') Full backup $(basename $BACKUPDIR)/full"

    DIROPT="--target-dir=$BACKUPDIR/full"
    LOGIN="--username=$MYSQL_USER --password=$MYSQL_PASS"
    COMPRESS="--parallel=4 --compress --compress-threads=2"
    xtrabackup $DIROPT $LOGIN $COMPRESS --backup --galera-info > $LOGFILE 2>&1

    check_for_errors $LOGFILE
    RETCODE=$?
    if [ $RETCODE == 1 ]
    then
        # something went wrong, time to clean up
        rm -rf $BACKUPDIR/full
    else
        prune_backups
    fi
}

###########
# create an incremental backup based on a full
#
do_incr_backup() {
    # count the number of backups already done - this is the ordinal for the next incremental
    ordinal=`ls -1 $BACKUPDIR | wc -l`
    let previous=ordinal-1

    INCRDIR="inc${ordinal}"
    if [ $previous == 0 ]
    then
        PREVDIR="full"
    else
        PREVDIR="inc${previous}"
    fi

    echo "$(date '+%y%m%d %H:%M:%S') Incremental backup $PREVDIR -> $INCRDIR"

    DIROPT="--target-dir=$BACKUPDIR/$INCRDIR --incremental_basedir=$BACKUPDIR/$PREVDIR"
    LOGIN="--username=$MYSQL_USER --password=$MYSQL_PASS"
    COMPRESS="--parallel=4 --compress --compress-threads=2"
    xtrabackup $DIROPT $LOGIN $COMPRESS --backup --galera-info > $LOGFILE 2>&1

    check_for_errors $LOGFILE
    RETCODE=$?
    if [ $RETCODE == 1 ]
    then
        # something went wrong, time to clean up
        rm -rf $BACKUPDIR/$INCRDIR
    fi

}

###########
#   MAIN
###########

# if there is no full backup then this is the first one
if [ ! -d $BACKUPDIR/full ]
then
    do_full_backup
else
    do_incr_backup
fi
