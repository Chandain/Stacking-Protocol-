// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Staking} from "../src/Staking.sol";

contract StakingFuzzTest is Test {
    Staking public staking;

    address userA = makeAddr("userA");
    address userB = makeAddr("userB");
    address funders = makeAddr("funders");

    function setUp() public {
        staking = new Staking(1 days, 1);
        vm.deal(userA, 1000);
        vm.deal(userB, 1000);
        vm.deal(funders, 1000);
        vm.deal(address(staking), 10000);
    }

    function warp(uint256 time) public {
        vm.warp(block.timestamp + time);
    }

    function transferFund(uint256 amount) public {
        vm.prank(funders);
        (bool success,) = address(staking).call{value: amount}("");
        require(success, "Transfer failed");
    }

    function testFuzz_PartialClaimWithBalanceLessThenLiability(uint256 _stakeAmount, uint256 _fundingSeed) public {
        vm.deal(address(staking), 0);
        uint256 balanceBeforeUserA = userA.balance;
        uint256 stakeAmountA = bound(_stakeAmount, 20, 100);

        vm.prank(userA);
        staking.stake{value: stakeAmountA}(stakeAmountA);

        {
            uint256 stakeAmountB = bound(_stakeAmount, 20, 200);
            vm.prank(userB);
            staking.stake{value: stakeAmountB}(stakeAmountB);
        }

        warp(1 days);
        uint256 rewardUserA = stakeAmountA;
        uint256 initialFunding = bound(_fundingSeed, 1, rewardUserA - 1);
        transferFund(initialFunding);

        {
            uint256 balanceBeforeClaim = userA.balance;
            vm.prank(userA);
            staking.claimReward();

            (, uint256 rewardStored,) = staking.getInfo(userA);
            uint256 paid = userA.balance - balanceBeforeClaim;
            assertEq(paid, initialFunding);
            assertEq(paid + rewardStored, rewardUserA);
            assertGe(address(staking).balance, staking.totalPrincipal());
        }

        vm.prank(userA);
        staking.unstake(stakeAmountA);
        {
            (uint256 amountStakedAfter,,) = staking.getInfo(userA);
            assertEq(amountStakedAfter, 0);
        }

        uint256 remainingDebt = rewardUserA - initialFunding;
        uint256 funding2 = bound(_fundingSeed, 1, remainingDebt);
        transferFund(funding2);

        {
            uint256 balanceBeforeClaim = userA.balance;
            vm.prank(userA);
            staking.claimReward();

            (, uint256 rewardStored,) = staking.getInfo(userA);
            uint256 paid = userA.balance - balanceBeforeClaim;
            assertEq(paid, funding2);
            assertEq(paid + rewardStored, remainingDebt);
            assertGe(address(staking).balance, staking.totalPrincipal());
        }

        uint256 funding3 = remainingDebt - funding2;
        transferFund(funding3);
        {
            uint256 balanceBeforeClaim = userA.balance;
            if (funding3 == 0) {
                vm.expectRevert(bytes("IB"));
            }
            vm.prank(userA);
            staking.claimReward();

            (, uint256 rewardStored,) = staking.getInfo(userA);
            assertEq(userA.balance - balanceBeforeClaim, funding3);
            assertEq(rewardStored, 0);
        }

        assertEq(userA.balance - balanceBeforeUserA, rewardUserA);
        assertEq(initialFunding + funding2 + funding3, rewardUserA);
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
