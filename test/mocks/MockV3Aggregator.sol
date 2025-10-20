// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title MockV3Aggregator
 * @notice Based on the FluxAggregator contract
 * @notice Use this contract when you need to test
 * other contract's ability to read data from an
 * aggregator contract, but how the aggregator got
 * its answer is unimportant
 */
contract MockV3Aggregator {

    uint8 public decimals;
    int256 initialAnswer;

    constructor(uint8 _decimals, int256 _initialAnswer) {
        decimals = _decimals;
        _initialAnswer = initialAnswer;
    }

}
