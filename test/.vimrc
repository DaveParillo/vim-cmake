filetype off
set nocompatible
set noloadplugins
exec 'set rtp+=' . getcwd() . '/test/vader.vim'
exec 'set rtp+=' . getcwd()
runtime plugin/cmake.vim
runtime plugin/vader.vim
filetype plugin indent on
syntax enable

