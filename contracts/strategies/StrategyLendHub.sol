// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "./StrategyCommon.sol";

contract StrategyLendHub is StrategyCommon {
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
    ) public StrategyCommon(_controller, _ctoken, _want, _comptrl, _comp) {}

    /// @dev 卖掉comp
    function _sellComp() internal override {
        // 市场数组
        address[] memory markets = new address[](1);
        // 数组唯一值为ctoken
        markets[0] = ctoken;
        // 调用comp的控制器,取出comp代币
        IUnitroller(comptrl).claimComp(address(this), markets);
        super._sellComp();
    }

    receive() external payable {}
}
