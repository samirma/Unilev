// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswapCore/contracts/UniswapV3Factory.sol";
import "../mocks/MockV3Aggregator.sol";
import "../../src/PriceFeedL1.sol";
import "../../src/UniswapV3Helper.sol";

contract Utils is Test {
    using stdStorage for StdStorage;

    UniswapV3Factory factory = UniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    function getPool(address tokenA, address tokenB, uint24 fee) public view returns (address) {
        address out = factory.getPool(tokenA, tokenB, fee);
        return out;
    }

    function writeTokenBalance(address who, address token, uint256 amt) public {
        stdstore.target(token).sig(IERC20(token).balanceOf.selector).with_key(who).checked_write(
            amt
        );
    }

}
