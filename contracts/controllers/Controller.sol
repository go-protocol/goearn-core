// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../../interfaces/uniswap/Uni.sol";
import "../../interfaces/yearn/IConverter.sol";
import "../../interfaces/yearn/IStrategy.sol";

contract Controller {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public governance;
    address public strategist;

    address public router;
    // 奖励地址
    address public rewards;
    mapping(address => address) public vaults;
    mapping(address => address) public strategies;
    mapping(address => mapping(address => address)) public converters;

    mapping(address => mapping(address => bool)) public approvedStrategies;

    // 奖励的分割数量 500 / 10000 = 5%
    uint256 public split = 500;
    uint256 public constant max = 10000;

    /**
     * @dev 构造函数
     * @param _rewards 奖励地址
     * @notice 将空闲余额发送到控制器,再调用控制器的赚钱方法
     */
    constructor(address _rewards, address _router) public {
        governance = msg.sender;
        strategist = msg.sender;
        router = _router;
        rewards = _rewards;
    }

    /**
     * @dev 设置奖励地址
     * @param _rewards 奖励地址
     * @notice 只能由治理地址设置
     */
    function setRewards(address _rewards) public {
        require(msg.sender == governance, "!governance");
        rewards = _rewards;
    }

    /**
     * @dev 设置策略员地址
     * @param _strategist 策略员地址
     * @notice 只能由治理地址设置
     */
    function setStrategist(address _strategist) public {
        require(msg.sender == governance, "!governance");
        strategist = _strategist;
    }

    /**
     * @dev 设置奖励比例
     * @param _split 分割数量
     * @notice 只能由治理地址设置
     */
    function setSplit(uint256 _split) public {
        require(msg.sender == governance, "!governance");
        split = _split;
    }

    /**
     * @dev 设置路由合约
     * @param _router 地址
     * @notice 只能由治理地址设置
     */
    function setRouter(address _router) public {
        require(msg.sender == governance, "!governance");
        router = _router;
    }

    /**
     * @dev 设置治理地址
     * @param _governance 治理地址
     * @notice 只能由治理地址设置
     */
    function setGovernance(address _governance) public {
        require(msg.sender == governance, "!governance");
        governance = _governance;
    }

    /**
     * @dev 设置保险库
     * @param _token token地址
     * @param _vault 保险库地址
     * @notice 只能由治理地址或者策略员地址设置
     */
    function setVault(address _token, address _vault) public {
        require(msg.sender == strategist || msg.sender == governance, "!strategist");
        require(vaults[_token] == address(0), "vault");
        vaults[_token] = _vault;
    }

    /**
     * @dev 批准策略
     * @param _token token地址
     * @param _strategy 策略地址
     * @notice 只能由治理地址设置,在批准策略映射中批准
     */
    function approveStrategy(address _token, address _strategy) public {
        require(msg.sender == governance, "!governance");
        approvedStrategies[_token][_strategy] = true;
    }

    /**
     * @dev 取消批准策略
     * @param _token token地址
     * @param _strategy 策略地址
     * @notice 只能由治理地址设置,在批准策略映射中取消批准
     */
    function revokeStrategy(address _token, address _strategy) public {
        require(msg.sender == governance, "!governance");
        approvedStrategies[_token][_strategy] = false;
    }

    /**
     * @dev 设置转换者
     * @param _input 输入地址
     * @param _output 输出地址
     * @param _converter 转换者地址
     * @notice 只能由治理地址或者策略地址设置
     */
    function setConverter(
        address _input,
        address _output,
        address _converter
    ) public {
        require(msg.sender == strategist || msg.sender == governance, "!strategist");
        converters[_input][_output] = _converter;
    }

    /**
     * @dev 强制设置策略,不进行取款
     * @param _token token地址
     * @param _strategy 策略地址
     * @notice 只能由治理地址或者策略员地址设置,需要批准策略员
     */
    function setStrategyWithoutWithdraw(address _token, address _strategy) public {
        require(msg.sender == strategist || msg.sender == governance, "!strategist");
        require(approvedStrategies[_token][_strategy] == true, "!approved");
        strategies[_token] = _strategy;
    }

    /**
     * @dev 设置策略
     * @param _token token地址
     * @param _strategy 策略地址
     * @notice 只能由治理地址或者策略员地址设置,需要批准策略员
     */
    function setStrategy(address _token, address _strategy) public {
        require(msg.sender == strategist || msg.sender == governance, "!strategist");
        require(approvedStrategies[_token][_strategy] == true, "!approved");

        address _current = strategies[_token];
        if (_current != address(0)) {
            IStrategy(_current).withdrawAll();
        }
        strategies[_token] = _strategy;
    }

    /**
     * @dev 赚钱方法
     * @param _token token地址
     * @param _amount 数额
     * @notice 调用策略地址的want地址,
     * 如果want地址对应地址不等于token,
     * 将amount数量的token发送到转换器,
     * 将转换后的want发送到策略地址,
     * 最后执行策略地址的存款方法
     */
    function earn(address _token, uint256 _amount) public {
        address _strategy = strategies[_token];
        address _want = IStrategy(_strategy).want();
        if (_want != _token) {
            address converter = converters[_token][_want];
            IERC20(_token).safeTransfer(converter, _amount);
            _amount = IConverter(converter).convert(_strategy);
            IERC20(_want).safeTransfer(_strategy, _amount);
        } else {
            IERC20(_token).safeTransfer(_strategy, _amount);
        }
        IStrategy(_strategy).deposit();
    }

    /**
     * @dev 查询余额
     * @param _token token地址
     * @notice 查询token对应的策略地址的余额方法
     */
    function balanceOf(address _token) external view returns (uint256) {
        return IStrategy(strategies[_token]).balanceOf();
    }

    /**
     * @dev 提款方法
     * @param _token token地址
     * @notice 只能由治理地址或者策略员地址设置,调用策略地址的提款方法
     */
    function withdrawAll(address _token) public {
        require(msg.sender == strategist || msg.sender == governance, "!strategist");
        IStrategy(strategies[_token]).withdrawAll();
    }

    /**
     * @dev 提款方法
     * @param _strategy 策略地址
     * @notice 只能由治理地址或者策略员地址设置,调用策略地址的提款方法
     */
    function withdrawAllFromStrategy(address _strategy) public {
        require(msg.sender == strategist || msg.sender == governance, "!strategist");
        IStrategy(_strategy).withdrawAll();
    }

    /**
     * @dev 万一token被卡住
     * @param _token token地址
     * @param _amount 数额
     * @notice 只能由治理地址或者策略员地址设置,将token发送给调用者
     */
    function inCaseTokensGetStuck(address _token, uint256 _amount) public {
        require(msg.sender == strategist || msg.sender == governance, "!governance");
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }

    /**
     * @dev 万一策略token被卡住
     * @param _strategy 策略地址
     * @param _token token地址
     * @notice 只能由治理地址或者策略员地址设置,调用策略合约中的提款方法
     */
    function inCaseStrategyTokenGetStuck(address _strategy, address _token) public {
        require(msg.sender == strategist || msg.sender == governance, "!governance");
        IStrategy(_strategy).withdraw(_token);
    }

    /**
     * @dev 返回预期收益
     * @param _strategy 策略地址
     * @param _token token地址
     * @notice 调用分割合约的获得预期收益的方法,参数为token地址,策略合约的want地址,策略合约在token合约中的余额,部分,0
     */
    function getExpectedReturn(address _strategy, address _token) public view returns (uint256) {
        uint256 _balance = IERC20(_token).balanceOf(_strategy);
        address _want = IStrategy(_strategy).want();
        address[] memory path = new address[](2);
        path[0] = _token;
        path[1] = _want;
        uint256[] memory amounts;
        amounts = Uni(router).getAmountsOut(_balance, path);
        return amounts[1];
    }

    /**
     * @dev 返回预期收益
     * @param _strategy 策略地址
     * @param _token token地址
     * @notice 只能由治理地址或者策略员地址设置,仅允许提取非核心策略令牌〜这超出了正常收益率,
     */
    // Only allows to withdraw non-core strategy tokens ~ this is over and above normal yield
    function yearn(address _strategy, address _token) public {
        require(msg.sender == strategist || msg.sender == governance, "!governance");
        // 此合同永远不应该具有主币数值，只是万一，因为这是一个公开调用
        // This contract should never have value in it, but just incase since this is a public call
        // 当前合约在token合约中的余额(提款之前)
        uint256 _before = IERC20(_token).balanceOf(address(this));
        // 从策略合约中提款
        IStrategy(_strategy).withdraw(_token);
        // 当前合约在token合约中的余额(提款之后)
        uint256 _after = IERC20(_token).balanceOf(address(this));
        // 如果提款后余额大于提款前余额
        if (_after > _before) {
            // 之后余额 - 之前余额
            uint256 _amount = _after.sub(_before);
            // want地址
            address _want = IStrategy(_strategy).want();
            // 之前 = 当前合约在want合约的余额
            _before = IERC20(_want).balanceOf(address(this));
            // 当前合约批准给路由合约0个数额
            IERC20(_token).safeApprove(router, 0);
            // 当前合约批准给路由合约_amount个数额
            IERC20(_token).safeApprove(router, _amount);

            address[] memory path = new address[](2);
            path[0] = _token;
            path[1] = _want;

            // 调用Uni合约的交换方法换出want
            Uni(router).swapExactTokensForTokens(_amount, uint256(0), path, address(this), block.timestamp + 1800);

            // 之后 = 当前合约在want合约的余额
            _after = IERC20(_want).balanceOf(address(this));
            // 如果之后 > 之前
            if (_after > _before) {
                // 之后余额 - 之前余额
                _amount = _after.sub(_before);
                // 奖励 = amount * 分割数量 / 最大值
                uint256 _reward = _amount.mul(split).div(max);
                // 赚钱方法(want地址, amount数量 - 奖励数量)
                earn(_want, _amount.sub(_reward));
                // 将奖励数量发送给奖励地址
                IERC20(_want).safeTransfer(rewards, _reward);
            }
        }
    }

    /**
     * @dev 提款方法
     * @param _token token地址
     * @param _amount 数额
     * @notice 只能由token的保险库合约执行,执行策略合约的提款方法
     */
    function withdraw(address _token, uint256 _amount) public {
        require(msg.sender == vaults[_token], "!vault");
        IStrategy(strategies[_token]).withdraw(_amount);
    }
}
