{-# LANGUAGE DataKinds                  #-}
{-# LANGUAGE EmptyDataDecls             #-}
{-# LANGUAGE DeriveAnyClass             #-}
{-# LANGUAGE DeriveGeneric              #-}
{-# LANGUAGE DerivingStrategies         #-}
{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE NoImplicitPrelude          #-}
{-# LANGUAGE OverloadedStrings          #-}
{-# LANGUAGE RecordWildCards            #-}
{-# LANGUAGE TemplateHaskell            #-}
{-# LANGUAGE TypeFamilies               #-}
{-# LANGUAGE TypeOperators              #-}
{-# LANGUAGE TypeApplications           #-}
{-# LANGUAGE ScopedTypeVariables        #-}
{-# options_ghc -Wno-redundant-constraints #-}
{-# options_ghc -fno-strictness            #-}
{-# options_ghc -fno-specialise            #-}

module Proxy.Contract.Models where

import qualified PlutusTx.Builtins   as Builtins
import           Playground.Contract (FromJSON, Generic, ToJSON, ToSchema)
import qualified PlutusTx
import           PlutusTx.Prelude
import qualified Prelude             as Haskell
import           Ledger

data ProxyAction = Swap | Deposit | Redeem
    deriving (Haskell.Show, Generic, ToJSON, FromJSON, ToSchema)

PlutusTx.unstableMakeIsData ''ProxyAction

--todo: rate :: Integer -> rate :: Double ?
--todo: remove ergoToken and adaToken from proxy datum ?
data ProxyDatum = ProxyDatum {
    action :: ProxyAction,
    slippageTolerance :: Integer,
    rate :: Integer,
    dexFeeDatum :: Integer,
    userPubKeyHash :: Builtins.ByteString,
    -- rename? In case of deposit we are going to get lpToken. See processor Dex.Processor.produceDepositOpData
    xProxyToken :: AssetClass,
    -- determine the hash of second coin
    yProxyToken :: AssetClass,
    targetPoolId :: Builtins.ByteString,
    lpProxyToken :: AssetClass
} deriving (Haskell.Show, Generic, ToJSON, FromJSON, ToSchema)

PlutusTx.unstableMakeIsData ''ProxyDatum