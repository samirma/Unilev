// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./utils/TestSetup.sol";

contract LeveragedTradeLong is TestSetup {
    function test__leveragedTradeToCloseLong1() public {
        address wbtc = conf.supportedTokens[0].token;
        address usdc = conf.supportedTokens[2].token;

        uint128 amount = 2e18; // 2 DAI/USDC (18 decimals)
        uint24 fee = 3000;

        depositLiquidity(usdc, 100000e18);

        writeTokenBalance(alice, usdc, amount);

        assertEq(amount, IERC20(usdc).balanceOf(alice));
        assertEq(0, IERC20(usdc).balanceOf(address(positions)));

        uint256 usdcBalanceBefore = IERC20(usdc).balanceOf(
            address(liquidityPoolFactory.getTokenToLiquidityPools(usdc))
        );
        console.log("USDC balance in lbPoolUsdc BEFORE open: ", usdcBalanceBefore);

        vm.startPrank(alice);
        IERC20(usdc).approve(address(positions), amount);
        console.log("Open position");
        market.openLongPosition(usdc, wbtc, uint24(fee), 5, amount, 0, 0);

        assertEq(0, IERC20(usdc).balanceOf(alice));

        uint256 usdcBalanceAfter = IERC20(usdc).balanceOf(
            address(liquidityPoolFactory.getTokenToLiquidityPools(usdc))
        );
        assertLt(usdcBalanceAfter, usdcBalanceBefore);

        uint256 wbtcBalance = IERC20(wbtc).balanceOf(address(positions));
        assertGt(wbtcBalance, 0);

        assertEq(1, positions.totalNbPos());
        uint256[] memory posAlice = positions.getTraderPositions(alice);

        assertEq(1, posAlice[0]);
        assertEq(alice, positions.ownerOf(posAlice[0]));
        console.log("Close position");
        market.closePosition(posAlice[0]);

        assertGt(IERC20(usdc).balanceOf(alice), 0);
        assertEq(0, IERC20(wbtc).balanceOf(address(positions)));

        uint256 usdcBalanceAfterClose = IERC20(usdc).balanceOf(
            address(liquidityPoolFactory.getTokenToLiquidityPools(usdc))
        );
        console.log("USDC balance in lbPoolUsdc AFTER close: ", usdcBalanceAfterClose);
    }
}
