// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interfaces/yearn/IVault.sol";
import "../interfaces/edc/IEdcVault.sol";

contract TestDW {
    /// @notice MDX 地址
    address public constant MDX = 0x25D2e80cB6B86881Fd7e07dd263Fb79f4AbE033c;
    address public constant vault = 0x9Cc4A1939BCD7928f9b64D7c745C5bf247cfc674;

    function deposit(uint256 _amount) public {
        IERC20(MDX).transferFrom(msg.sender, address(this), _amount);
    }

    function earn(uint256 _amount) public {
        IERC20(MDX).approve(vault, 0);
        IERC20(MDX).approve(vault, _amount);

        IVault(vault).deposit(_amount);
    }

    function withdraw(uint256 _share) public {
        IVault(vault).withdraw(_share);
    }

    function balanceOfPool() public view returns (uint256) {
        return IVault(vault).balanceOf(address(this));
    }
}
