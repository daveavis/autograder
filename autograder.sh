#!/bin/bash



# 0 to go ahead with cloning, 1 to skip cloning (set by cli -z)
skip_clone=0

# Path to my home folder
# Works in Bash on Mac/Linux, and Git Bash on Windows.
#home_path="$(echo ~)"
home_path="$HOME"

# Path to the directory containging this script and associated scripts
tools_path="$(dirname "$0")"
tools_path="$(readlink -f $tools_path)"  # expand relative path

# Path to the directory containing all of the cloned repositories
clone_path="$tools_path/clones"
if [ ! -d "$clone_path" ]
then
	mkdir -p "$clone_path"
fi

# Path to the directory containing all of the original repositories (used to see if the lab has been started or not)
orig_path="$clone_path/originals"

# Config file dir (not currently used)
config_path="$tools_path/configs"

# Grading file dir (not currently used)
grade_path="$tools_path/grade"

# List file dir (not currently used)
list_path="$tools_path/lists"

# Special Test file dir (not currently used)
special_test_path="$tools_path/special_tests"

# Directory containing supporting jar files 
jars_path="$tools_path/jars"

# name of the clone_all.sh script
clone_cmd="clone_all.sh"

# name of the jUnit jar file
jUnit_jar="$jars_path/junit-platform-console-standalone-1.3.1.jar"

# name of the Checkstyle jar file
checkstyle_jar="$jars_path/checkstyle-8.12-all.jar"

# Location of the Checkstyle config file.  Blank for the default file.  Can be URL or file.
checkstyle_config="http://www.daveavis.com/cs/checkstyle_SHS.xml"

# Java Classpath to use when running the programs
classpath="."

student_username=""
list_filename=""
lab_name=""
run=0				# zero to not run the main class, 1 to run the main class
check_all=0			# 1 to check all
update_all=0		# 1 to update all
skip=0  			# set to 1 to skip the rest of processing.  Used when compile fails and I don't want to continue.
quiet=false

# either "https" or "ssh" for use with the clone_all.sh script.  "ssh" doesn't work on campus.
protocol="https"

# The teacher's github username. Used with the clone_all.sh script. Overridden with the -a option.
github_username="daveavis"

# default commit message.  Used in conjunction with -p.  Updated when -m is specified.
message="Update from Mr. Avis"		# default commit message


print_help() {
	echo "usage: ./autograder.sh [OPTION]"
	echo ""
	echo "-a                Check all local repos to see if they are up to date."
	echo "-A                Update all local repos."
	echo "-B                The base repo name. The repo that all the labs were cloned from."
	echo "                  Automatically sets labname to be the lowercase version of the base repo name."
	echo "-c configfile     Read some options from a config file."
	echo "-h                Print this message."
	echo "-g gradefile      Grade based on the points in the gradefile."
	echo "-l labname        Lab name (e.g. lab-00-hello-world)"
	echo "-L filename       File containing a list of usernames. Used for running one course section at a time."
	echo "-m message        Commit message (used in conjunction with -p)"
	echo "-o org_name       GitHub organization name."
	echo "-p labname        The name of the lab to push local changes to GitHub"
	echo "-q				Quiet mode."
	echo "-r                Run the compiled class. Output goes to stdout."
	echo "-s filename       Filename where the main class resides (e.g. Filename.java)"
	echo "-t filename       Filename where the test class resides (e.g. FilenameTest.java)"
	echo "-T filename       Filename of the shell script holding a special test to run."
	echo "-u username       The teacher's GitHub username. Needed when cloning all repos in a lab."
	echo "-U username       A single student's username. Used for cloning/testing a single student's lab."
	echo "-z                skip cloning (generally used for testing)"
	echo ""
	echo "Clone and test one lab for a class and compare to the base repo. (recommended usage)"
	echo "./autograder.sh -o org_name -B base_repo_name -s source_filename -t test_filename -L username_list_filename"
	echo ""
	echo "Check if there are any updated labs on GitHub"
	echo "./autograder.sh -B base_repo_name -a [-L username_list_filename]"
	echo ""
	echo "Check if a single student's lab is up-to-date"
	echo "./autograder.sh -B base_repo_name -a -U student_username"
	echo ""
	echo "Clone and test a single student's lab"
	echo "./autograder.sh -o org_name -B base_repo_name -s source_filename -t test_filename -U student_username"
	echo ""
	echo "Clone and test all labs for an organization:"
	echo "./autograder.sh -o org_name -u teacher_username -l labname -s source_filename -t test_filename"
	echo ""
	echo "Push local changes to GitHub for all repos of a particular lab."
	echo "./autograder.sh -p labname [-m commit_message]"
}

# process command line options
# process config file first
optstring=":aAB:c:g:hl:L:m:o:p:qrs:t:T:u:U:z"
while getopts "$optstring" OPT
do
	case $OPT in
		c)
			config_file="$OPTARG"
			if [ ! -e "./$config_file" ]
			then
				echo "file $config_file does not exist."
				exit 1
			fi
			source "./$config_file"
			;;
	esac
done

OPTIND=1

# process the rest of the command line options
while getopts "$optstring" OPT
do
	case $OPT in
		a)
			check_all=1
			skip_clone=1
			;;
		A)
			update_all=1
			;;
		B)
			base_repo=$OPTARG
			lab_name=$(echo "$base_repo" | tr '[:upper:]' '[:lower:]')
			;;
		g)
			grade_file="$OPTARG"
			if [ ! -e "$grade_path/$grade_file" ]
			then
				echo "File $grade_file does not exist."
				exit 1
			fi
			;;
		h)
			print_help
			exit 0
			;;
		l)
			lab_name=$OPTARG
			;;
		L)
			list_filename=$OPTARG
			if [ ! -e "./$list_filename" ]
			then
				echo "File $list_filename does not exist."
				exit 1
			fi
			;;
		m)
			message=$OPTARG
			;;
		o)
			course=$OPTARG
			;;
		p)
			push_to=$OPTARG
			;;
		q)
			quiet=true
			;;
		r)
			run=1
			;;
		s)
			main_file=$OPTARG
			;;
		t)
			test_file=$OPTARG
			;;
		T)
			special_test_file=$OPTARG
			;;
		u)
			github_username=$OPTARG
			;;
		U)
			student_username=$OPTARG
			#skip_clone=1
			;;
		z)
			skip_clone=1
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
shift $(($OPTIND - 1))


run-special-test() {
	# run any special tests provided
	if [ -n "$special_test_file" ]
	then
		source $tools_path/$special_test_file $main_file $1
	fi
}

grade() {
	total_grade=100
	while read test points
	do
		points=`echo $points | tr -d '\r'`
		if [ -n "$test" ]
		then
			error=`echo "$jUnit_errors" | grep $test`
		fi
		if [ "$error" != "" ]
		then
			total_grade=$((total_grade-points))
		fi
		if [ "$test" = "checkstyle" ] && [ $checkstyle_errors -ne 0 ]
		then
			total_grade=$((total_grade-points))
		fi
	done < <(cat "$grade_path/$grade_file")
	if [ -n "$special_test_file" ]
	then
		points=$(run-special-test "grade")
		total_grade=$((total_grade-points))
	fi

	$quiet || echo "  Grade: $total_grade"
}

# Checking for files identical to original stub file.  Report "not started" when they are the same
compare-to-base() {
	# should be able to count number of commits that aren't mine.
	# then wouldn't have to clone the base repo at all.
	diff_out=$(diff -b "$orig_path/$base_repo/$main_file" "$clone_path/$lab_name/$lab_name-$student_username/$main_file")
	if [ -z "$diff_out" ]
	then
		echo "  Lab has not been started."
		skip=1    # don't bother processing if they haven't started.
		#return $skip
	fi
	#return 0
}

list-all-commits() {
	echo "  Commits by $student_username"
	git -C . log --format=format:"    %cd by %cn %ce" | grep -v "charles.avis@springbranchisd.com"
}

show-last-commit() {
	git -C . log --format=format:"%cd by %cn %ce" | grep -v "charles.avis@springbranchisd.com" | head -1
}

last-commit-date() {
	last_commit_string=$(show-last-commit)
	line_array=($last_commit_string)
	echo ${line_array[0]} ${line_array[1]} ${line_array[2]} ${line_array[3]}
}

clone-all() {
	# clone all of the repos
	if [ $skip_clone -eq 0 ]
	then
		"$tools_path"/$clone_cmd $course $lab_name $github_username $protocol
		if [ "$?" -ne "0" ];
		then
			$quiet || echo "Clone Failed."
			exit 1
		fi
	else $quiet || echo "Skipping clone_all..."
	fi
}

# clone one repo
clone-one() {
	$quiet || echo "Cloning $student_username..."
	# git command to clone from url or update from current dir
	dir="$clone_path/$lab_name"
	mkdir -p "$dir"
	cd "$dir"

	if [ -d "$dir/$lab_name-$student_username/.git" ]
	then
		git -C "$dir/$lab_name-$student_username" pull
	else
		git ls-remote https://github.com/$course/$lab_name-$student_username.git/ > /dev/null 2>&1
		if [ $? -eq 0 ]
		then
			git clone https://github.com/$course/$lab_name-$student_username.git/
		else # Repo probably doesn't exist. Usually because of a typo.
			echo "Repo does not exist."
			skip=1
		fi
	fi
}

clone-list() {
	dir="$clone_path/$lab_name"
	mkdir -p "$dir"
	cd "$dir"

	for USER in `cat "$tools_path/$list_filename" | tr -d '\r'`
	do
		if [ -d "$dir/$lab_name-$USER/.git" ]
		then
			git -C "$dir/$lab_name-$USER" pull
		else
			git ls-remote https://github.com/$course/$lab_name-$USER.git/ > /dev/null 2>&1
			if [ $? -eq 0 ]
			then
				git clone https://github.com/$course/$lab_name-$USER.git/
			else # Repo probably doesn't exist. Usually because of a typo.
				echo "Repo does not exist."
				#skip=1
			fi
		fi
	done
}

clone-base() {
	$quiet || echo "Cloning $base_repo"
	dir="$orig_path"
	mkdir -p "$dir"
	cd "$dir"
	if [ -d "$dir/$base_repo"/.git ]
	then
		git -C "$dir/$base_repo" pull
	else
		git ls-remote https://github.com/$course/$base_repo.git/ > /dev/null 2>&1
		if [ $? -eq 0 ]
		then
			git clone https://github.com/$course/$base_repo.git/
		else
			echo "Base repo does not exist."
			#skip=1
		fi
	fi
}

# compile the main java class
compile-main() {
	# Compile
	javac -cp "$classpath" $main_file 2> /dev/null
	if [ "$?" -ne "0" ]
	then
		COMPILE_ERRORS=`javac -cp "$classpath" $main_file 2>&1 | tail -1`
		$quiet || echo "    COMPILE FAILED: $COMPILE_ERRORS"
		$quiet && echo "    COMPILE FAILED"
		skip=1 # bypass processing the rest of this lab.
	fi
}

run-tests() {
	# run jUnit tests
	jUnit_errors=""
	num_jUnit_errors=`java -jar "$jUnit_jar" --class-path $classpath --scan-class-path --details=tree --disable-ansi-colors --details-theme=ascii | grep -c "\[X\]"`
	if [ "$num_jUnit_errors" -ne "0" ]
	then
		jUnit_errors=`java -jar "$jUnit_jar" --class-path $classpath --scan-class-path --details=tree --disable-ansi-colors --details-theme=ascii | grep "\[X\]"`
		$quiet || echo "  Unit test failures: $num_jUnit_errors"
		$quiet || echo "$jUnit_errors"
	fi
}

compile-tests() {
	# Compile jUnit tests
	# Classpath separator is : on UNIX and Git Bash (Windows), and ; on Windows
	javac -cp $classpath:"$jUnit_jar" $test_file 2> /dev/null
	if [ "$?" -ne "0" ]
	then
		$quiet || echo "  Unit tests failed to compile."
	else
		run-tests
	fi
}

run-checkstyle() {
	# run Checkstyle
	checkstyle_errors=`java -jar "$checkstyle_jar" -c $checkstyle_config $main_file | grep "[ERROR]" | wc -l`
	checkstyle_errors=$(( $checkstyle_errors ))    # trim whitespace
	if [ "$checkstyle_errors" -ne "0" ]
	then
		$quiet || echo "  Checkstyle failed with $checkstyle_errors errors."
	fi
}

run() {
	$quiet || echo "  Running program..."
	java -cp $classpath ${main_file%.*}
}

compile-and-test() {
	# TODO: If no base file then don't compare to base #
	compare="$(compare-to-base)"
	echo -n "$compare"   # print the error message if there was one
	#if [ $skip -eq 0 ]
	if [ -z "$compare" ]
	then
		$quiet || list-all-commits
		compile_result="$(compile-main)"
		echo -n "$compile_result"
		if [ -z "$compile_result" ]   # if compile didn't fail
		then
			if [ -n "$test_file" ]
			then
				compile-tests
				#run-tests
			else
				$quiet || echo "  No unit tests found."
			fi
			run-checkstyle
			run-special-test
			if [ $run -eq 1 ]
			then
				run
			fi
			if [ -n "$grade_file" ]
			then
				grade
			fi
			last_commit=$(last-commit-date)
			$quiet && echo "  Last Commit: $last_commit, Test Errors: $num_jUnit_errors, Checkstyle Errors: $checkstyle_errors, Grade: $total_grade"
		else
			echo ""
		fi
	else
		echo ""
		$quiet || echo "  Skipping lab..."
		skip=0		# reset for the next lab
	fi
}

# checking all local repos and reporting if up to date or not, possibly updating.
check-for-updates() {
	if [ -n "$lab_name" ]
	 then
		# check if a particular lab is up to date.
		if [ -n "$list_filename" ]
		then
			./check-for-updates.sh -l $lab_name -c $list_filename
		elif [ -n "$student_username" ]
		then
			./check-for-updates.sh -l $lab_name -u $student_username
		else
			./check-for-updates.sh -l $lab_name
		fi
	fi
}

push-all() {
	dir="$clone_path/$push_to"
	cd "$dir"
	for repo in `ls`
	do
		cd "$dir/$repo"
		if [ -d ".git" ]
		then
			$quiet || echo "Updating $repo"
			git add -A
			git commit -m "$message"
			git push origin master
		fi
	done
}

###########################################################################
#                                 Start                                   #
###########################################################################

if [ $check_all -eq 1 ]
then
	check-for-updates
fi

if [ -n "$push_to" ]
then
	push-all
	exit 0
fi

# Cloning
if [ $skip_clone -eq 0 ]
then
	if [ -n "$student_username" ]
	then
		clone-one
	elif [ -n "$list_filename" ]
	then
		clone-list
	else
		clone-all
	fi
if [ -n "$base_repo" ]
	then
		#echo "Cloning Base Repo"
		clone-base
	fi
#else
	#echo "Cloning skipped..."
fi

# Compiling and testing
if [ -n "$main_file" ] && [ $skip -eq 0 ]   # if no main file is specified then skip compiling and testing
then
	if [ -n "$student_username" ]
	then
		# process lab for single student
		dir="$clone_path/$lab_name/$lab_name-$student_username"
		$quiet || echo "Testing $lab_name-$student_username"
		$quiet && echo -n "$lab_name-$student_username "
		if [ -d "$dir" ]
		then
			cd "$dir"
			compile-and-test
		else
			echo "  Lab does not exist."
		fi
	elif [ -n "$list_filename" ]
	then
		# process lab for a list of students
		dir="$clone_path/$lab_name"
		for student_username in `cat "$tools_path/$list_filename" | tr -d '\r'`
		do
			$quiet || echo "Testing $lab_name-$student_username"
			$quiet && echo -n "$lab_name-$student_username"
			if [ -d "$dir/$lab_name-$student_username" ]
			then
				cd "$dir/$lab_name-$student_username"
				compile-and-test
			else
				echo "  Lab does not exist."
			fi
			$quiet || echo ""
		done
	else
		# process all of one lab
		for I in `ls "$clone_path"/$lab_name`
		do
			$quiet || echo "Testing $I"
			$quiet && -n echo "$I"
			student_username=${I#"$lab_name-"}   # remove the lab name
			student_username=${student_username%"/"}  # remove trailing slash
			dir="$clone_path/$lab_name/$I"
			if [ -d "$dir" ]
			then
				cd "$dir"
				compile-and-test
			else
				echo "  Lab does not exist."
			fi
			$quiet || echo ""
		done
	fi
fi

$quiet || echo "Done."
