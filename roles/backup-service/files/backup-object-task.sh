#!/bin/bash
set -e

# get parameter
BACKUP_OBJECT="$1"

# initialization
echo ">> INFO: running backup for $BACKUP_OBJECT"

rm -f /backup/socks/$BACKUP_OBJECT.sock

if ! mkdir -p "/backup/repos/$BACKUP_OBJECT";
then
  echo ">> ERROR: 'mkdir' failed for $BACKUP_OBJECT"
  exit 1
fi

if [ -z "$(find "/backup/repos/$BACKUP_OBJECT" -mindepth 1 -print -quit 2>/dev/null)" ];
then
  if ! borg init --encryption=none "/backup/repos/$BACKUP_OBJECT" ;
  then
    echo ">> ERROR: 'borg init' failed for $BACKUP_OBJECT"
    exit 1
  fi
fi

#### backup phase

# run borg create
echo ">> INFO: running 'borg create' for $BACKUP_OBJECT"

socat "UNIX-LISTEN:/backup/socks/$BACKUP_OBJECT.sock,fork" \
    "EXEC:borg serve --append-only --restrict-to-path /backup/repos/$BACKUP_OBJECT" &
SOCAT_PID=$!

sleep 1s

if ! \
  ssh \
    -o PasswordAuthentication=no \
    -R "/root/backup-server.sock:/backup/socks/$BACKUP_OBJECT.sock" \
    "root@$(jq -r --arg object "$BACKUP_OBJECT" '.objects[$object]' /backup/config.json)" \
    backup-on-pull.sh ;
then
  kill -INT $SOCAT_PID

  echo ">> ERROR: 'borg create' failed for $BACKUP_OBJECT"
  exit 2
fi

kill -INT $SOCAT_PID

# run borg prune
echo ">> INFO: running 'borg prune' for $BACKUP_OBJECT"
if ! \
  borg \
    prune --list \
    $(jq -r '.retention.keep | to_entries[] | "--keep-" + .key + "=" + .value' /backup/config.json) \
    /backup/repos/$BACKUP_OBJECT ;
then
  echo ">> ERROR: 'borg prune' failed for $BACKUP_OBJECT"
  exit 3
fi

# run aws s3 sync
echo ">> INFO: running 'aws s3 sync' for $BACKUP_OBJECT"
if ! \
  AWS_ACCESS_KEY_ID="$(jq -r '.upstream.aws.access_key_id' /backup/config.json)" \
  AWS_SECRET_ACCESS_KEY="$(jq -r '.upstream.aws.secret_access_key' /backup/config.json)" \
  borg \
    with-lock "/backup/repos/$BACKUP_OBJECT" \
    aws \
      s3 sync \
      "/backup/repos/$BACKUP_OBJECT" \
      "$(jq -r '.upstream.aws.bucket_url' /backup/config.json)/$BACKUP_OBJECT" \
      --delete ;
then
  echo ">> ERROR: 'aws s3 sync' failed for $BACKUP_OBJECT"
  exit 4
fi

# done
echo ">> INFO: completed backup for $BACKUP_OBJECT"
exit 0
