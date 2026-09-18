// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Staking} from "../src/Staking.sol";
import {StakingHandler} from "./StakingHandler.t.sol";


contract StakeInvariantTest is Test {
    StakingHandler handler;
    Staking staking;

    address public user = makeAddr("user");

    uint256 period = 1 days;

    function setUp() public {
        staking = new Staking(period, 1);
        handler = new StakingHandler(staking);

        vm.deal(user, 1000);
        vm.deal(address(staking), 100000);

        targetContract(address(handler));
    } 

    function invariant_ContractCanCoverPrincipal() public view {
        assertGe(
            address(staking).balance,
            staking.totalStake()
        );
    }

}