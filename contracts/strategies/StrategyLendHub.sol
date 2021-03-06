// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import "./inc/StrategyComp.sol";

contract StrategyLendHub is StrategyComp {
    /// @dev comp控制器地址
    address _comptrl = 0x6537d6307ca40231939985BCF7D83096Dd1B4C09;
    /// @dev comp代币地址
    address _comp = 0x8F67854497218043E1f72908FFE38D0Ed7F24721;

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
