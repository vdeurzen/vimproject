" vimproject.vim
" 
" Automatically determining project root directory and sourcing
" project-specific vim script.
"
" Version: 0.1
" Author: Dave van Soest
" Date: 2012-10-31
"       2012-09-09

"" Plugin configuration:
let g:vimProjectFilename = '.vimproject'


"" Find an ancestor directory with the specified file.
"" @param filename File name to search for.
"" @param dir Directory to start searching in.
"" @return The directory path or empty string if not found.
function! g:FindFileInAncestorDir(filename, dir)
	let curdir = simplify(a:dir."/")
	while 1
		if filereadable(curdir.a:filename)
			return curdir
		elseif curdir == "/"
			return ""
		endif
		let curdir = simplify(curdir."/../")
	endwhile
endfunction


let g:vimProjects = {}


function! s:fileModificationTime(filePath)
	return system('stat --printf=%Y ' . a:filePath) + 0
endfunction


function! s:sourceVimProjectFile(filePath)
	if filereadable(a:filePath)
		exec 'source ' . a:filePath
		let w:vimProjectFileModified = s:fileModificationTime(a:filePath)
	endif
endfunction


function! g:ResourceVimProjectFileIfModified()
	if exists('w:vimProjectRoot')
		let filePath = w:vimProjectRoot . g:vimProjectFilename
		let modified = s:fileModificationTime(filePath)
		if modified > w:vimProjectFileModified
			call s:sourceVimProjectFile(filePath)
		endif
	endif
endfunction


function! g:VimProjectSetDirAndPath()
	" Do nothing if the window has no associated project:
	if !exists('w:vimProjectRoot')
		return
	endif

	" Set dir and path:
	exec 'lcd ' . w:vimProjectRoot
	exec 'set path=' . join(w:vimProjectPath, ',')

	" Source the project file if modified:
	call g:ResourceVimProjectFileIfModified()
endfunction


"" Determine the project path and then:
""  1) Change the current directory to it.
""  2) Set the current path as it.
""  3) Source the vimproject file.
function! g:AutoVimProject()
	" Find the project path:
	let currentPath = expand("%:p:h")
	let projectRoot = g:FindFileInAncestorDir(g:vimProjectFilename, currentPath)
	if projectRoot == ""
		unlet! w:vimProjectRoot
		unlet! w:vimProjectName
		unlet! w:vimProjectPath
		return
	endif

	" VimProject info variables:
	let w:vimProjectRoot = projectRoot

	" VimProject info variables to be defined or extended in vimrproject file:
	let w:vimProjectName = 'UndefinedProject'
	let w:vimProjectPath = [projectRoot . '**']

	" Source the VimProject file:
	let filePath = projectRoot . g:vimProjectFilename
	call s:sourceVimProjectFile(filePath)

	" Add project to project dict:
	if has_key(g:vimProjects, w:vimProjectName) && g:vimProjects[w:vimProjectName] != w:vimProjectRoot
		echoerr 'Duplicate project names detected: ' . w:vimProjectName . '. Overriding existing entry.'
	endif
	let g:vimProjects[w:vimProjectName] = w:vimProjectRoot

	" Set dir and path for window:
	call g:VimProjectSetDirAndPath()
endfunction


"" Show Vim Project information:
function! g:VimProjectInfo()
	if exists('w:vimProjectRoot')
		echo 'Project name: ' . w:vimProjectName
		echo 'Project root path: ' . w:vimProjectRoot
		echo 'Project search path: ' . join(w:vimProjectPath, ',')
	else
		echo 'No VimProject'
	endif
endfunction


"" List all project names and paths:
function! g:VimProjectListAll()
	for [name, path] in items(g:vimProjects)
		echo name . ': ' . path
	endfor
endfunction


"" Auto commands
autocmd VimEnter,BufWinEnter,BufRead * call g:AutoVimProject()
autocmd WinEnter * call g:VimProjectSetDirAndPath()
autocmd BufRead,BufNewFile .vimproject set syntax=vim


"" Commands

" Information about the current project:
command! VPinfo call g:VimProjectInfo()

" List all projects:
command! VPall call g:VimProjectListAll()

" Create a tab and open the directory at the Vim Project path:
command! -nargs=1 -complete=customlist,VimProjectNames VPtab exec 'tabedit ' . g:vimProjects[<f-args>] | call g:AutoVimProject()
function! VimProjectNames(A,L,P)
	return filter(keys(g:vimProjects), 'strlen(v:val) >= strlen(a:A) && stridx(v:val, a:A) == 0')
endfunction

" Edit the current Vim Project file:
function! s:vimProjectEditProjectFile(...)
	if a:0 > 0
		exec 'tabedit ' . g:vimProjects[join(a:000, ' ')] . g:vimProjectFilename
	elseif exists('w:vimProjectRoot')
		exec 'tabedit ' . w:vimProjectRoot . g:vimProjectFilename
	else
		echo 'No VimProject'
	endif
endfunction
command! -nargs=? -complete=customlist,VimProjectNames VPedit call s:vimProjectEditProjectFile(<f-args>)

" Create a new Vim Project file:
function! s:vimProjectCreate(name)
	let filePath = getcwd() . '/' . g:vimProjectFilename
	if filereadable(filePath)
		echoerr 'Vim Project file already exists. Will not overwrite it.'
		return
	endif
	exec 'tabedit ' . filePath
	call setline(1, "let w:vimProjectName = '" . a:name . "'")
	call setline(2, '')
	call setline(3, '" Insert your project specific window initialization code here.')
	w
	call g:AutoVimProject()
endfunction
command! -nargs=1 VPcreate call s:vimProjectCreate(<f-args>)

" Re-source Vim Project file for current window:
" TODO: Not sure about the name of this command.
command! VPsource call g:ResourceVimProjectFileIfModified()

