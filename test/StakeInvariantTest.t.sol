// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Staking} from "../src/Staking.sol";
import {StakingHandler} from "./StakingHandler.t.sol";


contract StakeInvariantTest is Test {
    StakingHandler handler;
    Staking staking;

    address public userA = makeAddr("userA");
    address public userB = makeAddr("userB");


    uint256 period = 1 days;

    function setUp() public {
        staking = new Staking(period, 1);
        handler = new StakingHandler(staking);

        vm.deal(userA, 1000);
        vm.deal(userB, 1000);
        vm.deal(address(staking), 100000);

        targetContract(address(handler));
    } 

    function rewardLiability() public view returns (uint256) {
        (, uint256 storedRewardA, ) = staking.getInfo(userA);
        uint256 pendingRewardA = staking.earned(userA);
        uint256 totalA = storedRewardA + pendingRewardA;

        (, uint256 storedRewardB, ) = staking.getInfo(userB);
        uint256 pendingRewardB = staking.earned(userB);
        uint256 totalB = storedRewardB + pendingRewardB;

        uint256 total = totalA + totalB;
        return total;
    }

    function invariant_ContractCanCoverPrincipal() public view {
        assertGe(
            address(staking).balance,
            staking.totalStake()
        );
    }

    function invariant_PrincipalAccounting() public view {
        assertEq(staking.totalStake(), handler.ghost_totalPrincipal());
    }


    function invariant_ContractAssetsMoreThanLiability() public view {
        uint256 balance = address(staking).balance;
        uint256 principal = staking.totalStake();
        uint256 rewards = rewardLiability();

        console.log("assets", balance);
        console.log("principal", principal);
        console.log("reward liability", rewards);
        console.log("total liability", principal + rewards);

        assertGe(balance, principal + rewards);
    }

}