// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";

contract RejectEther {

    uint256 public totalStake;


    mapping(address => PositionInfo) positions;


    struct PositionInfo {
        uint256 stake;
        uint256 lastUpdate;
    }

    receive() external payable {
        revert("ETH_REJECTED");
    }

    function checkStake() public view returns (uint256) {
        PositionInfo storage info = positions[msg.sender];
        return info.stake;
    }

    function stake(uint256 amount) public payable {
        require(amount > 0, "IA");
        require(msg.value == amount, "EV");

        PositionInfo storage info = positions[msg.sender];


        info.lastUpdate = block.timestamp;


        totalStake += amount;
        info.stake += amount;
    }


    function unstake(uint256 amount) public {
        require(amount > 0, "IA");
        PositionInfo storage info = positions[msg.sender];

        info.stake -= amount;

        totalStake -= amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "TF");
    }
}