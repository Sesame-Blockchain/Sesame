// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRewardConvertor} from "./interfaces/IRewardConvertor.sol";
import {ISesame} from "./interfaces/ISesame.sol";

/**
 * @notice The HotPot contracts receives 2% of fee and use the proceed
 * to repurchase Sesame tokens and burn them (hence the name hot pot).
 * The objective of this contract is to stabilize and support Sesame price
 * when needed. Admin has full control on when and how much to repurchase
 * and burn. Withdrawral of the proceed as profit is forbidden until
 * sufficient amount has been burned.
 */
contract HotPot is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IRewardConvertor public rewardConvertor;
    address public immutable sesameToken;
    address public immutable rewardToken;

    /** @notice allow withdraw only when total supply drops below the threshold */
    uint256 public immutable safetyThreshold;

    event NewRewardConvertor(address rewardConvertor);
    event RepurchaseSesame(uint256 sold, uint256 bought);
    event BurnedSesame(uint256 amount);
    event WithdrawSesameToken(uint256 amount);
    event WithdrawRewardToken(uint256 amount);

    constructor(
        address _sesameToken,
        address _rewardToken,
        uint256 _safetyThreshold
    ) {
        sesameToken = _sesameToken;
        rewardToken = _rewardToken;
        safetyThreshold = _safetyThreshold;
    }

    /**
     * @notice Set reward convertor contract
     * @param _rewardConvertor address of the reward convertor (set to null to deactivate)
     */
    function setRewardConvertor(address _rewardConvertor) external onlyOwner {
        rewardConvertor = IRewardConvertor(_rewardConvertor);
        emit NewRewardConvertor(_rewardConvertor);
    }

    /**
     * @notice Repurchase Sesame token from the open market
     * @param amountToSell amount of reward token (WBNB) to sell
     * @param amountToReceive minimum Sesame token to receive
     */
    function repurchase(uint256 amountToSell, uint256 amountToReceive)
        external
        nonReentrant
        onlyOwner
        returns (uint256 amount)
    {
        uint256 bought = rewardConvertor.convert(
            rewardToken,
            sesameToken,
            amountToSell,
            amountToReceive
        );

        emit RepurchaseSesame(amountToSell, bought);
        return bought;
    }

    /**
     * @notice Burn repurchased token
     * @param amount amount to burn
     */
    function burn(uint256 amount) external onlyOwner {
        ISesame(sesameToken).burn(amount);
        emit BurnedSesame(amount);
    }

    /**
     * @notice Withdraw Sesame token for team use. Only
     * allowed when total supply is lower than safety threshold
     * @param amount Amount of Sesame token to withdraw
     */
    function withdrawSesameToken(uint256 amount)
        external
        nonReentrant
        onlyOwner
    {
        require(ISesame(sesameToken).burned() >= safetyThreshold);
        require(IERC20(sesameToken).balanceOf(address(this)) >= amount);
        IERC20(sesameToken).safeTransfer(_msgSender(), amount);
        emit WithdrawSesameToken(amount);
    }

    /**
     * @notice Withdraw reward token (WBNB) for team use. Only
     * allowed when total supply is lower than safety threshold
     * @param amount Amount of reward token (WBNB) to withdraw
     */
    function withdrawRewardToken(uint256 amount)
        external
        nonReentrant
        onlyOwner
    {
        require(ISesame(sesameToken).burned() >= safetyThreshold);
        require(IERC20(rewardToken).balanceOf(address(this)) >= amount);
        IERC20(rewardToken).safeTransfer(_msgSender(), amount);
        emit WithdrawRewardToken(amount);
    }
}
