#! /bin/bash -x

username=$1
delete_type=${2}
if [[ -z $username ]]; then
	echo "Username is required: $username"
	exit 1
fi


out=$(sudo -H /cmscripts/audit_user --user $username)

if [[ -z $out ]]; then
	echo "Invalid username: $username"
	exit 1
fi

echo "$out"
echo
if [[ "$delete_type" == 'delete_dir' ]]; then
	echo "WARNING: Actually deleting filenames from remote servers: $delete_type"
elif [[ "$delete_type" == 'delete_cl' ]]; then
	echo "WARNING: Actually deleting changelists from perforce: $delete_type"
else
	delete_type=
fi
#echo "$out" | /usr/bin/perl -ne 'print qq{ssh root\@$1 "ls $2"\n} if m!^ \- (\w+):(.+)$!;'

prev_ifs=$IFS
IFS=$'\n'
echo D: $delete_type
if [[ "$delete_type" != 'delete_cl' ]]; then
    for cmd in $(echo "$out" |delete_type=$delete_type /usr/bin/perl -ne 'print qq{sudo ssh -oBatchMode=yes -oConnectTimeout=5 root\@$1 "} . ($ENV{delete_type} eq 'delete_dir' ? "rm -rf" : "ls") . qq{ $2"\n} if m!^ \- (\w+):(.+)$!;'); do
	echo "CMD: $cmd"
	res=$(bash -c "$cmd")
	echo "$res"

	#out="$out\n$cmd\nResult:$res"
    done
elif [[ "$delete_type" == 'delete_cl' ]]; then
	for cmd in $(echo "$out" |delete_type=$delete_type /usr/bin/perl -ne 'print qq{p4 change -d -f $1\n} if m!^(\d+)$!;'); do
	echo "CMD: $cmd"
	res=$(bash -c "$cmd")
	echo "$res"

	#out="$out\n$cmd\nResult:$res"
    done
fi

IFS=$prev_ifs

#echo -e "$out"
