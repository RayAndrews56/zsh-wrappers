#!/usr/bin/zsh

# Called from /root/.zshrc -> /aWorking/Zsh/Boot/zshrc
# zsh is /usr/bin/zsh -> /bin/zsh -> /aWorking/Zsh/Zsh-5.8/bin/zsh
# fpath="/aWorking/Zsh/Zsh-5.8/share/zsh/5.8/functions"
# 2021-02-09: Huge restructure.

#echo "Running .zshrc"

# ==============================================================================
# ESENTIAL GLOBAL VARIABLES:

ZSHBOOT=/aWorking/Zsh/Boot
# System wide, persistent 'dirstack' for use with function 'c'.
DIRSTACK=$ZSHBOOT/Histfile/dirstack
HISTFILE=$ZSHBOOT/Histfile/histfile
HISTSIZE=SAVEHIST=20000
#READNULLCMD=${PAGER:-/usr/bin/pager}
#EDITOR="mcedit"
#REPORTTIME=10	# zsh built in timer minimum.
#PAGER=/usr/bin/less
PATH=".:/aWorking/Zsh/System:/aWorking/Bin:/usr/local/bin:/usr/sbin:/usr/bin"
OLDPATH=$PATH
# fn: bright magenta filenames. ln: bright green line numbers:
#export GREP_COLORS='ms=01;31:mc=01;31:fn=01;35:ln=01;32:bn=32:se=36'
export GREP_COLORS='fn=01;35:ln=01;32'

source $ZSHBOOT/zbindkey # key bindings:
source $ZSHBOOT/zstyle   # 'zstyle' for all 'setopt' and 'zstyle' stuff.

# ==============================================================================
#{ PROMPT STUFF: (completely self-contained)

# NB, these must remain different from the color variables used elsewhere! >%{ ... %}< remind prompt that these chars have no length on the prompt.
_red=$'%{\e[1;31m%}'
_grn=$'%{\e[1;32m%}'
_yel=$'%{\e[1;33m%}'
_blu=$'%{\e[1;34m%}'
_mag=$'%{\e[1;35m%}'
_nrm=$'%{\e[0m%}'

local cc=$(print -P %L)
# Show shell level minus one so I don't accidentally 'exit' the xterm:
# 2021-02-17: Now minus two.  Why?
#let cc--
(( cc -= 1 ))
#       tty        dir     sh-level
PS1=$'\n$_tty $_yel%d $_mag$cc$_nrm $ '

# Non ticking clock:
# RPS1=$'%t %w'
# Ticking clock:
# %B = bold, %F{yellow} = start yellow, %D{..} = 'strftime' formatted string, %L = hour (12 hr), %M = minute, %S = second.
#RPS1='%B%F{yellow}[%D{%L:%M:%S}]%f %w'

PS3=$'\n $_grn Make a selection and press ENTER ... '
PS4='+%N:%i:%_>'  # '+', name of file, line number, type '>'

#} END PROMPT STUFF.

# -----------------------------------------------------------------------------
# XTERM:

# Make sure we're in an xterm! My 'chpwd' and 'preexec' are irrelevant if not.
# 2022-09-24: Debian 11 TERM is 'xterm-256color'.  This covers anything with 'xterm' in it:
#if [[ $TERM == 'xterm' ]]; then
	if [[ -z ${TERM##*xterm*} ]]; then # NB DON'T OMIT SPACES!
	_tty="${TTY#/dev/pts/}"

# Executed *after* every directory change: Note need to add current directory.  Set the variable 't[?]' with '?' being the number of the current xterm, and writes the '/tmp/tmp_to_env.[?]' file which, as before, does nothing but contain the command to set the appropriate variable 't[?] to the current $PWD in the current xterm.  'preexec' is unchanged, sourcing all '/tmp/tmp_to_env.*' files before anything happens in any terminal, thus keeping everything up to date. See also '###1' changes in 'c' and 'dupe_rt'.
	chpwd ()
	{
		# _PWD saves $PWD with protected quotes as in: >/aMisc/Aim point RA: 19h 20m 56s Dec: +33°43'42"_files< ... directory name contains quotation marks!
		_PWD=( ${(f)PWD} )

		eval "t${_tty}=\"$_PWD\"" # Eg: " t2=/usr/bin "
		echo "t${_tty}=\"$_PWD\"" >! /tmp/tmp_to_env.t${_tty}
		echo "$_PWD" >>! $DIRSTACK
		[ -e "LOCAL" ] && source LOCAL
	}
	chpwd	# Force the above on creation of every xterm.
	# This creates the title in the xfce4 terminals.  '-P': perform prompt expansion. '\e]0' and '\a' are needed or the 'real' prompt is buggered.
	print -Pn "\e]0; XTERM:$_tty\a"

	# We can do:
	# $ universal "trash=garbage"
	# and that var will be instantly available in other xterms:
	universal() { echo "$1" >>! /tmp/universal } 
	# ... 'universal' is called in 'preexec' ca. line 104 below.

	# Called before any command is executed.  Not called on start of new terminal, but called if 'zsh' is executed within a terminal.  Not called if just ENTER is pressed:
	preexec ()
	{
		local aa= 
		local bb=
		set +F # 'set +F' still needed.
		for aa in /tmp/tmp_to_env.t*; do
			bb=${aa#/tmp/tmp_to_env.t}	# 'bb' = the number of the terminal.
			if [ ! -e /dev/pts/$bb ]; then	# If no coresponding '/dev/pts/?' ...
				rm $aa						# Kill 'tmp_to_env' file and ...
				eval "t$bb="				# kill variable containing '$PWD'.
				continue
			fi
			# else, source file to set var to $PWD for each open terminal.
			source $aa
		done
		[ -e /tmp/universal ] && . /tmp/universal;

		
		COMMAND2=$COMMAND1
		COMMAND1=$COMMAND0
		print -lrv COMMAND0 $@
	} # end: preexec ().

	# 'precmd' follows 'preexec'. Called for anything that creates a new prompt, including starting a new terminal, '$ zsh' within a terminal or just pressing ENTER (which does NOT call 'preexec').
	precmd ()
	{
### 2022-10-22:
		LASTDIR=$( cat $DIRSTACK | tail -n1 ) 
		# echo "lastdir is: $LASTDIR" > /dev/pts/2
	}

fi # end: if 'xterm'.

# -----------------------------------------------------------------------------
# SOURCE:

# Finished functions are here:
cd /aWorking/Zsh/Source
# This avoids paths being shown if using 'enable_lines' (see 'aa-messagefunctions') -- functions must be sourced while 'cd'd to their home directory. " (.) " prevents error as for loop tries to read directories:
for aa in *(.); do source $aa; done
popd

