-- | This is the base module for the Dotenv library.

module Dotenv (Name, Setting, Settings, Value, loadFile) where

import Prelude
import Control.Monad.Error.Class (class MonadThrow, catchError, throwError)
import Data.Either (either)
import Data.Maybe (Maybe)
import Data.Tuple (Tuple)
import Dotenv.Internal.Apply (applySettings)
import Dotenv.Internal.ChildProcess (_childProcess, handleChildProcess)
import Dotenv.Internal.Environment (_environment, handleEnvironment)
import Dotenv.Internal.Parse (settings) as Parse
import Dotenv.Internal.Resolve (resolveValues)
import Dotenv.Internal.Types (Setting) as IT
import Dotenv.Internal.Types (UnresolvedValue)
import Effect.Aff.Class (class MonadAff, liftAff)
import Effect.Exception (Error, error)
import Node.Encoding (Encoding(UTF8))
import Node.FS.Aff (readTextFile)
import Run (case_, interpret, on)
import Text.Parsing.Parser (parseErrorMessage, runParser)

-- The type of a setting name
type Name = String

-- The type of a (resolved) value
type Value = Maybe String

-- The type of a setting
type Setting = Tuple Name Value

-- The type of settings
type Settings = Array Setting

-- | Loads the `.env` file into the environment.
loadFile :: forall m. MonadAff m => MonadThrow Error m => m Settings
loadFile = readDotenv
       >>= (flip runParser Parse.settings >>> either (parseErrorMessage >>> error >>> throwError) pure)
       >>= processSettings

-- | Reads the `.env` file.
readDotenv :: forall m. MonadAff m => m String
readDotenv = liftAff $ readTextFile UTF8 ".env"
                     # flip catchError (const $ pure "")

-- | Processes settings by resolving their values and then applying them to the environment.
processSettings :: forall m. MonadAff m => Array (IT.Setting UnresolvedValue) -> m Settings
processSettings = (resolveValues >=> applySettings) >>> interpret
  ( case_
    # on _childProcess handleChildProcess
    # on _environment handleEnvironment
  )
  >>> liftAff
