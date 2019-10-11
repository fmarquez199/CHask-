{
{-
 * Representacion de la gramatica para el analisis sintactico
 *
 * Copyright : (c) 
 *  Manuel Gonzalez     11-10390
 *  Francisco Javier    12-11163
 *  Natascha Gamboa     12-11250
-}

module Playit.Parser (parse, error) where
import Control.Monad.Trans.State
import Control.Monad.IO.Class
import Playit.SymbolTable
import Playit.CheckAST
import Playit.Lexer
import Playit.Types
import Playit.AST

}

%name parse
%tokentype { Token }
%error { parseError }
%monad { MonadSymTab }


%token
  -- Palabras reservadas

  bool              { TkBATLE _ _ }
  null              { TkDeathZone _ _ }
  registro          { TkINVENTORY _ _ }
  union             { TkITEMS _ _ }
  list              { TkKIT _ _ }
  int               { TkPOWER _ _ }
  char              { TkRUNE _ _ }
  str               { TkRUNES _ _ }
  float             { TkSKILL _ _ }
  if                { TkBUTTON _ _ }
  proc              { TkBOSS _ _ }
  for               { TkCONTROLLER _ _ }
  print             { TkDROP _ _ }
  else              { TkNotPressed _ _ }
  free              { TkFREE _ _ }
  break             { TkGameOver _ _ }
  input             { TkJOYSTICK _ _ }
  continue          { TkKeepPlaying _ _ }
  funcCall          { TkKILL _ _ }
  while             { TkLOCK _ _ }
  function          { TkMONSTER _ _ }
  do                { TkPLAY _ _ }
  pointer           { TkPUFF _ _ }
  "."               { TkSPAWN _ _ }
  new               { TkSUMMON _ _ }
  return            { TkUNLOCK _ _ }
  world             { TkWORLD _ _ }
  of                { TkOF _ _ }
  endLine           { TkEndLine _ _}

  -- Literales booleanos

  true              { TkWIN _ _ }
  false             { TkLOSE _ _ }

  -- Identificadores

  programa          { TkProgramName _ _ }
  nombre            { TkID _ $$ }

  -- Caracteres

  caracter          { TkCARACTER _ $$ }
  string            { TkSTRINGS _ $$ }
  
  -- Literares numericos
  
  entero            { TkINT _ $$ }
  flotante          { TkFLOAT _ $$ }

  -- Simbolos

  ".~"              { TkFIN _ _ }
  "//"              { TkDivEntera _ _ }
  "||"              { TkOR _ _ }
  "&&"              { TkAND _ _ }
  "<="              { TkLessEqual _ _ }
  "=="              { TkEQUAL _ _ }
  "!="              { TkNotEqual _ _ }
  ">="              { TkGreaterEqual _ _ }
  "<<"              { TkOpenList _ _ }
  ">>"              { TkCloseList _ _ }
  "|>"              { TkOpenListIndex _ _ }
  "<|"              { TkCloseListIndex _ _ }
  "++"              { TkINCREMENT _ _ }
  "--"              { TkDECREMENT _ _ }
  "<-"              { TkIN  _ _ }
  "->"              { TkTO  _ _ }
  "|}"              { TkOpenArray _ _ }
  "{|"              { TkCloseArray _ _ }
  "|)"              { TkOpenArray _ _ }
  "(|"              { TkCloseArray _ _ }
  "+"               { TkSUM _ _ }
  "-"               { TkMIN _ _ }
  "*"               { TkMULT _ _ }
  "/"               { TkDIV _ _ }
  "%"               { TkMOD _ _ }
  "#"               { TkLEN _ _ }
  "?"               { TkREF _ _ }
  "!"               { TkNOT _ _ }
  "<"               { TkLessThan _ _ }
  ">"               { TkGreaterThan _ _ }
  "("               { TkOpenParenthesis _ _ }
  ")"               { TkCloseParenthesis _ _ }
  "{"               { TkOpenBrackets _ _ }
  "}"               { TkCloseBrackets _ _ }
  ","               { TkCOMA _ _ }
  ":"               { TkANEXO _ _ }
  "::"              { TkCONCAT _ _}
  "|"               { TkGUARD _ _ }
  "="               { TkASING _ _ }
  upperCase         { TkUPPER _ _ }
  lowerCase         { TkLOWER _ _ }

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                          Reglas de asociatividad
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


%nonassoc nombre of pointer
%left "=" ":" "<-"
%right "."
%left "||"
%left "&&"
%nonassoc "==" "!="
%nonassoc ">" "<" ">=" "<="
%left "+" "-"
%left "*" "/" "//" "%"
%right negativo "!" upperCase lowerCase input
%left "++" "|}" "{|" "<<" ">>" "::" "|)" "(|" "|>" "<|"
%left "--"
%right "#"
%left "?"

%%

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                          Reglas/Producciones
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

ProgramaWrapper :: {Instr}
  :  EndLines Programa EndLines
    {$2}
  |  EndLines Programa
    {$2}
  |  Programa EndLines
    {$1}
  |  Programa
    {$1}

Programa 
    : world programa ":" EndLines Instrucciones EndLines ".~"  
    {% do
        (symTab,_) <- get
        return $ BloqueInstr $5 symTab }
    

EndLines
  : endLine
    {}
  | EndLines endLine
    {}
  -- | {- Lamda -}
  --   {}
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                            Declaraciones
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

Declaraciones :: {SecuenciaInstr}
  : Declaracion 
    {[$1]}
  | Declaraciones endLine Declaracion
    {$1 ++ [$3]}

Declaracion :: {Instr}
  :  Tipo Identificadores
    {%  let (ids, asigs, vals) = $2 
        in do
            (actualSymTab, scope) <- get
            addToSymTab ids $1 vals actualSymTab scope
            return $ SecDeclaraciones asigs actualSymTab }


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                  Identificadores de las declaraciones
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
Identificadores ::{([Nombre], SecuenciaInstr, [Literal])}
  : Identificador
    { let (id, asigs, e) = $1 in ([id], asigs, [e]) }
  | Identificadores "," Identificador
    {let ((ids, asigs, exprs),(id, asig, e)) = ($1, $3) 
                  in (ids ++ [id], asigs ++ asig, exprs ++ [e])}

Identificador::{(Nombre, SecuenciaInstr, Literal)}
  : nombre "=" Expresion
    {($1, [Asignacion (Var $1 TDummy) $3],ValorVacio) }
  | nombre
    {($1, [], ValorVacio) }

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                      Lvalues y Tipos de datos
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


-- Lvalues, contenedores que identifican a las variables
Lvalue  ::  {Vars}
--  : Lvalue "." nombre
--    {}
    -- Tokens indexacion
--  | Lvalue "|)" Expresion "(|"
--    {}
--  | Lvalue "|>" Expresion "<|"
--    {}
--  | pointer Lvalue
--    {}
  : nombre
    {% crearIdvar $1 }


-- Tipos de datos
Tipo :: {Tipo}
  : Tipo "|}" Expresion "{|" %prec "|}"
    {TArray $3 $1}
  | list of Tipo
    {TLista $3}
  | int
    {TInt}
  | float
    {TFloat}
  | bool
    {TBool}
  | char
    {TChar}
  | str
    {TStr}
  | nombre
    {TDummy} -- No se sabe si es un Registro o Union
  | Tipo pointer
    {TApuntador}


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                        Secuencia de instrucciones
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

Instrucciones :: {SecuenciaInstr}
  : Instrucciones endLine Instruccion
    { $1 ++ [$3] }
  | Instruccion
    { [$1] }

Instruccion :: {Instr}
  : Declaracion
    { $1 }
 | DefinirSubrutina
    { $1 }
  | DefinirRegistro
    { $1 }
  | DefinirUnion
    { $1 }
--  | Controller
--    { $1 }
--  | Play
--    { $1 }
  | Button
    { $1 }
  | Asignacion
    { $1 }
  | EntradaSalida
    { $1 }
  | Free
    { $1 }
  | FuncCall
    { $1 }
  | return Expresion
    { Return $2 }
  | break
    { Break }
  | continue
    { Continue }
--  | nombre "++"
--    {}


--------------------------------------------------------------------------------
-- Instruccion de asignacion '='
Asignacion :: {Instr}
  : Lvalue "=" Expresion
    { crearAsignacion $1 $3 (0,0) }
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Instrucciones de condicionales 'Button', '|' y 'notPressed'
Button :: {Instr}
  : if ":" endLine Guardias ".~"
    { $4 }

Guardias::{Instr}
  : Guardia
    { $1 }
  | Guardias Guardia
    {% do
        (symTab,_) <- get
        let ButtonIF bloq1 = $1
        let ButtonIF bloq2 = $2
        return $ ButtonIF $ bloq1 ++ bloq2 }

Guardia:: {Instr}
  : "|" Expresion "}" EndLines Instrucciones endLine
    { crearGuardiaIF $2 $5 (posicion $1) }
  | "|" else "}" EndLines Instrucciones endLine
    { crearGuardiaIF (Literal (Booleano True) TBool) $5 (posicion $1) }
  | "|" Expresion "}" Instrucciones endLine
    { crearGuardiaIF $2 $4 (posicion $1) }
  | "|" else "}" Instrucciones endLine
    { crearGuardiaIF (Literal (Booleano True) TBool) $4 (posicion $1) }
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Instruccion de iteracion determinada 'control'
Controller
 : for InitVar1 "->" Expresion ":" endLine Instrucciones endLine ".~"
    {}
 | for InitVar1 "->" Expresion while Expresion ":" endLine Instrucciones endLine ".~"
    {}
 | for InitVar2 ":" endLine Instrucciones endLine ".~"
    {}
 | for InitVar1 "->" Expresion ":" endLine ".~"
    {}
 | for InitVar1 "->" Expresion while Expresion ":" endLine ".~"
    {}
 | for InitVar2 ":" endLine ".~"
    {}


-- Se inserta la variable de iteracion en la tabla de simbolos junto con su
-- valor inicial, antes de construir el arbol de instrucciones del 'for'
InitVar1
  : nombre "=" Expresion
    {}
  | Tipo nombre "=" Expresion
    {}

InitVar2
  : nombre "<-" Expresion %prec "<-"
    {}
  | Tipo nombre "<-" Expresion %prec "<-"
    {}
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Instruccion de iteracion indeterminada 'play lock'
Play
  : do ":" endLine Instrucciones endLine while Expresion endLine ".~"
    {}
  | do ":" endLine while Expresion endLine ".~"
    {}
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Instrucciones de E/S 'drop' y 'joystick'
EntradaSalida :: {Instr}
  : print Expresiones
    {crearPrint (crearListaExpr $2) (posicion $1) }
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Instrucciones para liberar la memoria de los apuntadores 'free'
Free :: {Instr}
Free
  : free nombre
    {Free $2}
  | free "|}" "{|" nombre
    {Free $4}
  | free "<<" ">>" nombre
    {Free $4}
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                           Subrutinas
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

DefinirSubrutina 
  : Boss
    {}
  | Monster
    {}

--------------------------------------------------------------------------------
-- Procedimientos
Boss 
  : proc nombre "(" Parametros ")" ":" endLine Instrucciones endLine ".~"
    {  }
  | proc nombre "(" Parametros ")" ":" endLine ".~"
    {}
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Funciones
Monster 
  : function nombre "(" Parametros ")" Tipo ":" endLine Instrucciones endLine ".~"
    {}
  | function nombre "(" Parametros ")" Tipo ":" endLine ".~"
    {}
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Definicion de los parametros de las subrutinas
Parametros :: {[Expr]}
  : Parametros "," Parametro
    { $1 ++ [$3] }
  | Parametro
    { [$1] }


Parametro :: {Expr}
  : Tipo nombre
    { Variables (Param $2) $1 }
  | Tipo "?" nombre
    { Variables (Param $3) $1 }
  | {- Lambda -}
    { ExprVacia }
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Llamada a subrutinas
FuncCall :: {Instr}
  : funcCall nombre "(" PasarParametros ")" 
  { llamarSubrutina $2 $4 }
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Pasaje de los parametros a las subrutinas
PasarParametros :: {Parametros}
  : PasarParametros "," ParametroPasado
    { $1 ++ [$3] }
  | ParametroPasado
    { [$1] }


ParametroPasado :: {Expr}
  : Expresion
    { $1 }
  | "?" Expresion
    { $2 }
  | {- Lambda -}
    { ExprVacia }
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                           Expresiones
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

Expresiones::{[Expr]}
  : Expresiones "," Expresion
    {$1 ++ [$3]}
  | Expresion
    {[$1]}

-- crearOpBin : 
--      TipoExpresion1 x TipoExpresion2 x TipoRetorno x Operacion x Expresion1 x Expresion2 =>
--      Chequea tipos
--      Crea la estructura de la operacion

Expresion :: {Expr}
  : Expresion "+" Expresion
    { crearOpBin TInt TInt TInt Suma $1 $3 }
  | Expresion "-" Expresion
    { crearOpBin TInt TInt TInt Resta $1 $3 }
  | Expresion "*" Expresion
    { crearOpBin TInt TInt TInt Multiplicacion $1 $3  }
  | Expresion "%" Expresion
    { crearOpBin TInt TInt TInt Modulo $1 $3 }
  | Expresion "/" Expresion
    { crearOpBin TInt TInt TInt Division $1 $3 }
  | Expresion "//" Expresion
    {crearOpBin  TInt  TInt TInt DivEntera $1 $3 }
  | Expresion "&&" Expresion
    { crearOpBin TBool TBool TBool And $1 $3 }
  | Expresion "||" Expresion
    { crearOpBin TBool TBool TBool Or $1 $3 }
  | Expresion "==" Expresion
    { crearOpBin TInt TInt TBool Igual $1 $3 }
  | Expresion "!=" Expresion
    { crearOpBin TInt TInt TBool Desigual $1 $3 }
  | Expresion ">=" Expresion
    { crearOpBin TInt TInt TBool MayorIgual $1 $3 }
  | Expresion "<=" Expresion
    { crearOpBin TInt TInt TBool MenorIgual $1 $3 }
  | Expresion ">" Expresion
    { crearOpBin TInt TInt TBool Mayor $1 $3 }
  | Expresion "<" Expresion
    { crearOpBin TInt TInt TBool Menor $1 $3 }
  | Expresion ":" Expresion %prec ":"
    { crearOpBin  TDummy TDummy (TLista TDummy) Anexo $1 $3 }
  | Expresion "::" Expresion
    { crearOpConcat Concatenacion $1 $3 }
  
--  | Expresion "?" Expresion ":" Expresion %prec "?"
--    { crearOpBin  TDummy TDummy (TLista TDummy) IfSimple $1 $3 }
  | "(" Expresion ")"
    {$2}
  | "{" Expresiones "}"
    {crearListaExpr $2 }
  | "|}" Expresiones "{|"
    {crearListaExpr $2 }
  | "<<" Expresiones ">>"
    {crearListaExpr $2 }
--  | "<<"  ">>"
--    {}
--  | FuncCall
--    { $1}
--  | new Tipo
--    { crearOpUn TDummy TDummy New $2 }
  | input
    { crearRead (posicion $1) (Literal ValorVacio TStr) }
  | input Expresion %prec input
    { crearRead (posicion $1) $2 }

  -- Operadores unarios
  | "-" Expresion %prec negativo
    { crearOpUn TInt TInt Negativo $2 }
--  | "#" Expresion
--    { crearOpUn (TArray Expr Tipo) (TArray Expr Tipo) Len $2 }
  | "!" Expresion
    { crearOpUn TBool TBool Not $2 }
  | upperCase Expresion %prec upperCase
    { crearOpUn TChar TChar UpperCase $2 }
  | lowerCase Expresion %prec lowerCase
    { crearOpUn TChar TChar LowerCase $2 }

  -- Literales
  | true
    { Literal (Booleano True) TBool }
  | false
    { Literal (Booleano False) TBool }
  | entero
    { Literal (Entero (read $1::Int)) TInt }
  | flotante
    { Literal (Flotante (read $1::Float)) TFloat }
  | caracter
    { Literal (Caracter $ $1 !! 0) TChar }
  | string
    { Literal (Str $1) TStr }
  | null
    { ExprVacia }
  | Lvalue
    { Variables $1 (typeVar $1) }


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                           Registros, Unions
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Registros
DefinirRegistro :: {Instr}
  : registro nombre ":" endLine Declaraciones endLine ".~"
    { definirRegistro $2 $5 TRegistro }
  | registro nombre ":" endLine ".~"
    { definirRegistro $2 [] TRegistro }
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Uniones
DefinirUnion :: {Instr}
  : union nombre ":" endLine Declaraciones endLine ".~"
    { definirUnion $2 $5 TUnion }
  | union nombre ":" endLine ".~"
    { definirUnion $2 [] TUnion }
--------------------------------------------------------------------------------


{
parseError :: [Token] -> a
parseError (h:rs) = 
    error $ "\n\nError sintactico del parser antes del : " ++ (show h) ++ "\n"
}
