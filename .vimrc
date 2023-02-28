"         <|> MANUAL PACKAGES <|>
packadd! onedark.vim                                  " A dark color scheme inpsired by Atom's One Dark

"         <|> PLUGIN CONFIG <|>
autocmd VimEnter * NERDTree | wincmd p                " open nerdtree on start and switch buffer to edit file
autocmd bufenter * if (winnr("$") == 1
            \ && exists("b:NERDTree")
            \ && b:NERDTree.isTabTree())
            \ | q | endif                             " close nerdtree if no file is open
autocmd FileType python setlocal commentstring=#\ %s  " configure commentary for python
autocmd FileType tex let
    \ b:dispatch='latexmk -pdf main.tex'              " set latex compiler for dispatch
let g:airline#extensions#tabline#enabled=1            " show buffers with tabs
let g:airline_powerline_fonts=1                       " use powerline fonts for statusbar
let g:ale_python_flake8_options=
    \ '--max-line-length=88
    \  --extend-ignore=E203'                          " set flake8 to respect black defaults
let g:ale_fix_on_save=1                               " let ALE apply fixes on save
let g:ale_fixers={
    \ '*':['remove_trailing_lines',
    \       'trim_whitespace'],
    \ 'javascript': ['prettier'],
    \ 'python': ['autoimport', 'isort', 'black']}     " remove extra white spaces, lines, and set fixers
let g:ale_virtualtext_cursor=0                        " disable inline warnings and errors
let NERDTreeShowHidden=1                              " show hidden files in nerdtree by default
let g:ycm_autoclose_preview_window_after_completion=1 " when completing, let YCM close the preview window
let g:ycm_filetype_blacklist={'tex':1}                " don't use YCM for LaTeX
nmap <silent> <C-n> :ALENextWrap<CR>|                 " move to next ALE warning or error
nmap <silent> <CS-n> :ALEPreviousWrap<CR>|            " move to previous ALE warning or error
nnoremap <silent> <expr> <C-p> (expand('%') =~
    \ 'NERD_tree' ? "\<c-w>\<c-w>" : '').":FZF\<cr>"  " do not open files in nerdtree with fzf

"         <|> EDITING <|>
filetype indent on                                    " copy indent from current line on <ENTER>
set clipboard=unnamed                                 " copy/paste from the system clipboard
set expandtab                                         " replace <TAB> with <SPACE>
set mouse=a                                           " enable mouse scrolling
set nojoinspaces                                      " do not insert 2 spaces after a period
set nostartofline                                     " cursor maintains column position across lines
set scrolloff=35                                      " always keep <scrolloff> lines above & below the cursor
set shiftwidth=4                                      " text is indented <shiftwidth> columns w/ '<<' & '>>'
set softtabstop=4                                     " number of spaces in a <TAB> when editing
set tabstop=4                                         " number of visual spaces per <TAB> in a file

"  	      <|> UI CONFIG <|>
set completeopt+=popup                                " show completion information in a popup window
set completepopup=highlight:Pmenu                     " set popup window color to completion menu color
set number relativenumber                             " show hybrid line numbers
set termguicolors                                     " enable 24-bit color support for terminal vim
set wildmenu                                          " visual autocomplete for command menu
syntax on                                             " sets color of text based on category of terms

"         <|> FILE-SPECIFIC <|>
au Filetype tex,markdown syntax spell toplevel |
    \ setlocal textwidth=79 spell spelllang=en        " spellcheck partial text files & wrap at 79 characters
let g:tex_flavor="latex"                              " set default tex flavor to LaTeX

"  	      <|> SEARCHING <|>
set hlsearch                                          " highlight matches
set ignorecase                                        " use case-insensitive search...
set incsearch                                         " search as characters are entered
set smartcase                                         " ... except when using capitals

"  	      <|> PERSONAL <|>
:command W w                                          " vim should do this by default
colorscheme onedark                                   " use one dark colortheme
nnoremap <silent> <CR> :nohlsearch<CR><CR>|           " unset last search pattern via return
set guifont=DejaVuSansMono_Nerd_Font_Mono             " use dejavu powerline nerd font
