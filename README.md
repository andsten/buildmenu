## Overview ##

License: WTFPL, see http://sam.zoy.org/wtfpl/COPYING

If you use the build-tool *Waf* (http://code.google.com/p/waf), this plugin will
assist you by providing a comfortable sidebar menu which lists all existing
build-targets of your current project. You can select one or more targets from
the list for building. 

This script is still quite young and far from being feature complete.

Planned features for future versions:
- user can add own args to the waf command-line for building
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

## Usage ##
To toggle the sidebar build menu you should define your own key-mapping. See
section "Mappings". In the sidebar menu you can select (and
unselect) one or more of the listed build-targets by pressing *Space*. The
selected targets are marked in a different color for visualization. For each
selection the *Waf* buildcommand for building those targets is shown in a
preview window on the top of the current tab. The build command e.g. looks lie
this:

    ./waf --targets=common,unittest1,unitest2
     
By default this plugin only executes the *Waf* command "./waf list" once when
the sidebar menu is opened for the first time in the vim session. When closing
and re-opening the menu, this command is not executed again and the list of
build-targets stays the same. You can press 'R' (for "refresh") in the menu 
to execute "./waf list" again.

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
To create your own key-mapping to toggle the Buildmenu add a line like the
following to your *.vimrc* file:

    map <YOURMAPPEDKEY> <Plug>BuildmenuToggle

Example: Choosing to map the key *F4*:

    map <F4> <Plug>BuildmenuToggle

If you did not (yet) set any mapping like that, this plugin assigns the key
sequence "<Leader>bm" to toggle the Buildmenu. By default <Leader> maps to
typing the backslash key '\'. You can change that by setting the variable
*mapleader* accordingly. See vim help for details.

Mappings in the sidebar menu:

#### Space ####
select or unselect a build-target from the list. the target
is highlighted in a different color to visualize your choice

#### Return ####
start building your selected build-targets with *Waf*. The
resulting build command could e.g. look like this:

     ./waf --targets=common,unittest1,unitest2

If you did not select any target so far, then the resulting
build command will not specify any targets, which for *Waf*
means 'make all':

     ./waf

The build command will be added to the ex command history of
Vim. So you can easily execute it again by pressing ":" and 
the cursor up key.


## Help ##
You find further details in Vim's online help when entering
    
    :help buildmenu

Or open the help file here on GitHub in my repository: *./doc/buildmenu.txt*.
