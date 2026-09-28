# Staking Protocol — Security Notes

1. Unfunded Reward Liability

**Description**

Reward liability increases with stake size and elapsed time, but the protocol does not guarantee sufficient funding for accrued rewards.

**Impact**

The contract may become unable to pay accrued rewards. Depending on the available balance and withdrawal logic, reward payments may also consume ETH required to repay users' principal.

**Evidence**

`test_ClaimRevertsWhenRewardExceedsAvailableAssets()` demonstrates that a reward claim fails when the reward owed exceeds the contract's available ETH balance.

The principal-consumption scenario is covered separately by `test_RewardPaymentCanConsumePrincipal()` in finding 3.

**Recommendation**

Protect outstanding principal when paying rewards. Establish a sustainable reward-funding mechanism and ensure the protocol does not promise rewards beyond its intended funding capacity.

2. Withdrawal Depends on Recipient Accepting ETH

**Description**

If the recipient is a smart contract that rejects incoming ETH, `unstake()` reverts because the principal transfer fails.

**Impact**

Affected smart-contract wallets may be unable to withdraw their principal through the current withdrawal path. The failed transaction preserves the original stake and accounting state.

**Evidence**

`testStakingAmountStillSameAfterUnstake()` confirms that a rejected ETH transfer causes `unstake(40)` to revert with `TF`, leaving both the user's stake and `totalPrincipal` unchanged at `100`.

**Recommendation**

Consider an alternative withdrawal recipient through a function such as `unstakeTo(amount, recipient)`. Only the position owner should be authorized to initiate withdrawal. Apply CEI and appropriate reentrancy protection.

3. Reward Payment Can Consume Principal

**Description**

Reward payments use the total contract balance without reserving the outstanding principal liability.

**Impact**

A successful claim exhausts the contract assets while the principal liability remains 100 wei. The contract cannot repay all outstanding principal from its remaining assets without additional funding. This test establishes that principal is no longer fully backed; it does not execute a withdrawal after the claim.

**Evidence**

`test_RewardPaymentCanConsumePrincipal()` stakes 100 wei into a contract initially funded with 10,000 wei, then advances time by 101 days.

| Contract assets | 10,100 | 0 |
| Principal liability | 100 | 100 |
| Accrued unpaid reward liability | 10,100 | 0 |
| User balance | 900 | 11,000 |

The test checks that the reward is positive, assets initially cover principal and the reward separately, the user receives the full reward, assets decrease by the reward paid, principal liability is unchanged, and remaining assets are below principal liability.


**Recommendation**

Use a pre-funded reward budget. Reserve rewards already allocated as user entitlements, and limit new accrual to the remaining unallocated budget. Merely funding the contract once is insufficient: funding must cover all recognized reward liabilities, and accrual must not continue without a funded budget.

Partial payment limited to assets above principal, Protects principal if the reserve is enforced, Unpaid reward debt can continue growing without funding when accrual remains unbounded, Rejected as the final solution

Pre-funded reward budget with reserved allocations and bounded accrual, Reserves principal separately from reward obligations, Every new reward entitlement consumes available unallocated funding


