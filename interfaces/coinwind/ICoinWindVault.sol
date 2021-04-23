// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface ICoinWindVault {
    function deposit(address token, uint256 _amount) external;

    function depositAll(address token) external;

    function withdraw(address token, uint256 _amount) external;

    function withdrawAll(address token) external;

    function getPoolId(address token) external view returns (uint256);

    function userInfo(uint256, address)
        external
        view
        returns (
            uint256 amount,
            uint256 rewardDebt,
            uint256 govRewardDebt
        );
}
