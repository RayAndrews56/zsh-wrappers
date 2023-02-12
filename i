#!/usr/bin/zsh

: <<'COMMENTBLOCK'

2023-01-24: describe-params much nicer:
2022-11-22: BUG! From build 56: parenthesis not quotes!

2022-11-1*: Add '-r' to all calls to 'pprint' so that '$ i red' shows:
typeset -g red=$'\C-[[31;1m'

2022-11-03: First sed: this highlights entire filename which must exist between the final '/' and the ':'. Note '\/'
2022-11-03: Test if the file is active (whence finds it):
2022-11-02: More elegant output of variables.
2022-11-02: Complete rethink of output:
2022-11-02: colorize symlink target, it's important not to miss.
2022-11-01: Complete rework of wwhence stuff.

2022-10-30: BUG: We must quote whole arg to execute for it to be saved to history and thus no backslashing of '|'.  This was also splitting on words, not ...

2022-10-30: Test for binary files BEFORE offering to view it.

2022-10-30: Modified execute to retain individual lines in output:

2022-10-29: Vast simplification: Of variable search; code 1/4 of the size.

2022-10-29: BUG! Using sed to do the filtering always gave us " *$1* " output -- there was no difference between: "*zsh" and: "zsh*" and: "*zsh*" IF the search was insensitive.  Now, using "(#i)" to insure case insensitivity, we can let typeset handle the wildcards acurately.

2022-10-28: Test for ACTIVE:

2022-10-28: Reworked verbosity.  Now: 0: kill messages.  1: default, normal display, 2: offer function deffinitions and file contents.  Avoid the  temptation to be too cute, offer functionality that's simple, rememberable and genuinely useful besides being easier to read code.

2022-10-28:  Have I ever really needed to strip the colors except with function_trace?  If I do: " $ i "path*" | stripcolors " will handle it with no grief.  So, remove all color stripping rather than adding more, since all the recent code is always colored.  Turns out only one block was modified, at ca. line 277.

2022-10-27: " $ i zsh ": " $ file /bin/zsh " will report 'pie-executable' even tho 'wwhence' correctly detects that: '/bin/zsh -> /user/bin/zsh', yet '/bin/zsh' itself is not a symlink because the symlink is that '/bin' is really '/usr/bin'.  So we add a call to 'realpath' to flag this issue when we can't call wwhence because a path has been given which whwence won't eat.

2022-10-25: Remove 'case': Why dumb down the output of 'file' especially when the list of outputs handled by the 'case' can be incomplete and thus result in an 'UNKNOWN' when the ouptpt is entirely known, just not one of the options in the 'case' list?  Good example of too much massaging of direct output of a command.

------------
THE TROUBLE WITH WWHENCE:

Note that scripts will only be found by wwhence if marked executable (chmod +x ...) and if the '-a' flag is used!!  This seems backwards:

'-m' handles wildcards (pattern searches), 'a' all files on path.
'-a' Do a search for all occurrences of name throughout the command path.
     Normally only the first occurrence is printed.
'-v' Verbose

/aWorking/Zsh/Source/Wk 4 $ whence -a zsh   
/usr/local/bin/zsh
/usr/bin/zsh
/bin/zsh

/aWorking/Zsh/Source/Wk 4 $ whence -am zsh	 # '-a' contradicts '-m' !!
/usr/local/bin/zsh
/usr/bin/zsh
/bin/zsh

/aWorking/Zsh/Source/Wk 4 $ whence -m zsh
/aWorking/Zsh/System/zsh					 	# missed above!

Let 'more' be plain text on the path:

$ whence -mav more
more is /bin/more

$ whence -mv more
more is /aWorking/Zsh/System/more

# When 'more' is executable no issues:

$ whence -mav more
more is /aWorking/Zsh/System/more
more is /bin/more

Order of precidence:  aliases first, they can even be named the same as some command that they invoke.  Reserved words.  Functions -- autoloaded have no precidence over other functions.  Builtins.  Finally executable scripts and binaries, neither has precidence.  

COMMENTBLOCK

alias i='noglob _i'

# Alias outside function avoids having to source this file twice before alias is found. '-w' (whole word) seems counterproductive. But we can get rogue matches in message text when the command is very short.  Color is green.  Three calls:
alias GREP="GREP_COLOR='01;32' grep --color=always" 

function _i ()
{
	[ -z "$1" ] && _i-syntax && return 0
	[[ ${1:0:1} = '-' ]] && dash_switch i $1 && return $?

	# '-U' automatically removes duplicates after realpath has expanded the dot (ca. line 129). This 'Fixed' $path works for wwhence as well :-)
	typeset -aU all_names=() # All names found by wwhence.
	local all_matches=()	 # All matches from 'ffind'
	local output_lines=()	 # Raw output from wwhence.
	local final=()		# Array for final output.
	local one_line=()	# Single line of wwhence output.
	local one_name=		# A single name stripped from wwhence output.
	local is_a_file=	# Filename if wwhence reports a file.
	local to_history=	# ,H
	local find_files=	# ',f' flag: use 'ffind' to search for files.
	local disable_msg=	# Flag disable messages.
	local var=			# General purpose variable.
	local sstrip=		# $1 stripped of wildcards.
	integer i=			# A counter.
	integer numfound=	# Count of items or lines of output.
	integer vverbose=1	# Normal display. '0': kill messages, '2': func deffs and view files.

	# All defaults are now case insensitive:
	local case_msg='Case INsensitive'
	local w_nocase='(#i)'	# ,C  Used once by wwhence.
	local f_nocase='i'		# ,c  Used by two calls to ffind.
	local msg='EXACT'		# Message for case and wildcard status.

	if [[ ${1:0:1} = ',' ]]; then
		for ((i=1; i < ${#1}; i++)); do
		case ${1:$i:1} in
			H ) to_history=yes  ;; # Only with non-verbose output.
			C ) case_msg='Case Sensitive'; w_nocase=''; f_nocase='' ;;
			f ) find_files='true';;	# Use 'ffind' to search for files.
			v )	vverbose=2
			# ^ If ',v' (no number following) presume maximum verbosity. The default verbosity is '3'.
			case "${1:$i+1:1}" in
				v ) vverbose=0 ;; # ',vv' = same as ',v0'
				0 ) vverbose=0 ;; # Kill messages.
				1 ) vverbose=1 ;; # Default: show messages.
				2 ) vverbose=2 ;; # Or plain ' ,v ' with no number.  Print function deffinitions and file contents too.
				* ) let i--    ;; # If unrecognized then it does not belong to ',v' and we cancel the 'let i++' below with 'let i--' here.
			esac
			let i++ # Additional increment to get past ',v?' not just ',v'.
			;; # end ',v'.
			* ) errormsg "No such switch >,${1:$i:1}<"; _i-syntax; return 1 ;;
		esac
		done
		shift
	fi

	rehash # Make sure that new files are found.

	(( vverbose == 0 )) && disable_msg=1  # Global variable.
	(( vverbose == 2 )) && { echo; path } # My 'path' command if verbosity = 4.
	(( vverbose > 0 ))  && echo # One newline below prompt.

	sstrip=${${1}//[*?]} # Cut off wildcards

	# If a capital letter is given then force case sensitivity:
	[[ $1 == *[[:upper:]]* ]] &&
	{
		case_msg='Implied Case Sensitive'; w_nocase=''; f_nocase=''
	}
	msg="$case_msg"
	[[ "$1" != "$sstrip" ]] && msg="$msg WILD" || msg="$msg TAME"

# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# If a path is given eg: | i "/bin/*zsh*" |, then we are only looking for the files in the filespec, just call i_files and return:

	# Any path must contain a slash so test for it:
	var=${${1}//[\/]}
	if [ "$var" != "$1" ]; then
	
		# 'normal files' (indicated by dot) includes executables but not symlinks so we can't use that test.  But we can exclude directories (which would be considered executable by ' -x ' test below):
		eval "all_files=( ${w_nocase}$1(N^/) )"
	
		actionmsg "$msg search for the files specified: ${grn}\"$1\"${nrm}"
		for ((i=1; i <= $#all_files; i++)); do
			echo

# 2022-11-03: Test if the file is active (i.e. whence finds it):
# NB if you do: " $ i ,C $W/RAp " , it will be reported ACTIVE because, even tho it is not on the PPATH (EXCEPT if the current directory is $W), if you specify the full path to that command, it will run no matter your current directory so it is indeed ACTIVE.  Contrary wise if you do: " $ i RAP ", then $W must be your current directory in order for wwhence to find it otherwise it will not be reported ACTIVE.
local active=$( whence -v "$all_files[i]" | grep " is $all_files[i]" )
[ "$active" ] && redline "ACTIVE:  $all_files[i]"

			_i_files "$all_files[i]"
		done
		return
	fi

# -----------------------------------------------------------------------------
# Search for variables:
#{
	# 2023-01-20: Huge simplification.  Use my 'v()' now:

	# EXACT: (SENS AND TAME):
	# We always do an exact search because we may as well be aware of an exact match even if the requested search was broader:
	actionmsg "\nEXACT search for all variables matching: ${grn}\"$sstrip\"${nrm} ..."
### 2023-01-24: describe-params much nicer:
#	v ,CX "$sstrip"
#describe-params $sstrip
v $sstrip

	# This msg applies to all serches below, not just variables:
	actionmsg "\n$msg searches for items matching: $grn'$1'$nrm ..."

	# NOT EXACT:
	# If we are EXACT eg: " i ,C PATH ", then there's nothing more to do so skip the next block, but if there were wildcards AND/OR ',C' was NOT used then we will also search for an insens match, wild or tame ($1 retains it's wildcards if any).  Note this search will be in addition to the exact search and may or may not find anything additional.
	[[ "$1" != "$sstrip" || w_nocase == '(#i)' ]] &&
	{
		actionmsg "\nFor variables ..."
		if [ "$w_nocase" = '' ]; then v ,CX "$1"; else v ,X "$1"; fi 
	}
#}
# -----------------------------------------------------------------------------
# Before using wwhence, check the path for unexecutable scripts that may be run via the dot operator. zsh searches for these on the path but wwhence does not look for them. Note as long as 'dot' is on the path, we don't need a separate search for local files:

	actionmsg "\nFor unexecutable scripts or text files on the path ..."

#{
###
	# ppath is path with the dot expanded, it is needed by 'ffind' which can't swallow PATH.  NB $path = $PATH but with spaces instead of colons so our local PATH just has the dot expanded as well (realpath can't act on PATH directly):
	typeset -aU ppath=( $( realpath -s $path ) ) 
	local PATH=$( echo $ppath | sed -r "s/ /:/g" )

# FIND COMMAND:
	# Filter out executables here, wwhence will catch them.
	# 'iwholename vs. 'iname' permits paths eg: " /bin/b* " BUT the path must be complete.  Careful not to search subdirs of path:
	_execute ,ns "find $ppath -maxdepth 1 -${f_nocase}name \"$1\" -type f ! -executable"
#} scope of ppath

	all_matches=( $_execute_output )
	numfound=$#all_matches # The number of matches.
	[ "$numfound" -eq 0 ] \
	&& infomsg "No unexecutable scripts or text files found." \
	|| infomsg "Found $numfound match(es):"

	# For all matching files:
	for (( i=1; i <= $numfound ; i++ )); do
		one_line="${all_matches[$i]}"
		echo
		_i_files "$one_line"
	done

# -----------------------------------------------------------------------------
# After unexecutable scripts or text files, now check for 'wwhence' command matches.  First we collect all wwhence output, trim it down to just names and then sort it and stip out duplicates (automatically via the 'typeset -aU all_names'). Switches: m=paterns, a=all occurrences, v=verbose, S=symlinks.  Note, '-a' switch ignores any non executable files on path.  '-S' shows full chain of symlinks, not just final destination as '-s' does.  We show full chain all the time. 

	actionmsg "\nFor aliases, reserved words, autoloads, regular functions and builtins,  Then searching the path for executable scripts and binary commands ..."

# WHENCE COMMAND:
	# Grab complete output including duplications. Item is first word. Split on newlines only.  wwhence finds files and symlinks but '-S' makes the links explicit:
	all_matches=( ${(f)"$( whence -mavS $w_nocase$1 )"} )

	# Trim output down to just names and remove duplicates: ('-U' above). 'LC_COLLATE=C' makes 'sort' case sensitive:
	all_names=( $(print -lr $all_matches | sed -r "s/ is .*//" | LC_COLLATE=C sort -d ) )

	# NB some names have more than one match, eg. an alias and a binary have the same name, thus this numfound can be less than the final numfound below:
	numfound=$#all_names
	(( numfound == 0 )) && \
	{
		infomsg "No alias, function, builtin, executable script or binary found on the path."
###		PATH=$OLDPATH
		return
	}

# -----------------------------------------------------------------------------
# Loop thru all commands found by wwhence. Obtain output of each wwhence call and append it all to one 'ffinal' array:

	for (( i=1; i <= $numfound ; i++ )); do
		# Convert each line into an array split on words because we will be processing the various words differently. Must protect newlines in aliases or ggrep buggers up printing a linefeed if it sees '\n' in the string.
###		one_name=( "${=nname[$i]//'\'/\\\\}" )
		one_name="$all_names[$i]"

# WHENCE COMMAND:
		# NB in case of multiple identities we can get more than one line of output here:
		output_lines=( "$( whence -avS $one_name )" )
		output_lines=( ${(f)output_lines} )
		# Append:
		final+=( ${output_lines} )
	done # END: Loop thru all commands found by wwhence.

		# We are finished with the moified PATH so restore the original:
###		PATH=$OLDPATH

	# ffinal looks ok when printed but since ooutput_lines can contain more than one line (in case of multiple identities), each element of ffinal can be more than one line, so we need the right code to 'flatten' the array:  Number of lines will now increase since multiline outputs above have been flattened:
	numfound=$#final
	infomsg "Found $numfound match(es):"

# -----------------------------------------------------------------------------
# We have our output with duplicate names removed, sorted and then re-whenced, now create full information and pprint it:

	# Mustn't reset this in the loop.
	local previousname=

	for (( i=1; i <= $numfound ; i++ )); do
	
		echo 	# Newline between all blocks of output.
		one_line=( ${=final[$i]} )	# Split on words:

		local truename="${one_line[1]}"
		local truetail="${one_line[3,-1]}"	# Skip ' is ' -- just the meat.
		local hiddenmsg=
		local expanded=
		
		# Second instance of the same name is 'hidden' by first instance:
		[ "$truename" = "$previousname" ] && hiddenmsg="${blu}HIDDEN: "
		previousname=$truename
		
		# wwhence output for a file eg: " RAP is ./RAP ".  The 3d word must be a filename with some path (even ' ./ ').  But a symlink can have more than three words.  Expand to realpath but don't follow symlinks, we want the local name of the link, not the file to which it points:
		expanded=$( realpath -sqe "$one_line[3]" )

		# If we have an expanded filename make that the new ttruetail, but not in the case of symlinks because we want to see the link explicitly.
		[[ "$expanded" && "${one_line[4]}" != '->' ]] && truetail="$expanded"
		
		print -r "${cyn}($i)TYPE: ${hiddenmsg}${grn}$truename${nrm} is $truetail"

		(( vverbose < 1 )) && continue

		# Regular file incl. binary and symlink:
		# In case whence reports a filename it is the 3d word in the output:
		[ "$expanded" ] && _i_files "$expanded"
	
		(( vverbose < 2 )) && continue

		[[ "$one_line" =~ 'is a shell function' ]] &&
		{
			inputmsg "\nPress 'y' to view the function declaration of $grn\"$1\"$yel or any other key to skip."
			read -sq &&
# TYPESET COMMAND:
				infomsg "\nFUNCTION DEFINITION:\n"; typeset -f $truename | expand -t4 # Expand tabs to 4 spaces.
		}
	done # END: loop thru all items found by whence.

# -----------------------------------------------------------------------------
# Offer 'ffind $1' for various selections of target directories on the system. NB we run this test only once against '$1' not for every file individually.

	if [ -n "$find_files" ]; then # ',f' switch.
		inputmsg "
Use 'find' to search for $grn'$1'$yel in ...
Press 'd': the entire filesystem minus mounts,
Press 'm': all Mounted filesystems under root,
Any other key defaults to : the Current directory:"

		local aaction=''
		read -sk1 key
		case $key in
			d ) aaction="/" ;;
			m ) aaction="/ -xdev" ;;
###			c ) ;&
			* ) aaction="." ;;
		esac
		advicemsg "Please wait ..."

# We must quote whole arg to execute for it to be saved to history and this requires no backslashing of '|'.  The former code was also splitting on words, not newlines which is useless if there are spaces in a filename; " -d'\\n' " fixes that. '-N' prevents file from columnizing output which makes it too wide.

# FIND AND FILE COMMAND:
# 2022-11-03: First sed: this highlights entire filename which must exist between the final '/' and the ':'. Note '\/' is the slash made litteral since the slash is also the sed separator.  Note '[^\/,:]': anything except EITHER a slash OR a colon, otherwise the entire line up to the colon would highlight.  This test makes sure only the last slash can start the match since previous slashes, starting to match, must end in another slash, thus breaking the pattern.
		_execute "find $aaction -type f -${f_nocase}name \"$1\" | xargs -d'\\n' file -iN 2> /dev/null \
		| sed -r \"s/\/([^\/,:]*):/\/${red}\1${nrm} :/Ig\" \
		| sed -r \"s/: (.*)/: ${cyn}\1${nrm}/\"" 

		advicemsg "\nSpecify a single file: \" i /path/somefile \" for more detailed information"
	fi # End of checking for files with 'ffind'.

} #End: i ().

# =============================================================================

# Function for matched files.  3 calls, one: for given paths, two: for scripts and text files found on the path, three: for executable files found by wwhence on the path.  One call per file.  Show 'LISTING', 'CONTENT' and if verbose = 2 offer contents of the file.
function _i_files ()
{
# FILE COMMAND:
# output eg: " c: text/x-shellscript; charset=utf-8  "
	
	local ccontent=( "${nrm}${=$(file -i "$1")}" )
	local var="OTHER: "	# Let's add types as we come across them.
	local var2=
	local prefix=

	[ -x "$1" ] 						&& prefix="EXECUTABLE "
	[[ "$ccontent" =~ 'x-empty' ]] 		&& var="EMPTY FILE: "
	[[ "$ccontent" =~ 'text/plain' ]]	&& var="TEXT FILE: "
	[[ "$ccontent" =~ 'symlink' ]]		&& var="SYMLINK: "
	[[ "$ccontent" =~ 'executable' ]]	&& var="BINARY FILE: "
	[[ "$ccontent" =~ 'perl' ]]			&& var="PERL SCRIPT: "
	# 'file' doesn't distinguish if file is executable or not so we must test:
	[[ "$ccontent" =~ 'shellscript' ]] 	&& var="SCRIPT: "

	outputmsg "CONTENT: ${yel}${prefix}${var}${nrm}$ccontent" | GREP "$1"

	(( vverbose < 1 )) && return

	# '$1' is full path but wildcards are stripped.
	var2=$( ls -Fl --time-style='+[%F--%H:%M]' $1 )

	# Colorize symlink target, it's important not to miss noticing that.
	[ "$var" = 'SYMLINK: ' ] && var2=$( echo $var2 | sed -r "s/( -> .*)/${red}\1/" )

	outputmsg "LISTING: ${nrm}$var2" | GREP "$1"

	(( vverbose < 2 )) && return

	# Show text of any script or text file:
	# text/x-shellscript; charset=us-ascii: ... with hashbang
	# text/plain; charset=us-ascii:         ... without hashbang
	if [[ "$ccontent" =~ "text/" ]]; then
		inputmsg "\nPress 'y' to view the contents of $grn\"$1\"$yel or any other key to skip."
		read -sq || return 0
		outputmsg "\nContents of $grn\"$1\"${nrm}:\n"; cat "$1" | expand -t4
	else
		warningmsg "\nCan't view binary files!"
	fi
} # End i_files().

# =============================================================================
function _i-syntax ()
{
	echo -e "
$_common_syntax
i ,{HCFv?} <alias, function, builtin, executable script or binary>  (wildcards ok).

,H: command to History
,C: Case sensitive search.
,f: Find more files.
,vv or ,v0: No messages, output data only.
,v1 (default): normal display with messages.
,v2 or ,v: print function deffinitions or file contents too.
"
}

function _i-usage ()
{
	_i-syntax

	echo -e "
USAGE: (i)nformation is a wrapper around 'whence', 'file' 'ls' 'typeset' and 'find'.

If there is nothing following 'i' this syntax help will be shown.

$red $ i \"/bin/*binary-file*\" $nrm
... If a path is given, 'i' displays information about the matched files including whether they are ACTIVE, that is, that 'whence' finds them and thus typing their name (without any path) at the command line and pressing ENTER will execute them.  (Of course, if they are executable files, supplying their full path and pressing ENTER will always execute them.) Quote anything with wildcards in it!

$red $ i *zsh* $nrm
If no path is given 'i' first searches for variables.  Next there is a search for non-executable scripts or text files on the path which might be sourced.  These  will be found by zsh if they are on the the path.

Finally 'i' searches using 'whence' for, in this order: aliases, reserved words, functions (including autoloads), builtins, text/scripts marked executable (chmod +x ... ) and binary executables. If a match is found and it is a normal file (text, script, binary or link), it then uses 'file' and 'ls' to display some information about that file.

If ',f' is given, 'i' offers to use 'find' to search more broadly for matching files, that is, beyond the path.  

Note that any 'dot' on the path will be expanded to its canonical value and if that creates any duplicates, they will be removed so that there are no double entries.  Symlinks on the path will be matched, and they show any chains of links up to the final target of the link.

The output consists of up to three lines:

(?)TYPE: .....
CONTENT: .....
LISTING: .....

TYPE is the output of 'whence'. If you see 'ACTIVE:' it means this file will be executed on the command line.  Conversely if you see 'HIDDEN:', another command by the same name will 'hide' this one.  For example, there might be an alias, a function and a binary command all having the same name -- by the rules of precidence the alias will be active and the other two 'HIDDEN'. 

CONTENT is the output of 'file' with a helpful summary preceeding.  Files only.

LISTING is an 'ls' listing.  Files only.

EXAMPLES:

${red} i ,C \"/bin/*zsh*\"${nrm}
... show information on any matching files. Case sensitive.

${red} i mtr*${nrm}
... Find any commands named 'mtr*' on the current path.

${red} i ,vf \"xfce*\"${nrm}
... Offer various broader searches for regular files as well as for commands and shows verbose output. Quote!
"
}

return

advicemsg "\nPlease wait for the prompt ..."

# From miscfunctions: 'N' = don't prompt since it's all being redirected.
_function_test N <<< "\
i /bin/*zsh*
i *rap*
i path
i *path*
i ,C *path*
i ,C path
i *zsh
i zsh*
i *zsh*
i user
i *user*
i ,C *user*
i ,C user
i USER
i *USER*
i ,C *USER*
i ,C USER" >> /tmp/_function_test$RANDOM

return

# From miscfunctions:
_function_test <<< "\
i /bin/*zsh*
i *rap*
i *zsh*
i path
i *path*
i ,C *path*
i ,C path
i user
i *user*"

