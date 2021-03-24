// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../../interfaces/yearn/IController.sol";
import "../../interfaces/compound/Token.sol";
import "../../interfaces/compound/CETH.sol";
import "../../interfaces/compound/IUnitroller.sol";
import "../../interfaces/uniswap/Uni.sol";
import "../../interfaces/weth/WETH.sol";

interface ISwapMining {
    function takerWithdraw() external;
}

contract StrategyCommon {
    using SafeMath for uint256;

    /// @notice WHT地址
    address public constant WHT = 0x5545153CCFcA01fbd7Dd11C0b23ba694D9509A6F;
    /// @notice USDT地址
    address public constant USDT = 0xa71EdC38d189767582C38A3145b5873052c3e47a;

    /// @notice MDEX路由地址
    address public constant uniRouter = 0xED7d5F38C79115ca12fe6C0041abb22F0A06C300;
    /// @notice GoSwap路由地址
    address public constant GoSwapRouter = 0xB88040A237F8556Cf63E305a06238409B3CAE7dC;
    /// @notice GOT地址
    address public constant GOT = 0xA7d5b5Dbc29ddef9871333AD2295B2E7D6F12391;

    /// @notice MDX SwapMining 地址
    address public constant SwapMining = 0x7373c42502874C88954bDd6D50b53061F018422e;
    /// @notice MDX 地址
    address public constant MDX = 0x25D2e80cB6B86881Fd7e07dd263Fb79f4AbE033c;
    /// @notice keepr机器人
    address public keeper;

    /// @notice 5%的管理费 450 / 10000
    uint256 public strategistReward = 450;
    /// @notice 收获奖励
    uint256 public harvestReward = 50;
    /// @notice 取款费
    uint256 public withdrawalFee = 50;
    /// @notice 各项费率基准值
    uint256 public constant FEE_DENOMINATOR = 10000;

    /// @notice ctoken地址
    address public immutable ctoken;
    /// @notice want地址
    address public immutable want;

    address public governance;
    address public controller;
    address public strategist;

    /// @notice comp控制器地址
    address public immutable comptrl;
    /// @notice comp代币地址
    address public immutable comp;

    /**
     * @dev 构造函数
     */
    constructor(
        address _controller,
        address _ctoken,
        address _want,
        address _comptrl,
        address _comp
    ) public {
        governance = msg.sender;
        strategist = msg.sender;
        controller = _controller;
        ctoken = _ctoken;
        want = _want;
        comptrl = _comptrl;
        comp = _comp;
    }

    /// @dev 确认调用者不能是除了治理和策略员以外的其他合约
    modifier onlyBenevolent {
        require(msg.sender == tx.origin || msg.sender == governance || msg.sender == strategist || msg.sender == keeper);
        _;
    }

    /**
     * @dev 设置策略员地址
     * @param _strategist 策略员地址
     * @notice 只能由治理地址设置
     */
    function setStrategist(address _strategist) external {
        require(msg.sender == governance || msg.sender == strategist, "!authorized");
        strategist = _strategist;
    }

    /**
     * @dev 设置提现手续费
     * @param _withdrawalFee 提现手续费
     * @notice 只能由治理地址设置
     */
    function setWithdrawalFee(uint256 _withdrawalFee) external {
        require(msg.sender == governance, "!governance");
        withdrawalFee = _withdrawalFee;
    }

    /**
     * @dev 设置策略奖励
     * @param _strategistReward 奖励
     * @notice 只能由治理地址设置
     */
    function setStrategistReward(uint256 _strategistReward) external {
        require(msg.sender == governance, "!governance");
        strategistReward = _strategistReward;
    }

    /**
     * @dev 设置收获奖励
     * @param _harvestReward 奖励
     * @notice 只能由治理地址设置
     */
    function setHarvestReward(uint256 _harvestReward) external {
        require(msg.sender == governance, "!governance");
        harvestReward = _harvestReward;
    }

    /**
     * @dev 设置守护机器人
     * @param _keeper 机器人地址
     * @notice 只能由治理地址设置
     */
    function setKeeper(address _keeper) external {
        require(msg.sender == governance, "!governance");
        keeper = _keeper;
    }

    ///@notice 设置治理账户地址
    function setGovernance(address _governance) external {
        require(msg.sender == governance, "!governance");
        governance = _governance;
    }

    ///@notice 设置控制器合约地址
    function setController(address _controller) external {
        require(msg.sender == governance, "!governance");
        controller = _controller;
    }

    ///@notice 返回当前合约的 want 余额
    ///@return want 余额
    function balanceOfWant() public view returns (uint256) {
        return IERC20(want).balanceOf(address(this));
    }

    ///@notice 返回当前合约的在存款池中的余额
    ///@return ctoken 中的余额
    function balanceOfPool() public view returns (uint256) {
        (, uint256 cTokenBal, , uint256 exchangeRate) = cToken(ctoken).getAccountSnapshot(address(this));
        return cTokenBal.mul(exchangeRate).div(1e18);
    }

    ///@notice 本策略管理的总want数额
    function balanceOf() public view returns (uint256) {
        return balanceOfWant().add(balanceOfPool());
    }

    /// @dev MDX交易即挖矿
    function _doSwapMining() internal {
        // 从MDX交易即挖矿提取MDX
        ISwapMining(SwapMining).takerWithdraw();
        // mdx余额
        uint256 mdxBalance = IERC20(MDX).balanceOf(address(this));
        // 如果mdx余额>0
        if (mdxBalance > 0) {
            // 用MDX交换USDT
            _swap(uniRouter, MDX, USDT, mdxBalance);
        }
    }

    /// @dev 发送复利奖励
    function _doReward() internal {
        // 如果当前合约的USDT余额
        uint256 usdtBalance = IERC20(USDT).balanceOf(address(this));
        // 如果当前合约的USDT余额>0
        if (usdtBalance > 0) {
            // 所有奖励数量 = USDT余额 * (触发奖励+策略奖励) / 10000
            uint256 _GOTreward = usdtBalance.mul(strategistReward.add(harvestReward)).div(FEE_DENOMINATOR);
            // 用USDT交换GOT
            _swap(GoSwapRouter, USDT, GOT, _GOTreward);
            // GOT余额
            uint256 _GOTBalance = IERC20(GOT).balanceOf(address(this));
            // 策略奖励 = 获得的数量 x 策略员奖励 / 10000
            uint256 _strategistReward = _GOTBalance.mul(strategistReward).div(strategistReward.add(harvestReward));
            // 触发harvest的奖励 开发者奖励的1/5
            uint256 _harvestReward = _GOTBalance.mul(harvestReward).div(strategistReward.add(harvestReward));
            // 将奖励发给策略员
            IERC20(GOT).transfer(strategist, _strategistReward);
            // 发送触发奖励
            IERC20(GOT).transfer(msg.sender, _harvestReward);
        }
    }

    /// @dev 购买本币
    function _buyWant() internal {
        // 如果want不是USDT,并且当前合约的USDT余额>0
        if (want != USDT && IERC20(USDT).balanceOf(address(this)) > 0) {
            // 用USDT交换want
            _swap(uniRouter, USDT, want, IERC20(USDT).balanceOf(address(this)));
        }
    }

    /// @dev 交换
    function _swap(
        address router,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal {
        // 将tokenIn批准给路由合约无限数量
        IERC20(tokenIn).approve(router, 0);
        IERC20(tokenIn).approve(router, uint256(-1));
        // 交易路径 USDT=>want
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        // 调用路由合约用tokenIn交换tokenOut
        Uni(router).swapExactTokensForTokens(amountIn, uint256(0), path, address(this), block.timestamp.add(1800));
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
                IERC20(want).approve(ctoken, 0);
                IERC20(want).approve(ctoken, _want);
                // 调用ctoken的铸造方法铸造_want数量的ctoken,并确认返回0
                require(cToken(ctoken).mint(_want) == 0, "deposit fail");
            }
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
    function withdraw(IERC20 _asset) public virtual returns (uint256 balance) {
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
        _asset.transfer(controller, balance);
    }

    /**
     * @notice 将当前合约的want发送‘_amount’数额给控制器合约的保险库
     * @dev 提款方法
     * @param _amount 提现数额
     * 提取部分资金，通常用于金库提取
     */
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
            IERC20(want).transfer(IController(controller).rewards(), _fee);
        }
        // 保险库 = want合约在控制器的保险库地址
        address _vault = IController(controller).vaults(address(want));
        // 确保保险库地址不为空
        require(_vault != address(0), "!vault"); // additional protection so we don't burn the funds
        // 将want 发送到 保险库
        IERC20(want).transfer(_vault, _amount.sub(_fee));
    }

    /**
     * @notice 根据当前合约在dusdt的余额计算出可以在dusdt中赎回的数额,并赎回资产
     * @dev 内部赎回资产方法
     * @param _amount 数额
     * @return _withdrew 赎回数额
     */
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

    /**
     * @notice 将当前合约的USDT全部发送给控制器合约的保险库
     * @dev 提款全部方法
     * @return balance 当前合约的USDT余额
     * 提取所有资金，通常在迁移策略时使用
     */
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
        IERC20(want).transfer(_vault, balance);
    }

    /// @dev 提款全部方法
    function _withdrawAll() internal {
        // 调用内部赎回资产方法
        _withdrawSome(balanceOfPool());
    }

    /// @dev 虚构卖掉comp方法
    function _sellComp() internal virtual {
        // 当前合约在comp代币的数量
        uint256 _comp = IERC20(comp).balanceOf(address(this));
        // 如果comp数量>0
        if (_comp > 0) {
            // 用comp交换USDT
            _swap(uniRouter, comp, USDT, _comp);
        }
    }

    /// @dev 收获方法
    function harvest() public onlyBenevolent {
        // 之前 = 当前合约在want的数量
        uint256 before = IERC20(want).balanceOf(address(this));
        // 卖掉comp
        _sellComp();
        // MDX交易即挖矿
        _doSwapMining();
        // 发送复利奖励
        _doReward();
        // 购买本币
        _buyWant();
        // 获得的数量 = 当前合约在want的余额 - 之前的数量
        uint256 gain = IERC20(want).balanceOf(address(this)).sub(before);
        // 如果获得的数量>0
        if (gain > 0) {
            // 存款
            deposit();
        }
    }
}
