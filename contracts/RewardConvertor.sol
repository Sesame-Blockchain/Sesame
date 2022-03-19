// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {IPancakeRouter01} from "./interfaces/IPancakeRouter01.sol";

contract RewardConvertor {
    IPancakeRouter01 public immutable router;

    constructor(address _router) {
        router = IPancakeRouter01(_router);
    }

    function convert(
        address tokenToSell,
        address tokenToBuy,
        uint256 amountToSell,
        uint256 minReceivable
    ) external returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = tokenToSell;
        path[1] = tokenToBuy;
        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountToSell,
            minReceivable,
            path,
            msg.sender,
            block.timestamp + 60
        );
        return amounts[0];
    }
}
