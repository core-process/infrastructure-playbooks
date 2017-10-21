#!/bin/bash

# get parameter
BACKUP_OBJECT="$1"

# read configuration
. /backup/config/vars.sh

# run rdiff-backup
export AWS_ACCESS_KEY_ID="$CONFIG_AWS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$CONFIG_AWS_KEY_SECRET"
duplicity --allow-source-mismatch --max-blocksize 4194304 --asynchronous-upload --no-encryption --full-if-older-than "$CONFIG_REMOTE_FULL_IF_OLDER_THAN" --exclude "/backup/repos/$BACKUP_OBJECT/rdiff-backup-data" "/backup/repos/$BACKUP_OBJECT" "$CONFIG_AWS_S3_URL/$BACKUP_OBJECT"
EXIT_CODE="$?"

# done!
exit $EXIT_CODE
