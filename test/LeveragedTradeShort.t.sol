// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./utils/TestSetup.sol";

contract LeveragedTradeShort is TestSetup {
    function test__leveragedTradeToCloseShort1() public {
        address wbtc = conf.supportedTokens[0].token;
        address usdc = conf.supportedTokens[2].token;

        uint128 amount = 2e18; // 2 USDC/DAI
        uint24 fee = 3000;

        // Short scenario: only the base token pool (WBTC) needs liquidity for the borrow
        vm.startPrank(bob);
        writeTokenBalance(bob, wbtc, 10e8);
        IERC20(wbtc).approve(address(lbPoolWbtc), 10e8);
        lbPoolWbtc.deposit(10e8, bob);
        vm.stopPrank();

        writeTokenBalance(alice, usdc, amount);

        assertEq(amount, IERC20(usdc).balanceOf(alice));
        assertEq(0, IERC20(usdc).balanceOf(address(positions)));

        uint256 wbtcBalanceBefore = IERC20(wbtc).balanceOf(address(lbPoolWbtc));

        vm.startPrank(alice);
        IERC20(usdc).approve(address(positions), amount);

        // Open Short on WBTC against USDC
        market.openShortPosition(
            usdc, // USDC (collateral)
            wbtc, // WBTC (exposure)
            uint24(fee),
            5, // 5x leverage
            amount,
            0,
            0
        );

        assertEq(0, IERC20(usdc).balanceOf(alice));

        // Contract holds USDC after short swap
        uint256 positionsUsdc = IERC20(usdc).balanceOf(address(positions));
        assertGt(positionsUsdc, amount * 4);

        // WBTC was borrowed
        uint256 wbtcBalanceAfter = IERC20(wbtc).balanceOf(address(lbPoolWbtc));
        assertLt(wbtcBalanceAfter, wbtcBalanceBefore);

        assertEq(1, positions.totalNbPos());
        uint256[] memory posAlice = positions.getTraderPositions(alice);
        assertEq(1, posAlice[0]);
        assertEq(alice, positions.ownerOf(posAlice[0]));

        market.closePosition(posAlice[0]);

        // Alice receives USDC back
        assertGt(IERC20(usdc).balanceOf(alice), 0);
        assertEq(0, IERC20(usdc).balanceOf(address(positions)));
    }
}
