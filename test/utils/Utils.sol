// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../mocks/MockV3Aggregator.sol";
import "../../src/PriceFeedL1.sol";
import "../../src/UniswapV3Helper.sol";

contract Utils is Test {
    using stdStorage for StdStorage;

    function writeTokenBalance(address who, address token, uint256 amt) public {
        stdstore.target(token).sig(IERC20(token).balanceOf.selector).with_key(who).checked_write(
            amt
        );
    }

}
