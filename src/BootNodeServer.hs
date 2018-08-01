{-# LANGUAGE LambdaCase          #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell     #-}

module BootNodeServer (
    bootNodeServer
) where

import           Control.Concurrent.Chan.Unagi.Bounded
import           Control.Monad                         (forever, void, when, forM_)
import qualified Data.Text                             as T
import qualified Network.WebSockets                    as WS
import           Service.InfoMsg                       as I
import           Service.Network.Base
import           Service.Network.WebSockets.Client
import           Service.Network.WebSockets.Server
import qualified Control.Concurrent                    as C
import           Control.Exception
import           Data.Aeson                            as A
import           Data.Maybe                            ()
import           Node.Data.GlobalLoging
import           Node.DataActor
import           Node.NetLvl.Massages
import           Service.System.Version

data ConnectTesterActor = AddConnectToList Connect | TestExistedConnect Connect


bootNodeServer :: PortNumber -> InChan InfoMsg -> InChan (DataActorRequest Connect) -> IO ()
bootNodeServer aRecivePort aInfoChan aFileServerChan = do
    writeLog aInfoChan [ServerBootNodeTag, InitTag] Info $
        "Init. ServerPoABootNode: a port is " ++ show aRecivePort
    (aInChan, aOutChan) <- newChan 64
    void $ C.forkIO $ forever $ do
        C.threadDelay 60000000
        aConnects <- getRecords aFileServerChan
        forM_ aConnects (tryWriteChan aInChan . TestExistedConnect)

    void $ C.forkIO $ forever $ readChan aOutChan >>= \case
        AddConnectToList aConn@(Connect aHostAdress aPort) -> void $ C.forkIO $ do
            C.threadDelay 3000000
            runClient (showHostAddress aHostAdress) (fromEnum aPort) "/" $
                \_ -> void $ tryWriteChan aFileServerChan $ AddRecords [aConn]

        TestExistedConnect aConn@(Connect aHostAdress aPort) -> void $ C.forkIO $ do
            aConnects <- getRecords aFileServerChan
            when (aConn`elem`aConnects) $ do
                aOk <- try $ runClient (showHostAddress aHostAdress) (fromEnum aPort) "/" $ \_ -> return ()
                case aOk of
                    Left (_ :: SomeException) ->
                        void $ tryWriteChan aFileServerChan $ DeleteRecords aConn
                    _ -> return ()

    runServer aRecivePort "bootNodeServer" $ \aHostAdress aPending -> do
        aConnect <- WS.acceptRequest aPending
        let aSend = WS.sendTextData aConnect . A.encode
            aLog  = writeLog aInfoChan [ServerBootNodeTag] Info
        aLog "ServerPoABootNode.Connect accepted."
        aMsg <- WS.receiveData aConnect
        case A.eitherDecodeStrict aMsg of
            Right a -> case a of
                RequestVersion -> do
                    aLog  $ "Version request from client node."
                    aSend $ ResponseVersion $(version)

                RequestPotentialConnects aFull
                    | aFull -> do
                        aLog "Accepted request full list of connections."
                        aConnects <- getRecords aFileServerChan
                        aSend $ ResponsePotentialConnects $ filter (\(Connect aAdress _) -> aHostAdress /= aAdress ) aConnects

                    | otherwise -> do
                        aLog "Accepted request of connections."
                        aConnects <- getRecords aFileServerChan
                        aSend $ ResponsePotentialConnects $ filter (\(Connect aAdress _) -> aHostAdress /= aAdress ) aConnects

                ActionAddToConnectList aPort ->
                    void $ tryWriteChan aInChan $ AddConnectToList (Connect aHostAdress aPort)

                ActionConnectIsDead aDeadConnect ->
                    void $ tryWriteChan aInChan $ TestExistedConnect aDeadConnect

                _  -> writeLog aInfoChan [ServerBootNodeTag] Warning $
                    "Broken message from PP " ++ show aMsg
            Left a -> do
                WS.sendTextData aConnect $ T.pack ("{\"tag\":\"Response\",\"type\":\"Error\", \"reason\":\"" ++ a ++ "\", \"Msg\":" ++ show aMsg ++"}")
                writeLog aInfoChan [ServerBootNodeTag] Warning $
                    "Broken message from PP " ++ show aMsg ++ " " ++ a ++ showHostAddress aHostAdress

--------------------------------------------------------------------------------
