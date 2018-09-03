module Enecuum.Framework.Domain.Node where

import Data.Text (Text)

import Enecuum.Framework.Domain.Networking (ConnectionConfig)

-- Raw vision of node domain types.
-- Some of these types can be taken from Legacy.

type NodeTag = Text

data NodeConfig = NodeConfig
  { _connectionConfig :: ConnectionConfig

  }

newtype NodeID = NodeID Text

