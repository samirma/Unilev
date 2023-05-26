// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@solmate/tokens/ERC20.sol";
import "@uniswapCore/contracts/interfaces/IUniswapV3Pool.sol";

/*
 * @title IMarket interface
 * @notice Interface for the Market contract
 * @dev Market will be the only entry point to interact with the protocol
 * @dev Since functions name are straightforward, no need to add NatSpec comments
 **/
interface IMarket {
    // --------------- Trader Zone ---------------
    function openPosition(
        address _v3Pool,
        address _token,
        bool _isShort,
        uint8 _leverage,
        uint128 _amount,
        uint160 _limitPrice,
        uint256 _stopLossPrice
    ) external;

    function closePosition(uint256 _posId) external;

    function editPosition(uint256 _posId, uint256 _newLstopLossPrice) external;

    function getTraderPositions(address _traderAdd) external view returns (uint256[] memory);

    // --------------- Liquidity Provider Zone ---------------
    function addLiquidity(address _poolAdd, uint256 _amount) external;

    function removeLiquidity(address _poolAdd, uint256 _amount) external;

    // --------------- Liquidator/Keeper Zone ---------------

    function liquidatePositions(uint256[] memory _posIds) external;

    function getLiquidablePositions() external view returns (uint256[] memory);

    // --------------- Admin Zone ---------------
    function createLiquidityPool(address _token) external;

    // Events
    event PositionOpened(
        uint256 indexed posId,
        address indexed trader,
        address indexed v3Pool,
        address token,
        uint256 amount,
        bool isShort,
        uint8 leverage,
        uint256 limitPrice,
        uint256 stopLossPrice
    );
    event PositionClosed(uint256 indexed posId, address indexed trader);
    event PositionEdited(uint256 indexed posId, address indexed trader, uint256 newStopLossPrice);
    event LiquidityAdded(
        address indexed poolAdd,
        address indexed liquidityProvider,
        uint256 assets
    );
    event LiquidityRemoved(
        address indexed poolAdd,
        address indexed liquidityProvider,
        uint256 shares
    );
    event PositionLiquidated(uint256 indexed posId, address indexed liquidator);
    event LiquidityPoolCreated(address indexed poolAdd, address sender);
    event PriceFeedAdded(address token, address priceFeed);
}
