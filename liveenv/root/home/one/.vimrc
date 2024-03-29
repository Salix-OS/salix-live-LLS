set nocompatible
set bs=2
set tw=0
set cindent

set ts=2 st=2 sw=2 ai et nobk ml
set mouse=a

set nowrapscan

set showmatch
set showmode
set uc=0
" This was causing trouble with the del key in many systems
" set t_kD=^?
map ^H X
map \e[3~ x
set mousehide
set hlsearch
let c_comment_strings=1

" Color for xiterm, rxvt, nxterm, color-xterm :
if has("terminfo")
set t_Co=8
set t_Sf=\e[3%p1%dm
set t_Sb=\e[4%p1%dm
else
set t_Co=8
set t_Sf=\e[3%dm
set t_Sb=\e[4%dm
endif

colorscheme evening

syntax on

autocmd FileType crontab :set backupcopy=yes
autocmd FileType crontab :set nobackup

