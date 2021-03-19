// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../../interfaces/yearn/IController.sol";

contract VaultCommon {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    /// @dev 最小值 / 最大值
    uint256 public min = 10000;
    uint256 public constant max = 10000;

    IERC20 public token;

    /// @dev 治理地址
    address public governance;
    /// @dev 控制器合约
    address public controller;

    /// @notice 当前合约在Token的余额,加上控制器中当前合约的余额
    function balance() public view returns (uint256) {
        return token.balanceOf(address(this)).add(IController(controller).balanceOf(address(token)));
    }

    /// @notice 设置最小值
    function setMin(uint256 _min) external {
        require(msg.sender == governance, "!governance");
        min = _min;
    }

    /// @notice 设置治理账号
    function setGovernance(address _governance) public {
        require(msg.sender == governance, "!governance");
        governance = _governance;
    }

    /// @notice 设置控制器
    function setController(address _controller) public {
        require(msg.sender == governance, "!governance");
        controller = _controller;
    }

    /**
     * @dev 赚钱方法
     * @notice 将空闲余额发送到控制器,再调用控制器的赚钱方法
     */
    function earn() public {
        uint256 _bal = available();
        token.safeTransfer(controller, _bal);
        IController(controller).earn(address(token), _bal);
    }

    /**
     * @dev 空闲余额
     * @notice 当前合约在token的余额的95%
     */
    // 此处的自定义逻辑用于允许借用保险库的数量
    // 设置最低要求，以保持小额取款便宜
    // Custom logic in here for how much the vault allows to be borrowed
    // Sets minimum required on-hand to keep small withdrawals cheap
    function available() public view returns (uint256) {
        // 当前合约在token的余额 * 95%
        return token.balanceOf(address(this)).mul(min).div(max);
    }
}
