// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IUniswapV3SwapRouter} from "../../src/interfaces/IUniswapV3.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {MockV3Aggregator} from "./MockV3Aggregator.sol";
import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {UniswapV3Helper} from "../../src/UniswapV3Helper.sol";
import {PriceFeedL1} from "../../src/PriceFeedL1.sol";
import {Utils} from "../utils/Utils.sol"; // Import Utils for writeTokenBalance

/**
 * @title MockUniswapV3Helper
 * @notice A mock implementation of UniswapV3Helper used for testing.
 * @dev This mock uses the PriceFeedL1 to simulate swap calculations based on USD prices,
 * and uses Forge cheatcodes (via Utils inheritance) to directly manipulate token balances.
 * @dev It calculates the exchange amount using USD prices and simulates a small 0.3% loss
 * to account for fees/slippage.
 */
contract MockUniswapV3Helper is Utils {

    PriceFeedL1 public immutable PRICE_FEED;

    constructor(
        address _priceFeed
    )  { 
        PRICE_FEED = PriceFeedL1(_priceFeed);
    }

    /**
     * @notice Mocks Uniswap's exactInputSingle. Sells an exact amount of _tokenIn for _tokenOut.
     * @dev Calculates the amountOut based on USD prices from PriceFeedL1.
     * @dev It updates the balances of msg.sender using Forge cheatcodes (`writeTokenBalance`).
     * @param _tokenIn The input token.
     * @param _tokenOut The output token.
     * @param _fee The Uniswap V3 fee (unused in mock).
     * @param _amountIn The exact amount of input token to sell.
     * @return amountOut The amount of output token received.
     */
   function swapExactInputSingle(
        address _tokenIn,
        address _tokenOut,
        uint24 _fee, // unused
        uint256 _amountIn
    ) public returns (uint256 amountOut) {
        // --- 1. Calculate amountOut (Net Effect of Swap) ---

        // Price of tokenIn in USD (18 decimals)
        uint256 priceInUsd = PRICE_FEED.getTokenLatestPriceInUsd(_tokenIn);
        // Price of tokenOut in USD (18 decimals)
        uint256 priceOutUsd = PRICE_FEED.getTokenLatestPriceInUsd(_tokenOut);

        // Value of input amount in USD (18 decimals)
        uint8 tokenInDecimals = IERC20Metadata(_tokenIn).decimals();
        uint256 valueUsd = (_amountIn * priceInUsd) / (10**tokenInDecimals);

        // Amount of tokenOut received (in its own decimals)
        uint8 tokenOutDecimals = IERC20Metadata(_tokenOut).decimals();
        // Calculate raw amountOut
        amountOut = (valueUsd * (10**tokenOutDecimals)) / priceOutUsd;

        // Apply a small "fee" (0.3%) to simulate slippage/swap cost in the mock.
        amountOut = (amountOut * 997) / 1000;


        // --- 2. Simulate Balance Changes (Net Effect on msg.sender - Positions.sol) ---

        // a) Remove _tokenIn from msg.sender (Positions.sol)
        uint256 currentBalanceIn = IERC20(_tokenIn).balanceOf(msg.sender);
        uint256 newBalanceIn = currentBalanceIn - _amountIn;
        writeTokenBalance(msg.sender, _tokenIn, newBalanceIn);

        // b) Send amountOut of _tokenOut to msg.sender (Positions.sol)
        uint256 currentBalanceOut = IERC20(_tokenOut).balanceOf(msg.sender);
        uint256 newBalanceOut = currentBalanceOut + amountOut;
        writeTokenBalance(msg.sender, _tokenOut, newBalanceOut);

        return amountOut;
    }

    /**
     * @notice Mocks Uniswap's exactOutputSingle. Sells up to _amountInMaximum of _tokenIn to receive an exact amount of _amountOut of _tokenOut.
     * @dev Calculates the amountIn required based on USD prices from PriceFeedL1.
     * @dev It updates the balances of msg.sender using Forge cheatcodes (`writeTokenBalance`).
     * @param _tokenIn The input token.
     * @param _tokenOut The output token.
     * @param _fee The Uniswap V3 fee (unused in mock).
     * @param _amountOut The exact amount of output token desired.
     * @param _amountInMaximum The maximum amount of input token to spend.
     * @return amountIn The exact amount of input token spent.
     */
    function swapExactOutputSingle(
        address _tokenIn,
        address _tokenOut,
        uint24 _fee, // unused
        uint256 _amountOut,
        uint256 _amountInMaximum
    ) public returns (uint256 amountIn) {
        // --- 1. Calculate amountIn (Net Cost of Swap) ---

        // Price of tokenIn in USD (18 decimals)
        uint256 priceInUsd = PRICE_FEED.getTokenLatestPriceInUsd(_tokenIn);
        // Price of tokenOut in USD (18 decimals)
        uint256 priceOutUsd = PRICE_FEED.getTokenLatestPriceInUsd(_tokenOut);

        // Value of output amount in USD (18 decimals)
        uint8 tokenOutDecimals = IERC20Metadata(_tokenOut).decimals();
        uint256 valueUsd = (_amountOut * priceOutUsd) / (10**tokenOutDecimals);

        // Amount of tokenIn required (in its own decimals)
        uint8 tokenInDecimals = IERC20Metadata(_tokenIn).decimals();
        // Calculate raw amountIn
        amountIn = (valueUsd * (10**tokenInDecimals)) / priceInUsd;

        // Apply a small "fee" (0.3%) to simulate slippage/swap cost.
        amountIn = (amountIn * 1003) / 1000;

        // Check against the maximum allowed input
        if (amountIn > _amountInMaximum) {
            // The calculated cost is too high, simulating a swap failure.
            return 0;
        }


        // --- 2. Simulate Balance Changes (Net Effect on msg.sender - Positions.sol) ---

        // a) Remove amountIn of _tokenIn from msg.sender (Positions.sol)
        uint256 currentBalanceIn = IERC20(_tokenIn).balanceOf(msg.sender);
        uint256 newBalanceIn = currentBalanceIn - amountIn;
        writeTokenBalance(msg.sender, _tokenIn, newBalanceIn);

        // b) Send _amountOut of _tokenOut to msg.sender (Positions.sol)
        uint256 currentBalanceOut = IERC20(_tokenOut).balanceOf(msg.sender);
        uint256 newBalanceOut = currentBalanceOut + _amountOut;
        writeTokenBalance(msg.sender, _tokenOut, newBalanceOut);

        return amountIn;
    }
}
