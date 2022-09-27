" Disable compatibility with vi which can cause unexpected issues.
set nocompatible

" Enable type file detection. Vim will be able to try to detect the type of file in use.
filetype on

" Enable plugins and load plugin for the detected file type.
filetype plugin on

" Load an indent file for the detected file type.
filetype indent on

" Turn syntax highlighting on.
syntax on

" Add numbers to each line on the left-hand side.
set number

" Highlight cursor line underneath the cursor horizontally.
set cursorline

" Highlight cursor line underneath the cursor vertically.
set cursorcolumn

" See file name in toolbar
set laststatus=2

" Set shift width to 4 spaces.
set shiftwidth=4

" Set tab width to 4 columns.
set tabstop=4

" Use space characters instead of tabs.
set expandtab

" Do not save backup files.
set nobackup

" Do not let cursor scroll below or above N number of lines when scrolling.
set scrolloff=10

" Do not wrap lines. Allow long lines to extend as far as the line goes.
set nowrap

" While searching though a file incrementally highlight matching characters as you type.
set incsearch

" Ignore capital letters during search.
set ignorecase

" Override the ignorecase option if searching for capital letters.
" This will allow you to search specifically for capital letters.
set smartcase

" Show partial command you type in the last line of the screen.
set showcmd

" Show the mode you are on the last line.
set showmode

" Show matching words during a search.
set showmatch

" Use highlighting when doing a search.
set hlsearch

" Set the commands to save in history default number is 20.
set history=1000

" Enable auto completion menu after pressing TAB.
set wildmenu

" Make wildmenu behave like similar to Bash completion.
set wildmode=longest,list,full

" There are certain files that we would never want to edit with Vim.
" Wildmenu will ignore files with these extensions.
set wildignore=*.docx,*.jpg,*.png,*.gif,*.pdf,*.pyc,*.exe,*.flv,*.img,*.xlsx

" Set vim copy paste to be the same as mac
set clipboard=unnamedplus,unnamed,autoselect

" More powerful backspacing
set backspace=indent,eol,start

" Set Undo persistence for files
if !isdirectory($HOME."/.vim")
    call mkdir($HOME."/.vim", "", 0770)
endif
if !isdirectory($HOME."/.vim/undo-dir")
    call mkdir($HOME."/.vim/undo-dir", "", 0700)
endif
set undodir=~/.vim/undo-dir
set undofile

" Resize vim and tmux together
autocmd VimResized * :wincmd =

" Automatically close NERDTree when you open a file
let NERDTreeQuitOnOpen=1

" Completion window
:set completeopt=longest,menuone

" Slime stuff
" always use tmux
let g:slime_target = 'tmux'

" fix paste issues in ipython
let g:slime_python_ipython = 1

" always send text to the top-right pane in the current tmux tab without asking
let g:slime_default_config = {
            \ 'socket_name': get(split($TMUX, ','), 0),
            \ 'target_pane': '{top-right}' }
let g:slime_dont_ask_default = 1

" Settings for YouCompleteMe
" let g:ycm_python_interpreter_path = '/Users/nathanieljoselson/.pyenv/versions/3.9.5/bin'
" let g:ycm_python_sys_path = []
" let g:ycm_extra_conf_vim_data = [
"   \  'g:ycm_python_interpreter_path',
"     \  'g:ycm_python_sys_path'
"       \]
"       let g:ycm_global_ycm_extra_conf = '~/.global_extra_conf.py'


"Settings for Black
" autocmd BufWritePre *.py execute ':Black'

"Todo settings
let g:VimTodoListsDatesEnabled=1

" Colorscheme
" set background=light
" autocmd vimenter * ++nested colorscheme solarized8
" let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
" let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"


"FZF find .files
" let $FZF_DEFAULT_COMMAND = 'ag --hidden --ignore .git -g ""'

" PLUGINS ---------------------------------------------------------------- {{{
call plug#begin('~/.vim/plugged')

  Plug 'dense-analysis/ale'

  Plug 'preservim/nerdtree'

  Plug 'tpope/vim-surround'

  Plug 'christoomey/vim-tmux-navigator'

  Plug 'ycm-core/YouCompleteMe'
  
  Plug 'psf/black', { 'branch': 'stable' }

  Plug 'tpope/vim-fugitive'
  
  Plug 'tpope/vim-commentary'

  Plug 'tpope/vim-repeat'

  Plug 'mbbill/undotree'
   
  Plug 'ludovicchabant/vim-gutentags'

  Plug 'aserebryakov/vim-todo-lists'

  Plug 'lifepillar/vim-solarized8'

  Plug 'wellle/targets.vim'

  Plug 'Raimondi/delimitMate'
 
  Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }

  Plug 'junegunn/fzf.vim'

  Plug 'jpalardy/vim-slime', { 'for': 'python' }

  Plug 'hanschen/vim-ipython-cell', { 'for': 'python' }

call plug#end()

" }}}


" MAPPINGS --------------------------------------------------------------- {{{

" remap escape
inoremap jj <esc>

" remap leader
let mapleader = ","

"Add a breakpoint vim
map <leader>b o__import__("ipdb").set_trace()jj
" Have j and k navigate visual lines rather than logical ones
nnoremap j gj
nnoremap k gk
" " I like using H and L for beginning/end of line
nnoremap H ^
nnoremap L $

" toggle search highligh
map <leader>h :noh<CR>

" toggle set paste and set nopaste
map <leader>p :call TogglePaste()<cr>

" Nerdtree remappings
map <leader>t :NERDTreeToggle<CR>
nmap <Leader>r :NERDTreeFocus<cr>R<c-w><c-p>

" Undotree remappings
map <leader>u :UndotreeToggle<CR>

" FZF
map <leader>z :FZF<CR>

"------------------------------------------------------------------------------
" ipython-cell configuration
"------------------------------------------------------------------------------
" map <Leader>s to start IPython
nnoremap <Leader>S :SlimeSend1 ipython<CR>

" map <Leader>r to run script
nnoremap <Leader>R :IPythonCellRun<CR>

" map <Leader>R to run script and time the execution
nnoremap <Leader>R :IPythonCellRunTime<CR>

" map <Leader>c to execute the current cell
nnoremap <Leader>c :IPythonCellExecuteCell<CR>

" map <Leader>C to execute the current cell and jump to the next cell
nnoremap <Leader>C :IPythonCellExecuteCellJump<CR>

" map <Leader>l to clear IPython screen
nnoremap <Leader>l :IPythonCellClear<CR>

" map <Leader>x to close all Matplotlib figure windows
nnoremap <Leader>x :IPythonCellClose<CR>

" map [c and ]c to jump to the previous and next cell header
nnoremap [c :IPythonCellPrevCell<CR>
nnoremap ]c :IPythonCellNextCell<CR>

" map <Leader>h to send the current line or current selection to IPython
nmap <Leader>s <Plug>SlimeLineSend
xmap <Leader>s <Plug>SlimeRegionSend

" map <Leader>p to run the previous command
nnoremap <Leader>P :IPythonCellPrevCommand<CR>

" map <Leader>Q to restart ipython
nnoremap <Leader>Q :IPythonCellRestart<CR>

" map <Leader>d to start debug mode
nnoremap <Leader>d :SlimeSend1 %debug<CR>

" map <Leader>q to exit debug mode or IPython
nnoremap <Leader>q :SlimeSend1 exit<CR>

" map <F9> and <F10> to insert a cell header tag above/below and enter insert mode
nmap <F9> :IPythonCellInsertAbove<CR>a
nmap <F10> :IPythonCellInsertBelow<CR>a

" also make <F9> and <F10> work in insert mode
imap <F9> <C-o>:IPythonCellInsertAbove<CR>
imap <F10> <C-o>:IPythonCellInsertBelow<CR>
" }}}


" VIMSCRIPT -------------------------------------------------------------- {{{

" This will enable code folding.
" Use the marker method of folding.
augroup filetype_vim
    autocmd!
    autocmd FileType vim setlocal foldmethod=marker
augroup END

augroup numbertoggle
    autocmd!
    autocmd BufEnter,FocusGained,InsertLeave,WinEnter * if &nu && mode() != "i" | set rnu   | endif
    autocmd BufLeave,FocusLost,InsertEnter,WinLeave   * if &nu                  | set nornu | endif
augroup END
" More Vimscripts code goes here.

function! TogglePaste()
    if(&paste == 0)
        set paste
        echo "Paste mode enabled"
    else
        set nopaste
        echo "Paste mode disabled"
    endif
endfunction


" }}}


" STATUS LINE ------------------------------------------------------------ {{{

" Status bar code goes here.

" }}}
