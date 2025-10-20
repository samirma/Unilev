// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./utils/TestSetupMock.sol";

contract LeveragedTradeShort is TestSetupMock {
    
function test__leveragedTradeWithoutStopLossAndLiquidateShort() public {
        uint128 amount = 1000e6;
        uint24 fee = 3000;
        writeTokenBalance(alice, conf.addUsdc, amount);

        //Mock intial values

        vm.startPrank(alice);
        IERC20(conf.addUsdc).approve(address(positions), amount);
        market.openPosition(conf.addUsdc, conf.addWbtc, uint24(fee), true, 2, amount, 0, 0);
        assertApproxEqRel(amount * 3, IERC20(conf.addUsdc).balanceOf(address(positions)), 0.05e18);

        vm.stopPrank();
        // Theoretically badDebt = 45000e6 lets set the price to 44000e6
        //Mock values

        uint256[] memory posAlice = positions.getTraderPositions(alice);
        assertEq(1, posAlice[0]);
        assertEq(alice, positions.ownerOf(posAlice[0]));

        vm.startPrank(bob);
        market.liquidatePosition(posAlice[0]);

        console.log("balance of alice addUSDC ", IERC20(conf.addUsdc).balanceOf(alice));
        // assertApproxEqRel(aaa, ERC20(conf.addWBTC).balanceOf(alice), 0.05e18); // TODO
        assertEq(30003000, IERC20(conf.addUsdc).balanceOf(bob));
        assertEq(0, IERC20(conf.addUsdc).balanceOf(address(positions)));
        assertEq(0, IERC20(conf.addWbtc).balanceOf(address(positions)));
    }
   
}
