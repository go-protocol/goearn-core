// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IEdcVault {
    function deposit(uint256 _pid, uint256 amount) external;

    function withdraw(uint256 _pid, uint256 amount) external;

    function withdrawAll(uint256 pid) external;

    function userInfo(uint256, address) external view returns (uint256 amount, uint256 rewardDebt);

    function BDP() external view returns (address);

    function REWARD_PER_BLOCK() external view returns (uint256);

    function START_BLOCK() external view returns (uint256);

    function claimReward(uint256 _pid) external;

    function depositAll(uint256 _pid) external;

    function emergencyWithdraw(uint256 _pid) external;

    function getApy(uint256 pid) external view returns (uint256);

    function getBegBalance(uint256 pid) external view returns (uint256);

    function getCurrentBalance(uint256 pid) external view returns (uint256);

    function getPrice(address addr) external view returns (uint256);

    function getStakedAmount(uint256 _pid, address _user) external view returns (uint256);

    function pendingReward(uint256 _pid, address _user) external view returns (uint256);

    function poolLength() external view returns (uint256);

    function straegyLength() external view returns (uint256);

    function strategyList(uint256) external view returns (address);
}
