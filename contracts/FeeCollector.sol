// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IRewardConvertor} from "./interfaces/IRewardConvertor.sol";
import {IWBNB} from "./interfaces/IWBNB.sol";

/**
 * @title FeeCollector
 * @notice It receives and distribuet fees to staking addresses
 */
contract FeeCollector is ReentrancyGuard, AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    // Operator role
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    IERC20 public immutable sesameToken;

    IERC20 public immutable rewardToken;

    // Reward convertor (tool to convert other currencies to rewardToken)
    IRewardConvertor public rewardConvertor;

    // Set of addresses that are staking only the fee sharing
    EnumerableSet.AddressSet private _feeStakingAddresses;
    uint256 private _totalShares;
    mapping(address => uint256) public shares;

    event ConversionToRewardToken(
        address indexed token,
        uint256 amountConverted,
        uint256 amountReceived
    );
    event FeeStakingAddressesAdded(
        address[] feeStakingAddresses,
        uint256[] shares
    );
    event FeeStakingAddressesRemoved(address[] feeStakingAddresses);
    event NewRewardConvertor(address rewardConvertor);
    event CollectRewardToken(address by, uint256 amount);

    /**
     * @notice Constructor
     * @param _sesameToken address of Sesame token
     * @param _rewardToken address of reward token (WBNB)
     */
    constructor(address _sesameToken, address _rewardToken) {
        rewardToken = IERC20(_rewardToken);
        sesameToken = IERC20(_sesameToken);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Collect all reward token as defined by shares.
     * Other currency must be manually converted to reward token
     * to be withdrawn.
     */
    function collect() public onlyRole(OPERATOR_ROLE) {
        // Check if there is any address eligible for fee-sharing only
        uint256 numberAddressesForFeeStaking = _feeStakingAddresses.length();
        require(numberAddressesForFeeStaking > 0, "No addresses");
        require(_totalShares > 0, "Shares undefined");

        // Calculate the reward to distribute as the balance held by this address
        uint256 reward = rewardToken.balanceOf(address(this));
        require(reward != 0, "Reward: Nothing to distribute");

        // If there are eligible addresses for fee-sharing only, calculate their shares
        for (uint256 i = 0; i < numberAddressesForFeeStaking; i++) {
            address addr = _feeStakingAddresses.at(i);
            uint256 amount = (shares[addr] * reward) / _totalShares;
            rewardToken.safeTransfer(addr, amount);
            emit CollectRewardToken(addr, amount);
        }
    }

    receive() external payable {}

    function convertToRewardToken(uint256 amount)
        external
        onlyRole(OPERATOR_ROLE)
    {
        require(amount <= address(this).balance);
        IWBNB(address(rewardToken)).deposit{value: amount}();
        emit ConversionToRewardToken(address(rewardToken), amount, amount);
    }

    /**
     * @notice Convert currencies to reward token
     * @dev Function only usable only for whitelisted currencies (where no potential side effect)
     * @param token address of the token to sell
     * @param minReceivable minimum amount to receive
     */
    function convertCurrencyToRewardToken(address token, uint256 minReceivable)
        external
        nonReentrant
        onlyRole(OPERATOR_ROLE)
    {
        require(
            address(rewardConvertor) != address(0),
            "Convert: RewardConvertor not set"
        );
        require(
            token != address(rewardToken),
            "Convert: Cannot be reward token"
        );

        uint256 amountToConvert = IERC20(token).balanceOf(address(this));
        require(amountToConvert != 0, "Convert: Amount to convert must be > 0");

        // Adjust allowance for this transaction only
        IERC20(token).safeIncreaseAllowance(
            address(rewardConvertor),
            amountToConvert
        );

        // Exchange token to reward token
        uint256 amountReceived = rewardConvertor.convert(
            token,
            address(rewardToken),
            amountToConvert,
            minReceivable
        );

        emit ConversionToRewardToken(token, amountToConvert, amountReceived);
    }

    /**
     * @notice Add staking addresses
     * @param _stakingAddresses array of addresses eligible for fee-sharing only
     */
    function addFeeStakingAddresses(
        address[] calldata _stakingAddresses,
        uint256[] calldata _shares
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _totalShares = 0;
        for (uint256 i = 0; i < _stakingAddresses.length; i++) {
            require(
                !_feeStakingAddresses.contains(_stakingAddresses[i]),
                "Owner: Address already registered"
            );
            _feeStakingAddresses.add(_stakingAddresses[i]);
            shares[_stakingAddresses[i]] = _shares[i];
            _totalShares += _shares[i];
        }

        emit FeeStakingAddressesAdded(_stakingAddresses, _shares);
    }

    /**
     * @notice Remove staking addresses
     * @param _stakingAddresses array of addresses eligible for fee-sharing only
     */
    function removeFeeStakingAddresses(address[] calldata _stakingAddresses)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        for (uint256 i = 0; i < _stakingAddresses.length; i++) {
            require(
                _feeStakingAddresses.contains(_stakingAddresses[i]),
                "Owner: Address not registered"
            );
            _feeStakingAddresses.remove(_stakingAddresses[i]);
            shares[_stakingAddresses[i]] = 0;
        }

        emit FeeStakingAddressesRemoved(_stakingAddresses);
    }

    /**
     * @notice Set reward convertor contract
     * @param _rewardConvertor address of the reward convertor (set to null to deactivate)
     */
    function setRewardConvertor(address _rewardConvertor)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        rewardConvertor = IRewardConvertor(_rewardConvertor);

        emit NewRewardConvertor(_rewardConvertor);
    }

    /**
     * @notice See addresses eligible for fee-staking
     */
    function viewFeeStakingAddresses()
        external
        view
        returns (address[] memory)
    {
        uint256 length = _feeStakingAddresses.length();

        address[] memory feeStakingAddresses = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            feeStakingAddresses[i] = _feeStakingAddresses.at(i);
        }

        return (feeStakingAddresses);
    }
}
