// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Utils} from "./utils/Utils.sol";
import "./utils/TestSetup.sol";

contract UtilsTest is TestSetup {
    
    function test__getLiquidityPool() public {
        address pool = market.getTokenToLiquidityPools(conf.addWBTC);
        assertEq(pool, address(lbPoolWBTC));
    }

}
