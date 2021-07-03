if exists('g:loaded_swift_format')
   finish
endif

try
    call operator#user#define(
        \ 'swift-format',
        \ 'operator#swift_format#do',
        \ 'let g:operator#swift_format#save_pos = getpos(".") \| let g:operator#swift_format#save_screen_pos = line("w0")'
        \ )
catch /^Vim\%((\a\+)\)\=:E117/
    " vim-operator-user is not installed
endtry

command! -range=% -nargs=0 SwiftFormat call swift_format#replace(<line1>, <line2>)

command! -range=% -nargs=0 SwiftFormatEchoFormattedCode echo swift_format#format(<line1>, <line2>)

augroup plugin-swift-format-auto-format
    autocmd!
    autocmd BufWritePre *
        \ if &ft =~# '^\%(swift\)$' &&
        \     g:swift_format#auto_format &&
        \     !swift_format#is_invalid() |
        \     call swift_format#replace(1, line('$')) |
        \ endif
    autocmd FileType swift
        \ if g:swift_format#auto_format_on_insert_leave &&
        \     !swift_format#is_invalid() |
        \     call swift_format#enable_format_on_insert() |
        \ endif
    autocmd FileType swift
        \ if g:swift_format#auto_formatexpr &&
        \     !swift_format#is_invalid() |
        \     setlocal formatexpr=swift_format#replace(v:lnum,v:lnum+v:count-1) |
        \ endif
augroup END

command! SwiftFormatAutoToggle call swift_format#toggle_auto_format()
command! SwiftFormatAutoEnable call swift_format#enable_auto_format()
command! SwiftFormatAutoDisable call swift_format#disable_auto_format()

let g:loaded_swift_format = 1
