#!/usr/bin/env python

import glob
import csv
import re
from datetime import timedelta, datetime
import json
import sys

def status():
    # read configuration
    with open('/backup/config.json') as stream:
        config = json.load(stream)
    # get joblog file paths
    joblogs = glob.glob('/backup/logs/joblog-*.log')
    joblogs.sort()
    # translate joblogs to details dictionary
    details = { }
    for joblog in joblogs:
        # read joblog file
        with open(joblog) as file:
            reader = csv.DictReader(file, dialect="excel-tab")
            for row in reader:
                # extract key of backup object
                match = re.match(r"/backup/scripts/backup-object\.sh (.*) &> /backup/logs/\1-\d{8}-\d{6}\.log", row["Command"])
                # store status data
                if match:
                    object = match.group(1)
                    exitval = int(row["Exitval"])
                    # handle skipped backups
                    if exitval == 99 and object in details:
                        details[object]["skipcount"] += 1
                    # write full details
                    else:
                        details[object] = {
                            "timestamp": datetime.utcfromtimestamp(float(row["Starttime"])),
                            "runtime": float(row["JobRuntime"]),
                            "exitcode": exitval,
                            "sigcode": int(row["Signal"]),
                            "skipcount": 1 if exitval == 99 else 0
                        }
    # compose summary of backup objects
    summary = { }
    ok = True
    for object in config['objects'].keys():
        summary[object] = {
            "ok": True,
            "message": "ok"
        }
        # check if we have a job status
        if object not in details:
            summary[object] = {
                "ok": False,
                "message": "backup not found"
            }
            ok = False
            continue
        # check if we have a bad exit code
        if details[object]["exitcode"] != 0:
            summary[object] = {
                "ok": False,
                "message": "backup failed (unknown error)",
                "exitcode": details[object]["exitcode"]
            }
            ok = False
            if details[object]["exitcode"] == 2:
                summary[object]["message"] = "backup failed ('borg create' failed)"
            if details[object]["exitcode"] == 3:
                summary[object]["message"] = "backup failed ('borg prune' failed)"
            if details[object]["exitcode"] == 4:
                summary[object]["message"] = "backup failed ('aws s3 sync' failed)"
            if details[object]["exitcode"] == 99:
                summary[object]["message"] = "backup skipped (blocked by parallel running backup process)"
            continue
        # check if we have a bad signal code
        if details[object]["sigcode"] != 0:
            summary[object] = {
                "ok": False,
                "message": "backup failed (signal caught)",
                "sigcode": details[object]["sigcode"]
            }
            ok = False
            continue
        # check if last backup is too old
        if details[object]["timestamp"] < datetime.utcnow() + timedelta(hours = -int(config['monitoring']['max_age_hours'])):
            summary[object] = {
                "ok": False,
                "message": "backup is too old",
                "timestamp": details[object]["timestamp"]
            }
            ok = False
            continue
    # return status
    return {
        "details": details,
        "summary": summary,
        "ok": ok
    }

if __name__ == "__main__":
    current = status()
    print(json.dumps(current, sort_keys=True, indent=2, default=str))
    sys.exit(0 if current["ok"] else 1)
