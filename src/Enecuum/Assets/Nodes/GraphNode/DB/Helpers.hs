module Enecuum.Assets.Nodes.GraphNode.DB.Helpers where

import           Enecuum.Prelude

import qualified Enecuum.Blockchain.DB                as D
import qualified Enecuum.Blockchain.DB.Lens           as Lens
import qualified Enecuum.Blockchain.Lens              as Lens
import qualified Enecuum.Domain                       as D
import qualified Enecuum.Language                     as L

import qualified Enecuum.Assets.Nodes.GraphNode.Logic as G

withKBlocksDB
    :: forall s db a
    .  Lens.HasKBlocksDB s (D.Storage db)
    => s
    -> L.DatabaseL db a
    -> L.NodeL a
withKBlocksDB dbModel = L.withDatabase (dbModel ^. Lens.kBlocksDB)

withKBlocksMetaDB
    :: forall s db a
    .  Lens.HasKBlocksMetaDB s (D.Storage db)
    => s
    -> L.DatabaseL db a
    -> L.NodeL a
withKBlocksMetaDB dbModel = L.withDatabase (dbModel ^. Lens.kBlocksMetaDB)

withMBlocksDB
    :: forall s db a
    .  Lens.HasMBlocksDB s (D.Storage db)
    => s
    -> L.DatabaseL db a
    -> L.NodeL a
withMBlocksDB dbModel = L.withDatabase (dbModel ^. Lens.mBlocksDB)

withMBlocksMetaDB
    :: forall s db a
    .  Lens.HasMBlocksMetaDB s (D.Storage db)
    => s
    -> L.DatabaseL db a
    -> L.NodeL a
withMBlocksMetaDB dbModel = L.withDatabase (dbModel ^. Lens.mBlocksMetaDB)

withDBModel :: G.GraphNodeData -> (D.DBModel -> L.NodeL ()) -> L.NodeL ()
withDBModel nodeData act = case nodeData ^. G.db of
    Nothing      -> pure ()
    Just dbModel -> act dbModel

-- -- | Loads the first value, and if it's `Left err`, returns `Left err`
-- -- Except when the key is not found.
-- -- If the first value is `Right res`, loads the rest
-- -- (loads all loaders or stops on the first Left result).
-- -- Turns the rest results into list of successes and returns `Right (res : resulsts)`
-- materialize :: [L.DatabaseL db (D.DBResult a)] -> L.DatabaseL db (D.DBResult [a])
-- materialize []          = pure $ Right []
-- materialize (loader:ls) = do
--     eResult <- loader
--     case eResult of
--         Left (D.DBError D.KeyNotFound _) -> pure $ Right []
--         Left err                         -> pure $ Left err
--         Right res                        -> do
--             results <- materialize' ls
--             pure $ Right $ res : results
--     where
--       materialize' :: [L.DatabaseL db (D.DBResult a)] -> L.DatabaseL db [a]
--       materialize' []          = pure []
--       materialize' (loader':ls') = do
--           eResult <- loader'
--           either (const $ pure []) (\res -> (res :) <$> materialize' ls') eResult

-- | On `Right val`, evals `action` with `val`.
-- On `Left err`, returns `Left err`.
withResult
    :: Applicative f
    => Either a t
    -> (t -> f (Either a b))
    -> f (Either a b)
withResult (Left err)     _      = pure $ Left err
withResult (Right result) action = action result

-- | On `Right val`, evals `action` with `val` and returns a list of successes.
-- On `Left err`, logs error except it is KeyNotFound and returns empty list.
materialize
    :: Monad m
    => L.Logger m
    => D.DBResult t
    -> (t -> m [b])
    -> m [b]
materialize (Right result)                     action = action result
materialize (Left (D.DBError D.KeyNotFound _)) _      = pure []
materialize (Left err)                         _      = do
    L.logError $ show err
    pure []