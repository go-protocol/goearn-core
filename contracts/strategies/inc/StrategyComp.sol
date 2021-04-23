// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import "../../../interfaces/compound/Token.sol";
import "../../../interfaces/compound/CETH.sol";
import "../../../interfaces/compound/IUnitroller.sol";
import "./StrategyBase.sol";

contract StrategyComp is StrategyBase {
    /// @notice ctoken地址
    address public immutable ctoken;
    /// @notice comp控制器地址
    address public immutable comptrl;
    /// @notice comp代币地址
    address public immutable comp;

    /**
     * @dev 构造函数
     * @param _controller controller地址
     * @param _want 本币地址
     * @param _ctoken cToken地址
     * @param _comptrl comp控制器
     * @param _comp comp币地址
     */
    constructor(
        address _controller,
        address _want,
        address _ctoken,
        address _comptrl,
        address _comp
    ) public StrategyBase(_controller, _want) {
        ctoken = _ctoken;
        comptrl = _comptrl;
        comp = _comp;
        rewardToken = _comp;
    }

    ///@notice 返回当前合约的在存款池中的余额
    ///@return ctoken 中的余额
    function balanceOfPool() public view override returns (uint256) {
        (, uint256 cTokenBal, , uint256 exchangeRate) = cToken(ctoken).getAccountSnapshot(address(this));
        return cTokenBal.mul(exchangeRate).div(1e18);
    }

    /**
     * @dev 私有存款，存入指定数量
     * @param _want want的数量
     * @notice 将want存入到comp的ctoken
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
                // 调用ctoken的铸造方法铸造_want数量的ctoken
                CETH(ctoken).mint{value: balance}();
            }
        } else {
            // 将_want余额数量的want批准给ctoken地址
            IERC20(want).approve(ctoken, 0);
            IERC20(want).approve(ctoken, _want);
            // 调用ctoken的铸造方法铸造_want数量的ctoken,并确认返回0
            require(cToken(ctoken).mint(_want) == 0, "deposit fail");
        }
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
        // 资产地址不能等于ctoken地址
        require(ctoken != address(_asset), "want");
        // 资产地址不能等于comp地址
        require(comp != address(_asset), "want");
        return super.withdraw(_asset);
    }

    /**
     * @notice 根据当前合约在dusdt的余额计算出可以在dusdt中赎回的数额,并赎回资产
     * @dev 内部赎回资产方法
     * @param _amount 数额
     * @return _withdrew 赎回数额
     */
    function _withdrawSome(uint256 _amount) internal override returns (uint256) {
        // 之前 = 当前合约的want余额
        uint256 before = IERC20(want).balanceOf(address(this));
        // 如果want地址==WHT地址
        if (want == WHT) {
            // 确认成功调用CETH合约的赎回底层资产方法,数量为_amount
            require(CETH(ctoken).redeemUnderlying(_amount) == 0, "redeem fail");
            // 当前合约的HT余额
            uint256 balance = address(this).balance;
            // 如果HT余额大于0
            if (balance > 0) {
                // 向WHT合约存款
                IWETH(want).deposit{value: balance}();
            }
        } else {
            // 确认成功调用CToken合约的赎回底层资产方法,数量为_amount
            require(cToken(ctoken).redeemUnderlying(_amount) == 0, "redeem fail");
        }
        // 返回当前合约在want合约的余额 - 之前的数量
        return IERC20(want).balanceOf(address(this)).sub(before);
    }

    /// @dev 领取comp
    function _getReward() internal virtual override {
        // 市场数组
        address[] memory markets = new address[](1);
        // 数组唯一值为ctoken
        markets[0] = ctoken;
        // 调用comp的控制器,取出comp代币
        IUnitroller(comptrl).claimComp(address(this), markets);
    }
}
