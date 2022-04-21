module ErgoDex.PContracts.PAssets
  ( poolNftMintValidatorT
  , poolLqMintValidatorT
  ) where

import Plutarch
import Plutarch.Prelude
import Plutarch.Api.V1
import PExtra.Monadic
import PExtra.List (pexists)
import PExtra.API (assetClass, assetClassValueOf)
import ErgoDex.PContracts.PApi (tletUnwrap, ownCurrencySymbol)

poolNftMintValidatorT :: Term s PTxOutRef -> Term s PTokenName -> Term s (PData :--> PScriptContext :--> PBool)
poolNftMintValidatorT oref tn = plam $ \_ ctx -> unTermCont $ do
  txinfo' <- tletField @"txInfo" ctx
  txinfo  <- tcont $ pletFields @'["inputs", "mint"] txinfo'
  let
    targetUtxoConsumed =
      let
        isTarget i = unTermCont $ do
          oref' <- tletField @"outRef" i
          pure $ oref' #== oref
      in pexists # plam (isTarget . pfromData) # pfromData (hrecField @"inputs" txinfo)
    tokenMintExact = unTermCont $ do
      valueMint <- tletUnwrap $ hrecField @"mint" txinfo
      let ownAc = assetClass # (ownCurrencySymbol # ctx) # tn
      pure $ assetClassValueOf # valueMint # ownAc #== 1
  pure $ targetUtxoConsumed #&& tokenMintExact

poolLqMintValidatorT :: Term s PTxOutRef -> Term s PTokenName -> Term s PInteger -> Term s (PData :--> PScriptContext :--> PBool)
poolLqMintValidatorT oref tn emission = plam $ \_ ctx -> unTermCont $ do
  txinfo' <- tletField @"txInfo" ctx
  txinfo  <- tcont $ pletFields @'["inputs", "mint"] txinfo'
  let
    targetUtxoConsumed =
      let
        isTarget i = unTermCont $ do
          oref' <- tletField @"outRef" i
          pure $ oref' #== oref
      in pexists # plam (isTarget . pfromData) # pfromData (hrecField @"inputs" txinfo)
    tokenMintExact = unTermCont $ do
      valueMint <- tletUnwrap $ hrecField @"mint" txinfo
      let ownAc = assetClass # (ownCurrencySymbol # ctx) # tn
      pure $ assetClassValueOf # valueMint # ownAc #== emission
  pure $ targetUtxoConsumed #&& tokenMintExact
