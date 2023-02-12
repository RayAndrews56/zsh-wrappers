#!/usr/bin/zsh

# 2022-11-15: Removed ',a' switch from execute().  That func. simplified.
# History list panelized.

function h ()
{
[[ "$1" = '-h' || "$1" = '-s' ]] && echo "
h ,HCtr <SEARCHSTRING> [SEARCHSTRING(S)] ...

,H: Command to history.
,C: Make case sensitive.
,B: Bare: no messages, no color and not sent to npanelize.
,t: Add timestamps.
,r: Second and following SEARCHSTRING(S) will use regular expressions.

The first search of the history list is always autowild will be case
sensitive if ,C is given.  Normal shell rules apply:  A string with spaces in it must be quoted; anything single quoted will be preserved litterally even if it is a variable; variables will expand within double quotes.  Subsequent searches are filterings of what has come before.  By default subsequent searches follow the same rules as the first search:

${red} h '^grep' \"\$variable\" '\$variable' ${nrm}
... Finds '^grep' litterally, expands the first '$variable' but takes the
second one litteraly.  However:

${red} h ,R '^grep' '^aptitude' ${nrm}
... Forces the second string to be a regular expression thus the search is for
'aptitude' at the beginning of a line. NB, if ,t is given beware that a search for '^aptitude' will always fail since the beginning of the line will be a timestamp!!  This is counter intuitive.

BUG:
${red} h ,R \"grep\" \"^grep\" ${nrm} fails for some reason.  Do this:
${red} h ,R ' ' \"^grep\" ${nrm}
"\
&& return 0

	local to_history=
	local grepstring=		# The cumulative search and color command.
	local firststring=		# The first search string is handled specialy.
	local ccolor=33			# Start with yellow.
	local grep_case='-i'	# Default is insensitive, 'C' = sensitive. 
	local hist_case='(#i)'	# ditto. 
	local timestamps=		# Default is no timestamps, ',t' = include them.
	local rregex='-F'		# Default is literal strings, ',r' = regex.
	local grep_colorize='--color=always' # Default is color, ',B' = bare.
	local bare=

	if [[ ${1:0:1} = ',' ]]; then
	for ((i=1; i < ${#1}; i++)); do
	case ${1:$i:1} in
		H ) to_history=1 ;;
		C ) grep_case=''; hist_case='' ;; # Case sensitive.
		B ) bare=1, grep_colorize= ;;
		t ) timestamps="t[%F--%R]"  ;;
		r ) rregex=''  ;; # Regex ON. TODO: explore 'E' here: extended regexp.
		* ) errormsg "No such switch >,${1:$i:1}<"; return 1 ;;
	esac
	done
	shift
	fi

	firststring=$1
	while [ "$1" ]; do
		# We create an arbitrarily long string of 'greps' here:
		grepstring+=" | GREP_COLOR='01;$ccolor' grep $grep_colorize $rregex $grep_case -- '$1'"
		let ccolor++
		shift
	done

	# r:reverse, n:no event numbers, m:pattern t:custom timestamps 1: from first entry in history.
	[ $bare ] && _execute "history -rnm$timestamps \"$hist_case*$firststring*\" 1 $grepstring" && return 0

	# Silent!  Only create variable.
	_execute ,s "history -rnm$timestamps \"$hist_case*$firststring*\" 1 $grepstring"

#{
### 2023-01-19: Got n_list working.  I forgot the 'print -zr' !!
#	print -rl "$_execute_output[@]" | npanelize

n_init; n_list $_execute_output[@]
print -zr "$SELECTED" 	# Print to command line.
#}
	return 0
}

# Example:
# history -rnm "*find*" 1  | GREP_COLOR='01;'33 grep --color=always "find" |  GREP_COLOR='01;'34 grep --color=always "always" | GREP_COLOR='01;'35 grep --color=always "skip" | npanelize skip
