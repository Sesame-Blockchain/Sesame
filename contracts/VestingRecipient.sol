// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title VestingRecipient
 * @notice It vests the Sesame tokens to an owner over a predetermined schedule.
 * Other tokens can be withdrawn at any time.
 */
contract VestingRecipient is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public immutable sesameToken;

    event Withdraw(address indexed currency, uint256 amount);

    constructor(address _sesameToken) {
        sesameToken = _sesameToken;
    }

    /** @notice Withdraw Sesame to the owner */
    function withdrawSesame() external nonReentrant onlyOwner {
        _withdraw(sesameToken);
    }

    /**
     * @notice Withdraw any currency to the owner
     * @param _currency address of the currency to withdraw
     */
    function withdrawOtherCurrency(address _currency)
        external
        nonReentrant
        onlyOwner
    {
        require(_currency != sesameToken, "Owner: Cannot withdraw Sesame");
        _withdraw(_currency);
    }

    function _withdraw(address _currency) internal {
        uint256 balanceToWithdraw = IERC20(_currency).balanceOf(address(this));

        // Transfer token to owner if not null
        require(balanceToWithdraw != 0, "Owner: Nothing to withdraw");
        IERC20(_currency).safeTransfer(msg.sender, balanceToWithdraw);

        emit Withdraw(_currency, balanceToWithdraw);
    }
}
