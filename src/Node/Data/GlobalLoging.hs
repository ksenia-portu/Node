{-#LANGUAGE FlexibleInstances, UndecidableInstances#-}
module Node.Data.GlobalLoging where

--
import              Control.Monad.Extra
import              Lens.Micro
import              Lens.Micro.Mtl
import              Control.Concurrent.Chan
import              Node.Node.Types

import              Node.Data.NodeTypes
import              Sharding.Space.Distance
import              Sharding.Space.Point
import              Sharding.Types.ShardTypes

import              System.Clock
import              Service.InfoMsg


type ConnectList = [NodeId]
type ShardCount = Int

data LogInfoMsg = LogInfoMsg MyNodeId MyNodePosition ConnectList  ShardCount (Distance Point) (Maybe [ShardHash])


-- | Пишу логи или метрики в канал, где их подхватит поток и перешлёт на сервер.
writeMetric :: Chan InfoMsg ->  String ->  IO ()
writeMetric aChan metric = writeChan aChan $ Metric $ metric


-- +log|tag1,tag2,tag3|nodeId|info|logMsg\r\n
writeLog :: Chan InfoMsg -> [LogingTag] -> MsgType -> String -> IO ()
writeLog aChan aTags aTypes aMsg = writeChan aChan $ Log aTags aTypes aMsg



-------------------------------------------------------------------------------------
