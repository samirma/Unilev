// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@solmate/tokens/ERC20.sol";

// Errors
error PriceFeedL1__TOKEN_NOT_SUPPORTED(address token);

contract PriceFeedL1 is Ownable {
    mapping(address => AggregatorV3Interface) public tokenToPriceFeed;

    constructor(address _owner) {
        transferOwnership(_owner);
    }

    /**
     * @notice Add a token to the price feed.
     *         Only the owner can add a token
     *         The token must be supported by Chainlink
     *         The price feed must be XXX/USD one (e.g. ETH/USD)
     * @param _token token address
     * @param _priceFeed price feed address
     */
    function addPriceFeed(
        address _token,
        address _priceFeed
    ) external onlyOwner {
        tokenToPriceFeed[_token] = AggregatorV3Interface(_priceFeed);
        emit PriceFeedAdded(_token, _priceFeed);
    }

    /**
     * @notice Returns the latest price of a token pair
     * @param _token0 token 0 address
     * @param _token1 token 1 address
     * @return int256 price of token 0 in terms of token 1
     */
    function getLatestPrice(
        address _token0,
        address _token1
    ) public view returns (uint256) {
        if (address(tokenToPriceFeed[_token0]) == address(0)) {
            revert PriceFeedL1__TOKEN_NOT_SUPPORTED(_token0);
        }
        if (address(tokenToPriceFeed[_token1]) == address(0)) {
            revert PriceFeedL1__TOKEN_NOT_SUPPORTED(_token1);
        }

        // prettier-ignore
        (
            /* uint80 roundID */,
            int256 priceToken0,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = AggregatorV3Interface(tokenToPriceFeed[_token0]).latestRoundData();

        // prettier-ignore
        (
            /* uint80 roundID */,
            int256 priceToken1,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = AggregatorV3Interface(tokenToPriceFeed[_token1]).latestRoundData();
        return
            (uint256(priceToken0) * uint256(ERC20(_token1).decimals())) /
            uint256(priceToken1);
    }

    function isPairSupported(
        address _token0,
        address _token1
    ) public view returns (bool) {
        if (address(tokenToPriceFeed[_token0]) == address(0)) {
            return false;
        }
        if (address(tokenToPriceFeed[_token1]) == address(0)) {
            return false;
        }
        return true;
    }

    // Events
    event PriceFeedAdded(address token, address priceFeed);
}
