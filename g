#!/usr/bin/zsh

: <<'COMMENTBLOCK'

'g' is a wrapper around 'grep'.

2023-02-09: ,W switch forces width of files column.
2023-02-05: ,w1 and ,w0 'change places'.
2023-02-05: Much editing.  Complete rework of arg parsing.
2023-02-05: $no_column > $ccolumn -- change polarity.
2023-02-05: BUG! ',w3' needs to be forced to ,w4:
2023-01-21: BUG! prevent 'naked' dash when there are no switches to grep.
2023-01-20: BUG! Add forced quotes around $1 this prevents the need for two levels of quoting eg:

2022-09-23:  The whole 'grep -e' thing seems to be a mistake, you get an 'either or' search not a 'both' search. 

2021-02-09: If filnames have spaces double quote all the single quoted filenames:
# $ g 'search string one' 'search string two' : " 'file names' 'with spaces' "

g $string "'any command'" : f i*  # Can use variable like this.

COMMENTBLOCK

alias g='noglob _g'
function _g () 
{
	# Force '-s' if no arguments
	[ -z "$1" ] && { _g-syntax; return 0 }

# Passive: the parsed command tail:
	typeset -a searchstrings=()	# The search string.
	typeset -a ffilespecs=() 	# The filespec to search, default is current dir.
	typeset -a ttail=()			# Native grep switches.

	local displaystring='|'     # The search string display.
	local msg=			# Message holder.
	local ccolumn=1		# Flag to columnize output.  Set if: ',w4'.
	local grep_prefix=	# Holds root 'grep' command: color=always or not.
	integer index=1		# An index counter.
	integer ccolor=31	# Start with red, >> green yellow blue magenta cyan.

# Active:
	local to_history=
# What is searched:
	local rrecurse=' -d skip' # Default is not recursive.
	local bbinary='I'	# Search binary files, default is NO.
# What is searched for:
	local ccase='i'		# Case insensitive search by default.
	local zsh_case='(#i)'
	local rregexp='F'	# Default is normal searches.  Regex OFF.
# How it is displayed:
	local ccontext=		# Number of lines of context, above and below.
	local wwidth='Hn'	# Default: show filenames, lines and found strings.
	local bbare=		# Dominant.  If set, no color, messages or columns.
	local disable_msg=  # Flag disable messages if ',B' is set.
###
typeset -gi g_max_file  # Zero on first run, but holds any value set at CL.

# Process switches: -----------------------------------------------------------

	[[ ${1:0:1} = '-' ]] && { dash_switch g $1; return $?  }

	if [[ ${1:0:1} = ',' ]]; then
	for ((i=1; i < ${#1}; i++)); do
	case ${1:$i:1} in
# Global switches:
		H ) to_history=1 ;;
		C ) ccase= ; zsh_case=	;; # Case sensitive.
		R ) rrecurse='r';;
		B ) bbare=1 	;; # Dominant.
# What is found:
		b ) # ,b or ,bb: # Show msg that a match was found or show contents.
			[[ ${1:$i+1:1} = 'b' ]] && { bbinary='ao'; let i++ } || bbinary='a' ;; 
# 2023-01-21: BUG! eg:
# $ set | g ,Cr "^PATH"
# ... created a grep with no native switches so the dash (which is added to $grep_prefix so that individual native switches don't have to add a dash each time) ... the dash ended up 'naked' which throws an error. Thus it must be removed or even better, replaced with another switch namely 'G'
		r ) rregexp='G';; # Regex ON. TODO: explore 'E' here: extended regexp.
# What is displayed:
		c ) # How many lines of context:
			case "${1:$i+1:1}" in
			[1-9] ) ccontext=" -C${1:$i+1:1}" ;;
				* ) let i-- ; warningmsg "\nNo such subswitch /"${1:$i+1:1}/""; return 1 ;;
			esac
			let i++
			;;
		w ) # Display width:
			case "${1:$i+1:1}" in
			0 ) wwidth='l'  ;; # List files with a match only.
			1 ) wwidth='c'  ;; # Ditto, but with count of matches.
			2 ) wwidth='h'  ;; # Found strings only.
			3 ) wwidth='Hn'; ccolumn= ;; # files, line numbers, and strings.
			4 ) wwidth='Hn' ;; # ditto but columnized (default).
			* ) let i-- ; warningmsg "\nNo such subswitch \"${1:$i+1:1}\""; return 1 ;;
			esac
			let i++
			;;
### 2023-02-09: Change width of files column: Dominant switch:
		W )
if [[ "${1:$i+1:1}" == <-> ]]; then
	(( g_max_file = ${1:$i+1:1} * 10 ))
	warningmsg "\n Forcing column display. Files column width: $g_max_file."
	wwidth='Hn'; ccolumn=1
	let i++
else
	warningmsg "\nNo such subswitch \"${1:$i+1:1}\""; return 1
fi ;;

		* ) errormsg "No such switch >,${1:$i:1}<"; return 1 ;;
	esac
	done
	shift
	fi

	# Do this here: check for no args following switches:
	[ -z "$1" ] && { errormsg "No search string given"; _g-syntax; return 1 }

	# NB can't columnize without color because sed looks for color change to anchor the special character.
	[ "$bbare" ] && { grep_prefix='grep -'; disable_msg=1; ccolumn= } \
				 ||   grep_prefix='grep --color=always -' # 'auto' does not work!

	# All searches need $case and $regexp so may as well append them here:
	grep_prefix="$grep_prefix$ccase$rregexp"

#{
### 2023-02-05: All parsing of command tail here now:
	#{
	local flag= # if: " $ g 'str1' 'str2' : -file : " force '-file' to be taken as filespec, not grep switches.

	integer ii=1
	# 1st section is search strings:
	for ((; ii <= $ARGC; ii++ )); do
		[[ $@[ii] == ':' ]] && break
		searchstrings+=( "$@[ii]"  )
		displaystring+="$@[ii]|"
	done

	(( ii++ ))
	# 2nd section is filespecs OR grep switches:
	for ((; ii <= $ARGC; ii++ )); do
		[[ $@[ii] == ':' ]] && flag=1 && break
		ffilespecs+=( "$@[ii]"  )
	done
	(( ii++ ))
	# Remainder of line should only be grep switches.
	ttail=( "$@[$ii, -1]" )
	
	# Smart arg: if we are given two 'sections', is the 2nd section filespecs or grep switches? If args start with a dash, assume switches, however if command tail finishes with a colon, then force 2nd section to be filespecs via flag.  This is useful if a filename begins with a dash.
	[[ ! "$ttail" && "${ffilespecs:0:1}" == '-' && ! "$flag" ]] \
		&& ttail=$ffilespecs && ffilespecs=
	#} scope of 'flag' and 'ii'.
#}
# Piped input: ----------------------------------------------------------------
# When piped input, code is much simpler and we execute imediately.  Only $case and $regexp switches are valid.  Note we will continue to use multi-colored searches here rather than the 'grep -e' OR search method:

	if [[ -p /dev/fd/0 ]]; then
###
	[ "$ffilespecs" ] && errormsg "No filespecs with piped input!" && return 0

# 2023-01-20: BUG! Add forced quotes around $1 this prevents the need for two levels of quoting eg:
#
# $ typeset -p | g 'export -T'
# Piped search for string(s): |export -T|
# grep: -T: No such file or directory
#
# ... we had to use:
# 0 /aWorking/Zsh/Source/Wk 1 $ typeset -p | g "'export -T'"
# ... but now it works with only the one set of single quotes.

		# Stuff searchstrings into positional params for easy handling:
		set -- $searchstrings
		# grep switches only apply to first search!
		# First itteration has no pipe symbol:
		grepline="GREP_COLOR='01;$ccolor' $grep_prefix $ttail -- \"$1\""
		shift

		while [ -n "$1" ]; do
			let ccolor++
			# Subsequent itterations need pipe symbol:
			grepline+=" | GREP_COLOR='1;$ccolor' $grep_prefix -- \"$1\""
			shift
		done

		msg="Piped search for string(s): ${cyn}$displaystring${nrm}"
		[ -z "$ccase" ] && msg+=" ${mag}case sensitive"
		actionmsg "\n$msg"

		_execute "$grepline"
		return
	fi

# Regular input: --------------------------------------------------------------

	# We must have at least one search string but if we have several, susequent searches are just multicolored SENS string filters handled in gg_column. What matters is the count of search strings, not the colon which might accidentally follow a single search string:
	if (( $#searchstrings > 1 )); then
	
### 2023-02-05: BUG! ',w3' needs to be forced to ,w4:
#		[ "$wwidth" != 'Hn' ] &&
		[[ "$wwidth" != 'Hn' || ! "$ccolumn" ]] &&
		{	wwidth='Hn'; ccolumn=1
			warningmsg "\nForcing ',w4' with multiple search. Switch ignored!"
		}
		# No context with multiple search! Filters will always remove context lines since there can't be a match there:
		[ "$ccontext" ] && 
		{
			ccontext=
			warningmsg "Can't have context with multiple search.  Switch ignored!"
		}
	fi

	# This will ignore any string that can't be expanded to an existing file:
	#	ffilespecs+=( $~@[ii](.N)  )
	[ ! "$ffilespecs" ] && ffilespecs='*'

	msg="Searching for string(s): ${cyn}$displaystring${nrm} in filespec(s): ${cyn}\"$ffilespecs\"${nrm}"

[ "$rregexp"  =   '' ] &&  msg=" REGEX: $msg"					# ,r
[ "$rrecurse" =  'r' ] && msg+=", recursive"					# ,R
 [ "$bbinary" =  'b' ] && msg+=", including binary listing"		# ,b
 [ "$bbinary" = 'ao' ] && msg+=", including binary contents"	# ,bb
   [ "$ccase" =   '' ] && msg+=", SENS"							# ,C
       [ "$ccontext" ] && msg+=", with context:$ccontext"		# ,c[1-9]
  [ "$wwidth" =  'l' ] && msg+=", showing filenames only"		# ,w0
   [ "$wwidth" = 'c' ] && msg+=", showing filenames + lines"    # ,w1
  [ "$wwidth" =  'h' ] && msg+=", showing strings only"			# ,w2
  [ "$wwidth" = 'Hn' ] && msg+=", showing filenames,lines + strings" # ,w4 ,w3

	infomsg "\n$msg"

	# The grep is complex since all file filtering is here.  Subsequent filtering and colorization is handled in gg_column but only case is honored.
	grepline="
$grep_prefix\
$wwidth$bbinary$rrecurse\
$ccontext $ttail \
-- '$searchstrings[$index]' $ffilespecs"

	_execute ,s "$grepline" # NB silent! gg_column will print output below after columnizing.

	# 2022-11-15: execute now returns errorlevel:
	(( $? > 0 )) && return 0

# Use extended char ASCII 127 (hex 7f) as the column marker.  sed search is for 'ESC[K' followed by either a ':' or a '-'. 'man grep' says colon is for matching lines, hypen for non-matching lines as when using 'grep -C2' -- we are showing two lines above and below the match, but only the matching line has the colon, the others have the hyphen. Sample 'grep -C2' output (minus the actual matching strings):

#working2-149-
#working2-150-
#working2:151:
#working2-152-
#working2-153-
	
	if [[ "$wwidth" = 'Hn' && "$ccolumn" ]]; then # Only if ',w4' which is forced if mutiple searches.
			
		# Need this in gg_column
		export searchstrings
		g_column 	# Uses _execute_output directly.
	else	# Anything less than ',4', no straigtening of columns:
		print -rl $_execute_output
		infomsg "$_execute_linecount lines"
	fi
} # End: _g

# =============================================================================

function g_column ()
{
integer max=50			# Default maximum width of filenames.
(( g_max_file > 0 )) && max=$g_max_file # If set, overwrite default value.

	# $remnant will be what's left as we progressively cut off each column from each row.
	typeset -a remnant=()
	typeset -a raw=()		# Each chunk up to and incl. \x7b.
	typeset -a trimmed=()	# Cut off colors and \x7b. Pad with dots.
	typeset -a evened=()	# Trim to size, all even.
	typeset -a final=()		# Glue chunks together.
	integer width=0			# Computed width of each column.
	integer len=			# Length of the list -- number of items.

	remnant=( "$( print -rl $_execute_output \
	| sed -r 's/(\x1b\[K[:-])/\1\x7f/g' )" )
	# ^ Read: end of color code then either a colon or a hyphen all replaced with the same string plus the special char.

	remnant=( ${(f)remnant} )
	len=$#remnant

# The output of g(), gives us two fields to columnize (filenames and line numbers) plus the found strings.  We must process the array twice for each column.  First, to find the widest element (the widest filename in the case of 'g()') and set that as the column width which can't be more than $mmax; we truncate any element longer than that.  We then pad with dots.  Second pass cuts each element in each line to the determined width ($aaa) and glues it to the final output line.  The third pass glues on the un-columnized remant of each line after filtering and colorizing.


	# For every line of input: trim off special char and append dots:
	for ((ii=1; ii<=$len; ii++)); do
			# Look for special character and break line there.  $rraw is up to and including the character, $rremnant is remainder.
		    raw[ii]="${(M)remnant[ii]#*$'\x7f'}" # Match anything up to special char.
		remnant[ii]="${(S)remnant[ii]#*$'\x7f'}" # Match all the rest of rremnant.
		# Trim off special char. and colors, last 17 chars: Fragile!
		trimmed[ii]="${${raw[ii]}[1,-17]}"	
		# If filename is too long, truncate:
		(( $#trimmed[ii] > max )) && trimmed[ii]=${${trimmed[ii]}[1,$max]}

		# $width is length of longest filename (or line number). No more than $mmax but maybe less.
		(( width < $#trimmed[ii] )) && width=$#trimmed[ii]

		# Pad with dots; just add too many, they'll be trimmed off below:  NB must get length BEFORE doing this.
		trimmed[ii]="$trimmed[ii]\
..............................................................................."

	done
	(( width > max )) && width=$max # Width can't be over max.

	# Go over every line again trimming to determined width: $width plus padding.
	for ((ii=1; ii<=$len; ii++)); do
		# Cut to width, all lines the same:
		evened[ii]="${${trimmed[ii]}[1, $((width+2))]}" # Pad two dots minimum.
# These show what's going on:
#varis $trimmed[ii]
#varis $evened[ii]
		# Append evened element to final output.
		final[ii]+=$evened[ii]
	done

	# 2022-11-18: Second pass now specialized -- no dots just colon. Simpler since no justification of line numbers -- not worth the trouble since following strings are ragged anyway:
	for ((ii=1; ii<=$len; ii++)); do
         final[ii]+=" ${(M)remnant[ii]#*$'\x7f'} "
		remnant[ii]="${(S)remnant[ii]#*$'\x7f'}"
	done

	# Third pass: append what's left AFTER colorizing for each search string in turn and deleting non-maching elements.

	ccolor=32	# red has already been used, start with green here.
	
	# We process each filter in turn because we can colorize the whole array in one gulp.
	for ((ee=2; ee<=$#searchstrings; ee++)); do
		# Colorize entire array in one go:
remnant=( ${remnant//(#b)($~zsh_case${searchstrings[ee]})/$'\e['$ccolor;1m${match[1]}$'\e[0m'} )

		# Zero non-matching lines but DON'T change the length of the array: 
		# Stephane's method :)
		# remnant=( "${remnant[@]/#%^*$~zsh_case${searchstrings[ee]}*}" )
		remnant=( "${(@M)remnant##*$~zsh_case${searchstrings[ee]}*}" )
		(( ccolor++ ))
	done
	
	# NB Can't append rremnant inside for loop above because there might be more than one search string to filter but we only append once.  If rremnant[ii] has not survived filtering then we kill the entire ffinal line since only matches are displayed:
	for ((ii=1; ii<=$len; ii++)); do
		[ "$remnant[ii]" ] && final[ii]+=$remnant[ii] || final[ii]=  
	done

	typeset -aU ffinal=( $final ) # Compact.
	print -rl $ffinal	# '-r' fixes problems with strange characters in filenames.
	infomsg "$#ffinal lines" # Must correct length since array is much compacted by subsequent searches.
} # End: g_column

# =============================================================================
function _g-syntax ()
{
echo -e "
$_common_syntax
${red}g ,HCRBr{b|bb}{w[0-4]}{W[1-9]}{c[2-9]} <STRING> [STRING] ... [: FILESPEC] ...
[: GREP SWITCHES] ${nrm}

${red}INPUT | g ,Cr <STRING> [STRING] ... : [GREP SWITCHES] ...${nrm}

,H:  command to History.
,C:  Case sensitive.
,R:  Recurse through subdirectories.
,B : Bare output, no coloring, no messages.

,r:  Regular expression mode.
,b:  search Binary files too (one line to show there is a match)
,bb: ... and show matches in context.

,w?  Width of display (amount of information). Default: ,w4: everything, columnized.
,w0: Just list files in FILESPEC that contain a match.
,w1: Ditto but include the count of the number of matches.
,w2: Show matching lines only.
,w3: Show files, lines and matches.
,w4: Ditto but columnize (default).

,W[1-9]: Set width of files column to 10 times given integer.  Dominant over ',w' -- if ,W is given ',w4' will be forced. Default width is 50.  Variable 'g_max_files' can be set at command line too.

,c[2-9] lines of context above and below the match (same as: 'grep -C[2-9]').

STRING:      The search String(s).
INPUT:        The output stream of some command piped as input to 'g'.
FILESPEC:      The filespecs (with optional path).
                (default is all files in current dir). Wildcards OK.
GREP SWITCHES:   Any 'native' grep switches may be appended.
"
}

function _g-usage
{
echo -e \
"
${grn}USAGE: $nrm

'g' is a wrapper around 'grep'.
If there is nothing following 'g' syntax help will be shown.

The STRING[S] can contain anything that 'grep' can swallow.  Standard shell rules on quoting apply.  You needn't quote the search string if it is a simple word with no spaces or special characters, otherwise quotes are need:
${red}g 'search string' : \"'file name' 'name with spaces'\" $nrm

If ',r' is given the string will be interpreted as a regular expression.  eg:
${red}g ,r '.,[[:digit:]][[:digit:]]' $nrm
... will search all files for a string matching: any character followed by a comma followed by two digits.  Use single quotes to avoid any expansions.

${red}set | g ,r ^path $nrm
... should show you 'path' and 'PATH' in your variables but only if they are at the beginning of a line (the caret forces that).

But if you want a variable to expand you can't use single quotes, do it this way:
${red}g \"$variable then some text\" $nrm

If there are no switches but the search string 'looks like' a switch, do this:

${red}g , -h $nrm
... the comma ends the switches so '-h' must be a search string.

*FILESPEC*[S] may include directory paths and/or wildcards. The default filespec is '*': all files in the current directory. Wildcards are ok. If recursion (,R) is used, then the default is to search all subdirs under the current directory, and if any filespecs are given, then they must be paths (directories) only. However \" --include=FILESPEC \" can be appended to the end of the command to narrow the search down to FILESPEC, but only one filespec can be given. 

${red}g ,R \"search string\" ~/Music/*.mp3 $nrm
... will NOT recurse, you must get rid of the ' /*.mp3 ' if you want recursion. or use:
${red}g ,R \"search string\" ~/Music --include=*.mp3 $nrm

${grn}MORE EXAMPLES: $nrm

${red}g ,b 'some string' $nrm
... A simple case-insensitive search for 'some string' in the current directory. Binary files will be searched as well as text files.  Note that you might have to use the ',b' option on more than real binary files, eg. with formated documents, because grep can be fooled by document control codes.

${red}g ,C 'now is the time' 'for all good men' : /speeches/*.txt $nrm
... Show lines that have both case sensitive strings in all '*.txt' files in '/speeches' directory.  The colon is mandatory whenever more than one search string is used.

${red}g ,R \"Beethoven\" : /music_catalogues /my_music $nrm
... Show all the 'Beethoven' listings fount in
'/music_catalogues' '/my_music' and their subdirectories.

${red}g ,R \"Beethoven\" : moonlight.mp3 $nrm
... Does NOT try to search all files named 'moonlight.mp3' in all subdirs!
In this case the ',R' switch tries to turn 'moonlight.mp3' into a path.
Try:
${red}g ,R \"Beethoven\" : : --include=moonlight.mp3 $nrm
... if there are wildcards note the double quoting:
${red}g ,R \"Beethoven\" : : "'--include=moonlight.*'" $nrm
... or DO include a path as well:
${red}g ,R \"Beethoven\" : /music* : "'--include=moonlight.*'" $nrm
... will search for all files matching 'moonlight.*' in any directory matching '/music*', and it's subdirectories.

${red}g \"[[:space:]] main(\" /usr/src/*.c $nrm
Search for function 'main' in all the '.c' files in the 'usr/src' directory.

${red}g ,c2 \"some string\" *.bak $nrm
'-c2' instructs 'g' to show two lines of 'context' both above and below.

'Native' grep switches can be appended:
${red}g ,H '-i \"wholedisk\"' g* -c $nrm
... Command to history, search for litteral string '-i \"wholedisk\"' in FILESPEC 'g*' and append the '-c' switch (count matches only) to the first grep.

Particularly useful native grep switches (that don't have 'g' equivalents) are:
-v: Invert match -- show only non-matching lines.
-x: The match must be a complete line.
-L: Show files that have NO match.
-w: Match must be a whole word in the normal regular expression sense:
( from 'info':)
     Select only those lines containing matches that form whole words.
     The test is that the matching substring must either be at the
     beginning of the line, or preceded by a non-word constituent
     character.  Similarly, it must be either at the end of the line or
     followed by a non-word constituent character.  Word-constituent
     characters are letters, digits, and the underscore.  This option
     has no effect if ‘-x’ is also specified.

Note that in case of multiple search strings, appended grep switches as well as native 'g' switches only effect the first search -- others are simple dumb string searches (tho case sensitive):

${red}g 'function _g ()' : g* : -x $nrm
... search all files matching 'g*' for the string 'function _g()' AND the string must consitute an entire line.

${red}g 'function' 'syntax' : g* c* : -w $nrm
... search all files matching either 'g*' or 'c*' for the string 'function' which must be a complete regexp word, and then filter again for the string 'syntax'.

${red}g ,w3rbRC '^string one' 'string two' : *.txt : -v $nrm
... ',w3' will be ignored since multiple searches must be use ',w4' display. The search will be recursive, include binary files and the first string will be considered a regexp.  The trailing '-v' also indicates that the first search will be inverted -- only NON-MATCHING lines will be shown. But the second string: 'string two', is simply a plain vanilla text filter of the output from the first search, the only switch that applies to it is ',C' (if given) -- case.  So in the above, we will see a display of lines that do NOT start with 'string one' but that DO contain 'string two', with both strings SENSE.

"

inputmsg "For complete information: '$ info grep'.  For a cut down version of the man page press 'y' or any other key to quit.  (Note, widen the terminal to at least 110 characters so the doc looks decent.)
"
	read -sq && e $Z/Doc/cut-down-mangrep
	return 0
}

return

# This is the original 'genric' version that processes both columns the same way and might be used elsewhere than here:
function g_column ()
{
	# $remnant will be what's left as we progressively cut off each column from each row.
	typeset -a remnant=()
	typeset -a raw=()		# Each chunk up to and incl. \x7b.
	typeset -a trimmed=()	# Cut off colors and \x7b. Pad with dots.
	typeset -a evened=()	# Trim to size, all even.
	typeset -a final=()		# Glue chunks together.
	integer width=0			# Computed width of each column.
	integer max=50			# Maximum width of filenames.
	integer max=50			# Maximum width of filenames.
	integer len=			# Length of the list -- number of items.
#{
### 2022-11-13: use _execute_output directly, no need for the intermediate file in /tmp:
remnant=( "$( print -rl $_execute_output \
	| sed -r 's/(\x1b\[K[:-])/\1\x7f/g' )" )
	# Read: end of color code then either a colon or a hyphen all replaced with the same string plus the special char.

remnant=( ${(f)remnant} )
len=$#remnant
#}
# The output of g(), gives us two fields to columnize (filenames and line numbers) plus the found strings.  We must process the array twice for each column.  First, to find the widest element (the widest filename in the case of 'g()') and set that as the column width which can't be more than $mmax; we truncate any element longer than that.  We then pad with dots.  Second pass cuts each element in each line to the determined width ($aaa) and glues it to the final output line.  The third pass glues on the un-columnized remant of each line after filtering and colorizing.

# The first two passes.  First we grab the filename, then the line number: 
for ((bb=2; bb>0; bb--)); do
	width=0
	# For every line of input: trim off special char and append dots:
	for ((ii=1; ii<=$len; ii++)); do
			# Look for special character and break line there.  $rraw is up to and including the character, $rremnant is remainder.
		    raw[ii]="${(M)remnant[ii]#*$'\x7f'}" # Match anything up to special char.
		remnant[ii]="${(S)remnant[ii]#*$'\x7f'}" # Match all the rest of rremnant.
		trimmed[ii]="${${raw[ii]}[1,-17]}"		 # Trim off special char. and colors, last 17 chars: Fragile!
		# If filename is too long, truncate:
		(( $#trimmed[ii] > max )) && trimmed[ii]=${${trimmed[ii]}[1,$max]}

		# $width is length of longest filename (or line number). No more than $mmax but maybe less.
		(( width < $#trimmed[ii] )) && width=$#trimmed[ii]

		# Pad with dots, just add too many, they'll be trimmed off below:  NB must get length BEFORE doing this.
		trimmed[ii]="$trimmed[ii]\
..............................................................................."

	done
	(( width > max )) && width=$max # Width can't be over max.

	# Go over every line again trimming to determined width: $width plus padding.
	for ((ii=1; ii<=$len; ii++)); do
		# Cut to width, all lines the same:
		evened[ii]="${${trimmed[ii]}[1, $((width+2))]}:" # Pad two dots minimum.
# These show what's going on:
#varis $trimmed[ii]
#varis $evened[ii]
		# Append evened element to final output.
		final[ii]+=$evened[ii]
	done
done # End: two passes.

# Third pass: append what's left AFTER colorizing for each search string in turn and deleting non-maching elements.

	ccolor=32	# red has already been used, start with green here.
	
	# We process each filter in turn because we can colorize the whole array in one gulp.
	for ((ee=2; ee<=$#searchstrings; ee++)); do
		# Colorize entire array in one go:
		remnant=( ${remnant//(#b)($~zsh_case${searchstrings[ee]})/$'\e['$ccolor;1m${match[1]}$'\e[0m'} )

		# Zero non-matching lines but DON'T change the length of the array; thank's Stephane:
### 2022-11-14: Stephane's method :)
#		remnant=( "${remnant[@]/#%^*$~zsh_case${searchstrings[ee]}*}" )
### Form from StackExchange:
		remnant=( "${(@M)remnant##*$~zsh_case${searchstrings[ee]}*}" )

		(( ccolor++ ))
	done
	
	# NB Can't append rremnant inside for loop above because there might be more than one search string to filter but we only append once.  If rremnant[ii] has not survived filtering then we kill the entire ffinal line since only matches are displayed:
	for ((ii=1; ii<=$len; ii++)); do
		[ "$remnant[ii]" ] && final[ii]+=$remnant[ii] || final[ii]=  
	done

	typeset -aU ffinal=( $final ) # Compact.
	print -rl $ffinal			# '-r' fixes problems with strange characters in filenames.
	infomsg "$#ffinal lines" # Must correct length since array is much compacted by subsequent searches.
} # End: g_column
