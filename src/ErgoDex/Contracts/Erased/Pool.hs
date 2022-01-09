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

module ErgoDex.Contracts.Erased.Pool where

import qualified Prelude                          as Haskell
import           Ledger
import           Ledger.Value                     (flattenValue, assetClassValueOf)
import           Playground.Contract              (FromJSON, Generic, ToJSON, ToSchema)
import           ErgoDex.Contracts.Erased.Coins
import qualified PlutusTx
import           PlutusTx.Prelude
import           PlutusTx.IsData.Class
import           PlutusTx.Sqrt

data PoolDatum = PoolDatum
  { poolNft :: AssetClass
  , poolX   :: AssetClass
  , poolY   :: AssetClass
  , poolLq  :: AssetClass
  , feeNum  :: Integer
  } deriving (Haskell.Show, Generic, ToJSON, FromJSON, ToSchema)
PlutusTx.makeIsDataIndexed ''PoolDatum [('PoolDatum, 0)]
PlutusTx.makeLift ''PoolDatum

instance Eq PoolDatum where
  {-# INLINABLE (==) #-}
  x == y = poolNft x == poolNft y &&
           poolX x   == poolX y &&
           poolY x   == poolY y &&
           poolLq x  == poolLq y &&
           feeNum x  == feeNum y

data PoolAction = Init | Deposit | Redeem | Swap
  deriving Haskell.Show
PlutusTx.makeIsDataIndexed ''PoolAction [ ('Init ,   0)
                                        , ('Deposit, 1)
                                        , ('Redeem,  2)
                                        , ('Swap,    3)
                                        ]
PlutusTx.makeLift ''PoolAction

data PoolState = PoolState
  { reservesX :: Integer
  , reservesY :: Integer
  , liquidity :: Integer
  } deriving Haskell.Show

{-# INLINABLE maxLqCap #-}
maxLqCap :: Integer
maxLqCap = 0x7fffffffffffffff

{-# INLINABLE readPoolState #-}
readPoolState :: PoolDatum -> TxOut -> PoolState
readPoolState PoolDatum{..} out =
    PoolState x y lq
  where
    value = txOutValue out
    x     = assetClassValueOf value poolX
    y     = assetClassValueOf value poolY
    lq    = maxLqCap - assetClassValueOf value poolLq

data PoolDiff = PoolDiff
  { diffX         :: Integer
  , diffY         :: Integer
  , diffLiquidity :: Integer
  }

{-# INLINABLE diffPoolState #-}
diffPoolState :: PoolState -> PoolState -> PoolDiff
diffPoolState s0 s1 =
    PoolDiff dx dy dlq
  where
    rx0 = reservesX s0
    rx1 = reservesX s1
    ry0 = reservesY s0
    ry1 = reservesY s1
    lq0 = liquidity s0
    lq1 = liquidity s1
    dx  = rx1 - rx0
    dy  = ry1 - ry0
    dlq = lq0 - lq1 -- pool keeps only the negative part of LQ tokens

{-# INLINABLE getPoolOutput #-}
getPoolOutput :: ScriptContext -> TxOut
getPoolOutput ScriptContext{scriptContextTxInfo=TxInfo{txInfoOutputs}} =
  head txInfoOutputs -- pool box is always 1st output

{-# INLINABLE getPoolInput #-}
getPoolInput :: ScriptContext -> TxOut
getPoolInput ScriptContext{scriptContextTxInfo=TxInfo{txInfoInputs}} =
  txInInfoResolved $ head txInfoInputs -- pool box is always 1st input

{-# INLINABLE findPoolDatum #-}
findPoolDatum :: TxInfo -> DatumHash -> PoolDatum
findPoolDatum info h = case findDatum h info of
  Just (Datum d) -> case fromBuiltinData d of
    (Just ps) -> ps
    _         -> traceError "error decoding pool data"
  _              -> traceError "pool input datum not found"

{-# INLINABLE validInit #-}
validInit :: PoolState -> PoolDiff -> Bool
validInit PoolState{..} PoolDiff{..} =
    traceIfFalse "Illegal initial pool state" validInitialState &&
    traceIfFalse "Illegal amount of liquidity forged" (diffLiquidity' <= liquidityUnlocked)
  where
    diffLiquidity' = diffLiquidity
    diffX'         = diffX
    diffY'         = diffY
    liquidity'     = liquidity
    reservesX'     = reservesX
    reservesY'     = reservesY

    validInitialState =
      liquidity' == 0 &&
      reservesX' == 0 &&
      reservesY' == 0

    liquidityUnlocked = case isqrt (diffX' * diffY') of
      Exactly l | l > 0       -> l
      Approximately l | l > 0 -> l + 1
      _                       -> traceError "insufficient liquidity"

{-# INLINABLE validDeposit #-}
validDeposit :: PoolState -> PoolDiff -> Bool
validDeposit PoolState{..} PoolDiff{..} =
    traceIfFalse "Illegal amount of liquidity forged" (diffLiquidity' <= liquidityUnlocked)
  where
    diffLiquidity' = diffLiquidity
    diffX'         = diffX
    diffY'         = diffY
    liquidity'     = liquidity
    reservesX'     = reservesX
    reservesY'     = reservesY

    liquidityUnlocked = min (divide (diffX' * liquidity') reservesX') (divide (diffY' * liquidity') reservesY')

{-# INLINABLE validRedeem #-}
validRedeem :: PoolState -> PoolDiff -> Bool
validRedeem PoolState{..} PoolDiff{..} =
    traceIfFalse "Illegal redeem" fairRedeem
  where
    diffLiquidity' = diffLiquidity
    diffX'         = diffX
    diffY'         = diffY
    liquidity'     = liquidity
    reservesX'     = reservesX
    reservesY'     = reservesY

    fairRedeem =
      diffX' * liquidity' >= diffLiquidity' * reservesX' && diffY' * liquidity' >= diffLiquidity' * reservesY'

{-# INLINABLE validSwap #-}
validSwap :: PoolDatum -> PoolState -> PoolDiff -> Bool
validSwap PoolDatum{..} PoolState{..} PoolDiff{..} =
    traceIfFalse "Illegal swap" fairSwap &&
    traceIfFalse "Liquidity emission must not change" (diffLiquidity == 0)
  where
    reservesX0     = reservesX
    reservesY0     = reservesY
    deltaReservesX = diffX
    deltaReservesY = diffY
    feeDen         = 1000

    fairSwap =
      if deltaReservesX > 0 then
        reservesY0 * deltaReservesX * feeNum >= negate deltaReservesY * (reservesX0 * feeDen + deltaReservesX * feeNum)
      else
        reservesX0 * deltaReservesY * feeNum >= negate deltaReservesX * (reservesY0 * feeDen + deltaReservesY * feeNum)

{-# INLINABLE mkPoolValidator #-}
mkPoolValidator :: PoolDatum -> PoolAction -> ScriptContext -> Bool
mkPoolValidator ps0@PoolDatum{..} action ctx =
    traceIfFalse "Pool NFT not preserved" poolNftPreserved &&
    traceIfFalse "Pool settings not preserved" poolSettingsPreserved &&
    traceIfFalse "Assets qty not preserved" strictAssets &&
    traceIfFalse "Script not preserved" scriptPreserved &&
    traceIfFalse "Invalid action" validAction
  where
    self      = getPoolInput ctx
    successor = getPoolOutput ctx

    poolNftPreserved = isUnit (txOutValue successor) poolNft

    selfDh = case txOutDatum self of
      Nothing -> traceError "pool input datum hash not found"
      Just h  -> h

    successorDh = case txOutDatum successor of
      Nothing -> traceError "pool output datum hash not found"
      Just h  -> h

    poolSettingsPreserved = successorDh == selfDh

    s0   = readPoolState ps0 self
    s1   = readPoolState ps0 successor
    diff = diffPoolState s0 s1

    strictAssets = numAssets == 3 || numAssets == 4
      where numAssets = length $ flattenValue (txOutValue successor)

    scriptPreserved = txOutAddress successor == txOutAddress self

    validAction = case action of
      Init    -> validInit s0 diff
      Deposit -> validDeposit s0 diff
      Redeem  -> validRedeem s0 diff
      Swap    -> validSwap ps0 s0 diff
