#!/bin/bash

cde_user=$1
max_participants=$2

echo "CDE 1.26 HOL DB TEARDOWN INITIATED...."
echo "..."
echo ".."
echo "."
echo "Provided CDE User: "$cde_user
echo "Provided Max Participants: "$max_participants

echo "Create teardown resource cde126-hol-teardown-"$cde_user
cde resource delete --name cde126-hol-teardown-$cde_user
cde resource create --name cde126-hol-teardown-$cde_user --type files
echo "Upload teardown script to resource cde126-hol-teardown-"$cde_user
cde resource upload --name cde126-hol-teardown-$cde_user --local-path "$(dirname "$0")/teardown.py"
echo "Create teardown job cde126-hol-teardown-"$cde_user
cde job delete --name cde126-hol-teardown-$cde_user
cde job create --name cde126-hol-teardown-$cde_user --type spark --mount-1-resource cde126-hol-teardown-$cde_user --application-file teardown.py
echo "Run teardown job cde126-hol-teardown-"$cde_user
cde job run --name cde126-hol-teardown-$cde_user --arg $max_participants
