// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";
import "./interfaces/IGovernance.sol";

/**
 * @title SesamePriceFeed
 * @notice Set a fixed conversion rate from Sesame token
 * to credit to be used by the Accountant
 */
contract SesameCredit is AggregatorV2V3Interface, Ownable {
    uint256 public constant override version = 0;
    IGovernance governance;
    uint8 public override decimals = 8;
    int256 public override latestAnswer;
    uint256 public override latestTimestamp;
    uint256 public override latestRound;

    mapping(uint256 => int256) public override getAnswer;
    mapping(uint256 => uint256) public override getTimestamp;
    mapping(uint256 => uint256) private getStartedAt;

    event SetGovernance(address indexed by, address governance);
    event UpdateAnswer(address indexed by, int256 answer);

    /**
     * @notice Must renounce ownership after setting governance contract.
     * This contract is forever bound to governance contract
     * @param _governance governance contract address
     */
    function setGovernance(address _governance) external onlyOwner {
        governance = IGovernance(_governance);
        emit SetGovernance(_msgSender(), _governance);
    }

    function updateAnswer(int256 _answer) external {
        require(_msgSender() == address(governance), "Unauthorized");
        latestAnswer = _answer;
        latestTimestamp = block.timestamp;
        latestRound++;
        getAnswer[latestRound] = _answer;
        getTimestamp[latestRound] = block.timestamp;
        getStartedAt[latestRound] = block.timestamp;
        emit UpdateAnswer(_msgSender(), _answer);
    }

    function getRoundData(uint80 _roundId)
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (
            _roundId,
            getAnswer[_roundId],
            getStartedAt[_roundId],
            getTimestamp[_roundId],
            _roundId
        );
    }

    function latestRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (
            uint80(latestRound),
            getAnswer[latestRound],
            getStartedAt[latestRound],
            getTimestamp[latestRound],
            uint80(latestRound)
        );
    }

    function description() external pure override returns (string memory) {
        return "v0.6/tests/MockV3Aggregator.sol";
    }
}
