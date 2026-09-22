// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Staking} from "../src/Staking.sol";

contract StakingFuzzTest is Test {
    Staking public staking;

    address user = makeAddr("user");

    function setUp() public {
        staking = new Staking(1 days, 1);
        vm.deal(user, 1000);
        vm.deal(address(staking), 10000);
    }

    function testFuzz_PartialUnstake(
        uint96 _stakeAmount,
        uint96 _unstakeAmount
    ) public {
        vm.startPrank(user);
        uint256 stakeAmount = bound(_stakeAmount, 1, 100);

        staking.stake{value: stakeAmount}(stakeAmount);

        uint256 unstakeAmount = bound(_unstakeAmount, 1, stakeAmount);
        staking.unstake(unstakeAmount);

        (uint256 userStake, ,) = staking.getInfo(user); 

        vm.stopPrank();

        assertEq(userStake, stakeAmount - unstakeAmount);
    }

    function testFuzz_RewardCheckPoint(
        uint96 _stakeAmount,
        uint96 _unstakeAmount,
        uint256 _elapsed
    ) public {
        vm.startPrank(user);

        uint256 stakeAmount = bound(_stakeAmount, 1, 100);
        staking.stake{value: stakeAmount}(stakeAmount);

        uint256 elapsed = bound(_elapsed, 1, 30 days);
        vm.warp(block.timestamp + elapsed);

        uint256 rewardAmount = staking.earned(user);

        uint256 unstakeAmount = bound(_unstakeAmount, 1, stakeAmount);
        staking.unstake(unstakeAmount);

        (uint256 userStake, uint256 userReward ,) = staking.getInfo(user); 

        vm.stopPrank();

        assertEq(userStake, stakeAmount - unstakeAmount);
        assertEq(rewardAmount, userReward);
    }

    function testFuzz_UnstakeZero(uint256 _amount) public {
        vm.startPrank(user);

        uint256 amount = bound(_amount, 1, 100);

        staking.stake{value: amount}(amount);

        vm.warp(block.timestamp + 1 days);

        vm.expectRevert(bytes("IA"));
        staking.unstake(0);

        vm.stopPrank();
    }

    function testFuzz_UnstakeStakeAmount(uint256 _amount) public {
        vm.startPrank(user);

        uint256 amount = bound(_amount, 1, 100);

        staking.stake{value: amount}(amount);

        (uint256 amountStakedBefore, ,) = staking.getInfo(user);

        vm.warp(block.timestamp + 1 days);

        staking.unstake(amount);

        (uint256 amountStakedAfter, ,) = staking.getInfo(user);

        uint256 amountUnstake = amountStakedBefore - amountStakedAfter;

        assertEq(amountUnstake, amount);
        console.log(amountUnstake, amount);

        vm.stopPrank();
    }

    function testFuzz_UnstakeMoreThanStakeAMount(uint256 amount) public {
        vm.startPrank(user);
        
        uint256 amountStake = bound(amount, 1, 100);
        staking.stake{value: amountStake}(amountStake);

        vm.warp(block.timestamp + 3 days);

        uint256 amountUnstake = bound(amount, amountStake + 1, 1000);

        vm.expectRevert(bytes("IB"));
        staking.unstake(amountUnstake);

        vm.stopPrank();
    }

}