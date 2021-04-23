// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IMasterChef {
    function deposit(uint256 pid, uint256 amount) external;

    function withdraw(uint256 pid, uint256 amount) external;

    function rewardPerToken() external view returns (uint256);

    function pendingSushi(uint256 pid, address account) external view returns (uint256);

    function userInfo(uint256, address) external view returns (uint256 amount, uint256 rewardDebt);

    function balanceOf(address account) external view returns (uint256);
}
