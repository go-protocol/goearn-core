// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;
import "./VaultCommon.sol";
import "../../interfaces/weth/WETH.sol";

contract gVault is VaultCommon, ERC20 {
    /// @dev WHT地址
    address public constant WHT = 0x5545153CCFcA01fbd7Dd11C0b23ba694D9509A6F;

    /**
     * @dev 构造函数
     * @param _controller 控制器
     */
    constructor(address _controller)
        public
        // 用编码的方法将原来token的名字和缩写加上前缀
        ERC20(string(abi.encodePacked("GoEarn HT")), string(abi.encodePacked("gHT")))
    {
        token = IERC20(WHT);
        governance = msg.sender;
        controller = _controller;
    }

    /// @dev 回退函数用于收款HT
    receive() external payable {}

    /**
     * @dev 存款方法
     * @param _amount 存款数额
     * @notice 当前合约在WETH的余额发送到当前合约,并铸造份额币
     */
    function deposit(uint256 _amount) public payable {
        // 确认存款数额等于value
        require(_amount == msg.value, "!amount");

        // 池子数量 = 当前合约和控制器合约在WETH的余额
        uint256 _pool = balance();
        // 之前 = 当前合约的WHT余额
        uint256 _before = token.balanceOf(address(this));
        // 向WHT合约存款
        IWETH(WHT).deposit{value: msg.value}();
        // 之后 = 当前合约的WHT余额
        uint256 _after = token.balanceOf(address(this));
        // 数量 = 之后 - 之前 (额外检查通缩标记)
        _amount = _after.sub(_before); // Additional check for deflationary tokens
        uint256 shares = 0;
        // 计算份额
        if (totalSupply() == 0) {
            shares = _amount;
        } else {
            // 份额 = 存款数额 * 总量 / 池子数量
            shares = (_amount.mul(totalSupply())).div(_pool);
        }
        // 为调用者铸造份额
        _mint(msg.sender, shares);
        earn();
    }

    /**
     * @dev 全部提款方法
     * @notice 将调用者的全部份额发送到提款方法
     */
    function withdrawAll() external {
        withdraw(balanceOf(msg.sender));
    }

    /**
     * @dev 提款方法
     * @param _shares 份额数量
     * @notice
     */
    function withdraw(uint256 _shares) public {
        // 当前合约和控制器合约在Token的余额 * 份额 / 总量
        uint256 r = (balance().mul(_shares)).div(totalSupply());
        // 销毁份额
        _burn(msg.sender, _shares);

        // 检查余额
        // Check balance
        // 当前合约在Token的余额
        uint256 b = token.balanceOf(address(this));
        // 如果余额 < 份额对应的余额
        if (b < r) {
            // 提款数额 = 份额对应的余额 - 余额
            uint256 _withdraw = r.sub(b);
            // 控制器的提款方法将WHT提款到当前合约
            IController(controller).withdraw(address(token), _withdraw);
            // 之后 = 当前合约的WHT余额
            uint256 _after = token.balanceOf(address(this));
            // 区别 = 之后 - 份额对应的余额
            uint256 _diff = _after.sub(b);
            // 如果区别 < 提款数额
            if (_diff < _withdraw) {
                // 份额对应的余额 = 余额 + 区别
                r = b.add(_diff);
            }
        }
        // 向WHT合约取款HT
        IWETH(WHT).withdraw(r);
        // 将对应数量的HT发送到调用者账户
        msg.sender.transfer(r);
    }

    /**
     * @dev 计算每股对应的底层资产
     */
    function getPricePerFullShare() public view returns (uint256) {
        return balance().mul(1e18).div(totalSupply());
    }
}
