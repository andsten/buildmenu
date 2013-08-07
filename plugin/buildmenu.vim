" ============================================================================
" Description: vim global plugin that provides build-targets list
" Maintainer:  Andrej Stender <mail@andrej-stender.de>
" License:     This program is free software. It comes without any warranty,
"              to the extent permitted by applicable law. You can redistribute
"              it and/or modify it under the terms of the Do What The Fuck You
"              Want To Public License, Version 2, as published by Sam Hocevar.
"              See http://sam.zoy.org/wtfpl/COPYING for more details.
" Version:     unstable deverloper version 0.1<v<0.2
"
" I took several code snippets and ideas from other vim plugins like e.g.
" NERDtree, fugitive ... Hereby a warm 'thank you' to the authors of those
" plugins for their great work! :-)
" ============================================================================


" SECTION: Script init stuff
" ============================================================================
if exists("g:loaded_buildmenu")
  finish
endif
let g:loaded_buildmenu = 1

" for line continuation - see :help use-cpo-save
let s:save_cpo = &cpo
set cpo&vim

"Function: s:initVariable() function
"This function is used to initialise a given variable to a given value. The
"variable is only initialised if it does not exist prior
"
"Args:
"var: the name of the var to be initialised
"value: the value to initialise var to
"
"Returns:
"1 if the var is set, 0 otherwise
function! s:initVariable(var, value)
    if !exists(a:var)
        exec 'let ' . a:var . ' = ' . "'" . substitute(a:value, "'", "''", "g") . "'"
        return 1
    endif
    return 0
endfunction


" SECTION: global variables/settings
" ============================================================================
call s:initVariable("g:BuildmenuMinWidth", 20)
call s:initVariable("g:BuildmenuMaxWidth", 40)
call s:initVariable("g:BuildmenuPosition", "right")
call s:initVariable("g:BuildmenuShowBuildCmdPreview", 1)
if !exists("g:BuildmenuGetTargetListCmd")
	let g:BuildmenuGetTargetListCmd = &makeprg . " list"
endif


" SECTION: Script local variables
" ============================================================================
call s:initVariable("s:warnmsg", " Plugin 'buildmenu' will probably not work correctly!")
call s:initVariable("s:abortmsg", " Aborting buildmenu plugin.")
call s:initVariable("s:BuildmenuMakeCmd", "mak")

let s:buildMenu = {}
let s:buildMenu.targets = []
let s:buildMenu.markedTargets = []
call s:initVariable("s:buildMenu.isInitialized", 0)
call s:initVariable("s:buildMenu.isOpen", 0)

let s:listWindow = {}
call s:initVariable("s:listWindow.width", g:BuildmenuMinWidth)
call s:initVariable("s:listWindow.lineOffset", 0)
call s:initVariable("s:listWindow.bufName", "buildmenu")
let s:listWindow.view = {}

let s:previewWindow = {}
call s:initVariable("s:previewWindow.bufName", "buildcmdpreview")


" SECTION: dictionary s:buildCmd 
" ============================================================================
let s:buildCmd = {}
let s:buildCmdIndex = []

function! s:buildCmd.Create(name, cmd) dict
	let self.name = a:name
	let self.cmd = a:cmd
	let self.lineOffset = 0
	call add(s:buildCmdIndex, self)
endfunction

function! s:buildCmd.AddAllToList(lineOffset) dict
	let self.lineOffset = a:lineOffset
	for i in range(len(s:buildCmdIndex))
		call setline(a:lineOffset + i, s:buildCmdIndex[i].name)
	endfor
endfunction

function! s:buildCmd.GetCmdFromLine(lineNum) dict
	let idx = a:lineNum - self.lineOffset
	if idx < len(s:buildCmdIndex)
		let cmd = s:buildCmdIndex[a:lineNum-self.lineOffset].cmd
		if match(cmd, "targets=") != -1
			let cmd = cmd . join(s:buildMenu.markedTargets, ",")
		endif
	else
		let cmd = "mak --targets=" . join(s:buildMenu.markedTargets, ",")
	endif
	return cmd
endfunction

function! s:InitBuildCmds()
	let s:cmdWafHelp = copy(s:buildCmd)
	call s:cmdWafHelp.Create("help", "mak --help")

	let s:cmdWafClean = copy(s:buildCmd)
	call s:cmdWafClean.Create("clean", "mak clean")

	let s:cmdWafDistclean = copy(s:buildCmd)
	call s:cmdWafDistclean.Create("distclean", "mak distclean")

	let s:cmdWafConfigure = copy(s:buildCmd)
	call s:cmdWafConfigure.Create("configure", "mak configure")

	let s:cmdWafBuildAll = copy(s:buildCmd)
	call s:cmdWafBuildAll.Create("build all", "mak build")

	let s:cmdWafBuildTargets = copy(s:buildCmd)
	call s:cmdWafBuildTargets.Create("build targets", "mak --targets=")
endfunction



" SECTION: key mappings      
" ============================================================================

" sequence '<Plug>BuildmenuToggle' is meant for the user so he/she can create
" a mapping to toggle this plugin. If no mapping is set, no key sequence
" can trigger it (see :help using-<Plug> for details)
noremap <unique> <script> <Plug>BuildmenuToggle  
             \ :exec <SID>BuildmenuToggle()<CR>

" if user did not define his/her own keymapping, use: <Leader>bm
" <Leader> by default translates to '\'. The user can set the variable
" 'mapleader' to set a different key (see :help mapleader for details)
if !hasmapto('<Plug>BuildmenuToggle')
  nmap <unique> <Leader>bm  <Plug>BuildmenuToggle
endif


" SECTION: user commands      
" ============================================================================

if !exists(":BuildmenuToggle")
  command -nargs=0  BuildmenuToggle  :call <SID>BuildmenuToggle()
endif
if !exists(":BuildmenuOpen")
  command -nargs=0  BuildmenuOpen    :call <SID>BuildmenuOpen()
endif
if !exists(":BuildmenuClose")
  command -nargs=0  BuildmenuClose   :call <SID>BuildmenuClose()
endif



" SECTION: debugging utils
" ============================================================================

function! g:BuildmenuDebug()
	call <SID>RestoreListWindowView()
endfunction


" SECTION: wrapper functions for key-mapping access
" ============================================================================

function! s:BuildmenuOpen()
	call s:buildMenu.Open()
endfunction

function! s:BuildmenuClose()
	call s:buildMenu.Close()
endfunction

function! s:BuildmenuToggle()
	call s:buildMenu.Toggle()
endfunction


" SECTION: dictionary s:buildMenu  public methods    
" ============================================================================

function! s:buildMenu.Open() dict
	try
		call self.Init()
		if self.isOpen == 0
			call s:previewWindow.Open()
			call s:listWindow.Open()
			"call s:listWindow.GotoLastSavedLinePos()
			let self.isOpen = 1
		endif
	catch /.*/
		echoe v:exception
	endtry
endfunction

function! s:buildMenu.Close() dict
	try
		call self.Init()
		if self.isOpen == 1
			call s:listWindow.Close()
			call s:previewWindow.Close()
			let self.isOpen = 0
		endif
	catch /.*/
		echoe v:exception
	endtry
endfunction

function! s:buildMenu.Toggle() dict
	try
		call self.Init()
		if self.isOpen == 0
			call s:previewWindow.Open()
			call s:listWindow.Open()
			"call s:listWindow.GotoLastSavedLinePos()
			let self.isOpen = 1
		else
			let rv1 = s:listWindow.Close()
			let rv2 = s:previewWindow.Close()
			if rv1 == -1 && rv2 == -1
				call s:previewWindow.Open()
				call s:listWindow.Open()
			else
				let self.isOpen = 0
			endif
		endif
	catch /.*/
		echoe v:exception
	endtry
endfunction


" SECTION: dictionary s:buildMenu  private methods
" ============================================================================

function! s:buildMenu.Init() dict
	if self.isInitialized == 0
		call self.RunPreChecks()
		call self.GetBuildTargetList()
		call self.GetBuildSystemVersionNumber()
		call s:listWindow.CalculateOptimalWidth(self.targets)
		call s:listWindow.AssembleStatusLine()
		call s:previewWindow.AssembleStatusLine()
		call s:InitBuildCmds()
		let self.isInitialized = 1
	endif
endfunction

function! s:buildMenu.RunPreChecks() dict
	if g:BuildmenuPosition != "right" && g:BuildmenuPosition != "left"
		echoe "g:BuildmenuPosition contains illegal value! set it to 'left' or to 'right'"
	endif

	if !filereadable(&makeprg)
		echoe = "error: binary specified in 'makeprg' not found (" . &makeprg . ")." . s:abortmsg
	endif

	if match(&makeprg, "waf", strlen(&makeprg)-strlen("waf")) == -1
		echo printf("warning: vim option 'makeprg' does not specify 'waf' binary (current value='%s')", &makeprg) . "." . s:warnmsg
	endif

	if !filereadable("wscript") 
		echo "warning: file 'wscript' not found in current working directory (" . getcwd() . ")." . s:warnmsg
	endif
endfunction

function! s:buildMenu.GetBuildTargetList() dict
	let self.markedTargets = []
	let wafoutput = system(g:BuildmenuGetTargetListCmd)
	let self.targets = split(wafoutput)
	
	"stop if not yet configured
	if match(wafoutput, "project was not configured") != -1
		echo "Warning: The Waf project was not configured: run 'waf configure' first!"
		return
	endif

	"remove waf ouput which is not part of target list
	let idx = match(self.targets, "'list'") 
	if idx != -1
		call remove(self.targets, idx, -1)
	endif
endfunction

function s:buildMenu.GetBuildSystemVersionNumber() dict
	let wafversioncmd = &makeprg . " --version"
	let wafoutput = system(wafversioncmd)
	let outputlist = split(wafoutput)
	let self.buildSysVersion = outputlist[1]
endfunction



" SECTION: dictionary s:listWindow
" ============================================================================

function! s:listWindow.Open() dict
	if g:BuildmenuPosition == "left"
		let winPos = "topleft"
	else
		let winPos = "botright"
	endif
	if !bufexists(self.bufName)
		exec winPos . " vertical " . self.width . " new"
		exec "edit " . self.bufName
		call self.UnSetHeaderLineHighlightning()
		call self.SetHeaderLineHighlightning()
		call setline(1, self.AssembleHeaderLine("Build-Commands"))
		call s:buildCmd.AddAllToList(2)
		call setline(8, self.AssembleHeaderLine("Build-Targets (". len(s:buildMenu.targets) . ")"))
		call append(8, s:buildMenu.targets)
		let self.lineOffset=8
		call self.SetKeyMappings()
		call self.SetOptions()
		setlocal statusline=%{g:Buildmenu_ListWindow_StatusLine}
	else
		exec winPos . " vertical " . self.width . " split " . self.bufName
		call s:RestoreListWindowView()
	endif
endfunction

function! s:listWindow.Close() dict
	if bufexists(self.bufName)
		let winnr = bufwinnr(self.bufName)
		if winnr != -1
			execute winnr . "wincmd w"
			let self.linepos = line(".")
			let self.view = winsaveview()
			hide
		else
			return -1
		endif
	endif
	return 0
endfunction

function! s:listWindow.CloseAndWipe() dict
	call self.Close()
	silent! exec "bwipeout " . self.bufName
endfunction

function! s:RestoreListWindowView()
	if len(s:listWindow.view) > 0
		call winrestview(s:listWindow.view)
	endif
endfunction

function! s:listWindow.AssembleStatusLine() dict
	let g:Buildmenu_ListWindow_StatusLine = "Waf v" . s:buildMenu.buildSysVersion
endfunction

function! s:listWindow.AssembleHeaderLine(text) dict
	let header = a:text
	if strlen(header) > (self.width-2)
		let header = strpart(header, 0, self.width-2)
	elseif strlen(header) < (self.width-2)
		let header = header . repeat(" ", self.width-strlen(header)-2)
	endif
	let header = "[" . header . "]"
	return header
endfunction

function! s:listWindow.SetHeaderLineHighlightning() dict
	syntax region buildmenuHeader start="^\s*\[" end="\]"
	highlight link buildmenuHeader StatusLine
endfunction

function! s:listWindow.UnSetHeaderLineHighlightning() dict
	highlight link buildmenuHeader NONE
	syntax clear buildmenuHeader 
endfunction

function! s:listWindow.MarkTargetLine(index, target) dict
	"TODO: collect highlights in a group for comfortable cleanup
	exec "syntax keyword buildmenuTarget" . a:index . " " . a:target
	exec "highlight link buildmenuTarget" . a:index . " Question"
endfunction

function! s:listWindow.UnMarkTargetLine(index) dict
	exec "highlight link buildmenuTarget" . a:index . " NONE"
	exec "syntax clear buildmenuTarget" . a:index
endfunction

function! s:listWindow.CalculateOptimalWidth(targets) dict
	let s:listWindow.width = g:BuildmenuMinWidth
	for n in a:targets
		let linelen = strlen(n)
		if linelen > s:listWindow.width
			let s:listWindow.width=linelen
		endif
	endfor
	if s:listWindow.width > g:BuildmenuMaxWidth
		let s:listWindow.width=g:BuildmenuMaxWidth
	endif
endfunction

function! s:listWindow.SetOptions() dict
	syntax case match
   	setlocal winfixwidth
	setlocal noswapfile
	setlocal bufhidden=hide
	setlocal buftype=nofile
	setlocal nowrap
	setlocal foldcolumn=0
	setlocal foldmethod=manual
	setlocal nofoldenable
	setlocal nobuflisted
	setlocal nospell
	setlocal iskeyword+=.
	setlocal nomodifiable
endfunction

function! s:listWindow.SetKeyMappings() dict
	map <buffer> <CR> :call <SID>ExecBuildCmd()<CR>
	map <buffer> <Space> :call <SID>MarkUnMarkBuildTarget()<CR>
	map <buffer> R :call <SID>RefreshBuildTargetList()<CR>
endfunction

function! s:listWindow.GotoLastSavedLinePos() dict
	if exists("self.linepos")
		call cursor(self.linepos, 1)
	endif
endfunction





" SECTION: dictionary s:previewWindow
" ============================================================================

function! s:previewWindow.Open() dict
	if g:BuildmenuShowBuildCmdPreview == 1
		if !bufexists(self.bufName)
			exec "topleft 1 new"
			exec "edit " . self.bufName
			let cmd = s:BuildmenuMakeCmd
			call append(".", substitute(cmd, "mak", &makeprg, ""))
			normal dd
			call self.ResizeHeightToFit()
			call self.SetOptions()
			setlocal statusline=%{g:Buildmenu_PreviewWindow_StatusLine}
		else
			exec "topleft 1 split " . self.bufName
		endif
	endif
endfunction

function! s:previewWindow.AssembleStatusLine() dict
	let g:Buildmenu_PreviewWindow_StatusLine = "Build command preview"
endfunction

function! s:previewWindow.Close() dict
	if g:BuildmenuShowBuildCmdPreview == 1
		if bufexists(self.bufName)
			let winnr = bufwinnr(self.bufName)
			if winnr != -1
				execute winnr . "wincmd w"
				hide
			else
				return -1
			endif
		endif
		return 0
	endif
	return -1 
endfunction

function! s:previewWindow.Update() dict
	call s:AssembleBuildCmd()
	if g:BuildmenuShowBuildCmdPreview == 1
		if bufexists(self.bufName)
			let winnr = bufwinnr(self.bufName)
			let currwinnr = winnr()
			if winnr != -1
				execute bufwinnr(self.bufName) . "wincmd w"
				setlocal modifiable
				normal ggdG
				let cmd = s:BuildmenuMakeCmd
				call append(".", substitute(cmd, "mak", &makeprg, ""))
				normal dd
				call self.ResizeHeightToFit()
				setlocal nomodifiable
			else
				call self.Open()
			endif
			execute currwinnr . "wincmd w"
		end
	endif
endfunction

function! s:previewWindow.ResizeHeightToFit() dict
	let height = float2nr(ceil(strlen(s:BuildmenuMakeCmd) / winwidth(0))) + 1
	exec "resize " . height
endfunction

function! s:previewWindow.SetOptions() dict
	syntax case match
   	setlocal winfixwidth
	setlocal noswapfile
	setlocal bufhidden=hide
	setlocal buftype=nofile
	setlocal wrap
	setlocal foldcolumn=0
	setlocal foldmethod=manual
	setlocal nofoldenable
	setlocal nobuflisted
	setlocal nospell
	setlocal iskeyword+=.
	setlocal nomodifiable
endfunction



" SECTION: 
" ============================================================================

function! s:RefreshBuildTargetList()
	call s:UnSelectUnMarkAllBuildTargets()
	call s:listWindow.UnSetHeaderLineHighlightning()
	call s:buildMenu.GetBuildTargetList()
	call s:listWindow.CalculateOptimalWidth(s:buildMenu.targets)
	"syntax clear
	"syntax case match
	call s:listWindow.CloseAndWipe()
	call s:listWindow.Open()
	silent call s:previewWindow.Update()
endfunction

function! s:ExecBuildCmd()
	if line(".") > s:listWindow.lineOffset
		if len(s:buildMenu.markedTargets) == 0
			call s:MarkUnMarkBuildTarget()
		endif
	else
		let cmd = getline(".")
		if match(cmd, "^\[.*") != -1
			"echo "header"
			return
		endif
	endif
	call s:AssembleBuildCmd()
	let s:listWindow.linepos = line(".")
	call s:buildMenu.Close()
	call histadd(":", s:BuildmenuMakeCmd)
	exec s:BuildmenuMakeCmd
endfunction

function! s:AssembleBuildCmd()
	let s:BuildmenuMakeCmd = s:buildCmd.GetCmdFromLine(line("."))
endfunction

function! s:MarkUnMarkBuildTarget()
	if line(".") > s:listWindow.lineOffset
		let index = line(".")-1-s:listWindow.lineOffset
		let target = get(s:buildMenu.targets, index)
		let markIndex = index(s:buildMenu.markedTargets, target)
		echo markIndex
		if markIndex < 0
			call add(s:buildMenu.markedTargets, target)
			call s:listWindow.MarkTargetLine(index, target)
		else
			call s:listWindow.UnMarkTargetLine(index)
			call remove(s:buildMenu.markedTargets, markIndex)
		endif
		silent call s:previewWindow.Update()
	endif
endfunction

function! s:UnSelectUnMarkAllBuildTargets()
	for target in s:buildMenu.markedTargets
		let index = index(s:buildMenu.targets, target) 
		let markIndex = index(s:buildMenu.markedTargets, target)
		call s:listWindow.UnMarkTargetLine(index)
		call remove(s:buildMenu.markedTargets, markIndex)
	endfor
endfunction


" SECTION: helper functions (thanks to the author of NERDtree ;-) )
" ============================================================================

function! s:NextBufferName()
    let name = "Buildmenu_" . s:NextBufferNumber()
    return name
endfunction

" the number to add to the buffer name to make the buf name unique
function! s:NextBufferNumber()
    if !exists("s:NextBufNum")
        let s:NextBufNum = 1
    else
        let s:NextBufNum += 1
    endif
    return s:NextBufNum
endfunction



"reset &cpo back to users setting
let &cpo = s:save_cpo
unlet s:save_cpo
