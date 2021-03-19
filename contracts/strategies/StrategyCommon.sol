// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

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

contract StrategyCommon {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    /// @notice WHT地址
    address public constant WHT = 0x5545153CCFcA01fbd7Dd11C0b23ba694D9509A6F;
    /// @notice USDT地址
    address public constant USDT = 0xa71EdC38d189767582C38A3145b5873052c3e47a;

    /// @notice MDEX路由地址
    address public constant uniRouter = 0xED7d5F38C79115ca12fe6C0041abb22F0A06C300;
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
    address public ctoken;
    /// @notice want地址
    address public want;

    address public governance;
    address public controller;
    address public strategist;

    /**
     * @dev 构造函数
     */
    constructor() public {
        governance = msg.sender;
        strategist = msg.sender;
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
}
