// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../../interfaces/yearn/IController.sol";
import "../../interfaces/compound/Token.sol";
import "../../interfaces/compound/CETH.sol";
import "../../interfaces/compound/IUnitroller.sol";
import "../../interfaces/uniswap/Uni.sol";
import "../../interfaces/weth/WETH.sol";

contract StrategyLendHub {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    /// @notice WHT地址
    address public constant WHT = 0x5545153CCFcA01fbd7Dd11C0b23ba694D9509A6F;

    /// @notice MDEX路由地址
    address public constant uniRouter = 0xED7d5F38C79115ca12fe6C0041abb22F0A06C300;
    /// @notice keepr机器人
    address public keeper;

    /// @notice 5%的管理费 500 / 10000
    uint256 public strategistReward = 500;
    /// @notice 取款费，暂时没收
    uint256 public withdrawalFee = 0;
    /// @notice 各项费率基准值
    uint256 public constant FEE_DENOMINATOR = 10000;

    /// @notice comp控制器地址
    address public constant comptrl = 0x6537d6307ca40231939985BCF7D83096Dd1B4C09;
    /// @notice comp代币地址
    address public comp = 0x8F67854497218043E1f72908FFE38D0Ed7F24721;

    /// @notice ctoken地址
    address public ctoken = 0x1C478D5d1823D51c4c4b196652912A89D9b46c30;
    /// @notice want地址(HUSD)
    address public want = 0x0298c2b32eaE4da002a15f36fdf7615BEa3DA047;

    /// @notice 治理地址----主要用于治理权限检验
    address public governance;
    /// @notice 控制器地址-----主要用于与本合约的资金交互
    address public controller;
    /// @notice 策略管理员地址-----主要用于权限检验和发放策略管理费
    address public strategist;

    /**
     * @dev 构造函数
     * @param _controller 控制器地址
     */
    constructor(address _controller) public {
        governance = msg.sender;
        strategist = msg.sender;
        controller = _controller;
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
     * @dev 设置守护机器人
     * @param _keeper 机器人地址
     * @notice 只能由治理地址设置
     */
    function setKeeper(address _keeper) external {
        require(msg.sender == governance, "!governance");
        keeper = _keeper;
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
            // 将_want余额数量的want批准给ctoken地址
            IERC20(want).safeApprove(ctoken, 0);
            IERC20(want).safeApprove(ctoken, _want);
            // 调用ctoken的铸造方法铸造_want数量的ctoken,并确认返回0
            require(cToken(ctoken).mint(_want) == 0, "deposit fail");
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

        // 提现手续费 提现金额 * 500 / 10000 百分之五
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
        // 确认成功调用CToken合约的赎回底层资产方法,数量为_amount
        require(cToken(ctoken).redeemUnderlying(_amount) == 0, "redeem fail");
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
        //将want余额全部发送到保险库 中
        IERC20(want).safeTransfer(_vault, balance);
    }

    /// @dev 提款全部方法
    function _withdrawAll() internal {
        // 调用内部赎回资产方法
        _withdrawSome(balanceOfPool());
    }

    /// @dev 确认调用者不能是除了治理和策略员以外的其他合约
    modifier onlyBenevolent {
        require(msg.sender == tx.origin || msg.sender == governance || msg.sender == strategist || msg.sender == keeper);
        _;
    }

    ///@dev 收获方法
    ///@notice
    function harvest() public onlyBenevolent {
        // 市场数组
        address[] memory markets = new address[](1);
        // 数组唯一值为ctoken
        markets[0] = ctoken;
        // 调用comp的控制器,取出comp代币
        IUnitroller(comptrl).claimComp(address(this), markets);
        // 当前合约再comp代币的数量
        uint256 _comp = IERC20(comp).balanceOf(address(this));

        // 之前 = 当前合约在want的数量
        uint256 before = IERC20(want).balanceOf(address(this));

        // 如果comp数量>0
        if (_comp > 0) {
            // 将comp批准给uni路由合约无限数量
            IERC20(comp).safeApprove(uniRouter, 0);
            IERC20(comp).safeApprove(uniRouter, uint256(-1));

            // 交易路径 comp=>HUSD
            address[] memory path = new address[](2);
            path[0] = comp;
            path[1] = want;
            // 调用uni路由合约将comp卖成usdt
            Uni(uniRouter).swapExactTokensForTokens(_comp, uint256(0), path, address(this), block.timestamp.add(1800));
        }
        // 获得的数量 = 当前合约在want的余额 - 之前的数量
        uint256 gain = IERC20(want).balanceOf(address(this)).sub(before);
        // 如果获得的数量>0
        if (gain > 0) {
            // 奖励 = 获得的数量 x 策略员奖励 / 10000
            uint256 _reward = gain.mul(strategistReward).div(FEE_DENOMINATOR);
            // 将奖励发给策略员
            IERC20(want).safeTransfer(governance, _reward);
            // 存款
            deposit();
        }
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

    receive() external payable {}
}
