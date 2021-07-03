let s:save_cpo = &cpo
set cpo&vim

let s:on_windows = has('win32') || has('win64')
let s:dict_t = type({})
let s:list_t = type([])
if exists('v:true')
    let s:bool_t = type(v:true)
else
    let s:bool_t = -1
endif

" helper functions {{{
function! s:has_vimproc() abort
    if !exists('s:exists_vimproc')
        try
            silent call vimproc#version()
            let s:exists_vimproc = 1
        catch
            let s:exists_vimproc = 0
        endtry
    endif
    return s:exists_vimproc
endfunction

function! s:system(str, ...) abort
    let command = a:str
    let input = a:0 >= 1 ? a:1 : ''

    if a:0 == 0 || a:1 ==# ''
        silent let output = s:has_vimproc() ?
                    \ vimproc#system(command) : system(command)
    elseif a:0 == 1
        silent let output = s:has_vimproc() ?
                    \ vimproc#system(command, input) : system(command, input)
    else
        " ignores 3rd argument unless you have vimproc.
        silent let output = s:has_vimproc() ?
                    \ vimproc#system(command, input, a:2) : system(command, input)
    endif

    return output
endfunction

function! s:create_keyvals(key, val) abort
    if type(a:val) == s:dict_t
        return a:key . ': {' . s:stringize_options(a:val) . '}'
    elseif type(a:val) == s:bool_t
        return a:key . (a:val == v:true ? ': true' : ': false')
    elseif type(a:val) == s:list_t
        return a:key . ': [' . join(a:val,',') . ']'
    else
        return a:key . ': ''' . escape(a:val, '''') . ''''
    endif
endfunction

function! s:stringize_options(opts) abort
    let keyvals = map(items(a:opts), 's:create_keyvals(v:val[0], v:val[1])')
    return join(keyvals, ',')
endfunction

function! s:build_extra_options() abort
    let opts = copy(g:c_format#style_options)
    if has_key(g:swift_format#filetype_style_options, &ft)
        call extend(opts, g:swift_format#filetype_style_options[&ft])
    endif

    let extra_options = s:stringize_options(opts)
    if !empty(extra_options)
        let extra_options = ', ' . extra_options
    endif

    return extra_options
endfunction

function! s:make_style_options() abort
    let extra_options = s:build_extra_options()
    return printf("{BasedOnStyle: %s, IndentWidth: %d, UseTab: %s%s}",
                        \ g:swift_format#code_style,
                        \ (exists('*shiftwidth') ? shiftwidth() : &l:shiftwidth),
                        \ &l:expandtab==1 ? 'false' : 'true',
                        \ extra_options)
endfunction

function! s:success(result) abort
    let exit_success = (s:has_vimproc() ? vimproc#get_last_status() : v:shell_error) == 0
    return exit_success && a:result !~# '^YAML:\d\+:\d\+: error: unknown key '
endfunction

function! s:error_message(result) abort
    echoerr 'swift-format has failed to format.'
    echomsg a:result
    "if a:result =~# '^YAML:\d\+:\d\+: error: unknown key '
    "    echohl ErrorMsg
    "    for l in split(a:result, "\n")[0:1]
    "        echomsg l
    "    endfor
    "    echohl None
    "endif
endfunction

function! swift_format#get_version() abort
    if &shell =~# 'csh$' && executable('/bin/bash')
        let shell_save = &shell
        set shell=/bin/bash
    endif
    try
        let version_output = s:system(s:shellescape(g:swift_format#command).' --version 2>&1')
        return matchlist(version_output, '\(\d\+\)\.\(\d\+\).\(\d\+\)')[1:3]
    finally
        if exists('l:shell_save')
            let &shell = shell_save
        endif
    endtry
endfunction

function! swift_format#is_invalid() abort
    if !exists('s:command_available')
        if !executable(g:swift_format#command)
            return 1
        endif
        let s:command_available = 1
    endif

    if !exists('s:version')
        let v = swift_format#get_version()
        if len(v) < 2
            " XXX: Give up checking version
            return 0
        endif
        " if v[0] < 3 || (v[0] == 3 && v[1] < 4)
        "     return 2
        " endif
        let s:version = v
    endif

    return 0
endfunction

function! s:verify_command() abort
    let invalidity = swift_format#is_invalid()
    if invalidity == 1
        echoerr "swift-format is not found. check g:swift_format#command."
    elseif invalidity == 2
        " TODO ver check
        echoerr 'swift-format 3.3 or earlier is not supported for the lack of aruguments'
    endif
endfunction

function! s:shellescape(str) abort
    if s:on_windows && (&shell =~? 'cmd\.exe')
        " shellescape() surrounds input with single quote when 'shellslash' is on. But cmd.exe
        " requires double quotes. Temporarily set it to 0.
        let shellslash = &shellslash
        set noshellslash
        try
            return shellescape(a:str)
        finally
            let &shellslash = shellslash
        endtry
    endif
    return shellescape(a:str)
endfunction

" }}}

" variable definitions {{{
function! s:getg(name, default) abort
    " backward compatibility
    if exists('g:operator_'.substitute(a:name, '#', '_', ''))
        echoerr 'g:operator_'.substitute(a:name, '#', '_', '').' is deprecated. Please use g:'.a:name
        return g:operator_{substitute(a:name, '#', '_', '')}
    else
        return get(g:, a:name, a:default)
    endif
endfunction

let g:swift_format#command = s:getg('swift_format#command', 'swift-format')
let g:swift_format#extra_args = s:getg('swift_format#extra_args', "")
if type(g:swift_format#extra_args) == type([])
    let g:swift_format#extra_args = join(g:swift_format#extra_args, " ")
endif

let g:swift_format#code_style = s:getg('swift_format#code_style', 'google')
let g:swift_format#style_options = s:getg('swift_format#style_options', {})
let g:swift_format#filetype_style_options = s:getg('swift_format#filetype_style_options', {})

let g:swift_format#detect_style_file = s:getg('swift_format#detect_style_file', 1)
let g:swift_format#enable_fallback_style = s:getg('swift_format#enable_fallback_style', 1)

let g:swift_format#auto_format = s:getg('swift_format#auto_format', 0)
let g:swift_format#auto_format_on_insert_leave = s:getg('swift_format#auto_format_on_insert_leave', 0)
let g:swift_format#auto_formatexpr = s:getg('swift_format#auto_formatexpr', 0)
" }}}

" format codes {{{
function! s:detect_style_file() abort
    let dirname = fnameescape(expand('%:p:h'))
    return findfile('.swift-format', dirname.';') != '' || findfile('_swift-format', dirname.';') != ''
endfunction

function! swift_format#format(line1, line2) abort
    let args = ''
    " let args = printf(' -lines=%d:%d', a:line1, a:line2)
    " if ! (g:swift_format#detect_style_file && s:detect_style_file())
    "     if g:swift_format#enable_fallback_style
    "         let args .= ' ' . s:shellescape(printf('-style=%s', s:make_style_options())) . ' '
    "     else
    "         let args .= ' -fallback-style=none '
    "     endif
    " else
    "     let args .= ' -style=file '
    " endif
    let filename = expand('%')
    if filename !=# ''
        let args .= printf('--assume-filename=%s ', s:shellescape(escape(filename, " \t")))
    endif
    let args .= g:swift_format#extra_args
    let swift_format = printf('%s %s ', s:shellescape(g:swift_format#command), args)
    let source = join(getline(1, '$'), "\n")
    return s:system(swift_format, source)
endfunction
" }}}

" replace buffer {{{
function! swift_format#replace(line1, line2, ...) abort
    call s:verify_command()

    let pos_save = a:0 >= 1 ? a:1 : getpos('.')
    let formatted = swift_format#format(a:line1, a:line2)
    if !s:success(formatted)
        call s:error_message(formatted)
        return
    endif

    let winview = winsaveview()
    let splitted = split(formatted, '\n', 1)

    silent! undojoin
    if line('$') > len(splitted)
        execute len(splitted) .',$delete' '_'
    endif
    call setline(1, splitted)
    call winrestview(winview)
    call setpos('.', pos_save)
endfunction
" }}}

" auto formatting on insert leave {{{
let s:pos_on_insertenter = []

function! s:format_inserted_area() abort
    let pos = getpos('.')
    " When in the same buffer
    if &modified && ! empty(s:pos_on_insertenter) && s:pos_on_insertenter[0] == pos[0]
        call swft_format#replace(s:pos_on_insertenter[1], line('.'))
        let s:pos_on_insertenter = []
    endif
endfunction

function! swift_format#enable_format_on_insert() abort
    augroup plugin-swift-format-auto-format-insert
        autocmd! * <buffer>
        autocmd InsertEnter <buffer> let s:pos_on_insertenter = getpos('.')
        autocmd InsertLeave <buffer> call s:format_inserted_area()
    augroup END
endfunction
" }}}

" toggle auto formatting {{{
function! swift_format#toggle_auto_format() abort
    let g:swift_format#auto_format = !g:swift_format#auto_format
    if g:swift_format#auto_format
        echo 'Auto swift-format: enabled'
    else
        echo 'Auto swift-format: disabled'
    endif
endfunction
" }}}

" enable auto formatting {{{
function! swift_format#enable_auto_format() abort
    let g:swift_format#auto_format = 1
endfunction
" }}}

" disable auto formatting {{{
function! swift_format#disable_auto_format() abort
    let g:swift_format#auto_format = 0
endfunction
" }}}
let &cpo = s:save_cpo
unlet s:save_cpo
