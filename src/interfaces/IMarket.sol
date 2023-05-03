// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswapV3/contracts/interfaces/IUniswapV3Pool.sol";

interface IMarket {
    enum PositionStatus {
        OPEN,
        CLOSED,
        LIQUIDATED
    }

    struct PositionParams {
        IUniswapV3Pool v3Pool; // pool to trade
        IERC20 token; // token to trade => should be token0 or token1 of v3Pool
        uint256 value; // amount of token to trade
        bool isShort; // true if short, false if long
        uint8 leverage; // leverage of position => 0 if no leverage
        uint256 limitPrice; // limit order price => 0 if no limit order
        uint256 stopLossPrice; // stop loss price => 0 if no stop loss
        PositionStatus status; // status of position
    }

    // --------------- Trader Zone ---------------
    function openPosition(
        address _v3Pool,
        address _token,
        uint256 _value,
        bool _isShort,
        uint8 _leverage,
        uint256 _limitPrice,
        uint256 _stopLossPrice
    ) external;

    function closePosition(uint256 _posId) external;

    function editPosition(
        uint256 _posId,
        uint256 _newLimitPrice,
        uint256 _newLstopLossPrice
    ) external;

    // --------------- Liquidity Provider Zone ---------------
    function addLiquidity(address _poolAdd) external;

    function removeLiquidity(address _poolAdd) external;

    // --------------- Liquidator/Keeper Zone ---------------
    function liquidatePosition(uint256 _posId) external;

    function batchLiquidatePosition(uint256[] memory _posIds) external;

    function getLiquidablePositions() external view returns (uint256[] memory);

    // --------------- Admin Zone ---------------
    function createLiquidityPool(IUniswapV3Pool _v3Pool) external;

    // Events
    event PositionOpened(
        uint256 indexed posId,
        address indexed trader,
        address indexed v3Pool,
        address token,
        uint256 value,
        bool isShort,
        uint8 leverage,
        uint256 limitPrice,
        uint256 stopLossPrice
    );
    event PositionClosed(uint256 indexed posId, address indexed trader);
    event PositionEdited(
        uint256 indexed posId,
        address indexed trader,
        uint256 newLimitPrice,
        uint256 newStopLossPrice
    );
    event LiquidityAdded(
        address indexed poolAdd,
        address indexed liquidityProvider
    );
    event LiquidityRemoved(
        address indexed poolAdd,
        address indexed liquidityProvider
    );
    event PositionLiquidated(uint256 indexed posId, address indexed liquidator);
    event LiquidityPoolCreated(address indexed poolAdd);
}
