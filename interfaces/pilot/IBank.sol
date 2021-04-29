// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IBank {
    function banks(address token)
        external
        view
        returns (
            address tokenAddr,
            address pTokenAddr,
            bool isOpen,
            bool canDeposit,
            bool canWithdraw,
            uint256 totalVal,
            uint256 totalDebt,
            uint256 totalDebtShare,
            uint256 totalReserve,
            uint256 lastInterestTime
        );

    function totalToken(address token) external view returns (uint256);

    function deposit(address token, uint256 amount) external payable;

    function deposit(uint256 amount) external;

    function withdraw(address token, uint256 pAmount) external;

    function withdraw(uint256 pAmount) external;

    function debtValToShare(address token, uint256 debtVal) external view returns (uint256);

    function debtShareToVal(address token, uint256 debtShare) external view returns (uint256);
}
