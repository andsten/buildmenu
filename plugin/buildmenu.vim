" ============================================================================
" Description: vim global plugin that provides build-targets list
" Maintainer:  Andrej Stender <mail@andrej-stender.de>
" License:     This program is free software. It comes without any warranty,
"              to the extent permitted by applicable law. You can redistribute
"              it and/or modify it under the terms of the Do What The Fuck You
"              Want To Public License, Version 2, as published by Sam Hocevar.
"              See http://sam.zoy.org/wtfpl/COPYING for more details.
"
" ============================================================================

if exists("g:loaded_buildmenu")
  finish
endif
let g:loaded_buildmenu = 1

" for line continuation - see :help use-cpo-save
let s:save_cpo = &cpo
set cpo&vim


" SECTION: global variables/settings
" ============================================================================

" minimum column with of the sidebar build menu.
if !exists("g:BuildmenuMinWidth")
	let g:BuildmenuMinWidth = 20
endif

" maximum column with of the sidebar build menu.
if !exists("g:BuildmenuMaxWidth")
	let g:BuildmenuMaxWidth = 40
endif

" shell command to obtain list of buildtargets. vim option 'makeprg' is
" expected to specify the 'waf' binary, so the resulting default value
" should be './waf list'
if !exists("g:BuildmenuGetTargetListCmd")
	let g:BuildmenuGetTargetListCmd = &makeprg . " list"
endif

" open preview window together with build menu and show build command
" default: 1 (yes); set to 0 to switch this feature off
if !exists("g:BuildmenuShowBuildCmdPreview")
	let g:BuildmenuShowBuildCmdPreview = 1
endif

" SECTION: script local variables      
" ============================================================================

" error string
let s:abortmsg = ". aborting buildmenu plugin."

" safe initial value for this varialbe
let s:BuildmenuMakeCmd = "mak"

"for actions executed only once on first call to BuildmenuOpen()
let s:init=0


" SECTION: key mappings      
" ============================================================================

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
" ============================================================================
if !exists(":BuildmenuToggle")
  command -nargs=0  BuildmenuToggle  :call <SID>BuildmenuToggle()
  command -nargs=0  BuildmenuOpen    :call <SID>BuildmenuOpen()
  command -nargs=0  BuildmenuClose   :call <SID>BuildmenuClose()
endif



" SECTION: functions
" ============================================================================
function! s:BuildmenuOpen()
	if s:init == 0
		let retval = s:PreChecks()
		if retval != 0
			return -1
		endif
		call s:getWafBuildList()
		call s:InitPreviewWindow()
		let s:init = 1
	endif
	if !exists('t:BuildmenuBufName')
		let t:BuildmenuBufName = s:nextBufferName()
		exec "botright vertical " . s:BuildmenuWidth . " new"
		exec "edit " . t:BuildmenuBufName
		call append(".", s:BuildTargets)
		normal dd
		call s:SetLocalKeyMappings()
		syntax case match
		call s:SetThrowAwayBufferWinOptions()
		call s:PreventBuildmenuUserEdit()
		if exists("s:buildlistlinepos")
			call cursor(s:buildlistlinepos, 1)
		endif
		call s:ReMarkBuildTargets()
		silent call s:OpenPreviewWindow()
		return 1
	else 
		return 0
	endif
endfunction

function! s:InitPreviewWindow()
	if g:BuildmenuShowBuildCmdPreview == 1
		let s:build_command_preview = tempname()
		pclose
	endif
endfunction

function! s:OpenPreviewWindow()
	if g:BuildmenuShowBuildCmdPreview == 1
		pclose!
		exec "normal! \<C-w>h"
		set previewheight=1
		pedit s:build_command_preview
		exec "normal! \<C-w>k"
		call setline(".", s:BuildmenuMakeCmd)
		exec "normal! \<C-w>j\<C-w>l"
	endif
endfunction

function! s:ClosePreviewWindow()
	if g:BuildmenuShowBuildCmdPreview == 1
		pclose!
		bdelete! s:build_command_preview
	endif
endfunction

function! s:UpdatePreviewWindow()
	if g:BuildmenuShowBuildCmdPreview == 1
		exec "normal! \<C-w>h\<C-w>k"
		call setline(".", s:BuildmenuMakeCmd)
		exec "normal! \<C-w>j\<C-w>l"
	endif
endfunction

function! s:BuildmenuClose()
	if exists('t:BuildmenuBufName')
		silent! exec "bwipeout " . t:BuildmenuBufName
		unlet! t:BuildmenuBufName
		call s:ClosePreviewWindow()
	endif
endfunction

function! s:BuildmenuToggle()
	let retval = s:BuildmenuOpen()
	if retval == 0
		call s:BuildmenuClose()
	endif
endfunction

function! s:PreChecks()
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

function! s:Refresh()
	normal gg^VGd
	call s:getWafBuildList()
	call append(".", s:BuildTargets)
	normal dd
	syntax clear
	syntax case match
endfunction


function! s:getWafBuildList()
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

function! s:SetLocalKeyMappings()
	map <buffer> <CR> :call <SID>ExecBuildCmd()<CR>
	map <buffer> <Space> :call <SID>MarkUnMarkBuildTarget()<CR>
	map <buffer> R :call <SID>Refresh()<CR>
endfunction


" SECTION: helper functions (thanks to the author of NERDtree ;-) )
" ============================================================================
"
function! s:SetThrowAwayBufferWinOptions()
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

function! s:PreventBuildmenuUserEdit()
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

function! s:nextBufferName()
    let name = "Buildmenu_" . s:nextBufferNumber()
    return name
endfunction

" the number to add to the buffer name to make the buf name unique
function! s:nextBufferNumber()
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
