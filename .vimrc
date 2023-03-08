"         <|> MANUAL PACKAGES <|>
packadd! onedark.vim                                        " A dark color scheme inpsired by Atom"s One Dark

"         <|> PLUGIN CONFIG <|>
autocmd BufEnter * if (winnr("$") == 1 &&
    \ &filetype == "coc-explorer") | q | endif              " close explorer if it is the last buffer
autocmd BufWritePre <buffer> silent! undojoin |
    \ :call <SID>Fixers()                                   " call fixers on save
autocmd BufWritePre *.py Isort                              " call isort on save
autocmd FileType python setlocal commentstring=#\ %s        " configure commentary for python
autocmd FileType tex let b:dispatch="latexmk -pdf main.tex" " set latex compiler for dispatch
autocmd TabEnter * CocCommand explorer
autocmd VimEnter * CocCommand explorer
inoremap <silent> <expr> <TAB> coc#pum#visible()
    \ ? coc#pum#next(1) : "\<TAB>"                          " use tab to go forwards in autocomplete
inoremap <silent> <expr> <S-TAB> coc#pum#visible()
    \ ? coc#pum#prev(1) : "\<S-Tab>"                        " use shift-tab to go backwards in autocomplete
let g:airline#extensions#tabline#enabled=1                  " show buffers in tabline
let g:airline_powerline_fonts=1                             " use powerline fonts for statusbar
let g:coc_global_extensions=["coc-explorer", "coc-jedi",
    \ "coc-json", "coc-pairs", "coc-pyright", "coc-vimlsp"] " add explorer, jedi, json, pairs, pyright, & vimlsp coc extensions
let g:vim_isort_config_overrides={"profile": "black"}       " set isort to use black profile
nnoremap <silent> K :call CocAction("doHover")<CR>|         " induce hover action from lsp
nnoremap <silent> <expr> <C-o> (expand("%") =~
    \ "coc-explorer" ? "\<c-w>\<c-w>" : "").":Files\<CR>"   " do not open files in explorer with fzf
nnoremap <silent> <C-n> <Plug>(coc-diagnostic-next)|        " move to next coc diagnostic
nnoremap <silent> <C-p> <Plug>(coc-diagnostic-prev)|        " move to previous coc diagnostic

"         <|> EDITING <|>
filetype indent on                                          " copy indent from current line on <ENTER>
set autochdir                                               " update working directory dynamically
set clipboard=unnamed                                       " copy/paste from the system clipboard
set expandtab                                               " replace <TAB> with <SPACE>
set mouse=a                                                 " enable mouse scrolling
set nojoinspaces                                            " do not insert 2 spaces after a period
set nostartofline                                           " cursor maintains column position across lines
set scrolloff=35                                            " always keep <scrolloff> lines above & below the cursor
set shiftwidth=4                                            " text is indented <shiftwidth> columns w/ "<<" & ">>"
set softtabstop=4                                           " number of spaces in a <TAB> when editing
set tabstop=4                                               " number of visual spaces per <TAB> in a file

"  	      <|> UI CONFIG <|>
set cursorline                                              " highlight the text line of the cursor
set number relativenumber                                   " show hybrid line numbers
set switchbuf=useopen,usetab                                " switch to window with desired buffer, if available
set termguicolors                                           " enable 24-bit color support for terminal vim
syntax on                                                   " sets color of text based on category of terms

"         <|> FILE-SPECIFIC <|>
au Filetype tex,markdown syntax spell toplevel |
    \ setlocal textwidth=79 spell spelllang=en              " spellcheck partial text files & wrap at 79 characters
let g:tex_flavor="latex"                                    " set default tex flavor to LaTeX

"  	      <|> SEARCHING <|>
set hlsearch                                                " highlight matches
set ignorecase                                              " use case-insensitive search...
set incsearch                                               " search as characters are entered
set smartcase                                               " ... except when using capitals

"  	      <|> PERSONAL <|>
:command W w                                                " vim should do this by default
colorscheme onedark                                         " use one dark colortheme
hi Normal guibg=NONE ctermbg=NONE                           " use a transparent background
hi Terminal guibg=NONE ctermbg=NONE                         " use a transparent terminal
let &t_SI = "\<Esc>]50;CursorShape=1\x7"                    " Vertical bar in insert mode
let &t_EI = "\<Esc>]50;CursorShape=0\x7"                    " Block in normal mode
nnoremap <silent> <CR> :nohlsearch<CR>|                     " unset last search pattern via return
set guifont=DejaVuSansMono_Nerd_Font_Mono                   " use dejavu powerline nerd font
tnoremap <silent> <expr> <C-L> Clear()                      " use a better way to clear the screen

"        <|> FUNCTIONS <|>
function! Clear()                                           " add stdout to scrollback buffer and clear the screen
    let row=min([bufnr()->term_getcursor()[0]-1,
        \ bufnr()->term_getsize()[0]-2])
    if row > 0
        call term_sendkeys("", "tput indn " . row .
            \ " && clear \<CR>")
    endif
    return ""
endfunction
function! <SID>Fixers()                                     " remove trailing lines and trim whitespace
  if !&binary && &filetype != 'diff'
    let l:save = winsaveview()
    keeppatterns %s/\s\+$//e
    silent! %s#\($\n\s*\)\+\%$##
    call winrestview(l:save)
  endif
endfun
