// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "./interfaces/IGovernance.sol";
import "./interfaces/IProduct.sol";

contract RandomNumberGenerator is VRFConsumerBaseV2, Ownable {
    uint32 numWords;
    uint16 requestConfirmations;
    uint32 callbackGasLimit;
    uint64 subscriptionId;
    bytes32 keyhash;

    IGovernance governance;
    VRFCoordinatorV2Interface immutable coordinator;
    mapping(uint256 => Request) public requestMap;
    struct Request {
        address product;
        uint256 round;
    }

    event SetGovernance(address indexed by, address governance);
    event SetNumWords(address indexed by, uint32 numWords);
    event SetRequestConfirmations(address indexed by, uint16 blocks);
    event SetCallbackGasLimit(address indexed by, uint32 gasLimit);
    event SetSubscriptionId(address indexed by, uint64 subscriptionId);
    event SetGasLaneKeyHash(address indexed by, bytes32 keyHash);
    event RequestRandomNumber(address indexed requester, uint256 round, uint256 requestId);
    event AcquireRandomNumber(address indexed requester, uint256 round, uint256 requestId);

    constructor(address _vrfCoordinator) VRFConsumerBaseV2(_vrfCoordinator) {
        coordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
    }

    /**
     * @notice Must renounce ownership after setting governance contract.
     * This contract is forever bound to governance contract
     * @param _governance governance contract address
     */
    function setGovernance(address _governance) public onlyOwner {
        governance = IGovernance(_governance);
        emit SetGovernance(_msgSender(), _governance);
    }

    /**
     * @notice Set number of random number to request. Most product
     * only needs one unless new product requires more
     * @param _numWords Number of random numbers to request
     */
    function setNumWords(uint32 _numWords) public {
        require(governance.isVoter(_msgSender()) == true, "Unauthorized");
        numWords = _numWords;
        emit SetNumWords(_msgSender(), _numWords);
    }

    /**
     * @notice Set of number of block confirmations for each random
     * number. Fewer blocks means faster speed and higher risk
     * @param _blocks Number of blocks
     */
    function setRequestConfirmations(uint16 _blocks) public {
        require(governance.isVoter(_msgSender()) == true, "Unauthorized");
        requestConfirmations = _blocks;
        emit SetRequestConfirmations(_msgSender(), _blocks);
    }

    /**
     * @notice Adjust gas limit for VRF callback. This may be required
     * if more complex product logic is launched
     * @param _gasLimit New gas limit
     */
    function setCallbackGasLimit(uint32 _gasLimit) public {
        require(governance.isVoter(_msgSender()) == true, "Unauthorized");
        callbackGasLimit = _gasLimit;
        emit SetCallbackGasLimit(_msgSender(), _gasLimit);
    }

    /**
     * @notice Set Chainlink VRF subscription ID
     * @param _id Subscription ID
     */
    function setSubscriptionId(uint64 _id) public {
        require(governance.isVoter(_msgSender()) == true, "Unauthorized");
        subscriptionId = _id;
        emit SetSubscriptionId(_msgSender(), _id);
    }

    /**
     * @notice Set gas price lane
     * @param _keyHash Chainlink gas lane hash
     */
    function setKeyHash(bytes32 _keyHash) public {
        require(governance.isVoter(_msgSender()) == true, "Unauthorized");
        keyhash = _keyHash;
        emit SetGasLaneKeyHash(_msgSender(), _keyHash);
    }

    /**
     * @notice Only callable by active product contracts. Cache a mapping
     * from request ID to product address to be used by the callback
     */
    function requestRandomNumber(uint256 round) external {
        require(governance.isProduct(_msgSender()) == true, "Unauthorized");
        uint256 requestId = coordinator.requestRandomWords(
            keyhash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        requestMap[requestId] = Request(_msgSender(), round);
        emit RequestRandomNumber(_msgSender(), round, requestId);
    }

    /**
     * @notice Internally called by the VRF coordinator
     * @param _requestId Used to identify product contract
     * @param _rand Arary of random numbers
     */
    function fulfillRandomWords(uint256 _requestId, uint256[] memory _rand)
        internal
        override
    {
        require(_rand[0] > 0, "VRF failed!");
        Request memory req = requestMap[_requestId];
        IProduct(req.product).pickWinner(_rand, req.round);
        emit AcquireRandomNumber(req.product, req.round, _requestId);
    }
}
