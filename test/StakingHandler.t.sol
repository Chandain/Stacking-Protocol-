// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Staking} from "../src/Staking.sol";


contract StakingHandler is Test {
    Staking public staking;

    address public user = makeAddr("user");


    constructor(Staking _staking) {
        staking = _staking;
    }

    function stake(uint256 amount) external {

        uint256 _amount = bound(amount, 1, 100);
        // 1. bound amount ke range valid
        // 2. siapkan ETH untuk actor
        vm.deal(user, 101);
        // 3. panggil staking.stake()
        vm.prank(user);
        staking.stake{value: _amount}(_amount);
    }

    function warp(uint256 _elapsed) external {
        uint256 elapsed = bound(_elapsed, 1, 30 days); 

        vm.warp(block.timestamp + elapsed);
    }

    function claim() external {
        console.log("balanceBefore", address(staking).balance);
        console.log("totalStakeBefore", staking.totalStake());
        console.log("reeward", staking.earned(user));
        vm.prank(user);
        staking.claimReward();
        console.log("balanceAfter", address(staking).balance);
        console.log("totalStake after", staking.totalStake());
    }
}