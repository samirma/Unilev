// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./utils/TestSetup.sol";

contract SimpleTradeLong is TestSetup {
    function test__simpleTradeToCloseLong1() public {
        uint128 amount = 10e8;

        address tokenAddress = conf.wbtc;

        IERC20 tokenErc20 = IERC20(tokenAddress);

        writeTokenBalance(alice, tokenAddress, amount);

        assertApproxEqAbs(amount, tokenErc20.balanceOf(alice), 1e6);
        assertEq(0, tokenErc20.balanceOf(address(positions)));

        vm.startPrank(alice);
        tokenErc20.approve(address(positions), amount);
        market.openPosition(tokenAddress, conf.usdc, uint24(3000), false, 1, amount, 0, 0);

        assertApproxEqAbs(0, tokenErc20.balanceOf(alice), 1e6);
        assertApproxEqAbs(amount, tokenErc20.balanceOf(address(positions)), 1e6);

        assertEq(1, positions.totalNbPos());
        uint256[] memory posAlice = positions.getTraderPositions(alice);
        assertEq(1, posAlice[0]);
        assertEq(alice, positions.ownerOf(posAlice[0]));

        market.closePosition(posAlice[0]);

        assertApproxEqAbs(amount, tokenErc20.balanceOf(alice), 1e16);
        assertEq(0, tokenErc20.balanceOf(address(positions)));
    }

    function test__simpleTradeToCloseLong2() public {
        address tokenAddress = conf.wbtc;

        IERC20 tokenErc20 = IERC20(tokenAddress);

        writeTokenBalance(alice, tokenAddress, 10e8);

        assertApproxEqAbs(10e8, tokenErc20.balanceOf(alice), 1e6);
        assertEq(0, tokenErc20.balanceOf(address(positions)));

        vm.startPrank(alice);
        tokenErc20.approve(address(positions), 10e8);
        market.openPosition(tokenAddress, conf.usdc, uint24(3000), false, 1, 10e8, 0, 0);

        assertApproxEqAbs(0, tokenErc20.balanceOf(alice), 1e6);
        assertApproxEqAbs(10e8, tokenErc20.balanceOf(address(positions)), 1e6);

        assertEq(1, positions.totalNbPos());
        uint256[] memory posAlice = market.getTraderPositions(alice);
        (
            address baseToken_,
            address quoteToken_,
            uint128 positionSize_,
            uint64 timestamp_,
            bool isShort_,
            uint8 leverage_,
            uint256 breakEvenLimit_,
            uint160 limitPrice_,
            uint256 stopLossPrice_,
            int128 currentPnL_,

        ) = // int128 collateralLeft_
            market.getPositionParams(posAlice[0]);
        assertEq(baseToken_, tokenAddress);
        assertEq(quoteToken_, conf.usdc);
        //assertEq(positionSize_, 999900000);
        assertEq(timestamp_, block.timestamp);
        assertEq(isShort_, false);
        assertEq(leverage_, 1);
        assertEq(breakEvenLimit_, 0);
        assertEq(limitPrice_, 0);
        assertEq(stopLossPrice_, 0);
        //assertEq(pnl, -100000);
        //assertEq(currentPnL_, int128(999800000));

        assertEq(1, posAlice[0]);
        assertEq(alice, positions.ownerOf(posAlice[0]));

        market.closePosition(posAlice[0]);

        assertApproxEqAbs(10e8, tokenErc20.balanceOf(alice), 1e16);
        assertEq(0, tokenErc20.balanceOf(address(positions)));
    }
}
