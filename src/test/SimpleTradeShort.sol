// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Utils} from "./utils/Utils.sol";
import "./utils/TestSetup.sol";
import "@uniswapPeriphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract SimpleTradeShort is TestSetup {
    function test__simpleTradeToCloseShort1() public {
        uint128 amount = 1000e6;
        uint24 fee = 3000;
        writeTokenBalance(alice, conf.addUSDC, amount);
        setPrice(
            30000e6,
            conf.addWBTC,
            conf.addUSDC,
            fee,
            mockV3AggregatorWBTCETH,
            mockV3AggregatorUSDCETH,
            uniswapV3Helper
        );
        assertEq(amount, ERC20(conf.addUSDC).balanceOf(alice));
        assertEq(0, ERC20(conf.addUSDC).balanceOf(address(positions)));

        vm.startPrank(alice);
        ERC20(conf.addUSDC).approve(address(positions), amount);
        market.openPosition(conf.addUSDC, conf.addWBTC, uint24(fee), true, 1, amount, 0, 0);

        assertEq(0, ERC20(conf.addUSDC).balanceOf(alice));
        assertApproxEqRel(amount * 2, ERC20(conf.addUSDC).balanceOf(address(positions)), 0.05e18);

        assertEq(1, positions.totalNbPos());
        uint256[] memory posAlice = positions.getTraderPositions(alice);
        assertEq(1, posAlice[0]);
        assertEq(alice, positions.ownerOf(posAlice[0]));

        market.closePosition(posAlice[0]);

        assertApproxEqRel(amount, ERC20(conf.addUSDC).balanceOf(alice), 0.05e18);
        assertEq(0, ERC20(conf.addUSDC).balanceOf(address(positions)));
    }

    function test__simpleTradeStopLossAndCloseLossShort() public {
        uint128 amount = 1000e6;
        uint24 fee = 3000;
        writeTokenBalance(alice, conf.addUSDC, amount);
        setPrice(
            30000e6,
            conf.addWBTC,
            conf.addUSDC,
            fee,
            mockV3AggregatorWBTCETH,
            mockV3AggregatorUSDCETH,
            uniswapV3Helper
        );
        vm.startPrank(alice);
        ERC20(conf.addUSDC).approve(address(positions), amount);
        market.openPosition(conf.addUSDC, conf.addWBTC, uint24(fee), true, 1, amount, 0, 40000e6);

        assertApproxEqRel(amount * 2, ERC20(conf.addUSDC).balanceOf(address(positions)), 0.05e18);

        vm.stopPrank();
        setPrice(
            41000e6,
            conf.addWBTC,
            conf.addUSDC,
            fee,
            mockV3AggregatorWBTCETH,
            mockV3AggregatorUSDCETH,
            uniswapV3Helper
        );

        uint256[] memory posAlice = positions.getTraderPositions(alice);
        assertEq(1, posAlice[0]);
        assertEq(alice, positions.ownerOf(posAlice[0]));

        vm.startPrank(alice);
        market.closePosition(posAlice[0]);

        console.log("balance of alice addWBTC ", ERC20(conf.addWBTC).balanceOf(alice));
        // assertApproxEqRel(aaa, ERC20(conf.addWBTC).balanceOf(alice), 0.05e18); // TODO
        assertEq(30003000, ERC20(conf.addUSDC).balanceOf(alice));
        assertEq(0, ERC20(conf.addUSDC).balanceOf(address(positions)));
        assertEq(0, ERC20(conf.addWBTC).balanceOf(address(positions)));
    }

    function test__simpleTradeStopLossAndCloseWinShort() public {
        uint128 amount = 1000e6;
        uint24 fee = 3000;
        writeTokenBalance(alice, conf.addUSDC, amount);
        setPrice(
            30000e6,
            conf.addWBTC,
            conf.addUSDC,
            fee,
            mockV3AggregatorWBTCETH,
            mockV3AggregatorUSDCETH,
            uniswapV3Helper
        );
        vm.startPrank(alice);
        ERC20(conf.addUSDC).approve(address(positions), amount);
        market.openPosition(conf.addUSDC, conf.addWBTC, uint24(fee), true, 1, amount, 0, 40000e6);

        assertApproxEqRel(amount * 2, ERC20(conf.addUSDC).balanceOf(address(positions)), 0.05e18);

        vm.stopPrank();
        setPrice(
            20000e6,
            conf.addWBTC,
            conf.addUSDC,
            fee,
            mockV3AggregatorWBTCETH,
            mockV3AggregatorUSDCETH,
            uniswapV3Helper
        );

        uint256[] memory posAlice = positions.getTraderPositions(alice);
        assertEq(1, posAlice[0]);
        assertEq(alice, positions.ownerOf(posAlice[0]));

        vm.startPrank(alice);
        market.closePosition(posAlice[0]);

        console.log("balance of alice addWBTC ", ERC20(conf.addWBTC).balanceOf(alice));
        // assertApproxEqRel(aaa, ERC20(conf.addWBTC).balanceOf(alice), 0.05e18); // TODO
        assertEq(30003000, ERC20(conf.addUSDC).balanceOf(alice));
        assertEq(0, ERC20(conf.addUSDC).balanceOf(address(positions)));
        assertEq(0, ERC20(conf.addWBTC).balanceOf(address(positions)));
    }

    // function test__simpleTradeStopLossAndLiquidate() public {
    //     uint128 amount = 10e8;
    //     writeTokenBalance(alice, conf.addWBTC, amount);
    //     setPrice(
    //         30000e6,
    //         conf.addWBTC,
    //         conf.addUSDC,
    //         3000,
    //         mockV3AggregatorWBTCETH,
    //         mockV3AggregatorUSDCETH,
    //         uniswapV3Helper
    //     );

    //     vm.startPrank(alice);
    //     ERC20(conf.addWBTC).approve(address(positions), amount);
    //     market.openPosition(conf.addWBTC, conf.addUSDC, uint24(3000), false, 1, amount, 0, 20000e6); // ST at 20000$ for 1 BTC

    //     uint256[] memory posAlice = positions.getTraderPositions(alice);
    //     assertEq(1, posAlice[0]);
    //     vm.stopPrank();

    //     setPrice(
    //         19000e6,
    //         conf.addWBTC,
    //         conf.addUSDC,
    //         3000,
    //         mockV3AggregatorWBTCETH,
    //         mockV3AggregatorUSDCETH,
    //         uniswapV3Helper
    //     );
    //     vm.startPrank(bob);

    //     uint256[] memory liquidablePos = market.getLiquidablePositions();
    //     assertEq(1, liquidablePos.length);
    //     assertEq(3, positions.getPositionState(1));
    //     assertEq(1, liquidablePos[0]);

    //     market.liquidatePosition(liquidablePos[0]);

    //     // console.log("balance of bob reward", ERC20(conf.addWBTC).balanceOf(bob));

    //     assertApproxEqRel(19000e6 * 10, ERC20(conf.addUSDC).balanceOf(alice), 0.01e18);
    //     assertApproxEqRel(100000, ERC20(conf.addWBTC).balanceOf(bob), 0.01e18);

    //     assertEq(0, ERC20(conf.addWBTC).balanceOf(address(positions)));
    //     assertEq(0, ERC20(conf.addUSDC).balanceOf(address(positions)));

    //     vm.stopPrank();
    // }

    // function test__simpleTradeStopLossAndLiquidateBatch() public {
    //     uint128 amount = 10e8;
    //     writeTokenBalance(alice, conf.addWBTC, amount * 3);
    //     setPrice(
    //         30000e6,
    //         conf.addWBTC,
    //         conf.addUSDC,
    //         3000,
    //         mockV3AggregatorWBTCETH,
    //         mockV3AggregatorUSDCETH,
    //         uniswapV3Helper
    //     );

    //     vm.startPrank(alice);
    //     ERC20(conf.addWBTC).approve(address(positions), amount);
    //     market.openPosition(conf.addWBTC, conf.addUSDC, uint24(3000), false, 1, amount, 0, 20000e6); // ST at 20000$ for 1 BTC
    //     ERC20(conf.addWBTC).approve(address(positions), amount * 2);
    //     market.openPosition(
    //         conf.addWBTC,
    //         conf.addUSDC,
    //         uint24(3000),
    //         false,
    //         1,
    //         amount * 2,
    //         0,
    //         21000e6
    //     ); // ST at 20000$ for 1 BTC

    //     uint256[] memory posAlice = positions.getTraderPositions(alice);
    //     assertEq(2, posAlice[0]);
    //     assertEq(1, posAlice[1]);

    //     vm.stopPrank();

    //     setPrice(
    //         19000e6,
    //         conf.addWBTC,
    //         conf.addUSDC,
    //         3000,
    //         mockV3AggregatorWBTCETH,
    //         mockV3AggregatorUSDCETH,
    //         uniswapV3Helper
    //     );
    //     vm.startPrank(bob);

    //     uint256[] memory liquidablePos = market.getLiquidablePositions();
    //     assertEq(2, liquidablePos.length);
    //     assertEq(3, positions.getPositionState(2));
    //     assertEq(2, liquidablePos[0]);
    //     assertEq(1, liquidablePos[1]);

    //     market.liquidatePositions(liquidablePos);

    //     assertApproxEqRel(19000e6 * 10 * 3, ERC20(conf.addUSDC).balanceOf(alice), 0.05e18);
    //     assertApproxEqRel(100000 * 2, ERC20(conf.addWBTC).balanceOf(bob), 0.01e18);

    //     assertEq(0, ERC20(conf.addWBTC).balanceOf(address(positions)));
    //     assertEq(0, ERC20(conf.addUSDC).balanceOf(address(positions)));

    //     vm.stopPrank();
    // }

    // function test__simpleLimitOrderAndClose() public {
    //     uint128 amount = 30000e6;
    //     uint24 fee = 100;
    //     address token1 = conf.addWBTC;
    //     address token2 = conf.addUSDC;

    //     writeTokenBalance(alice, token1, amount);

    //     vm.startPrank(alice);
    //     ERC20(token1).approve(address(positions), amount);
    //     market.openPosition(token1, token2, uint24(fee), false, 1, amount, 40000e6, 0);

    //     assertEq(0, ERC20(token2).balanceOf(address(positions)));

    //     assertEq(1, positions.totalNbPos());
    //     uint256[] memory posAlice = positions.getTraderPositions(alice);
    //     assertEq(1, posAlice[0]);
    //     assertEq(1, posAlice.length);
    //     assertEq(2, positions.getPositionState(1));

    //     market.closePosition(posAlice[0]);

    //     // assertEq(0, ERC20(token1).balanceOf(address(positions))); // TODO check why this is not 0
    //     assertApproxEqRel(amount, ERC20(token1).balanceOf(address(alice)), 0.01e18);

    //     vm.stopPrank();
    // }
}
