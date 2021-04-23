// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IVault {
    function deposit(uint256 _amount) external payable;

    function depositHT() external payable;

    function withdraw(uint256 _shares) external;

    function withdrawHT(uint256 _shares) external;
}
