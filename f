#!/usr/bin/zsh

: <<'COMMENTBLOCK'

'f' is a wrapper around 'find'

2023-02-11: Use '*' as default, but only if ',S' and/or ',d':
2023-01-19: Add 'Nothing found' msg:
2023-01-19: If a capital letter is given then force case sensitivity:
2023-01-19: BUG! Going back to build 38: all slashes were being colorized!

2022-11-20: restrict 'look into directories' to when ,d is given, do we really want a list of file matches and directory matches AND list of files within the directories?  That's a bit unfocused so drop ,X switch and show 'ls' info within directories only when ',d' is given.  Besides ,X was useless if ,f or ,e were given anyway.

2022-11-16: Prune out /var:

NB If using xargs, final message is taken as input!!  Thus output must be bare.

' ,m ' switch is more trouble that it's worth.  Why would we not want to search mounted filesystems when my whole system revolves around mounted filesystems?  A local search can always be used if needed.

Multiple searches with find:
$ find -H -O3 . -warn -xdev -name f -o -name l

COMMENTBLOCK

alias f='noglob _f'
function _f ()
{
	# Force '-s' if no arguments
	[ -z "$1" ] && _f-syntax && return 0
	[[ ${1:0:1} = '-' ]] && dash_switch f $1 && return $?
# System:
	local to_history= 	# Write expanded command to history list.
	local sselect=		# Offer 'cd' selection.
# What is found:
	local ppath='.'
	local path_msg="current directory" # The directory to search.
	local nname=		# The search string.
	local rrecursive=
	local recursion_msg="(and subdirectories)"
	local ttype=
	local type_msg="all files" # File type. Default: 'all types'.
	local ttime=		# mtime or mmin.
	local llinks="-H"
	local links_msg="on command line only" # My: [A|N|C] = native: [L|P|H]
	local ccase="-iname"
	local case_msg="INsensitive" # Case insensitive search. (-name vs. -iname)
	local xecutable= 	# Flag for executable files serarch.
# What is shown:
	local ssort=
	local sort_msg='Unsorted.'
	local bbare=	# Strip to bare files esp. for use with xxargs.
	local ls_output=		# Show 'ls' info on matches.
	local ls_color=' --color=always'
# Passive:
	time_msg="(any date)"
	local grep_case='-i'

# -----------------------------------------------------------------------------
# Process switches.

	if [ ${1:0:1} = ',' ]; then
	for ((i=1; i < ${#1}; i++)); do
	case ${1:$i:1} in
# System:
		H ) to_history='yes' ;;
		C ) ccase="-name"; grep_case='' ; case_msg="sensitive" ;; # Case sensitive.
		# No color in case output used as input to another command.
		B ) bbare='yes'; ls_color='' ;;
		S ) sselect='yes' ;; # ,S implies ,d: directories only!
		# Exception: f() is the only command that is recursive by default. Lower case 'r' turns recursion OFF:
		r ) rrecursive=' -maxdepth 1'; recursion_msg="(no subdirectories)" ;;

# Link handling:
		# Default is command line links only which overrides find's default which is '-P': never follow.
		c ) llinks='-H'; ;; 
		a ) llinks='-L'; links_msg="always" ;;
		n ) llinks='-P'; links_msg="never" ;;

# Directory, executable file, normal file or link. Default = 'all'.
		d ) ttype=' -type d'; type_msg="directories" ;;
		f ) ttype=' -type f'; type_msg="normal files" ;; # Default.
		l ) ttype=' -type l'; type_msg="links" ;;
		e ) ttype=' -type f'; type_msg="executable files";
							  xecutable=" -executable" ;;
# How it is sorted:
		t ) ssort='t'	; sort_msg="Sorting by time/date." ;;
		s ) ssort='S' 	; sort_msg="Sorting by size." ;;
		n ) ssort=''  	; sort_msg="Sorting by name." ;;

# Add 'ls' information:
		L ) ls_output=1 ;; # Add 'ls' style information.

		* ) errormsg "No such switch >,${1:$i:1}<"; _f-syntax; return 1 ;;
	esac
	done
	shift
	fi

	# Select only when finding directories:
	[[ "$sselect" = 'yes' && "$ttype" != ' -type d' ]] &&
	{
		ttype=' -type d'
		warningmsg "You can only select directories. Forcing ',d'."
	}
# -----------------------------------------------------------------------------
# Process arguments, either path(s) or time/date filter:

	local nname=$1
### 2023-02-11: Use '*' as default, but only if ',S' and/or ',d':
	[[ ! "$nname" && "$ttype" == ' -type d' ]] && nname='*'

	[ ! "$nname" ] && { errormsg "Insuficient arguments"; _f-syntax; return 1 }

	# 2023-01-19: If a capital letter is given then force case sensitivity:
	[[ $@ == *[[:upper:]]* ]] && \
	{
		ccase="-name"; grep_case='' ; case_msg="Implied Sensitive"
	}

	# Kill default dot directory and default msg if we have specified directory.
	[ -d "$2" ] && ppath='' && path_msg=''

	while [ "$2" ] # Test $2 now, i.e. before 'shift'.
	do
		shift
		# We can do this: '$ f *file* . /bin' to search two directories.
		# We can do this: '$ f *file* $path' to search entire $path for '*file*'
		# Process path. Default is '.' (current directory) set below.
		# NB in a case like using '$path'--when that is not quoted, it consists of single arguments, so we string them together like this:
		[ -d "$1" ] && ppath+=" $1 " && continue
		# ... Note that if '$path' is double quoted, it exists as ONE argument, so the '-d' test fails.

		[[ "${1:0:4}" != "days" && "${1:0:4}" != "mins" ]] && continue
		# Process time filter.
		#{ scope:
		local time_msg1=
		local time_msg2=
		if   [ "${1:0:4}" = "days" ]; then ttime=" -mtime"; time_msg2="days"
		elif [ "${1:0:4}" = "mins" ]; then ttime=" -mmin";  time_msg2="minutes"
		fi

		if   [ "${1:4:1}" = '+' ]; then ttime+=" +"; time_msg1="older"
		elif [ "${1:4:1}" = '-' ]; then ttime+=" -"; time_msg1="younger"
		else errormsg "Bad argument: >$1<" && return 1
		fi

		integer num="${1:5}" # The number. Will be zero if not an integer.
		(( num == 0 )) && errormsg "Bad argument: >$1<" && return 1

		# Combine strings eg: "-mtime -" + "20" = "-mtime -20"
		ttime="$ttime$num"
		time_msg="$time_msg1 than $num $time_msg2"
	done # while [ $2 ]
	# If path is 'dot', leave the 'current directory' msg.
	[ "$ppath" != '.' ] && path_msg="$ppath"
		#} scope

	# Prune out /var, this is a system dir we never want to look into:
	[ "$ppath" = ' / ' ] && ppath=" / -path /var -prune -o "

	# NB If using xargs, this message is taken as input so kill it!!
	[ -z "$bbare" ] && infomsg "\nFinding: $type_msg $time_msg, named: '$nname' on: '$path_msg' ${recursion_msg}. Links followed $links_msg. Case $case_msg. $sort_msg\n"

# -----------------------------------------------------------------------------
# Make strings and execute:

	string="find -O3 $llinks $ppath $rrecursive -warn $ttype $ccase \
\"$nname\" $xecutable $ttime -print" # NB need '-print' if we are using '-prune'.

	# We are not making a directory selection, we want a listing:
	[ -z "$sselect" ] &&
	{
		[ "$ls_output" ] &&
		{
			local xxtended='d'
# 2022-11-20: Do we really want a list of file matches and directory matches AND list of files within the directories?  That's a bit unfocused so drop ,X switch and show 'ls' info within directories only when ',d' is given:
			[ "$type_msg" = 'directories' ] && xxtended=''

			# Emulate 'l, w2' output:
			string+=" | xargs -d'\n' ls -FGg$ssort$xxtended \
--time-style='+[%F--%H:%M]' --group-directories-first ${ls_color} \
| sed -r \"s/^(.{10} [[:digit:]] )/ /\" "
		}

		# We colorize unless name is only wildcards:

		# Exclude colorization also if 'bbare' or 'ls_output' are set: (we prefer ls colors over grep color):
		if ! [[ $nname = '*' || $nname = '?' || $bbare || $ls_output ]]; then
#{
# This colorizes only the stripped search string AND only the first match vs. grep which always colorizes all matches on the line: NB must use backreference!! otherwise replacement is forced to case of literal arg to function even if we are not SENS.
			nname=${nname//[\*?]} # Strip off wildcards front or back.
			string+=" | sed -r \"s|$nname|${red}&${nrm}|I\" "
#			string+=" | sed -r \"s|($nname)|${red}\1${nrm}|I\" "
#}
		fi

# Sample _execute $string:
# find -O3 -H .  -warn  -iname "J*"
# | xargs -d'\n' ls -FGg
# --time-style='+[%F--%H:%M]' --group-directories-first --color=always
# | sed -r "s|^(.{10} [[:digit:]] )| |"
# | egrep -i --color=always "^|J*"

		# NB use: ',n' or ',L' (ls) complains of not being able to find null line.
		_execute ,n $string
		[ "$bbare" ] && return 0
		(( _execute_linecount == 0 )) && warningmsg "Nothing found" && return 1
		infomsg "$_execute_linecount lines"
		return 0
	} # End: not making selection.

# -----------------------------------------------------------------------------
# We will be making a slection: (or auto 'cd' if single match).  NB 'string' here is not colorized and items are all directories: 'string' above is quite different.

	_execute ,s $string

	# If no matches, just quit.
	[ "$_execute_linecount" = '0' ] && warningmsg "Not found" && return 2
	# If only one match, cd to it.
	[ "$_execute_linecount" = '1' ] \
	&& 	{ actionmsg "Auto cd to single match ..."; cd "$_execute_output"; return 0 }

	echo

	# This works too: print -rl "$_execute_output[@]" | npanelize
	n_init ""
	SELECTED=	# Careful, if nn_list balks (as with _function_test()), we don't want old value lurking.
	n_list "$_execute_output[@]" # Quote to preserve blank lines around messages.
	# SELECTED is returned by nn_list:
	[ -n "$SELECTED" ] && { cd "$SELECTED"; return "$?" } # 'cd'. Returns '1' on error, '0' on success.
}

# =============================================================================
function _f-syntax ()
{
echo -e "
$_common_syntax
f ,HSrc{CAN}{fdel}{tsn}{BL} <FILESPEC> [PATH(S)] [<days,mins><+,-><INTEGER>]

System:
,H:  Command to History.
,S:  Offer 'Select' to 'cd' (implies ,h and contradicts ,fel).

Targets:
,r:  One directory only.  ('find' is normaly recursive).
,C:  Enable Case sensitive search.
,can:  Follow symbolic links: Command line only, Always, Never.
,dfel: Type of file: Directory, regular File, Executable file, symbolic Link. Default is to search for all types.

Output:
,tsn:  Sort by Time, Size, Name.
,B:  Bare listing, this is needed if 'xargs' will be used.
,L:  Add 'ls' information.

FILESPEC: The filespec to seach for.
PATH ...: The directory(s) to search, defaults to current dir.

[<days,mins><+,-><INTEGER>]:
	Filter files by age, either younger or older than
	INTEGER number of either days or minutes.
"
}

# =============================================================================
function _f-usage ()
{
_f-syntax

echo -e "
${grn}USAGE:${nrm}'f' is a wrapper around 'find'.

If there is nothing following 'f', syntax help will be shown.

${red}f c\* /etc /bin $nrm
... A simple search for files matching 'c*'in the '/etc' and '/bin' directories and their subdirs.

${red}f ,re *edit* \$path $nrm
... Search for any executable '*edit*' files on the path.  Note that ',r' should be used because the path is NOT recursive itself so we only want to search the directories actually named in the path, not subdirectories.

${red}f ,Cae c\* days+2 $nrm
... Show all files matching 'c*' under the current directory. SENS search, follow all symbolic links, show executable files only that are over two days old.  Note ',a' can result in endless loops!  Furthermore you'll see the same file shown more than once -- it's 'real' location and the symlinked location.

${red}f ,d >! outputfile $nrm
Find all directories under the current directory and print the colored list to 'outputfile'.  Note, when ',d' or ',S' is given, a default filespec of '*' is assumed.  In all other situations a filespec must be given.

${red}f ,rB *.bak days+100 | xargs -0 -d'\n' -p -I{} mv {} Backup_dir $nrm
Move all backup files, in the current directory only, that are older than 100 days to the backup directory.  Must use ',B' for bare listing!! 'xargs: -0': handle special characters like quotes and backlash as literal, '-d'\n'': split arguments on newlines not spaces, '-p': prompt, '-I{}': '{}' will indicate the position of the input (other chars might be used but '{}' is standard and pretty safe). ',t': verbose.

${red}f ,L c\* $nrm
Add 'ls' information to the output.  If ',dL' is given then show ls information for files within matched directories too.
There are no 'active' features of 'find' in this wrapper but you can pipe to 'xargs':

${red}f ,B filename . | xargs -pn1 rm $nrm
... Finds all files named 'filename' in the current directory and subdirs, and sends the uncolored list to xargs which prompts (-p) before removing each file found, one line at a time (-n1).

${red}f ,B *.back . | xargs -pn1 -I {} mv {} BackupDirectory $nrm
... Note the more complicated form when the input comes 'between' two parts of the command (where the '{}' is).  Again the ',B' switch must be used.

Or use ',H' then hit the up arrow to see the 'real' command, then modify it to suit, eg:
${red}f ,HB junk .$nrm
... now hit the up arrow, retrieving:
${red}find -H -O3  . -warn  -iname junk $nrm
... and add whatever 'xargs' or other command you want to pipe to.

Note that it's a good idea to just list the files before you take some action on them that might not be reversable. The above 'xargs' method seems better than the '-exec' method. (see 'man find')
"
}
