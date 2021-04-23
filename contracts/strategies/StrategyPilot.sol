// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import "../../interfaces/pilot/IBank.sol";
import "./inc/StrategyVault.sol";

contract StrategyPilot is StrategyVault {
    /// @notice vault地址
    address public constant pilotVault = 0xD42Ef222d33E3cB771DdA783f48885e15c9D5CeD;
    /// @notice pilot 地址
    address public constant PTD = 0x52Ee54dd7a68e9cf131b0a57fd6015C74d7140E2;

    /**
     * @dev 构造函数
     * @param _controller controller地址
     * @param _want 本币地址
     * @param _pool Pilot质押池地址
     */
    constructor(
        address _controller,
        address _want,
        address _pool
    ) public StrategyVault(_controller, _want, pilotVault, _pool) {
        rewardToken = PTD;
    }

    ///@notice 本策略管理的总want数额
    function balanceOf() public view override returns (uint256) {
        uint256 _balanceOfWant = balanceOfWant();
        uint256 _balanceOfPool = balanceOfPool();
        uint256 _balanceOfVault = balanceOfVault();
        return _balanceOfWant.add(IBank(vault).debtShareToVal(want, _balanceOfPool.add(_balanceOfVault)));
    }

    function _depositHT(uint256 amount) internal override {
        // 调用vault的存款方法
        IBank(vault).deposit{value: amount}(address(0), amount);
    }

    function _depositToken(uint256 amount) internal override {
        // 调用vault的存款方法
        IBank(vault).deposit(want, amount);
    }

    function _withdrawHT(uint256 amount) internal override {
        // 从Vault解除质押
        IBank(vault).withdraw(address(0), amount);
    }

    function _withdrawToken(uint256 amount) internal override {
        // 从Vault解除质押
        IBank(vault).withdraw(want, amount);
    }
}
