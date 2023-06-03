// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Utils} from "./utils/Utils.sol";
import "./utils/TestSetup.sol";

contract SimpleTrade is TestSetup, Utils {
    function test__simpleTradeToClose1() public {
        writeTokenBalance(alice, conf.addWBTC, 10e8);
        (uint160 price, uint160 sqrtPriceX96) = setPrice(
            90000e6,
            conf.addWBTC,
            conf.addUSDC,
            3000,
            mockV3AggregatorWBTCETH,
            mockV3AggregatorUSDCETH,
            uniswapV3Helper
        );
        assertEq(10e8, ERC20(conf.addWBTC).balanceOf(alice));
        assertEq(0, ERC20(conf.addWBTC).balanceOf(address(positions)));

        vm.startPrank(alice);
        ERC20(conf.addWBTC).approve(address(positions), 10e8);
        market.openPosition(conf.addWBTC, conf.addUSDC, uint24(3000), false, 1, 10e8, 0, 0);

        assertEq(0, ERC20(conf.addWBTC).balanceOf(alice));
        assertEq(10e8, ERC20(conf.addWBTC).balanceOf(address(positions)));

        assertEq(1, positions.totalNbPos());
        uint256[] memory posAlice = positions.getTraderPositions(alice);
        assertEq(0, posAlice[0]);
        assertEq(alice, positions.ownerOf(0));

        market.closePosition(posAlice[0]);

        assertEq(10e8, ERC20(conf.addWBTC).balanceOf(alice));
        assertEq(0, ERC20(conf.addWBTC).balanceOf(address(positions)));
    }

    function test__simpleTradeToClose2() public {
        writeTokenBalance(alice, conf.addWBTC, 10e8);
        (uint160 price, uint160 sqrtPriceX96) = setPrice(
            0,
            conf.addWBTC,
            conf.addUSDC,
            3000,
            mockV3AggregatorWBTCETH,
            mockV3AggregatorUSDCETH,
            uniswapV3Helper
        );
        assertEq(10e8, ERC20(conf.addWBTC).balanceOf(alice));
        assertEq(0, ERC20(conf.addWBTC).balanceOf(address(positions)));

        vm.startPrank(alice);
        ERC20(conf.addWBTC).approve(address(positions), 10e8);
        market.openPosition(conf.addWBTC, conf.addUSDC, uint24(3000), false, 1, 10e8, 0, 0);

        assertEq(0, ERC20(conf.addWBTC).balanceOf(alice));
        assertEq(10e8, ERC20(conf.addWBTC).balanceOf(address(positions)));

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
            uint256 stopLossPrice_
        ) = market.getPositionParams(posAlice[0]);
        assertEq(baseToken_, conf.addWBTC);
        assertEq(quoteToken_, conf.addUSDC);
        assertEq(positionSize_, 999900000);
        assertEq(timestamp_, block.timestamp);
        assertEq(isShort_, false);
        assertEq(leverage_, 1);
        assertEq(breakEvenLimit_, 0);
        assertEq(limitPrice_, 0);
        assertEq(stopLossPrice_, 0);

        assertEq(0, posAlice[0]);
        assertEq(alice, positions.ownerOf(0));

        market.closePosition(posAlice[0]);

        assertEq(10e8, ERC20(conf.addWBTC).balanceOf(alice));
        assertEq(0, ERC20(conf.addWBTC).balanceOf(address(positions)));
    }
}
