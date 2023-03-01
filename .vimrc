"         <|> MANUAL PACKAGES <|>
packadd! onedark.vim                                        " A dark color scheme inpsired by Atom's One Dark

"         <|> PLUGIN CONFIG <|>
autocmd bufenter * if (winnr('$') == 1
            \ && exists('b:NERDTree')
            \ && b:NERDTree.isTabTree())
            \ | q | endif                                   " close nerdtree if no file is open
autocmd FileType python setlocal commentstring=#\ %s        " configure commentary for python
autocmd FileType tex let b:dispatch='latexmk -pdf main.tex' " set latex compiler for dispatch
autocmd VimEnter * NERDTree | wincmd p                      " open nerdtree on start and switch buffer to edit file
inoremap <silent> <expr> <tab> pumvisible()
    \ ? coc#_select_confirm() : "\<C-g>u\<TAB>"             " use tab to go forwards in autocomplete
inoremap <silent> <expr> <S-TAB> pumvisible()
    \ ? coc#pum#prev(1) : "\<C-h>"                          " use shift-tab to go backwards in autocomplete
let g:airline#extensions#tabline#enabled=1                  " show buffers with tabs
let g:airline_powerline_fonts=1                             " use powerline fonts for statusbar
let g:ale_linters={'python': ['flake8']}                    " set linters for ale to use
let g:ale_python_flake8_options='--max-line-length=88
    \  --extend-ignore=E203'                                " set flake8 to respect black defaults
let g:ale_fix_on_save=1                                     " let ALE apply fixes on save
let g:ale_fixers={
    \ '*':['remove_trailing_lines', 'trim_whitespace'],
    \ 'javascript': ['prettier'],
    \ 'python': ['autoimport', 'isort', 'black']}           " remove extra white spaces, lines, and set fixers
let g:ale_sign_error = '✘'                                  " use icons instead of >> for errors in ale
let g:ale_sign_warning = '⚠'                                " use icons instead of -- for warnings in ale
let NERDTreeShowHidden=1                                    " show hidden files in nerdtree by default
nnoremap <silent> K :call CocAction("doHover")<CR>|         " induce hover action from lsp
nnoremap <silent> <expr> <C-o> (expand('%') =~ 'NERD_tree'
    \ ? "\<c-w>\<c-w>" : '').":FZF\<CR>"                    " do not open files in nerdtree with fzf
nnoremap <silent> <C-n> :ALENextWrap<CR>|                   " move to next ALE warning or error
nnoremap <silent> <C-p> :ALEPreviousWrap<CR>|               " move to previous ALE warning or error

"         <|> EDITING <|>
filetype indent on                                          " copy indent from current line on <ENTER>
set clipboard=unnamed                                       " copy/paste from the system clipboard
set expandtab                                               " replace <TAB> with <SPACE>
set mouse=a                                                 " enable mouse scrolling
set nojoinspaces                                            " do not insert 2 spaces after a period
set nostartofline                                           " cursor maintains column position across lines
set scrolloff=35                                            " always keep <scrolloff> lines above & below the cursor
set shiftwidth=4                                            " text is indented <shiftwidth> columns w/ '<<' & '>>'
set softtabstop=4                                           " number of spaces in a <TAB> when editing
set tabstop=4                                               " number of visual spaces per <TAB> in a file

"  	      <|> UI CONFIG <|>
set number relativenumber                                   " show hybrid line numbers
set termguicolors                                           " enable 24-bit color support for terminal vim
syntax on                                                   " sets color of text based on category of terms

"         <|> FILE-SPECIFIC <|>
au Filetype tex,markdown syntax spell toplevel |
    \ setlocal textwidth=79 spell spelllang=en              " spellcheck partial text files & wrap at 79 characters
let g:tex_flavor='latex'                                    " set default tex flavor to LaTeX

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
