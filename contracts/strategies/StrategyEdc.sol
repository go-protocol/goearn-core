// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;
import "./inc/StrategyPool.sol";
import "../../interfaces/edc/IEdcVault.sol";

contract StrategyEdc is StrategyPool {
    /// @notice Edc地址
    address public constant EDC = 0x68a0A1fEF18DfCC422Db8bE6F0F486dEa1999EDC;

    /**
     * @dev 构造函数
     * @param _controller controller地址
     * @param _want 本币地址
     * @param _pool edc池子id
     */
    constructor(
        address _controller,
        address _want,
        uint256 _pool
    ) public StrategyPool(_controller, _want, _pool) {
        rewardToken = EDC;
        vault = 0x80b0eAfA5AAec24c3971d55A4919e8D6a6b71c78;
    }

    ///@notice 返回当前合约的在存款池中的余额
    ///@return EdcVault 中的余额
    function balanceOfPool() public view override returns (uint256) {
        (uint256 bal, ) = IEdcVault(vault).userInfo(pool, address(this));
        return bal;
    }

    /// @dev 获取额外奖励方法
    function _getReward() internal override {
        // 向Vault取款0可以将收益取出
        IEdcVault(vault).withdraw(pool, uint256(0));
    }
}
