// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/GoSwap/IGoSwapPair.sol";
import "../interfaces/GoSwap/IGoSwapFactory.sol";

/**
 * @title 通过手续费回购GOT的合约
 */
contract GoSwapBuyGOT is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    /// @dev 配对合约set
    EnumerableSet.AddressSet private _pairs;
    /// @dev 下一个pair
    uint8 public nextPair;

    address public constant factory = 0x76854443c1FC36Bbad8E9Ae361ED415dD673640f;
    address public constant sGOT = 0x324e22a6D46D514dDEcC0D98648191825BEfFaE3;
    address public constant GOT = 0xA7d5b5Dbc29ddef9871333AD2295B2E7D6F12391;
    address public constant HUSD = 0x0298c2b32eaE4da002a15f36fdf7615BEa3DA047;

    /**
     * @dev 返回所有配对合约
     * @return pairs 配对合约数组
     */
    function allPairs() public view returns (address[] memory pairs) {
        pairs = new address[](_pairs.length());
        for (uint256 i = 0; i < _pairs.length(); i++) {
            pairs[i] = _pairs.at(i);
        }
    }

    /**
     * @dev 添加配对合约
     * @param pair 帐号地址
     */
    function addPair(address pair) public onlyOwner {
        _pairs.add(pair);
    }

    /**
     * @dev 移除配对合约
     * @param pair 帐号地址
     */
    function removePair(address pair) public onlyOwner {
        _pairs.remove(pair);
    }

    /**
     * @dev 根据索引返回Pair合约
     * @param index 索引
     * @return vault Pair合约
     */
    function getPairByIndex(uint256 index) public view returns (address vault) {
        return _pairs.at(index);
    }

    /**
     * @dev 将token转换为GOT
     */
    function convert() public onlyOwner {
        if (_pairs.length() == 0) return;
        address pair = getPairByIndex(nextPair);
        if (IERC20(pair).balanceOf(address(this)) > 0) {
            // 找到token0
            address token0 = IGoSwapPair(pair).token0();
            // 找到token1
            address token1 = IGoSwapPair(pair).token1();
            // 调用配对合约的transfer方法,将当前合约的余额发送到配对合约地址上
            _safeTransfer(pair, pair, IERC20(pair).balanceOf(address(this)));
            // 调用配对合约的销毁方法,将流动性token销毁,之后配对合约将会向当前合约地址发送token0和token1
            (uint256 amount0, uint256 amount1) = IGoSwapPair(pair).burn(address(this));
            // 交换HUSD
            uint256 HUSDAmount = _toHUSD(token0, amount0) + _toHUSD(token1, amount1);
            // 交换GOT
            _toGOT(HUSDAmount);
        }
        nextPair = nextPair >= _pairs.length() - 1 ? 0 : nextPair + 1;
    }

    /**
     * @dev 将token卖出转换为HUSD
     * @param token token
     */
    function _toHUSD(address token, uint256 amountIn) internal returns (uint256) {
        // 如果token地址是GOT地址
        if (token == GOT) {
            // 将输入数额从当前合约地址发送到stake合约
            _safeTransfer(token, sGOT, amountIn);
            return 0;
        }
        // 如果token地址是HUSD地址
        if (token == HUSD) {
            // 将数额从当前合约发送到工厂合约上的HUSD和GOT的配对合约地址上
            _safeTransfer(token, IGoSwapFactory(factory).getPair(HUSD, GOT), amountIn);
            return amountIn;
        }
        // 实例化token地址和HUSD地址的配对合约
        IGoSwapPair pair = IGoSwapPair(IGoSwapFactory(factory).getPair(token, HUSD));
        // 如果配对合约地址 == 0地址 返回0
        if (address(pair) == address(0)) {
            return 0;
        }
        // 从配对合约获取储备量0,储备量1
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        // 找到token0
        address token0 = pair.token0();
        // 获取手续费
        uint8 fee = pair.fee();
        // 排序形成储备量In和储备量Out
        (uint256 reserveIn, uint256 reserveOut) = token0 == token ? (reserve0, reserve1) : (reserve1, reserve0);
        // 税后输入数额 = 输入数额 * (1000-fee)
        uint256 amountInWithFee = amountIn.mul(1000 - fee);
        // 输出数额 = 税后输入数额 * 储备量Out / 储备量In * 1000 + 税后输入数额
        uint256 amountOut = amountInWithFee.mul(reserveOut) / reserveIn.mul(1000).add(amountInWithFee);
        // 排序输出数额0和输出数额1,有一个是0
        (uint256 amount0Out, uint256 amount1Out) = token0 == token ? (uint256(0), amountOut) : (amountOut, uint256(0));
        // 将输入数额发送到配对合约
        _safeTransfer(token, address(pair), amountIn);
        // 执行配对合约的交换方法(输出数额0,输出数额1,发送到WETH和token的配对合约上)
        pair.swap(amount0Out, amount1Out, IGoSwapFactory(factory).getPair(HUSD, GOT), new bytes(0));
        return amountOut;
    }

    /**
     * @dev 用amountIn数量的HUSD交换GOT并发送到stake合约上
     * @param amountIn 输入数额
     */
    function _toGOT(uint256 amountIn) internal {
        // 获取GOT和HUSD的配对合约地址,并实例化配对合约
        IGoSwapPair pair = IGoSwapPair(IGoSwapFactory(factory).getPair(HUSD, GOT));
        // 获取配对合约的储备量0,储备量1
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        // 找到token0
        address token0 = pair.token0();
        // 获取手续费
        uint8 fee = pair.fee();
        // 排序生成储备量In和储备量Out
        (uint256 reserveIn, uint256 reserveOut) = token0 == HUSD ? (reserve0, reserve1) : (reserve1, reserve0);
        // 税后输入数额 = 输入数额 * (1000-fee)
        uint256 amountInWithFee = amountIn.mul(1000 - fee);
        // 分子 = 税后输入数额 * 储备量Out
        uint256 numerator = amountInWithFee.mul(reserveOut);
        // 分母 = 储备量In * 1000 + 税后输入数额
        uint256 denominator = reserveIn.mul(1000).add(amountInWithFee);
        // 输出数额 = 分子 / 分母
        uint256 amountOut = numerator / denominator;
        // 排序输出数额0和输出数额1,有一个是0
        (uint256 amount0Out, uint256 amount1Out) = token0 == HUSD ? (uint256(0), amountOut) : (amountOut, uint256(0));
        // 执行配对合约的交换方法(输出数额0,输出数额1,发送到stake合约上)
        pair.swap(amount0Out, amount1Out, sGOT, new bytes(0));
    }

    /**
     * @dev 安全法送方法
     * @param token token地址
     * @param to 接收地址
     * @param amount 数额
     */
    function _safeTransfer(
        address token,
        address to,
        uint256 amount
    ) internal {
        IERC20(token).safeTransfer(to, amount);
    }

    /**
     * @dev 拯救Token
     */
    function saveToken(address _asset) public onlyOwner returns (uint256 balance) {
        // 当前合约在资产合约中的余额
        balance = IERC20(_asset).balanceOf(address(this));
        // 将资产合约的余额发送给控制器合约
        _safeTransfer(_asset, msg.sender, balance);
    }
}
