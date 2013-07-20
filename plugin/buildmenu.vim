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
call s:initVariable("g:BuildmenuMinWidth", 20)
call s:initVariable("g:BuildmenuMaxWidth", 40)
call s:initVariable("g:BuildmenuPosition", "right")
call s:initVariable("g:BuildmenuShowBuildCmdPreview", 1)
if !exists("g:BuildmenuGetTargetListCmd")
	let g:BuildmenuGetTargetListCmd = &makeprg . " list"
endif

" SECTION: script local variables      
call s:initVariable("s:abortmsg", ". aborting buildmenu plugin.")
call s:initVariable("s:BuildmenuMakeCmd", "mak")

let s:buildMenu = {}
let s:buildMenu.targets = []
call s:initVariable("s:buildMenu.isInitialized", 0)
call s:initVariable("s:buildMenu.isOpen", 0)

let s:listWindow = {}
call s:initVariable("s:listWindow.width", g:BuildmenuMinWidth)

let s:previewWindow = {}


" SECTION: key mappings      
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
	echo s:buildMenu
endfunction


" SECTION: wrapper functions for key-mapping access
" ============================================================================

" wrapper to make function accessable for a key-mapping
function! s:BuildmenuOpen()
	call s:buildMenu.Open()
endfunction

" wrapper to make function accessable for a key-mapping
function! s:BuildmenuClose()
	call s:buildMenu.Close()
endfunction

" wrapper to make function accessable for a key-mapping
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
			let self.isOpen = 1
		else
			call s:listWindow.Close()
			call s:previewWindow.Close()
			let self.isOpen = 0
		endif
	catch /.*/
		echoe v:exception
	endtry
endfunction


" SECTION: dictionary s:buildMenu  init methods
" ============================================================================

function! s:buildMenu.Init() dict
	if self.isInitialized == 0
		call self.RunPreChecks()
		call self.GetWafTargetList()
		call s:listWindow.CalculateOptimalWidth(self.targets)
		let self.isInitialized = 1
	endif
endfunction

function! s:buildMenu.RunPreChecks() dict
	if g:BuildmenuPosition != "right" && g:BuildmenuPosition != "left"
		echoe "g:BuildmenuPosition contains illegal value! set it to 'left' or to 'right'"
	endif

	if match(&makeprg, "waf", strlen(&makeprg)-strlen("waf")) == -1
		echoe printf("vim option 'makeprg' does not specify 'waf' binary (current value='%s')", &makeprg) . s:abortmsg
	endif

	if !filereadable(&makeprg)
		echoe = "error: binary specified in 'makeprg' not found (" . &makeprg . "). " . s:abortmsg
	endif

	if !filereadable("wscript") 
		echo "warning: file 'wscript' not found in current working directory (" . getcwd() . ")"
	endif

	"detect Waf version
	let wafversioncmd = &makeprg . " --version"
	let wafoutput = system(wafversioncmd)
	let outputlist = split(wafoutput)
	let s:buildMenu.buildSysVersion = outputlist[1]
endfunction

function! s:buildMenu.GetWafTargetList() dict
	let wafoutput = system(g:BuildmenuGetTargetListCmd)
	
	"stop if not yet configured
	if match(wafoutput, "project was not configured") != -1
		echoe "The Waf project was not configured: run 'waf configure' first!"
	endif

	let self.targets = split(wafoutput)

	"remove waf ouput which is not part of target list
	let idx = match(self.targets, "'list'") 
	if idx != -1
		call remove(self.targets, idx, -1)
	endif

	let s:MarkedBuildTargets = []
endfunction


" SECTION: dictionary s:listWindow
" ============================================================================

function! s:listWindow.Open() dict
	if !exists('t:BuildmenuTargetListBufName')
		let t:BuildmenuTargetListBufName = s:NextBufferName()
		if g:BuildmenuPosition == "left"
			let winPos = "topleft"
		else
			let winPos = "botright"
		endif
		exec winPos . " vertical " . self.width . " new"
		exec "edit " . t:BuildmenuTargetListBufName
		call append(".", s:buildMenu.targets)
		normal dd
		call self.GotoLastSavedLinePos()
		call self.SetKeyMappings()
		call self.SetOptions()
		call self.SetUnEditable()
		call s:ReMarkBuildTargets()
	endif
endfunction

function! s:listWindow.Close() dict
	if exists('t:BuildmenuTargetListBufName')
		silent! exec "bwipeout " . t:BuildmenuTargetListBufName
		unlet! t:BuildmenuTargetListBufName
	endif
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
	setlocal buftype=nofile
	setlocal bufhidden=wipe
	setlocal nowrap
	setlocal foldcolumn=0
	setlocal foldmethod=manual
	setlocal nofoldenable
	setlocal nobuflisted
	setlocal nospell
	"setlocal readonly
endfunction

function! s:listWindow.SetKeyMappings() dict
	map <buffer> <CR> :call <SID>ExecBuildCmd()<CR>
	map <buffer> <Space> :call <SID>MarkUnMarkBuildTarget()<CR>
	map <buffer> R :call <SID>RefreshBuildTargetList()<CR>
endfunction

function! s:listWindow.SetUnEditable() dict
	"if someone knows a better way to prevent getting into insert mode,
	"please implement it
	map <buffer> i <Nop>
	map <buffer> I <Nop>
	map <buffer> a <Nop>
	map <buffer> A <Nop>
	map <buffer> x <Nop>
	map <buffer> X <Nop>
	map <buffer> d <Nop>
	map <buffer> D <Nop>
	map <buffer> dd <Nop>
	map <buffer> o <Nop>
	map <buffer> O <Nop>
	map <buffer> y <Nop>
	map <buffer> p <Nop>
	map <buffer> r <Nop>
	map <buffer> s <Nop>
	map <buffer> c <Nop>
	map <buffer> v <Nop>
	map <buffer> V <Nop>
	"...
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
		if !exists('t:BuildmenuPreviewBufName')
			let t:BuildmenuPreviewBufName = s:NextBufferName()
			exec "topleft 1 new"
			exec "edit " . t:BuildmenuPreviewBufName
			call append(".", s:BuildmenuMakeCmd)
			normal dd
			call self.ResizeHeightToFit()
			call self.SetOptions()
		endif
	endif
endfunction

function! s:previewWindow.Close() dict
	if g:BuildmenuShowBuildCmdPreview == 1
		if exists('t:BuildmenuPreviewBufName')
			silent! exec "bwipeout " . t:BuildmenuPreviewBufName
			unlet! t:BuildmenuPreviewBufName
		endif
	endif
endfunction

function! s:previewWindow.Update() dict
	if g:BuildmenuShowBuildCmdPreview == 1
		if exists('t:BuildmenuPreviewBufName')
			if g:BuildmenuPosition == "left"
				exec "normal! \<C-w>l\<C-w>k"
			else
				exec "normal! \<C-w>h\<C-w>k"
			endif
			normal ggdG
			call append(".", s:BuildmenuMakeCmd)
			normal dd
			call self.ResizeHeightToFit()
			if g:BuildmenuPosition == "left"
				exec "normal! \<C-w>h"
			else
				exec "normal! \<C-w>l"
			endif
		endif
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
	setlocal buftype=nofile
	setlocal bufhidden=wipe
	setlocal wrap
	setlocal foldcolumn=0
	setlocal foldmethod=manual
	setlocal nofoldenable
	setlocal nobuflisted
	setlocal nospell
	"setlocal readonly
endfunction



" SECTION: 
" ============================================================================

function! s:RefreshBuildTargetList()
	call s:UnSelectUnMarkAllBuildTargets()
	normal gg^VGd
	call s:buildMenu.GetWafTargetList()
	call s:listWindow.CalculateOptimalWidth(s:buildMenu.targets)
	call append(".", s:buildMenu.targets)
	normal dd
	normal gg
	call s:AssembleBuildCmd()
	silent call s:previewWindow.Update()
	syntax clear
	syntax case match
endfunction

function! s:ExecBuildCmd()
	if len(s:MarkedBuildTargets) == 0
		call s:MarkUnMarkBuildTarget()
	endif
	call s:AssembleBuildCmd()
	let s:listWindow.linepos = line(".")
	call s:buildMenu.Close()
	call histadd(":", s:BuildmenuMakeCmd)
	exec s:BuildmenuMakeCmd
endfunction

function! s:AssembleBuildCmd()
	let s:BuildmenuMakeCmd = "mak " . "--targets=" .
				\ join(s:MarkedBuildTargets, ",")
endfunction

function! s:MarkUnMarkBuildTarget()
	let index = line(".")-1
	let target = get(s:buildMenu.targets, index)
	let markIndex = index(s:MarkedBuildTargets, target)
	if markIndex < 0
		call add(s:MarkedBuildTargets, target)
		exec "syntax keyword buildmenuTarget" . index . " " . target
		exec "highlight link buildmenuTarget" . index . " Directory"
	else
		exec "highlight link buildmenuTarget" . index . " NONE"
		exec "syntax clear buildmenuTarget" . index
		call remove(s:MarkedBuildTargets, markIndex)
	endif
	call s:AssembleBuildCmd()
	silent call s:previewWindow.Update()
endfunction

function! s:ReMarkBuildTargets()
	for target in s:MarkedBuildTargets
		let index = index(s:buildMenu.targets, target) 
		exec "syntax keyword buildmenuTarget" . index . " " . target
		exec "highlight link buildmenuTarget" . index . " Directory"
	endfor
endfunction

function! s:UnSelectUnMarkAllBuildTargets()
	for target in s:MarkedBuildTargets
		let index = index(s:buildMenu.targets, target) 
		let markIndex = index(s:MarkedBuildTargets, target)
		exec "highlight link buildmenuTarget" . index . " NONE"
		exec "syntax clear buildmenuTarget" . index
		call remove(s:MarkedBuildTargets, markIndex)
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
