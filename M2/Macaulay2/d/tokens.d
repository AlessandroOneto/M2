--		Copyright 1994 by Daniel R. Grayson
--- here we define the recursive types involved in parsing
use pthread0;
use stdiop;
use gmp1;
use xml;
use engine;
use varnets;
use expr;
export threadLocal debugLevel := 0;
export threadLocal engineDebugLevel := 0;



export isglobaldict(d:Dictionary):bool := !d.transient && d.frameID == 0;

-- misc

export flush(f:TokenFile):void := (f.nexttoken=NULL; flush(f.posFile););
export close(file:TokenFile):int := close(file.posFile);
export fileErrorMessage(f:TokenFile):string := fileErrorMessage(f.posFile);
export fileError(f:TokenFile):bool := fileError(f.posFile);
export clearFileError(f:TokenFile):void := clearFileError(f.posFile);
export isatty(f:TokenFile):bool := isatty(f.posFile);

-- Expr Functions

export printErrorMessage(err:Error):void := printErrorMessage(err.position,err.message);

export getLocalDictionary(frameID:int):Dictionary := (
     p := allDictionaries;
     while (
	  if p.dictionary.frameID == frameID then return p.dictionary;
	  p != p.next) do p = p.next;
     error("internal error: local dictionary with frameID " + tostring(frameID) + " not found");
     dummyDictionary);
export localDictionaryClosure(f:Frame):DictionaryClosure := DictionaryClosure(noRecycle(f),getLocalDictionary(f.frameID));


-- more dummies

dummyunary(w:Token,o:TokenFile,prec:int,obeylines:bool):ParseTree := (
     error("unary dummy used"); 
     w);
dummybinary(w:ParseTree,v:Token,o:TokenFile,prec:int,obeylines:bool):ParseTree := (
     error("binary dummy used"); 
     w);
export nopr := -1;						    -- represents unused precedence
export newParseinfo():parseinfo := parseinfo(nopr,nopr,nopr,parsefuns(dummyunary,dummybinary));
export dummyWord    := Word("{*dummy word*}",TCnone,0,newParseinfo());

export dummyTree    := ParseTree(dummy(dummyPosition));
export emptySequence := Sequence();
export dummyUnaryFun(c:Code):Expr := (
     error("dummy unary function called");
     nullE);
export dummyPostfixFun(c:Code):Expr := (
     error("dummy postfix function called");
     nullE);
export dummyBinaryFun(c:Code,d:Code):Expr := (
     error("dummy binary function called");
     nullE);
export dummyTernaryFun(c:Code,d:Code,e:Code):Expr := (
     error("dummy ternary function called");
     nullE);
export emptySequenceE := Expr(emptySequence);

export dummySymbol := Symbol(
     Word("{*dummy symbol*}",TCnone,0,newParseinfo()),dummySymbolHash,dummyPosition,
     dummyUnaryFun,dummyPostfixFun,dummyBinaryFun,
     Macaulay2Dictionary.frameID,dummySymbolFrameIndex,1,
     false,						    -- not protected, so we can use it in parallelAssignmentFun
     false,
     false
     );
dummySymbolClosure := SymbolClosure(globalFrame,dummySymbol);
globalFrame.values.dummySymbolFrameIndex = Expr(dummySymbolClosure);
export dummyCode := Code(nullCode());
export NullCode := Code(nullCode());
export dummyCodeClosure := CodeClosure(dummyFrame,dummyCode);
export dummyToken   := Token(
     Word("{*dummy token*}",TCnone,0,newParseinfo()),
     dummyPosition.filename,
     dummyPosition.line,
     dummyPosition.column,
     dummyPosition.loadDepth,
     Macaulay2Dictionary,dummySymbol,false);

export parseWORD    := newParseinfo();			    -- parsing functions filled in later




-- debugging

export returnMessage := "unhandled return command";
export continueMessage := "unhandled continue command";
export continueMessageWithArg := "unhandled continue command, with argument";
export stepMessage := "unhandled step command";
export stepMessageWithArg := "unhandled step command, with argument";
export breakMessage := "unhandled break command";
export throwMessage := "unhandled throw command";
export unwindMessage := "unhandled unwind command";
export interruptMessage := "interrupted";
export alarmMessage := "alarm occurred";
export steppingMessage := "--stepping limit reached";
export buildErrorPacket(message:string):Expr := Expr(Error(dummyPosition,message,nullE,false,dummyFrame));
export buildErrorPacketErrno(msg:string,errnum:int):Expr := buildErrorPacket( msg + ": " + strerror(errnum) );
export cwd():Expr := (
     r := getcwd();
     if r === "" then buildErrorPacket("can't get current working directory: " + syserrmsg())
     else Expr(stringCell(r)));
dummyDebuggerFun(f:Frame,c:Code):Expr := nullE;
export debuggerFun := dummyDebuggerFun;
export handleInterrupts := true;
(threadLocal export stopIfError := true) = false;
foreach s in argv do
  if s === "--stop" then stopIfError = true else
  if s === "--int" then (handleInterrupts = false; handleInterruptsSetup(handleInterrupts););
(threadLocal export debuggingMode := false) = true;

export printIfError(e:Expr):void := (
     when e is err:Error do printErrorMessage(err.position,err.message) else nothing;
     );
export printError(err:Error):Error := (
     if !(err.printed && err.position.filename === "stdio")
     then printErrorMessage(err.position, if err.printed then "--back trace--" else err.message);
     err.printed = true;
     err);
export position(t:Token):Position := Position(t.filename,t.line,t.column,t.loadDepth);
export printErrorMessage(t:Token,message:string):void := printErrorMessage(position(t),message);
export printWarningMessage(t:Token,message:string):void := printWarningMessage(position(t),message);


export (x:SymbolClosure) === (y:SymbolClosure) : bool := (
     x == y || x.symbol == y.symbol && x.frame == y.frame
     );
export (x:SymbolBody) === (y:SymbolBody) : bool := (
     x == y || x.symbol == y.symbol
     );
export (x:SymbolClosure) === (y:SymbolBody) : bool := (
     x.symbol == y.symbol
     );
export (x:SymbolBody) === (y:SymbolClosure) : bool := (
     x.symbol == y.symbol
     );
export (x:Symbol) === (y:SymbolClosure) : bool := x == y.symbol;
export (x:Symbol) === (y:SymbolBody   ) : bool := x == y.symbol;
export (x:SymbolClosure) === (y:Symbol) : bool := x.symbol == y;
export (x:SymbolBody   ) === (y:Symbol) : bool := x.symbol == y;
export (x:SymbolClosure) === (y:Expr):bool := (
     x == y || (
	  when y
	  is z:SymbolClosure do x.symbol == z.symbol && x.frame == z.frame
	  is z:SymbolBody    do x.symbol == z.symbol
	  else false
	  ));
export (x:Expr) === (y:SymbolClosure):bool := (
     y == x || (
	  when x
	  is z:SymbolClosure do y.symbol == z.symbol && y.frame == z.frame
	  is z:SymbolBody    do y.symbol == z.symbol
	  else false
	  ));
export (x:Symbol) === (y:Expr):bool := (
     when y
     is z:SymbolClosure do x == z.symbol
     is z:SymbolBody    do x == z.symbol
     else false);
export (x:Expr) === (y:Symbol):bool := (
     when x 
     is z:SymbolClosure do y == z.symbol     
     is z:SymbolBody    do y == z.symbol
     else false);

-- operator names for the disassembler
export dummyUnop(c:Code):Expr := nullE;
export dummyBinop(c:Code,d:Code):Expr := nullE;
export dummyTernop(c:Code,d:Code,e:Code):Expr := nullE;
export dummyMultop(s:CodeSequence):Expr := nullE;
export unopNameListCell := {f:unop,name:string,next:unopNameListCell};
export binopNameListCell := {f:binop,name:string,next:binopNameListCell};
export ternopNameListCell := {f:ternop,name:string,next:ternopNameListCell};
export multopNameListCell := {f:multop,name:string,next:multopNameListCell};
export unopNameList := unopNameListCell(dummyUnop,"{*dummy unary operator*}",self);
export binopNameList := binopNameListCell(dummyBinop,"{*dummy binnary operator*}",self);
export ternopNameList := ternopNameListCell(dummyTernop,"{*dummy ternary operator*}",self);
export multopNameList := multopNameListCell(dummyMultop,"{*dummy n-ary operator*}",self);
export getUnopName(f:unop):string := (
     p := unopNameList;
     while true do (
	  if p == p.next then return "";
	  if p.f == f then return p.name;
	  p = p.next;
	  ));
export getBinopName(f:binop):string := (
     p := binopNameList;
     while true do (
	  if p == p.next then return "";
	  if p.f == f then return p.name;
	  p = p.next;
	  ));
export getTernopName(f:ternop):string := (
     p := ternopNameList;
     while true do (
	  if p == p.next then return "";
	  if p.f == f then return p.name;
	  p = p.next;
	  ));
export getMultopName(f:multop):string := (
     p := multopNameList;
     while true do (
	  if p == p.next then return "";
	  if p.f == f then return p.name;
	  p = p.next;
	  ));


-- Local Variables:
-- compile-command: "echo \"make: Entering directory \\`$M2BUILDDIR/Macaulay2/d'\" && make -C $M2BUILDDIR/Macaulay2/d tokens.o "
-- End:
