module Enecuum.Core.Logger.InterpreterHslogger where

import           Enecuum.Prelude
import           Eff (Eff, handleRelay)
import qualified Enecuum.Core.Language                      as L
import System.Log (Priority(..))
import System.Log.Logger
import System.Log.Handler (close, LogHandler)
import System.Log.Handler.Simple
import Enecuum.Core.Logger.Language
import qualified Enecuum.Core.Types.Logger as T
import qualified Data.Text as TXT (unpack)
import Enecuum.Core.Logger.Hslogger (withLogger, withLoggerOriginal, setCommonFormatter, withLoggerOriginalNew)
import Enecuum.Core.System.Directory (defaultLogFileName, appFileName)
import System.Log.Handler (setFormatter)
import System.Log.Formatter
import           Enecuum.Core.Types.Logger     (standartFormat)
import Enecuum.Core.Logger.Hslogger (LoggerHandle(..))


-- | Dispatch log level from the LoggerL language
-- to the relevant log level of hslogger package
dispatchLogLevel :: T.LogLevel -> Priority
dispatchLogLevel T.Debug   = DEBUG
dispatchLogLevel T.Info    = INFO
dispatchLogLevel T.Warning = WARNING
dispatchLogLevel T.Error   = ERROR

-- | Interprets a LoggerL language.
-- via package hslogger
interpretLoggerL :: L.LoggerL a -> Eff '[SIO, Exc SomeException] a
interpretLoggerL logger@(L.LogMessage _ _ ) = safeIO $ interpretLoggerLBase logger
interpretLoggerL logger@(L.SetConfigForLog _ _ _) = safeIO $ interpretLoggerLBase logger


-- | Base primitive for the LoggerL language.
interpretLoggerLBase ::  L.LoggerL a -> IO ()
interpretLoggerLBase (L.LogMessage logLevel msg ) = do
  withLoggerOriginal $ logM comp (dispatchLogLevel logLevel) $ TXT.unpack msg
interpretLoggerLBase (L.SetConfigForLog level logFilename format) =
  withLogger (\(LoggerHandle fh) -> do
                 -- let fh' = setFormatter fh (simpleLogFormatter format)
                 -- updateGlobalLogger comp $ addHandler fh'
                 updateGlobalLogger comp $ setLevel $ dispatchLogLevel level
             )

-- | Base primitive for the LoggerL language.
interpretLoggerLBaseNew ::  L.LoggerL a -> IO ()
interpretLoggerLBaseNew (L.LogMessageNew fileLevel logFilename format logLevel msg ) = do
  withLoggerOriginalNew format logFilename (dispatchLogLevel fileLevel) $
    logM comp (dispatchLogLevel logLevel) $ TXT.unpack msg


-- | Runs the LoggerL language without config.
runLoggerL
    :: Eff '[L.LoggerL, SIO, Exc SomeException] a
    -> Eff '[SIO, Exc SomeException] a
runLoggerL = handleRelay pure ((>>=) . interpretLoggerL )

-- 'comp' is short for 'component'
comp :: String
comp = "LoggingExample.Main"
