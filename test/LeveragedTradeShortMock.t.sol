// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./utils/TestSetupMock.sol";

contract LeveragedTradeShortMock is TestSetupMock {
    
    function test__leveragedTradeWithoutStopLossAndLiquidateShort() public {
        uint128 amount = 1000e6;
        uint24 fee = 3000;
        writeTokenBalance(alice, conf.addUsdc, amount);

        // Assert initial balances before opening position
        assertEq(amount, IERC20(conf.addUsdc).balanceOf(alice));
        assertEq(0, IERC20(conf.addUsdc).balanceOf(address(positions)));
        
        vm.startPrank(deployer);
        mockV3AggregatorUsdcUsd.updateAnswer(33330000); // ~$0.3333
        vm.stopPrank();

        vm.startPrank(alice);
        // Approve the Positions contract to spend the input token (USDC)
        IERC20(conf.addUsdc).approve(address(positions), amount);
        market.openPosition(conf.addUsdc, conf.addWbtc, uint24(fee), true, 2, amount, 0, 0);
        assertApproxEqRel(amount * 3, IERC20(conf.addUsdc).balanceOf(address(positions)), 0.05e18);

        vm.stopPrank();

        vm.startPrank(deployer);
        mockV3AggregatorWbtcUsd.updateAnswer(81000 * 1e8);
        vm.stopPrank();
        
        uint256[] memory posAlice = positions.getTraderPositions(alice);
        assertEq(1, posAlice[0]);
        assertEq(alice, positions.ownerOf(posAlice[0]));

        vm.startPrank(bob);
        // The liquidation should now pass because the price is >= 81000
        market.liquidatePosition(posAlice[0]);

        console.log("balance of alice addUSDC ", IERC20(conf.addUsdc).balanceOf(alice));
        // assertApproxEqRel(aaa, ERC20(conf.addWBTC).balanceOf(alice), 0.05e18); // TODO
        assertEq(30003000, IERC20(conf.addUsdc).balanceOf(bob));
        assertEq(0, IERC20(conf.addUsdc).balanceOf(address(positions)));
        assertEq(0, IERC20(conf.addWbtc).balanceOf(address(positions)));
    }
   
}
