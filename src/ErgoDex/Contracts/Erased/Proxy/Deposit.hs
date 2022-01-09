{-# LANGUAGE AllowAmbiguousTypes        #-}
{-# LANGUAGE DataKinds                  #-}
{-# LANGUAGE EmptyDataDecls             #-}
{-# LANGUAGE DeriveAnyClass             #-}
{-# LANGUAGE DeriveGeneric              #-}
{-# LANGUAGE DerivingStrategies         #-}
{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE OverloadedStrings          #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE KindSignatures             #-}
{-# LANGUAGE MonoLocalBinds             #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE NoImplicitPrelude          #-}
{-# LANGUAGE PartialTypeSignatures      #-}
{-# LANGUAGE RecordWildCards            #-}
{-# LANGUAGE ScopedTypeVariables        #-}
{-# LANGUAGE TemplateHaskell            #-}
{-# LANGUAGE TypeApplications           #-}
{-# LANGUAGE TypeFamilies               #-}
{-# LANGUAGE TypeOperators              #-}
{-# LANGUAGE TypeSynonymInstances       #-}
{-# LANGUAGE ViewPatterns               #-}
{-# LANGUAGE NamedFieldPuns             #-}
{-# OPTIONS_GHC -Wno-simplifiable-class-constraints #-}
{-# OPTIONS_GHC -fno-strictness #-}
{-# OPTIONS_GHC -fno-specialise #-}
{-# OPTIONS_GHC -fno-omit-interface-pragmas #-}

module ErgoDex.Contracts.Erased.Proxy.Deposit where

import qualified Prelude                          as Haskell

import           Ledger
import           Ledger.Value (assetClassValueOf)
import qualified Ledger.Ada   as Ada

import           ErgoDex.Contracts.Erased.Coins
import           ErgoDex.Contracts.Proxy.Order
import           ErgoDex.Contracts.Erased.Pool   (PoolState(..), PoolDatum(..), readPoolState, getPoolInput, findPoolDatum)
import qualified PlutusTx
import           PlutusTx.Prelude

data DepositDatum = DepositDatum
   { poolNft       :: AssetClass
   , exFee         :: Integer
   , rewardPkh     :: PubKeyHash
   , collateralAda :: Integer
   } deriving stock (Haskell.Show)
PlutusTx.makeIsDataIndexed ''DepositDatum [('DepositDatum, 0)]
PlutusTx.makeLift ''DepositDatum

{-# INLINABLE mkDepositValidator #-}
mkDepositValidator :: DepositDatum -> BuiltinData -> ScriptContext -> Bool
mkDepositValidator DepositDatum{..} _ ctx =
    txSignedBy txInfo rewardPkh || (
      traceIfFalse "Invalid pool" validPool &&
      traceIfFalse "Invalid number of inputs" validNumInputs &&
      traceIfFalse "Invalid reward proposition" validRewardProp &&
      traceIfFalse "Unfair execution fee taken" fairFee &&
      traceIfFalse "Minimal reward not met" validReward
    )
  where
    txInfo = scriptContextTxInfo ctx
    self   = getOrderInput ctx
    pool   = getPoolInput ctx
    reward = getOrderRewardOutput ctx

    poolValue = txOutValue pool

    validPool = isUnit poolValue poolNft

    validNumInputs = length (txInfoInputs txInfo) == 2

    validRewardProp = maybe False (== rewardPkh) (pubKeyOutput reward)

    selfValue   = txOutValue self
    rewardValue = txOutValue reward

    ps@PoolDatum{..} = case txOutDatum pool of
      Nothing -> traceError "pool input datum hash not found"
      Just h  -> findPoolDatum txInfo h

    (inX, inY)
      | isAda poolX =
        let depositedAda = rx - exFee - collateralAda
        in (depositedAda, ry)
      | isAda poolY =
        let depositedAda = ry - exFee - collateralAda
        in (rx, depositedAda)
      | otherwise   = (rx, ry)
      where
          rx     = assetClassValueOf selfValue poolX
          ry     = assetClassValueOf selfValue poolY

    fairFee = outAda >= collateralAda
      where outAda = Ada.getLovelace $ Ada.fromValue rewardValue

    outLq = assetClassValueOf rewardValue poolLq

    poolState = readPoolState ps pool

    liquidity' = liquidity poolState
    reservesX' = reservesX poolState
    reservesY' = reservesY poolState

    minReward = min (divide (inX * liquidity') reservesX') (divide (inY * liquidity') reservesY')

    validReward = outLq >= minReward
