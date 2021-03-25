// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IWHT {
    function deposit() external payable;

    function transfer(address, uint256) external returns (bool);

    function withdraw(uint256) external;
}
