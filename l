#!/usr/bin/zsh

: <<'COMMENTBLOCK'
'l' is a wrapper around 'ls'.

2023-02-10: Back to perl.
2023-02-06: BUG! 78,79: this was colorizing final 'g' in: " $ l g* "
2023-01-18: BUG, 'useless' line code wasn't working.
2023-01-18: BUG, need space before 'ccase' in big string. ',C' was busted.
2023-01-18: Huge simplification of colorizing. one perl does everthing.
2023-01-18: When using ',R' no need to use dot for current directory.
2023-01-18: When using ',R' we always show CONTENTS! 
2023-01-01: Let's colorize dirs:
2023-01-01: If ,Rd then use t(), the output is nicer:
2023-01-01: Don't presume '.', if $1 is not a directory it is an error:
2022-10-25: BUG! Must have realpath to directory:

2022-09-27: Remember that directory names are case sensitive in terms of showing contents!

2021-01-07: Must quote piped grep strings!
Note, we must use the ' (#i) ' pattern match method for case insensitivity because 'ls' is by nature case sensitive.  Can't rely on grep!

Native 'ls' switches used here:

A = do not list . and ..

F = classify file type, append  * / = > @ |
	@ means symbolic link (or that the file has extended attributes).
	* means executable.
	= means socket.
	| means named pipe.
	> means door.
	/ means directory.

widths:
G = dont show group
g = like 'l' but don't list owner
l = detailed listing (not using this right now).

These *native* switches are optional:
r = reverse ( my ',u') that is: upside down, not backwards.
d = list directory entries instead of directory contents. NB 'my d' and 'ls -d' are not the same!
t = sort by modification time.
R = recursive.  NB arg only applies to dirnames not to files!

Not preferred:
h = human readable sizes eg: '9.3K' ... not detailed enough.

COMMENTBLOCK

# Variable stores prefered switches but can be overridden.
l_switches=",w2v"
alias l='noglob _l'
function _l ()
{
	[[ ${1:0:1} == '-' ]] && dash_switch l $1 && return $?
	# NB variables are persistent! Must initialize here in case fce is run without switches, thus giving no chance to reset varaibles below.

	local to_history=	# Global flag for writing to history list.
	local sstring=		# Passive.  Final command string to send to 'execute'.

# What is shown:
	local ffilespec='*'	 # One or more filespecs.  Default is 'all files'.
	local ccase='(#i)'	 
	local case_msg='INsensitive' # Pattern filter on filespec.
	local filetype=
	local filetype_msg='All file types'
	local dirnames='d'	 # ls switch: show directory names, not contents.
	local rrecursive=
	local recursive_msg=''

# Information shown:
	local wwidth='Gg'	# 'Same as: w2'.

# How it is shown:
	local cclassify='F'	# ' ls -F ' adds classification characters to output (eg. ' / ' for directories ). Kill in case of 'bare' listings?
	local uupsidedown='r'
	local upsidedown_msg=' upside down '
	# Access time, modification time, size.
	local sortby='t'
	local sortby_msg="Mod. Time"
	local pplain=	  # Default is color.
	local bbare=	  # Firstish. No classify, no color, ls native or grep.
	local vverbose=   # Flag messages off by default.
# Passive:
	local ls_color=' --color=always' # 'ls' native colorizing.
	integer ii=''		# Counter.
# NO!:	integer sed_flag=''
	local sed_flag='' # Flag that ssed will remove permissions from output.

#------------------------------------------------------------------------------
# Process switches.

# 2021-01-12: Cool use of variable to preset switches :-)
for ((a=2; a>0; a--)); do # Grab switches from both sources or one or neither.
	[ $a -eq 2 ] && switches="$l_switches" 	# First pass reads variable.
	[ $a -eq 1 ] && switches="$1"			# Second pass reads CLI.
	[ -z "$switches" ] && continue

	if [[ ${switches:0:1} = ',' ]]; then
	for ((ii=1; ii < $#switches; ii++)); do
	case ${switches:$ii:1} in
#{ outdent
	H ) to_history=1 ;; # Flag used in 'execute'.
	C ) ccase=''; case_msg='Sensitive' ;; # Make case sens.
	R ) rrecursive='R'; recursive_msg='Recursive, ' ;;
	B ) bbare=1 ;;	# Dominant.  Kill color, messages, summary and give narrow listing.

# What is shown: (the list) ---------------------------------------------------

	# Select types based on ls's 'classify' character at END of line ('$'). Explanation of  symbols below.
	d ) filetype='/$';		filetype_msg='Directories'  ;;		# /
	e ) filetype='\*$'; 	filetype_msg='Executable Files' ;;	# *
	# Regexp: everything except > */=@| < then end of line.
	f ) filetype='[^*/=@|]$'; filetype_msg='Normal Files' ;; # No char used.

# The information shown: (info for each item on the list) ---------------------
	w )
		case "${switches:$ii+1:1}" in
			1 ) wwidth='1'   sed_flag=  ;; # NB ZERO TO OVERWRITE l_switches!
			2 ) wwidth='Gg'; sed_flag=1 ;; # Flag:use ssed to strip permissions.
			3 ) wwidth='g';  sed_flag=1 ;;
			4 ) wwidth='l'   sed_flag=  ;;
			* ) let ii--; warningmsg "No such subswitch \"${1:$ii+1:1}\"" ;;
		esac
		let ii++
	;; # end ',w'.

# How it is sorted: -----------------------------------------------------------

	# Timestamps: Lastish:
	a ) sortby='tu'; sortby_msg='Access Time' ;;		# '-u' requires '-t'.
	t ) sortby='t' ; sortby_msg='Modification Time' ;; 	# Default.
	s ) sortby='S' ; sortby_msg='File Size' ;;
	n ) sortby=''  ; sortby_msg='Name' ;;
	u ) uupsidedown=''; upsidedown_msg=' normally ';;

# How it is shown: ------------------------------------------------------------

	# Kill all coloring, ls_color=' ' Note, this is used when there is nothing to color anyway more than as a user option.  It is auto=set below.
	p ) pplain=1 ;;
	#  ',v' adds verbosity, ',vv' removes it.
	v ) [[ ${1:$ii+1:1} == 'v' ]] && { vverbose= ; let ii++ } || vverbose=1 ;;

	* ) errormsg "No such switch >,${switches:$ii:1}<"; _l-syntax; return 1 ;;
#} end outdent
	esac
	done
		[ "$switches" = "$1" ] && shift # AND there were actual switches.
	fi # END: switches.
done # Processing switches.

#------------------------------------------------------------------------------
# Process arguments.  Process some defaults.  Repair contraditions.


	# 2023-01-18: If a capital letter is given then force case sensitivity:
	[[ $@ == *[[:upper:]]* ]] &&
	{
		ccase=''; case_msg='Implied Sensitive' # Make case sens.
	}

	# 2023-01-01: If ,Rd is given then use t(), the output is nicer:
	[[ "$rrecursive" && "$filetype_msg" == 'Directories' ]] && 
	{
		# Make sure we have a valid directory:
		# 2023-01-17: default is current dir:
		[[ -d "$1" || ! "$1" ]] && t "$1" && return 0
		errormsg "No filenames! '$1' isn't a directory."
		return 1
	}

	# This the only place where dirnames (ls -d) is controlled: If arg is a dirname, show contents of dirname, not name of dirname because that's pointless.
	[ -d "$1" ] && dirnames='' 

	# 2023-01-18: 'l ,R .' and 'l ,R' now work the same, the dot isn't needed. And with recursion we always show dir contents. NB ls recursion only accepts filespec when it is a dirname, my 'l' will also show local files that match.  Local matches and subdir matches will both colorize: 
	[ "$rrecursive" ] && dirnames=''

	# Grab unglobbed filespec. 'execute' will expand it at execution. Multiple filespecs are permitted.
	[ "$1" ] && ffilespec=( "$@" )

	# By default if filespec matches a directory name EXACT we list CONTENTS (the files IN the directory).  But if ',R' is given then wildcard matches are accepted.
	# The ',d' switch makes a listing of subdirectories under the current directory or the target directory if given, it is a simple filter for the '/' char.
	# $ l Junk*  		Matching files and directories in current directory.
	# $ l ,d Junk* 		Matching only directories in current directory.
	# $ l Junk-in-junk 		All contents of subdirectory Junk-in-junk.
	# $ l ,d Junk-in-junk	All directories found under Junk-in-junk.
	# All 'contents' listing  now bare, why colorize the name of the parent directory when what we are showing is contents in which a match is incidental.

	# Case switch is irrelevant to *contents* (what string would you match?) But it is relevant to matching directory names themselves just incase you have two directories with same spelling except for case -- unlikely but possible.

	# We select file types based on the visual output of ls (directories end in a '/' for example). Otherwise, no filtering at all:
	[ "$filetype" ] && filetype=" | egrep '$filetype'"

	# Dominant: kill everything fancy: kill 'cclassify' too?  Should we kill wwidth?
	[ "$bbare" ] && { ls_color= pplain=1 wwidth= vverbose= sed_flag= }
	[ $pplain ] && ls_color=

	# Remember that directory names are always case sensitive!
	[ "$dirnames" ] && ffilespec_msg="LISTING of \"$ffilespec\":" \
					 || ffilespec_msg="CONTENTS of \"$ffilespec\":"

# -----------------------------------------------------------------------------
# Create the string to execute:

	# Filter out " drwxr-xr-x 4 " stuff.  Sometimes the single digit before the filesize is two or three digits, seems to be with directories or at the root.
	[ "$sed_flag" ] && 
		local ssed_string=" | sed -r \"s/^(.{10} {1,3}[[:digit:]]{1,3} )/ /\""

# Make execute string.  " ( (#i) ) " is a patern match on the list of files, not a 'ls' switch.
# Get rid of '(N)', ls ends up with no arument and so 'ls' shows entire directory!

	sstring=\
"ls --time-style='+[%F--%H:%M]' --group-directories-first\
 -A$cclassify$uupsidedown$wwidth$dirnames$sortby$rrecursive\
$ls_color $ccase$ffilespec 2> /dev/null\
$filetype\
$ssed_string\
 | egrep -v '^total'"

# Sample:
# Fixed switch:
# "ls -A  is 'Always': Ignore only dot and dotdot directories (current and parent).
# --time-style='+[%F--%H:%M]' --group-directories-first : dirs always first.

# Variable switches:
#	   F : $cclassify : So far, always 'F': do classify.
#	   r : $uupsidedown : reverse sort.
#	   G : $wwidth : kill 'group' information always.
#	   g : $wwidth : wide format but kill owner information.
#	   d : $dirnames : If 'l ,d' is used, show directory names, not contents.
#	   t : $sortby : t, tu, S, '': time, mod. time, size or name.
#	   R : $rrecursive: recursive listing.
# --color=always : or blank for no color.
# (#i)junk 2> /dev/null : filespec and messages to null.
# (blank) $filetype:  Blank in case of no file type filtering, or "egrep ..."
# | sed -r "s|^(.{10} [[:digit:]] )| |": filter out " drwxr-xr-x 4 " stuff.
# | egrep -v '^total' : don't  want totals.
# | sed '/;34m\.\x1b\[0m\/$/d'" : remove useless line if no files found.

	# Get rid of useless 'dot' line when there is no match (eg)
	# " 1024 [2021-06-11--19:48] ./ "
	# NB only the dot is colored blue, it's easy to miss!
	[ "$pplain" ] && sstring+=" | sed '/] \.\/$/d'"	\
				  || sstring+=" | sed '/;34m\.\x1b\[0m\/$/d'"  # Colored blue by ls.

# -----------------------------------------------------------------------------
# Attend to messages, attend to colorization and execute:

	# If bare (',B'), no further processing, just _execute and return.
	[ "$bbare" ] && _execute "$sstring" && return 0

# Sample msg:
# CONTENTS of "junk": all file types, Recursive, INsensitive. Sorting upside down by: Mod. Time:

	[ "$vverbose" ] && infomsg "\n$ffilespec_msg ${filetype_msg}, ${recursive_msg}$case_msg. Sorting${upsidedown_msg}by: $sortby_msg:"

# 2023-01-18: Huge reworking, old code removed see build 76:
# We are NOT plain so colorize the filespec:
# Let's not have partly blue, partly red directory listings.  And colorization makes little sense with recursion since the point of the filespec is the DIRNAME not coincidental filename matches: (but this is maybe a personal preference). NB colorization will still happen to directories in 'normal' listing.
	[[ "$pplain" || "$filetype_msg" = 'Directories' || "$rrecursive" ]] ||
	{
		# The dot is taken as 'any character' by sed, so remove them.  NB eg: ' l ,d ./Znt ' is fine:
		ffilespec=${ffilespec//[\*?.]} # Strip off wildcards front or back.

#{
# PERL!!! This solves the 'greedy match' problem that sed has:

### 2023-02-06: BUG! this was colorizing final 'g' in test: " $ l g* "
# But this does work with dashes in directory names:
### 2023-02-10: Added '?' forces shortest match:
# Tests: $ l , $ l g*, $ l Test, $ l b2022-12-18-backup, $ l Znt/n*
	sstring+=" | perl -pe \"s|\] (.*?)($ffilespec)|\] \1${red}\2${nrm}|i\" "

# Most recent in use:
# Old sed but with pipe as separator, test: " $ l Test/cc "
#		sstring+=" | sed -r \"s|\] ([^$ffilespec|'']*)($ffilespec)|\] \1${red}\2${nrm}|i\" "  # Added INSENS.

#}
	} # $pplain

	# 2023-01-01: Let's colorize recursive dirs: (But this will catch any filename ending in a colon!)
	[ "$rrecursive" ] &&
		sstring+=" | sed -r \"s/(.[^:]*):$/${blu}\1:${nrm}/\" "

	_execute "$sstring"

# -----------------------------------------------------------------------------
# Totals:

	if [ "$vverbose" ]; then

	(( _execute_linecount == 0 )) && warningmsg "Nothing found" && return 1

	# Strip out dirname if any:
	local ddirectory=${1%/*}
	[ -d "$ddirectory" ] || ddirectory='.'
	# Must have realpath to directory:
	ddirectory=$( realpath $ddirectory )

	A=`du -Ssch "$ddirectory" 2> /dev/null | grep $ddirectory`
	B=`du -Ssch "$ddirectory" 2> /dev/null | grep "total$"`

	infomsg "\nItems found: $_execute_linecount\n\
Total bytes in directory \"$ddirectory\": ${A:0:4}\n\
Total including subdirs: ${B:0:4}"
	fi
} #END: _l()

# =============================================================================
function _l-syntax ()
{
echo "
$_common_syntax
l ,H{fde}{tasn}pvw[1-4]Brwc [FILESPEC[S]] [ZSH GLOBBING] ...

,H: command to History.

Listing: (File types): --------------------------------------------------------

,d: Directories only.  Only directories will be shown.
,e: Executable files only.
,f: Normal files only.
(default is all files).

,R: Recurse thru subdirs. (Use 'f' for recursive searches for files.)
,C: Case sensitive.

Width: how much information to show: ------------------------------------------

,w1: filenames only.
,w2: size, date, filename. (default)
,w3: owner, size, date, filename.
,w4: full 'ls -l' display.

Display: ----------------------------------------------------------------------

Sort by:
,t: modification time (default).
,a: Access time.
,s: file Size.
,n: Name (alphabetical).

,u: list upside down (reversed sort top to bottom).

,v: 'verbose': add messages top and bottom.
,vv: 'unverbose': cancel messages top and bottom.

,p: Plain: remove all color from listing.
,B: Bare listing, no color, no messages, file names only.

FILESPEC[S]:	Any filespecs.
(ZSH GLOBBING): See 'l -h'."
} # _l-syntax

# =============================================================================
function _l-usage ()
{
_l-syntax

echo -e "
${grn}USAGE: $nrm

'l' is a wrapper around 'ls'.

If there is nothing following 'l' the current directory is listed.

${red}l ,u ${nrm}
... List the files and directories in the current directory sorted upside down by date (the default).

${red}l ,w2 *.mp3 *.mp4 ${nrm}
... A wide listing of all '.mp3' and '.mp4' files in the current directory.

${red}l ,s *.c ${nrm}
... Listing of all '*.c' files in the current directory sorted by size.

${red}l ,vC /usr/src/*.c ${nrm}
... Case sensitive listing of all '*.c' files in directory '/usr/src' with messages shown. (Use ',vv' to kill messages and summary.)

If the filespec is an exact match for a (sub)directory, what is shown will be the *contents* of that subdirectory:
${red}l ,vv /usr/share ${nrm}
... show the complete contents of '/usr/share' with no messages.

As above, but show only the subdirectories under '/usr/share':
${red}l ,dvv /usr/share ${nrm}

${red}l ,dw4 /usr/src ${nrm}
... List all subdirectories under '/usr/src' (with maximum information).

${red}l ,Rd filespec ${nrm}
... if both ,R and ,d are given, we use the 't' command for more attractive output.  

Note, if you are looking for files that begin with a comma, but no switches are set, those files will look to 'l' like switches so do this:
${red}l , ,d* ${nrm}
... the 'blank' leading comma ends parsing for switches and the rest must be filenames.

 ==============================================================================

${grn}ZSH GLOBBING: $nrm

'l' supports zsh's 'glob qualifiers' exactly as does 'ls'. These are a set of flags in parenthesis at the end of each filespec (no space please).  This is just a brief introduction to what is possible. See:
${red}http://zsh.sourceforge.net/Doc/Release/Expansion.html (Section
'14.8.7 Glob Qualifiers') ${nrm} ... for more posibilities.

Filtering of search results can be done by several criteria:

Use the standard zsh globbing method for recursion:
${red}l **/c.* ${nrm}
... Find all files matching 'c.*' in the current directory and all
subdirectories.  This is quite different from the use of the ',R' switch:
${red}l ,R c* ${nrm}
... which would list all files within any directories matching 'c*'.

TYPE:
(.) regular files only, (/) directories, (*) executable files, (@)symlinks, (=) sockets, (p) named pipes, (%) device files, (%b) block files, (%c) for character files:

${red}l **/c.*(*) s.* ${nrm}
... Search recursively for all files matching 'c.*' that are executable, as
well as for all files matching 's.*' in the current directory only.

PERMISSIONS:
(r,w,x) readable, writeable, executable by the owner.
(R,W,X) ditto for any user.
(A,I,E) ditto for group members:

${red}l **/*(.x) ${nrm}
... Find all files recursively that are executable by the owner of the file.

You can use 'chmod' style permisions:

${red}l **/*(.:g-w:) ${nrm}
... Find all regular files recursively that don't have group write permission.

NAME OF FILE OWNER:
${red}l *abc*(u:root:) *xyz*(u:ray:) ${nrm}
... Filter filespecs for user 'root' and user 'ray'.

MODIFICATION OR ACCESS TIME:
(m) modification, (a) access. Search for exact times or 'before' (+) or 'after' (-). (d) days (the default), (M) months, (w) weeks, (h) hours, (m) minutes, (s) seconds:

${red}l *(*aM-1) ${nrm}
... Filter for all executable files accessed within the last month:

SIZE:
(L) size in bytes, (Lk)in kilobytes, (Lm) in megabytes, (Lp) in 512‑byte blocks.  Search for exact size, or larger (+), or smaller (-). 'exact size' here means the size rounded up to the next 'unit', and 'smaller' means smaller than the size rounded up to the next unit, so to be honest '(Lk-1)' matches nothing, and '(Lk-2)' matches files smaller than one kilobyte (stupid!).

${red}l **/*(.Lm+10) ${nrm}
... All regular files recursively larger than 10 megabytes.

These glob qualifiers can be combined. The results may be lengthy, but the power
is awesome:

${red}l *(u0WLk+10m0) ${nrm}
... All files owned by root (u0), user-writable (W), more than 10k in size (Lk+10) and modified during the last hour (m0).

Use (^) before a qualifier to negate it or (,) for logical 'or'.

${red}l /dev/sd[ab]?${nrm} : finds: /dev/sda3 or /dev/sdb9, etc.

${red}l ,v0 **/?,*[0-9]${nrm}
... Recursively, any char then a comma then any number of digits.

${red}l ,v0 **/?,[[:digit:]]#${nrm} : ditto, but note changed grammar.

List all of trycompare's backup files and delete them with prompting:
${red}l ,B *,??,*,[[:digit:]]$ | xargs -d'\n' -pn1 rm${nrm}

${red}l (g|f),3* ${nrm}: 'g' or 'f' then ',3' then anything.

Note: some of the above will screw up the default colorization which expects literal strings on the command line. If something goes wrong, try the ',p' or ',B' switches to turn colorization off.
"
} # _l-usage

return

#tests:

# Or: _function_test < filename
_function_test <<< "\

"


