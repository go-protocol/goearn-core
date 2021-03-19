// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "./StrategyCommon.sol";

contract StrategyChannels is StrategyCommon {
    /// @notice comp控制器地址
    address public constant comptrl = 0x8955aeC67f06875Ee98d69e6fe5BDEA7B60e9770;
    /// @notice comp代币地址
    address public comp = 0x1e6395E6B059fc97a4ddA925b6c5ebf19E05c69f;

    /**
     * @dev 构造函数
     * @param _controller 控制器地址
     * @param _ctoken CToken地址
     * @param _want want地址
     */
    constructor(
        address _controller,
        address _ctoken,
        address _want
    ) public {
        controller = _controller;
        ctoken = _ctoken;
        want = _want;
    }

    /**
     * @dev 存款方法
     * @notice 将want发送到ctoken,如果是wht就发送到ceth
     */
    function deposit() public {
        // _want余额 = 当前合约在_want合约中的余额
        uint256 _want = IERC20(want).balanceOf(address(this));
        // 如果_want余额 > 0
        if (_want > 0) {
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
                IERC20(want).safeApprove(ctoken, 0);
                IERC20(want).safeApprove(ctoken, _want);
                // 调用ctoken的铸造方法铸造_want数量的ctoken,并确认返回0
                require(cToken(ctoken).mint(_want) == 0, "deposit fail");
            }
        }
    }

    ///@notice 将当前合约在'_asset'资产合约的余额'balance'发送给控制器合约
    ///@dev 提款方法
    ///@param _asset 资产地址
    ///@return balance 当前合约在资产合约中的余额
    // 控制器仅用于从灰尘中产生额外奖励的功能
    // Controller only function for creating additional rewards from dust
    function withdraw(IERC20 _asset) external returns (uint256 balance) {
        // 只允许控制器合约调用
        require(msg.sender == controller, "!controller");
        // 资产地址不能等于want地址
        require(want != address(_asset), "want");
        // 资产地址不能等于ctoken地址
        require(ctoken != address(_asset), "want");
        // 资产地址不能等于comp地址
        require(comp != address(_asset), "want");
        // 当前合约在资产合约中的余额
        balance = _asset.balanceOf(address(this));
        // 将资产合约的余额发送给控制器合约
        _asset.safeTransfer(controller, balance);
    }

    ///@notice 将当前合约的want发送‘_amount’数额给控制器合约的保险库
    ///@dev 提款方法
    ///@param _amount 提现数额
    // 提取部分资金，通常用于金库提取
    // Withdraw partial funds, normally used with a vault withdrawal
    function withdraw(uint256 _amount) external {
        // 只允许控制器合约调用
        require(msg.sender == controller, "!controller");
        // 当前合约的want余额
        uint256 _balance = IERC20(want).balanceOf(address(this));
        //如果 余额 < 提现数额
        if (_balance < _amount) {
            // 数额 = 赎回资产（数额 - 余额）
            _amount = _withdrawSome(_amount.sub(_balance));
            // 数额 += 余额
            _amount = _amount.add(_balance);
        }

        // 提现手续费
        uint256 _fee = _amount.mul(withdrawalFee).div(FEE_DENOMINATOR);
        // 如果手续费>0
        if (_fee > 0) {
            // 将手续费发送到控制器奖励地址
            IERC20(want).safeTransfer(IController(controller).rewards(), _fee);
        }
        // 保险库 = want合约在控制器的保险库地址
        address _vault = IController(controller).vaults(address(want));
        // 确保保险库地址不为空
        require(_vault != address(0), "!vault"); // additional protection so we don't burn the funds
        // 将want 发送到 保险库
        IERC20(want).safeTransfer(_vault, _amount.sub(_fee));
    }

    ///@notice 根据当前合约在dusdt的余额计算出可以在dusdt中赎回的数额,并赎回资产
    ///@dev 内部赎回资产方法
    ///@param _amount 数额
    ///@return _withdrew 赎回数额
    function _withdrawSome(uint256 _amount) internal returns (uint256) {
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

    ///@notice 将当前合约的USDT全部发送给控制器合约的保险库
    ///@dev 提款全部方法
    ///@return balance 当前合约的USDT余额
    //提取所有资金，通常在迁移策略时使用
    // Withdraw all funds, normally used when migrating strategies
    function withdrawAll() external returns (uint256 balance) {
        // 只允许控制器合约调用
        require(msg.sender == controller, "!controller");
        //调用内部全部提款方法
        _withdrawAll();

        //当前合约的want余额
        balance = IERC20(want).balanceOf(address(this));

        //保险库 = want合约在控制器的保险库地址
        address _vault = IController(controller).vaults(address(want));
        //确保保险库地址不为空
        require(_vault != address(0), "!vault"); // additional protection so we don't burn the funds
        //将want余额全部发送到保险库中
        IERC20(want).safeTransfer(_vault, balance);
    }

    /// @dev 提款全部方法
    function _withdrawAll() internal {
        // 调用内部赎回资产方法
        _withdrawSome(balanceOfPool());
    }

    ///@dev 收获方法
    function harvest() public onlyBenevolent {
        // 调用comp的控制器,取出comp代币
        IUnitroller(comptrl).claimCan(address(this));
        // 当前合约再comp代币的数量
        uint256 _comp = IERC20(comp).balanceOf(address(this));

        // 之前 = 当前合约在want的数量
        uint256 before = IERC20(want).balanceOf(address(this));

        // 如果comp数量>0
        if (_comp > 0) {
            // 将comp批准给uni路由合约无限数量
            IERC20(comp).safeApprove(uniRouter, 0);
            IERC20(comp).safeApprove(uniRouter, uint256(-1));

            // 交易路径 comp=>USDT
            address[] memory path = new address[](2);
            path[0] = comp;
            path[1] = USDT;
            // 调用uni路由合约将comp卖成USDT
            Uni(uniRouter).swapExactTokensForTokens(_comp, uint256(0), path, address(this), block.timestamp.add(1800));
            // 如果want不是USDT,并且当前合约的USDT余额>0
            if (want != USDT && IERC20(USDT).balanceOf(address(this)) > 0) {
                // 将USDT批准给uni路由合约无限数量
                IERC20(USDT).safeApprove(uniRouter, 0);
                IERC20(USDT).safeApprove(uniRouter, uint256(-1));
                // 交易路径 USDT=>want
                path[0] = USDT;
                path[1] = want;
                // 调用uni路由合约用USDT购买want
                Uni(uniRouter).swapExactTokensForTokens(
                    IERC20(USDT).balanceOf(address(this)),
                    uint256(0),
                    path,
                    address(this),
                    block.timestamp.add(1800)
                );
            }
        }
        // 获得的数量 = 当前合约在want的余额 - 之前的数量
        uint256 gain = IERC20(want).balanceOf(address(this)).sub(before);
        // 如果获得的数量>0
        if (gain > 0) {
            // 奖励 = 获得的数量 x 策略员奖励 / 10000
            uint256 _reward = gain.mul(strategistReward).div(FEE_DENOMINATOR);
            // 触发harvest的奖励 开发者奖励的1/5
            uint256 _harvestReward = _reward.mul(harvestReward).div(FEE_DENOMINATOR);
            // 发送触发奖励
            IERC20(want).safeTransfer(msg.sender, _harvestReward);
            // 将奖励发给策略员
            IERC20(want).safeTransfer(strategist, _reward);
            // 存款
            deposit();
        }
    }

    receive() external payable {}
}
