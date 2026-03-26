// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract FeeManager is Ownable {
    struct FeeParams {
        uint128 treasureFee;
        uint128 liquidationReward;
        bool isCustom;
    }

    // Default fees - packed into a single slot
    uint128 public defaultTreasureFee;
    uint128 public defaultLiquidationReward;

    // Position Life Time (timestamp-based - kept for backward compatibility)
    uint64 public defaultPositionLifeTime = uint64(30 days);
    mapping(address => uint64) public customLifeTimes;
    
    // Position Life Time (block-based - more manipulation-resistant)
    uint256 public constant AVG_BLOCK_TIME = 12 seconds; // Ethereum average block time
    uint64 public defaultPositionLifeBlocks = uint64((30 days) / 12 seconds); // ~216000 blocks
    mapping(address => uint64) public customLifeBlocks;

    // Mapping from trader address to their custom fees
    mapping(address => FeeParams) public customFees;

    event CustomFeeSet(address indexed trader, uint128 treasureFee, uint128 liquidationReward);
    event CustomFeeRemoved(address indexed trader);
    event DefaultFeesUpdated(uint128 treasureFee, uint128 liquidationReward);

    constructor(
        uint128 _defaultTreasureFee,
        uint128 _defaultLiquidationReward
    ) Ownable(msg.sender) {
        defaultTreasureFee = _defaultTreasureFee;
        defaultLiquidationReward = _defaultLiquidationReward;
    }

    /**
     * @notice Set custom fees for a trader (Add or Update)
     * @param _trader The address of the trader
     * @param _treasureFee The custom treasure fee
     * @param _liquidationReward The custom liquidation reward
     */
    function setCustomFees(
        address _trader,
        uint128 _treasureFee,
        uint128 _liquidationReward
    ) external onlyOwner {
        customFees[_trader] = FeeParams({
            treasureFee: _treasureFee,
            liquidationReward: _liquidationReward,
            isCustom: true
        });
        emit CustomFeeSet(_trader, _treasureFee, _liquidationReward);
    }

    /**
     * @notice Remove custom fees for a trader, reverting them to default
     * @param _trader The address of the trader to remove custom fees from
     */
    function removeCustomFees(address _trader) external onlyOwner {
        delete customFees[_trader];
        emit CustomFeeRemoved(_trader);
    }

    /**
     * @notice Update the default fees
     * @param _treasureFee The new default treasure fee
     * @param _liquidationReward The new default liquidation reward
     */
    function setDefaultFees(uint128 _treasureFee, uint128 _liquidationReward) external onlyOwner {
        defaultTreasureFee = _treasureFee;
        defaultLiquidationReward = _liquidationReward;
        emit DefaultFeesUpdated(_treasureFee, _liquidationReward);
    }

    /**
     * @notice Set the default position life time
     * @param _defaultPositionLifeTime The new default position life time
     */
    function setDefaultPositionLifeTime(uint64 _defaultPositionLifeTime) external onlyOwner {
        defaultPositionLifeTime = _defaultPositionLifeTime;
    }

    /**
     * @notice Set a custom position life time for a specific address
     * @param _trader The trader address
     * @param _lifeTime The custom life time
     */
    function setCustomPositionLifeTime(address _trader, uint64 _lifeTime) external onlyOwner {
        customLifeTimes[_trader] = _lifeTime;
    }

    /**
     * @notice Remove the custom position life time for a specific address
     * @param _trader The trader address
     */
    function removeCustomPositionLifeTime(address _trader) external onlyOwner {
        delete customLifeTimes[_trader];
    }

    /**
     * @notice Get the position life time for a trader
     * @param _trader The trader address
     * @return The position life time in seconds
     */
    function getPositionLifeTime(address _trader) external view returns (uint64) {
        if (customLifeTimes[_trader] != 0) {
            return customLifeTimes[_trader];
        }
        return defaultPositionLifeTime;
    }
    
    /**
     * @notice Get the position life time in blocks for a trader
     * @param _trader The trader address
     * @return The position life time in blocks
     */
    function getPositionLifeBlocks(address _trader) external view returns (uint64) {
        if (customLifeBlocks[_trader] != 0) {
            return customLifeBlocks[_trader];
        }
        return defaultPositionLifeBlocks;
    }
    
    /**
     * @notice Set the default position life time in blocks
     * @param _defaultPositionLifeBlocks The new default position life time in blocks
     */
    function setDefaultPositionLifeBlocks(uint64 _defaultPositionLifeBlocks) external onlyOwner {
        defaultPositionLifeBlocks = _defaultPositionLifeBlocks;
    }
    
    /**
     * @notice Set a custom position life time in blocks for a specific address
     * @param _trader The trader address
     * @param _lifeBlocks The custom life time in blocks
     */
    function setCustomPositionLifeBlocks(address _trader, uint64 _lifeBlocks) external onlyOwner {
        customLifeBlocks[_trader] = _lifeBlocks;
    }
    
    /**
     * @notice Remove the custom position life time in blocks for a specific address
     * @param _trader The trader address
     */
    function removeCustomPositionLifeBlocks(address _trader) external onlyOwner {
        delete customLifeBlocks[_trader];
    }

    /**
     * @notice Get the fees for a trader (custom if enabled, default otherwise)
     * @param _trader The address of the trader
     * @return treasureFee The applicable treasure fee
     * @return liquidationReward The applicable liquidation reward
     */
    function getFees(
        address _trader
    ) external view returns (uint128 treasureFee, uint128 liquidationReward) {
        if (customFees[_trader].isCustom) {
            return (customFees[_trader].treasureFee, customFees[_trader].liquidationReward);
        }
        return (defaultTreasureFee, defaultLiquidationReward);
    }
}
