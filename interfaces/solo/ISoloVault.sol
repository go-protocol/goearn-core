// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface ISoloVault {
    function ERC20_LIST(string calldata) external view returns (address);

    function SAFE_MULTIPLIER() external view returns (uint256);

    function addPool(address token, uint256 depositCap) external;

    function addWhitelist(address _white) external;

    function deposit(uint256 pid, uint256 amount) external;

    function dispatcher() external view returns (address);

    function getGlobalStatistics() external view returns (uint256, uint256);

    function owner() external view returns (address);

    function pidOfToken(address token) external view returns (uint256);

    function pools(uint256)
        external
        view
        returns (
            address token,
            uint256 depositCap,
            uint256 depositClosed,
            uint256 lastRewardBlock,
            uint256 accRewardPerShare,
            uint256 accShare,
            uint256 apy,
            uint256 used
        );

    function poolsLength() external view returns (uint256);

    function removeWhitelist(address _white) external;

    function setDispatcher(address _dispatcher) external;

    function setPoolDepositCap(address token, uint256 depositClosed) external;

    function tokenUsdtPrice(address token) external view returns (uint256);

    function transferETH(address target, uint256 value) external;

    function transferToken(
        address token,
        address target,
        uint256 value
    ) external;

    function unclaimedReward(uint256 pid, address _user) external view returns (uint256);

    function updatePoolReward(address token, uint256 reward) external;

    function userStatistics(address) external view returns (uint256 claimedReward);

    function users(uint256, address) external view returns (uint256 amount, uint256 rewardDebt);

    function withdraw(uint256 pid, uint256 amount) external;
}
