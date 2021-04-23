// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;
import "./StrategyBase.sol";
import "../../../interfaces/pool/IPoolVault.sol";

contract StrategyPool is StrategyBase {
    /// @notice vault地址
    address public vault;
    /// @notice 池子id pid
    uint256 public immutable pool;

    /**
     * @dev 构造函数
     * @param _controller controller地址
     * @param _want 本币地址
     * @param _pool 池子id
     */
    constructor(
        address _controller,
        address _want,
        uint256 _pool
    ) public StrategyBase(_controller, _want) {
        pool = _pool;
    }

    /**
     * @dev 私有存款，存入指定数量
     * @param amount want的数量
     */
    function _depositSome(uint256 amount) internal override {
        // 将_want余额数量的want批准给vault地址
        IERC20(want).approve(vault, 0);
        IERC20(want).approve(vault, amount);
        // 向vault存款
        IPoolVault(vault).deposit(pool, amount);
    }

    /**
     * @notice 从vault取款
     * @dev 内部赎回资产方法
     * @param _amount 数额
     * @return _withdrew 赎回数额
     */
    function _withdrawSome(uint256 _amount) internal override returns (uint256) {
        // 之前 = 当前合约的want余额
        uint256 before = IERC20(want).balanceOf(address(this));
        // 从vault取款
        IPoolVault(vault).withdraw(pool, _amount);
        // 返回当前合约在want合约的余额 - 之前的数量
        return IERC20(want).balanceOf(address(this)).sub(before);
    }
}
