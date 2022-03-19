// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IGovernance {
    function isVoter(address _voter) external view returns (bool);

    function isProduct(address _product) external view returns (bool);

    function accountant() external view returns (address);

    function feeCollector() external view returns (address);

    function randomNumberGenerator() external view returns (address);
}
