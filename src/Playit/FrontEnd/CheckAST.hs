{- |
 * Checks the AST types
 *
 * Copyright : (c)
 *  Manuel Gonzalez     11-10390
 *  Francisco Javier    12-11163
 *  Natascha Gamboa     12-11250
-}

module Playit.FrontEnd.CheckAST where

import Control.Monad.Trans.RWS
import Control.Monad           (when,unless)
import Data.Maybe              (isJust,fromJust,fromMaybe,maybe)
import Playit.FrontEnd.Utils
import Playit.FrontEnd.Errors
import Playit.FrontEnd.Promises.Handler
import Playit.FrontEnd.SymbolTable
import Playit.FrontEnd.Types
import qualified Data.Map as M


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--                        Verificar tipos del AST
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- TODO: colocar los chekeos de checkArray/Index. NO se usa
-- | Checks the type of the index(ed) expression / variable.
checkIndex :: Var -> Type -> Pos -> Pos -> FileCodeReader -> (Type, String)
checkIndex var tExpr pVar pExpr fileCode
  | typeVar var == TError =
    --(TError, semmErrorMsg "Array or List" "Type Error" fileCode pVar)
    (TError, "")

  | tExpr /= TInt =
    (TError, semmErrorMsg TInt tExpr fileCode pExpr)

  | otherwise = (baseTypeArrLst (typeVar var), "")
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- | Checks that desref is to a pointer
checkDesref :: Type -> Pos -> FileCodeReader -> (Type, String)
checkDesref tVar p fileCode
  | isPointer tVar = let (TPointer t) = tVar in (t, "")
  | otherwise = (TError, errorMsg "This is not a pointer" fileCode p)
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- | Checks the new defined type
-- TODO: Faltaba algo, pero no recuerdo que
checkNewType :: Id -> Pos -> SymTab -> FileCodeReader -> MonadSymTab String
checkNewType tName p (SymTab t) fileCode = do
  state@SymTabState{symTab = st, proms = promises} <- get
  let
    infos = lookupInScopes [1] tName st
  
  if isJust infos then
    let
      symIndex = M.findIndex tName t
      sym      = head . snd $ M.elemAt symIndex t -- its already checked that's not redefined
    in
      if category sym == TypeConstructors then return ""
      else
        return (errorMsg ("This isn't a defined type\n"++tName++"\n") fileCode p)
  else do
    let
      promise = getPromise tName promises

    unless (isJust promise) $ do
      -- Create the promise
      let 
        newProm     = PromiseT tName  p
        newPromises = promises ++ [newProm]

      put state{proms = newPromises}

    return ""
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- | Cheacks the assginations type in declarations
checkAssigs :: [(Instr,Pos)] -> Type -> FileCodeReader -> MonadSymTab (InstrSeq, String)
checkAssigs assigs t fileCode
  | eqAssigsTypes updatedAssigs t = do
    -- Actualiza los TPDummys
    nexprs <- mapM (\(Assig _ e _) -> updateExpr e t) onlyassigs    
    return ([Assig v ne ta | (Assig v _ ta,ne) <- zip updatedAssigs nexprs ],"")

  | otherwise = do
    let
      le  = map (\(Assig _ e _,p) -> (e,p)) assigs
      got = head $ dropWhile (\(e,_) ->  isJust (getTLists [typeE e,t])) le
      msg = semmErrorMsg t (typeE $ fst got) fileCode (snd got)

    if typeE (fst got) /= TError then return (updatedAssigs, msg)
    else return (updatedAssigs, "")

  where
    onlyassigs  = map fst assigs
    updatedAssigs = map (changeTDummyAssigs t) onlyassigs
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- | Checks the assignation's types
checkAssig :: Type -> Expr -> Pos -> FileCodeReader -> String
checkAssig tLval expr p fileCode
  | isRead || isNull || isInitReg || (tExpr == tLval) || isLists = ""
  | isArray tLval && isArray tExpr =
    -- Si son arrays y arrays del mismo tipo 
    --- TODO:  Faltaría verificar que tienen el mismo tamaño para arrays con expresiones no literales
    --          Power|)2(|  ==  Power|)1+1(|
    --          Power|)n(|  ==  Power|)i(|
    if isJust tarrays && e1 == e2 then "" else msg
  
  | otherwise = msg

  where
    tExpr         = typeE expr
    isEmptyList   = isList tExpr && baseTypeT tExpr == TDummy
    isListLval    = isList tLval && isSimpleType (baseTypeT tLval)
    isLists       = isEmptyList && isListLval && isJust (getTLists [tLval,tExpr])
    isRead        = tExpr == TRead
    isNull        = tExpr == TNull
    isInitReg     = tExpr == TRegister
    msg           = semmErrorMsg tLval tExpr fileCode p
    (TArray e1 _) = tLval
    (TArray e2 _) = tExpr
    tarrays       = getTLists [baseTypeArrLst tLval,baseTypeArrLst tExpr]
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- types ok, cantidad == #campos
-- checkRegUnion :: Id -> [Expr] -> SymTab -> FileCodeReader -> String
-- checkRegUnion name exprs symTab fileCode
--   | noErr && regOK && typesOK && (isRegister || isUnion) = ""
--   | noErr && regOK && not isUnion  = msgNoUnion
--   | noErr && regOK && not isRegister  = msNroFields
--   | noErr && regOK            = msgBadTypes
--   | noErr                                          = msgUndefined
--   | otherwise                                      = msgTError

--   where
--     reg          = lookupInSymTab name symTab
--     regOK        = isJust reg
--     typesE       = map typeE exprs
--     t            = symType (head $ fromJust reg)
--     isRegister   = t == TRegister
--     isUnion      = t == TUnion
--     n            = length exprs
--     noErr        = TError `notElem` typesE
--     (Params p)   = extraInfo (head $ fromJust reg) !! 1
--     typesP       = map fst p

--     typesOK      = null typesE || typesE == typesP || any isRegUnion typesE
--     msgNoUnion   = name ++ " is an union"
--     msNroFields  = "Mismatched ammount of fields initialized for " ++ name
--     msgBadTypes  = "Mismatched types initializating " ++ name
--     msgUndefined = "Undefined register or union " ++ name
--     msgTError    = "Type error in initialization expressions " ++ show exprs
-------------------------------------------------------------------------------

checkRegUnion :: Id -> [(Expr,Pos)] -> SymTab -> FileCodeReader -> Pos -> String
checkRegUnion name exprs symTab fileCode p
  | noErr =
    let symReg = lookupInSymTab name symTab
    in
    if isJust symReg then do
      let 
        registerUnionSym = head $ fromJust symReg
        typeR            = symType registerUnionSym
        fields           = fromJust $ getParams (extraInfo registerUnionSym)
        typesP           = map fst fields
      
      if typeR == TRegister then
        if not (null typesE) then
          if nexprs == length fields then
            if (nexprs == 0 && null fields) ||
              all (==True) [isJust (getTLists [te,tp]) | (te,tp) <- zip typesE typesP] then
                -- TODO: No se esta actualizando el nodo
                -- nexprs <- mapM (\((e,p),tp) -> updateExpr e tp)  (zip exprs typesP)
                ""
            else
              let 
                ((tGot,pTGot),tExpected) = head $ dropWhile (\((te,_),tp) -> isJust (getTLists [te,tp])) [((typeE e,p),tp) | ((e,p),tp) <- zip exprs typesP]
              in
                semmErrorMsg tExpected tGot fileCode pTGot
          else
            if nexprs /= 0 then
               errorMsg "You must provide a value for each field!" fileCode p
            else ""
        else ""
      else
        if not (null typesE) then
          if nexprs > 1 then
              errorMsg "You have to use just one value to initialize an Item" fileCode p
          else
            if null fields then
               errorMsg "This union doesnt have any field" fileCode p
            else if True `elem` [isJust (getTLists [te,tp]) | te <- typesE , tp <- typesP] then 
              -- TODO: No se esta actualizando el nodo
              -- let (e,tp) = head $ filter (\(e,tp) -> isJust (getTLists [typeE e,tp]))  [(e,tp) | (e,_) <- exprs , tp <- typesP]
              -- nexpr <- updateExpr e tp
              ""
            else
               errorMsg  ("Type: '" ++ show (head typesE) ++ "' doesn't belong to any Item field!") fileCode p
        else ""
    else
       errorMsg ("Undefined register or union " ++ name) fileCode p

  | otherwise = ""

  where
    typesE = map (\(e,_) -> typeE e) exprs
    nexprs = length exprs
    noErr  = TError `notElem` typesE

-------------------------------------------------------------------------------
-- | Checks if var is an Iteration's Variable.
checkIterVar :: Var -> MonadSymTab Bool
checkIterVar var = do
  SymTabState{symTab = st, currS = s'} <- get
  let cc s = category s == IterationVariable && scope s == s'
      name = getName var
      sym  = lookupInSymTab name st
      cat  = maybe [] (filter cc) sym
      -- cat  = filter cc $ fromJust (lookupInSymTab name st)

  return $ not $ null cat
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- | Checks the binary's expression's types
checkBinary :: BinOp -> (Expr,Pos) -> (Expr,Pos) -> MonadSymTab (Expr,String)
checkBinary op (e1,p1) (e2,p2) = do
  fileCode <- ask
  let
    tE1         = typeE e1
    tE2         = typeE e2
    tE2'        = baseTypeT tE2
    baseT1      = baseTypeE e1
    baseT2      = baseTypeE e2
    tList       = getTLists [tE1,tE2]
    eqOps       = [Eq,NotEq]
    compOps     = [Eq, NotEq, GreaterEq, LessEq, Greater, Less]
    aritOps     = [Add, Minus, Mult, Division]
    aritInt     = [DivEntera, Module]
    boolOps     = [And, Or]
    anexo       = Binary op e1 e2 tE2
    arit        = Binary op e1 e2 tE1
    div         = Binary op e1 e2 TFloat
    comp        = Binary op e1 e2 TBool
    err         = Binary op e1 e2 TError
    noTError    = tE1 /= TError && tE2 /= TError -- TODO : Agregar a las comparaciones cuando no salga en el primer error
    isRegUnions = isRegUnion tE1 || isRegUnion tE2
    isLists     = isList tE1 && isList tE2 && isJust (getTLists [tE1,tE2])
    nullE1      = tE1 == TNull && isPointer tE2
    nullE2      = isPointer tE1 && tE2 == TNull
    isNull      = (nullE1 || nullE2) || (tE1 == TNull && tE2 == TNull)
    notRegUnion = "Neither Register nor Union"
    regUnion    = "Register or Union"
    msgTE12P2   = semmErrorMsg tE1 tE2 fileCode p2
    msgTE21P1   = semmErrorMsg tE2 tE1 fileCode p1
    msgComp     = compErrorMsg tE1 fileCode p1

  if tE1 == tE2 then
    case op of
      x | x `elem` compOps ->
        if op `elem` eqOps then 
          if isTypeComparableEq tE1 then return (comp, "")
          else 
            if tE1 == TPDummy then
              let related = getRelatedPromises comp
              in addLateCheck comp comp [p1,p2] related >> return (comp, "")
            else
              if tE1 == TNull then return (comp, "")
              else
                return (err, msgComp)

        else 
          if tE1 == TInt || tE1 == TFloat then return (comp, "")
          else
            if tE1 == TPDummy then
              let related = getRelatedPromises comp
              in addLateCheck comp comp [p1,p2] related >> return (comp, "")
            else
              return (err, aritErrorMsg tE1 fileCode p1)

      x | x `elem` aritOps ->
          if tE1 == TInt || tE2 == TFloat then
            if op == Division then return (div, "") else return (arit, "")
          else 
            if tE1 == TPDummy then
              let related = getRelatedPromises arit
              in addLateCheck arit arit [p1,p2] related >> return (arit, "")
            else 
              return (err, aritErrorMsg tE1 fileCode p1)

      x | x `elem` aritInt ->
          if tE1 == TInt then return (arit, "")
          else 
            if tE1 == TPDummy then do
              ne1 <- updateExpr e1 TInt
              ne2 <- updateExpr e2 TInt
              return (Binary op ne1 ne2 TInt, "")
            else
              return (err, semmErrorMsg TInt tE1 fileCode p1)

      x | x `elem` boolOps ->
          if tE1 == TBool then return (comp, "")
          else
            if tE1 == TPDummy then do
              ne1 <- updateExpr e1 TBool
              ne2 <- updateExpr e2 TBool
              return (Binary op ne1 ne2 TBool, "")
            else
              return (err, semmErrorMsg TBool tE1 fileCode p1)

  else -- Tipos distintos
    if op `elem` eqOps then
      if isTypeComparableEq tE1 && tE2 == TPDummy then do
        ne2 <- updateExpr e2 tE1
        let
          expr = Binary op e1 ne2 TBool
          allidsp = getRelatedPromises expr

        unless (null allidsp ) $
          addLateCheck expr expr [p1,p2] allidsp
        return (expr,"") 

      else 
        if tE1 == TPDummy && isTypeComparableEq tE2 then do
          ne1 <- updateExpr e1 tE2
          let
            expr = Binary op ne1 e2 TBool
            allidsp = getRelatedPromises expr

          unless (null allidsp ) $
            addLateCheck expr expr [p1,p2] allidsp
          return (expr,"")
        
        else 
          if isNull then
            -- TODO: Falta TDUmmy adentro de  punteros
            return (comp, "")
          else 
              if tE1 == TPDummy && tE2 == TNull then do
                ne1 <- updateExpr e1 (TPointer TPDummy)
                -- TODO: Falta manejar apuntador a TDUmmy
                return (Binary op ne1 e2 TBool, "")
              else
                if tE1 == TNull && tE2 == TPDummy then do
                  ne2 <- updateExpr e2 (TPointer TPDummy)
                  -- TODO: Falta manejar apuntador a TDUmmy
                  return (Binary op e1 ne2 TBool, "")
                else
                    if isTypeComparableEq tE1 && not (isTypeComparableEq tE2) then
                      return (err,msgTE12P2)
                    
                    else
                      if not (isTypeComparableEq tE1) && isTypeComparableEq tE2 then
                        return (err,msgTE21P1)
                      
                      else
                        if isLists then
                          let
                            typel = fromJust $ getTLists [tE1,tE2] 
                            allidsp = getRelatedPromises comp
                          in
                          if not (null allidsp) then do
                            ne1 <- updateExpr e1 typel
                            ne2 <- updateExpr e2 typel
                            let 
                              newExpr = Binary op ne1 ne2 TBool
                              newRelated = getRelatedPromises newExpr
                            
                            unless (null newRelated) $
                              addLateCheck newExpr newExpr [p1,p2] newRelated
                            return (newExpr, "")
                          else 
                            return (comp, "")
                
                        else
                          if isPointer tE1 && isPointer tE2 && isJust (getTLists [tE1,tE2]) then
                            let
                              typep = fromJust $ getTLists [tE1,tE2] 
                              allidsp = getRelatedPromises comp
                            in
                              if not (null allidsp) then do
                                ne1 <- updateExpr e1 typep
                                ne2 <- updateExpr e2 typep
                                let 
                                  newExpr = Binary op ne1 ne2 TBool
                                  newRelated = getRelatedPromises newExpr
                                
                                unless (null newRelated) $
                                  addLateCheck newExpr newExpr [p1,p2] newRelated
                                return (newExpr, "")
                              else
                                return (comp, "")
                          else
                            if isTypeComparableEq tE1 && isTypeComparableEq tE2 then
                              return (err,msgTE12P2)
                            else -- TODO :Faltan arrays compatibles
                              return (err,msgComp)

    else 
      if op `elem` compOps || op `elem` aritOps then
        if isTypeNumber tE1 &&  tE2 == TPDummy then do
          ne2 <- updateExpr e2 tE1
          if op `elem` compOps then return (Binary op e1 ne2 TBool, "")
          else return (Binary op e1 ne2 tE1, "")

        else 
          if tE1 == TPDummy &&  isTypeNumber tE2 then do
            ne1 <- updateExpr e1 tE2
            if op `elem` compOps then
              return (Binary op ne1 e2 TBool, "")
            else
              return (Binary op ne1 e2 tE2, "")
          else 
            if isTypeNumber tE1 && not (isTypeNumber tE2) then return (err,msgTE12P2)
            else 
              if not (isTypeNumber tE1) &&  isTypeNumber tE2 then return (err,msgTE21P1)
              else  
                if isTypeNumber tE1  && isTypeNumber tE2 then return (err,msgTE12P2)
                else 
                  return (err, aritErrorMsg tE1 fileCode p1)

      else 
        if op `elem` aritInt then
          if tE1 == TInt && tE2 == TPDummy then do
            ne2 <- updateExpr e2 tE1
            return (Binary op e1 ne2 tE1, "")
          else 
            if tE1 == TPDummy &&  tE2 == TInt then do
              ne1 <- updateExpr e1 tE2
              return (Binary op ne1 e2 tE2, "")
            else 
              if tE1 == TInt then return (err,msgTE12P2)
              else 
                if tE2 == TInt then return (err,msgTE21P1)
                else return (err, semmErrorMsg TInt tE1 fileCode p1)
        
        else 
          if op `elem` boolOps then
            if tE1 == TBool && tE2 == TPDummy then do
              ne2 <- updateExpr e2 tE1
              return (Binary op e1 ne2 TBool, "")
            else 
              if tE1 == TPDummy && tE2 == TBool then do
                ne1 <- updateExpr e1 tE2
                return (Binary op ne1 e2 TBool, "")
              else 
                if tE1 == TBool then return (err,msgTE12P2)
                else 
                  if tE2 == TBool then return (err,msgTE21P1)
                  else return (err, semmErrorMsg TBool tE1 fileCode p1)
          else 
            error $ "Internal error checkbinary: "  ++ show op
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- | Checks the unary's expression type is the spected
checkUnary :: UnOp -> Type -> Type -> Pos -> FileCodeReader -> (Type, String)
checkUnary op tExpr tExpected p fileCode =
  case op of
    Length ->
      if isArray tExpr || isList tExpr || tExpr == TPDummy then (TInt, "")
      else
        (TError, arrLstErrorMsg tExpr fileCode p)

    Negative ->
      if tExpr `elem` [TInt, TFloat, TPDummy] then (tExpr, "")
      else
        (TError, aritErrorMsg tExpr fileCode p)

    _ | tExpr == TDummy   -> (TDummy, "")
      | tExpr == TPDummy  -> (TPDummy, "")
      | tExpr == tExpected -> (tExpr, "")
      | otherwise -> (TError, semmErrorMsg tExpected tExpr fileCode p)
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- | Checks 
checkAnexo :: (Expr,Pos) -> (Expr,Pos) -> FileCodeReader -> (Type, String)
checkAnexo (e1,p1) (e2,p2) fileCode
    | typeR /= TError = (typeR, "")
    | otherwise       = (TError, msg)

    where
        tE1   = typeE e1
        tE2   = typeE e2
        typeR = fromMaybe TError (getTLists [TList tE1,tE2])
        msg   = semmErrorMsg (TList tE1) tE2 fileCode p2
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
checkIfSimple :: (Type,Pos) -> (Type,Pos) -> (Type,Pos) -> FileCodeReader -> (Type,String)
checkIfSimple (tCond,pCond) (tTrue,pTrue) (tFalse,pFalse) fileCode
  | tCond `elem` [TBool,TPDummy] && isJust tResult = (fromJust tResult, "")
  | tCond /= TBool                                 = (TError, errCond)
  | isRealType tTrue && not (isRealType tFalse)    = (TError, errFalse)
  | not (isRealType tTrue) && isRealType tFalse    = (TError, errTrue)
  | otherwise                                      = (TError, otherErr)

  where
    tResult  = getTLists [tTrue, tFalse]
    errCond  = semmErrorMsg TBool tCond fileCode pCond
    errFalse = semmErrorMsg tTrue tFalse fileCode pFalse
    errTrue  = semmErrorMsg tFalse tTrue fileCode pTrue
    otherErr = semmErrorMsg tTrue tFalse fileCode pFalse
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--       Cambiar el tipo 'TDummy' cuando se lee el tipo de la declacion
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------


changeTDummyList :: Type -> Type-> Type
changeTDummyList (TList TDummy) newT = TList newT
changeTDummyList (TList t) newT      = TList (changeTDummyList t newT)
changeTDummyList t newT              = t


changeTPDummyFunction :: Expr -> Type -> Expr
changeTPDummyFunction (FuncCall c TPDummy) =  FuncCall c
-- Error: otherwise


-------------------------------------------------------------------------------
-- Cambia el TDummy de una variable en las declaraciones
changeTDummyLvalAsigs :: Var -> Type -> Var
changeTDummyLvalAsigs (Var n TDummy) t    = Var n t
changeTDummyLvalAsigs (Index var e t') t  = Index (changeTDummyLvalAsigs var t) e t'
changeTDummyLvalAsigs (Desref var t') t   = Desref (changeTDummyLvalAsigs var t) t'
changeTDummyLvalAsigs (Field var id t') t = Field (changeTDummyLvalAsigs var t) id t'
changeTDummyLvalAsigs var _               = var
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- Cambia el TDummy de las variables en las declaraciones
changeTDummyAssigs :: Type -> Instr -> Instr
changeTDummyAssigs t (Assig lval e _) =
    Assig (changeTDummyLvalAsigs lval t) (changeTRead e t) TVoid
-------------------------------------------------------------------------------


-- Cableado para que el input corra
changeTRead :: Expr -> Type -> Expr
changeTRead (Read e _) t = Read e t
changeTRead e _ = e
