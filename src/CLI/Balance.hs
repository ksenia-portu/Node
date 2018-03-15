module CLI.Balance ( countBalance ) where

--import Data.Monoid (mconcat)
import Service.System.Directory (getTransactionFilePath)
import Service.Types.PublicPrivateKeyPair
import Service.Types
import Node.FileDB.FileDB (readHashMsgFromFile)

getBalance :: PublicKey -> [Transaction] -> Amount
getBalance key transactions = sum $ map getAmount transactions
  where
    getAmount (WithSignature t _) = getAmount t
    getAmount (WithTime _ t) = getAmount t
    getAmount (SendAmountFromKeyToKey from to a)
      | from == key  = a *(-1)
      | to == key    = a
      | otherwise    = 0
    getAmount _ = 0

countBalance :: PublicKey -> IO Amount
countBalance key = do
    ts <- readTransactions =<< getTransactionFilePath
    return $ getBalance key ts

readTransactions :: String -> IO [Transaction]
readTransactions fileName = do
    mblocks <-  readHashMsgFromFile fileName
    let ts =  [trs | (Microblock _ _ trs) <- mblocks]
    return $ mconcat ts