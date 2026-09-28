// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {RejectEther} from "../src/RejectEther.sol";

contract TestRejectEther is Test {
    RejectEther public reject;

    address public user = makeAddr("user");

    function setUp() public {
        reject = new RejectEther();

        vm.deal(user, 1000);
    }

    function testStakingAmountStillSameAfterUnstake() public {
        reject.stake{value: 100}(100);

        uint256 balanceBefore = address(reject).balance;
        uint256 stakeBefore = reject.checkStake();
        uint256 totalBefore = reject.totalStake();

        vm.expectRevert(bytes("TF"));
        reject.unstake(40);

        uint256 stakeAfter = reject.checkStake();
        uint256 totalAfter = reject.totalStake();

        uint256 balanceAfter = address(reject).balance;

        assertEq(balanceBefore, balanceAfter);
        assertEq(totalBefore, totalAfter);
        assertEq(stakeBefore, stakeAfter);
    }
}
