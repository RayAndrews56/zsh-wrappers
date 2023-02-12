# zsh-wrappers
my favorite zsh wrappers around common commands: grep, find, cd, etc.
This is my first use of github, a real README will follow once I get this thing up and running.

For now, very briefly: 

I've never uploaded or attempted to share any of my zsh coding.  I don't know what the protocols are, and my code is no doubt amaturish.  If anyone shows any interest in the functions here, I hope for reviews and improvments from competent zsh users!  The 'zshrc' and 'zstyle' files are my zsh bootup files, they are included just in case anything there is needed.  At the very least the 'preexec()' and 'precmd()' and 'chpwd()' functions in 'zshrc' are needed for my 'c()' function to work. 'zstyle' is there just in case any of the options shown are needed.  

Files 'raysyntax.txt' and 'help-on-help.txt' are works in progress that will be of little interest to anyone less deranged than I am, but the former gives some idea what I'm trying to do here.  Basically, we all have our favorite switches (options) which we routinely use with various system commands and probably making aliases and/or scripts and/or functions to 'wrap' these commands is a very common thing.  Also, there seems to be little coordination in the design of the various system utilities used in Linux -- I've attempted to make a common syntax and common set of switches for my utilities, eg: ',C' *always* indicates case-sensitivity.  My wrappers started out as innocent little aliases but they've grown and I myself can't immagine living without them.

Files 'aznt', 'nview' and 'ntools' are heavy edits of the work of Sebastian Gniazdowski.  You can find the originals elsewhere on github I believe.  'aznt' offers no user functions, but provides 'nlist()', which is used by several of my functions to created a selectable menu screen.  For example my 'h()' provides a search of the command history: "$ h 'find' 'exec'" will list all entries in the zsh history that match both 'find' and 'exec', and lets you highlight and select the one you want, pasting it to the the command line.  'nview' is a file quick-view utility and 'ntools' are some other tools originally written by Sebastian.

My stuff:  'messagefunctions' are colorized messages that I use throughout.  I like the idea, but it's not well developed yet and my use of color is still a bit chaotic. 'miscfunctions' are just that -- some of them are quite nice.  'aliases' -- some of these will be used by my functions so I include the whole thing. 'execute' contains a helper function used very commonly -- I create huge strings for execution sometimes and function '_execute()' detonates them and saves them to the history list as desired.




