## Overview ##

License: WTFPL, see http://sam.zoy.org/wtfpl/COPYING

If you use the build-tool Waf http://code.google.com/p/waf, this plugin will
assist you by providing a comfortable sidebar menu which lists all existing
build-targets of your current project. You can select a target and start
building by pressing <Return>.

This script is still far from being feature complete.

## Waf ##
So far this plugin merely works with the *Waf* buildsystem
http://code.google.com/p/waf. However support of other buildsystems like e.g.
*SCons* and *GNU Make* is planned for future versions.

With *Waf* it is very easy for this plugin to provide a list of build-targets,
because this build system provides a command line argument to list all
targets:

    $ ./waf list 

Not all other buildsystems do provide this feature.

## Setup ##

### Installation ###
Just place the file *buildmenu.vim* in your *$VIMRUNTIME/plugin/* directory and
the file *buildmenu.txt* in your *$VIMRUNTIME/doc/* directory.

For more comfortable handling of vim plugins the use of the plugin *pathogen* is recommended.
In that case you merely need to create a clone of the buildmenu git repository in directory
*~/.vim/bundle/buildmenu*. See https://github.com/tpope/vim-pathogen for details. 

Then choose a key-mapping to toggle the buildmenu plugin (see section below).

To index the vim internal help page of plugin buildmenu, enter this command in vim

    :helptags $VIMRUNTIME/doc
    
(When using *pathogen*, just enter *:Helptags&* instead.)

### Waf dependencies ###
Preconditions that must be met for Buildmenu to work normally:

The **waf** binary and a **wscript** file must be located in **:pwd** (which usually
should be your project root directory). If not then Buildmenu will show
an error message instead of opening the menu.

The vim option **makeprg** must be set to employ the waf binary. To do that
place the following line in your **.vimrc** file: 

    :set makeprg=./waf


## Key-Mapping ##

To create a mapping to the command *:BuildmenuToggle* (which opens/closes the buildmenu) 
add a line like the following to your *.vimrc* file:

    map <YOURMAPPEDKEY> <Plug>BuildmenuToggle

Example: Choosing to map the key *<F4>*:

    map <F4> <Plug>BuildmenuToggle

## Help ##
You find further details in Vim's online help when entering
    
    :help buildmenu
