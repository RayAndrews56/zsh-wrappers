# zsh-wrappers
my favorite zsh wrappers around common commands: grep, find, cd, etc.
This is my first use of github, a real README will follow once I get this thing up and running.

For now, very briefly: 

I've never uploaded or attempted to share any of my zsh coding.  I don't know what the protocols are, and my code is no doubt amaturish.  If anyone shows any interest in the functions here, I hope for reviews and improvments from competent zsh users!  The 'zshrc' and 'zstyle' files are my zsh bootup files, they are included just in case anything there is needed.  At the very least the 'preexec()' and 'precmd()' and 'chpwd()' functions in 'zshrc' are needed for my 'c()' function to work. 'zstyle' is there just in case any of the options shown are needed.  

Files 'raysyntax.txt' and 'help-on-help.txt' are works in progress that will be of little interest to anyone less deranged than I am, but the former gives some idea what I'm trying to do here.  Basically, we all have our favorite switches (options) which we routinely use with various system commands and probably making aliases and/or scripts and/or functions to 'wrap' these commands is a very common thing.  Also, there seems to be little coordination in the design of the various system utilities used in Linux -- I've attempted to make a common syntax and common set of switches for my utilities, eg: ',C' *always* indicates case-sensitivity.  My wrappers started out as innocent little aliases but they've grown and I myself can't immagine living without them.

Files 'aznt', 'nview' and 'ntools' are heavy edits of the work of Sebastian Gniazdowski.  You can find the originals elsewhere on github I believe.  'aznt' offers no user functions, but provides 'nlist()', which is used by several of my functions to created a selectable menu screen.  For example my 'h()' provides a search of the command history: "$ h 'find' 'exec'" will list all entries in the zsh history that match both 'find' and 'exec', and lets you highlight and select the one you want, pasting it to the the command line.  'nview' is a file quick-view utility and 'ntools' are some other tools originally written by Sebastian.

My stuff:  'messagefunctions' are colorized messages that I use throughout.  I like the idea, but it's not well developed yet and my use of color is still a bit chaotic. 'miscfunctions' are just that -- some of them are quite nice.  'aliases' -- some of these will be used by my functions so I include the whole thing. 'execute' contains a helper function used very commonly -- I create huge strings for execution sometimes and function '_execute()' detonates them and saves them to the history list as desired.

The functions:

The other files mostly contain just one function of the same name as the file along with it's helper functions.  (However I often do this sort of thing:

alias f='noglob _f'
function _f ()
{ ...

... that will be in the file 'f').  

u(): (Unzip): This is rather boring I just call whatever unzip, untar or whatever other de-compress utility is required based on the file extension.

timer(): Probably not needed, there are stock system utilities that do this work better.

mnt(): (Mount): Mounts and entire disk.  This utility is very specific to my system's setup but it might be of interest.  I can do:

$ mnt sdb

... and the whole disk '/dev/sdb' will be mounted to proscribed places.

h(): (History): Is very nice and should be of general interest.  I can't live without it.

s(): (Save): There may be better ways to save backups, but this is simple and effective.

try(): (Try): Very personal, these functions work with the backup system that my 's()' function creates and they restore and source backup functions.

rap(): Debian specific, this function attempts to put all the functionality of apt, apt-get, dpkg, aptitude and the whole mess of Debian package management under one roof.  It more or less works but it's a hodge-podge.

c(): (cd): One of my favorites, 'cd' to any recently visited directory.  But the list is persistent and global (this depends on the functions in my 'zshrc').  Lots of little features too, like:

$ c ,4

... 'cd' to the directory current on terminal #4.

varis(): A handy, dandy, variable viewer, useful in debugging.  If there's a better way please let me know!

v(): (variable): Gives a nice listing of variables (parameters) along with their attributes and values:

$ v ,f pa*

integer:  Pagecount = 1
array:  Pagetop = ( 1 )
association-readonly-hide-hideval-special:  parameters = !hidden!
array-readonly-hide-hideval-special:  patchars = !hidden!
scalar-tied-export-special:  PATH = .:/aWorking/Zsh/System:/aWorking/Bin:/usr/local/bin ...
array-tied-special:  path = ( . /aWorking/Zsh/System /aWorking/Bin /usr/local/bin /usr/ ...

...

i(): (Information): This monstrosity attempts to show you *everything* that the shell might identify or find matching the argument entered, be it a command of any sort, a file, a variable, a named pipe or WHATEVER.  If zsh recognizes it in any way shape or form, i(), should find it.

g(): (grep): A nice wrapper around grep, not too fancy except for the justified output.

l(): (ls): Wraps 'ls' in a very civilized way.

f(): (find): A nice wrapper around 'find'.

CONCLUSION:

Sorry in advance!  All feedback welcome.  To run this stuff you'd probably just source all the files (except for the '.txt' files) and everything should be available.  If there's any interest in any of this, I look forward to improvements (or replacements).  Many thanks to the superb people on <zsh-users@zsh.org> who labored patiently helping me to get as far as I have, especially Bart and Roman.  
