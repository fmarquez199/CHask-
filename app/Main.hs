{- |
 *  Main module
 *
 * Copyright : (c) 
 *  Manuel Gonzalez     11-10390
 *  Francisco Javier    12-11163
 *  Natascha Gamboa     12-11250
-}
module Main where

import Control.Monad.Trans.RWS (runRWST)
import Control.Monad           (mapM_)
import Control.Exception
import Data.Strings            (strEndsWith)
import System.Environment      (getArgs)
import System.IO.Error
import System.IO               (readFile)
import Playit.SymbolTable
import Playit.Errors
import Playit.Parser
import Playit.Lexer
import Playit.TAC
import Playit.TACType
import Playit.Types
import Playit.PrintPromises


-- | Determines if an file is empty
isEmptyFile :: String -> Bool
isEmptyFile = all (== '\n')


-- | Determines that '.game' is the extension of the file
checkExt :: [String] -> Either String String
checkExt []         = Left "\nError: no file given\n"
checkExt (file:_:_) = Left "\nError: more than one file given\n"
checkExt [file]     = if strEndsWith file ".game" then Right file
                      else  Left "\nError: extension for file not valid\n"


main :: IO ()
main = do
  -- Get arguments from terminal
  args <- getArgs

  case checkExt args of
    Left  msg         -> putStrLn msg
    Right checkedFile -> do
      code <- readFile checkedFile

      if null code || isEmptyFile code then putStrLn "\nError: empty file\n"
      else
        let tokens       = alexScanTokens code
            (hasErr,pos) = lexerErrors tokens
            fileCode     = (checkedFile,code)
            parseCode    = parse tokens
        in
        if hasErr then putStrLn $ showLexerErrors fileCode pos
        else do
          -- mapM_ print tokens
          (ast,state@SymTabState{symTab = st},errs) <- runRWST parseCode fileCode stInitState
          
          if null errs then do
            print ast -- >> print st >> printPromises (proms state)
            -- putStrLn $ "\nActive scopes: " ++ show (actS state)
            -- putStrLn $ "\nActual scope:" ++ show (stScope state)
            -- putStrLn $ "\nOffSets: " ++ show (offSets state)
            -- putStrLn $ "\nActual offset: " ++ show (actOffS state)
            -- (_,state,tac) <- runRWST (gen ast) ast (tacInitState (symTab state))
            -- mapM_ print tac
            -- print state
          else
            mapM_ putStrLn errs
