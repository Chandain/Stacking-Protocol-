// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Staking} from "../src/Staking.sol";

contract StakingTest is Test {
    address user = makeAddr("user");
    Staking public staking;

    uint256 period = 1 days;

    function setUp() public {
        staking = new Staking(period, 1);
        vm.deal(user, 1000);
        vm.deal(address(staking), 10000);
    }

    function test_Stake() public {
        vm.prank(user);
        staking.stake{value: 100}(100);
    } 

    function invariant_ContractCanCoverPrincipal() public {
        assertGe(address(staking).balance, staking.totalStake());
    }   

    function testAmountUnstakeIsZero() public {
        vm.startPrank(user);

        staking.stake{value: 10}(10);

        vm.expectRevert(bytes("IA"));
        staking.unstake(0);

        vm.stopPrank();
    }

    function testUnstakeTotalStake() public {
        vm.startPrank(user);

        uint256 amountStake = 10;

        staking.stake{value: amountStake}(amountStake);

        staking.unstake(amountStake);
        vm.stopPrank();
    }

    function testUnstakeMoreThanTotalStake() public {
        vm.startPrank(user);

        uint256 amountStake = 10;

        staking.stake{value: amountStake}(amountStake);

        vm.expectRevert(bytes("IB"));
        staking.unstake(amountStake + 1);
        vm.stopPrank();
    }

    function testElapsedLessThanFullPeriod() public {
        vm.startPrank(user);

        uint256 amountStake = 10;

        staking.stake{value: amountStake}(amountStake);

        vm.warp(block.timestamp + period - 1);

        uint256 amountReward = staking.earned(user);
        staking.unstake(amountStake);
        vm.stopPrank();

        (, uint256 userReward,) = staking.getInfo(user);

        assertEq(userReward, 0);
        assertEq(amountReward, 0);

    }

    function testClaimAfterPartialUnstake() public {
        vm.startPrank(user);

        staking.stake{value: 10}(10);

        
        vm.warp(block.timestamp + 2 days);
        uint256 rewardBeforeUnstake = staking.earned(user);

        staking.unstake(4);
        
        vm.warp(block.timestamp + 1 days);

        uint256 rewardAfeterUnstake = staking.earned(user);

        uint256 balanceBeforeClaim = address(user).balance;
        staking.claimReward();
        uint256 balanceAfterClaim = address(user).balance;
        vm.stopPrank();

        (, uint256 rewardAfterClaim,) = staking.getInfo(user);

        console.log(rewardBeforeUnstake, rewardAfeterUnstake, balanceBeforeClaim, balanceAfterClaim);
        assertEq(rewardAfterClaim, 0);
        assertEq(rewardBeforeUnstake + rewardAfeterUnstake, balanceAfterClaim - balanceBeforeClaim);
    }

    function testPartialUnstakeCheckpointsReward() public {

        vm.prank(user);
        staking.stake{value: 10}(10);

        console.log(staking.checkAmountStake());

        vm.warp(block.timestamp + 2 days);

        vm.prank(user);
        staking.unstake(4);

        (uint256 stake, uint256 reward,) = staking.getInfo(user);

        assertEq(stake, 6);
        assertEq(reward, 20);
    }

    function testCannotUnstakeMoreThanStake() public {
        vm.startPrank(user);

        staking.stake{value: 10}(10);

        vm.warp(block.timestamp + 2 days);

        vm.expectRevert(bytes("IB"));
        staking.unstake(11);
        vm.stopPrank();
    }

    function test_EarnRewardOverTime() public {
        vm.prank(user);
        staking.stake{value: 100}(100);

        vm.warp(block.timestamp + 1 days);

        uint256 reward = staking.earned(user);

        assert(reward > 0);
    }
    
    function stakeAndWarp(uint256 amount, uint256 time) internal {
        vm.prank(user);
        staking.stake{value: amount}(amount);
        vm.warp(block.timestamp + (time + 1));
    }
    function test_ClaimDoesNotChangePrincipal() public {
        stakeAndWarp(100, 1 days);

        vm.startPrank(user);
        uint256 principalBeforeClaim = staking.checkAmountStake();
        
        staking.claimReward();
        uint256 principalAfterClaim = staking.checkAmountStake();
        vm.stopPrank();


        assertEq(principalBeforeClaim, principalAfterClaim);
    }

    function test_DoubleClaimDoesNotDoubleReward() public {
        stakeAndWarp(100, 1 days);
        vm.startPrank(user);
        staking.claimReward();
        uint256 rewardAfterClaim = staking.earned(user);
        vm.stopPrank();

        assertEq(rewardAfterClaim, 0);
    }

    function test_UnstakeReturnsPrincipal() public {
        stakeAndWarp(100, 1 days);

        vm.startPrank(user);
        console.log("Balance before claim: ", address(user).balance);
        uint256 rewardBeforeClaim = staking.earned(user);
        staking.claimReward();
        console.log("Balance after claim: ", address(user).balance);
        uint256 balanceBeforeUnstake = address(user).balance;
        console.log("Balance before unstake: ", balanceBeforeUnstake);
        staking.unstake(10);
        uint256 balanceAfterUnstake = address(user).balance;
        console.log("Balance after unstake: ", balanceAfterUnstake);
        vm.stopPrank();

        assertEq(balanceBeforeUnstake + rewardBeforeClaim, balanceAfterUnstake);
    }
}