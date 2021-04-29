// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import "../../interfaces/golf/IVault.sol";
import "./inc/StrategyVault.sol";

contract StrategyGolf is StrategyVault {
    /// @notice golff 地址
    address public constant GOF = 0x2AAFe3c9118DB36A20dd4A942b6ff3e78981dce1;

    /**
     * @dev 构造函数
     * @param _controller controller地址
     * @param _want 本币地址
     * @param _pool Golf质押池地址
     * @param _vault Golf保险库地址
     */
    constructor(
        address _controller,
        address _want,
        address _pool,
        address _vault
    ) public StrategyVault(_controller, _want, _vault, _pool) {
        rewardToken = GOF;
    }

    function _depositHT(uint256 amount) internal override {
        // 调用vault的存款方法
        IVault(vault).depositHT{value: amount}();
    }

    function _depositToken(uint256 amount) internal override {
        // 调用vault的存款方法
        IVault(vault).deposit(amount);
    }

    function _withdrawHT(uint256 amount) internal override {
        // 从Vault解除质押
        IVault(vault).withdrawHT(amount);
        // 当前合约的HT余额
        uint256 balance = address(this).balance;
        // 如果HT余额大于0
        if (balance > 0) {
            // 向WHT合约存款
            IWETH(want).deposit{value: balance}();
        }
    }

    function _withdrawToken(uint256 amount) internal override {
        // 从Vault解除质押
        IVault(vault).withdraw(amount);
    }
}
