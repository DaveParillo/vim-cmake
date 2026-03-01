" autoload/cmake.vim - Implementation for vim-cmake
" Maintainer:   Dirk Van Haerenborgh <http://vhdirk.github.com/>
" Version:      0.3

" ------------------------------------------------------------
" Internal helpers (s: scope is per-file, so these are private
" to this autoload script)
" ------------------------------------------------------------

function! s:fnameescape(file) abort
  if exists('*fnameescape')
    return fnameescape(a:file)
  else
    return escape(a:file," \t\n*?[{`$\\%#'\"|!<")
  endif
endfunction

" Returns the path to the dotfile used to persist b:build_dir,
" anchored to the project root (one level above b:build_dir), or
" falling back to the directory of the current file.
function! s:dotfile_path() abort
  if exists('b:build_dir') && !empty(b:build_dir)
    return fnamemodify(b:build_dir, ':p:h:h') . '/.vim-cmake'
  endif
  return fnamemodify(expand('%:p:h'), ':p') . '/.vim-cmake'
endfunction

function! s:find_build_dir() abort
  " Do not overwrite already found build_dir, may be set explicitly by user.
  if exists("b:build_dir") && b:build_dir != ""
    return 1
  endif
  " Check dotfile cache first
  let l:dotfile = s:dotfile_path()
  if filereadable(l:dotfile)
    let l:lines = readfile(l:dotfile)
    if !empty(l:lines)
      let l:candidate = fnamemodify(l:lines[0], ':p')
      if isdirectory(l:candidate)
        let b:build_dir = l:candidate
        echom "vim-cmake: Restored build directory from cache: " . b:build_dir
        return 1
      else
        call delete(l:dotfile)
      endif
    endif
  endif
  " search filesystem
  let g:cmake_build_dir = get(g:, 'cmake_build_dir', 'build')
  let b:build_dir = finddir(g:cmake_build_dir, ';')
  if b:build_dir == ""
    " Find build directory in path of current file
    let b:build_dir = finddir(g:cmake_build_dir, s:fnameescape(expand("%:p:h")) . ';')
  endif
  if b:build_dir != ""
    " expand() would expand "" to working directory, but we need
    " this as an indicator that build was not found
    let b:build_dir = fnamemodify(b:build_dir, ':p')
    echom "Found cmake build directory: " . s:fnameescape(b:build_dir)
    call cmake#SaveBuildDir()
    return 1
  else
    echom "Unable to find cmake build directory."
    return 0
  endif
endfunction

function! s:find_smp() abort
  if executable('nproc')
    let l:nproc = system('nproc')
    let b:smp = '-j' . substitute(l:nproc, '\n\+$', '', '')
    return 1
  endif
  return 0
endfunction

function! s:cmake_configure(cmake_vim_command_args) abort
  exec 'cd' s:fnameescape(b:build_dir)
  let l:argument = []
  " Only change values of variables if project is not configured already,
  " otherwise we overwrite existing configuration.
  let l:configured = filereadable("CMakeCache.txt")
  if !l:configured
    if exists("g:cmake_project_generator")
      let l:argument += [ "-G \"" . g:cmake_project_generator . "\"" ]
    endif
    if exists("g:cmake_cxx_compiler")
      let l:argument += [ "-DCMAKE_CXX_COMPILER:FILEPATH=" . g:cmake_cxx_compiler ]
    endif
    if exists("g:cmake_c_compiler")
      let l:argument += [ "-DCMAKE_C_COMPILER:FILEPATH=" . g:cmake_c_compiler ]
    endif
    if exists("g:cmake_usr_args")
      let l:argument += [ g:cmake_usr_args ]
    endif
  endif
  if exists("g:cmake_install_prefix")
    let l:argument += [ "-DCMAKE_INSTALL_PREFIX:FILEPATH=" . g:cmake_install_prefix ]
  endif
  if exists("g:cmake_build_type")
    let l:argument += [ "-DCMAKE_BUILD_TYPE:STRING=" . g:cmake_build_type ]
  endif
  if exists("g:cmake_build_shared_libs")
    let l:argument += [ "-DBUILD_SHARED_LIBS:BOOL=" . g:cmake_build_shared_libs ]
  endif
  if exists("g:cmake_toolchain_file")
    let l:argument += [ "-DCMAKE_TOOLCHAIN_FILE:FILEPATH=" . g:cmake_toolchain_file ]
  endif
  if g:cmake_export_compile_commands
    let l:argument += [ "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON" ]
  endif

  let l:argumentstr      = join(l:argument, " ")
  let l:escaped_build_dir = s:fnameescape(b:build_dir)
  let l:home_dir          = "-H" . l:escaped_build_dir . "/.."
  let l:build_dir_path    = "-B" . l:escaped_build_dir
  let s:cmd = 'cmake ' . l:home_dir . ' ' . l:build_dir_path . ' ' . l:argumentstr
            \ . " " . join(a:cmake_vim_command_args)

  echo s:cmd
  if exists(":AsyncRun")
    execute 'copen'
    execute 'AsyncRun ' . s:cmd
    execute 'wincmd p'
  else
    silent let s:res = system(s:cmd)
    silent echo s:res
  endif

  " Create symbolic link to compilation database for use with YouCompleteMe
  if g:cmake_ycm_symlinks && filereadable("compile_commands.json")
    if has("win32")
      exec "mklink" "../compile_commands.json" "compile_commands.json"
    else
      silent echo system("ln -s " . s:fnameescape(b:build_dir) . "/compile_commands.json ../compile_commands.json")
    endif
    echom "Created symlink to compilation database"
  endif
  exec 'cd -'
endfunction

" ------------------------------------------------------------
" Public API (cmake# namespace — called from plugin/cmake.vim)
" ------------------------------------------------------------

function! cmake#Configure(...) abort
  if !s:find_build_dir()
    return
  endif
  call s:cmake_configure(a:000)
endfunction

function! cmake#CMake(...) abort
  if !s:find_build_dir()
    return
  endif
  if g:cmake_use_smp && s:find_smp()
    let l:smp = ' ' . shellescape(b:smp)
  else
    let l:smp = ''
  endif
  let &makeprg = 'sh -c ''cmake --build ' . shellescape(b:build_dir) . l:smp
              \ . ' ${1:+--target "$@"}'' sh'
  if !filereadable(b:build_dir . '/CMakeCache.txt')
    call s:cmake_configure([])
  endif
  execute 'make ' . join(a:000)
endfunction

function! cmake#FindBuildDir() abort
  unlet! b:build_dir
  call delete(s:dotfile_path())
  call s:find_build_dir()
endfunction

function! cmake#SaveBuildDir() abort
  if !exists('b:build_dir') || empty(b:build_dir)
    return
  endif
  let l:dotfile = s:dotfile_path()
  call writefile([b:build_dir], l:dotfile)
endfunction

function! cmake#LoadBuildDir() abort
  " Don't overwrite an already-set value
  if exists('b:build_dir') && !empty(b:build_dir)
    return
  endif
  let l:dotfile = s:dotfile_path()
  if !filereadable(l:dotfile)
    return
  endif
  let l:lines = readfile(l:dotfile)
  if empty(l:lines)
    return
  endif
  let l:candidate = fnamemodify(l:lines[0], ':p')
  if isdirectory(l:candidate)
    let b:build_dir = l:candidate
  else
    " Dotfile is stale - build dir no longer exists
    call delete(l:dotfile)
  endif
endfunction

function! cmake#CleanBuildDir(bang) abort
  if !exists('b:build_dir') || empty(b:build_dir)
    echohl ErrorMsg
    echom 'vim-cmake: No build directory set. Run :CMake or :CMakeFindBuildDir first.'
    echohl None
    return
  endif

  let l:build_dir = fnamemodify(b:build_dir, ':p')

  if !isdirectory(l:build_dir)
    echohl ErrorMsg
    echom 'vim-cmake: Build directory does not exist: ' . l:build_dir
    echohl None
    return
  endif

  " Guard against cleaning obviously dangerous paths
  let l:home = fnamemodify('~', ':p')
  let l:cwd  = fnamemodify('.', ':p')
  let l:root = '/'
  if l:build_dir ==# l:home || l:build_dir ==# l:cwd || l:build_dir ==# l:root
    echohl ErrorMsg
    echom 'vim-cmake: Refusing to clean a root, home, or working directory: ' . l:build_dir
    echohl None
    return
  endif

  " Require CMakeCache.txt as a sanity check
  if !filereadable(l:build_dir . '/CMakeCache.txt')
    echohl WarningMsg
    echom 'vim-cmake: Directory does not look like a CMake build dir (no CMakeCache.txt): ' . l:build_dir
    echohl None
    if !a:bang
      return
    endif
    echom 'vim-cmake: Proceeding anyway due to !-bang override.'
  endif

  " Prompt unless bang
  if !a:bang
    let l:answer = input('vim-cmake: Clean all files in ' . l:build_dir . '? [y/N] ')
    echo ' '
    if l:answer !~? '^y\(es\)\?$'
      echom 'vim-cmake: Clean cancelled.'
      return
    endif
  endif

  echom 'vim-cmake: Cleaning ' . l:build_dir . ' ...'
  let l:errors = delete(l:build_dir, 'rf')
  if l:errors != 0
    echohl ErrorMsg
    echom 'vim-cmake: Clean failed (delete returned ' . l:errors . ').'
    echohl None
  else
    echom 'vim-cmake: Done.'
    unlet b:build_dir
    call delete(s:dotfile_path())
  endif
endfunction

