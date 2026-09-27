# Staking Protocol — Security Notes

1. Unfunded Reward Liability

**Description**

Reward liability increases with stake size and elapsed time, but the protocol does not guarantee sufficient funding for accrued rewards.

**Impact**

The contract may become unable to pay accrued rewards. Depending on the available balance and withdrawal logic, reward payments may also consume ETH required to repay users' principal.

**Evidence**

`test_ClaimRevertsWhenRewardExceedsAvailableAssets()` demonstrates that a reward claim fails when the reward owed exceeds the contract's available ETH balance.

The possibility of consuming principal requires a separate regression test.

**Recommendation**

Protect outstanding principal when paying rewards. Establish a sustainable reward-funding mechanism and ensure the protocol does not promise rewards beyond its intended funding capacity.

2. Withdrawal Depends on Recipient Accepting ETH

**Description**

If the recipient is a smart contract that rejects incoming ETH, `unstake()` reverts because the principal transfer fails.

**Impact**

Affected smart-contract wallets may be unable to withdraw their principal through the current withdrawal path. The failed transaction preserves the original stake and accounting state.

**Evidence**

`testStakingAmountStillSameAfterUnstake()` confirms that a rejected ETH transfer causes `unstake(40)` to revert with `TF`, leaving both the user's stake and `totalStake` unchanged at `100`.

**Recommendation**

Consider an alternative withdrawal recipient through a function such as `unstakeTo(amount, recipient)`. Only the position owner should be authorized to initiate withdrawal. Apply CEI and appropriate reentrancy protection.