// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interfaces/yearn/IVault.sol";
import "../interfaces/uniswap/Uni.sol";

contract GetGOTApy {
    using SafeMath for uint256;
    mapping(uint256 => uint256) public snapshots;
    uint256 public lastSnapshot;
    /// @notice GoSwap路由地址
    address public constant router = 0xB88040A237F8556Cf63E305a06238409B3CAE7dC;
    /// @notice HUSD地址
    address public constant HUSD = 0x0298c2b32eaE4da002a15f36fdf7615BEa3DA047;
    /// @notice GOT地址
    address public constant GOT = 0xA7d5b5Dbc29ddef9871333AD2295B2E7D6F12391;
    /// @notice sGOT地址
    address public constant sGOT = 0x324e22a6D46D514dDEcC0D98648191825BEfFaE3;

    /// @dev 获取价格
    function _getPriceOne() private view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = GOT;
        path[1] = HUSD;
        uint256[] memory amounts;
        amounts = Uni(router).getAmountsOut(1e18, path);
        return amounts[1];
    }

    /// @dev 根据数组获取锁仓量
    function getTVLs() public view returns (uint256) {
        return IERC20(GOT).balanceOf(sGOT);
    }

    /// @dev 根据数组获取锁仓量对应价格
    function getTVLPrice() public view returns (uint256) {
        return getTVLs().mul(_getPriceOne()).div(1e8);
    }

    /// @dev 获取全部锁仓量
    function getTVL() public view returns (uint256 tvl) {
        tvl = getTVLs();
    }

    /// @dev 记录快照
    function snapshot() public {
        uint256 mod = block.timestamp.mod(1 days);
        uint256 today = mod > 16 hours ? block.timestamp.sub(mod).add(16 hours) : block.timestamp.sub(mod).sub(8 hours);
        if (snapshots[today] == 0) {
            snapshots[today] = IVault(sGOT).getPricePerFullShare();
            lastSnapshot = today;
        }
    }

    /// @dev 获得apy
    function getApys(uint256 duration) public view returns (uint256) {
        uint256 lastEpoch = lastSnapshot.sub(duration);
        uint256 before = snapshots[lastEpoch] > 1e18 ? snapshots[lastEpoch] : 1e18;
        uint256 apy = snapshots[lastSnapshot] > 1e18 ? snapshots[lastSnapshot].sub(before) : 1e18;
        return apy;
    }

    /// @dev 获得每日apy
    function getApysOfDay() public view returns (uint256) {
        return getApys(1 days);
    }

    /// @dev 获取每周apy
    function getApysOfWeek() public view returns (uint256) {
        return getApys(1 weeks);
    }

    /// @dev 获取每月apy
    function getApysOfMonth() public view returns (uint256) {
        return getApys(30 days);
    }
}
