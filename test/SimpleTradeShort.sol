// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./utils/TestSetup.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract SimpleTradeShort is TestSetup {
    function test__simpleTradeToCloseShort1() public {
        uint128 amount = 1000e6;
        uint24 fee = 3000;
        writeTokenBalance(alice, conf.addUsdc, amount);

        assertEq(amount, IERC20(conf.addUsdc).balanceOf(alice));
        assertEq(0, IERC20(conf.addUsdc).balanceOf(address(positions)));

        vm.startPrank(alice);
        IERC20(conf.addUsdc).approve(address(positions), amount);
        market.openPosition(conf.addUsdc, conf.addWbtc, uint24(fee), true, 1, amount, 0, 0);

        assertEq(0, IERC20(conf.addUsdc).balanceOf(alice));
        assertApproxEqRel(amount * 2, IERC20(conf.addUsdc).balanceOf(address(positions)), 0.05e18);

        assertEq(1, positions.totalNbPos());
        uint256[] memory posAlice = positions.getTraderPositions(alice);
        assertEq(1, posAlice[0]);
        assertEq(alice, positions.ownerOf(posAlice[0]));

        market.closePosition(posAlice[0]);

        assertApproxEqRel(amount, IERC20(conf.addUsdc).balanceOf(alice), 0.05e18);
        assertEq(0, IERC20(conf.addUsdc).balanceOf(address(positions)));
    }
    
}
