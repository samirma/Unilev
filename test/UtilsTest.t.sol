// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./utils/TestSetup.sol";

contract UtilsTest is TestSetup {
    
    function test__getLiquidityPool() public view {
        address pool = market.getTokenToLiquidityPools(conf.wbtc);
        assertEq(pool, address(lbPoolWbtc));
    }

}
