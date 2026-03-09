" cmake.vim - Vim plugin to make working with CMake a little nicer
" Maintainer:   Dirk Van Haerenborgh <http://vhdirk.github.com/>
" Version:      1.0

let s:cmake_plugin_version = '1.0'

if exists("loaded_cmake_plugin")
  finish
endif

" We set this variable here even though the plugin may not actually be loaded
" because the executable is not found. Otherwise the error message will be
" displayed more than once.
let loaded_cmake_plugin = 1

" Set option defaults
if !exists("g:cmake_export_compile_commands")
  let g:cmake_export_compile_commands = 0
endif
if !exists("g:cmake_ycm_symlinks")
  let g:cmake_ycm_symlinks = 0
endif
if !exists("g:cmake_use_smp")
  let g:cmake_use_smp = 0
endif

if !executable("cmake")
  echoerr "vim-cmake requires cmake executable. Please make sure it is installed and on PATH."
  finish
endif

" Public Interface:
command! -nargs=? -complete=customlist,s:list_targets CMakeBuild call cmake#CMakeBuild(<f-args>)
command! -nargs=? CMakeConfigure    call cmake#Configure(<f-args>)
command! -bang    CMakeClean        call cmake#CleanBuildDir(<bang>0)
command!          CMakeFindBuildDir call cmake#FindBuildDir()

function! s:list_targets(A, L, C) abort
  if !exists("b:build_dir")
    return []
  endif
  let l:all_targets = split(
        \ system("cmake --build " . b:build_dir . " --target help | awk 'NR > 1 {print $2}'"),
        \ '\n')
  return filter(l:all_targets, "v:val =~ '^" . a:A . "'")
endfunction

" Persist and restore b:build_dir across sessions
augroup vim_cmake_persist
  autocmd!
  autocmd BufReadPost  * call cmake#LoadBuildDir()
  autocmd BufWritePost * call cmake#SaveBuildDir()
augroup END

