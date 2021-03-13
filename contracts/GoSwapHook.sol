// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

interface IStrategy {
    function harvest() external;
}

/**
 * @title 交易钩子合约,替换这个合约可以在swap交易过程中插入操作
 */
contract GoSwapHook is Ownable {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    address public strategy = 0x38229b1399A4DEFaEbbE2f754a4BF83a2c3E645E;
    address public token = 0x0298c2b32eaE4da002a15f36fdf7615BEa3DA047;

    /// @dev 配对合约set
    EnumerableSet.AddressSet private _pairs;
    /**
     * @dev 事件:交换
     * @param sender 发送者
     * @param amount0Out 输出金额0
     * @param amount1Out 输出金额1
     * @param to to地址
     */
    event Swap(address indexed pair, address indexed sender, uint256 amount0Out, uint256 amount1Out, address indexed to);

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
     * @dev 修改器:只能通过配对合约调用
     */
    modifier onlyPair() {
        require(_pairs.contains(msg.sender), "Only Pair can call this");
        _;
    }

    /**
     * @dev 交换钩子
     * @param sender 发送者
     * @param amount0Out 输出金额0
     * @param amount1Out 输出金额1
     * @param to to地址
     */
    function swapHook(
        address sender,
        uint256 amount0Out,
        uint256 amount1Out,
        address to
    ) public onlyPair {
        IStrategy(strategy).harvest();
        uint256 bal = IERC20(token).balanceOf(address(this));
        // 发送触发奖励
        IERC20(token).safeTransfer(to, bal);
        //触发交换事件
        emit Swap(msg.sender, sender, amount0Out, amount1Out, to);
    }
}
