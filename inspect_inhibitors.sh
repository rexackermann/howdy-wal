#!/bin/bash
# Get all inhibitors and their details

inhibitors=$(gdbus call --session --dest org.gnome.SessionManager --object-path /org/gnome/SessionManager --method org.gnome.SessionManager.GetInhibitors | grep -o "'/[^']*'")

for path in $inhibitors; do
    path=${path//\'/} # remove quotes
    echo "Path: $path"
    gdbus call --session --dest org.gnome.SessionManager --object-path "$path" --method org.gnome.SessionManager.Inhibitor.GetAppId
    gdbus call --session --dest org.gnome.SessionManager --object-path "$path" --method org.gnome.SessionManager.Inhibitor.GetReason
    gdbus call --session --dest org.gnome.SessionManager --object-path "$path" --method org.gnome.SessionManager.Inhibitor.GetFlags
done
