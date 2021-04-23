// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;
import "./inc/StrategyPool.sol";
import "../../interfaces/solo/ISoloVault.sol";

contract StrategySoloMDX is StrategyPool {
    /**
     * @dev 构造函数
     * @param _controller controller地址
     * @param _want 本币地址
     * @param _pool solo池子id
     */
    constructor(
        address _controller,
        address _want,
        uint256 _pool
    ) public StrategyPool(_controller, _want, _pool) {
        rewardToken = MDX;
        vault = 0x1cF73836aE625005897a1aF831479237B6d1e4D2;
    }

    ///@notice 返回当前合约的在存款池中的余额
    ///@return SoloVault 中的余额
    function balanceOfPool() public view override returns (uint256) {
        (uint256 bal, ) = ISoloVault(vault).users(pool, address(this));
        return bal;
    }

    /// @dev 获取额外奖励方法
    function _getReward() internal virtual override {
        // 向SoloVault存款0可以将收益取出
        ISoloVault(vault).deposit(pool, uint256(0));
    }
}
