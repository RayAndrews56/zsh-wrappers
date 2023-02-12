#!/bin/zsh

alias v='noglob _v'
function _v ()
{
	[[ "$1" = '-h' || "$1" = '-s' ]] && 
	{
	infomsg "
List atributes and values of all variables indicated by FILTER.

v ,CSsp [FILTER] [FILTER] ...

v ,C: SENS: (if FILTER is given).
v ,p: Plain, no color, this is good when the output will be sent to a file.
v ,n: Display only 'hideval' variables.
v ,h: Don't show 'hideval' variables.
v ,H: Show full values of 'hideval' variables.
v ,f: Full display of attributes in word form.

FILTER[S]: if given, are patterns of variable names.  No quoting is necessary if wildcards are given.  The default is all variables: '*'.

$red v ,H c* d* $nrm
... Show full attribute decriptions of all variables matching 'c*' or 'd*'

$red $ v p*

Hrhvs parameters = !hidden!
Arhvs patchars = !hidden!
Stes  PATH = .:/aWorking/Zsh/System:/aWorking/Bin:/usr/local/bin:/usr/sbin:/usr/bin
Ats   path = ( . /aWorking/Zsh/System /aWorking/Bin /usr/local/bin /usr/sbin /usr/bin ) ...
As    pipestatus = ( 0 )
Irs   PPID = 4218
Ss    PROMPT = $'\n$_tty $_yel%d $_mag$cc$_nrm $ '
...
$nrm

... The output consists of three fields: Firstly a full-words ( if ',f' is given) or abrieviated description of the variable attributes, then the name of the variable (normaly colored cyan unless ',p' is given), then the value, truncated if needed to the screen width.  The full-words descriptions are like those you can see using the 't' flag like this: '$ print ${(t)path}'. (do: man zshepn ... go to line 911 and look for 'Use a string describing the type of the parameter' for the full list.)  The abrieviated descriptions are identical to the switches typeset uses to set the attribute except where an exclamation mark is shown (in which case there will be an explanation in the comment).

The attributes can be usefully divided into the fundamental type, the status of the variable, and any display modifiers. First the abreviated then the full-words forms are shown in order of printing:

FUNDAMENTAL TYPES:   Types always come first and there can only be one:

i:  'integer' integer.
F:! 'float'   floating point number with scientific display (typeset -E).
F:  'float'   floating point number with decimal display (typeset -F).
s:! 'scalar'  ordinary scalar,not an integer or float (typeset default, no switch).
a:  'array'   normal array.
A:  'association' associative array or 'hash' (always 'hideval' as well).

STATUS ATTRIBUTES:

r:  'readonly' this often goes with 'special'.
h:  'hide'     only used with 'special' and 'local'.
H:  'hideval'  the value of the variable will be hidden -- there are things we
               really don't want to see, like lists of color codes.  This tends
               to go with 'special' and 'hide'.  However 'print' displays these
               values anyway, tho 'set' doesn't.
T:  'tied'     to another variable.
x:  'export'   to the environment and thus persistent within that terminal
               -- it will be inherited by subshells.
o:! 'local'    to the running function or process (typeset default, no switch).
s:! 'special'  to zsh.  A user cannot set this attribute.
t:  'tag'      lets you add this flag to any variable.
?:! 'undefined' for autoloaded parameters not yet loaded (whatever that means).
    (none)     there is no attribute word for global variables for some reason,
               it seems to be the default -- if it isn't local it's global
               (typeset -g). 

DISPLAY MODIFIER ATTRIBUTES:

U:  'unique'   duplicate values will be removed, saving the first instance.
l:  'lower'      displays as all lower case.
u:  'upper'        displays as all upper case.
R:  'right_blanks'  right justified and pad with blanks (spaces).
Z:  'right_zeros'     right justified and pad with zeros.              
L:  'left'              left justified and remove leading blanks.
LZ: 'left-right_zeros'    left justified and remove leading zeros (but not spaces).

To show only those variables that have a certain attribute, eg 'export' :

$red v ,f [FILTER] | g '-export' $nrm
"
return 
	}
	local _v_abrev=( sed -re "s/(^[^ ]*) ([^=]*)=(.*)/\1  \2 = \3/" \
     -e "s/integer[ |-]/i/" \
       -e "s/float[ |-]/F/" \
      -e "s/scalar[ |-]/s/" \
       -e "s/array[ |-]/a/" \
 -e "s/association[ |-]/A/" \
\
    -e "s/export[ |-]/x/" \
     -e "s/local[ |-]/o/" \
      -e "s/tied[ |-]/T/" \
   -e "s/special[ |-]/s/" \
  -e "s/readonly[ |-]/r/" \
      -e "s/hide[ |-]/h/" \
       -e "s/tag[ |-]/t/" \
   -e "s/hideval[ |-]/H/" \
 -e "s/undefined[ |-]/?/" \
\
 -e "s/unique[ |-]/U/" \
  -e "s/lower[ |-]/l/" \
  -e "s/upper[ |-]/u/" \
# NB the order below is critical! 
 -e "s/left-right_zeros[ |-]/LZ/" \
             -e "s/left[ |-]/L/" \
      -e "s/right_zeros[ |-]/Z/" \
     -e "s/right_blanks[ |-]/R/" \
# Columnize -- add too many spaces then grab first six chars:
 -e "s/^([^ ]*)/\1     /" \
 -e "s/^(.{6}) */\1/" )

	local _v_colorize=( sed -r "s/^(.[^ ]*)( *)(.[^ = ]*)/\1\2${cyn}\3${nrm}/" )
	local _v_width=$(( COLUMNS - 5 ))
	local _v_case='(#i)' # Default INSENS.
	local _v_hidevar=1	# Default, show hidevars as '!hidden!'.
	local _v_visible=1	# Default, show visible vars. (??)
	typeset -ga VARIABLES=()


	if [[ ${1:0:1} == ',' ]]; then
	for ((i=1; i < ${#1}; i++)); do
	case ${1:$i:1} in
		C ) _v_case= 	 ;; # Enable SENS.
		p ) _v_colorize= ;; # 'plain': no color.
		n ) _v_visible=  ;; # Don't display unhidden vars.
		h ) _v_hidevar=  ;; # Hide hideval variables.
		H ) _v_hidevar=2 ;; # Show FULL value of hidevars.
		f ) _v_abrev=( sed -re "s/(^[^ ]*) ([^=]*)=(.*)/\1:  \2 = \3/" ) ;;
		* ) errormsg "No such switch \",${1:$i:1}\""; return 1 ;;
		esac
	done
	shift
	fi	  # End: process ',' switches.

	# If a capital letter is given then force _v_case sensitivity:
	[[ $@ == *[[:upper:]]* ]] && _v_case=

	# Default is all params:
	# Get parse error: #	[ ! "$@" ] && set 1 '*'
	[ ! "$1" ] && set -- '*'

# $parameters is an associative array, so you can subscript it with [ ] to get the elements.  The keys of this array are parameter names. 

# (k) prefixing an associative array reference means to return the keys (normally the values would be returned), so now we have an array of parameter names.

# (o) prefixing any array reference means to sort ("order") the results, so we get the matching parameter names in alphabetical order.

# (I) in an associative array subscript means to return every element whose key matches a pattern, so instead of getting just one element it is an array of elements.

# ${(j.|.)var} means to join an array with vertical bars; here the var is @ for the positional parameters.  R: THIS CREATES AN ALTERNATION: 'bg|bg_bold|bg_no_bold|...'

# ${~something} means the value of something can be treated as a pattern, so the |-joined positional parameters form a pattern.

# "set --" replaces the original positional parameters with this array of parameter names.

	# This version is needed if more than one arg:
	set -- ${(ok)parameters[(I)${_v_case}${~${(j.|.)@}}]}

#{
### 2023-02-07: May as well colorize and space around equal sign:
	# If only one input, show everything and return:
	if [[ "$ARGC" = 1 ]]; then 
	outputmsg "\nExact match found: \n "; print -rl "${parameters[$1]} $( typeset -m -- ${(b)1} )" | sed -r "s/^(.[^ ]*)( *)(.[^=]*)=/\1\2${cyn}\3${nrm} = /"
	 return 0
	fi
#	[[ "$ARGC" = 1 ]] \
#	&& print -rl "${parameters[$1]} $( typeset -m -- ${(b)1} )" && return 0
#	local _v_colorize=( sed -r "s/^(.[^ ]*)( *)(.[^ = ]*)/\1\2${cyn}\3${nrm}/" )
#}

	while ((ARGC)); do
		if [[ -${parameters[$1]}- = *-hideval-* ]]; then
			if [[ "$_v_hidevar" == '1' ]]; then # Show hideval values as '!hidden!':
				#           attributes        name and '=-hidden-':
				VARIABLES+="${parameters[$1]} ${(q-)1}=!hidden!"
			elif [[ "$_v_hidevar" == '2' ]]; then # Show entire hideval values:
				#           attributes        name and value:
VARIABLES+="${parameters[$1]} $( typeset -m -- ${(b)1} )"
#VARIABLES+="${parameters[$1]} $1=${(Pq+)1}"
			fi
		elif [[ "$_v_visible" ]]; then # Show vars that are not hideval.
VARIABLES+="${parameters[$1]} $( typeset -m -- ${(b)1} )"
#VARIABLES+="${parameters[$1]} $1=${(Pq+)1}"

# Actual string, then 'typeset' then '(Pq)':
#   ( sed -re "s/(^[^ ]*) ([^=]*)=(.*)/\1  \2 = \3/" -e "s/integer[ |-]/I/
# = ( sed -re 's/(^[^ ]*) ([^=]*)=(.*)/\1  \2 = \3/' -e 's/integer[ |-]/I/ ...
# = 'sed -re s/(^[^ ]*) ([^=]*)=(.*)/\1  \2 = \3/ -e s/integer[ |-]/I/ -e  ...
# '(Pq)' is more compact but misses the outer parenthesis.  This form is 4x faster too: " $ time (repeat 100 v) " is 6 sec, vs. 25 sec for the former. But 'color' is quite wrong using '(Pg)' -- need '${(kv)1}' for AAs.

		fi 
	shift
	done

	echo
	[ ! "$VARIABLES" ] && warningmsg "Nothing found" && return 1

	print -rl -- $VARIABLES \
	| ${_v_abrev:-cat} \
	| sed -re "s/^(.{1,${_v_width}}).*/\1/" -e "s/^(.{$_v_width})/\1 .../" \
	| ${_v_colorize:-cat}

} # END: v()

allvars ()
{
	# Name and type in long format:
	print -l -- "\n${cyn}ALL VARIABLES AND THEIR TYPES:${nrm} \n"
	printf "%-25s %s\n" ${(kv)parameters} | sort
	# Types only:
#	printf "%s\n" ${(v)parameters} | sort
}

# Variables that have no value: 'empty' or 'null'.  But '*, @, _, argv' show as null when they are not:
nullvars ()
{
	# OR:  "$ v | g ,r /'/'$ "
	# emulate -L zsh -o extendedglob
	nnullvars=()
	for name in ${(k)parameters}; do
		[[ -z "${(P)name}" ]] && nnullvars+=( "$name" )
	done

	print -l -- "\n${cyn}NULL VARIABLES:${nrm} \n"
	print -l -- "$nnullvars[@]" | sort
}

#describe-params()
dp ()
{
	emulate -L zsh -o extendedglob

	set -- ${(ok)parameters[(I)${~${(j.|.)@}}]}
	while ((ARGC)); do
		print -rn -- "${parameters[$1]} "
		if [[ -${parameters[$1]}- = *-hideval-* ]]; then
			print -r -- "${(q-)1}"
		else
			typeset -m -- ${(b)1}
		fi
		shift
	done
}

