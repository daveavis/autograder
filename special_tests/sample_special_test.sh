#!/bin/bash

###
# Special test script to test things that aren't testable via jUnit.
# Can test the contents of the .java file, like number of case statements,
# or length of file, or presence of a for loop instead of while loop, etc.
#
# Can output a message or not, but when $quiet=true then output only
# how many points were lost for this test.
#
# $1 contains the main .java file to be tested.
# $2 contains "grade" if the number of points lost is to be returned.
###

point_value=20  # how much is this test worth?
success_message="  Test succeeded message."
fail_message="  Test failed message."
java_file=$1
grading=$2

###################################################
# Run a custom test and set success=1 if it passes
###################################################

if [ -n "$grading" ]
then
	if [ $success -eq 1 ]
	then
		echo 0  # no points off for success
	else
		echo $point_value  #points off for failure
	fi
else
	if [ $success -eq 1 ]
	then
		$quiet || echo success_message
	else
		$quiet || echo fail_message
	fi
fi
