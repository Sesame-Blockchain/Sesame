// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISesameCredit {
    function latestAnswer() external view returns (int256);

    function updateAnswer(int256 _answer) external;
}
