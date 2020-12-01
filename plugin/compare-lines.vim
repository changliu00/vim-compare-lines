" Vim plugin to diff two lines of a buffer and navigate through the changes
" File:     compare-lines.vim
" Author:   statox
" License:  This file is distributed under the MIT License

" Create the commands
command! -nargs=* CL                 call <SID>PreTreatmentFunction("Compare", <f-args>)
command! -nargs=* CompareLines       call <SID>PreTreatmentFunction("Compare", <f-args>)
command! -nargs=* FL                 call <SID>PreTreatmentFunction("Focus", <f-args>)
command! -nargs=* FocusLines         call <SID>PreTreatmentFunction("Focus", <f-args>)
command! -nargs=* FCL                call <SID>PreTreatmentFunction("CompareFocus", <f-args>)
command! -nargs=* FocusCompareLines  call <SID>PreTreatmentFunction("CompareFocus", <f-args>)

command! XL call <SID>RestoreAfterCompare()

function s:get_line_number_or_relatively(str)
	if a:str[0] == "+"
		return line(".") + str2nr(a:str[1:])
	elseif a:str[0] == "-"
		return line(".") - str2nr(a:str[1:])
	else
		return str2nr(a:str)
	endif
endfunction

" This function is called to
" - get the line numbers
" - check their existence in the buffer
" - save the foldmethod
" - create the mappings of the plugin
function! s:PreTreatmentFunction(function, ...)
    " Depending on the number of arguments define which lines to treat
    if len(a:000) == 0
        let l1=line(".")
        let l2=line(".")+1
    elseif len(a:000) == 1
        let l1 =line(".")
		let l2 =s:get_line_number_or_relatively(a:1)
    elseif len(a:000) == 2
        let l1 = s:get_line_number_or_relatively(a:1)
        let l2 = s:get_line_number_or_relatively(a:2)
    else
        echom "Bad number of arguments"
        return
    endif

    " Sort the lines
    if ( l1 > l2 )
        let temp = l2
        let l2 = l1
        let l1 = temp
    endif

    " Check that the lines are in the buffer
    if (l1 < 1 || l1 > line("$") || l2 < 1 || l2 > line("$"))
        echom ("A selected line is not in the buffer")
        return
    endif

    " Save user configurations
    " Handle foldmethod configuration
    let s:foldmethod_save=&foldmethod
    let s:hlsearch_save=&hlsearch
    execute "mkview! " . &viewdir . "compare-lines"

    " Change foldmethod to do ours foldings
    set foldmethod=manual

    " Create a mapping to quit the compare mode
    if !empty(maparg('<C-c>', 'n')) 
        let s:mapping_save = maparg('<C-c>', 'n', 0, 1)
    endif
    nnoremap <C-c> :XL<CR>

    " Depending on the command used call the corresponding function
    if a:function == "Compare"
        call CL#CompareLines(l1, l2)
    elseif a:function == "Focus"
        call CL#FocusLines(l1, l2)
    elseif a:function == "CompareFocus"
        call CL#CompareLines(l1, l2)
        call CL#FocusLines(l1, l2)
    else
        echoe "Unkown function call"
        return
    endif
endfunction

function! s:RestoreAfterCompare()
    " Remove search highlight
    nohlsearch

    " Remove foldings created by the plugin
    normal! zE

    " Restore user configuration
    execute "loadview " . &viewdir ."compare-lines"
    let &foldmethod=s:foldmethod_save
    let &hlsearch=s:hlsearch_save

    " Restore the mapping to its previous value
    unmap <C-c>
    if exists("s:mapping_save")
        execute (s:mapping_save.noremap ? 'nnoremap ' : 'nmap ') .
             \ (s:mapping_save.buffer ? ' <buffer> ' : '') .
             \ (s:mapping_save.expr ? ' <expr> ' : '') .
             \ (s:mapping_save.nowait ? ' <nowait> ' : '') .
             \ (s:mapping_save.silent ? ' <silent> ' : '') .
             \ s:mapping_save.lhs . " "
             \ s:mapping_save.rhs
    endif
endfunction
