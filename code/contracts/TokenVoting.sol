pragma solidity ^0.5.4;

import "./math/SafeMath.sol";
import "./access/ReentrancyGuard.sol";
import "./SecurityToken.sol";

/**
 * @title Implements partition-based voting for ERC-1400 security tokens.
 */
contract TokenVoting is ReentrancyGuard {

    using SafeMath for uint256;

    // Represents an empty vote entry
    bytes32 private constant EMPTY_VOTE = bytes32(uint256(1));

    // Represents an empty bytes32 struct
    bytes32 private constant ZERO_BYTES32 = bytes32(0);

    // Possible states of the voting process
    uint8 private constant VOTING_OPEN = 1;
    uint8 private constant VOTING_CLOSED = 2;

    /**
    Contains the vote submitted on a security token.
    The hierarchy is as follows:
    - The address of the smart contract.
    - The partition in which the voting process takes place.
    - The topic under debate within that specific partition.
    - The point in time of the voting process. This is an Ethereum Transaction Block Number.
    - The vote value submitted the sender (voter).
     */
    mapping (address => mapping (bytes32 => mapping (bytes32 => mapping (uint256 => mapping (address => bytes32))))) 
    private _votes;

    mapping (address => mapping (bytes32 => mapping (bytes32 => mapping (uint256 => mapping (bytes32 => uint256))))) 
    private _voteCounts;

    mapping (address => mapping (bytes32 => mapping (bytes32 => mapping (uint256 => bytes32[])))) 
    private _votingOptions;

    mapping (address => mapping (bytes32 => mapping (bytes32 => mapping (uint256 => address[])))) 
    private _voters;

    mapping (address => mapping (bytes32 => mapping (bytes32 => mapping (uint256 => uint8)))) 
    private _state;

    mapping (address => mapping (bytes32 => mapping (bytes32 => mapping (uint256 => uint256)))) 
    private _votingDeadline;

    event VoteCreated(
        address indexed tokenAddress,
        bytes32 indexed partition, 
        bytes32 topic, 
        uint256 indexed blockNumber, 
        address createdBy,
        uint256 deadline
    );

    event VoteSubmitted(
        address indexed tokenAddress,
        bytes32 indexed partition, 
        bytes32 topic, 
        uint256 indexed blockNumber, 
        bytes32 vote,
        address submittedBy
    );

    modifier controllableTokenOnly(SecurityToken securityToken, address senderAddr) {
        require(securityToken.isControllable(), 
        "The security token is not controllable. Cannot initiate a voting process on this token.");

        require(securityToken.isController(senderAddr), 
        "Only the Controller is allowed to initiate a voting process on the security token.");
        _;
    }

    /**
     * @notice Allows a token controller to initiate a voting process on a given topic and partition
     * @param securityToken The security token
     * @param partition The partition under debate
     * @param topic The topic under debate
     * @param blockNumber The Ethereum block number (point in time)
     * @param options The list of possible voting options
     * @param targetAudience The list of addresses that will participate in the voting process
     * @param durationInSeconds The duration in seconds of the voting process (TTL - Time to live). 
                                Pass zero if the voting does not require a deadline.
     */
    function createVote(
        SecurityToken securityToken,
        bytes32 partition, 
        bytes32 topic, 
        uint256 blockNumber, 
        bytes32[] memory options, 
        address[] memory targetAudience,
        uint256 durationInSeconds
        ) public 
            nonReentrant 
            controllableTokenOnly(securityToken, msg.sender) {

        address tokenAddress = address(securityToken);

        // Validate the voting options
        require(options.length > 1, "The voting options are required. You must define two voting options at least.");
        require(targetAudience.length > 0, "The target audience is required");

        // Make sure we are not debating the same thing over and over again (token + partition + topic + blocknumber)
        require(!isValidContext(tokenAddress, partition, topic, blockNumber), "The voting proposal already exists.");

        // Make sure the controller does not introduce an invalid voting option
        for (uint256 i = 0; i < options.length; i++) {
            require(options[i] != ZERO_BYTES32, "The voting option cannot be zero bytes");
            require(options[i] != EMPTY_VOTE, "The voting option cannot be an empty vote");
        }

        // Make sure the controller does not introduce duplicate addresses
        for (uint256 i = 0; i < targetAudience.length; i++) {
            require(_votes[tokenAddress][partition][topic][blockNumber][targetAudience[i]] == ZERO_BYTES32, 
            "Duplicate voter. The voter already exists.");

            _votes[tokenAddress][partition][topic][blockNumber][targetAudience[i]] = EMPTY_VOTE;
        }

        // Set voters and options
        _votingOptions[tokenAddress][partition][topic][blockNumber] = options;
        _voters[tokenAddress][partition][topic][blockNumber] = targetAudience;

        // The caller will set the duration to zero if voting does not require a deadline
        uint256 closeTimeInUtc = (durationInSeconds > 0) ? now + durationInSeconds * 1 seconds : 0;

        // Enable voting        
        _state[tokenAddress][partition][topic][blockNumber] = VOTING_OPEN;
        _votingDeadline[tokenAddress][partition][topic][blockNumber] = closeTimeInUtc;

        // Emit the event
        emit VoteCreated(tokenAddress, partition, topic, blockNumber, msg.sender, closeTimeInUtc);
    }

    /**
     * @notice Allows a token controller to add more voters in case the audience is too large. 
     *         Call this function if you want to split the target audience in chunks, avoiding an out-of-gas scenario.
     * @param securityToken The security token
     * @param partition The partition under debate
     * @param topic The topic under debate
     * @param blockNumber The Ethereum block number (point in time)
     * @param targetAudience The list of addresses to add to the voting process
     */
    function appendVoters(
        SecurityToken securityToken,
        bytes32 partition, 
        bytes32 topic, 
        uint256 blockNumber, 
        address[] memory targetAudience
        ) public 
        nonReentrant 
        controllableTokenOnly(securityToken, msg.sender) {

        require(targetAudience.length > 0, "The target audience is required");

        address tokenAddress = address(securityToken);
        require(isValidContext(tokenAddress, partition, topic, blockNumber), "Invalid voting context.");

        // Check the current state of the voting process
        require(!votingIsClosed(tokenAddress, partition, topic, blockNumber), 
        "Voting is closed. Cannot append voters.");

        for (uint256 i = 0; i < targetAudience.length; i++) {
            // Make sure the controller does not append invalid voters
            require(_votes[tokenAddress][partition][topic][blockNumber][targetAudience[i]] == ZERO_BYTES32, 
            "Duplicate voter. The voter already exists.");

            // Apply state changes
            _votes[tokenAddress][partition][topic][blockNumber][targetAudience[i]] = EMPTY_VOTE;
            _voters[tokenAddress][partition][topic][blockNumber].push(targetAudience[i]);
        }
    }

    /**
     * @notice Submits a vote.
     * @param securityToken The security token
     * @param partition The partition under debate
     * @param topic The topic under debate
     * @param blockNumber The Ethereum block number (point in time)
     * @param vote The vote of the sender
     */
    function submitVote(
        SecurityToken securityToken,
        bytes32 partition, 
        bytes32 topic, 
        uint256 blockNumber, 
        bytes32 vote
    ) 
    public nonReentrant {
        address tokenAddress = address(securityToken);

        // Validations
        require(isValidContext(tokenAddress, partition, topic, blockNumber), "Invalid voting context");
        require(isValidVoter(tokenAddress, partition, topic, blockNumber, msg.sender), "Invalid voter");
        require(!hasVoted(tokenAddress, partition, topic, blockNumber, msg.sender), "The sender already voted.");
        require(isValidVotingOption(tokenAddress, partition, topic, blockNumber, vote), "Invalid voting option");
        require(!votingIsClosed(tokenAddress, partition, topic, blockNumber), 
        "Voting is closed. No further votes accepted.");

        // State changes
        _votes[tokenAddress][partition][topic][blockNumber][msg.sender] = vote;
        _voteCounts[tokenAddress][partition][topic][blockNumber][vote] = 
        _voteCounts[tokenAddress][partition][topic][blockNumber][vote].add(1);

        // Emit the event
        emit VoteSubmitted(tokenAddress, partition, topic, blockNumber, vote, msg.sender);
    }

    /**
     * @notice Allows a controller to close the voting process manually, at any time.
     * @param securityToken The address of the security token
     * @param partition The partition under debate
     * @param topic The topic under debate
     * @param blockNumber The Ethereum block number (point in time)
     */
    function closeVoteManually(
        SecurityToken securityToken,
        bytes32 partition, 
        bytes32 topic, 
        uint256 blockNumber
    ) public 
    nonReentrant 
    controllableTokenOnly(securityToken, msg.sender) {

        address tokenAddress = address(securityToken);

        // Validate the transition state
        require(_state[tokenAddress][partition][topic][blockNumber] == VOTING_OPEN, 
        "Invalid transition state. Voting is not enabled.");

        // Change the state to "closed", regardless of any deadline previously defined by the controller.
        _state[tokenAddress][partition][topic][blockNumber] = VOTING_CLOSED;
    }

    /**
     * @notice Indicates if the voting process is closed.
     * @param tokenAddress The address of the security token
     * @param partition The partition under debate
     * @param topic The topic under debate
     * @param blockNumber The Ethereum block number (point in time)
     * @return returns true if the voting process is closed
     */
    function votingIsClosed(
        address tokenAddress,
        bytes32 partition, 
        bytes32 topic, 
        uint256 blockNumber
    ) public view returns (bool) {

        // Determine if the voting process was manually closed by the Controller of the security token
        bool manuallyClosedByController = _state[tokenAddress][partition][topic][blockNumber] == VOTING_CLOSED;

        // Determine if the deadline was reached
        uint256 deadline = _votingDeadline[tokenAddress][partition][topic][blockNumber];
        bool deadlineReached = (deadline == 0) ? false : now > deadline;

        return manuallyClosedByController || deadlineReached;
    }

    /**
     * @notice Indicates if the voting process requires a deadline.
     * @param tokenAddress The address of the security token
     * @param partition The partition under debate
     * @param topic The topic under debate
     * @param blockNumber The Ethereum block number (point in time)
     * @return returns true if a deadline is required
     */
    function requiresDeadline(
        address tokenAddress,
        bytes32 partition, 
        bytes32 topic, 
        uint256 blockNumber
    ) public view returns (bool) {
        return _votingDeadline[tokenAddress][partition][topic][blockNumber] > 0;
    }

    /**
     * @notice Gets the list of voting options for the context specified.
     * @param tokenAddress The address of the security token
     * @param partition The partition under debate
     * @param topic The topic under debate
     * @param blockNumber The Ethereum block number (point in time)
     * @return returns an array containing the voting options
     */
    function getVotingOptions(
        address tokenAddress,
        bytes32 partition, 
        bytes32 topic, 
        uint256 blockNumber
    ) public view returns (bytes32[] memory) {
        return _votingOptions[tokenAddress][partition][topic][blockNumber];
    }

    /**
     * @notice Gets the vote of the address specified.
     * @param securityToken The address of the security token
     * @param partition The partition under debate
     * @param topic The topic under debate
     * @param blockNumber The Ethereum block number (point in time)
     * @param addr The address of the voter
     */
    function getVote(
        SecurityToken securityToken,
        bytes32 partition, 
        bytes32 topic, 
        uint256 blockNumber, 
        address addr
        ) public view returns (bytes32) {

        // The address of the security token
        address tokenAddress = address(securityToken);

        // Determine whether the voting results can be revealed or not
        bool canReveal = canRevealResults(securityToken, partition, topic, blockNumber);

        // Do not reveal the vote of this token holder until voting is resolved.
        return canReveal ? _votes[tokenAddress][partition][topic][blockNumber][addr] : ZERO_BYTES32;
    }

    /**
     * @notice Gets the statistics of the voting process.
     * @param securityToken The address of the security token
     * @param partition The partition under debate
     * @param topic The topic under debate
     * @param blockNumber The Ethereum block number (point in time)
     * @return returns two parallel arrays containing the voting options and their respective counts
     */
    function getStats(
        SecurityToken securityToken,
        bytes32 partition, 
        bytes32 topic, 
        uint256 blockNumber
    ) public view returns (bytes32[] memory, uint256[] memory) {

        // The address of the security token
        address tokenAddress = address(securityToken);

        // Determine whether the voting results can be revealed or not
        bool canReveal = canRevealResults(securityToken, partition, topic, blockNumber);

        uint256 totalScores = _votingOptions[tokenAddress][partition][topic][blockNumber].length;

        bytes32[] memory optionValues = new bytes32[](totalScores);
        uint256[] memory optionCounts = new uint256[](totalScores);

        for (uint256 i = 0; i < totalScores; i++) {
            bytes32 votingOption = _votingOptions[tokenAddress][partition][topic][blockNumber][i];
            uint256 numberOfVotes = _voteCounts[tokenAddress][partition][topic][blockNumber][votingOption];

            // Do not reveal the votes count until voting is resolved
            optionValues[i] = votingOption;
            optionCounts[i] = canReveal ? numberOfVotes : 0;
        }

        return (optionValues, optionCounts);
    }

    /**
     * @notice Gets the votes of all voters.
     * @param securityToken The address of the security token
     * @param partition The partition under debate
     * @param topic The topic under debate
     * @param blockNumber The Ethereum block number (point in time)
     * @return returns two parallel arrays containing the voters and their respective vote
     */
    function getVotes(
        SecurityToken securityToken,
        bytes32 partition, 
        bytes32 topic, 
        uint256 blockNumber
    ) public view returns (address[] memory, bytes32[] memory) {

        // The address of the security token
        address tokenAddress = address(securityToken);

        // Determine whether the voting results can be revealed or not
        bool canReveal = canRevealResults(securityToken, partition, topic, blockNumber);

        uint256 totalVoters = _voters[tokenAddress][partition][topic][blockNumber].length;
        address[] memory voters = new address[](totalVoters);
        bytes32[] memory voteValues = new bytes32[](totalVoters);

        for (uint256 i = 0; i < totalVoters; i++) {
            address voterAddr = _voters[tokenAddress][partition][topic][blockNumber][i];
            bytes32 voteValue = _votes[tokenAddress][partition][topic][blockNumber][voterAddr];
            
            // Do not reveal the vote of each token holder until voting is resolved
            voters[i] = voterAddr;
            voteValues[i] = canReveal ? voteValue : ZERO_BYTES32;
        }

        return (voters, voteValues);
    }

    /**
     * @notice Indicates if the vote results can be revealed.
     * @param securityToken The address of the security token
     * @param partition The partition under debate
     * @param topic The topic under debate
     * @param blockNumber The Ethereum block number (point in time)
     * @return returns true if the vote results can be revealed.
     */
    function canRevealResults(
        SecurityToken securityToken,
        bytes32 partition, 
        bytes32 topic, 
        uint256 blockNumber
    ) private view returns (bool) {

        // The address of the security token
        address tokenAddress = address(securityToken);

        // Indicates if a deadline was set by the token controller
        bool deadlineSetByController = requiresDeadline(tokenAddress, partition, topic, blockNumber);

        // Indicates if the voting process is closed, either manually or automatically.
        bool votingClosed = votingIsClosed(tokenAddress, partition, topic, blockNumber);

        if (deadlineSetByController) {
            // If a deadline was set, you can reveal vote results if -and only if- the voting process is closed.
            // The voting process gets resolved if any of the following conditions are met:
            //   a) The controller closes the voting process manually
            //   b) The voting process expired as per TTL (time to live) duration in seconds defined by the controller.
            return votingClosed;
        } else {
            // Provided that the controller did not define any deadline for the voting process,
            // vote results will not be available until the controller closes the voting process manually.
            // There is no deadline in this case.
            // If the controller is no longer available on the token specified then the results go public.
            if (securityToken.isControllable()) {
                // The security token is still controllable on-chain, 
                // even though no deadline was defined in terms of voting.
                // In this case, the controller is required to close the voting process manually 
                // in order to see the vote results.
                return _state[tokenAddress][partition][topic][blockNumber] == VOTING_CLOSED;
            } else {
                // The token is no longer controllable and no deadline was defined on the voting process.
                // As a result, we can reveal the voting results.
                return true;
            }
        }
    }

    /**
     * @notice Indicates if the voting context specified is valid.
     * @param tokenAddress The address of the security token
     * @param partition The partition under debate
     * @param topic The topic under debate
     * @param blockNumber The Ethereum block number (point in time)
     * @return returns true if the context is valid
     */
    function isValidContext(
        address tokenAddress,
        bytes32 partition, 
        bytes32 topic, 
        uint256 blockNumber
    ) private view returns (bool) {
        return _votingOptions[tokenAddress][partition][topic][blockNumber].length > 0;
    }

    /**
     * @notice Indicates if the voting option specified is valid.
     * @param tokenAddress The address of the security token
     * @param partition The partition under debate
     * @param topic The topic under debate
     * @param blockNumber The Ethereum block number (point in time)
     * @param option The voting option
     * @return returns true if the option is valid
     */
    function isValidVotingOption(
        address tokenAddress,
        bytes32 partition, 
        bytes32 topic, 
        uint256 blockNumber, 
        bytes32 option
        ) private view returns (bool) {

        uint256 k = _votingOptions[tokenAddress][partition][topic][blockNumber].length;

        for (uint256 i = 0; i < k; i++) {
            if (_votingOptions[tokenAddress][partition][topic][blockNumber][i] == option) {
                return true;
            }
        }

        return false;
    }

    /**
     * @notice Indicates if the address specified is a valid voter.
     * @param tokenAddress The address of the security token
     * @param partition The partition under debate
     * @param topic The topic under debate
     * @param blockNumber The Ethereum block number (point in time)
     * @param addr The address of the voter
     * @return returns true if the voter is valid
     */
    function isValidVoter(
        address tokenAddress,
        bytes32 partition, 
        bytes32 topic, 
        uint256 blockNumber, 
        address addr
        ) private view returns (bool) {
        return _votes[tokenAddress][partition][topic][blockNumber][addr] != ZERO_BYTES32;
    }

    /**
     * @notice Indicates if the address specified has voted already.
     * @param tokenAddress The address of the security token
     * @param partition The partition under debate
     * @param topic The topic under debate
     * @param blockNumber The Ethereum block number (point in time)
     * @param addr The address of the voter
     * @return returns true if the voter has voted already.
     */
    function hasVoted(
        address tokenAddress,
        bytes32 partition, 
        bytes32 topic, 
        uint256 blockNumber, 
        address addr
        ) private view returns (bool) {
        return 
        isValidVoter(tokenAddress, partition, topic, blockNumber, addr) && 
        _votes[tokenAddress][partition][topic][blockNumber][addr] != EMPTY_VOTE;
    }

}