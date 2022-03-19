// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IRandomNumberGenerator {
    function setGovernance(address _governance) external;

    function requestRandomNumber(uint256 _round) external;
}
