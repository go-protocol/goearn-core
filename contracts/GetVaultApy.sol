// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interfaces/yearn/IVault.sol";
import "../interfaces/uniswap/Uni.sol";

contract GetVaultApy {
    using SafeMath for uint256;
    mapping(uint256 => mapping(address => uint256)) public snapshots;
    mapping(uint256 => bool) public hasSnapshot;
    uint256 public lastSnapshot;
    address[] public vaults;
    address public governance;
    /// @notice MDEX路由地址
    address public constant uniRouter = 0xED7d5F38C79115ca12fe6C0041abb22F0A06C300;
    /// @notice USDT地址
    address public constant USDT = 0xa71EdC38d189767582C38A3145b5873052c3e47a;

    /**
     * @dev 构造函数
     */
    constructor() public {
        governance = msg.sender;
    }

    /**
     * @dev 设置治理地址
     * @param _governance 治理地址
     * @notice 只能由治理地址设置
     */
    function setGovernance(address _governance) public {
        require(msg.sender == governance, "!governance");
        governance = _governance;
    }

    /// @dev 获取价格
    function _getPriceOne(address _token) private view returns (uint256) {
        uint256 amountIn = 10**uint256(IVault(_token).decimals());
        if (_token == USDT) {
            return amountIn;
        } else {
            address[] memory path = new address[](2);
            path[0] = _token;
            path[1] = USDT;
            uint256[] memory amounts;
            amounts = Uni(uniRouter).getAmountsOut(amountIn, path);
            return amounts[1];
        }
    }

    /// @dev 设置保险库数组
    function setVaults(address[] memory _vaults) public {
        require(msg.sender == governance, "!governance");
        vaults = _vaults;
    }

    /// @dev 获取保险库数组
    function getVaults() public view returns (address[] memory _vaults) {
        _vaults = vaults;
    }

    /// @dev 根据数组获取锁仓量
    function getTVLs(address[] memory _vaults) public view returns (uint256[] memory) {
        uint256[] memory tvls = new uint256[](_vaults.length);
        for (uint256 i = 0; i < _vaults.length; i++) {
            tvls[i] = IVault(_vaults[i]).balance();
        }
        return tvls;
    }

    /// @dev 根据数组获取锁仓量对应价格
    function getTVLPrice(address[] memory _vaults) public view returns (uint256[] memory) {
        uint256[] memory tvls = new uint256[](_vaults.length);
        for (uint256 i = 0; i < _vaults.length; i++) {
            address token = IVault(_vaults[i]).token();
            tvls[i] = IVault(_vaults[i]).balance().mul(_getPriceOne(token)).div(1e18);
        }
        return tvls;
    }

    /// @dev 获取全部锁仓量
    function getTVL() public view returns (uint256 tvl) {
        for (uint256 i = 0; i < vaults.length; i++) {
            address token = IVault(vaults[i]).token();
            tvl = tvl.add(IVault(vaults[i]).balance().mul(_getPriceOne(token)).div(1e18));
        }
    }

    /// @dev 记录快照
    function snapshot() public {
        uint256 mod = block.timestamp.mod(1 days);
        uint256 today = mod > 16 hours ? block.timestamp.sub(mod).add(16 hours) : block.timestamp.sub(mod).sub(8 hours);
        if (hasSnapshot[today] == false) {
            for (uint256 i = 0; i < vaults.length; i++) {
                snapshots[today][vaults[i]] = IVault(vaults[i]).getPricePerFullShare();
            }
            hasSnapshot[today] = true;
            lastSnapshot = today;
        }
    }

    /// @dev 获得apy
    function getApys(address[] memory _vaults, uint256 duration) public view returns (uint256[] memory) {
        uint256[] memory apys = new uint256[](_vaults.length);
        uint256 lastEpoch = lastSnapshot.sub(duration);
        for (uint256 i = 0; i < _vaults.length; i++) {
            uint256 before = snapshots[lastEpoch][_vaults[i]] > 1e18 ? snapshots[lastEpoch][_vaults[i]] : 1e18;
            apys[i] = snapshots[lastSnapshot][_vaults[i]] > 1e18 ? snapshots[lastSnapshot][_vaults[i]].sub(before) : 1e18;
        }
        return apys;
    }

    /// @dev 获得每日apy
    function getApysOfDay(address[] memory _vaults) public view returns (uint256[] memory) {
        return getApys(_vaults, 1 days);
    }

    /// @dev 获取每周apy
    function getApysOfWeek(address[] memory _vaults) public view returns (uint256[] memory) {
        return getApys(_vaults, 1 weeks);
    }

    /// @dev 获取每月apy
    function getApysOfMonth(address[] memory _vaults) public view returns (uint256[] memory) {
        return getApys(_vaults, 30 days);
    }
}
