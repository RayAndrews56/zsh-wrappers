#!/usr/bin/zsh

: <<'COMMENTBLOCK'

2023-01-17: If a capital letter is given then force case sensitivity:

2023-01-17: In practice we don't want '*$1*' searches here, but '$1*' -- "$ c M" should take us to subdir 'Misc' neverminding subdirs 'Empty' or 'Temp'.  

2022-11-11: Fabulous imrovement thank's Roman!  No need to process line by line:

2022-11-10: Back to grep!  It's faster (40 sec vs. 43) and the sed separator character might show up in a search string!! Especially if it is '/' which it usually is.  

2022-11-07: The old method just looked for matched strings anywhere in the list. '-w' was imperfect since all sorts of characters legal in directory names are not official 'word' characters.  This method is retained if the ',w' switch is given otherwise we have a disiplined search of the final directory names only:

The buggery:  What I thought was splitting on newlines was in fact splitting on words, which you don't realize until a path with spaces in it shows up.  grep is happy to color all matches no matter how it is split, but the listing shows paths with a space on two lines.  Problem is with the 'print' of the variable so as to pipe to grep.  Solution is to do it one line at a time.

2022-11-06: Beauty! '-U' style array will remove duplicates which can happen when one of the wwholedisk finds is actually changed to and becomes a member of the rrecent list:

2022-11-06: Much improved, ,C and ,x are honored: in quick change to subdirectory.

NB MUST NOT quote like: " ( "$rrecent" ) ", or n_list() looks ok, but whole array is one element! '(f)' flag forces 'split on newlines' where needed.

COMMENTBLOCK

# Handle 'cd' with added messages:  Three calls. 1) a pathless and possibly incomplete directory name matches a local subdirectory so auto-cd to it. 2) There is only one match in the computed list of directories, so auto-cd to it. 3) A selection has been made from the nn_list().
function see-dee ()
{
	actionmsg "Changing to $1 ..."
	cd $1 &> /dev/null && return 0
	errormsg "Directory not found: $1"; return 1
}

# Use this variable to run test code:
#TEST_c=
#if [ "$TEST_c" ]; then
#else
#fi

# Or within the function catch special switch:
#if [[ ${1} == '.T' ]]; then
#TEST_c=1
#_test_c
#return
#fi

function c ()
{
	local case_msg='INsensitive' # For messages.
	local wholedisk_flag= 	# Search whole system.  Off by default, it's slow and usually we want a directory we've alerady been to.
	local zsh_case='(#i)'	# INSENS by default
	local grep_case='-i'	# INSENS by default
	local wild_msg='WILD'	# ditto.
	local scope_msg=		# ditto.
	local no_cd=		# Default: 'cd' if given argument produces only one match.
	local wide_msg=		# If we are given ',w' use older filtering.


	if [[ ${1:0:1} == ',' ]]; then
	for ((i=1; i < ${#1}; i++)); do
	case ${1:$i:1} in

		C ) zsh_case=''; grep_case=''; case_msg='Sensitive' ;; # Enable sensitive.
		T ) wild_msg='TAME' ;; 		# Force 'whole word' searches. Only applies to first filter.
		X ) zsh_case=''; grep_case=''; case_msg='Sensitive'; wild_msg='TAME'; scope_msg='EXACT' ;;

		a ) wholedisk_flag=1 ;;
		n ) no_cd='true' ;; 		# Prevent automatic 'cd' ... sometimes we want to see all possible matches.
		w ) wide_msg=' WIDE' ;;		# Old listing with match anywhere in line.
		* ) errormsg "No such switch \",${1:$i:1}\""; return 1 ;;
		esac
	done
	shift
	fi	  # End: process ',' switches.
	# WIDE forces WILD:
	[ "$wide_msg" = 'WIDE' ] && wild_msg='WILD'

# -----------------------------------------------------------------------------
# The 'quick and easy' uses:

	# " c - " Special case just: " cd - ", i.e. return to previous dir in this shell:
	if [ "${1:0:1}" = '-' ]; then
	   [ -z "${1:1:1}" ] && cd - && return 0 # No char directly after dash.
	   dash_switch c $1; return $? # But remember, we might have a 'dash switch'.
	fi

	# " c ... " Note, too many dots don't matter, just go 'up' the tree as far as possible.
	[ "$1" = '..' ] && { cd ..; return }
	[ "$1" = '...' ] && { cd ..; cd ..; return }
	[ "$1" = '....' ] && { cd ..; cd ..; cd ..; return }
	[ "$1" = '.....' ] && { cd ..; cd ..; cd ..; cd ..; return }

	# " c 2 " If $1 is a number, cd to the current directory in the terminal number specified (the uncolored leftmost number shown in the prompt).  If number is too big we continue.  LESSON: note how we use 'eval' to specifiy the current directory for the correct terminal, (eg. " $t2 " is the current directory on terminal #2).

	[[ "$1" == <0-99> ]] && eval cd \$t${1} &> /dev/null && return

	# " c . " Make 'dot' change to last dir changed to anywhere by any method. That way all terminals can 'synch' with: 'c .'. Note, this breaks convention!  This test must be above the next one or 'c .' would be captured by it since '.' is a valid directory.
	[ "$1" = '.' ] && cd $( cat $DIRSTACK | tail -n 1 ) && return

# -----------------------------------------------------------------------------
# Uses involving string arguments :

### 2023-01-17: If a capital letter is given then force case sensitivity:
[[ $@ == *[[:upper:]]* ]] && \
{
	zsh_case=''; grep_case=''; case_msg='Implied Sensitive'
}

	# " c [dir] ": 'cd' to subdirectory:
	# ',C switch respected.  If there is a matching subdirectory 'cd' to it.  To force going to the list use the ',n' switch or add a second argument.
	[[ -z "$no_cd" && -n "$1" && -z "$2" ]] && \
	{
		# Plain vanilla cd:
		[ -d "$1" ] && { see-dee $1; return 0 }

		local subdirs=()
		# Glob modifiers: '(#i)' = case insensitive, '/' = a directory, 'N' = continue on error.

#{
#2023-01-17: In practice we don't want '*$1*' searches here, but '$1*' which we might call 'half tame'.  Eg. if I do "$ c M" I'm thinking of the 'Misc' subdir, NOT the 'Empty' and 'Temp' subdirs as well.
#		[ "$wild_msg" = 'WILD' ] \
#			&& eval "subdirs=( ${zsh_case}*$~1*(/N) )" \
#			|| eval "subdirs=( ${zsh_case}$~1(/N) )"
#		eval "subdirs=( ${zsh_case}$~1*(/N) )"
### 2023-02-05: remove 'eval':
		subdirs=( ${zsh_case}$~1*(/N) )
#varis ,1 subdirs
#}
		[ "$#subdirs" -eq 1 ] && { see-dee "$subdirs[1]" && return 0 }
		# else, fall through to nn_list() display:
	}

# =============================================================================
# Uses involving nn_list():

# If no argument, or argument fails above, or we have more than one argument, or ',n' is given, remove duplicates from '$DIRSTACK', and offer an nn_list() selection:

# -----------------------------------------------------------------------------
# Read directory stack, remove duplicates and dead directories and resave:

# This code in 'zshrc':
# " chpwd () { eval "t${TTY[-1]}"; echo "$PWD" >>! $DIRSTACK; } "
# ... pushes new directories to the bottom of $DIRSTACK.  But in our nn_list() selection below we want the newest directories on top.  So we read $DIRSTACK into a temporary array '$ttemp', remove deletions and duplicates, invert the lines, and save the result in $ddir_list which will be used to make the directory list shown by nn_list().  $ttemp is then truncated to 45 lines, inverted again (back to 'right side up'), and written back to $DIRSTACK.

	local temp=( ${(f)"$(<$DIRSTACK)"} )	# Grab the dirstack to an array.

	# Remove deleted directories (or anything not recognized as a directory) leaving blanks:
	for (( aa = 1; aa <= $#temp; aa++ )); do
		! [ -d "$temp[$aa]" ] && temp[$aa]=
	done
	# Missing elements compressed automatically and duplicates removed, favoring topmost (U), from inverted array (O).
	typeset -aU recent=( ${(Oa)temp} )
	# Restore original order (newest last). $rrecent might be longer, but $ttemp is truncated to 45 elements.
	temp=( ${(Oa)recent[1,45]} )
	print -rl -- "${temp[@]}" >! $DIRSTACK # And write it back to dirstack.

# -----------------------------------------------------------------------------
# Create message strings:

	local scope_msg="Case $case_msg $wild_msg"
	[[ "$case_msg" = 'INsensitive' && "$wild_msg" = 'WILD' ]] && scope_msg='BROAD'
	[[ "$case_msg" = 'Sensitive'   && "$wild_msg" = 'TAME' ]] && scope_msg='EXACT'
	
	local final_msg="directories matching: ${grn}\"$@\"${mag} ($scope_msg$wide_msg):${nrm}"
	
	local action_msg="Searching all recent directories:"
	[ "$1" ] && action_msg="Searching recent $final_msg"
	[[ "$1" && "$wholedisk_flag" ]] && action_msg="Searching recent and system wide $final_msg"

	actionmsg "\n$action_msg"
#varis ,2 action_msg
# -----------------------------------------------------------------------------
# If we have arguments the list will be filtered and colorized. Besides searching recent directories, we will also check for global searches if ',a' is given.  (We ignore ',a' if there is no argument otherwise every directory on the whole system would show!)  Note, if we have no arguments then there will be no need for any of this -- $ccombined is already set to $rrecent and we're good to go.

	local wholedisk= 			# Holds system wide search for matches.
	local combined=( $recent ) 	# $ccombined holds both arrays but always shows $rrecent.  We are all done if no arguments.

	if [ "$1" ]; then # Ends ca. line 256.

		# Grab the 'wwholedisk' list if ',a' is given:
		[ -n "$wholedisk_flag" ] &&
		{
			[ "$wild_msg" = 'WILD' ] \
				&& eval "wholedisk=( $zsh_case/**/*$~1*(/N) )" \
				|| eval "wholedisk=( $zsh_case/**/$~1(/N) )"
		} # We have the wwholedisk.

#{
# 2022-11-07: The old method just looked for matched strings anywhere in the list. 'grep -w' was imperfect since all sorts of characters legal in directory names are not official 'word' characters.  The old method is retained if the ',w' switch is given otherwise we now have a disiplined search of the final directory names only.  NB 'cc' is a normal array!! We can't use rrecent here because as a '-U' array, it keeps reajusting it's own length!!
		local cc=( $recent )

		[ ! "$wide_msg" ] && \
		{
			local dirname=
			
			for (( aa = 1; aa <= $#cc; aa++ )); do
				# These are full paths of recently visited directories, $1 may be only a partial match if we are WILD.
				dirname=${cc[$aa]:t}

	if [[ "$scope_msg" = 'BROAD' 				 && $dirname == (#i)*$~1* ]] \
	|| [[ "$scope_msg" = 'Case INsensitive TAME' && $dirname == (#i)$~1 ]] \
	|| [[ "$scope_msg" = 'Case Sensitive WILD' 	 && $dirname == *$~1* ]] \
	|| [[ "$scope_msg" = 'EXACT' 				 && $dirname == $~1 ]]; then ; # Do nothing, we have a match.
	else cc[$aa]=	# Kill the line, it does not match.
	fi
			done
		}
#}

# -----------------------------------------------------------------------------
# Now we colorize the filter strings including the first which must be a proper directory name.
# Note, we can't use rrecent here since it recompacts automatically after each filter run.

		local color=31 # red >> green, yellow, blue, magenta, cyan.
		local filter=

	# 2022-11-11: Fabulous imrovement thank's Roman!  No need to process line by line:
		for filter in "$@"; do
	cc=( ${(M)cc:#*$~zsh_case${filter}*} )	# Delete non-matching lines
	# Colorize whole array in one gulp:
	cc=( ${cc//(#b)($~zsh_case${filter})/$'\e['$color;1m${match[1]}$'\e[0m'} )

			[ "$wholedisk_flag" ] && \
			{
	wholedisk=( ${(M)wholedisk:#*$~zsh_case${filter}*} )
	wholedisk=( ${wholedisk//(#b)($~zsh_case${filter})/$'\e['$color;1m${match[1]}$'\e[0m'} )
			}

			(( color++ )) # Next ccolor.
		done # Finished colorizing

# -----------------------------------------------------------------------------
# Temporarily combine $rrecent and $wwholedisk (if used) to test fo single match to 'cd' to.  No emptly lines or messages please. Beauty! '-U' style array will remove duplicates which can happen when one of the wwholedisk finds is actually changed to and becomes a member of the rrecent list:

		recent=( $cc ) # Compact the list since it will be full of holes also rrecent ans wwholedisk will probably have common directories so delete duplicates for purposed of 'cd':
		typeset -aU for_cd=( ${recent} ${wholedisk} )

		# Return if no matches:
		[ "$#for_cd" -eq '0' ] &&\
		{
			# If no matches recurse to 'normal display'.
			warningmsg "No results: $final_msg"
			sleep 2
			c # Why not just default to plain listing? NB recursion dangerous!
			return 0
		}
		# If only one match in either $rrecent' or $wwholedisk, 'cd' to it.
		[[ "$#for_cd" -eq '1' && -z "$no_cd" ]] \
		&& \
		{
			target=$( echo $for_cd[1] | stripcolors ) # Strip out colors!
			see-dee "$target"
			return "$?"
		}

# -----------------------------------------------------------------------------
# Now we add messages for the final list and send it to nn_list():

		msg1=":$mag Most recently visited $final_msg"
		msg2=":$mag System wide $final_msg"

		# Concatenate colored arrays including blank lines and messages.  NB colon as first char in messages means line will be skipped by nn_list().  Note, no message is printed when no ',a' is given or no filters.
		combined=( $msg1 "" $recent )
		[ -n "$wholedisk_flag" ] && combined+=( "" $msg2 "" $wholedisk )

	fi # END: if [ "$1" ]; then ... We have created the colored list.

	# In line below, " n_init $1 " would eliminate any line not containing '$1' thus removing all 'msg' lines and all blanks!  Use " n_init "" " to solve the problem:	Simpler to just kill ' $1 '?  Alas it doesn't work.

	# Return here when running performance tests: nn_list doesn't work with _function_test so just print the output:

	if [ "$TEST_c" ]; then
		print -l "${combined[@]}"	# This prints blank lines.  "print -l $combined": This skips blank lines.
		return
	fi

# -----------------------------------------------------------------------------
# Run nn_list:

	# Must define help screen *before* nn_list is called: (otherwise help only shows contents on 2nd call of this function): local array is fine.

	local help_body=(\
#   ============= no line longer than this: =================
	"Navigate with HOME, END, PGUP, PGDN, '^U', '^D'"
	"(half page up/down), Up or Down arrows, then ENTER or"
	"mouse click to 'cd' to directory."
	" "
	"'/' Starts search.  BACKSPACE. '^W' erase word (rare!)."
	"ENTER or Up arrow to return to directory list."
	""
	"'h' shows this help. 'q' quits the program."
	" Mouse works as you'd expect."
	" "
	"               Any key to exit help" )

	n_init ""
	SELECTED=	# Careful, if nn_list balks (as with _function_test()), we don't want to see-dee!
	n_list "${combined[@]}" # Must quote to preserve blank lines around messages.

	# SELECTED is returned by nn_list:
	[ -n "$SELECTED" ] && { see-dee "$SELECTED"; return "$?" } # 'cd'. Returns '1' on error, '0' on success.
} # END: c()

# =============================================================================
function _c-syntax ()
{
tabs -4
echo -e "
$_common_syntax
${red}SYNTAX:$nrm

c ,[CTX!][anw] [DIRECTORY] [STRING1] [STRING2] ...

,C: Case sensitive search.
,T: Tame search -- no autowild.
,X: EXACT search: dominant: TAME and SENSE.
,a: Search entire disk for matching directories, not just from $DIRSTACK.
,n: Don't 'cd' even if only one directory matches.
,w: Wide search for match anywhere in the list item (recent directories only).

DIRECTORY: 	'c' will attempt to match complete or partial directory names.
STRING:		Directory list will be filtered for items that match STRING.

$red c $nrm
... View the directory stack and make a selection where to 'cd' to.

$red c - $nrm
... 'cd' to previous directory in that terminal, same as: 'cd -'.

$red c . $nrm
... Change to last directory changed to on *any* terminal.

$red c ... $nrm
... cd to parent of parent directory, same as: 'cd ../..'.

$red c [NUMBER] $nrm
... Change to current directory of the terminal specified by NUMBER ( the leftmost number of my prompt).

$red c [DIRECTORY] $nrm
... If DIRECTORY is matched exactly and there is only one match 'cd' to it otherwise offer a selection. Case and TAME are honored.  The first possible match is a subdirectory of the current directory. Eg:

$red c /etc/def $nrm
Probably 'cd' to '/etc/default' in the current directory.

$red c /etc/init.d $nrm
'cd' to \" /etc/init.d \". Don't forget to fully qualify the path if you want a direct 'cd'.

$red c ,n [DIRECTORY] $nrm
... Even if DIRECTORY is matched offer a selection, don't 'cd'.

$red c ,aC [DIRECTORY] [STRING1] [STRING2] $nrm
... Show only directory paths that contain all strings (case sensitive) -- this is an 'AND' search, not an 'OR' search. Include all matching directories on the system too.  (Note, this can be slow.) Note the first search is 'smart' it will only match a proper directory name.  The searches following the first are simply pattern matches. 

$red c ,aX etc system $nrm
Show an EXACT listing, including all matches on the directory tree, that match both 'etc' and 'system'.
"
}

function _c-usage
{
_c-syntax
echo -e "
USAGE: 'c' is a wrapper around 'cd' that uses it's own directory stack (normally '/aWorking/Zsh/Boot/dirstack'  AKA '$DIRSTACK') which is persistent, global and removes duplicates.  The  45 most recently visited directories (the number is hard coded but easy to change) will be shown -- use the arrow keys to highlight the one you want to 'cd' too and press ENTER.

If arguments are given they filter the directory stack.  If ',a' is given (in addition to arguments) the whole system will be searched for matching directories. The filtering is WILD and INSENS by default.  ',C' forces SENS, ',T' forces TAME and ',X' forces EXACT (both SENS and TAME).  If there is only one match it will be 'cd' to (unless ',n' is given), otherwise the graphical selection window is shown.  Note if more than one argument is given the filtering is additive, that is, all the strings must be matched.  

$red c ,a zsh $nrm
... When we have matching directories nested we get this sort of thing:

/aWorking/Backup/${yel}Zsh${nrm}
/aWorking/Backup/${yel}Zsh${nrm}/${yel}Zsh${nrm}-5.8
/aWorking/Backup/${yel}Zsh${nrm}/${yel}Zsh${nrm}-5.8/share/${yel}zsh${nrm}

$red c ,ax zsh $nrm
... Notice that a tame match omits the second line because 'Zsh-5.8' would be a wild match:

/aWorking/Backup/${yel}Zsh${nrm}
\e[9;1m/aWorking/Backup/${yel}Zsh${nrm}/\e[9;1m${yel}Zsh${nrm}$\e[9;1m-5.8${nrm}
/aWorking/Backup/${yel}Zsh${nrm}/${yel}Zsh${nrm}-5.8/share/${yel}zsh${nrm}

Whereas the first argument given is always filtered properly by zsh looking for proper final directory names (honoring ,CTX) all subsequent searches are just dumb string matching filters which might match anywhere in a list item. The ',T' and ',X' switches are implied for these subsequent searches because dumb pattern matching has no idea how to expand a string to a proper directory name, however ',C' is honored:

$red c ,a zsh ing/Ba $nrm
... will show this match:

/aWork${grn}ing/Ba${nrm}ckup/Zsh/Zsh-5.8/share/${red}zsh-common${nrm}

If the ',w' flag is given, then *all* fitering of the list is done via this same 'dumb' pattern match, this is the older method which would list items that matched anywhere in the item not just in the final directory name.  ',w' cancels ',T' and forces WILD searches (again because we are just doing simple pattern matches.  Note this only applies to the list of recent directories, the 'system wide' searches are unaffected.

$red c ,w 11/.th ail/Loc $nrm
... will match:
/aMisc/Backup-root-2022-10-${red}11/.th${nrm}underbird/i3n1gea2.Default User/Ma${grn}il/Loc${nrm}al Folders/ZSH.sbd
... not that any sane person is ever going to do that :-)
"
}

return

function _test_c ()
{

# [ ! "$TEST_c" ] && return

advicemsg "\nPlease wait for the prompt ..."

# Performance: sed method 43 seconds, grep method 40,51 seconds, native code 40,39 seconds.

timer start
_function_test N <<< "
c ,a bin etc; W
c ,aC Cursor; W
c ,aC Default; W
c ,aCT Zsh; W
c ,a curs; W
c ,a cursor doc usr; W
c ,a cursors; W
c ,aC Zsh; W
c ,aC zsh; W
c ,aC zsh share; W
c ,aC zsh W; W
c ,a gea2.Default; W
c ,an Oneyar; W
c ,aT zsh; W
c ,aw zsh; W
c ,aX Boneyard; W
c ,a xfce-perchannel-xml; W
c ,a xfce-perchannel-xml etc; W
echo zsh native code
" >> /tmp/_function_test$RANDOM
timer stop
}

return

# From miscfunctions: 'N' = don't prompt since it's all being redirected.

_function_test N <<< "
c ,a bin etc; W
c ,aC Cursor; W
c ,aC Default; W
c ,aCT Zsh; W
c ,a curs; W
c ,a cursor doc usr; W
c ,a cursors; W
c ,aC Zsh; W
c ,aC zsh; W
c ,aC zsh share; W
c ,aC zsh W; W
c ,a gea2.Default; W
c ,an Oneyar; W
c ,aT zsh; W
c ,aw zsh; W
c ,aX Boneyard; W
c ,a xfce-perchannel-xml; W
c ,a xfce-perchannel-xml etc; W
" 

