// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import "./VaultCommon.sol";

contract gVault is VaultCommon, ERC20 {
    /**
     * @dev 构造函数
     * @param _token 基础资产Token
     * @param _controller 控制器
     */
    constructor(address _token, address _controller)
        public
        // 用编码的方法将原来token的名字和缩写加上前缀
        ERC20(string(abi.encodePacked("GoEarn ", ERC20(_token).name())), string(abi.encodePacked("g", ERC20(_token).symbol())))
    {
        token = IERC20(_token);
        governance = msg.sender;
        controller = _controller;
    }

    /**
     * @dev 全部存款方法
     * @notice 将调用者的全部Token作为参数发送到存款方法
     */
    function depositAll() external {
        deposit(token.balanceOf(msg.sender));
    }

    /**
     * @dev 存款方法
     * @param _amount 存款数额
     * @notice 当前合约在Token的余额发送到当前合约,并铸造份额币
     */
    function deposit(uint256 _amount) public {
        // 池子数量 = 当前合约和控制器合约在Token的余额
        uint256 _pool = balance();
        // 之前 = 当前合约的Token余额
        uint256 _before = token.balanceOf(address(this));
        // 将调用者的Token发送到当前合约
        token.safeTransferFrom(msg.sender, address(this), _amount);
        // 之后 = 当前合约的Token余额
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
    // 无需重新实施余额以降低费用并加快交换速度
    // No rebalance implementation for lower fees and faster swaps
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
            // 控制器的提款方法将Token提款到当前合约
            IController(controller).withdraw(address(token), _withdraw);
            // 之后 = 当前合约的Token余额
            uint256 _after = token.balanceOf(address(this));
            // 区别 = 之后 - 份额对应的余额
            uint256 _diff = _after.sub(b);
            // 如果区别 < 提款数额
            if (_diff < _withdraw) {
                // 份额对应的余额 = 余额 + 区别
                r = b.add(_diff);
            }
        }

        // 将数量为份额对应的余额的Token发送到调用者账户
        token.safeTransfer(msg.sender, r);
    }

    /**
     * @dev 计算每股对应的底层资产
     */
    function getPricePerFullShare() public view returns (uint256) {
        return balance().mul(1e18).div(totalSupply());
    }
}
