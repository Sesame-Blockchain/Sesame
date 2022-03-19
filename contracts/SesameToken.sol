// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ISesame} from "./interfaces/ISesame.sol";

contract SesameToken is ERC20, AccessControl, ISesame {
    uint256 public immutable override SUPPLY_CAP = 100000000 ether;
    uint256 public override burned;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /**
     * @notice Constructor
     */
    constructor() ERC20("Sesame", "SESA") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Mint Sesame tokens
     * @param account address to receive tokens
     * @param amount amount to mint
     * @return status true if mint is successful, false if not
     */
    function mint(address account, uint256 amount)
        external
        override
        onlyRole(MINTER_ROLE)
        returns (bool status)
    {
        if (totalSupply() + amount <= SUPPLY_CAP) {
            _mint(account, amount);
            return true;
        }
        return false;
    }

    /** @notice HotPot can burn token after repurchase */
    function burn(uint256 amount) external override onlyRole(BURNER_ROLE) {
        _burn(_msgSender(), amount);
        burned += amount;
    }
}
