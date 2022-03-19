// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRewardConvertor {
    function convert(
        address tokenToSell,
        address tokenToBuy,
        uint256 amountToSell,
        uint256 minReceivable
    ) external returns (uint256);
}
