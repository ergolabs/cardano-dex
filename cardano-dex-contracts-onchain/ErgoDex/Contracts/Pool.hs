{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE UndecidableInstances #-}

module ErgoDex.Contracts.Pool (
    PoolConfig (..),
    PoolRedeemer (..),
    PoolAction (..),
    burnLqInitial,
    maxLqCap
) where

import PlutusTx.Builtins
import qualified PlutusTx
import PlutusLedgerApi.V1.Value

data PoolConfig = PoolConfig
    { poolNft    :: AssetClass
    , poolX      :: AssetClass
    , poolY      :: AssetClass
    , poolLq     :: AssetClass
    , poolFeeNum :: Integer
    }
    deriving stock (Show)

PlutusTx.makeIsDataIndexed ''PoolConfig [('PoolConfig, 0)]

data PoolAction = Deposit | Redeem | Swap | Destroy
    deriving (Show)

instance PlutusTx.FromData PoolAction where
    {-# INLINE fromBuiltinData #-}
    fromBuiltinData d = matchData' d (\_ _ -> Nothing) (const Nothing) (const Nothing) chooseAction (const Nothing)
      where
        chooseAction i
            | i == 0 = Just Deposit
            | i == 1 = Just Redeem
            | i == 2 = Just Swap
            | i == 3 = Just Destroy
            | otherwise = Nothing

instance PlutusTx.UnsafeFromData PoolAction where
    {-# INLINE unsafeFromBuiltinData #-}
    unsafeFromBuiltinData = maybe (PlutusTx.Builtins.error ()) id . PlutusTx.fromBuiltinData

instance PlutusTx.ToData PoolAction where
    {-# INLINE toBuiltinData #-}
    toBuiltinData a = mkI $ case a of
        Deposit -> 0
        Redeem -> 1
        Swap -> 2
        Destroy -> 3

data PoolRedeemer = PoolRedeemer
    { action :: PoolAction
    , selfIx :: Integer
    }
    deriving (Show)

PlutusTx.makeIsDataIndexed ''PoolRedeemer [('PoolRedeemer, 0)]

{-# INLINEABLE maxLqCap #-}
maxLqCap :: Integer
maxLqCap = 0x7fffffffffffffff

{-# INLINEABLE burnLqInitial #-}
burnLqInitial :: Integer
burnLqInitial = 1000