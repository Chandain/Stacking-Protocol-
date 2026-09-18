// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";

contract Staking {
    uint256 public totalLiquidity; 
    uint256 public feePeriod;
    uint256 public rewardRate;
    uint256 public totalStake;


    mapping(address => PositionInfo) positions;

    constructor(uint256 _feePeriod, uint256 _rewardRate) {
        feePeriod = _feePeriod;
        rewardRate = _rewardRate;
    }

    struct PositionInfo {
        uint256 stake;
        uint256 reward;
        uint256 lastUpdate;
    }

    receive() external payable {}

    function stake(uint256 amount) public payable {
        require(amount > 0, "IA");
        require(msg.value == amount, "EV");

        PositionInfo storage info = positions[msg.sender];

        if(info.stake == 0) {
            info.lastUpdate = block.timestamp;
        } else {
            uint256 reward = earned(msg.sender);
            info.reward += reward;
            info.lastUpdate = block.timestamp;
        }

        totalStake += amount;
        info.stake += amount;

        console.log(address(this).balance);
    }

    function getInfo(address user) public view returns (uint256 amountStake, uint256 reward, uint256 lastUpdate) {
        PositionInfo storage info = positions[user];
        return (info.stake, info.reward, info.lastUpdate);
    }

    function checkAmountStake() public view returns (uint256) {
        PositionInfo storage info = positions[msg.sender];
        return info.stake;
    }

    function earned(address user) public view returns (uint256 feeEarned){
        PositionInfo storage info = positions[user];

        uint256 elapsed = block.timestamp - info.lastUpdate;
        if(elapsed < feePeriod) {
            return 0;
        }
        uint256 period = elapsed / feePeriod;

        feeEarned = info.stake * rewardRate * period;
    }

    function claimReward() public {
        PositionInfo storage info = positions[msg.sender];

        uint256 elapsed = block.timestamp - info.lastUpdate;
        uint256 period = elapsed / feePeriod;
        uint256 consumedTime = period * feePeriod;

        uint256 amount = (info.stake * rewardRate * period) + info.reward;

        require(amount > 0, "IB");

        info.reward = 0;
        info.lastUpdate += consumedTime;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "TF");
    }


    function unstake(uint256 amount) public {
        require(amount > 0, "IA");
        PositionInfo storage info = positions[msg.sender];

        require(info.stake >= amount, "IB");

        info.reward += earned(msg.sender);
        info.stake -= amount;
        
        //kondisi salah
        // info.stake -= amount;
        // info.reward += earned(msg.sender);
        totalStake -= amount;
        info.lastUpdate = block.timestamp;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "TF");
    }
}


