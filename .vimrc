"         <|> MANUAL PACKAGES <|>
packadd! onedark.vim                        " A dark color scheme inpsired by Atom's One Dark

"         <|> PLUGIN CONFIG <|>
autocmd VimEnter * NERDTree | wincmd p      " open nerdtree on start and switch buffer to edit file
autocmd BufWritePre *.py execute ':Black'|  " run black on save
autocmd bufenter * if (winnr("$") == 1
            \ && exists("b:NERDTree")
            \ && b:NERDTree.isTabTree()) 
            \ | q | endif                   " close nerdtree if no file is open
let g:airline#extensions#tabline#enabled=1  " show buffers with tabs
let g:airline_powerline_fonts=1             " use powerline fonts for statusbar
let g:ale_fix_on_save=1                     " let ALE apply fixes on save
let g:ale_fixers={
    \ '*':['remove_trailing_lines',
    \      'trim_whitespace']}              " remove extra white spaces and lines
let g:ycm_filetype_blacklist={'tex':1}      " don't use YCM for LaTeX
nmap <silent> <C-n> :ALENextWrap<cr>        " move to next ALE warning or error
nmap <silent> <C-p> :ALEPreviousWrap<cr>    " move to previous ALE warning or error

"         <|> FILE-SPECIFIC <|>
au Filetype tex,markdown setlocal        
    \ textwidth=79                 
    \ spell spelllang=en                    " wrap at 79 characters & use spellchecking
let g:tex_flavor="latex"                    " set default tex flavor to LaTeX

"         <|> EDITING <|>
filetype indent on                          " copy indent from current line on <ENTER>
set clipboard=unnamed                       " copy/paste from the system clipboard
set expandtab                               " replace <TAB> with <SPACE>
set mouse=a                                 " enable mouse scrolling
set nostartofline                           " cursor maintains column position across lines
set scrolloff=35                            " always keep <scrolloff> lines above & below the cursor
set shiftwidth=4                            " text is indented <shiftwidth> columns w/ '<<' & '>>'
set softtabstop=4                           " number of spaces in a <TAB> when editing
set tabstop=4                               " number of visual spaces per <TAB> in a file

"  	      <|> UI CONFIG <|>
set number                                  " show line numbers
set termguicolors                           " enable 24-bit color support for terminal vim
set wildmenu                                " visual autocomplete for command menu
syntax on                                   " sets color of text based on category of terms

"  	      <|> SEARCHING <|>
set hlsearch                                " highlight matches
set ignorecase                              " use case-insensitive search...
set incsearch                               " search as characters are entered
set smartcase                               " ... except when using capitals

"  	      <|> PERSONAL <|>
"nnoremap :W :w                              " vim should do this by default
:command W w
colorscheme onedark                         " use one dark colortheme
nnoremap <CR> :noh<CR><CR>                  " unset last search pattern via return
set guifont=DejaVu\ Sans\ Mono
            \\ for\ Powerline               " use powerline font

