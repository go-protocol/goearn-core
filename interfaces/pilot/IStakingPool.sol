// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IStakingPool {
    function stake(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function rewardPerToken() external view returns (uint256);

    function earned(address account) external view returns (uint256);

    function getReward() external;

    function balanceOf(address account) external view returns (uint256);
}
