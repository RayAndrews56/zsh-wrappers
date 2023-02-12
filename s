#!/usr/bin/zsh

: <<'COMMENTBLOCK'

# This is a 'save/restore' incremental backup utility.  It depends on 'ffind_match()' in file 'try' (three calls here).

2022-11-18: Write 'forced' message in one go.

2022-10-27: BUG. If the last backup number is duplicated -- which shouldn't happen but it does -- without '(Y1)' the duplicated number is ignored and we keep counting down.  

2021-08-10: BUG! need shortest match test here:

2021-08-06: Huge rework, most old code gone probably go back to 's,61' for last stable.

2021-08-05: This form is better.  Previous would capture: 'd,1garbage' which can't be a backup.

COMMENTBLOCK

# Can be increased or decreased as desired, but the impact on speed is noticable:
integer MAXIMUM_BACKUP_NUMBER=200

# Restore backup either by given backup number or else the last backup is restored automatically:
# $ s ,r s 4 ... will restore " s,4... " to " s "
# $ s ,r s   ... will restore the last backup unless there is an ambiguity.

# $1 is target basefile, $2 is the backup index number.
function _restore ()
{
	# Global variable holds one matched filename, either exact or completed.  Set in 'ffind_match()':
	MATCH_FOUND=
	local aaa=
	local iindex=
	local rv2=

	# We have $2, so force backup to that specified index:
	if [ "$2" ]; then
		[[ $2 != <-> ]] && errormsg "That's not a valid index number." && return 1

		aaa="$1,$2"	# basename,index
		find_match "$aaa"
		rv=$?
	else # Automatic resore:
	for ((i=$MAXIMUM_BACKUP_NUMBER; i>0; i--)); do
		aaa="$1,$i"
		find_match ,n "$aaa" # ',n' prevents pointless 'not found' messages when counting down.
		rv=$?
		[ "$MATCH_FOUND" ] && break
	done
	fi

	[[ "$rv" < 2 || "$rv" = 5 ]] && rv2=1	# No matches or ambiguous.
	[[ "$rv" = 4 ]] &&
		{ local ffiles=( $1,$2*(N) ); print -l $ffiles; rv2=1 }

	# This is proof against: " c,12junk " being treated like a proper backup.
	[ "$MATCH_FOUND" ] &&
	{
		# Need '#' for SHORTEST match. Read: From the front, strip anything except a comma, then a comma:
		iindex="${MATCH_FOUND#*,}"
		# Read: From the end, strip a comma then anything else.  This should isolate the index:
		iindex="${iindex%%,*}"
		# A bogus index like " file,123four,comment " will be caught here:
		[[ $iindex != <-> ]] &&
		{
			warningmsg \"$iindex\" in: "\"$MATCH_FOUND\" is not a valid index!"
			rv2=1
		}
	}
	[ "$rv2" = 1 ] && warningmsg "No backup made, quitting" && return 1

	actionmsg "Copying \"$MATCH_FOUND\" to \"$1\""
	cp -v "$MATCH_FOUND" "$1"
	return 0;
} # END: _restore().

# =============================================================================
function s ()
{
# $ s file   [description] ... automatic save to next highest index.
# $ s file 2 [description] ... forced save to given number.
# $ s file ! [description] ... force overwrite of last backup.

# Initialization, switches and errors: ----------------------------------------

	[ ! "$1" ] && _s-syntax && return 0 # Force '-s' if no arguments
	[[ ${1:0:1} = '-' ]] && dash_switch s $1 && return $?

	local rrestore=		# Flag.
	local base_file=	# Base name of the file to be backed up or restored.
	local msg=			# Message string.
	local iindex=		# Backup index.
	local last_backup=  # Full name of last backup.
	local ddescription= # Passive holder of description.

	MATCH_FOUND= # Global variable set in ffind_match() in file 'try'.

	if [ ${1:0:1} = ',' ]; then
		for ((i = 1; i < ${#1}; i++)); do
		case ${1:$i:1} in
			r ) rrestore=1 ;;
			* ) errormsg "No such switch >,${1:$i:1}<"; _s-syntax; return 1 ;;
		esac
		done
		shift # Do this here. There might not be any switches!
	fi # Process switches.

	[ ! "$1" ] && errormsg "Nothing to do, insufficient arguments" && return 1
	[ ! -e "$1" ] && errormsg "Base file does not exist" && return 1

	base_file="$1" # Don't shift, we need $1 again below.
	[ "$rrestore" ] && { _restore $1 $2; return $? } # Only use of '_restore'.

# Get index to write to: ------------------------------------------------------

	# If $2 is a number then we are forcing to the named backup index.
	if [[ "$2" = <-> ]]; then
		iindex="$2"
		msg="Forcing write to index '${iindex}'."
		shift # We may have a description string ...

	# arg is not a number so find index automaticaly: Count DOWN to find backup number: (NB don't quote!)
	else
		for ((i=$MAXIMUM_BACKUP_NUMBER; i>0; i--)); do
			# Don't use ffind_match()!  Even if we have more than one match, that's ok here, we only want the highest index number so we can increment it.  Counting down should prevent any: ',1' vs. ',10' style ambiguities.

			# '(N)' don't worry about nothing found.
			# 2022-10-27: BUG. If the last backup number is duplicated -- which souldn't happen but it does -- without '(Y1)' the duplicated number is ignored and we keep counting down.  
			last_backup=( $1,$i*(NY1) )
			[ -e "${last_backup}" ] && break # We have our existing highest backup file.
		done # We now have highest used index.
		if [[ "$2" = '!' ]]; then
			iindex="$i" # When forcing, we use the current highest index.  Good for incremental backups without creating a new file.
			shift
		# Automatic backup will use next higher index.
		else
			# We only check for identical files in case of automatic backups.
			if [ -e "$last_backup" ]; then
				diff $base_file $last_backup &> /dev/null &&
					infomsg "\"$base_file\" is identical to previous backup '$last_backup'. Quitting." && return 0
			fi
			iindex=$(( i + 1 )) # Auto backup will use the next higher index.
			msg="Automatic backup."
			# NB no 'shift' here, we don't have an '!' or a number.
		fi
	fi # Automatic or forced index number has been found.

# Supposing there's more than one file matching the index? --------------------
	# {
	local aaa="$base_file,$iindex"
	find_match ,n $aaa # ',n' because there will normally be a 'not found'.
	rv=$?
	[[ $rv > 3 ]] &&
	{
		warningmsg "Ambiguous target, quitting."
		print -l $aaa
		return 1
	}
	# } scope

# Get any description string: -------------------------------------------------

	# We have our index, now check for a description string and append it. Note, even if forcing, an explicit description will still be used otherwise we salvage the previous.
	shift

	if [ "$*" ]; then # A description has been provided so use it:
		ddescription=",$*" # Add the comma HERE!
	else # No new description provided:

		# Salvage the previous description (with comma) if any.  NB there is only a trailing comma IF there was a previous description.  Read: "Strip anything except a comma, then a comma, then any number of digits, then a comma."  NB '##' for LONGEST MATCH in case more than one digit.:

		# Is this better?: In "file,123four" 'four' is NOT a proper description!  This demands proper form but puts the comma back latter:
		[ "$MATCH_FOUND" ] && ddescription="${MATCH_FOUND##*,<->,}"
		[ "$ddescription" ] && ddescription=",$ddescription"
	fi

# Some helpful messages: -----------------------------------------------------

	# If there is a forced overwrite. Prevent any duplicate index in case we are modifying the description which would create a unique filename.  NB 'nname' only exists IF there is an existing file with that index.
	# {
	local nname=( $base_file,$iindex*(N) )
	[ "$nname" ] &&
	{
		msg="Forcing overwrite of last backup: \"$nname\""
		rm -v $nname &> /dev/null
	}
	actionmsg "$msg"
	# } scope
# Now create the new filename and write it: -----------------------------------

	# Create backup file: basename plus new or overwritten index plus new or salvaged comment:  NB comma attaches to description; not added explicitly incase there is no description, which would leave a hanging comma.
	cp -v $base_file "$base_file,$iindex$ddescription"
	return 0
} # END: s().

# =============================================================================
function _s-syntax ()
{
echo -e "
$_common_syntax

s BASEFILE [BACKUP#] [STRING] ... Force backup/overwrite to specified BACKUP#.
s ,r BASEFILE [BACKUP#]     ... Restore BASEFILE from BACKUP#.
s BASEFILE   [STRING]      ... Automatic backup to next index number.
s BASEFILE ! [STRING]     ... Force backup/overwrite to last existing backup.
s ,r BASEFILE            ... Restore BASEFILE from the most recent backup.

BASEFILE: File to backup or restore.  A path can be used.
BACKUP#:  The 'counter' or index of the backup file to be saved or resored.
STRING:   A descriptive string to append to the name of the saved file.
'!':      Force overwrite of last backup.
"
} # END: _s-syntax().

# =============================================================================
function  _s-usage
{
_s-syntax
echo -e "
$grn USAGE:$nrm 's' (Save) is a sequential file backup/restore utility.

If there is nothing following 's', syntax help will be shown .

The files created by this function look like this:
'basefile,83,description string', where 'basefile' is the name of the file backed up, '83' is the backup number, automatic or forced, and 'description string' is just that.

$red s basefile $nrm
Will create 'basefile,1', if that file does not already exist; if it does exist, 'basefile,2' is created. Next time 'basefile,3' and so on. The next save number is found by counting DOWN from the value of the variable $MAXIMUM_BACKUP_NUMBER, thus if there is a 'hole' in the sequence of backup numbers (due to a backup having been deleted or renamed) it will be ignored and the most recent backup always has the highest number (unless otherwise renamed by the user or unless a backup number is forced).  In these 'automatic' backups, if the basefile has not changed since the previous backup, we abort with a message. (Why make a new backup if nothing has changed?  But you can 'force' a backup at any time, see below.)  Note that file timestamps are ignored.  If an older backup is edited or 'touch'ed, this function does not care.

You can add an aditional string after the name of the file to be saved, this is appended after the backup number, and is typically a description of that particular backup:
$red s basefile some comment $nrm
... Create: 'basefile,1,some comment'. (It might not be '1' of course.)  You can have spaces in the comment; best to quote.  You must quote if funny characters are included:
$red s basefile 'some ! funny () comment' $nrm

$red s basefile 10 $nrm
... Backup 'basefile' to 'basefile,10'.  This is a 'forced' backup since the backup number '10' is explicit and backup #10 will be overwritten if it exists.

$red s basefile 5 123some-comment $nrm
... Create or overwrite: 'basefile,5,123some-comment'.  A description may be added after the backup number but if no description is given any existing description for the given backup number will be reused:

$red s basefile ! some comment $nrm
... Backup 'basefile' to 'basefile,??,some comment', where '??' means the index of the last backup.  This is useful when you want to do a 'test-save-test-save' sequence without needing a permanent backup for each change, just to be sure that you can restore from the last change in case of a mistake.  As above, if the last backup has a description string it will be reused unless a new description is given.

Note that the second argument is 'smart': if it is a number or an exclamation mark, it will always be used as the backup number.  If is not a number, it will be used as the descriptive string. But note that if a backup number is given, then any following argument will always be interpreted as a descriptive string, so it can be a number or not.

You can specify a directory path different from the current directory and the backup will be done in that directory, but you probably won't want to do that very often.  All comparisons and file creations will be done in that directory.

This function is very careful to prevent duplicate backup indexes which are a very bad thing.  If there is confusion a message will be printed. If you force a backup, any existing backup of the same index will be overwritten irrespective of a different description (which would create a unique filename and so be quite possible as far as the OS is concerned.)  Also, if the last backup index is, say, 10, and you force a backup to index 20, note that the next automatic backup will be to index 21 -- you will hardly ever want to do something like that but you certainly can -- you might want to synchronize backup indexes between several different base files, for example.

$red s ,r basefile $nrm
Restore the last backup.

$red s ,r basefile 10 $nrm
Restore 'basefile,10[description]'.
"
} # END: _s-usage().
