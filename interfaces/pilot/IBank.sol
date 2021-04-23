// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IBank {
    function deposit(address token, uint256 amount) external payable;

    function withdraw(address token, uint256 pAmount) external;

    function debtValToShare(address token, uint256 debtVal) external view returns (uint256);

    function debtShareToVal(address token, uint256 debtShare) external view returns (uint256);
}
