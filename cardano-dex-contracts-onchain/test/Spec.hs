module Main(main) where

import ErgoDex.PMintingValidators

import Tests.Deposit 
import Tests.Pool 
import Tests.Swap
import Tests.Redeem
import Tests.Staking
import Tests.StakeMinting 

import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main = do
  defaultMain tests

tests = testGroup "Contracts"
  [ checkStakeChangeMintingPolicy
  , checkPool
  , checkPoolRedeemer
  , checkRedeem
  , checkRedeemIdentity
  , checkRedeemIsFair
  , checkRedeemRedeemer
  , checkDeposit 
  , checkDepositChange
  , checkDepositRedeemer
  , checkDepositIdentity
  , checkDepositLq
  , checkDepositTokenReward
  , checkSwap
  , checkSwapRedeemer
  , checkSwapIdentity
  , checkPkhLockStaking
  ]