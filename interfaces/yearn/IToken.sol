// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

// NOTE: Basically an alias for Vaults
interface yERC20 {
    function deposit(uint256 _amount) external payable;

    function withdraw(uint256 _amount) external;

    function getPricePerFullShare() external view returns (uint256);
}
