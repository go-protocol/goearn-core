// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IUnitroller {
    function claimComp(address holder, address[] calldata cTokens) external;

    function claimCan(address holder, address[] calldata cTokens) external;
}
