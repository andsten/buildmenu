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

" this ist just a safe value to initialize this variable to cause no harm.
" should not be changed
let g:BuildmenuMakeCmd = "mak"

" setting
" shell command to obtain list of buildtargets. vim option 'makeprg' is
" expected to specify the 'waf' binary, so the resulting default value
" should be './waf list'
let g:BuildmenuGetTargetListCmd = &makeprg . " list"



" SECTION: script local variables      
" ============================================================================
let s:abortmsg = ". aborting buildmenu plugin."



" SECTION: key mappings      
" ============================================================================
if !hasmapto(':call ListBuildTargets<CR>')
  map <unique> <Leader>a  <Plug>BuildmenuToggle
endif
noremap <unique> <script> <Plug>BuildmenuToggle  :call <SID>BuildmenuToggle()<CR>



" SECTION: user commands      
" ============================================================================
if !exists(":BuildmenuToggle")
  command -nargs=0  BuildmenuToggle  :call <SID>BuildmenuToggle()
  command -nargs=0  BuildmenuOpen    :call <SID>BuildmenuOpen()
  command -nargs=0  BuildmenuClose   :call <SID>BuildmenuClose()
  command -nargs=0  BuildmenuMake    :exec g:BuildmenuMakeCmd
endif



" SECTION: functions
" ============================================================================
function! s:BuildmenuOpen()
	if !exists('t:BuildmenuBufName')
		let retval = s:PreChecks()
		if retval != 0
			return -1
		endif
		let width = s:getWafBuildList()
		let t:BuildmenuBufName = s:nextBufferName()
		exec "botright vertical " . width . " new"
		exec "edit " . t:BuildmenuBufName
		call append(".", s:wafbuildlist)
		normal dd
		map <buffer> <CR> :call <SID>ExecBuildCmd()<CR>
		call s:SetThrowAwayBufferWinOptions()
		if exists("s:buildlistlinepos")
			call cursor(s:buildlistlinepos, 1)
		endif
		return 1
	else 
		return 0
	endif
endfunction

function! s:BuildmenuClose()
	if exists('t:BuildmenuBufName')
		silent! exec "bwipeout " . t:BuildmenuBufName
		unlet! t:BuildmenuBufName
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

function! s:getWafBuildList()
	let wafoutput = system(g:BuildmenuGetTargetListCmd)
	let s:wafbuildlist = split(wafoutput)
	call remove(s:wafbuildlist, -4, -1)
	let longest=0
	for n in s:wafbuildlist
		let linelen = strlen(n)
		if linelen > longest
			let longest=linelen
		endif
	endfor
	return longest
endfunction

function! s:ExecBuildCmd()
	let g:BuildmenuMakeCmd = "mak " . "--targets=" . get(s:wafbuildlist, line(".")-1)
	let s:buildlistlinepos = line(".")
	call s:BuildmenuClose()
	call histadd(":", g:BuildmenuMakeCmd)
	exec g:BuildmenuMakeCmd
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
