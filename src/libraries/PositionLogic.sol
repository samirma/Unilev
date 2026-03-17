// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IUniswapV3Factory, IUniswapV3Pool} from "../interfaces/IUniswapV3.sol";
import {PriceFeedL1} from "../PriceFeedL1.sol";
import {LiquidityPoolFactory} from "../LiquidityPoolFactory.sol";
import {
    Positions__POOL_NOT_OFFICIAL,
    Positions__TOKEN_NOT_SUPPORTED,
    Positions__NO_PRICE_FEED,
    Positions__LEVERAGE_NOT_IN_RANGE,
    Positions__TOKEN_NOT_SUPPORTED_ON_MARGIN,
    Positions__AMOUNT_TO_SMALL,
    Positions__LIMIT_ORDER_PRICE_NOT_CONCISTENT,
    Positions__STOP_LOSS_ORDER_PRICE_NOT_CONCISTENT
} from "./PositionTypes.sol";

library PositionLogic {
    struct ValidationParams {
        address token0;
        address token1;
        uint24 fee;
        uint8 leverage;
        uint256 amount;
        uint256 limitPrice;
        uint256 stopLossPrice;
        address liquidityPoolFactoryUniswapV3;
        address liquidityPoolFactory;
        address priceFeed;
        uint256 maxLeverage;
        uint256 minPositionAmountInUsd;
    }

    struct ValidationResult {
        uint256 price;
        address baseToken;
        address quoteToken;
        bool isBaseToken0;
        address v3Pool;
    }

    struct PnLCalculationParams {
        uint256 initialPrice;
        uint256 currentPrice;
        uint256 totalBorrow;
        uint128 collateralSize;
        uint8 leverage;
        bool isShort;
        address initialToken;
        address priceFeed;
        uint24 poolFee;
        address feeManager;
        address trader;
    }

    struct PnLCalculationResult {
        int128 currentPnL;
        int128 collateralLeft;
    }

    /**
     * @notice Calculate the PnL and collateral left for a position
     * @param params PnL calculation parameters
     * @return result Current PnL and collateral left
     * @dev PnL Calculation Logic:
     * - Long: profit when price goes UP (base token appreciates vs quote)
     * - Short: profit when price goes DOWN (base token depreciates vs quote)
     * - PnL = totalBorrow * priceChangePercent / 10000
     */
    function calculatePnL(
        PnLCalculationParams memory params
    ) internal view returns (PnLCalculationResult memory result) {
        // Calculate price change percentage
        int256 priceChangePercent;
        if (params.currentPrice > params.initialPrice) {
            priceChangePercent = int256((params.currentPrice - params.initialPrice) * 10000) / int256(params.initialPrice);
        } else {
            priceChangePercent = -int256((params.initialPrice - params.currentPrice) * 10000) / int256(params.initialPrice);
        }

        uint256 positionSize = uint256(params.collateralSize) * params.leverage;
        int256 rawPnl;
        if (params.isShort) {
            rawPnl = -int256(positionSize) * priceChangePercent / 10000;
        } else {
            rawPnl = int256(positionSize) * priceChangePercent / 10000;
        }

        int256 finalValue = int256(uint256(params.collateralSize)) + rawPnl;

        if (finalValue > 0 && params.poolFee > 0) {
            int256 swapFee = (finalValue * int256(uint256(params.poolFee))) / 1_000_000;
            finalValue -= swapFee;
        }

        if (finalValue > 0 && params.feeManager != address(0)) {
            (bool success, bytes memory data) = params.feeManager.staticcall(
                abi.encodeWithSignature("getFees(address)", params.trader)
            );
            if (success) {
                (uint128 treasureFee, ) = abi.decode(data, (uint128, uint128));
                int256 treasureDeduction = (finalValue * int256(uint256(treasureFee))) / 10000;
                finalValue -= treasureDeduction;
            }
        }

        result.currentPnL = int128(finalValue - int256(uint256(params.collateralSize)));
        result.collateralLeft = int128(finalValue);
    }

    function _getBaseValidationResult(
        ValidationParams memory params
    ) private view returns (ValidationResult memory result) {
        result.v3Pool = address(
            IUniswapV3Factory(params.liquidityPoolFactoryUniswapV3).getPool(
                params.token0,
                params.token1,
                params.fee
            )
        );

        // Cache pool contract to avoid repeated external calls
        IUniswapV3Pool pool = IUniswapV3Pool(result.v3Pool);

        if (pool.factory() != params.liquidityPoolFactoryUniswapV3) {
            revert Positions__POOL_NOT_OFFICIAL(result.v3Pool);
        }

        // Cache token addresses
        address poolToken0 = pool.token0();
        address poolToken1 = pool.token1();

        // check token
        if (poolToken0 != params.token0 && poolToken1 != params.token0) {
            revert Positions__TOKEN_NOT_SUPPORTED(params.token0);
        }

        uint256 token0UsdPrice = PriceFeedL1(params.priceFeed).getTokenLatestPriceInUsd(
            params.token0
        );
        bool isToken0Stable = (token0UsdPrice >= 0.9e18 && token0UsdPrice <= 1.1e18);

        if (isToken0Stable) {
            result.quoteToken = params.token0;
            result.baseToken = (params.token0 == poolToken0) ? poolToken1 : poolToken0;
        } else {
            result.baseToken = params.token0;
            result.quoteToken = (params.token0 == poolToken0) ? poolToken1 : poolToken0;
        }
        result.isBaseToken0 = (result.baseToken == poolToken0);

        // check if pair is supported by PriceFeed
        if (!PriceFeedL1(params.priceFeed).isPairSupported(result.baseToken, result.quoteToken)) {
            revert Positions__NO_PRICE_FEED(result.baseToken, result.quoteToken);
        }

        result.price = PriceFeedL1(params.priceFeed).getPairLatestPrice(
            result.baseToken,
            result.quoteToken
        );

        // check leverage
        if (params.leverage <= 1 || params.leverage > params.maxLeverage) {
            revert Positions__LEVERAGE_NOT_IN_RANGE(params.leverage);
        }

        // check amount
        uint256 humanReadableUsd = PriceFeedL1(params.priceFeed).getAmountInUsd(
            params.token0,
            params.amount
        ); // Returns value with 18 decimals
        if (humanReadableUsd < params.minPositionAmountInUsd) {
            revert Positions__AMOUNT_TO_SMALL(
                IERC20Metadata(params.token0).symbol(),
                humanReadableUsd,
                params.amount
            );
        }
    }

    function validateOpenLongPosition(
        ValidationParams memory params
    ) external view returns (ValidationResult memory result) {
        result = _getBaseValidationResult(params);

        if (
            LiquidityPoolFactory(params.liquidityPoolFactory).getTokenToLiquidityPools(
                result.quoteToken
            ) == address(0)
        ) {
            revert Positions__TOKEN_NOT_SUPPORTED_ON_MARGIN(result.quoteToken);
        }

        if (params.limitPrice < result.price && params.limitPrice != 0) {
            revert Positions__LIMIT_ORDER_PRICE_NOT_CONCISTENT(params.limitPrice);
        }
        if (params.stopLossPrice > result.price && params.stopLossPrice != 0) {
            revert Positions__STOP_LOSS_ORDER_PRICE_NOT_CONCISTENT(params.stopLossPrice);
        }
    }

    function validateOpenShortPosition(
        ValidationParams memory params
    ) external view returns (ValidationResult memory result) {
        result = _getBaseValidationResult(params);

        if (
            LiquidityPoolFactory(params.liquidityPoolFactory).getTokenToLiquidityPools(
                result.baseToken
            ) == address(0)
        ) {
            revert Positions__TOKEN_NOT_SUPPORTED_ON_MARGIN(result.baseToken);
        }

        if (params.limitPrice > result.price && params.limitPrice != 0) {
            revert Positions__LIMIT_ORDER_PRICE_NOT_CONCISTENT(params.limitPrice);
        }
        if (params.stopLossPrice < result.price && params.stopLossPrice != 0) {
            revert Positions__STOP_LOSS_ORDER_PRICE_NOT_CONCISTENT(params.stopLossPrice);
        }
    }
}
