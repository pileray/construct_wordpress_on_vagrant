#! /bin/bash

source secrets.sh

period=5
dirpath="/root/backup/mysql"
filename=`date '+%Y%m%d'`
mysqldump  -u root -p $password --lock-all-tables --all-databases --events > $dirpath/$filename.sql
oldfile=`date --date "$period days ago" '+%Y%m%d'`
rm -f $dirpath/$oldfile.sql
