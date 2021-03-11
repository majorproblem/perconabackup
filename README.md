# perconabackup
Backup scripts to use with crontab using Percona XtraBackup. It consists of three files:

- `backup.sh`
- `backup.conf`
- `prepare.sh`

## Taking backup

### backup.sh
This is the main backup script that is run one or several times a day. It creates a full backup the first time it is run and then incremental backups every time after that. The script creates a directory per backup and in this is the full and the incremental backups stored.

#### Configuration

All configuration is done in the file `backup.conf`

### Crontab
The backup require some sort of periodicity and typically this is done with `Crontab`. Here is the Crontab I use

```crontab
30 00-23/3  * * * /backup/bin/backup.sh >> /backup/perback.log
00 00 * * 1 /usr/bin/savelog /backup/perback.log
```

It runs a backup every three hours, starting at half past twelve in the night and the output is stored in a logfile
called `/backup/perpack.log` in my case, but this can be called anything, of course.

#### Note
This crontab makes use of the `savelog` package to manage aging and compressing logfiles. As can be seen from the
Crontab this command is run once a day, with the name of the log file as parameter. Please see the man pages for
`savelog` for all details.

## Restoring from a backup
To restore a Percona cluster from a backup is a two-step process: the first is to prepare the backup, i.e., to take the  full backup and then apply all incremental backups (if there are any). Once that is done, it is possible to restore the database from this.

### Preparation
Preparation is done with the `prepare.sh` script. It takes care of the fiddly bits with preparing a backup that might consist of one full and several incremental backups and compbines those into one, restorable, copy.