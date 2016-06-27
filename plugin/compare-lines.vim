" Vim plugin to diff two lines of a buffer and navigate through the changes
" File:     compare-lines.vim
" Author:   statox
" License:  This file is distributed under the MIT License

" Create the commands
command! -nargs=* CL2                call <SID>PreTreatmentFunction("Compare2", <f-args>)
command! -nargs=* CL                 call <SID>PreTreatmentFunction("Compare", <f-args>)
command! -nargs=* CompareLines       call <SID>PreTreatmentFunction("Compare", <f-args>)
command! -nargs=* FL                 call <SID>PreTreatmentFunction("Focus", <f-args>)
command! -nargs=* FocusLines         call <SID>PreTreatmentFunction("Focus", <f-args>)
command! -nargs=* FCL                call <SID>PreTreatmentFunction("CompareFocus", <f-args>)
command! -nargs=* FocusCompareLines  call <SID>PreTreatmentFunction("CompareFocus", <f-args>)

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
        let l2 =str2nr(a:1)
    elseif len(a:000) == 2
        let l1 = str2nr(a:1)
        let l2 = str2nr(a:2)
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
    nnoremap <C-c> :call <SID>RestoreAfterCompare()<CR>

    " Depending on the command used call the corresponding function
    if a:function == "Compare"
        call <SID>CompareLines(l1, l2)
    elseif a:function == "Compare2"
        call <SID>CompareLines2(l1, l2)
    elseif a:function == "Focus"
        call <SID>FocusLines(l1, l2)
    elseif a:function == "CompareFocus"
        call <SID>CompareLines(l1, l2)
        call <SID>FocusLines(l1, l2)
    else
        echoe "Unkown function call"
        return
    endif
endfunction

function! s:RestoreAfterCompare()
    " Remove search highlight
    if (s:current_matching != -1)
        call matchdelete(s:current_matching)
    endif

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

" Get two different lines and put the differences in the search register
function! s:CompareLines2(l1, l2)
    let l1 = a:l1
    let l2 = a:l2

    " Get the content of the lines
    let line1 = getline(l1)
    let line2 = getline(l2)

    " Get the longest common sequence between the lines
    let LCS = LCSpython(line1, line2)
    echo "LCS: " . LCS

    let pattern=""
    let loop=1
    let i=0
    let j=1
    
    " Get the differences between the first line and the LCS
    let diffs=[]
    let i=0
    let j=0
    for i in range(0, len(line1))
        if strpart(line1, i, 1) == strpart(LCS, j, 1)
            let j+=1
            "if pattern != ""
                call add(diffs, pattern)
                let pattern=""
            "endif
        else
            let pattern = pattern . strpart(line1, i, 1)
        endif
    endfor
    " Remove the empty parts
    call filter(diffs, 'count(diffs, v:val) == 1')
    " Join with a "and" in regex
    let pattern = join(diffs, '\|')
    " Add the line number and remove the last "\|"
    let pattern = "\\%" . l1 . "l" . strpart(pattern, 0, len(pattern)-2)

    echom "pattern: " . pattern

"abcdefghi
"abdehi
    
    " Search and highlight the diff
    execute "let @/='" . pattern . "'"
    normal! n
    "let s:current_matching = matchadd('Search', pattern)
    let s:current_matching = matchadd('error', pattern)
endfunction

"From http://rosettacode.org/wiki/Longest_common_subsequence#Python
" Find the longest common subsequence between two strings
function! LCSpython(line1, line2)
let LCS=""
python << EOF
import vim
def lcs(a, b):
    lengths = [[0 for j in range(len(b)+1)] for i in range(len(a)+1)]

    # row 0 and column 0 are initialized to 0 already
    for i, x in enumerate(a):
        for j, y in enumerate(b):
            if x == y:
                lengths[i+1][j+1] = lengths[i][j] + 1
            else:
                lengths[i+1][j+1] = max(lengths[i+1][j], lengths[i][j+1])

    # read the substring out from the matrix
    result = ""
    x, y = len(a), len(b)
    while x != 0 and y != 0:
        if lengths[x][y] == lengths[x-1][y]:
            x -= 1
        elif lengths[x][y] == lengths[x][y-1]:
            y -= 1
        else:
            assert a[x-1] == b[y-1]

            result = a[x-1] + result
            x -= 1
            y -= 1

    return result

vim.command("let LCS='%s'"% lcs(vim.eval("a:line1"), vim.eval("a:line2")))
EOF
return LCS
endfunction

" Get two different lines and put the differences in the search register
function! s:CompareLines(l1, l2)
    let l1 = a:l1
    let l2 = a:l2
    let s:current_matching = -1

    " Get the content of the lines
    let line1 = getline(l1)
    let line2 = getline(l2)

    let pattern = ""

    " Compare lines and create pattern of diff
    for i in range(strlen(line1))
        if strpart(line1, i, 1) != strpart(line2, i, 1)
            if pattern != ""
                let pattern = pattern . "\\|"
            endif
            let pattern = pattern . "\\%" . l1 . "l" . "\\%" . ( i+1 ) . "c"
            let pattern = pattern . "\\|" . "\\%" . l2 . "l" . "\\%" . ( i+1 ) . "c"
        endif
    endfor

    " Search and highlight the diff
    execute "let @/='" . pattern . "'"
    normal! n
    "let s:current_matching = matchadd('Search', pattern)
    let s:current_matching = matchadd('error', pattern)
endfunction

" Creates foldings to focus on two lines
function! s:FocusLines(l1, l2)
    let l1 = a:l1
    let l2 = a:l2

    if (l1 > 1)
        execute "1, " . ( l1 - 1 ) . "fold"
    endif

    if ( l2-l1 > 2 )
        execute (l1 + 1) . "," . (l2 - 1) . "fold"
    endif

    if (l2 < line('$'))
        execute (l2 + 1) . ",$fold"
    endif
endfunction
