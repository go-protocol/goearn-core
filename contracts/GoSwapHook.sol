// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStrategy {
    function harvest() external;
}

interface IVault {
    function token() external view returns (address);

    function controller() external view returns (address);
}

interface IController {
    function strategies(address) external view returns (address);
}

/**
 * @title 交易钩子合约,替换这个合约可以在swap交易过程中插入操作
 */
contract GoSwapHook {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev 管理员
    address public owner;
    /// @dev 默认gas
    uint256 public defaultGas = 1500000;
    /// @notice GOT地址
    address public constant GOT = 0xA7d5b5Dbc29ddef9871333AD2295B2E7D6F12391;

    /// @dev 配对合约set
    EnumerableSet.AddressSet private _pairs;
    /// @dev Vault合约set
    EnumerableSet.AddressSet private _vaults;
    /// @dev 下一个vault
    uint8 public nextVault;

    /**
     * @dev 构造函数
     */
    constructor() public {
        owner = msg.sender;
    }

    /**
     * @dev 事件
     * @param token token地址
     * @param strategy 策略地址
     * @param success 成功
     * @param returndata 返回
     * @param reward 奖励
     */
    event Hook(address indexed token, address indexed strategy, bool success, bytes returndata, uint256 reward);

    /**
     * @dev 设置默认gas
     * @param _defaultGas 默认gas
     */
    function setDefaultGas(uint256 _defaultGas) public {
        require(msg.sender == owner, "!owner");
        defaultGas = _defaultGas;
    }

    /**
     * @dev 返回所有配对合约
     * @return pairs 配对合约数组
     */
    function allPairs() public view returns (address[] memory pairs) {
        pairs = new address[](_pairs.length());
        for (uint256 i = 0; i < _pairs.length(); i++) {
            pairs[i] = _pairs.at(i);
        }
    }

    /**
     * @dev 添加配对合约
     * @param pair 帐号地址
     */
    function addPair(address pair) public {
        require(msg.sender == owner, "!owner");
        _pairs.add(pair);
    }

    /**
     * @dev 移除配对合约
     * @param pair 帐号地址
     */
    function removePair(address pair) public {
        require(msg.sender == owner, "!owner");
        _pairs.remove(pair);
    }

    /**
     * @dev 返回所有Vault合约
     * @return vaults Vault合约数组
     */
    function allVaults() public view returns (address[] memory vaults) {
        vaults = new address[](_vaults.length());
        for (uint256 i = 0; i < _vaults.length(); i++) {
            vaults[i] = _vaults.at(i);
        }
    }

    /**
     * @dev 根据索引返回Vault合约
     * @param index 索引
     * @return vault Vault合约
     */
    function getVaultByIndex(uint256 index) public view returns (address vault) {
        return _vaults.at(index);
    }

    /**
     * @dev 添加Vault合约
     * @param vault 帐号地址
     */
    function addVault(address vault) public {
        require(msg.sender == owner, "!owner");
        _vaults.add(vault);
    }

    /**
     * @dev 移除Vault合约
     * @param vault 帐号地址
     */
    function removeVault(address vault) public {
        require(msg.sender == owner, "!owner");
        _vaults.remove(vault);
    }

    /// @dev 设置保险库数组
    function setVaults(address[] memory vaults) public {
        require(msg.sender == owner, "!owner");
        for (uint256 i = 0; i < _vaults.length(); i++) {
            _vaults.remove(_vaults.at(i));
        }
        for (uint256 i = 0; i < vaults.length; i++) {
            _vaults.add(vaults[i]);
        }
    }

    /**
     * @dev 交换钩子
     * @param sender 发送者
     * @param amount0Out 输出金额0
     * @param amount1Out 输出金额1
     * @param to to地址
     */
    function swapHook(
        address sender,
        uint256 amount0Out,
        uint256 amount1Out,
        address to
    ) public returns (bool, bytes memory) {
        sender;
        amount0Out;
        amount1Out;
        require(_pairs.contains(msg.sender) || msg.sender == owner, "Only Pair can call this");
        require(gasleft() >= defaultGas, "!gasleft");
        if (_vaults.length() > 0) {
            address controller = IVault(getVaultByIndex(nextVault)).controller();
            address token = IVault(getVaultByIndex(nextVault)).token();
            address strategy = IController(controller).strategies(token);
            (bool success, bytes memory returndata) = strategy.call{gas: defaultGas}(abi.encodeWithSelector(IStrategy.harvest.selector));

            uint256 bal = IERC20(GOT).balanceOf(address(this));
            if (bal > 0) IERC20(GOT).transfer(to, bal);
            emit Hook(token, strategy, success, returndata, bal);
            nextVault = nextVault >= _vaults.length() - 1 ? 0 : nextVault + 1;
            return (success, returndata);
        }
    }
}
