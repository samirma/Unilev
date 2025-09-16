// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Errors
error PriceFeedL1__TOKEN_NOT_SUPPORTED(address token);

contract PriceFeedL1 is Ownable {
    mapping(address => AggregatorV3Interface) public tokenToPriceFeedUSD;

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Add a token to the price feed.
     * Only the owner can add a token
     * The token must be supported by Chainlink
     * The price feed must be XXX/USD one (e.g. ETH/USD)
     * @param _token token address
     * @param _priceFeed price feed address
     */
    function addPriceFeed(address _token, address _priceFeed) external onlyOwner {
        tokenToPriceFeedUSD[_token] = AggregatorV3Interface(_priceFeed);
    }

    /**
     * @notice Returns the latest price of a token pair
     * @param _token0 token 0 address
     * @param _token1 token 1 address
     * @return int256 price of token 0 in terms of token 1
     */
    function getPairLatestPrice(address _token0, address _token1) public view returns (uint256) {
        return
            (getTokenLatestPriceInUSD(_token0) * (10 ** uint256(IERC20Metadata(_token1).decimals()))) /
            getTokenLatestPriceInUSD(_token1);
    }

    /**
     * @notice Returns the latest price of a token in USD, normalized to 18 decimals.
     * @param _token The token address.
     * @return uint256 The price in USD with 18 decimals.
     */
    function getTokenLatestPriceInUSD(address _token) public view returns (uint256) {
        AggregatorV3Interface priceFeed = tokenToPriceFeedUSD[_token];
        if (address(priceFeed) == address(0)) {
            revert PriceFeedL1__TOKEN_NOT_SUPPORTED(_token);
        }
        (, int256 price, , , ) = priceFeed.latestRoundData();
        uint8 decimals = priceFeed.decimals();
        return uint256(price) * 10**(18 - decimals);
    }

    /**
     * @notice Returns the USD in a human readable value of a given amount of a token.
     * @param _token The token address.
     * @param _amount The amount of the token (in its smallest unit, not human-readable format).
     * @return uint256 The value in USD, with 18 decimals of precision.
     */
    function getAmountInUSD(address _token, uint256 _amount) public view returns (uint256) {
        uint256 priceInUSD = getTokenLatestPriceInUSD(_token); // This is already normalized to 18 decimals
        uint8 tokenDecimals = IERC20Metadata(_token).decimals();
        return (_amount * priceInUSD) / (10**tokenDecimals);
    }

    function isPairSupported(address _token0, address _token1) public view returns (bool) {
        if (address(tokenToPriceFeedUSD[_token0]) == address(0)) {
            return false;
        }
        if (address(tokenToPriceFeedUSD[_token1]) == address(0)) {
            return false;
        }
        return true;
    }
}
