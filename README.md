## Overview ##

License: WTFPL, see http://sam.zoy.org/wtfpl/COPYING

If you are using the build-system *Waf* (http://code.google.com/p/waf), this
plugin assists you by providing a comfortable sidebar menu which lists all
existing build-targets of your current project. You can select a target and
start building by pressing *Return*.

This script is still far from being feature complete.

Planned features for future versions:
- multi-select build targets (mark e.g. by pressing *Space*)
- cache target list (not call './waf list' on each open)
- user can add args to the waf command-line for building
- showing waf command-line for building in preview window
- providing waf default commands (configure, build, ...)
- quick-help in the style of NERDTree (when pressing *?*)
- support of other build systems like *SCons* and *GNU Make* (if feasible)

## Waf ##
So far this plugin merely works with the *Waf* buildsystem
http://code.google.com/p/waf. 

With *Waf* it is very easy for this plugin to provide a list of build-targets,
because this build system provides a command line argument to list all
targets:

    $ ./waf list 

Not all other buildsystems do provide this feature.

## Setup ##

### Installation ###
Just place the file *buildmenu.vim* in your *~/.vim/plugin/* directory and
the file *buildmenu.txt* in your *~/.vim/doc/* directory.

For more comfortable handling of vim plugins the use of the plugin *pathogen* is recommended.
In that case you merely need to create a clone of the buildmenu git repository in directory
*~/.vim/bundle/buildmenu*. See https://github.com/tpope/vim-pathogen for details. 

Then choose a key-mapping to toggle the buildmenu plugin (see section below).

To index the vim internal help page of the plugin buildmenu, enter this command in vim

    :helptags ~/.vim/doc
    
(When using *pathogen*, just enter *:Helptags* instead.)

### Waf dependencies ###
Preconditions that must be met for Buildmenu to work properly:

The *Waf* binary must be installed on the system. 

The vim option *makeprg* must specify this *Waf* binary. To do that place a
line like the following one in your *.vimrc* file:

   :set makeprg=./waf

The *Waf* build system by default expects the user to place the *Waf* binary
in the root directory of his/her code project, together with a *wscript*
file. This is why the example *.vimrc* line above sets *makeprg* to *'./waf'*.
If your *Waf* binary is located in another path, then you need to set
*makeprg* to this path.

Nevertheless for *Waf* (and this plugin) to work properly, the current
working directory (*:pwd*) must be the root directory of your code project,
which also contains the root makefile for the *Waf* buildsystem, which is
usually named *wscript*. So either start vim in the root directory of
your project or use the vim command *:cd* to change into that directory.

An error message will be shown if one of these preconditions is not met
and you try to open the Buildmenu.

## Key-Mapping ##

To create a mapping to the command *:BuildmenuToggle* (which opens/closes the buildmenu) 
add a line like the following to your *.vimrc* file:

    map <YOURMAPPEDKEY> <Plug>BuildmenuToggle

Example: Choosing to map the key *<F4>*:

    map <F4> <Plug>BuildmenuToggle

## Help ##
You find further details in Vim's online help when entering
    
    :help buildmenu

Or open the help file here on GitHub in my repository: *./doc/buildmenu.txt*.
