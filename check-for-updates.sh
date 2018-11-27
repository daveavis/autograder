#!/bin/bash

###
# usage: check-for-updates.sh -c classlist -o organization -u user -l lab
# Outputs a list of local repos that need updating ready for piping to another
# script to actually do the updating.
###

# path to my home folder
home_path="$(echo ~)"
tools_path="$(dirname $0)"
clone_path="$tools_path/clones"

while getopts "c:l:o:u:" OPT;
do
	case $OPT in
		c)
			classlist_file=$OPTARG
			;;
        l)
            labname=$OPTARG
            ;;
        o)
            org_name=$OPTARG
            ;;
        u)
            student_username=$OPTARG
            ;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			exit 1
			;;
		:)
			echo "Option -$OPTARG requires an argument." >&2
			exit 1
			;;
	esac
done

if [ -n "$classlist_file" ]
then
    for student in `cat $classlist_file | tr -d '\r'`
    do
		dir="$clone_path/$labname/$labname-$student"
        git -C "$dir" remote update > /dev/null 2>&1
		status_text=`git -C "$dir" status`
        if [ `echo $status_text | grep "behind" | wc -l` -ne 0 ]
        then
            echo "$dir"
        fi
    done
elif [ -n "$student_username" ]
then
    student=$student_username
	dir="$clone_path/$labname/$labname-$student"
	git -C "$dir" remote update > /dev/null 2>&1
    status_text=`git -C "$dir" status`
    if [ `echo $status_text | grep "behind" | wc -l` -ne 0 ]
    then
        echo "$dir"
    fi
else
    for repo in `ls "$clone_path/$labname/" | grep ^lab`
    do
		dir="$clone_path/$labname/$repo"
		if [ -d "$dir/.git" ]
		then
			git -C "$dir" remote update > /dev/null 2>&1
        	status_text=`git -C "$dir" status`
        	if [ `echo $status_text | grep "behind" | wc -l` -ne 0 ]
        	then
            	echo "$dir"
        	fi
		fi
    done
fi
