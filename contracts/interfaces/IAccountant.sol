// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IAccountant {
    function credit(
        address player,
        uint256 point,
        uint256 round,
        uint256 ticket
    ) external;
}
