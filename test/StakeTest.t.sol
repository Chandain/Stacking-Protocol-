// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Staking} from "../src/Staking.sol";

contract StakingTest is Test {
    address userA = makeAddr("userA");
    address userB = makeAddr("userB");
    Staking public staking;

    uint256 period = 1 days;

    string json = '{"bar":"Hello World"}';

    function setUp() public {
        staking = new Staking(period, 1);
        vm.deal(userA, 1000);
        vm.deal(userB, 1000);
        vm.deal(address(staking), 10000);
    }

    function parseJsonString(string memory key) public view returns (string memory result) {
        result = vm.parseJsonString(json, key);
    }

    //call vm.parseJsonString using key without dot will fails, while using fots will works
    //this is because foundry using JSON path, foundry need selector to find the location of value in JSON
    function testJsonStringWithoutDot() public {
        vm.expectRevert();
        this.parseJsonString("bar");
    }

    function testJsonStringWithDot() public view {
        string memory result = parseJsonString(".bar");
        assertEq(result, "Hello World");

        console.log(result);
    }

    // stored reward nonzero; ok
    // surplus lebih kecil dari total owed; ok
    // payout sama dengan surplus; oke
    // stored reward akhir = owedBefore - payout;   
    // totalPrincipal tidak berubah;
    // balance contract tetap >= totalPrincipal.
    

    function test_IfBalanceNotEnoughUnpaidRewardStoredInUserInformation() 
    public {
        vm.startPrank(userA);

        staking.stake{value: 100}(100);
        vm.warp(block.timestamp + 20 days);

        staking.unstake(20);

        vm.warp(block.timestamp + 100 days);

        (, uint256 rewardStoredBeforeClaim, ) = staking.getInfo(userA);
        uint256 rewardAccured = staking.earned(userA);
        uint256 rewardAvaible = staking.getRewardAvaibility();
        uint256 rewardUnpaid = (rewardAccured + rewardStoredBeforeClaim) - rewardAvaible;

        uint256 totalPrincipalBeforeClaim = staking.totalPrincipal();

        staking.claimReward();

        (, uint256 rewardStored, ) = staking.getInfo(userA);

        vm.warp(block.timestamp + 20 days);

        vm.expectRevert(bytes("ICB"));
        staking.claimReward();

        uint256 totalPrincipalAfterClaim = staking.totalPrincipal();

        vm.stopPrank();

        assertEq(rewardUnpaid, rewardStored);
        assertEq(totalPrincipalAfterClaim, totalPrincipalBeforeClaim);
        assertGe(address(staking).balance, totalPrincipalAfterClaim);
    }


    function test_RewardPaymentCannotConsumePrincipal() public {
        vm.startPrank(userA);
        staking.stake{value: 100}(100);

        vm.warp(block.timestamp + 101 days);

        uint256 userBalanceBefore = userA.balance;
        uint256 principalBeforeClaim = staking.totalPrincipal();
        uint256 availible = staking.getRewardAvaibility();

        staking.claimReward();

        uint256 userBalanceAfter = userA.balance;
        uint256 assetsAfter = address(staking).balance;
        uint256 principalAfterClaim = staking.totalPrincipal();
         
        vm.warp(block.timestamp + 10 days);

        vm.expectRevert(bytes("ICB"));
        staking.claimReward();

        vm.stopPrank();


        assertEq(principalBeforeClaim, principalAfterClaim);
        assertEq(assetsAfter, principalBeforeClaim);
        assertEq(userBalanceBefore + availible, userBalanceAfter);

        assertGe(assetsAfter, principalAfterClaim);
        console.log("q");
    }

    function test_RewardPaymentCanConsumePrincipal() public {
        vm.startPrank(userA);
        staking.stake{value: 100}(100);

        vm.warp(block.timestamp + 101 days);

        uint256 userBalanceBefore = userA.balance;
        uint256 rewardOwed = staking.earned(userA);
        uint256 principalLiability = staking.totalPrincipal();
        uint256 assetsBefore = address(staking).balance;
        uint256 rewardAvaible = staking.getRewardAvaibility();
        (, uint256 storedReward,) = staking.getInfo(userA);
        uint256 expectedReward = storedReward + rewardOwed;
        uint256 surplusReward = staking.getRewardAvaibility();

        uint256 expectedPaid = expectedReward < surplusReward 
        ? expectedReward
        : surplusReward;
        staking.claimReward();

        uint256 userBalanceAfter = userA.balance;

        uint256 assetsAfter = address(staking).balance;
        uint256 principalAfterClaim = staking.totalPrincipal();
        vm.stopPrank();

        console.log("contract assets", assetsBefore, "principal liability", principalLiability);
        console.log("reward owed", rewardOwed, "assets after", assetsAfter);
        console.log("principal after claim", principalAfterClaim);

        assertGt(rewardOwed, 0);
        assertGe(assetsBefore, principalLiability);
        assertGe(assetsBefore, rewardOwed);

        assertEq(userBalanceAfter - userBalanceBefore, expectedPaid);
        assertEq(principalAfterClaim, principalLiability);
        assertEq(assetsAfter, assetsBefore - expectedPaid);
        // assertLt(assetsAfter, principalAfterClaim);
    }

    function test_Stake() public {
        vm.prank(userA);
        staking.stake{value: 100}(100);
    }

    function getActor(uint256 actorSeed) public view returns (address actor) {
        actor = actorSeed % 2 == 0 ? userA : userB;
    }

    function test_ClaimStoredRemainsFundToUserInfoWhenFundNotEnough() public {
        vm.startPrank(userA);

        staking.stake{value: 100}(100);

        vm.warp(block.timestamp + 250 days);

        uint256 pendingReward = staking.earned(userA);
        (, uint256 storedReward,) = staking.getInfo(userA);

        uint256 expectedReward = pendingReward + storedReward;
        uint256 availableAssets = address(staking).balance;

        uint256 rewardAvaible = staking.getRewardAvaibility();
        uint256 rewardStored = expectedReward - rewardAvaible;

        assertGt(expectedReward, availableAssets, "Test setup: reward must exceed available assets");

        staking.claimReward();

        (, uint256 storedRewardAfterClaim,) = staking.getInfo(userA);
        vm.stopPrank();

        assertEq(storedRewardAfterClaim, rewardStored);
    }

    function testAmountUnstakeIsZero() public {
        vm.startPrank(userA);

        staking.stake{value: 10}(10);

        vm.expectRevert(bytes("IA"));
        staking.unstake(0);

        vm.stopPrank();
    }

    function testUnstaketotalPrincipal() public {
        vm.startPrank(userA);

        uint256 amountStake = 10;

        staking.stake{value: amountStake}(amountStake);

        staking.unstake(amountStake);
        vm.stopPrank();
    }

    function testUnstakeMoreThantotalPrincipal() public {
        vm.startPrank(userA);

        uint256 amountStake = 10;

        staking.stake{value: amountStake}(amountStake);

        vm.expectRevert(bytes("IB"));
        staking.unstake(amountStake + 1);
        vm.stopPrank();
    }

    function testElapsedLessThanFullPeriod() public {
        vm.startPrank(userA);

        uint256 amountStake = 10;

        staking.stake{value: amountStake}(amountStake);

        vm.warp(block.timestamp + period - 1);

        uint256 amountReward = staking.earned(userA);
        staking.unstake(amountStake);
        vm.stopPrank();

        (, uint256 userAReward,) = staking.getInfo(userA);

        assertEq(userAReward, 0);
        assertEq(amountReward, 0);
    }

    function testClaimAfterPartialUnstake() public {
        vm.startPrank(userA);

        staking.stake{value: 10}(10);

        vm.warp(block.timestamp + 2 days);
        uint256 rewardBeforeUnstake = staking.earned(userA);

        staking.unstake(4);

        vm.warp(block.timestamp + 1 days);

        uint256 rewardAfeterUnstake = staking.earned(userA);

        uint256 balanceBeforeClaim = address(userA).balance;
        staking.claimReward();
        uint256 balanceAfterClaim = address(userA).balance;
        vm.stopPrank();

        (, uint256 rewardAfterClaim,) = staking.getInfo(userA);

        console.log(rewardBeforeUnstake, rewardAfeterUnstake, balanceBeforeClaim, balanceAfterClaim);
        assertEq(rewardAfterClaim, 0);
        assertEq(rewardBeforeUnstake + rewardAfeterUnstake, balanceAfterClaim - balanceBeforeClaim);
    }

    function testPartialUnstakeCheckpointsReward() public {
        vm.prank(userA);
        staking.stake{value: 10}(10);

        console.log(staking.checkAmountStake());

        vm.warp(block.timestamp + 2 days);

        vm.prank(userA);
        staking.unstake(4);

        (uint256 stake, uint256 reward,) = staking.getInfo(userA);

        assertEq(stake, 6);
        assertEq(reward, 20);
    }

    function testCannotUnstakeMoreThanStake() public {
        vm.startPrank(userA);

        staking.stake{value: 10}(10);

        vm.warp(block.timestamp + 2 days);

        vm.expectRevert(bytes("IB"));
        staking.unstake(11);
        vm.stopPrank();
    }

    function test_EarnRewardOverTime() public {
        vm.prank(userA);
        staking.stake{value: 100}(100);

        vm.warp(block.timestamp + 1 days);

        uint256 reward = staking.earned(userA);

        assert(reward > 0);
    }

    function stakeAndWarp(uint256 amount, uint256 time) internal {
        vm.prank(userA);
        staking.stake{value: amount}(amount);
        vm.warp(block.timestamp + (time + 1));
    }

    function test_ClaimDoesNotChangePrincipal() public {
        stakeAndWarp(100, 1 days);

        vm.startPrank(userA);
        uint256 principalBeforeClaim = staking.checkAmountStake();

        staking.claimReward();
        uint256 principalAfterClaim = staking.checkAmountStake();
        vm.stopPrank();

        assertEq(principalBeforeClaim, principalAfterClaim);
    }

    function test_DoubleClaimDoesNotDoubleReward() public {
        stakeAndWarp(100, 1 days);
        vm.startPrank(userA);
        staking.claimReward();
        uint256 rewardAfterClaim = staking.earned(userA);
        vm.stopPrank();

        assertEq(rewardAfterClaim, 0);
    }

    function test_UnstakeReturnsPrincipal() public {
        stakeAndWarp(100, 1 days);

        vm.startPrank(userA);
        console.log("Balance before claim: ", address(userA).balance);
        uint256 rewardBeforeClaim = staking.earned(userA);
        console.log("rewardBeforeClaim", rewardBeforeClaim);
        staking.claimReward();
        console.log("Balance after claim: ", address(userA).balance);
        uint256 balanceBeforeUnstake = address(userA).balance;
        console.log("Balance before unstake: ", balanceBeforeUnstake);
        staking.unstake(10);
        uint256 balanceAfterUnstake = address(userA).balance;
        console.log("Balance after unstake: ", balanceAfterUnstake);
        vm.stopPrank();

        assertEq(balanceBeforeUnstake + 10, balanceAfterUnstake);
    }
}
