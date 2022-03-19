// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IProduct {
    function pickWinner(uint256[] memory _rand, uint256 _round) external;

    function activate() external;

    function deactivate() external;
}
