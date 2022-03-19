// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IAccountant.sol";
import "./interfaces/IGovernance.sol";
import "./interfaces/IProduct.sol";
import "./interfaces/IRandomNumberGenerator.sol";
import "./interfaces/IWBNB.sol";

contract SesameGame is IProduct, ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum STATE {
        CLOSED,
        OPEN,
        PENDING
    }
    mapping(uint256 => STATE) public state;

    IGovernance public governance;
    IRandomNumberGenerator public immutable rng;
    IAccountant public immutable accountant;
    AggregatorV3Interface public immutable priceFeed;
    IWBNB public immutable rewardToken;
    IERC20 public immutable gameToken;
    address payable public immutable collector;
    bool private immutable _native;

    uint256 public round;
    uint256 public lastRound;
    address public lastWinner;
    mapping(uint256 => address[]) public tickets;
    mapping(uint256 => mapping(address => uint256)) public ticketMap;
    mapping(uint256 => address) public winner;

    uint256 public immutable ticketPrice;
    uint256 public immutable ticketPerRound;
    uint256 public immutable feePercent = 5;

    uint256 public currentFees;
    uint256 public currentFund;
    uint256 public totalFeesCollected;
    uint256 public totalFeesEmitted;
    uint256 public totalFundCollected;
    uint256 public totalFundEmitted;
    string public version;

    event StartedRound(uint256 round);
    event EndedRound(uint256 round);
    event EnterTicket(address indexed player, uint256 round, uint256 tickets);
    event DeclareWinner(address indexed player, uint256 round, uint256 prize);
    event Refund(address indexed player, uint256 round, uint256 tickets);

    modifier onlyGovernance() {
        require(msg.sender == address(governance), "UNAUTHORIZED");
        _;
    }

    modifier onlyRNG() {
        require(msg.sender == address(rng), "UNAUTHORIZED");
        _;
    }

    constructor(
        address _governance,
        address _rewardToken,
        address _gameToken,
        address _priceFeed,
        uint256 _ticketPrice,
        uint256 _ticketPerRound,
        string memory _version
    ) {
        governance = IGovernance(_governance);
        rng = IRandomNumberGenerator(governance.randomNumberGenerator());
        accountant = IAccountant(governance.accountant());
        collector = payable(governance.feeCollector());

        _native = _rewardToken == _gameToken;
        rewardToken = IWBNB(_rewardToken);
        gameToken = IERC20(_gameToken);
        priceFeed = AggregatorV3Interface(_priceFeed);
        ticketPrice = _ticketPrice;
        ticketPerRound = _ticketPerRound;
        version = _version;
    }

    /**
     * @notice Players enters the current round and pays
     * for the number of tickets in native currency
     * @param ticket Number of tickets to enter
     */
    function enter(uint256 ticket) public payable nonReentrant {
        require(state[round] == STATE.OPEN, "NOT OPEN");
        if (_native)
            require(msg.value == ticket * netTicketPrice(), "BAD AMOUNT");

        if (ticket + tickets[round].length > ticketPerRound) {
            uint256 extra = ticket + tickets[round].length - ticketPerRound;
            ticket -= extra;

            // Product uses BNB, refund the extra part
            if (_native) {
                payable(msg.sender).transfer(extra * netTicketPrice());
                emit Refund(msg.sender, round, extra);
            }
        }

        // Product uses ERC20, do partial transfer
        if (!_native) {
            gameToken.safeTransferFrom(
                msg.sender,
                address(this),
                ticket * netTicketPrice()
            );
        }

        for (uint256 i = 0; i < ticket; i++) {
            tickets[round].push(msg.sender);
        }

        currentFund += ticket * ticketPrice;
        currentFees += ticket * feePerTicket();
        totalFundCollected += ticket * ticketPrice;
        totalFeesCollected += ticket * feePerTicket();
        ticketMap[round][msg.sender] += ticket;

        uint256 credit = getCredit(ticket * netTicketPrice());
        accountant.credit(msg.sender, credit, round, ticket);
        emit EnterTicket(msg.sender, round, ticket);
        if (tickets[round].length == ticketPerRound) {
            _endRound();
            _startRound();
        }
    }

    /**
     * @notice Callback for the random number generator
     * @param _rand Arary of random numbers
     */
    function pickWinner(uint256[] memory _rand, uint256 _round)
        external
        override
        onlyRNG
        nonReentrant
    {
        require(state[_round] == STATE.PENDING, "NOT OPEN");
        uint256 indexOfWinner = _rand[0] % ticketPerRound;
        address _winner = tickets[_round][indexOfWinner];
        winner[_round] = _winner;

        uint256 toWinner = ticketPerRound * ticketPrice;
        currentFund = 0;
        totalFundEmitted += toWinner;

        // Convert to reward rewardToken before transmit
        uint256 toShare = ticketPerRound * feePerTicket();
        currentFees = 0;
        totalFeesEmitted += toShare;

        if (_native) {
            payable(_winner).transfer(toWinner);
            rewardToken.deposit{value: toShare}();
            rewardToken.transfer(governance.feeCollector(), toShare);
        } else {
            gameToken.safeTransfer(_winner, toWinner);
            gameToken.safeTransfer(governance.feeCollector(), toShare);
        }

        lastWinner = _winner;
        emit DeclareWinner(_winner, _round, currentFund);

        lastRound = _round;
        _closeRound(_round);
    }

    /** @notice Activate product, only callable from governance */
    function activate() external override onlyGovernance {
        _startRound();
    }

    /** @notice Emergency: deactivate product, only callable from governance */
    function deactivate() external override onlyGovernance {
        require(state[round] != STATE.PENDING, "PENDING");
        _refund(round);
        _closeRound(round);

        // retrieve any remaining balance to avoid being trapped
        rewardToken.transfer(collector, rewardToken.balanceOf(address(this)));
        gameToken.safeTransfer(collector, gameToken.balanceOf(address(this)));
        selfdestruct(collector);
    }

    /** @notice Refund players of the given round */
    function _refund(uint256 _round) internal nonReentrant {
        for (uint256 i = 0; i < tickets[_round].length; i++) {
            address player = tickets[_round][i];
            uint256 amount = ticketMap[_round][player] * netTicketPrice();
            if (amount > 0) {
                ticketMap[_round][player] = 0;
                if (_native) {
                    payable(player).transfer(amount);
                } else {
                    gameToken.safeTransfer(player, amount);
                }
            }
        }
        totalFeesCollected -= currentFees;
        totalFundCollected -= currentFund;
        currentFees = 0;
        currentFund = 0;
    }

    /** @notice Start a new round */
    function _startRound() internal {
        round++;
        state[round] = STATE.OPEN;
        emit StartedRound(round);
    }

    /**
     * @notice Reached current round limit. Stop accepting
     * more ticket. Request random number.
     */
    function _endRound() internal {
        state[round] = STATE.PENDING;
        rng.requestRandomNumber(round);
        emit EndedRound(round);
    }

    /** @notice Mark current round closed, after picking winner */
    function _closeRound(uint256 _round) internal {
        state[_round] = STATE.CLOSED;
    }

    /** @notice Convert players' deposit to USD at market price */
    function getCredit(uint256 amount) public view returns (uint256) {
        return (amount * getPriceFeed()) / 1 ether;
    }

    /** @notice Get game rewardToken price quote in USD (18 decimals) */
    function getPriceFeed() public view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return uint256(price) * 10**10;
    }

    /** @notice Price and fee for each ticket */
    function netTicketPrice() public view returns (uint256) {
        return ticketPrice + feePerTicket();
    }

    /** @notice Fee for each ticket */
    function feePerTicket() public view returns (uint256) {
        return (ticketPrice * feePercent) / 100;
    }

    /** @notice Number of tickets in current round */
    function getTicketCount() external view returns (uint256 count) {
        return tickets[round].length;
    }

    /** @notice Number of tickets bought by player at given round */
    function getUserTicketCount(uint256 _round, address _player)
        external
        view
        returns (uint256 count)
    {
        return ticketMap[_round][_player];
    }
}
