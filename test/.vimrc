filetype off
set nocompatible
set noloadplugins
exec 'set rtp+=' . getcwd() . '/test/vader.vim'
exec 'set rtp+=' . getcwd()
runtime plugin/cmake.vim
runtime plugin/vader.vim
filetype plugin indent on
syntax enable

function! Normalize(path, ...) abort
  let l:modifier = a:0 > 0 ? a:1 : ':p'
  let l:fname = fnamemodify(resolve(a:path), l:modifier)
  return expand(l:fname)
endfunction
