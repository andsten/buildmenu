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

" SECTION: Script init stuff {{{1
"============================================================
if exists("g:loaded_buildmenu")
  finish
endif
let g:loaded_buildmenu = 1
let g:BuildmenuMakePrg = "./waf"

"for line continuation - see :help use-cpo-save
let s:save_cpo = &cpo
set cpo&vim

"see :help using-<Plug>
if !hasmapto(':call ListBuildTargets<CR>')
  map <unique> <Leader>a  <Plug>BuildmenuToggle
endif
noremap <unique> <script> <Plug>BuildmenuToggle  :call <SID>BuildmenuToggle()<CR>

"set user-command
if !exists(":BuildmenuToggle")
  command -nargs=0  BuildmenuToggle  :call <SID>BuildmenuToggle()
  command -nargs=0  BuildmenuOpen    :call <SID>BuildmenuOpen()
  command -nargs=0  BuildmenuClose   :call <SID>BuildmenuClose()
  command -nargs=0  BuildmenuMake    :call <SID>BuildmenuMake()
endif

function! s:BuildmenuToggle()
	let retval = s:PreChecks()
	if retval != 0
		return
	endif
	let retval = s:OpenListWindow()
	if retval == 0
		call s:CloseListWindow()
	endif
endfunction

function! s:BuildmenuOpen()
	let retval = s:PreChecks()
	if retval != 0
		return
	endif
	call s:OpenListWindow()
endfunction

function! s:BuildmenuClose()
	call s:CloseListWindow()
endfunction


function! s:PreChecks()
	if !filereadable("waf")
		echo "waf not found in " . getcwd()
		return 1
	endif
	if !filereadable("wscript") 
		echo "wscript not found in " .getcwd()
		return 1
	endif
	return 0
endfunction

function! s:getWafBuildList()
	let wafoutput = system("./waf list")
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

function! s:OpenListWindow()
	if !exists('t:BuildmenuBufName')
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

function! s:ExecBuildCmd()
	let s:buildcmd = "mak " . "--targets=" . get(s:wafbuildlist, line(".")-1)
	let s:buildlistlinepos = line(".")
	call s:CloseListWindow()
	call s:BuildmenuMake()
endfunction

function! s:BuildmenuMake()
	let save_makeprg = &makeprg
	let &makeprg=g:BuildmenuMakePrg
	call histadd(":", "BuildmenuMake")
	exec s:buildcmd
	let &makeprg= save_makeprg
endfunction

function! s:CloseListWindow()
	if exists('t:BuildmenuBufName')
		silent! exec "buffer " . t:BuildmenuBufName
		quit!
		unlet! t:BuildmenuBufName
	endif
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
