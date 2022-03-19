// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IGovernance.sol";

/**
 * Accountant keeps track of users' activity (point) on each block,
 * defiend as dollar volume on the accounting period.
 * At the end of each period, a separate process scans the event
 * log and build a merkle tree to decide how fees are distributed.
 */
contract Accountant is Ownable {
    IGovernance governance;
    event Credit(
        address indexed player,
        address indexed product,
        uint256 indexed round,
        uint256 ticket,
        uint256 point
    );

    /**
     * @notice Must renounce ownership after setting governance contract.
     * This contract is forever bound to governance contract
     * @param _governance governance contract address
     */
    function setGovernance(address _governance) public onlyOwner {
        governance = IGovernance(_governance);
    }

    /**
     * @notice Active product can credit point for user.
     * Product is responsible to calculate point by converting
     * respective tokens into a single currency to be used as point
     * @param player Player who deposited in product contract
     * @param point Number of points converted from deposited token
     * @param round Current round of the product
     * @param ticket Number of ticket entered by player
     */
    function credit(
        address player,
        uint256 point,
        uint256 round,
        uint256 ticket
    ) external {
        require(governance.isProduct(_msgSender()) == true);
        emit Credit(player, _msgSender(), round, ticket, point);
    }
}
