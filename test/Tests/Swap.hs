module Tests.Swap where

import qualified ErgoDex.PContracts.PPool as PPool
import qualified ErgoDex.PContracts.PSwap as PSwap
import ErgoDex.PValidators

import Eval
import Gen.Utils

import Plutus.V1.Ledger.Api

import Hedgehog

import Test.Tasty
import Test.Tasty.HUnit
import Test.Tasty.Hedgehog as HH

import Gen.Models
import Gen.DepositGen
import Gen.PoolGen
import Gen.SwapGen

checkSwap = testGroup "CheckSwap"
  [ HH.testProperty "correct_swap" successSwap
  , HH.testProperty "correct_swap_x_is_ada" successSwapWithXIsAda
  , HH.testProperty "swap_invalid_ex_fee" invalidExFee
  , HH.testProperty "swap_invalid_fair_price" invalidFairPrice
  ]

checkSwapRedeemer = testGroup "SwapRedeemer"
  [ HH.testProperty "fail_if_poolInIx_is_incorrect" swapIncorrectPoolInIx
  , HH.testProperty "fail_if_orderInIx_is_incorrect" swapIncorrectOrderInIx
  , HH.testProperty "fail_if_rewardOutIx_is_incorrect" swapIncorrectRewardOutIx
  ]

checkSwapIdentity = testGroup "CheckSwapIdentity"
  [ HH.testProperty "fail_if_selfIdentity_is_incorrect" swapSelfIdentity
  , HH.testProperty "fail_if_poolIdentity_is_incorrect" swapPoolIdentity
  ]
  
successSwap :: Property
successSwap = property $ do
  let (x, y, nft, lq) = genAssetClasses
  pkh             <- forAll genPkh
  orderTxRef      <- forAll genTxOutRef
  let
    (cfgData, dh) = genSConfig x y nft 100 100 100 pkh 10 1
    orderTxIn     = genSTxIn orderTxRef dh x 10 5000000
    orderTxOut    = genSTxOut dh y 10 5000000 pkh
  
  poolTxRef <- forAll genTxOutRef
  let
    (pcfg, pdh) = genPConfig x y nft lq 1
    poolTxIn    = genPTxIn poolTxRef pdh x 100 y 100 lq 9223372036854775797 nft 1 5000000
    poolTxOut   = genPTxOut pdh x 110 y 90 lq 9223372036854775787 nft 1 3000000
  
  let
    txInfo  = mkTxInfo poolTxIn orderTxIn poolTxOut orderTxOut
    purpose = mkPurpose orderTxRef

    cxtToData          = toData $ mkContext txInfo purpose
    orderRedeemToData  = toData $ mkOrderRedeemer 0 1 1

    result = eraseRight $ evalWithArgs (wrapValidator PSwap.swapValidatorT) [cfgData, orderRedeemToData, cxtToData]

  result === Right ()

successSwapWithXIsAda :: Property
successSwapWithXIsAda = property $ do
  let (_, y, nft, lq) = genAssetClasses
  pkh             <- forAll genPkh
  orderTxRef      <- forAll genTxOutRef
  let
    x             = mkAdaAssetClass 
    (cfgData, dh) = genSConfig x y nft 995 1400234506794448 1000000000000000000 pkh 15000000 1428332176
    orderTxIn     = genSTxIn orderTxRef dh x 1000000000 0
    orderTxOut    = genSTxOut dh y 4739223624 1687642 pkh
  
  poolTxRef <- forAll genTxOutRef
  let
    (pcfg, pdh) = genPConfig x y nft lq 1
    poolTxIn    = genPTxIn poolTxRef pdh x 1000000000 y 100000000000 lq 9223371936849775932 nft 1 0
    poolTxOut   = genPTxOut pdh x 1050000000 y 95260776376 lq 9223372036854775787 nft 1 0 
  
  let
    txInfo  = mkTxInfo poolTxIn orderTxIn poolTxOut orderTxOut
    purpose = mkPurpose orderTxRef

    cxtToData          = toData $ mkContext txInfo purpose
    orderRedeemToData  = toData $ mkOrderRedeemer 0 1 1

    result = eraseRight $ evalWithArgs (wrapValidator PSwap.swapValidatorT) [cfgData, orderRedeemToData, cxtToData]

  result === Right ()

invalidFairPrice :: Property
invalidFairPrice = property $ do
  let (x, y, nft, lq) = genAssetClasses
  pkh             <- forAll genPkh
  orderTxRef      <- forAll genTxOutRef
  let
    (cfgData, dh) = genSConfig x y nft 1000 100 1 pkh 10 1
    orderTxIn     = genSTxIn orderTxRef dh x 10 5000000
    orderTxOut    = genSTxOut dh y 10 500000 pkh
  
  poolTxRef <- forAll genTxOutRef
  let
    (pcfg, pdh) = genPConfig x y nft lq 1
    poolTxIn    = genPTxIn poolTxRef pdh x 10 y 100 lq 9223372036854775797 nft 1 5000000
    poolTxOut   = genPTxOut pdh x 110 y 90 lq 9223372036854775787 nft 1 3000000
  
  let
    txInfo  = mkTxInfo poolTxIn orderTxIn poolTxOut orderTxOut
    purpose = mkPurpose orderTxRef

    cxtToData          = toData $ mkContext txInfo purpose
    orderRedeemToData  = toData $ mkOrderRedeemer 0 1 1

    result = eraseBoth $ evalWithArgs (wrapValidator PSwap.swapValidatorT) [cfgData, orderRedeemToData, cxtToData]

  result === Left ()

invalidExFee :: Property
invalidExFee = property $ do
  let (x, y, nft, lq) = genAssetClasses
  pkh             <- forAll genPkh
  orderTxRef      <- forAll genTxOutRef
  let
    (cfgData, dh) = genSConfig x y nft 100 100 100 pkh 10 1
    orderTxIn     = genSTxIn orderTxRef dh x 10 5000000
    orderTxOut    = genSTxOut dh y 10 500000 pkh
  
  poolTxRef <- forAll genTxOutRef
  let
    (pcfg, pdh) = genPConfig x y nft lq 1
    poolTxIn    = genPTxIn poolTxRef pdh x 100 y 100 lq 9223372036854775797 nft 1 5000000
    poolTxOut   = genPTxOut pdh x 110 y 90 lq 9223372036854775787 nft 1 3000000
  
  let
    txInfo  = mkTxInfo poolTxIn orderTxIn poolTxOut orderTxOut
    purpose = mkPurpose orderTxRef

    cxtToData          = toData $ mkContext txInfo purpose
    orderRedeemToData  = toData $ mkOrderRedeemer 0 1 1

    result = eraseBoth $ evalWithArgs (wrapValidator PSwap.swapValidatorT) [cfgData, orderRedeemToData, cxtToData]

  result === Left ()

swapSelfIdentity :: Property
swapSelfIdentity = property $ do
  let (x, y, nft, lq) = genAssetClasses
  pkh             <- forAll genPkh
  orderTxRef      <- forAll genTxOutRef
  let
    (cfgData, dh) = genSConfig x y nft 100 100 100 pkh 10 1
    orderTxIn     = genSTxIn orderTxRef dh x 10 5000000
    orderTxOut    = genSTxOut dh y 10 5000000 pkh
  
  poolTxRef <- forAll genTxOutRef
  let
    (pcfg, pdh) = genPConfig x y nft lq 1
    poolTxIn    = genPTxIn poolTxRef pdh x 100 y 100 lq 9223372036854775797 nft 1 5000000
    poolTxOut   = genPTxOut pdh x 110 y 90 lq 9223372036854775787 nft 1 3000000
  
  let
    txInfo  = mkTxInfo poolTxIn orderTxIn poolTxOut orderTxOut
    purpose = mkPurpose poolTxRef

    cxtToData          = toData $ mkContext txInfo purpose
    orderRedeemToData  = toData $ mkOrderRedeemer 0 1 1

    result = eraseBoth $ evalWithArgs (wrapValidator PSwap.swapValidatorT) [cfgData, orderRedeemToData, cxtToData]

  result === Left ()

swapPoolIdentity :: Property
swapPoolIdentity = property $ do
  let (x, y, nft, lq) = genAssetClasses
  pkh             <- forAll genPkh
  orderTxRef      <- forAll genTxOutRef
  let
    (cfgData, dh) = genSConfig x y nft 100 100 100 pkh 10 1
    orderTxIn     = genSTxIn orderTxRef dh x 10 5000000
    orderTxOut    = genSTxOut dh y 10 5000000 pkh
  
  poolTxRef <- forAll genTxOutRef
  let
    (pcfg, pdh) = genPConfig x y nft lq 1
    poolTxIn    = genPTxIn poolTxRef pdh x 100 y 100 lq 9223372036854775797 nft 2 5000000
    poolTxOut   = genPTxOut pdh x 110 y 90 lq 9223372036854775787 nft 1 3000000
  
  let
    txInfo  = mkTxInfo poolTxIn orderTxIn poolTxOut orderTxOut
    purpose = mkPurpose orderTxRef

    cxtToData          = toData $ mkContext txInfo purpose
    orderRedeemToData  = toData $ mkOrderRedeemer 0 1 1

    result = eraseBoth $ evalWithArgs (wrapValidator PSwap.swapValidatorT) [cfgData, orderRedeemToData, cxtToData]

  result === Left ()

swapIncorrectPoolInIx :: Property
swapIncorrectPoolInIx = property $ do
  let (x, y, nft, lq) = genAssetClasses
  pkh             <- forAll genPkh
  orderTxRef      <- forAll genTxOutRef
  let
    (cfgData, dh) = genSConfig x y nft 100 100 100 pkh 10 1
    orderTxIn     = genSTxIn orderTxRef dh x 10 5000000
    orderTxOut    = genSTxOut dh y 10 5000000 pkh
  
  poolTxRef <- forAll genTxOutRef
  let
    (pcfg, pdh) = genPConfig x y nft lq 1
    poolTxIn    = genPTxIn poolTxRef pdh x 100 y 100 lq 9223372036854775797 nft 1 5000000
    poolTxOut   = genPTxOut pdh x 110 y 90 lq 9223372036854775787 nft 1 3000000
  
  let
    txInfo  = mkTxInfo poolTxIn orderTxIn poolTxOut orderTxOut
    purpose = mkPurpose orderTxRef

    cxtToData          = toData $ mkContext txInfo purpose
    orderRedeemToData  = toData $ mkOrderRedeemer 1 1 1

    result = eraseBoth $ evalWithArgs (wrapValidator PSwap.swapValidatorT) [cfgData, orderRedeemToData, cxtToData]

  result === Left ()

swapIncorrectOrderInIx :: Property
swapIncorrectOrderInIx = property $ do
  let (x, y, nft, lq) = genAssetClasses
  pkh             <- forAll genPkh
  orderTxRef      <- forAll genTxOutRef
  let
    (cfgData, dh) = genSConfig x y nft 100 100 100 pkh 10 1
    orderTxIn     = genSTxIn orderTxRef dh x 10 5000000
    orderTxOut    = genSTxOut dh y 10 5000000 pkh
  
  poolTxRef <- forAll genTxOutRef
  let
    (pcfg, pdh) = genPConfig x y nft lq 1
    poolTxIn    = genPTxIn poolTxRef pdh x 100 y 100 lq 9223372036854775797 nft 1 5000000
    poolTxOut   = genPTxOut pdh x 110 y 90 lq 9223372036854775787 nft 1 3000000
  
  let
    txInfo  = mkTxInfo poolTxIn orderTxIn poolTxOut orderTxOut
    purpose = mkPurpose orderTxRef

    cxtToData          = toData $ mkContext txInfo purpose
    orderRedeemToData  = toData $ mkOrderRedeemer 0 0 1

    result = eraseBoth $ evalWithArgs (wrapValidator PSwap.swapValidatorT) [cfgData, orderRedeemToData, cxtToData]

  result === Left ()

swapIncorrectRewardOutIx :: Property
swapIncorrectRewardOutIx = property $ do
  let (x, y, nft, lq) = genAssetClasses
  pkh             <- forAll genPkh
  orderTxRef      <- forAll genTxOutRef
  let
    (cfgData, dh) = genSConfig x y nft 100 100 100 pkh 10 1
    orderTxIn     = genSTxIn orderTxRef dh x 10 5000000
    orderTxOut    = genSTxOut dh y 10 5000000 pkh
  
  poolTxRef <- forAll genTxOutRef
  let
    (pcfg, pdh) = genPConfig x y nft lq 1
    poolTxIn    = genPTxIn poolTxRef pdh x 100 y 100 lq 9223372036854775797 nft 1 5000000
    poolTxOut   = genPTxOut pdh x 110 y 90 lq 9223372036854775787 nft 1 3000000
  
  let
    txInfo  = mkTxInfo poolTxIn orderTxIn poolTxOut orderTxOut
    purpose = mkPurpose orderTxRef

    cxtToData          = toData $ mkContext txInfo purpose
    orderRedeemToData  = toData $ mkOrderRedeemer 0 1 0

    result = eraseBoth $ evalWithArgs (wrapValidator PSwap.swapValidatorT) [cfgData, orderRedeemToData, cxtToData]

  result === Left ()