// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract FeeManager is Ownable {
    struct FeeParams {
        uint256 treasureFee;
        uint256 liquidationReward;
        bool isCustom;
    }

    // Default fees
    uint256 public defaultTreasureFee;
    uint256 public defaultLiquidationReward;

    // Mapping from trader address to their custom fees
    mapping(address => FeeParams) public customFees;

    event CustomFeeSet(address indexed trader, uint256 treasureFee, uint256 liquidationReward);
    event CustomFeeRemoved(address indexed trader);
    event DefaultFeesUpdated(uint256 treasureFee, uint256 liquidationReward);

    constructor(
        uint256 _defaultTreasureFee,
        uint256 _defaultLiquidationReward
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
        uint256 _treasureFee,
        uint256 _liquidationReward
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
    function setDefaultFees(uint256 _treasureFee, uint256 _liquidationReward) external onlyOwner {
        defaultTreasureFee = _treasureFee;
        defaultLiquidationReward = _liquidationReward;
        emit DefaultFeesUpdated(_treasureFee, _liquidationReward);
    }

    /**
     * @notice Get the fees for a trader (custom if enabled, default otherwise)
     * @param _trader The address of the trader
     * @return treasureFee The applicable treasure fee
     * @return liquidationReward The applicable liquidation reward
     */
    function getFees(
        address _trader
    ) external view returns (uint256 treasureFee, uint256 liquidationReward) {
        FeeParams memory params = customFees[_trader];
        if (params.isCustom) {
            return (params.treasureFee, params.liquidationReward);
        } else {
            return (defaultTreasureFee, defaultLiquidationReward);
        }
    }
}
