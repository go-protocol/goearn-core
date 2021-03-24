// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "./StrategyCommon.sol";

contract StrategyChannels is StrategyCommon {
    /// @dev comp控制器地址
    address _comptrl = 0x8955aeC67f06875Ee98d69e6fe5BDEA7B60e9770;
    /// @dev comp代币地址
    address _comp = 0x1e6395E6B059fc97a4ddA925b6c5ebf19E05c69f;

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
        // 市场数组ß
        address[] memory markets = new address[](1);
        // 数组唯一值为ctoken
        markets[0] = ctoken;
        // 调用comp的控制器,取出comp代币
        IUnitroller(comptrl).claimCan(address(this), markets);
        super._sellComp();
    }

    receive() external payable {}
}
