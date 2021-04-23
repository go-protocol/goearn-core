// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IPoolVault {
    function deposit(uint256 pid, uint256 amount) external;

    function withdraw(uint256 pid, uint256 amount) external;
}
