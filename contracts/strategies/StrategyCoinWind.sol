// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;
import "./inc/StrategyBase.sol";
import "../../interfaces/coinwind/ICoinWindVault.sol";

contract StrategyCoinWind is StrategyBase {
    /// @notice vault地址
    address public constant vault = 0xAba48B3fF86645ca417f79215DbdA39B5b7cF6b5;

    /**
     * @dev 构造函数
     * @param _controller controller地址
     * @param _want 本币地址
     */
    constructor(address _controller, address _want) public StrategyBase(_controller, _want) {
        rewardToken = MDX;
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
        ICoinWindVault(vault).deposit(want, amount);
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
        ICoinWindVault(vault).withdraw(want, _amount);
        // 返回当前合约在want合约的余额 - 之前的数量
        return IERC20(want).balanceOf(address(this)).sub(before);
    }

    ///@notice 返回当前合约的在存款池中的余额
    ///@return EdcVault 中的余额
    function balanceOfPool() public view override returns (uint256) {
        uint256 pid = ICoinWindVault(vault).getPoolId(want);
        (uint256 bal, , ) = ICoinWindVault(vault).userInfo(pid, address(this));
        return bal;
    }

    /// @dev 获取额外奖励方法
    function _getReward() internal override {
        // 向Vault取款0可以将收益取出
        ICoinWindVault(vault).withdraw(want, uint256(0));
    }
}
