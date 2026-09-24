// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Staking} from "../src/Staking.sol";


contract StakingHandler is Test {
    Staking public staking;

    uint256 public ghost_totalPrincipal;
    uint256 public ghost_totalDeposited;
    uint256 public ghost_totalPrincipalOut;
    uint256 public ghost_totalRewardsPaid;

    address public userA = makeAddr("userA");
    address public userB = makeAddr("userB");


    constructor(Staking _staking) {
        vm.deal(userA, 1000);
        vm.deal(userB, 1000);
        staking = _staking;
    }

    function getActor(uint256 actorSeed) public view returns(address actor){
        actor = actorSeed % 2 == 0 ? userA : userB;
    }


    function stake(uint256 _amount, uint256 actorSeed) external {
        address actor = getActor(actorSeed);

        uint256 amount = bound(_amount, 1, 100);

        vm.prank(actor);
        staking.stake{value: amount}(amount);

        ghost_totalPrincipal += amount;
        ghost_totalDeposited += amount;
    }

    function warp(uint256 _elapsed) external {
        uint256 elapsed = bound(_elapsed, 1, 30 days); 

        vm.warp(block.timestamp + elapsed);
    }

    function claim(uint256 actorSeed) external {
        address actor = getActor(actorSeed);

        uint256 balanceBefore = address(staking).balance;
        console.log("balanceBefore", balanceBefore);

        // console.log("totalStakeBefore", staking.totalStake());

        uint256 pendingReward = staking.earned(actor);
        // console.log("pendingReward", pendingReward);

        (, uint256 storedReward, ) = staking.getInfo(actor);
        // console.log("storedReward", storedReward);

        uint256 expectedReward = storedReward + pendingReward;
        // console.log("expectedReward", expectedReward);

        if (expectedReward == 0) return;


        vm.prank(actor);
        staking.claimReward();

        uint256 balanceAfter = address(staking).balance;
        // console.log("balanceAfter", balanceAfter);

        // uint256 rewardAfter = staking.earned(actor);
        // console.log("rewardAfter", rewardAfter);

        uint256 rewardActuallyPaid = balanceBefore - balanceAfter;
        console.log("Claim", rewardActuallyPaid);
        // console.log("rewardActuallyPaid", rewardActuallyPaid);

        // ghost_totalRewardsPaid += rewardActuallyPaid; 
        // console.log("totalStake after", staking.totalStake());

        // console.log("Deposited", ghost_totalDeposited);
        // console.log("PrincipalOut", ghost_totalPrincipalOut);

        // console.log("-------");

        assertEq(rewardActuallyPaid, expectedReward);
    }

    function unstake(uint256 _amount, uint256 actorSeed) external {
        address actor = getActor(actorSeed);
        
        (uint256 userStake, , ) = staking.getInfo(actor);

        if(userStake == 0) return;

        uint256 amount = bound(_amount, 1, userStake);

        vm.prank(actor);
        staking.unstake(amount);   

        ghost_totalPrincipal -= amount;
        ghost_totalPrincipalOut += amount;
    }
}