set nocompatible                            " Vundle dependencies
set rtp+=~/.vim/bundle/Vundle.vim           " set the runtime path to include Vundle and initialize
call vundle#begin()
Plugin 'VundleVim/Vundle.vim'               " The plugin-manager for Vim
Plugin 'dense-analysis/ale'                 " Asynchronous lint engine
Plugin 'psf/black'                          " The uncompromising Python code formatter'
Plugin 'tpope/vim-dispatch'                 " Asynchronous build and test dispatcher
Plugin 'preservim/nerdtree'                 " A tree explorer plugin for vim
Plugin 'joshdick/onedark.vim'               " A dark color scheme inspired by Atom's One Dark
Plugin 'vim-airline/vim-airline'            " Lean & mean status/tabline for vim that's light as air
Plugin 'rhysd/vim-clang-format'             " Vim plugin for clang-format, a formatter for C, C++...
Plugin 'ycm-core/YouCompleteMe'             " A code-completion for Vim
call vundle#end()

"         <|> PLUGIN CONFIG <|>
let g:airline#extensions#tabline#enabled=1  " show buffers with tabs
let g:airline_powerline_fonts=1             " use powerline fonts for statusbar
autocmd VimEnter * NERDTree | wincmd p      " open nerdtree on start and switch buffer to edit file
autocmd bufenter * if (winnr("$") == 1
            \ && exists("b:NERDTree")
            \ && b:NERDTree.isTabTree()) 
            \ | q | endif                   " close nerdtree if no file is open

"         <|> FILE-SPECIFIC <|>
au Filetype plaintex,tex,markdown setlocal        
    \ textwidth=79                 
    \ spell spelllang=en                    " wrap at 79 characters & use spellchecking

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
set wildmenu                                " visual autocomplete for command menu
syntax on                                   " sets color of text based on category of terms

"  	      <|> SEARCHING <|>
set hlsearch                                " highlight matches
set ignorecase                              " use case-insensitive search...
set incsearch                               " search as characters are entered
set smartcase                               " ... except when using capitals

"  	      <|> PERSONAL <|>
command! W write                            " vim should do this by default
map /\ :noh                                 " redraw screen without highlighting 
colorscheme onedark                         " use one dark colortheme
set guifont=DejaVu\ Sans\ Mono
            \\ for\ Powerline               " use powerline font
