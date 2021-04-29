// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import "../../interfaces/pilot/IBank.sol";
import "./inc/StrategyVault.sol";

contract StrategyPilot is StrategyVault {
    /// @notice vault地址
    address public constant pilotVault = 0xD42Ef222d33E3cB771DdA783f48885e15c9D5CeD;
    address public constant pilotHUSDBank = 0x5Ee5Dbce6e1a7d0692DA579cC2594B0F5a8f56a1;
    /// @notice pilot 地址
    address public constant PTD = 0x52Ee54dd7a68e9cf131b0a57fd6015C74d7140E2;
    address public constant HUSD = 0x0298c2b32eaE4da002a15f36fdf7615BEa3DA047;
    /// @notice pToken 地址
    address public pToken;
    address public xHUSD;

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
        if (_want == WHT) {
            (, pToken, , , , , , , , ) = IBank(pilotVault).banks(address(0));
        } else if (_want == HUSD) {
            pToken = 0x4d9EFcb0C28522fF736e76a6c6B1F795882b3d74;
            xHUSD = 0xFD52a2AB38dd92E61a615Fc1C40c2E841A4e8579;
        } else {
            (, pToken, , , , , , , , ) = IBank(pilotVault).banks(_want);
        }
    }

    ///@notice 返回当前合约的在存款池中的余额
    ///@return pool 中的余额
    function balanceOfVault() public view override returns (uint256) {
        return IERC20(pToken).balanceOf(address(this));
    }

    ///@notice 本策略管理的总want数额
    function balanceOf() public view override returns (uint256) {
        uint256 _balanceOfWant = balanceOfWant();
        uint256 _balanceOfPool = balanceOfPool();
        uint256 _balanceOfVault = balanceOfVault();
        address token = want == WHT ? address(0) : want;
        uint256 pAmount = _balanceOfPool.add(_balanceOfVault);
        uint256 _ptokenTotalSupply = want == HUSD ? IERC20(xHUSD).totalSupply().mul(1e10) : IERC20(pToken).totalSupply();
        return _balanceOfWant.add(pAmount.mul(IBank(vault).totalToken(token)).div(_ptokenTotalSupply));
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
            // 调用vault的存款方法
            _depositToken(_want);
        }
        // 当前合约的GTOKEN余额
        uint256 _bal = balanceOfVault();
        // 当前合约之前在pool的余额
        uint256 before = balanceOfPool();
        // 将bal余额数量的GTOKEN批准给pool地址
        IERC20(pToken).approve(pool, 0);
        IERC20(pToken).approve(pool, _bal);
        IStakingPool(pool).stake(_bal);
        require(balanceOfPool() == before.add(_bal), "deposit fail!");
    }

    function _depositHT(uint256 amount) internal override {
        // 调用vault的存款方法
        IBank(vault).deposit{value: amount}(address(0), amount);
    }

    function _depositToken(uint256 amount) internal override {
        address bank = want == HUSD ? pilotHUSDBank : vault;
        // 将_want余额数量的want批准给vault地址
        IERC20(want).approve(bank, 0);
        IERC20(want).approve(bank, amount);
        if (want == HUSD) {
            // 调用vault的存款方法
            IBank(bank).deposit(amount);
        } else {
            // 调用vault的存款方法
            IBank(bank).deposit(want, amount);
        }
    }

    function _depositHUSD(uint256 amount) internal {
        // 调用vault的存款方法
        IBank(vault).deposit(want, amount);
    }

    function _withdrawHT(uint256 amount) internal override {
        // 从Vault解除质押
        IBank(vault).withdraw(address(0), amount); // 当前合约的HT余额
        uint256 balance = address(this).balance;
        // 如果HT余额大于0
        if (balance > 0) {
            // 向WHT合约存款
            IWETH(want).deposit{value: balance}();
        }
    }

    function _withdrawToken(uint256 amount) internal override {
        address bank = want == HUSD ? pilotHUSDBank : vault;
        if (want == HUSD) {
            IERC20(pToken).approve(bank, 0);
            IERC20(pToken).approve(bank, amount);
            // 从Vault解除质押
            IBank(bank).withdraw(amount);
        } else {
            // 从Vault解除质押
            IBank(vault).withdraw(want, amount);
        }
    }
}
