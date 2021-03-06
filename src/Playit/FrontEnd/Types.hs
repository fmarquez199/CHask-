{- |
 * Grammatical types
 *
 * Copyright : (c) 
 *  Manuel Gonzalez     11-10390
 *  Francisco Javier    12-11163
 *  Natascha Gamboa     12-11250
-}
module Playit.FrontEnd.Types where

import Control.Monad.Trans.RWS
import Data.List                       (intercalate,elemIndex)
import Data.Maybe                      (fromJust)
-- import Playit.FrontEnd.Promises.Types -- Resolver ciclo de importacion
import qualified Data.Map               as M


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--                       AST representation data types
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------


-- | Program Variables, registers, unions and subroutines ids
type Id = String

-- Instruction's position
type Pos = (Int, Int)

-- Subroutine's parameters / arguments 
type Params = [(Expr,Pos)]

-- Instruction sequence
type InstrSeq = [Instr]


-- Tipo de dato que pueden ser las expresiones
data Type = 
  TArray Expr Type |
  TBool            |
  TChar            |
  TDummy           | -- Temp for when the type its still unknown
  TError           | -- Error type, type checks fail
  TFloat           |
  TInt             |
  TList Type       |
  TListEmpty       |
  TNew Id          |
  TNull            |
  TPDummy          | -- Temp for when the subroutine is promised to be defined later
  TPointer Type    |
  TRead            | -- Cableado para que el input corra
  TRegister        |
  TStr             |
  TUnion           |
  TVoid              -- Procedures type by default
  deriving(Eq, Ord)

instance Show Type where
    show (TArray e t) = show t ++ "|}" ++ show e ++ "{|"
    show TBool        = "Battle"
    show TChar        = "Rune"
    show TDummy       = "Type unkown"
    show TError       = "Type error"   
    show TFloat       = "Skill"
    show TInt         = "Power"
    show (TList t)    = "Kit of (" ++ show t ++ ")"
    show TListEmpty   = "Empty Kit"
    show (TNew str)   = str
    show TNull        = "DeathZone*"
    show TPDummy      = "Unknown return type"
    show (TPointer t) = "" ++ show t ++ "*"
    show TRegister    = "Inventory"
    show TRead        = ""
    show TStr         = "Runes"
    show TUnion       = "Items"
    show TVoid        = "Void"

    
-- Kinds of variables
data Var =
  Param Id Type Ref   |
  Desref Var Type     | -- Desreferenced variable
  Var Id Type         |
  Index Var Expr Type | -- Indexed variable
  Field Var Id Type     -- Registers / unions field
  deriving (Eq, Ord)


instance Show Var where
  show (Param n t Value) = "Parameter: " ++ {-"("++show t++")"++-}n
  show (Param n t _)     = "Parameter: ?" ++ {-"("++show t++")"++-}n
  show (Desref v t)      = {-"("++show t++")"++-}"puff (" ++ show v ++ ")"
  show (Var n t)         = {-"("++show t++")"++-}n
  show (Index v e t)     = {-"("++show t++")"++-}show v ++ "[" ++ show e ++ "]"
  show (Field v n t)     = {-"("++show t++") "++"("++-}show v ++ " spawn " ++ n

-- Specify if a parameter is by value or reference
data Ref =
  Reference |
  Value
  deriving(Eq, Show, Ord)

-- Instructions
data Instr  = 
  Assig Var Expr Type                      |
  Assigs InstrSeq Type                     |
  Break Type                               |
  Continue Type                            |
  For Id Expr Expr InstrSeq Type           |
  ForEach Id Expr InstrSeq Type            |
  ForWhile Id Expr Expr Expr InstrSeq Type |
  Free Id Type                             | -- TODO: Cambiar Id por Expr, ayuda en TAC
  IF [(Expr, InstrSeq)] Type               |
  Print [Expr] Type                        |
  ProcCall Subroutine Type                 |
  Program InstrSeq Type                    |
  Return Expr Type                         |
  While Expr InstrSeq Type
  deriving (Eq,Ord)

instance Show Instr where
  show (Assig v e _)             = "  " ++ show v ++ " = " ++ show e ++ "\n"
  show (Assigs s _)              = intercalate "  " (map show s)
  show (Break _)                 = "  GameOver\n"
  show (Continue _)              = "  KeepPlaying\n"
  show (For n e1 e2 s _)         = "  controller " ++ n ++ " = " ++ show e1 ++ " -> "
      ++ show e2 ++ ":\n  " ++ intercalate "  " (map show s) ++ "\n  .~\n"

  show (ForEach n e s _)         = "  controller " ++ n ++ " <- " ++ show e ++
      ":\n  " ++ intercalate "  " (map show s) ++ "\n  .~\n"

  show (ForWhile n e1 e2 e3 s _) = "  controller " ++ n ++ " = " ++ show e1 ++ " -> " ++
      show e2 ++ " lock " ++ show e3 ++ ":\n  " ++ 
      intercalate "  " (map show s) ++ "\n  .~\n"

  show (Free n _)                = "  free " ++ n ++ "\n"
  show (IF s _)                  = "  Button:\n  " ++ concatMap (++"\n  ") guards ++ ".~\n"
      where
          conds  = map (show . fst) s
          instrs =  map (concatMap show . snd) s
          guards = ["| "++c++" }\n    "++i | c<-conds,i<-instrs,elemIndex c conds==elemIndex i instrs]

  show (Print e _)               = "  drop " ++ show e ++ "\n"
  show (ProcCall s _)            = "  kill " ++ show s ++ "\n"
  show (Program s _)             = "\nworld:\n" ++ concatMap show s ++ ".~\n"
  show (Return e _)              = "  unlock " ++ show e
  show (While e s _)             = "  play:\n    " ++
      intercalate "    " (map show s) ++ "  lock " ++ show e ++ "\n  .~\n"


data Subroutine = Call Id Params    deriving (Eq, Ord)

instance Show Subroutine where
  show (Call n p) = n ++ "(" ++ intercalate "," (map (show . fst) p) ++ ")"


-- Expressions
data Expr = 
  ArrayList [Expr] Type        |
  Binary BinOp Expr Expr Type  |
  FuncCall Subroutine Type     |
  IdType Type                  |
  IfSimple Expr Expr Expr Type |
  Literal Literal Type         |
  Null                         | -- tipo: compatible con apt de lo que sea o que el contexto lo diga
  Unary UnOp Expr Type         |
  Read Expr Type               |
  Variable Var Type
  deriving (Eq, Ord)

instance Show Expr where
  show (ArrayList lst t)     = {-"("++show t++")"++-}"[" ++ intercalate "," (map show lst) ++ "]"
  show (FuncCall s t)        = {-"("++show t++")"++-}"kill " ++ show s
  show (IdType t)            = show t
  show (IfSimple e1 e2 e3 t) = {-"("++show t++")"++-}show e1 ++ " ? " ++ show e2 ++ " : " ++ show e3
  show (Literal lit t)       = {-"("++show t++")"++-}show lit
  show Null                  = "DeathZone"
  show (Binary op e1 e2 t)   = {-"("++show t++")"++-}"(" ++ show e1 ++ show op ++ show e2 ++ ")"
  show (Unary op e1 t)       = {-"("++show t++")"++-}show op ++ show e1
  show (Read e t)            = "joystick " ++ show e
  show (Variable var t)      = {-"E("++show t++")"++-}show var

data Literal =
  ArrLst [Literal] | -- >> Arrays and lists
  Boolean Bool     |
  Character Char   |
  EmptyVal         |
  Floatt Float     |
  Integer Int      |
  Register [Expr]  |
  Str String       
  deriving (Eq, Ord)

instance Show Literal where
    show (ArrLst l@(ArrLst _:_))    = show $ map show l 
    show (ArrLst l@(Boolean _:_))   = show $ map ((\x->read x::Bool) . show) l
    show (ArrLst l@(Character _:_)) = show $ map ((\x->read x::Char) . show) l
    show (ArrLst l@(Integer _:_))   = show $ map ((\x->read x::Int) . show) l
    show (ArrLst l@(Floatt _:_))    = show $ map ((\x->read x::Float) . show) l
    show (ArrLst l)                 = concatMap show l
    show (Register inits)           = "{" ++ intercalate "," (map show inits) ++ "}"
    show (Boolean val)              = show val
    show (Character val)            = show val
    show (Integer val)              = show val
    show (Floatt val)               = show val
    show (Str val)                  = val
    show EmptyVal                   = "Empty Value"


-- Binary operators
data BinOp =
  And         |
  Anexo       |
  Concat      |
  NotEq       |
  DivEntera   |
  Division    |
  Eq          |
  Greater     |
  GreaterEq   |
  Less        |
  LessEq      |
  Module      |
  Mult        |
  Or          |
  Minus       |
  Add
  deriving (Eq, Ord)

instance Show BinOp where
  show And       = " && "
  show Anexo     = " : "
  show Concat    = " :: "
  show NotEq     = " != "
  show DivEntera = " // "
  show Division  = " / "
  show Eq        = " == "
  show Greater   = " > "
  show GreaterEq = " >= "
  show Less      = " < "
  show LessEq    = " <= "
  show Module    = " % "
  show Mult      = " * "
  show Or        = " || "
  show Minus     = " - "
  show Add       = " + "


-- Unary operators
data UnOp =
  Length    |
  LowerCase |
  Negative  |
  New       |
  Not       |
  UpperCase
  deriving (Eq, Ord)

instance Show UnOp where
  show Length    = "#"
  show LowerCase = "."
  show Negative  = "-"
  show New       = "summon "
  show Not       = "!"
  show UpperCase = "^"


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--                          Symbol table data types
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

-- Id scope
type Scope = Integer

-- Static chain
type ActiveScopes = [Scope]

-- Symbols categories
data Category  = 
  Constants         |
  Fields            |
  Functions         |
  IterationVariable |
  Parameters Ref    |
  Pointers          |
  Procedures        |
  TypeConstructors  |
  Types             |
  Variables
  deriving (Eq, Ord)

instance Show Category where
  show Constants         = "Constants"
  show Fields            = "Fields"
  show Functions         = "Functions"
  show IterationVariable = "Iteration's Variable"
  show (Parameters r)    = "Parameters by " ++ show r
  show Pointers          = "Pointers"
  show Procedures        = "Procedures"
  show TypeConstructors  = "Type Constructors"
  show Types             = "Types"
  show Variables         = "Variables"

-- Symbol extra information
data ExtraInfo =
  AST InstrSeq       |
  Params [(Type,Id)] |
  FromReg Id {- Bool que indica si esta activo(uniones) -}        -- Register / union al que pertenece el campo/variable
  deriving (Eq, Ord)

instance Show ExtraInfo where
  show (AST s)     = "    AST:\n      " ++ intercalate "\t  " (map show s)
  show (Params p)  = "    Parameters: " ++ show p ++ "\n"
  show (FromReg n) = "    Campo del registro: " ++ show n


-- Symbol related information in the symbol table entry
data SymbolInfo = SymbolInfo {
  symId     :: Id,
  symType   :: Type,
  scope     :: Scope,
  category  :: Category,
  extraInfo :: [ExtraInfo]
  }
  deriving (Eq, Ord)

instance Show SymbolInfo where
  show (SymbolInfo n t s c i) = "\n  Type: " ++ show t ++ " | Scope: " ++
    show s ++ " | Category: "++ show c ++
    if not (null i) then
      "\n    Extra:\n  " ++ intercalate "  " (map show i) ++ "\n"
    else ""

printSymbolInfoData :: SymbolInfo -> String
printSymbolInfoData (SymbolInfo n t s c _) =
  if c == Variables then show s ++ n ++ case t of
    TInt -> ": .buffer 4\n"
    TFloat -> ": .buffer 8"
    x | elem x [TChar, TBool] -> ": .buffer 1\n"
    TStr -> ": .buffer 80\n"
  else ""

{- | New type that represents the symbol table
 * Hash table:
 *   Key: Id
 *   Value: Symbol information
-}
newtype SymTab  = SymTab { getSymTab :: M.Map Id [SymbolInfo] }
                deriving (Eq, Ord)

instance Show SymTab where
  show (SymTab st) = header ++ info ++ symbols
    where
      header       = "\n------------\n Symbol table \n------------\n"
      info         = "- Symbol | Related information \n------------\n"
      table        = M.toList st
      stWithScopes = M.map (map scope) st
      symbols'     = map fst $ M.toList $ M.filter (any (>0)) stWithScopes
      showInfo i   = if scope i > 0 then show i else ""
      showTable (k,v) = 
        if k `elem` symbols' then k ++ " -> " ++ concatMap showInfo (reverse v) ++ "\n"
        else ""
      symbols = concatMap showTable table

printData :: SymTab -> String
printData (SymTab st) = do
  let showTable (k, v) = if elem k symbols' then concatMap showInfo (reverse v) ++ "\n" else ""
      symbols'     = map fst $ M.toList $ M.filter (any (>0)) stWithScopes
      stWithScopes = M.map (map scope) st
      showInfo i   = if scope i > 0 then printSymbolInfoData i else ""
  concatMap showTable $ M.toList st


-- State that stores the symbol table, active scopes, total scopes and subroutines promises
data SymTabState = SymTabState {
  symTab :: SymTab,
  actS   :: ActiveScopes,
  currS  :: Scope,
  proms  :: Promises
}

-- Reader that stores the file name and the code for better show of errors
type FileCodeReader = (String,String)

-- Symbol table, active scopes and total scopes monad transformer handler
type MonadSymTab a = RWST FileCodeReader [String] SymTabState IO a




type Promises = [Promise]

-- Subroutine promise for co-recursive subroutines and Registers/unions
data Promise = PromiseS {
  promiseId           :: Id,
  promiseParams       :: [(Type,Pos)],
  promiseType         :: Type,
  promiseCat          :: Category,
  promisePos          :: Pos,
  promiseLateCheck    :: [LateCheckPromise],
  -- Llamadas a funciones que se deben chequear cuando se actualiza el tipo de 
  -- retorno de esta promesa
  -- esta promesa aparece en las expresiones de llamadas a funciones
  otherCallsLateCheck :: [LateCheckPromise],
  forEachLateCheck    :: [LateCheckPromise]
  } | 
  PromiseT {
    promiseId  :: Id,
    promisePos :: Pos
  }
  deriving (Eq, Ord,Show)

-- 
-- Power a = a() > b()? 1:2
-- Power a = #(a() :: b())==10 ? 1:2
-- 
data LateCheckPromise = 
  LateCheckPromS {
    expr        :: Expr,   -- Expresion que debe ser evaluada cuando se actualiza el tipo de la promesa
    argsPos     :: [Pos],  -- Posiciones (linea,columna) de los argumentos necesarios para el check
    linkedProms :: [Id]    -- Otras promesas enlazadas a este check (su relacionado)
  } | 
  LateCheckPromCall {
    promCall    :: Subroutine,  -- Llamada que se debe evaluar
    linkedProms :: [Id]         -- Promesas enlazadas
  } | 
  LateCheckPromForE {
    expr        :: Expr, -- Llamada que se debe evaluar
    varId       :: Id,   -- Promesas enlazadas
    varType     :: Type, -- Promesas enlazadas
    exprPos     :: Pos,
    linkedProms :: [Id]  -- Otras promesas enlazadas a este check (su relacionado)
  }
  deriving (Eq, Ord,Show)

data PromiseExtraI = PromiseExtraI{}
