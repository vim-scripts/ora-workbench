" Purpose: Workbench for Oracle Databases
" Version: 1.9
" Author: rkaltenthaler@yahoooooo.com
" Last Modified: $Date: 2013-04-09 10:10:38 +0200 (Tue, 09 Apr 2013) $
" Id : $Id: orawb.vim 325 2013-04-09 08:10:38Z nikita $
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"
" Description:
" This file contains functions/commands/abbreviations to make Vim an
" Oracle SQL*Plus IDE.
" The main highlights of this script are:
"
" - command Ys[how] to login to an Oracle database an to show a tree of the
"   database objects
" - command Yo[pen] to edit database objects in vim
" - command Ym[ake] to compile database objects.
" 
" This script requires an Oracle client installtion on your computer. The
" script calls sqlplus. If sqlplus is not in your PATH you need to alter the
" script variable s:sqlcmd.
"
"
" This script contains parts from Rajesh Kallingal's script oracle.vim.
"
" Installation:
" 	Just drop it this file in your plugin folder/directory. To get some of the
" 	additional features you have to download the ftplugin sql.vim and put that
" 	in the ftplugin folder/directory
"
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Do not load, if already been loaded
if exists("loaded_sqlrc")
	delfunction WBLoad
	delfunction WBOpenObject
	delfunction WBCompileObject
	delfunction WBInitDescriptionWindow
	delfunction WBShow
	delfunction WBHide
	delfunction WBInitWorksheet
	delfunction WBGetObjectInfoFromTree
	delfunction WBChangeConnection
	delfunction WBChangeConnection2
	delfunction WBDescribeObject
	delfunction WBLoadObjectType
	delfunction WBKeyMappingGeneral
	delfunction WBKeyMappingCompiler
	delfunction WBSqlPlus
	delfunction CreateTmpBuffer
	delfunction CheckModified
	delfunction CheckConnection
	delfunction DescribeObject
	delfunction DescribeNamedObject
	delfunction GetColumns
	delfunction GetPackageFunctions
	delfunction OmniComplet
	delfunction CompletTable
	delfunction CompletFunction
	delfunction GetSourceForObject
	delfunction SqlPlus
	delfunction ListInvalidObjects
	delfunction SqlMake
	delfunction FormatErrorMessage
	delfunction SwitchToDesc
	delfunction SelectDataFromObject
	delfunction CreateTmpFile
	delfunction CreateTmpFilename
	delfunction CreateTmpFilename2
	delfunction SqlCompile
	delfunction DisplaySynonym
	delfunction DisplayQueue
	delfunction DisplayJob
	delfunction DisplayTrigger
	delfunction DisplaySequence
	delfunction DisplayIndex
	delfunction DisplayConstraint
	delfunction DisplaySingleRecord
	delfunction DisplaySingleRecordInternal
	delfunction LoadAutoCommands
	delfunction BuildConnectString
	delfunction SetupStatusLine
	delfunction ChangeConnection
	delfunction ChangeConnection2
	delfunction CreateSourceForSynonym
	"  finish
endif

let loaded_sqlrc=1


" Line continuation used here
let s:cpo_save = &cpo
set cpo&vim


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Variables
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" following are the default values for the variables used to connect to an
" Oracle instance. you can change these variables to connect to a different
" instance or as a different user. use :CC command to change the connection
" variables. 

let s:sqlcmd='sqlplus '	" executable name of SQL*Plus (non GUI version), if sqlplus is not in the PATH, use the complete path to sqlplus. Make sure you insert a space before the ending quote (')
let s:user=''	" Default Oracle user name
let s:password=''	" Default Oracle password
let s:server=''	" Default Oracle server to use
let s:sysdba='N' " Default: user is not the SYSDBA
let s:connect_string='' " Connection string
let g:orawb_connect_status='?' " Status text

let g:dateformat="'YYYYMMDD HH24MI'"	" Default date format to use
let s:do_highlight_errors=1 " set this variable to 1 to highlight errors after compiling, set to 0 to turn it off
let s:autocmd_loaded=0	"flag to remember if the VIM autocommands for ORACLE are loaded

" -- Workbench stuff

" Tree buffer
let s:treebuffer=-1  " empty = tree-buffer not open 
let s:treewidth=25 " width of the tree window
let s:tree_reload=0 " flag: 1==the tree needs to be re-loaded

" Description buffer
let s:descbuffer=-1 " buffer number of the description buffer
let s:sqlerr=0 " SQLERR from SQLPLUS
let s:wsbuffer=-1 " buffer number of the worksheet
let s:keywordfile = "__KEYWORDS.sql" " known keywords for the session
let s:filenumber=1 " number for temp-file-names

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Commands
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
command! -range=% Sql call SqlPlus ()
command! -nargs=* Yshow call WBShow(<f-args>)
command! Yhide call WBHide()
command! -nargs=* Yconnection call WBChangeConnection(<f-args>)

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Global key mappings 
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" WBSqlPlus - call SQLPlus for the current SQL worksheet
"
" Run the content of the current buffer as SQLPlus commands.
" Send the output to the description window
"
function WBSqlPlus(...)
  	if CheckConnection () != 0
 		return -1
	endif

	" remember this window
	let CurrentWnd = bufwinnr("%")
 
 	" insert the layout settings
 	call append("0","SET PAGESIZE 999")
 	call append("0","SET TAB OFF")
 	
 	" append the QUIT command
 	call append("$","QUIT ROLLBACK")
 
	" write the content of the worksheet to a buffer
	silent execute "1,$y z"

 	" remove the line with the QUIT command from the buffer
 	execute '$,$d'
	" remove the lines with the format commands from the buffer
 	execute '1,2d'
 
 	" Switch to the desciption buffer
 	call SwitchToDesc()
	
	" Paste the text into the buffer
	silent execute ":put! z"

	" Build the command line. The result will look like this:
	" sqlplus -S kalle/kalle@mydatabase @@ param1 param2 ....
	
	" Build the parameter part of the command line
	let params = ""
	if a:0 > 0
		let params = " @@"
		for x in a:000
			let params = params . " " . x
		endfor
	endif	
	
	" Execute the range and display the result in buffer
	" echo a:firstline "," a:lastline
	silent execute '1,$!' . s:sqlcmd . '-S ' . s:connect_string . params
	normal 1G
 
 	" save SQL error message
 	let s:sqlerr =  v:shell_error

	" return to the original window
	silent execute CurrentWnd . 'wincmd w'
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Get name and type of an object from the tree
" To use  this function, the cursor must be placed
" in the tree.
"
" Parameter : /
" return: Dictionary 	[result] :  	error code (0==OK)
" 			[name] : 	object name
" 			[type] : 	object type 
function WBGetObjectInfoFromTree()
	" pattern to match the [nnnn] key in the line
	let l:keypattern='\[[A-Z0-9_$ a-z]\+\]'

	let l:result = { "code": 0 ,"name":'' ,"type":'',"parent":''}  
	
	" remember the current position
	let currentPos=getpos(".")	
	
	" select the object name
	normal 1|
	let NameStartPos = searchpos('\i')
	let NameEndPos = searchpos('\s')
        let NameLine = getline(".")	
	let l:result.name=strpart(NameLine,get(NameStartPos,1)-1,get(NameEndPos,1)-get(NameStartPos,1))
	
	" get the type-key. It looks like  this: [TABLE]
	let l:typekey = matchstr(getline('.'),l:keypattern,0,1)   
	let l:result.type=strpart(l:typekey,1,strlen(l:typekey)-2)
	
	" get the parent-key. It looks like this: [ERGEBNIS]
	let l:parentkey = matchstr(getline('.'),l:keypattern,0,2)   
	let l:result.parent=strpart(l:parentkey,1,strlen(l:parentkey)-2)

	return l:result
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" COMPILE an object from the tree. 
" Execute the following steps:
" 1. get the name of the object
" 2. get the type of the object
" 3. Build a directory containing the compile commands for the diffeent object
" types.
" 4. Call the SqlCompile function with the parameters:
" 	object name
" 	object type
" 	compile command
"
function WBCompileObject()
	" Get information about the object
	let ObjInfo=WBGetObjectInfoFromTree()

	" Fill the directory of compile statements 
	let fktdir={}
	let fktdir["PACKAGE"]="alter package %1 compile specification"
	let fktdir["PACKAGE BODY"]="alter package %1 compile body"
	let fktdir["TYPE"]="alter type %1 compile specification"
	let fktdir["TYPE BODY"]="alter type %1 compile body"
	let fktdir["FUNCTION"]="alter function %1 compile"
	let fktdir["PROCEDURE"]="alter procedure %1 compile"
	let fktdir["VIEW"]="alter view %1 compile"
	let fktdir["TRIGGER"]="alter trigger %1 compile"

	" check, if the object is in the dictionary
	if has_key(fktdir,ObjInfo.type)
		" get the function that compiles the object
		let Compilefkt=substitute(fktdir[ObjInfo.type],"%1",ObjInfo.name,"g")
	
		" ...and compile
		echo Compilefkt
		call SqlCompile(Compilefkt,ObjInfo.name,ObjInfo.type)	
	else
		echo "dont know how to compile this."
	endif
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" (re) compile an existing object in the database
"
" Parameter:
" [in] SQL command to compile the object
" [in] Name of the object e.g Kalle
" [in] Type of the object e.g. PROCEDURE
"
" Do this:
" 1. remember the current window / buffer
" 2. open the description buffer
" 3. write the compile command to the description buffer
" 4. Add some SQL*Plus to display error messages
" 5. Call SQLPLUS
" 6. return to the original buffer
"
function SqlCompile(SqlCommand,ObjectName,ObjectType)
	" check the DB connection
	if CheckConnection() != 0
		return
	endif
 
 	" remember the current window
 	let CurrentWnd=bufwinnr("%")
 
 	" open the description window
 	call SwitchToDesc()
 
 	" the description buffer is empty. Write the compile commands
 	" into the buffer
 	let SqlCommandLine = a:SqlCommand . ';'
 	call append("0", SqlCommandLine )
	call append("$", "SHOW ERRORS " . a:ObjectType . " " . a:ObjectName)

	" compile using SQLPLUS
	1,$call SqlPlus()

	" return to the original window
	silent execute CurrentWnd . "wincmd w"	
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" OPEN an object from the tree. 
" Execute the following steps:
" 1. get the name of the object
" 2. get the type of the object
" 3. select the corresponding OPEN function from the directory
" 4. execute the OPEN function
"
function WBOpenObject()
	" Get information about the object
	let ObjInfo=WBGetObjectInfoFromTree()
	
	" Fill the parameter list.
	" P1 = object name
	" P2 = object type
	let parameters=[ObjInfo.name,ObjInfo.type]

	" Fill the directory of functions
	let fktdir={}
	let fktdir["PACKAGE"]=function("GetSourceForObject")
	let fktdir["PACKAGE BODY"]=function("GetSourceForObject")
	let fktdir["TYPE"]=function("GetSourceForObject")
	let fktdir["TYPE BODY"]=function("GetSourceForObject")
	let fktdir["FUNCTION"]=function("GetSourceForObject")
	let fktdir["PROCEDURE"]=function("GetSourceForObject")
	let fktdir["TABLE"]=function("SelectDataFromObject")
	let fktdir["VIEW"]=function("SelectDataFromObject")
	let fktdir["TRIGGER"]=function("GetSourceForObject")
	let fktdir["SCHEMA"]=function("WBChangeConnection2")
	let fktdir["SYNONYM"]=function("CreateSourceForSynonym")
	let fktdir["DATABASE LINK"]=function("DisplayDBLink")

	" check if a function exits
	if has_key(fktdir,ObjInfo.type)
		" get the function that opens the object
		let Openfkt=fktdir[ObjInfo.type]
	
		" echo string(Openfkt)	
 		let r=call(Openfkt,parameters)	
	endif
endfunction


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Load the SQL workbench
" 
function! WBLoad()
	if CheckConnection () != 0
		return
	endif

	" remove current content
	:1,$d
	
	" generate load-script and call SqlPlus to execute it
	call WBLoadObjectType()
	" return

	" inform the user: we are loading...
	echo "loading..."
	1,$call SqlPlus()
	" check for errors
	if s:sqlerr != 0
		return 
	endif

	set foldmethod=manual
	normal zE

	let l:keywordfilename=CreateTmpFilename(s:keywordfile)
	
	" move the keywords to a seperate file
	execute 'set dictionary-=' . keywordfilename
	redraw
	call cursor(1,1)
	" call input(getline(234))
	let l:keywordline=search('\c#KEYWO','w')
	" call input(string(l:keywordline))
	execute ",$w! " . l:keywordfilename
	execute 'set dictionary+=' . keywordfilename

	" delete the keywords from the tree
	execute ",$d"	
	normal 1G	
	setlocal ts=8 nomodified
	
	" Define the text of the FOLDs
	set foldtext=matchstr(getline(v:foldstart),'^\\s*').'+'.matchstr(getline(v:foldstart),'\\S\\+\\s\\?\\S*')

	" Define the expression that VIM uses  the calculate the begin and
	" the end of a fold
	set foldexpr=(indent(v:lnum)>indent(v:lnum+1)?'<'.string(indent(v:lnum)/4):(indent(v:lnum)<indent(v:lnum+1)?'>'.string(indent(v:lnum+1)/4):string(indent(v:lnum+1)/4)))    
	set foldmethod=expr

	" reload has been done
	let s:tree_reload=0
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Hide the workbench
"
" Do this:
"
" Tree Buffer
" -----------
" if the tree buffer does not exist or is not visible do nothing
" if the tree buffer is visible then
" 	- save its content
" 	- close the window
"
" Description Buffer
" ------------------
" if the description buffer does not exist or is not visible do nothing
" if the description buffer is visible then:
" 	- save its content
" 	- close the window
"
"
function WBHide()
	" remember the active buffer
	let currentBuffer=bufnr("%")
	
	" check the tree window
	if s:treebuffer > 0
		" tree is loaded. Check the window
		if bufwinnr(s:treebuffer) >  0
			" close the window   
			silent execute bufwinnr(s:treebuffer) . 'wincmd w'
			silent execute 'hide'
		endif
	endif	

	" check the description window
	if s:descbuffer > 0
		try
			" description is loaded. Check the window
			if bufwinnr(s:descbuffer) > 0
				"close the window
				silent execute bufwinnr(s:descbuffer) . 'wincmd w'
				silent execute 'hide'
			endif
		catch
			"echo KL>can not close	
		endtry	
	endif
	
	" check the SQLWorksheet window
	if s:wsbuffer > 0
		try
			" SQL worksheet loaded
			if bufwinnr(s:wsbuffer) > 0
				" close the window
				silent execute bufwinnr(s:wsbuffer) . 'wincmd w'
				silent execute 'hide'
			endif
		catch
			"echo KL>can not close	
		endtry	
	endif

	" go back to original window
 	"" silent execute bufwinnr(currentBuffer) . 'wincmd w'
endfunction


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" WBKeyMappingGeneral
" ------------------------
"
"  Do this:
"  - define the database shorts-cuts that are available to all buffers
"
"  This are:
"  SqlMake(), DescribeObject(), WBShow(), WBHide(), 
"  WBChangeConnection()
"
"
function WBKeyMappingGeneral()
	command! -nargs=* Ymake call WBSqlPlus(<f-args>)
	command! Ydescribe call DescribeObject()
	command! Yworksheet call WBInitWorksheet()
	
	" add key mappings
	nmap Ys Y:call WBShow()<C-M>
	nmap Yh Y:call WBHide()<C-M>
	nmap Yc Y:call WBChangeConnection() <C-M>
	nmap Yw Y:call WBInitWorksheet() <C-M>
	nmap Ym Y:call WBSqlPlus()<C-M>
	nmap Yd Y:call DescribeObject()<C-M>
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" WBKeyMappingCompiler
" --------------------
"
"  Setup the keymappings for buffers  that can be compiled.
"  This function is used for:
"  Package Spec and Body
"  Type Spec and Body
"  
function WBKeyMappingCompiler()
	" add commands
	command!-buffer Ymake call SqlMake()
	command!-buffer Ydescribe call DescribeObject()
	command!-buffer Yworksheet call WBInitWorksheet()
	
	" add key mappings
	nmap <buffer> Ys Y:call WBShow()<C-M>
	nmap <buffer> Yh Y:call WBHide()<C-M>
	nmap <buffer> Yc Y:call WBChangeConnection() <C-M>
	nmap <buffer> Yw Y:call WBInitWorksheet() <C-M>
	nmap <buffer> Ym Y:call SqlMake()<C-M>
	nmap <buffer> Yd Y:call DescribeObject()<C-M>
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Show the workbench
"
" Do this:
"
" Tree Buffer
" -----------
" if the tree buffer exists and is visible do nothing
" if the tree buffer exists and is not visible, split the window
" 	and show the buffer
" if the tree buffer does not exist,
" 	- split the window
" 	- create it (empty)
"	- fill it with data
" 
" Description Window
" ------------------
" if the description buffer exists and is visible do nothing
" if the description buffer exists an is not visible, split the 
" 	window an show the buffer
" if the description buffer does not exist,
" 	- split the windows
" 	- create it (empty)
"
function WBShow(...)
	" if we'v got parameter, they are used as the connect string for
	" SQLPLUS
	let l:params=""
	if a:0 > 0
		for x in a:000
			let l:params=l:params . " " . x
		endfor
		call ChangeConnection2(l:params)
	endif	
	
	" check if we can connect to ORACLE
	if CheckConnection () != 0
		return
	endif
	" remember the number of the current activ buffer
	let currentBuffer=bufnr("%")

	if bufexists(s:treebuffer) > 0
		" the TREE buffer exist. Check, if the buffer is displayed in
		" a window
		if bufwinnr(s:treebuffer) <= 0
			" the buffer is not visible. Display it
			4wincmd k
			4wincmd h
			setlocal nosplitright
			vsplit 
        		silent execute 'vertical resize '. string(s:treewidth)
			silent execute 'b ' . s:treebuffer
		else
			" the buffer is visible. Focus it
			silent execute bufwinnr(s:treebuffer) . 'wincmd w'
		endif
		" if parameter have been supplied, the connection may have
		" changed - we need to re-load the tree
		if (a:0 > 0) || (s:tree_reload==1)
			call WBLoad()
		endif	
	else
		" the tree buffer is not existing
		silent execute 'vnew'
        	silent execute 'vertical resize '. string(s:treewidth)
		let s:treebuffer=bufnr('%')
		
		" set window attributes 
		set nowrap
		set foldenable
		set foldmethod=manual
		setlocal buftype=nofile
		setlocal bufhidden=hide
		setlocal noswapfile
		setlocal filetype=sql
		setlocal nobuflisted
		setlocal noautochdir
		
		" fill the buffer
		call WBLoad()
		
		" load commands that are available for all buffers
		call WBKeyMappingGeneral()

		" show the statusline with USER@HOST
		execute "setlocal  statusline=[Yd][Ym][Yo][Yu]"
		
		" load commands for the tree-buffer
		command!-buffer Ymake call WBCompileObject()
		command!-buffer Ydescribe call WBDescribeObject()
		command!-buffer Yopen call WBOpenObject()
		command!-buffer Yinvalid call ListInvalidObjects()
		command!-buffer Yupdate call WBLoad()
		
		" load the short-cuts for the tree-buffer
		nmap <buffer> Ys Y:call WBShow() <C-M>
		nmap <buffer> Yh Y:call WBHide() <C-M>
		nmap <buffer> Yc Y:call WBChangeConnection() <C-M>
		nmap <buffer> Yd Y:call WBDescribeObject() <C-M>
		nmap <buffer> Yo Y:call WBOpenObject() <C-M>
		nmap <buffer> Yu Y:call WBLoad() <C-M>
		nmap <buffer> Ym Y:call WBCompileObject() <C-M>
		nmap <buffer> Yi Y:call ListInvalidObjects() <C-M>
		nmap <buffer> +  zo
		nmap <buffer> -  zc
	endif

	" go back to original window
 	execute bufwinnr(currentBuffer) . 'wincmd w'
	
	" Description window actions
	if (s:descbuffer <=  0) || (bufexists(s:descbuffer) <= 0)
		call WBInitDescriptionWindow()
	else
		" check, if the window with the description buffer is open
		if bufwinnr(s:descbuffer) <= 0 
			call WBInitDescriptionWindow()
		endif
	endif

	
	" go back to original window
 	execute bufwinnr(currentBuffer) . 'wincmd w'
	
	" check if we need to show a new SQL worksheet
	if (s:wsbuffer <= 0) || (bufexists(s:wsbuffer) <= 0)
		" show  the SQL worksheet
		call WBInitWorksheet()
	endif
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Change the database connection
"
" Do the following:
"
" 1. Call WBChangeConnection2 with the s:user value as parameter
"
function WBChangeConnection(...)
	" Build the parameter part of the command line
	let l:params = ""
	" Check, if we have got parameters
	if a:0 > 0
		for x in a:000
			let l:params=l:params . " " . x
		endfor
		call ChangeConnection2(l:params)
		
		" Re-load the tree if the tree is visible
		if bufexists(s:treebuffer) > 0
			" the TREE buffer exist. Check, if the buffer is displayed in
			" a window
			if bufwinnr(s:treebuffer) <= 0
				" the buffer is not visible. - do nothing
			else
				" the buffer is visible. Focus it
				silent execute bufwinnr(s:treebuffer) . 'wincmd w'
				call WBLoad()
			endif
		endif
	else	
		call WBChangeConnection2(s:user,"SCHEMA")
	endif	
	

	redraw!
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Change the database connection
"
" Parameter:
" NewUser : new default username for the connect dialog
" ObjType : not user
"
" Do the following:
"
" 1. Remove the content of the TREE window
" 2. Call ChangeConnection to new connection information from the user
" 3. Re-load the content of the TREE window
"
function WBChangeConnection2(NewUser,ObjType)
	" remember the current buffer
	let currentBuffer=bufnr("%")
	
	" goto the TREE	
	if s:treebuffer > 0
		" tree is loaded. Check the window
		if bufwinnr(s:treebuffer) >  0
			" remove the content from the tree
			silent execute bufwinnr(s:treebuffer) . 'wincmd w'
			silent execute '1,$d'
		else
			" delete the tree buffer
			execute 'bd!' . s:treebuffer
		endif
	endif	

	" get and store new connection information
	call ChangeConnection(a:NewUser)

	setlocal omnifunc=OmniComplet

	" Restore the tree if 
	" the TREE buffer exist. Check, if the buffer is displayed in
	" a window
	if bufwinnr(s:treebuffer) > 0
		" the buffer is visible. Focus it
		silent execute bufwinnr(s:treebuffer) . 'wincmd w'
		call WBLoad()

		" show the statusline with USER@HOST
		call SetupStatusLine("[Yd][Ym][Yo][Yu]")
	endif

endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Create the buffer with the SQL worksheet
"
" Do the following
"
" 1. Generate the filename of the worksheet
" 2. Check if the [No Name] buffer exists
" 2.1 if it exists, load the (empty) SQL worksheet into the buffer
" 2.2 if not, create a new buffer for the SQL worksheet
"
function! WBInitWorksheet()
	
	" check if the first buffer is the [No Name] buffer
	if (bufwinnr(1) > 0) && (strlen(bufname(1))==0) 	
		" use the initial No Name buffer
		execute "b 1"
	else
		" Create a new window with a new buffer.
		" Goto the upper right corner
		4wincmd k
		4wincmd l 
		setlocal splitbelow
		setlocal splitright
		15new
	endif

	" Remember the buffer number
	let s:wsbuffer = bufnr("%")
	
	" Cleanup  the buffer
	execute "1,$d"

	call append("0","set timing ON")
	call append("0","--alter session set timed_statistics=true;")
	call append("0","--set autotrace on explain STATISTICS")
	call append("0","set linesize 1024")
	call append("0","set serveroutput on size 1000000")
	call append("0","-- Enter SqlPlus commands here. Press [Ym] to execute.")

	" Setup buffer options
	setlocal buftype=nowrite
	setlocal bufhidden=hide
	setlocal noswapfile
	setlocal filetype=sql
	setlocal noautochdir
	setlocal ignorecase
	
	" show the statusline with USER@HOST
	call SetupStatusLine("[Yd][Ym]")

	
	" add commands
	call WBKeyMappingGeneral()
	
	" If the user saves the worksheet, remove the nowrite buffer type
	:au BufWritePost <buffer> set buftype=""
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Create a window to display object descriptions
function WBInitDescriptionWindow()
	" split for the DESCRIPTION part in  the lower right corner
	4wincmd j
	4wincmd l
	
	belowright 10new
	let s:descbuffer=bufnr('%')
	set nowrap
	set foldenable
	set foldmethod=manual
	set winfixheight
	setlocal filetype=sql
	setlocal buftype=nowrite
	setlocal bufhidden=hide
	setlocal noswapfile
	setlocal noautochdir
	
	" show the statusline with USER@HOST
	call SetupStatusLine("[Yd]")
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Load the the content of the given type 
" 
function! WBLoadObjectType()
	
	" create the SQL statement to select objects of given type
	normal GG
	let lineWithTypeName=get(getpos("."),1)
	normal GGo
	call append("$","SET PAGESIZE 0")
	call append("$","SET LINESIZE 1024")
	call append("$","SET FEEDBACK 0")
	call append("$","SET ECHO OFF")
	" call append("$","COLUMN OBJECT_NAME FORMAT A80")
	call append("$","COLUMN DDNAME FORMAT A80")
	call append("$","COLUMN OBJECT_TYPE FORMAT A32")
	call append("$","SET RECSEPCHAR |")

	" load tables
	call append("$","PROMPT   [TABLE]")
	call append("$","select DDNAME,DDTYPE from(")
	call append("$","-- Table names")
	call append("$","select ")
	call append("$","   concat('    ',p.OBJECT_NAME) DDNAME")
	call append("$","  ,p.OBJECT_NAME DDTABLE")
	call append("$","  ,'[TABLE]'  DDTYPE")
	call append("$","  ,10 DDLEVEL ")
	call append("$","from user_objects p ")
	call append("$","where p.OBJECT_TYPE = 'TABLE'")
	call append("$","and not p.OBJECT_NAME like 'BIN$%'")
	call append("$","union all")

	call append("$","-- Indexes")
	call append("$","select '        [INDEX]' DDNAME, TABLE_NAME DDTABLE, 'DUMMY' DDTYPE, 20 DDLEVEL from USER_INDEXES group by TABLE_NAME")
	call append("$","union all")
	call append("$","select ")
	call append("$","   CONCAT('        ',i.INDEX_NAME) DDNAME")
	call append("$","  ,i.TABLE_NAME DDTABLE")
	call append("$","  ,CONCAT('[INDEX][',CONCAT(i.TABLE_NAME,']')) DDTYPE")
	call append("$","  ,21 DDLEVEL ")
	call append("$","from USER_INDEXES i")
	call append("$","union all")

	call append("$","select '        [CONSTRAINT]' DDNAME ,c.TABLE_NAME DDTABLE ,'DUMMY' DDTYPE ,30 DDLEVEL ")
	call append("$","from ")
	call append("$","USER_CONSTRAINTS c , USER_TABLES t")
	call append("$","where t.TABLE_NAME = c.TABLE_NAME")
	call append("$","group by c.TABLE_NAME")
	call append("$","union all")
	call append("$","select ")
	call append("$"," CONCAT('        ',c.CONSTRAINT_NAME) DDNAME")
	call append("$",",c.TABLE_NAME DDTABLE")
	call append("$",",CONCAT('[CONSTRAINT][',CONCAT(c.TABLE_NAME,']')) DDTYPE")
	call append("$",",31 DDLEVEL ")
	call append("$","from USER_CONSTRAINTS c, USER_TABLES t")
	call append("$","where c.TABLE_NAME=t.TABLE_NAME")
	call append("$","union all")

	call append("$","-- Trigger")
	call append("$","select '        [TRIGGER]' DDNAME, TABLE_NAME DDTABLE, 'DUMMY' DDTYPE, 40 DDLEVEL from USER_INDEXES group by TABLE_NAME")
	call append("$","union all")
	call append("$","select ")
	call append("$","   CONCAT('        ', t.TRIGGER_NAME) DDNAME ")
	call append("$","  ,t.TABLE_NAME DDTABLE")
	call append("$","  ,CONCAT('[TRIGGER][',CONCAT(t.TABLE_NAME, ']')) DDTYPE")
	call append("$","  ,41 DDLEVEL")
	call append("$","  from USER_TRIGGERS t")
	call append("$",")")
	call append("$","order by DDTABLE, DDLEVEL;")
	call append("$","SELECT concat('    ','------') from dual;")

	" load all types
	let objlist = [ "VIEW","SEQUENCE","QUEUE","FUNCTION","PROCEDURE","PACKAGE","PACKAGE BODY","SYNONYM","TYPE", "TYPE BODY","DATABASE LINK"]
	for item in objlist
		call append("$","PROMPT [".item."]")
		call append("$","SELECT concat('    ',concat(decode(STATUS,'VALID','','(!)'),OBJECT_NAME)) DDNAME")
		call append("$",",concat(concat('[',OBJECT_TYPE),']') ")
		call append("$","from USER_OBJECTS ")
		call append("$","WHERE OBJECT_TYPE=UPPER('".item."')")
		call append("$","AND NOT OBJECT_NAME like 'BIN$%'")
		call append("$","order by OBJECT_NAME;")
		call append("$","SELECT concat('    ','------') from dual;")
	endfor
	
	" USER JOBS
	call append("$","PROMPT [JOBS]")
	call append("$"," SELECT concat('    ',concat(DECODE(BROKEN,'N','','(!)'),TO_CHAR(JOB))) DDNAME,concat(concat('[','JOB'),']') from user_jobs order by  job;")
	call append("$","SELECT concat('    ','------') from dual;")
	
	" add users
	call append("$","PROMPT [USERS]")
	call append("$","SELECT concat('    ',USERNAME) DDNAME,concat(concat('[','SCHEMA'),']') from ALL_USERS order by USERNAME;")
	call append("$","SELECT concat('    ','------') from dual;")
	
	" add all system packages
	call append("$","PROMPT [SYS Packages]")
	call append("$","SELECT concat('    ',concat(decode(STATUS,'VALID','','(!)'),OBJECT_NAME)) DDNAME,concat(concat('[',OBJECT_TYPE),']') from ALL_OBJECTS WHERE OBJECT_TYPE=UPPER('PACKAGE') and owner='SYS' order by OBJECT_NAME;")
	call append("$","SELECT concat('    ','------') from dual;")

	" spool keywords to the keywords file
	call append("$","PROMPT ###KEYWORS###")
	call append ("$","select distinct NAME from ( select synonym_name NAME  from all_synonyms union all select object_name NAME from user_objects) order by NAME;")

endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Create a temp buffer using the given object name
" 
function! CreateTmpBuffer(ObjectName)
	let tmpfile = CreateTmpFilename(a:ObjectName)
	silent execute 'new ' . l:tmpfile
	1,$delete	" empty the buffer
	return bufnr("%")
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Create a temp file using the given object name
" 
function! CreateTmpFile(ObjectName)
	let tmpfile = CreateTmpFilename(a:ObjectName)
	silent execute 'edit ' . tmpfile
	1,$delete	" empty the buffer
	return bufnr(tmpfile)
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Create a temp filename
" [in] Object name
" [out] a file for the given object name
"
function! CreateTmpFilename(ObjectName)
	let tmpbase='/tmp'
	if strlen($TEMP)>=1
		let tmpbase=$TEMP
	endif
	let tmpfile = l:tmpbase .  '/' . s:server . '_' . s:user . '_' . a:ObjectName
  	return tmpfile
endfunction
	
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Create a temp filename. Use a index number
" [in] Object name
" [out] a file for the given object name
"
function! CreateTmpFilename2(ObjectName)
	let tmpbase='/tmp'
	if strlen($TEMP)>=1
		let tmpbase=$TEMP
	endif
	let tmpfile = l:tmpbase .  '/' . s:server . '_' . s:user . '_' . s:filenumber . '_'  . a:ObjectName
	let s:filenumber = s:filenumber+1
  	return tmpfile
endfunction

function! CheckModified ()
	"check the file is modified
	if &modified
		let l:choice = confirm ("Do you want to save changes before continuing?", "&Yes\n&No\n&Cancel", 1, "Question")
		if l:choice == 1
			write
		elseif l:choice == 2
			"nothing to do
		else
			return -1
		endif
	endif
endfunction


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" CheckConnection
"
" Check, if all the parameters that we need to connect to the database
" have been defined.
"
" We are checking for:
" s:user
" s:password
" s:server
" 
" If one of this is missing, we prompt the user for it.
" 
function! CheckConnection ()
	" Check to ensure the connection details are defined in the global
	" variables
	if exists ("s:user") == 0 || exists ("s:password") == 0 || exists ("s:server") == 0 || s:user == "" || s:password == "" || s:server == ""
		if ChangeConnection (s:user) != 0
			return -1
		endif
	endif
	" if the variables are still not set return error
	if exists ("s:user") == 0 || exists ("s:password") == 0 || exists ("s:server") == 0 || s:user == "" || s:password == "" || s:server == ""
		echohl ErrorMsg
		echo "Invalid connection information"
		echohl None
		return -1
	else
		return 0
	endif
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Create the connection string for SqlPlus from the script variable:
" s:user
" s:password
" s:server
" s:sysdba
"
" Parameter: -
" return: name/passoword@server [AS SYSDBA]
"
function! BuildConnectString(user,password,server,sysdba)
	let l:connect_string = a:user . '/' . a:password . '@' .  a:server

	" check for sysdba mode
	if a:sysdba == "Y"
		let l:connect_string = l:connect_string . " AS SYSDBA"
	endif
	let s:connect_string=l:connect_string 
	let g:orawb_connect_status=a:user.'@'.a:server

	" remember that we will need to reload  the tree
	let s:tree_reload=1
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Change the database connection
"
" Parameter: new user name
"
function! ChangeConnection(NewUser)
	let s:user = a:NewUser
	" Prompt user for all the connection information to Oracle
	exec 'let l:user = input ("Enter userid [' . s:user . ']: ")'
	exec 'let l:password = inputsecret ("Enter Password [' . substitute (s:password, '.', '*', 'g') . ']: ")'
	exec 'let l:server = input ("Enter Server [' . s:server . ']: ")'
	exec 'let l:sysdba = input ("as SYSDBA (Y/N/Q) [' . s:sysdba . ']: ")'
	
	" check for QUIT
	if toupper(l:sysdba) == "Q" 
		return -1
	endif
	if l:user != ""
		let s:user = l:user
	endif
	if l:password != ""
		let s:password = l:password
	endif
	if l:server != ""
		let s:server = l:server
	endif
	if l:sysdba != ""
		let s:sysdba = toupper(l:sysdba)
	endif

	" setup s:connect_string and g:orawb_connect_status
	call BuildConnectString(s:user,s:password,s:server,s:sysdba)

	" setup the autocommands for all buffer
	call LoadAutoCommands()

	return 0
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Change the database connection
"
" Parameter: SQLPLUS connect string - Examples
"
" kalle/kalle@mydatabase
" kalle@mydatabase
" kalle/kalle
" kalle
" kalle as SYSDBA
"
"
" The function does this:
"
" Reset the username, the password and the connect options
" s:user, s:password, s:sysdba
"
" Try to  get the following information from the connect string
" 	- username
" 	- password
" 	- server
" 	- sysdba
" ...and  store the information in: s:user, s:password, s:sysdba, s:server
"
" Check, if one of the following pieces of information is missing:
" 	- username
" 	- password
" 	- server
" If so, prompt the user for this information and store it.
"
" Build a new s:connect_string
"
function! ChangeConnection2(SqlPlusConnectString)
	let s:user=''
	let s:password=''
	let s:sysdba=''

	let l:loginAs=''
	let l:constr=a:SqlPlusConnectString

	" remove leading blanks
	let l:blanks=matchstr(l:constr,"^\[ ]\\+")
	let l:constr=strpart(l:constr,strlen(l:blanks))

	" get the user name
	let s:user=matchstr(l:constr,"^\[^ /@]\\+")
	" remove the user-name from the connect string
 	let l:constr=strpart(l:constr,strlen(s:user))	
	
	" now the connection string look like this:
	" /mypassword			or
	" /mypassword AS Sysdba		or
	" /mypassword@mydb		or
	" /mypassword@mydb AS Sysdba	or
	" @mydb  			or
	" @mydb AS Sysdba		or
	"  AS Sysdba
	"
	" Check the first character to see which case we dealing with..
	if l:constr[0] == "/"
		" get the password
		let l:constr=strpart(l:constr,1)
		let s:password=matchstr(l:constr,"^\[^ @]\\+")
		let l:constr=strpart(l:constr,strlen(s:password))
	endif
	
	" now the connection string look like this:
	" @mydb  			or
	" @mydb AS Sysdba		or
	"  AS Sysdba
	"
	" Check the first character to see which case we dealing with..
	if l:constr[0]=="@"
		" get the database name
		let l:constr=strpart(l:constr,1)
		let s:server=matchstr(l:constr,"^\[^ ]\\+")
		let l:constr=strpart(l:constr,strlen(s:server))
	endif

	" now the connection string look like this:
	"  AS Sysdba
	"
	" Check the first character to see which case we dealing with..
	if l:constr[0] == ' '
		" get the password
		let l:constr=strpart(l:constr,1)
		let l:loginAs=toupper(matchstr(l:constr,"^\[^ ]\\+"))
		if l:loginAs=="SYSDBA"
			let s:sysdba=true
		endif	
	endif

	" check for missing parameter:
	" -password
	" -server
	if s:password==""
		exec 'let s:password = inputsecret ("Enter Password [' . substitute (s:password, '.', '*', 'g') . ']: ")'
	endif
	if s:server==""
		exec 'let s:server = input ("Enter Server [' . s:server . ']: ")'
	endif	

	" setup s:connect_string and g:orawb_connect_status
	call BuildConnectString(s:user,s:password,s:server,s:sysdba)
	 
	" setup the autocommands for all buffer
	call LoadAutoCommands()

endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Setup the status ling for the current buffer
"
" Parameters:
" a:normalModeKeys	String with normal mode keys
"
function! SetupStatusLine(NormalModeKeys)
	" show the statusline with USER@HOST
	execute "setlocal  statusline=%{g:orawb_connect_status}:"  . a:NormalModeKeys
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Switch to the description buffer
" The function returns the buffer number of the previously active buffer
function! SwitchToDesc()
	" remember the number of the current activ buffer
	let currentBuffer=bufnr("%")
	if (s:descbuffer <=  0) ||(bufexists(s:descbuffer) <= 0)
		call WBInitDescriptionWindow()
	endif
	" check, if the window with the description buffer is open
	if bufwinnr(s:descbuffer) <= 0 
		call WBInitDescriptionWindow()
	endif
	" goto the window that contains the buffer that contains the
	" description
 	execute bufwinnr(s:descbuffer) . 'wincmd w'
	" revmove current content
	:1,$d
	return currentBuffer
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Describe the object under the cursor in  the tree window
"
" The function calls SQLPLUS>desc
"
function! WBDescribeObject ()
	" Get information about the object
	let ObjInfo=WBGetObjectInfoFromTree()

	" Fill the parameter list.
	" P1 = object name
	" P2 = object type
	let parameters=[ObjInfo.name,ObjInfo.type]

	" Fill the directory of functions
	let fktdir={}
	let fktdir["SYNONYM"]=function("DisplaySynonym")
	let fktdir["QUEUE"]=function("DisplayQueue")
	let fktdir["JOB"]=function("DisplayJob")
	let fktdir["TRIGGER"]=function("DisplayTrigger")
	let fktdir["SEQUENCE"]=function("DisplaySequence")
	let fktdir["INDEX"]=function("DisplayIndex")
	let fktdir["CONSTRAINT"]=function("DisplayConstraint")

	" check if a function exits
	if has_key(fktdir,ObjInfo.type)
		" get the function that opens the object
		let Openfkt=fktdir[ObjInfo.type]
	
		" echo string(Openfkt)	
 		let r=call(Openfkt,parameters)	
	else
		" default: let SQLPLUS describe the object
		call DescribeNamedObject(ObjInfo.name,ObjInfo.type)
	endif

endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Describe the object under the cursor
"
" The function calls SQLPLUS>desc
"
function! DescribeObject()
	" get the name of the object that we are describing
	let l:object = expand("<cword>")
	
	call DescribeNamedObject(l:object,"")
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Describe the given object
"
" Parameter: 	[in] Object Name
" 		[in] Object Type (optional)
"
" The function calls SQLPLUS>desc
"
function! DescribeNamedObject(ObjectName,ObjectType)
	if CheckConnection () != 0
		return
	endif

	" remember the number of the current activ buffer
	let currentBuffer=SwitchToDesc()
	
	" create the SQL statements for describe and execute
	call append (0, "prompt " . a:ObjectName)
	call append (1, "desc " . a:ObjectName)
	1,$call SqlPlus()

	"delete the SQL> prompts
	" normal dW+df 
	setlocal ts=8 nomodified

	" go back to original window
 	execute bufwinnr(currentBuffer) . 'wincmd w'
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Complet a table.column name element using the
" omni-complet-function of VIM
"
" The function is doing this:
"
"
function! OmniComplet(findstart,base)
	echo "Enter OmniComplet"
	let l:result=CompletTable(a:findstart,a:base)

	if !empty(l:result)
		return l:result
	endif

	let l:result=CompletFunction(a:findstart,a:base)	
	return l:result
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Complet a package.function name element using the
" omni-complet-function of VIM
"
function! CompletFunction(findstart,base)
	echo "-->CompletFunction"
	" read the current cursor position
	let l:currentline=line('.')
	let l:currentcol=col('.')

	"   v_somename := dbms_output.
	" find somthing that looks like t. or tt. 
	let l:shortcutpattern="\\s\[a-zA-Z0-9$_\]\\+\\."
	let l:pos_start=searchpos(l:shortcutpattern,"bcWn")
	let l:pos_end=searchpos(l:shortcutpattern,"ebcWn")
	echo pos_start
	echo pos_end

	if l:currentline != get(l:pos_start,0)
		return []
	endif

	if a:findstart==1
		return get(l:pos_end,1)
	endif

	" found in current line. Now extract the name of the package
	let l:line = getline(".")
	let l:package_name = strpart(l:line,get(l:pos_start,1),get(l:pos_end,1)-get(l:pos_start,1)-1)
	echo l:package_name	

	" get the function and procedure names
	let l:package_functions=GetPackageFunctions(l:package_name)
        
	" add all function names which match with the base-string to the
	" result
	let l:result = []
	let l:basePattern = toupper(a:base) . ".*"
	for currentfunction in l:package_functions 
		if toupper(currentfunction) =~ l:basePattern 
			call add(l:result,currentfunction)
		endif	
	endfor	

	return l:result
endfunction	

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Complet a table.column name element using the
" omni-complet-function of VIM
"
function! CompletTable(findstart,base)
	" read the current cursor position
	let l:currentline=line('.')
	let l:currentcol=col('.')

	" find somthing that looks like t. or tt. 
	let l:shortcutpattern="\[a-zA-Z0-9$_\]\\+\\."
	let l:pos_start=searchpos(l:shortcutpattern,"bcWn")
	let l:pos_end=searchpos(l:shortcutpattern,"ebcWn")
	if l:currentline != get(l:pos_start,0)
		return []
	endif

	if a:findstart==1
		return get(l:pos_end,1)
	endif

	" found in current line. Now extract the name of the table
	let l:line = getline(".")
	let l:table_shortcut = strpart(l:line,get(l:pos_start,1)-1,get(l:pos_end,1)-get(l:pos_start,1))

	" now find the name of the table: 
	" SELECT * FROM ergebnis t where t.
	" SELECT d.ID FROM
	"  treffer d 
	"  where d.ID=12;
	"
	" Find <somename><whitespace><table_shortcut>
	" Find forward and backward - take the one that closed to the cursor
	" position
	let l:pattern = "\[a-zA-Z0-9$_\]\\+\\s\\+" . l:table_shortcut . "\\(\\(\\s\\)\\|\\(,\\)\\|\\(;\\)\\|\\($\\)\\)"
	" call input(l:pattern)
	let tab_pos_before = searchpos(l:pattern,"bcWn")
	let tab_pos_after = searchpos(l:pattern,"cWn")
	if get(tab_pos_before,0)==0
		let tab_pos_begin = tab_pos_after
	else
		if get(tab_pos_after,0)==0
			let tab_pos_begin = tab_pos_before
		else
			let diff_before = l:currentline-get(tab_pos_before,0)
			let diff_after  = get(tab_pos_after,0)-l:currentline
			if diff_before>diff_after
				let tab_pos_begin = tab_pos_after
			else
				let tab_pos_begin = tab_pos_before
			endif
		endif
	endif	

	" call input(string(tab_pos_begin))

	" get the line that contains the name of the table
	let l:tablename_line = getline(get(tab_pos_begin,0))
	let l:tab_pos_end = matchend(l:tablename_line,"\\c\[A-Z0-9_$\]\\+",get(tab_pos_begin,1)-1)
        let l:tablename=strpart(l:tablename_line,get(tab_pos_begin,1)-1,tab_pos_end-get(tab_pos_begin,1)+1)
	" call input("tab_pos_end=" . string(tab_pos_end) . " tablename=" . l:tablename)	

	" get the columns of the table
	let l:columns=GetColumns(l:tablename)
        
	" put all matching column names into the result list
	let l:result = []
	let l:pattern = toupper(a:base) . ".*"
	for currentcol in l:columns
		if toupper(currentcol) =~ l:pattern
			call add(l:result,currentcol)
		endif	
	endfor	

	" add the base tag
	" let l:result = add(l:result,a:base)	
	call sort(l:result)
	return l:result
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Get a list of all columns of the table named a:TableName
"
" The function does the following:
" 1. create a temporary file
" 2. write the SQL commands to list the columns of the table to the file
" 3. execute the command and store the result in the string
" 4. parse the string an write the entries into a LIST
" 5. return the LIST
"
function! GetColumns(TableName)
	if CheckConnection () != 0
		return
	endif
	
	" remember th activ buffer 
	let l:cur_buf = bufnr("%")

	" build the SQL command to list the colunm names
	silent execute 'new '
	let l:sql_cmd = "select column_name from all_tab_columns where table_name = upper('" . a:TableName . "');"
	call append (0,"set pagesize 0") 
	call append (0,"set feedback off") 
	call append ("$",l:sql_cmd) 

	" execute the SQL command
	%call SqlPlus()

	" check for errors
	if s:sqlerr != 0 
		return []
	endif

	" get the content of the buffer as a list
	let l:lines=getline(1,'$')

	" remove empty lines
	let l:result = []
	for currentline in l:lines	
		if len(currentline) > 0 
			call add(l:result,currentline)
		endif	
	endfor	

	" delete the buffer
	silent execute 'bd!'

	return l:result
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Get a list of all functions or procedures within a package
"
" The function does the following:
" 1. create a temporary file
" 2. write the SQL commands to describe the package
" 3. execute the command and store the result in the string
" 4. parse the string an write the entries into a LIST
" 5. return the LIST
"
function! GetPackageFunctions(PackageName)
	if CheckConnection () != 0
		return
	endif
	
	" remember th activ buffer 
	let l:cur_buf = bufnr("%")

	" build the SQL command to list the colunm names
	silent execute 'new '
	let l:sql_cmd = "DESCRIBE " . a:PackageName
	call append (0,"set pagesize 0") 
	call append (0,"set feedback off") 
	call append (0,"SET linesize 80")
	call append (0,"SET DESCRIBE DEPTH 1")
	call append (0,"SET DESCRIBE INDENT ON")
	call append (0,"SET DESCRIBE LINE OFF")
	call append ("$",l:sql_cmd) 

	" execute the SQL command
	%call SqlPlus()

	" check for errors
	if s:sqlerr != 0 
		return []
	endif

	" remove all lines that do not describe a function or a procedure
	:silent! 1,$s/^ .\+$\n//g

	" remove the keywords FUNCTION and PROCEDURE
	:silent! 1,$s/^[A-Za-z0-9_$]\+\s/

	" get the content of the buffer as a list
	let l:functionlines = getline(1,'$')
	
	" delete the buffer
	silent execute 'bd!'

	" check for the text ERROR: in the first line
	if len(l:functionlines) > 0 
		if toupper(get(l:functionlines,0)) =~ "^ERROR:.*"
			return []
		endif	
	endif	


	" remove all empty lines
	let l:result = []
	for currentline in l:functionlines
		if len(currentline) > 0 
			call add(l:result,currentline)
		endif	
	endfor

	return l:result
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Get the source code of the given object name and object type
"
function! GetSourceForObject(ObjectName,ObjectType)
	if CheckConnection () != 0
		return
	endif

	" Get the source of the function/procedure under the cursor
	" let l:object = expand("<cword>")

	" goto the window in the upper let corner
	4wincmd k
	4wincmd l

	" call CreateTmpBuffer("source_".a:ObjectName.".sql")
	new
	call append (0, "Upper ('" . a:ObjectType . "') order by LINE;")
	call append (0, 'and type = ')
	call append (0, "Upper ('" . a:ObjectName . "') ")
	call append (0, 'select text from user_source where name = ')
	call append("0","SET FEEDBACK 0")
	call append (0, 'set linesize 32000')
	call append (0, 'set pagesize 0')

	%call SqlPlus()

	call append (0, "CREATE OR REPLACE ")
	1join

	call append ("$", "/")
	1
	setlocal nomodified
	setlocal filetype=sql
	
	" add commands
	call WBKeyMappingCompiler()
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Create the DDL code for a SYNONYM
"
function! CreateSourceForSynonym(ObjectName,ObjectType)
	if CheckConnection () != 0
		return
	endif

	" goto the window in the upper let corner
	4wincmd k
	4wincmd l

	new

let l:cmd=      "dbms_output.put_line('CREATE OR REPLACE SYNONYM "
let l:cmd=l:cmd.'"'
let l:cmd=l:cmd."'||v_synonym.SYNONYM_NAME||'"
let l:cmd=l:cmd.'" FOR "'
let l:cmd=l:cmd."'||v_synonym.TABLE_NAME||'"
let l:cmd=l:cmd.'";'
let l:cmd=l:cmd."');"

let l:cmd_owner=            "dbms_output.put_line('CREATE OR REPLACE SYNONYM "
let l:cmd_owner=l:cmd_owner.'"'
let l:cmd_owner=l:cmd_owner."'||v_synonym.SYNONYM_NAME||'"
let l:cmd_owner=l:cmd_owner.'" FOR "'
let l:cmd_owner=l:cmd_owner."'||v_synonym.TABLE_OWNER||'"
let l:cmd_owner=l:cmd_owner.'"."'
let l:cmd_owner=l:cmd_owner."'||v_synonym.TABLE_NAME||'"
let l:cmd_owner=l:cmd_owner.'";'
let l:cmd_owner=l:cmd_owner."');"


let l:cmdnet=      "dbms_output.put_line('CREATE OR REPLACE SYNONYM "
let l:cmdnet=l:cmdnet.'"'
let l:cmdnet=l:cmdnet."'||v_synonym.SYNONYM_NAME||'"
let l:cmdnet=l:cmdnet.'" FOR "'
let l:cmdnet=l:cmdnet."'||v_synonym.TABLE_NAME||'"
let l:cmdnet=l:cmdnet.'"@'
let l:cmdnet=l:cmdnet."'||v_synonym.DB_LINK||';');"

let l:cmdnet_owner=      "dbms_output.put_line('CREATE OR REPLACE SYNONYM "
let l:cmdnet_owner=l:cmdnet_owner.'"'
let l:cmdnet_owner=l:cmdnet_owner."'||v_synonym.SYNONYM_NAME||'"
let l:cmdnet_owner=l:cmdnet_owner.'" FOR "'
let l:cmdnet_owner=l:cmdnet_owner."'||v_synonym.TABLE_OWNER||'"
let l:cmdnet_owner=l:cmdnet_owner.'"."'
let l:cmdnet_owner=l:cmdnet_owner."'||v_synonym.TABLE_NAME||'"
let l:cmdnet_owner=l:cmdnet_owner.'"@'
let l:cmdnet_owner=l:cmdnet_owner."'||v_synonym.DB_LINK||';');"

call append("$","set serveroutput on size 1000000")
call append("$","set linesize 1024")
call append("$","declare")
call append("$","v_synonym USER_SYNONYMS%rowtype;")
call append("$","begin")
call append("$","select * into v_synonym from USER_SYNONYMS where SYNONYM_NAME = '".a:ObjectName."';")
call append("$","if v_synonym.DB_LINK is null then")
call append("$","if v_synonym.TABLE_OWNER is null then")
call append("$",l:cmd)
call append("$","else")
call append("$",l:cmd_owner)
call append("$","end if;")
call append("$","else")
call append("$","if v_synonym.TABLE_OWNER is null then")
call append("$",l:cmdnet)
call append("$","else")
call append("$",l:cmdnet_owner)
call append("$","end if;")
call append("$","end if;")
call append("$","end;")
call append("$","/")

	%call SqlPlus()
	1join
	2,$d

	setlocal nomodified
	setlocal filetype=sql
	
	" add commands
	call WBKeyMappingCompiler()
endfunction
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Display a SYNONYM 
"
" Do the following:
" 	- call DisplaySingleRecord for the table USER_SYNONYMS and  the 
" 	ObjectName as SELECT condition
" 
"
function! DisplaySynonym(ObjectName,ObjectType)
	call DisplaySingleRecord("Synonym " . a:ObjectName,"USER_SYNONYMS","SYNONYM_NAME='".a:ObjectName."'")
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Display a Contraint 
"
" Do the following:
"	- call DisplaySingleRecord to display the line
"	describing the queue with the name ObjectName from
"	the view USER_CONSTRAINTS
"
function! DisplayConstraint(ObjectName,ObjectType)
	" Open the description window
	let l:currentBuffer=SwitchToDesc()

	" insert the PL/SQL Block to display the columns
	call append("$","set feedback off")
	call append("$","set serveroutput on")
	call append("$","declare")
	call append("$","	v_result varchar2(4000);")
	call append("$","begin")
	call append("$","	for col in (select * from USER_CONS_COLUMNS where CONSTRAINT_NAME='".a:ObjectName."' ) loop")
	call append("$","		v_result := v_result || ','||col.TABLE_NAME||'.'||col.COLUMN_NAME;")
	call append("$","	end loop;")
	call append("$","	dbms_output.put_line('COLUMNS :'||SUBSTR (v_result,2));")
	call append("$","end;")
	call append("$","/")

	" PL/SQL Block to display the referenced columns
	call append("$","set feedback off")
	call append("$","set serveroutput on")
	call append("$","declare")
	call append("$","	v_result varchar2(4000);")
	call append("$","begin")
	call append("$","	for col in (select * from USER_CONS_COLUMNS c where c.CONSTRAINT_NAME=(")
	call append("$","		select cc.R_CONSTRAINT_NAME from USER_CONSTRAINTS cc where cc.CONSTRAINT_NAME='".a:ObjectName."'")
	call append("$","	)) loop")
	call append("$","		v_result := v_result || ','||col.TABLE_NAME||'.'||col.COLUMN_NAME;")
	call append("$","	end loop;")
	call append("$","	dbms_output.put_line('REFERENCED COLUMNS :'||SUBSTR (v_result,2));")
	call append("$","end;")
	call append("$","/")

	call DisplaySingleRecordInternal("Contraint " . a:ObjectName,"USER_CONSTRAINTS","CONSTRAINT_NAME='".a:ObjectName . "'")
	" go back to original window
 	execute bufwinnr(l:currentBuffer) . 'wincmd w'
	setlocal nomodified
endfunction
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Display a Index 
"
" Do the following:
"	- call DisplaySingleRecord to display the line
"	describing the queue with the name ObjectName from
"	the view USER_INDEXES
"
function! DisplayIndex(ObjectName,ObjectType)
	" Open the description window
	let l:currentBuffer=SwitchToDesc()

	" insert the PL/SQL Block to display the columns
	call append("$","set feedback off")
	call append("$","set serveroutput on")
	call append("$","declare")
	call append("$","	v_result varchar2(4000);")
	call append("$","begin")
	call append("$","	for col in (select * from USER_IND_COLUMNS where index_name='" . a:ObjectName . "' ) loop")
	call append("$","		v_result := v_result || ','||col.COLUMN_NAME;")
	call append("$","	end loop;")
	call append("$","	dbms_output.put_line('COLUMNS :'||SUBSTR (v_result,2));")
	call append("$","end;")
	call append("$","/")

	" Display the data
	call DisplaySingleRecordInternal("Index " . a:ObjectName,"USER_INDEXES","INDEX_NAME='".a:ObjectName . "'")

	" go back to original window
 	execute bufwinnr(l:currentBuffer) . 'wincmd w'
	setlocal nomodified
endfunction
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Display a Database Link 
"
" Do the following:
"	- call DisplaySingleRecord to display the line
"	describing the queue with the name ObjectName from
"	the view USER_DB_LINKS
"
function! DisplayDBLink(ObjectName,ObjectType)
	call DisplaySingleRecord("Database Link " . a:ObjectName,"USER_DB_LINKS","DB_LINK='".a:ObjectName . "'")
endfunction
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Display a Sequence 
"
" Do the following:
"	- call DisplaySingleRecord to display the line
"	describing the queue with the name ObjectName from
"	the view USER_SEQUENCES
"
function! DisplaySequence(ObjectName,ObjectType)
	call DisplaySingleRecord("Sequence " . a:ObjectName,"USER_SEQUENCES","SEQUENCE_NAME='".a:ObjectName . "'")
endfunction
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Display a Trigger 
"
" Do the following:
"	- call DisplaySingleRecord to display the line
"	describing the queue with the name ObjectName from
"	the view USER_TRIGGERS
"
function! DisplayTrigger(ObjectName,ObjectType)
	call DisplaySingleRecord("Trigger " . a:ObjectName,"USER_TRIGGERS","TRIGGER_NAME='".a:ObjectName . "'")
endfunction
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Display a Job 
"
" Do the following:
"	- call DisplaySingleRecord to display the line
"	describing the queue with the name ObjectName from
"	the view USER_JOBS
"
function! DisplayJob(ObjectName,ObjectType)
	call DisplaySingleRecord("Job " . a:ObjectName,"USER_JOBS","JOB=".a:ObjectName)
endfunction
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Display a Queue 
"
" Do the following:
"	- call DisplaySingleRecord to display the line
"	describing the queue with the name ObjectName from
"	the view USER_QUEUES
"
function! DisplayQueue(ObjectName,ObjectType)
	" Open the description window
	let l:currentBuffer=SwitchToDesc()


	call append("$","set feedback off")
	call append("$","set serveroutput on")
	call append("$","declare")
	call append("$","	v_queue_name  USER_QUEUES.NAME%type := '". a:ObjectName ."';")
	call append("$","	v_sql varchar2(4000):='SELECT DECODE (state ,0,''READY'' ,1,''WAITING'' ,2,''PROCESSED'' ,3,''EXPIRED'' ,''?'') STATE ,COUNT(state)-1 FROM (select STATE from == where Q_NAME = :1 union all select 0 STATE from dual union all select 1 STATE from dual union all select 2 STATE from dual union all select 3 STATE from dual) group by state order by state';")
	call append("$","	type t_state_cursor is REF CURSOR;")
	call append("$","	v_cur t_state_cursor; ")
	call append("$","	v_state varchar2(50);")
	call append("$","	v_count number;")
	call append("$","	v_queue_table USER_QUEUES.NAME%type;")
	call append("$","begin")
	call append("$","	-- read the name of the queue table")
	call append("$","	select QUEUE_TABLE into v_queue_table from USER_QUEUES where NAME=v_queue_name;")
	call append("$","	-- build the select")
	call append("$","	v_sql := regexp_replace(v_sql,'==',v_queue_table);")
	call append("$","       open v_cur for v_sql using v_queue_name;")
	call append("$","	loop")
	call append("$","		fetch v_cur into v_state,v_count;")
	call append("$","		exit when v_cur%NOTFOUND;")
	call append("$","		dbms_output.put_line('Entries in state ' || v_state || ' :' || TO_CHAR (v_count));")
	call append("$","	end loop;")
	call append("$","	close v_cur;	")
	call append("$","end;")
	call append("$","/")

	call DisplaySingleRecordInternal("Queue " . a:ObjectName,"USER_QUEUES","NAME='".a:ObjectName."'")
	" go back to original window
 	execute bufwinnr(l:currentBuffer) . 'wincmd w'
	setlocal nomodified
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Display a single record from a given table 
"
" Parameter
" 	Title		- a title  text line
" 	Tablename	- name of the table or view that contains the record
"	Condition	- WHERE condition to select the record from the table
"	or the view.
"
" Do the following:
" 1. open the description window
" 2. call DisplaySingleRecordInternal to display the data
" 3. return to the original window 
"
function! DisplaySingleRecord(Title,Tablename,Condition)
	" Open the description window
	let l:currentBuffer=SwitchToDesc()
	
	" Display the data
	call DisplaySingleRecordInternal(a:Title,a:Tablename,a:Condition)

	" go back to original window
 	execute bufwinnr(l:currentBuffer) . 'wincmd w'
	setlocal nomodified
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Display a single record from a given table 
"
" Parameter
" 	Title		- a title  text line
" 	Tablename	- name of the table or view that contains the record
"	Condition	- WHERE condition to select the record from the table
"	or the view.
"
" Do the following:
" 1. open the description window
" 2. get a list of all column names of the table
" 3. generate the SQLPLUS statemens to display each column in a single row
" 3. call SQLPLUS to execute the command
"
function! DisplaySingleRecordInternal(Title,Tablename,Condition)
	let l:firstRow = 0

	if CheckConnection () != 0
		return
	endif
	
	" get all column names as a list
	let currentBuffer=bufnr("%")
	let l:Columns=GetColumns(a:Tablename)
 	execute bufwinnr(l:currentBuffer) . 'wincmd w'

	call append("$","set pagesize 0")
	call append("$","set linesize 4000")
	" format for column description
	call append("$","col CCC_DESC0 FORMAT A30")
	call append("$","col CCC_DESC NEWL FORMAT A30")
	
	" insert the SELECT part of the SQL 
	call append("$","select")

	" loop all columns and insert the SQL to receive the data from the
	" table
	for l:CurrentColumn in l:Columns
		if l:firstRow == 0 
			call append("$","'" . l:CurrentColumn . " :' CCC_DESC0," . l:CurrentColumn)
			let l:firstRow = 1
		else
			call append("$",",'" . l:CurrentColumn . " :' CCC_DESC," . l:CurrentColumn)
		endif
	endfor
 
	" insert the from nnnnn part of the SQL
	call append("$","from " . a:Tablename )
	
	" insert the condition
	call append("$","where " . a:Condition . ";")
	
	" execute
	1,$call SqlPlus()
	
	" insert the title
	call append(0,a:Title)
	normal 1G
	normal yypVr=o
endfunction
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Select data from the object (object==view or table)
"
" The number of entries is limited to 25
"
function! SelectDataFromObject(ObjectName,ObjectType)
	if CheckConnection () != 0
		return
	endif
	
	" create the SELECT statement
	let SelectStm = "select * from " . a:ObjectName . " where rownum < 26;"

	" Open the description window
	call SwitchToDesc()

	call CreateTmpBuffer("source_".a:ObjectName.".sql")
	call append (0, SelectStm )
	call append("0","SET FEEDBACK 1")
	call append (0, 'set linesize 32000')
	call append (0, 'set pagesize 9999')

	1,$call SqlPlus()
	1
	call append (0, SelectStm )
	
	" add commands
	command!-buffer Ydescribe call DescribeObject()
	
	" add key mappings
	nmap <buffer> ys y:call WBShow()<C-M>
	nmap <buffer> yh y:call WBHide()<C-M>
	nmap <buffer> yc y:call WBChangeConnection() <C-M>
	nmap <buffer> yd y:call DescribeObject()<C-M>

	setlocal nomodified
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Load the VIM auto-commands for the workbench. We are using the following
" auto-commands:
"
" omnifunc	BufAdd,BufNew	Setup a function to compleat column names
"
" Parameter :	-
"
" Do the following:
" 1. check, if the variable s:autocmd_loaded is set to 1. if so, exit the
" function
" 2. set the variable s:autocmd_loaded to 1
" 3. setup omnifunc for the event BufAdd
" 4. setup omnifunc for the event BufNew
"
function! LoadAutoCommands() 
	if s:autocmd_loaded != 1
		let s:autocmd_loaded = 1
		" autocmd BufEnter * echo "Kalle"
		autocmd BufEnter * setlocal omnifunc=OmniComplet
	endif	
endfunction

function! SqlPlus (...) range
" this function lets you 
" 	- start SQL*Plus
" 	- execute the contents of the current buffer and show the results back in
" 	the same buffer
" 	- execute the selected lines from the current buffer and show results in a
" 	new buffer

	if CheckConnection () != 0
		return -1
	endif

	"echo a:0
	if a:0 > 0 
		if a:1 == "@"
			" run the 2nd parameter as a file

			"check the file is modified
			if CheckModified () == -1
				return -1
			endif
			silent execute '!' . s:sqlcmd . ' ' . s:connect_string . ' @' . a:2
		else
			" just start SQL*Plus
			silent execute '!start ' . s:sqlcmd . s:connect_string
		endif
	else
		" Execute the range and display the result in buffer
		" echo a:firstline "," a:lastline
		silent execute a:firstline ',' a:lastline '!' . s:sqlcmd . '-S ' . s:connect_string
	endif
	" save SQL error message
	let s:sqlerr =  v:shell_error
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" List all invalid objects in the current schema
"
function! ListInvalidObjects ()
	if CheckConnection () != 0
		return
	endif
	" remember the number of the current activ buffer
	let currentBuffer=SwitchToDesc()
	
	echo "List Invalid Objects"
	normal ggVGscolumn object_name format A32
	normal ocolumn object_type format A32
	normal oset PAGESIZE 0
	normal oselect object_type, object_name from user_objects where status = 'INVALID' order by object_name;
	1,4call SqlPlus()

	setlocal ts=8 nomodified
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Remove all marks from the current buffer
"
function! RemoveAllMarks(buffername)
	let l:sign_count = 1000
 	while l:sign_count < 1100	
		silent execute 'sign unplace ' . l:sign_count . ' buffer=' . bufnr(a:buffername)
		let l:sign_count = l:sign_count + 1 
	endwhile
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Compile a piece of PL/SQL code.
"
" This function can compile:
" 	trigger
" 	type + type body
"	package + package body
"	function
"	procedure
"	view
"	dimension
"	java classes
"
" Assumes that the stored procedure code starts with "^create or replace..."
" at the beginning of the line
"
" Change the following settings (done in sql.vim ftplugin):
" To use multiline error format of SQL*Plus
function! SqlMake ()
	"set efm=%E%l/%c%m,%C%m,%Z

	if CheckConnection () != 0
		return
	endif
	"	close the error window, in case its open
	cclose
	redraw

	" we are getting into trouble is vim is in acd mode
	if exists("&acd")
		let org_acd=&acd
		let &acd=0
	endif

	"	File Names used in this function
	let l:cur_buf = bufnr("%")
	let l:ef_save	= &errorfile
	let &errorfile = CreateTmpFilename("sqlmake.err")
	let l:sqlfile = CreateTmpFilename("sqltmp.sql")

	" delete the old errorfile
	if filereadable (&errorfile)
		call delete (&errorfile)
	endif

	" remove existing signs
	call RemoveAllMarks('%')

	"Copy the source file to a temporary SQL file and added SQL commands to
	"show the error messages and to exit SQL*Plus after compilation is
	"finished
	""exec 'silent write! ' . l:sqlfile
	"" exec 'w!'
	"" exec 'silent edit! ' . l:sqlfile
	exec '1,$y q'
	exec 'new ' . l:sqlfile
	exec '1,$d'
	normal "qP
	let l:tmp_buf = buffer_number("%")

	" get the type of the object from the SQL text
	let sqlType=""
	let sqlName=""
	let &ignorecase=1
	normal 1G
	let pbegin='CREATE[ \t\n]\+OR[ \t\n]\+REPLACE[ \t\n]\+'
	if search(pbegin.'PACKAGE[ \t\n]BODY[ \t\n]\+','e') >= 1
		let sqlType = "package body"
	elseif search(pbegin.'PACKAGE[ \t\n]\+','e') >= 1
		let sqlType = "package"
	elseif search(pbegin.'FUNCTION[ \t\n]\+','e') >= 1
		let sqlType = "function"
	elseif search(pbegin.'PROCEDURE[ \t\n]\+','e') >= 1
		let sqlType = "procedure"
	elseif search(pbegin.'TRIGGER[ \t\n]\+','e') >= 1
		let sqlType = "trigger"
	elseif search(pbegin.'VIEW[ \t\n]\+','e') >= 1
		let sqlType = "view"
	elseif search(pbegin.'TYPE BODY[ \t\n]\+','e') >= 1
		let sqlType = "type body"
	elseif search(pbegin.'TYPE[ \t\n]\+','e') >= 1
		let sqlType = "type"
	elseif search(pbegin.'DIMENSION[ \t\n]\+','e') >= 1
		let sqlType = "dimension"
	elseif search(pbegin.'JAVA CLASS[ \t\n]\+','e') >= 1
		let sqlType = "java class"
	endif
	
	" move to the next word. It contains the name of the object
	let nameStartCol=get(getpos("."),2)
	if search('\(".\+"\)\|\([A-Z,_,a-z,0-9]\+\)','e') >=1 
		let nameEndCol=get(getpos("."),2) 
		let nameLine=getline(get(getpos("."),1))
	        let sqlName=strpart(nameLine,nameStartCol,nameEndCol-nameStartCol)
		" remove apostrove surounding the name
		if stridx(sqlName,'"')>=0
			let sqlName=strpart(sqlName,1,strlen(sqlName)-2)
		endif
	else
		echo "Object not found" . string(getpos("."))
		echo search('\(".\+"\)\|\([A-Z,_,a-z,0-9]\+\)/e','ce') 
		return 
	endif	
	
	" add show error at the end of SQL file
	call append ("$", "set pagesize 0")
	call append ("$", "show error " . sqlType . " " . sqlName)

	" add EXIT at the end of SQL file
	call append ("$", "EXIT")
	silent write

	" compile the l:sqlfile in SQL*Plus
	let l:command = s:sqlcmd . " -S -L " . s:connect_string . " @" .  l:sqlfile
	"" echohl MoreMsg
	echo "Compiling..."
	"" echohl None
	let l:sqlout = system (l:command)
	
	"TODO check for v:shell_error

	let l:error_exists = FormatErrorMessage (l:sqlout)

	" go to the original alternate buffer
	execute 'silent buffer ' . l:cur_buf

	" delete the temporary SQL file and buffer
	exec 'silent bwipeout! ' . l:tmp_buf
	close
	"++KL++	silent call delete ( l:sqlfile )
	

	" if vih has +signs then use signs else put special character ("--ERR--")
	" for highlighting on the error lines if this is used an autocmd event for
	" BufWritePre will remove all these error marks/signs
	if l:error_exists != 0 && exists ("s:do_highlight_errors") && s:do_highlight_errors == 1
		" save the modified status
		let l:mod_flag = &modified
		let l:error_lines = s:sqlErrLines " this variable is set in FormatErrorMessage() function
		" if its a vim with +sings then use signs else use --ERR-- to
		" mark and highlight error lines
		if has ("signs")
			let l:sign_count = 1000
			while strlen (l:error_lines) > 1
				let l:line_num = matchstr (l:error_lines, '[0-9]\+')
				if l:line_num != ""
					let l:sign_count = l:sign_count + 1
					execute 'sign place ' . l:sign_count . ' line=' . l:line_num . ' name=SQLMakeError buffer=' . l:cur_buf
				endif
				let l:error_lines = strpart (l:error_lines, strlen (l:line_num) + 1, 99999999)
			endwhile
		endif
		let &modified = l:mod_flag
	endif

	" load the errors, if any
	cfile
	if l:error_exists != 0
		copen
		norm 
	else
		""echohl MoreMsg
		""echo "No Errors"
		""echohl None
	endif
	let &errorfile = l:ef_save
	norm 

	if exists("&acd")
		" restore acd mode
		let &acd=org_acd	
	endif	
	redraw
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Format the error messages that SQLPLUS has send to the output stream.
"
" At least 2 different formats of messages are used:
"
" 1. When compiling PL/SQL Programs
" ......................................
" Line/Column	Message
"
" Example:
"  5/1     PLS-00103: Encountered the symbol PROCEDURE when expecting one
"          of the following:
" 
" 2. When compiling object types
" .....................................
"
" ORA-NNNNN: line NNN, column NNN: 
" Message
"
" Example:
" ORA-06550: line 6, column 1:
" PLS-00103: Encountered the symbol SSSSS when expecting one of the following:
" . ) , @ % is authid as cluster order using external character
" 
"
function! FormatErrorMessage (sqloutput)
	" Define the patter that matches the two types of error message
	let l:ErrorPattern = '\(ORA-[0-9]\{5,5}:\s\+line\s\+[0-9]\+,\s\+column\s\+[0-9]\+\)\|\([0-9]\+\/[0-9]\+\t\)'
	let l:LineNumberPattern = '\([0-9]\+\/\)\|\(line\s\+[0-9]\+\)'
	
	" Map error line numbers to correct line number in the file, as SQL*Plus
	" removes all blank lines from compiled code and lines numbers are changed
	" accordingly
	
	let l:errmsgs = a:sqloutput

	" remove the headings
	" where there are errors
	let l:match_pos = match (l:errmsgs,l:ErrorPattern)
	let l:errmsgs = strpart (l:errmsgs, l:match_pos, 99999999) 
	"echo 'l:errmsgs : ' strlen (l:errmsgs)

	" where there are no errors
"+kl+	let l:match_pos = matchend (l:errmsgs,'No errors\.')
"+kl+	let l:errmsgs = strpart (l:errmsgs, l:match_pos, 99999999) 
"	echo 'l:errmsgs : ' strlen (l:errmsgs)

	" remove the footers
"	let l:match_pos = match (l:errmsgs, 'Disconnected from Oracle')
"	let l:errmsgs = strpart (l:errmsgs, 0, l:match_pos - 1) 
"	echo 'l:errmsgs : ' strlen (l:errmsgs)
"	echo 'l:errmsgs : ' l:errmsgs
"let g:sqloutorg = l:errmsgs


	if ( strlen ( l:errmsgs ) <= 0)
		" create empty error file
		exec 'redir > ' . &errorfile
		redir end

"		echohl ErrorMsg
"		echo 'No Errors.'
"		echohl None
		return 0
	else
		" find the first line of code (starting with "create or replace")
		let l:total_lines = line("$")
		let l:current_line = 1
		while (l:current_line <= l:total_lines)
			let l:line = getline (l:current_line)
			if (l:line =~? '^create\s\+or\s\+replace')
				break
			else
				let l:current_line = l:current_line + 1
			endif
		endwhile
		let l:comments_count = l:current_line - 1

		" map the linenumbers
		let l:new_errmsg = ''
		let s:sqlErrLines = '' " use a script variable to return the formatted error message
		while strlen (l:errmsgs)
			" first get the line/col part of the current message
			let l:match_pos = matchend (l:errmsgs,l:ErrorPattern)
			let l:curr_msg = strpart (l:errmsgs, 0, l:match_pos)

			" now get the rest of message upto next line/col or the left out
			let l:errmsgs = strpart (l:errmsgs, l:match_pos + 1, 99999999)
			let l:match_pos = match (l:errmsgs,l:ErrorPattern)
			" echo 'l:match_pos : ' l:match_pos 
			if l:match_pos > 0
				let l:curr_msg = l:curr_msg . strpart (l:errmsgs, 0, l:match_pos)
				let l:errmsgs = strpart (l:errmsgs, l:match_pos, 99999999)
			else
				let l:curr_msg = l:curr_msg . l:errmsgs
				let l:errmsgs = ''
			endif
			" echo 'l:curr_msg : ' l:curr_msg 
			" call input("Press CR to continue...")

			" now get the correct line numbers
			let l:line_part_1 = matchstr (l:curr_msg,l:LineNumberPattern)
			let l:linenum = matchstr (l:line_part_1,'[0-9]\+')
			let l:new_linenum = l:linenum + l:comments_count
			let l:new_errmsg = l:new_errmsg . l:new_linenum . strpart (l:curr_msg, strlen (l:linenum), 99999999)
			"store linenumbers in a global variable
			let s:sqlErrLines = s:sqlErrLines . l:new_linenum . ';'
"echo 'l:new_errmsg : ' l:new_errmsg 
		endwhile

"let g:sqlout1 = l:errmsgs
		" save the errormessages to the error file
		exec 'redir > ' . &errorfile
		echo l:new_errmsg
		redir end
		return 1
	endif


	return 

endfunction



""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Signs
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
if has("signs")
	let v:errmsg = ""
	silent! sign list SQLMakeError
	if "" != v:errmsg
		sign define SQLMakeError linehl=Error text=?> texthl=Error
	endif
endif



augroup SqlPlus
"  au!
"
" This is to remove any error indicators that was added as part of SqlMake().
autocmd! BufWritePre,FileWritePre *.sql,*.pls
if has("signs")
	autocmd BufWritePre,FileWritePre *.sql,*.pls normal :sign unplace *
else
	autocmd BufWritePre,FileWritePre *.sql,*.pls normal :g/ --ERR\d*--/s///g
endif

autocmd! BufNewFile,BufRead *.pkb,*.pks call WBKeyMappingCompiler()
 
"  autocmd BufEnter *.iqd,*.sql,*.pls,afiedt.buf, source $VIM/user/sqlEnter.vim
"  autocmd BufLeave,WinLeave *.iqd,*.sql,*.pls,afiedt.buf source $VIM/user/sqlLeave.vim

augroup end

" Load key and command defintions
call WBKeyMappingGeneral()
" restore 'cpo'
let &cpo = s:cpo_save
unlet s:cpo_save
