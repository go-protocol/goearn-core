// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import "./inc/StrategyBase.sol";
import "../../interfaces/yearn/IToken.sol";
import "../../interfaces/sushi/IMasterChef.sol";

contract StrategyHfi is StrategyBase {
    /// @notice HFI 地址
    address public constant HFI = 0x98fc3b60Ed4A504F588342A53746405E355F9347;
    /// @notice 主厨合约
    address public constant MasterChef = 0x23159F45Db93729d03a54ff9965F91764b91eC4C;
    /// @notice vault地址
    address public immutable vault;
    /// @notice pid 池子id
    uint256 public immutable pool;

    /**
     * @dev 构造函数
     * @param _controller controller地址
     * @param _want 本币地址
     * @param _vault Golf保险库地址
     * @param _pool Golf质押池地址
     */
    constructor(
        address _controller,
        address _want,
        address _vault,
        uint256 _pool
    ) public StrategyBase(_controller, _want) {
        vault = _vault;
        pool = _pool;
        rewardToken = HFI;
    }

    ///@notice 返回当前合约的在存款池中的余额
    ///@return pool 中的余额
    function balanceOfPool() public view override returns (uint256) {
        (uint256 bal, ) = IMasterChef(MasterChef).userInfo(pool, address(this));
        return bal;
    }

    /// @dev 返回当前合约在Pool赚到的收益
    function poolEarned() public view virtual returns (uint256) {
        return IMasterChef(MasterChef).pendingSushi(pool, address(this));
    }

    ///@notice 返回当前合约的在存款池中的余额
    ///@return pool 中的余额
    function balanceOfVault() public view virtual returns (uint256) {
        return IERC20(vault).balanceOf(address(this));
    }

    ///@notice 本策略管理的总want数额
    function balanceOf() public view virtual override returns (uint256) {
        uint256 _balanceOfWant = balanceOfWant();
        uint256 _balanceOfPool = balanceOfPool();
        uint256 _balanceOfVault = balanceOfVault();
        uint256 _getPricePerFullShare = yERC20(vault).getPricePerFullShare();
        // 全部余额 = want余额 + (pool余额 + vault余额) * 每股对应资产数量 / 1e18
        return _balanceOfWant.add((_balanceOfPool.add(_balanceOfVault)).mul(_getPricePerFullShare).div(1e18));
    }

    function _depositHT(uint256 amount) internal virtual {
        // 调用vault的存款方法
        yERC20(vault).deposit{value: amount}(amount);
    }

    function _depositToken(uint256 amount) internal virtual {
        // 调用vault的存款方法
        yERC20(vault).deposit(amount);
    }

    /**
     * @dev 私有存款，存入指定数量
     * @param _want want的数量
     * @notice 从当前合约存入到保险库Vault，然后将保险库的存款凭证存入到挖矿池子Pool
     */
    function _depositSome(uint256 _want) internal override {
        // 如果want地址==WHT地址
        if (want == WHT) {
            // 从WHT合约取款WHT
            IWETH(WHT).withdraw(_want);
            // 当前合约的HT余额
            uint256 balance = address(this).balance;
            // 如果HT余额>0
            if (balance > 0) {
                _depositHT(balance);
            }
        } else {
            // 将_want余额数量的want批准给vault地址
            IERC20(want).approve(vault, 0);
            IERC20(want).approve(vault, _want);
            // 调用vault的存款方法
            _depositToken(_want);
        }
        // 当前合约的GTOKEN余额
        uint256 _bal = balanceOfVault();
        // 当前合约之前在pool的余额
        uint256 before = balanceOfPool();
        // 将bal余额数量的GTOKEN批准给pool地址
        IERC20(vault).approve(MasterChef, 0);
        IERC20(vault).approve(MasterChef, _bal);
        IMasterChef(MasterChef).deposit(pool, _bal);
        require(balanceOfPool() == before.add(_bal), "deposit fail!");
    }

    /**
     * @notice 将当前合约在'_asset'资产合约的余额'balance'发送给控制器合约
     * @dev 提款方法
     * @param _asset 资产地址
     * @return balance 当前合约在资产合约中的余额
     * 控制器仅用于从灰尘中产生额外奖励的功能
     */
    // Controller only function for creating additional rewards from dust
    function withdraw(IERC20 _asset) public override returns (uint256 balance) {
        // 资产地址不能等于vault地址
        require(vault != address(_asset), "want");
        return super.withdraw(_asset);
    }

    /// @dev 私有从Pool取款
    function _withdrawFromPool() internal {
        // 当前合约之前在pool的余额
        uint256 _bal = balanceOfPool();
        // 从Pool解除质押
        IMasterChef(MasterChef).withdraw(pool, _bal);
    }

    function _withdrawHT(uint256 amount) internal virtual {
        // 从Vault解除质押
        yERC20(vault).withdraw(amount);
    }

    function _withdrawToken(uint256 amount) internal virtual {
        // 从Vault解除质押
        yERC20(vault).withdraw(amount);
    }

    /// @dev 私有从Vault取款
    function _withdrawFromVault() internal {
        // 当前合约的GTOKEN余额
        uint256 _bal = balanceOfVault();
        if (want == WHT) {
            // 从Vault解除质押
            _withdrawHT(_bal);
        } else {
            // 从Vault解除质押
            _withdrawToken(_bal);
        }
    }

    /**
     * @notice 根据当前合约在dusdt的余额计算出可以在dusdt中赎回的数额,并赎回资产
     * @dev 内部赎回资产方法
     * @param _amount 数额
     * @return _withdrew 赎回数额
     */
    function _withdrawSome(uint256 _amount) internal override returns (uint256) {
        // 从Pool和Vault解除质押
        _withdrawFromPool();
        _withdrawFromVault();
        // 如果want地址==WHT地址
        if (want == WHT) {
            // 当前合约的HT余额
            uint256 balance = address(this).balance;
            // 如果HT余额大于0
            if (balance > 0) {
                // 向WHT合约存款
                IWETH(want).deposit{value: balance}();
            }
        }
        // 确认当前合约余额大于取款数额
        require(balanceOfWant() >= _amount, "Insufficient amount");
        // 将当前合约的want余额减去取款数额，剩余再存回
        _depositSome(balanceOfWant().sub(_amount));
        // 返回当前合约在want合约的余额 - 之前的数量
        return _amount;
    }

    /// @dev 获取额外奖励方法
    function _getReward() internal override {
        // 领取奖励
        IMasterChef(MasterChef).withdraw(pool, uint256(0));
    }
}
