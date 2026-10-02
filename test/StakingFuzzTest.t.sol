// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Staking} from "../src/Staking.sol";

contract StakingFuzzTest is Test {
    Staking public staking;

    address userA = makeAddr("userA");
    address userB = makeAddr("userB");

    function setUp() public {
        staking = new Staking(1 days, 1);
        vm.deal(userA, 1000);
        vm.deal(userB, 1000);
        vm.deal(address(staking), 10000);
    }

    function warp(uint256 time) public {
        vm.warp(block.timestamp + time);
    }

    function testFuzz_PartialClaimWithBalanceLessThenLiability(uint256 _stakeAmount, uint256 _fundingSeed) public {
        vm.deal(address(staking), 0);
        uint256 stakeAmountA = bound(_stakeAmount, 20, 100);
        uint256 stakeAmountB = bound(_stakeAmount, 20, 200);

        vm.prank(userA);
        staking.stake{value: stakeAmountA}(stakeAmountA);

        vm.prank(userB);
        staking.stake{value: stakeAmountB}(stakeAmountB);

        warp(1 days);
        uint256 rewardUserA = staking.earned(userA);
        uint256 initialFunding = bound(_fundingSeed, 1, rewardUserA - 1);
        vm.deal(address(staking), address(staking).balance + initialFunding);
        console.log("contract balance: ", address(staking).balance);

        vm.startPrank(userA);
        staking.claimReward();

        staking.unstake(stakeAmountA);
        (uint256 amountStakedAfter,,) = staking.getInfo(userA);

        uint256 remainingDebt = rewardUserA - initialFunding;
        uint256 funding2 = bound(_fundingSeed, 1, remainingDebt);
        vm.deal(address(staking), address(staking).balance + funding2);
        staking.claimReward();

        uint256 funding3 = remainingDebt - funding2;
        vm.deal(address(staking), address(staking).balance + funding3);
        if (funding3 == 0) {
            vm.expectRevert(bytes("IB"));
        }
        staking.claimReward();

        vm.stopPrank();

        assertEq(initialFunding + funding2 + funding3, rewardUserA);
        assertEq(amountStakedAfter, 0);
        assertGe(address(staking).balance, staking.totalPrincipal());
    }

    function testFuzz_PartialUnstake(uint96 _stakeAmount, uint96 _unstakeAmount) public {
        vm.startPrank(userA);
        uint256 stakeAmount = bound(_stakeAmount, 1, 100);

        staking.stake{value: stakeAmount}(stakeAmount);

        uint256 unstakeAmount = bound(_unstakeAmount, 1, stakeAmount);
        staking.unstake(unstakeAmount);

        (uint256 userAStake,,) = staking.getInfo(userA);

        vm.stopPrank();

        assertEq(userAStake, stakeAmount - unstakeAmount);
    }

    function testFuzz_ClaimNotDecreasePrincipal(uint256 _elapsed, uint256 _stakeAmount) public {
        vm.startPrank(userA);
        uint256 stakeAmount = bound(_stakeAmount, 100, 1000);
        staking.stake{value: stakeAmount}(stakeAmount);

        uint256 elapsed = bound(_elapsed, 1, 30 days);
        vm.warp(block.timestamp + elapsed);

        (, uint256 rewardStored,) = staking.getInfo(userA);
        uint256 owed = staking.earned(userA) + rewardStored;

        if (owed == 0) {
            vm.expectRevert(bytes("IB"));
        }
        staking.claimReward();
        vm.stopPrank();

        assertGe(address(staking).balance, staking.totalPrincipal());
    }

    function testFuzz_RewardCheckPoint(uint96 _stakeAmount, uint96 _unstakeAmount, uint256 _elapsed) public {
        vm.startPrank(userA);

        uint256 stakeAmount = bound(_stakeAmount, 1, 100);
        staking.stake{value: stakeAmount}(stakeAmount);

        uint256 elapsed = bound(_elapsed, 1, 30 days);
        vm.warp(block.timestamp + elapsed);

        uint256 rewardAmount = staking.earned(userA);

        uint256 unstakeAmount = bound(_unstakeAmount, 1, stakeAmount);
        staking.unstake(unstakeAmount);

        (uint256 userAStake, uint256 userAReward,) = staking.getInfo(userA);

        vm.stopPrank();

        assertEq(userAStake, stakeAmount - unstakeAmount);
        assertEq(rewardAmount, userAReward);
    }

    function testFuzz_UnstakeZero(uint256 _amount) public {
        vm.startPrank(userA);

        uint256 amount = bound(_amount, 1, 100);

        staking.stake{value: amount}(amount);

        vm.warp(block.timestamp + 1 days);

        vm.expectRevert(bytes("IA"));
        staking.unstake(0);

        vm.stopPrank();
    }

    function testFuzz_UnstakeStakeAmount(uint256 _amount) public {
        vm.startPrank(userA);

        uint256 amount = bound(_amount, 1, 100);

        staking.stake{value: amount}(amount);

        (uint256 amountStakedBefore,,) = staking.getInfo(userA);

        vm.warp(block.timestamp + 1 days);

        staking.unstake(amount);

        (uint256 amountStakedAfter,,) = staking.getInfo(userA);

        uint256 amountUnstake = amountStakedBefore - amountStakedAfter;

        assertEq(amountUnstake, amount);
        console.log(amountUnstake, amount);

        vm.stopPrank();
    }

    function testFuzz_UnstakeMoreThanStakeAMount(uint256 amount) public {
        vm.startPrank(userA);

        uint256 amountStake = bound(amount, 1, 100);
        staking.stake{value: amountStake}(amountStake);

        vm.warp(block.timestamp + 3 days);

        uint256 amountUnstake = bound(amount, amountStake + 1, 1000);

        vm.expectRevert(bytes("IB"));
        staking.unstake(amountUnstake);

        vm.stopPrank();
    }
}
