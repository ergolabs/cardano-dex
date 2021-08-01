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


module Dex.Contract.OnChain where

import           Control.Monad          (void)
import           GHC.Generics           (Generic)
import           Ledger.Value
    ( AssetClass (..),
      symbols,
      assetClassValueOf,
      tokenName,
      currencySymbol,
      assetClass )
import           Ledger.Contexts        (ScriptContext(..))
import qualified Ledger.Constraints     as Constraints
import qualified Ledger.Typed.Scripts   as Scripts
import Plutus.Contract
    ( endpoint,
      utxoAt,
      submitTxConstraints,
      submitTxConstraintsSpending,
      collectFromScript,
      select,
      type (.\/),
      BlockchainActions,
      Endpoint,
      Contract,
      AsContractError,
      ContractError )
import           Plutus.Contract.Schema ()
import           Plutus.Trace.Emulator  (EmulatorTrace)
import qualified Plutus.Trace.Emulator  as Trace
import           PlutusTx.Builtins  (divideInteger, multiplyInteger, addInteger, subtractInteger)
import Ledger
    ( findOwnInput,
      getContinuingOutputs,
      ownHashes,
      ScriptContext(scriptContextTxInfo),
      TxInInfo(txInInfoResolved),
      TxInfo(txInfoInputs),
      DatumHash,
      Redeemer,
      TxOut(txOutDatumHash, txOutValue),
      Value)
import qualified Ledger.Ada             as Ada

import qualified PlutusTx
import           PlutusTx.Prelude
import           Schema                 (ToArgument, ToSchema)
import           Wallet.Emulator        (Wallet (..))

import Dex.Contract.Models
import Utils
    ( amountOf,
      isUnity,
      outputAmountOf,
      Amount(unAmount),
      Coin(Coin),
      CoinA,
      CoinB,
      LPToken,
      getCoinAFromPool,
      getCoinBFromPool,
      getCoinLPFromPool,
      lpSupply,
      findOwnInput',
      currentContractHash,
      valueWithin,
      calculateValueInOutputs,
      proxyDatumHash,
      ownOutput)

{-# INLINABLE checkTokenSwap #-}
checkTokenSwap :: ErgoDexPool -> ScriptContext -> Bool
checkTokenSwap ErgoDexPool{..} sCtx =
    traceIfFalse "Expected A or B coin to be present in input" checkSwaps
  where

    ownInput :: TxInInfo
    ownInput = findOwnInput' sCtx

    previousValue :: Value
    previousValue = txOutValue $ txInInfoResolved ownInput

    newValue :: Value
    newValue = txOutValue $ ownOutput sCtx

    checkCorrectnessSwap :: AssetClass -> AssetClass -> Bool
    checkCorrectnessSwap coinX coinY =
      let
        previousXValue = assetClassValueOf previousValue (coinX)
        previousYValue = assetClassValueOf previousValue (coinY)
        newXValue = assetClassValueOf newValue (coinX)
        newYValue = assetClassValueOf newValue (coinY)
        coinXToSwap = newXValue - previousXValue
        rate = newYValue `multiplyInteger` coinXToSwap `multiplyInteger` (feeNum) `divideInteger` (previousYValue `multiplyInteger` 1000 + coinXToSwap `multiplyInteger` (feeNum))
      in newYValue == (previousYValue `multiplyInteger` rate)

    checkSwaps :: Bool
    checkSwaps = checkCorrectnessSwap xCoin yCoin || checkCorrectnessSwap yCoin xCoin

{-# INLINABLE checkCorrectDepositing #-}
checkCorrectDepositing :: ErgoDexPool -> ScriptContext -> Bool
checkCorrectDepositing ErgoDexPool{..} sCtx =
  traceIfFalse "Incorrect lp token value" checkDeposit
  where

    ownInput :: TxInInfo
    ownInput = findOwnInput' sCtx

    previousValue :: Value
    previousValue = txOutValue $ txInInfoResolved ownInput

    newValue :: Value
    newValue = txOutValue $ ownOutput sCtx

    checkDeposit :: Bool
    checkDeposit =
      let
        previousXValue = assetClassValueOf previousValue (xCoin)
        previousYValue = assetClassValueOf previousValue (yCoin)
        previousLPValue = assetClassValueOf previousValue (lpCoin)
        newXValue = assetClassValueOf newValue (xCoin)
        newYValue = assetClassValueOf newValue (yCoin)
        newLPValue = assetClassValueOf newValue (lpCoin)
        coinXToDeposit = newXValue - previousXValue
        coinYToDeposit = newYValue - previousYValue
        correctLpRew = min (coinXToDeposit * lpSupply `divideInteger` previousXValue) (coinYToDeposit * lpSupply `divideInteger` previousYValue)
      in newLPValue == (previousLPValue - correctLpRew)

{-# INLINABLE checkCorrectRedemption #-}
checkCorrectRedemption :: ErgoDexPool -> ScriptContext -> Bool
checkCorrectRedemption ErgoDexPool{..} sCtx =
  traceIfFalse "Incorrect lp token value" checkRedemption
  where

    ownInput :: TxInInfo
    ownInput = findOwnInput' sCtx

    previousValue :: Value
    previousValue = txOutValue $ txInInfoResolved ownInput

    newValue :: Value
    newValue = txOutValue $ ownOutput sCtx

    checkRedemption :: Bool
    checkRedemption =
      let
        previousXValue = assetClassValueOf previousValue (xCoin)
        previousYValue = assetClassValueOf previousValue (yCoin)
        previousLPValue = assetClassValueOf previousValue (lpCoin)
        newXValue = assetClassValueOf newValue (xCoin)
        newYValue = assetClassValueOf newValue (yCoin)
        newLPValue = assetClassValueOf newValue (lpCoin)
        lpReturned = newLPValue - previousLPValue
        correctXValue = lpReturned * previousXValue `divideInteger` lpSupply
        correctYValue = lpReturned * previousYValue `divideInteger` lpSupply
      in newXValue == correctXValue && newYValue == correctYValue

{-# INLINABLE mkDexValidator #-}
mkDexValidator :: ErgoDexPool -> ContractAction -> ScriptContext -> Bool
mkDexValidator pool SwapLP sCtx    = checkCorrectRedemption pool sCtx
mkDexValidator pool AddTokens sCtx = checkCorrectDepositing pool sCtx
mkDexValidator pool SwapToken sCtx = checkTokenSwap pool sCtx
mkDexValidator _ _ _ = False