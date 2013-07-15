" ============================================================================
" Description: vim global plugin that provides build-targets list
" Maintainer:  Andrej Stender <mail@andrej-stender.de>
" License:     This program is free software. It comes without any warranty,
"              to the extent permitted by applicable law. You can redistribute
"              it and/or modify it under the terms of the Do What The Fuck You
"              Want To Public License, Version 2, as published by Sam Hocevar.
"              See http://sam.zoy.org/wtfpl/COPYING for more details.
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
call s:initVariable("s:init", 0)
call s:initVariable("s:BuildMenuIsOpen", 0)
let s:BuildMenuIsOpen = 0

" SECTION: key mappings      
" sequence '<Plug>BuildmenuToggle' is meant for the user so he/she can create
" a mapping to toggle this plugin. If no mapping is set, no key sequence
" can trigger it (see :help using-<Plug> for details)
noremap <unique> <script> <Plug>BuildmenuToggle  
             \ :call <SID>BuildmenuToggle()<CR>

" if user did not define his/her own keymapping, use: <Leader>bm
" <Leader> by default translates to '\'. The user can set the variable
" 'mapleader' to set a different key (see :help mapleader for details)
if !hasmapto('<Plug>BuildmenuToggle')
  nmap <unique> <Leader>bm  <Plug>BuildmenuToggle
endif

" SECTION: user commands      
if !exists(":BuildmenuToggle")
  command -nargs=0  BuildmenuToggle  :call <SID>BuildmenuToggle()
  command -nargs=0  BuildmenuOpen    :call <SID>BuildmenuOpen()
  command -nargs=0  BuildmenuClose   :call <SID>BuildmenuClose()
endif



" SECTION: top level functions
" ============================================================================
function! s:BuildmenuOpen()
	call s:InitPlugin()
	if s:init == 0
		return
	endif
	if s:BuildMenuIsOpen == 0
		call s:OpenPreviewWindow()
		call s:OpenTargetListWindow(s:BuildmenuWidth)
		let s:BuildMenuIsOpen = 1
	endif
endfunction

function! s:BuildmenuClose()
	call s:InitPlugin()
	if s:init == 0
		return
	endif
	if s:BuildMenuIsOpen == 1
		call s:CloseTargetListWindow()
		call s:ClosePreviewWindow()
		let s:BuildMenuIsOpen = 0
	endif
endfunction

function! s:BuildmenuToggle()
	call s:InitPlugin()
	if s:init == 0
		return
	endif
	if s:BuildMenuIsOpen == 0
		call s:OpenPreviewWindow()
		call s:OpenTargetListWindow(s:BuildmenuWidth)
		let s:BuildMenuIsOpen = 1
	else
		call s:CloseTargetListWindow()
		call s:ClosePreviewWindow()
		let s:BuildMenuIsOpen = 0
	endif
endfunction


" SECTION: internal functions
" ============================================================================

function! s:InitPlugin()
	if s:init == 0
		if s:PreChecks() != 0
			return -1
		endif
		call s:GetWafTargetList()
		let s:init = 1
		return 0
	endif
endfunction

function! s:OpenTargetListWindow(width)
	if !exists('t:BuildmenuTargetListBufName')
		let t:BuildmenuTargetListBufName = s:NextBufferName()
		if g:BuildmenuPosition == "left"
			let winPos = "topleft"
		else
			let winPos = "botright"
		endif
		exec winPos . " vertical " . a:width . " new"
		exec "edit " . t:BuildmenuTargetListBufName
		call append(".", s:BuildTargets)
		normal dd
		call s:SetTargetListWindowKeyMappings()
		call s:SetTargetListWinOptions()
		call s:SetUnEditable()
		call s:GotoLastSavedLinePos()
		call s:ReMarkBuildTargets()
	endif
endfunction

function! s:CloseTargetListWindow()
	if exists('t:BuildmenuTargetListBufName')
		silent! exec "bwipeout " . t:BuildmenuTargetListBufName
		unlet! t:BuildmenuTargetListBufName
	endif
endfunction

function! s:OpenPreviewWindow()
	if g:BuildmenuShowBuildCmdPreview == 1
		if !exists('t:BuildmenuPreviewBufName')
			let t:BuildmenuPreviewBufName = s:NextBufferName()
			exec "topleft 1 new"
			exec "edit " . t:BuildmenuPreviewBufName
			call append(".", s:BuildmenuMakeCmd)
			normal dd
			call s:ResizePrevWinHeightToFit()
			call s:SetPreviewWinOptions()
		endif
	endif
endfunction

function! s:ClosePreviewWindow()
	if g:BuildmenuShowBuildCmdPreview == 1
		if exists('t:BuildmenuPreviewBufName')
			silent! exec "bwipeout " . t:BuildmenuPreviewBufName
			unlet! t:BuildmenuPreviewBufName
		endif
	endif
endfunction

function! s:UpdatePreviewWindow()
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
			call s:ResizePrevWinHeightToFit()
			if g:BuildmenuPosition == "left"
				exec "normal! \<C-w>h"
			else
				exec "normal! \<C-w>l"
			endif
		endif
	endif
endfunction

function! s:ResizePrevWinHeightToFit()
	let height = float2nr(ceil(strlen(s:BuildmenuMakeCmd) / winwidth(0))) + 1
	exec "resize " . height
endfunction

function! s:GotoLastSavedLinePos()
	if exists("s:buildlistlinepos")
		call cursor(s:buildlistlinepos, 1)
	endif
endfunction

function! s:PreChecks()
	if g:BuildmenuPosition != "right" && g:BuildmenuPosition != "left"
		echoe "error: g:BuildmenuPosition contains illegal value! set it to 'left' or to 'right'"
		return 1
	endif
	if match(&makeprg, "waf", strlen(&makeprg)-strlen("waf")) == -1
		echoe printf("error: vim option 'makeprg' does not specify 'waf' binary (current value='%s')", &makeprg) . s:abortmsg
		return 1
	endif
	if !filereadable(&makeprg)
		echoe "binary specified in 'makeprg' not found (" . &makeprg . "). " . s:abortmsg
		return 1
	endif
	if !filereadable("wscript") 
		echoe "warning: file 'wscript' not found in current working directory (" . getcwd() . ")"
	endif
	return 0
endfunction

function! s:RefreshBuildTargetList()
	normal gg^VGd
	call s:GetWafTargetList()
	call append(".", s:BuildTargets)
	normal dd
	syntax clear
	syntax case match
endfunction

function! s:GetWafTargetList()
	let wafoutput = system(g:BuildmenuGetTargetListCmd)
	let s:BuildTargets = split(wafoutput)
	call remove(s:BuildTargets, -4, -1)
	let s:BuildmenuWidth = g:BuildmenuMinWidth
	for n in s:BuildTargets
		let linelen = strlen(n)
		if linelen > s:BuildmenuWidth
			let s:BuildmenuWidth=linelen
		endif
	endfor
	if s:BuildmenuWidth > g:BuildmenuMaxWidth
		let s:BuildmenuWidth=g:BuildmenuMaxWidth
	endif
	let s:MarkedBuildTargets = []
endfunction

function! s:ExecBuildCmd()
	if len(s:MarkedBuildTargets) == 0
		call s:MarkUnMarkBuildTarget()
	endif
	call s:AssembleBuildCmd()
	let s:buildlistlinepos = line(".")
	call s:BuildmenuClose()
	call histadd(":", s:BuildmenuMakeCmd)
	exec s:BuildmenuMakeCmd
endfunction

function! s:AssembleBuildCmd()
	let s:BuildmenuMakeCmd = "mak " . "--targets=" .
				\ join(s:MarkedBuildTargets, ",")
endfunction

function! s:MarkUnMarkBuildTarget()
	let index = line(".")-1
	let target = get(s:BuildTargets, index)
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
	silent call s:UpdatePreviewWindow()
endfunction

function! s:ReMarkBuildTargets()
	for target in s:MarkedBuildTargets
		let index = index(s:BuildTargets, target) 
		exec "syntax keyword buildmenuTarget" . index . " " . target
		exec "highlight link buildmenuTarget" . index . " Directory"
	endfor
endfunction

function! s:SetTargetListWindowKeyMappings()
	map <buffer> <CR> :call <SID>ExecBuildCmd()<CR>
	map <buffer> <Space> :call <SID>MarkUnMarkBuildTarget()<CR>
	map <buffer> R :call <SID>RefreshBuildTargetList()<CR>
endfunction


" SECTION: helper functions (thanks to the author of NERDtree ;-) )
" ============================================================================
"
function! s:SetTargetListWinOptions()
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
	setlocal readonly
endfunction

function! s:SetPreviewWinOptions()
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
	setlocal readonly
endfunction

function! s:SetUnEditable()
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
