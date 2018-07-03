{-# LANGUAGE LambdaCase          #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE PackageImports      #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Node.Lib where

import qualified Control.Concurrent                    as C
import           Control.Concurrent.Chan.Unagi.Bounded
import           Control.Exception
import           Control.Monad
import           Data.Aeson
import qualified Data.ByteString.Lazy                  as L
import           Data.IORef
import           Lens.Micro
import           Network.Socket                        (tupleToHostAddress)
import           Node.Data.Key
import           Node.FileDB.FileServer
import           Node.Node.Base.Server
import           Node.Node.Config.Make
import           Node.Node.Types
import           Service.InfoMsg                       (InfoMsg)
import           Service.Network.Base
import           Service.Transaction.Common            (DBPoolDescriptor (..),
                                                        addMacroblockToDB,
                                                        addMicroblockToDB)
import           Service.Types                         (Microblock, Transaction)
import           System.Directory                      (createDirectoryIfMissing)
import           System.Environment

-- code examples:
-- http://book.realworldhaskell.org/read/sockets-and-syslog.html
-- docs:
-- https://github.com/ethereum/devp2p/blob/master/rlpx.md
-- https://github.com/ethereum/wiki/wiki/%C3%90%CE%9EVp2p-Wire-Protocol
-- https://www.stackage.org/haddock/lts-10.3/network-2.6.3.2/Network-Socket-ByteString.html

-- | Standart function to launch a node.
startNode :: (NodeConfigClass s, ManagerMsg a1, ToManagerData s) =>
       DBPoolDescriptor
    -> BuildConfig
    -> C.Chan ExitMsg
    -> C.Chan Answer
    -> InChan InfoMsg
    -> ((InChan a1, OutChan a1) -> IORef s -> IO ())
    -> ((InChan a1, OutChan a1) -> C.Chan Transaction -> C.Chan Microblock -> MyNodeId -> InChan FileActorRequest -> IO a2)
    -> IO (InChan a1, OutChan a1)
startNode descrDB buildConf exitCh answerCh infoCh manager startDo = do

    --tmp
    createDirectoryIfMissing False "data"

    managerChan@(inChanManager, _) <- newChan (2^7)
    aMicroblockChan  <- C.newChan
    aVlalueChan      <- C.newChan
    aTransactionChan <- C.newChan
    config  <- readNodeConfig
    bnList  <- readBootNodeList $ bootNodeList buildConf
    (aInFileRequestChan, aOutFileRequestChan) <- newChan (2^4)
    void $ C.forkIO $ startFileServer aOutFileRequestChan
    let portNumber = extConnectPort buildConf
    md      <- newIORef $ toManagerData aTransactionChan aMicroblockChan aVlalueChan exitCh answerCh infoCh aInFileRequestChan bnList config portNumber
    startServerActor inChanManager portNumber
    void $ C.forkIO $ microblockProc descrDB aMicroblockChan aVlalueChan infoCh
    void $ C.forkIO $ manager managerChan md
    void $ startDo managerChan aTransactionChan aMicroblockChan (config^.myNodeId) aInFileRequestChan
    return managerChan


microblockProc :: DBPoolDescriptor -> C.Chan Microblock -> C.Chan Value -> InChan InfoMsg -> IO ()
microblockProc descriptor aMicroblockCh aVlalueChan aInfoCh = do
    void $ C.forkIO $ forever $ do
        aMicroblock <- C.readChan aMicroblockCh
        addMicroblockToDB descriptor aMicroblock aInfoCh
    forever $ do
        aVlalue <- C.readChan aVlalueChan
        addMacroblockToDB descriptor aVlalue aInfoCh


readNodeConfig :: IO NodeConfig
readNodeConfig =
    try (L.readFile "configs/nodeInfo.json") >>= \case
        Right nodeConfigMsg         -> case decode nodeConfigMsg of
            Just nodeConfigData     -> return nodeConfigData
            Nothing                 -> putStrLn "Config file can not be readed. New one will be created" >> config
        Left (_ :: SomeException)   -> putStrLn "ConfigFile will be created." >> config
  where
    config = do
        makeFileConfig
        readNodeConfig

readBootNodeList :: String -> IO BootNodeList
readBootNodeList conf = do
    bnList  <- try (getEnv "bootNodeList") >>= \case
            Right item              -> return item
            Left (_::SomeException) -> return conf
    toNormForm $ read bnList
     where
       toNormForm aList = return $ (\(a,b,c) -> (NodeId a, Connect (tupleToHostAddress b) c))
          <$> aList

---



mergeMBlocks :: [Microblock] -> [Microblock] -> [Microblock] -- new old result
mergeMBlocks [] old = old
mergeMBlocks (x:xs) olds = if containMBlock x olds
    then mergeMBlocks xs olds
    else mergeMBlocks xs (x : olds)


containMBlock :: Microblock -> [Microblock] -> Bool
containMBlock el elements = or $ (==) <$> [el] <*> elements
-------------------------------------------------------
