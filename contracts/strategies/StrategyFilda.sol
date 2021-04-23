// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import "./inc/StrategyComp.sol";

contract StrategyFilda is StrategyComp {
    /// @dev comp控制器地址
    address _comptrl = 0xb74633f2022452f377403B638167b0A135DB096d;
    /// @dev comp代币地址
    address _comp = 0xE36FFD17B2661EB57144cEaEf942D95295E637F0;

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
    ) public StrategyComp(_controller, _want, _ctoken, _comptrl, _comp) {}
}
