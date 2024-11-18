"        📦 Packages 📦
packadd! onedark.vim                                            " A dark color scheme inpsired by Atom's One Dark

"        🔌 Plugins 🔌
autocmd BufEnter * if (winnr("$") == 1 &&
  \ &filetype == 'coc-explorer') | q | endif                    " close explorer if it is the only window
autocmd BufWritePre <buffer> call <SID>Fixers()                 " call fixers on save
autocmd FileType python setlocal commentstring=#\ %s            " configure commentary for python
autocmd FileType tex let b:dispatch="latexmk -pdf main.tex"     " set latex compiler for dispatch
autocmd VimEnter,TabNew * exe "CocCom explorer" |               " open explorer on new tabs
let g:airline#extensions#tabline#enabled=1                      " show buffers in tabline
let g:airline#extensions#tabline#show_close_button=0            " do not show close button in tabline
let g:airline#extensions#tabline#show_splits=0                  " do not show open split in tabline
let g:airline#extensions#tabline#tab_nr_type=1                  " show tab number in tabline
let g:airline_powerline_fonts=1                                 " use powerline fonts for statusbar
let g:coc_global_extensions=["coc-diagnostic",
  \ "coc-dictionary", "coc-explorer", "coc-jedi",
  \ "coc-json", "coc-pairs", "coc-pyright", "coc-vimlsp",
  \ "coc-vimtex"]                                               " add coc extensions for writing, editing, and coding
nnoremap <silent> K :call CocAction("doHover")<CR>|             " induce hover action from lsp
nnoremap <silent> <expr> <C-b> (expand("%") =~
  \ "coc-explorer" ? "\<c-w>\<c-w>" : "").":Buffers\<CR>"       " do not open buffers in explorer with fzf
nnoremap <silent> <expr> <C-o> (expand("%") =~
  \ "coc-explorer" ? "\<c-w>\<c-w>" : "").":Files\<CR>"         " do not open files in explorer with fzf
nnoremap <silent> <C-g> :Rg<CR>|                                " open ripgrep with control-g
nnoremap <silent> <C-n> <Plug>(coc-diagnostic-next)|            " move to next coc diagnostic with control-n
nnoremap <silent> <C-p> <Plug>(coc-diagnostic-prev)|            " move to previous coc diagnostic with control-p
set tagfunc=CocTagFunc                                          " let coc drive tags

"        🖋 Editing 🖋
filetype indent on                                              " copy indent from current line on <ENTER>
nnoremap <silent> <CR> :nohlsearch<CR>|                         " unset last search pattern via return
set autoread                                                    " automatically read files when changed outside vim
set autowriteall                                                " automatically write when switching buffers
set clipboard=unnamed                                           " copy/paste from the system clipboard
set dictionary+=/usr/share/dict/words                           " add dictionary completion support
set expandtab                                                   " replace <TAB> with <SPACE>
set ignorecase                                                  " use case-insensitive search
set incsearch                                                   " search as characters are entered
set nojoinspaces                                                " do not insert 2 spaces after a period
set nostartofline                                               " cursor maintains column position across lines
set shiftwidth=4                                                " text is indented <shiftwidth> columns w/ "<<" & ">>"
set softtabstop=4                                               " number of spaces in a <TAB> when editing
set smartcase                                                   " override ignorecase when desired
set tabstop=4                                                   " number of visual spaces per <TAB> in a file

"  	     🖼 Interface 🖼
set cursorline                                                  " highlight the text line of the cursor
set hlsearch                                                    " highlight matches
set number relativenumber                                       " show hybrid line numbers
set mouse=a                                                     " enable mouse scrolling
set scrolloff=35                                                " always keep <scrolloff> lines above & below the cursor
set signcolumn=yes                                              " always add space for symbols
set switchbuf=useopen,usetab                                    " switch to window with desired buffer, if available
set termguicolors                                               " enable 24-bit color support for terminal vim
syntax on                                                       " sets color of text based on category of terms

"        📁 File-specific 📁
au Filetype tex,markdown syntax spell toplevel |
  \ setlocal textwidth=79 spell spelllang=en                    " spellcheck partial text files & wrap at 79 characters
let g:tex_flavor="latex"                                        " set the default tex flavor to latex

"  	     💻 Personal 💻
colorscheme onedark                                             " use one dark colortheme
command W w                                                     " vim should do this by default
hi Normal guibg=NONE ctermbg=NONE                               " use a transparent background
hi Terminal guibg=NONE ctermbg=NONE                             " use a transparent terminal
hi! link CocSymbolClass Structure                               " set coc class symbol color to Structure color
hi! link CocSymbolVariable Identifier                           " set coc variable symbol color to Identifier color
let &t_SI="\<Esc>]50;CursorShape=1\x7"                          " Vertical bar in insert mode
let &t_EI="\<Esc>]50;CursorShape=0\x7"                          " Block in normal mode
set guifont=DejaVuSansMono_Nerd_Font_Mono                       " use dejavu powerline nerd font

"        🧮 Functions 🧮
function! <SID>Fixers()                                         " remove trailing lines and trim whitespace
  if !&binary && &filetype != 'diff' && mode() ==# 'n'
    let l:cursor=getpos(".")
    silent! keeppatterns keepjumps execute 'undojoin | %s#[ \t]\+$##g' | update
    silent! keeppatterns keepjumps execute 'undojoin | :%s#\($\n\s*\)\+\%$##' | update
    call setpos('.', l:cursor)
  endif
endfun
