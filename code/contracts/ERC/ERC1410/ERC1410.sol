pragma solidity ^0.5.4;

import "./../../math/SafeMath.sol";
import "./../../math/KindMath.sol";
import "./../../access/ReentrancyGuard.sol";
import "./../ERC1643/ERC1643.sol";
import "./../ERC1644/IERC1644.sol";
import "./IERC1410.sol";

/**
 * @title This abstract contract implements the standard ERC-1410 (Partially Fungible Token Standard)
 */
contract ERC1410 is ReentrancyGuard, ERC1643, IERC1644, IERC1410 {

    using SafeMath for uint256;

    // Represents a fungible set of tokens.
    struct Partition {
        uint256 amount;
        bytes32 partition;
    }

    // Ethereum Status Codes defined by EIP-1066 (https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1066.md)
    byte constant internal EIP1066_SUCCESS = 0x01;
    byte constant internal EIP1066_TOKEN_TRANSFER_FAILED = 0x50;
    byte constant internal EIP1066_TOKEN_TRANSFER_SUCCESSFUL = 0x51;
    byte constant internal EIP1066_AWAITING_PAYMENT_FROM_OTHERS = 0x52;
    byte constant internal EIP1066_NOT_FOUND = 0x20;

    // Defines the default partition of all tokens
    bytes32 internal constant DEFAULT_PARTITION = "default";

    // Represents an empty string formatted as bytes-32 struct
    bytes32 internal constant ZERO_BYTES32 = bytes32(0);
    address internal constant ZERO_ADDRESS = address(0);

    // The application identifier
    bytes32 internal _appIdentifier;

    // The number of tokens in existance
    uint256 private _totalSupply;

    // The address of the controller, which is a delegated entity set by the issuer/owner of the token
    address private _controllerAddress;

    // Used to permanently halt all minting
    bool private _issuanceStopped;

    // Used to pause or unpause trading
    bool private _paused;

    // Mapping from investor to aggregated balance across all investor token sets
    mapping (address => uint256) private _balances;

    // Mapping from investor to their partitions
    mapping (address => Partition[]) private _partitions;

    // Mapping from (investor, partition) to index of corresponding partition in partitions
    // @dev Stored value is always greater by 1 to avoid the 0 value of every index
    mapping (address => mapping (bytes32 => uint256)) private _partitionToIndex;

    // Mapping from (investor, partition, operator) to approved status
    mapping (address => mapping (bytes32 => mapping (address => bool))) private _partitionApprovals;

    // Mapping from (investor, operator) to approved status (can be used against any partition)
    mapping (address => mapping (address => bool)) private _approvals;

    event TransferByPartition(
        bytes32 indexed _fromPartition,
        address _operator,
        address indexed _from,
        address indexed _to,
        uint256 _value,
        bytes _data,
        bytes _operatorData
    );

    event AuthorizedOperator(address indexed operator, address indexed tokenHolder);
    event RevokedOperator(address indexed operator, address indexed tokenHolder);

    event AuthorizedOperatorByPartition(
        bytes32 indexed partition, address indexed operator, address indexed tokenHolder
    );

    event RevokedOperatorByPartition(
        bytes32 indexed partition, address indexed operator, address indexed tokenHolder
    );

    // This event is emitted when the token is no longer controllable
    event FinalizedControllerFeature();

    event Paused(address indexed pausedByAddress);
    event UnPaused(address indexed unpausedByAddress);

    /**
     * @notice Constructor
     * @param owner The owner of the smart contract
     * @param controllerAddr The address of the controller delegated by the issuer
     * @param appIdentifier The application identifier, if any
     */
    constructor(address owner, address controllerAddr, bytes32 appIdentifier) public ERC1643(owner) {
        // Below condition is to restrict the owner/issuer to become the controller as well in ideal world.
        // But for non ideal case issuer could set another address which is not the owner of the token 
        // but issuer holds its private key.
        require(controllerAddr != owner, "The owner is not allowed to become a controller");
        require(controllerAddr != address(this), "The contract cannot be the token controller");
        require(owner != address(this), "The contract cannot be the owner");
        _controllerAddress = controllerAddr;

        _appIdentifier = appIdentifier;
    }

    // Modifier to check whether the address specified is authorized or not 
    modifier onlyController(address addr) {
        require(isSafeAddress(addr), "Invalid controller address");
        require(addr == _controllerAddress, "Only controllers are allowed to execute this function");
        _;
    }

    modifier onlyIfControllable() {
        require(_isControllable(), "The security token is not controllable");
        _;
    }

    // Modifier to check if issuance is enabled
    modifier onlyIfIssuanceEnabled() {
        require(_isIssuable(), "Issuance has finished for the token. No new tokens can be minted or issued.");
        _;
    }

    // Modifier to check if token trading is paused
    modifier onlyIfNotPaused() {
        require(!_paused, "Token trading is paused.");
        _;
    }

    /**
     * @notice Makes sure the operator is not an 0x0 address nor the address of the smart contract
     * @param operator The owner of the smart contract
     */
    modifier validOperatorAddressOnly(address operator) {
        require(isSafeAddress(operator), "Invalid operator address");
        _;
    }

    /**
     * @notice It is used to end the controller feature from the token
     */
    function finalizeControllable() external onlyOwner onlyIfControllable {
        // The token is no longer controllable
        _controllerAddress = ZERO_ADDRESS;

        // Trigger the event
        emit FinalizedControllerFeature();
    }
    
    /**
     * @notice Authorises an operator for all partitions of `msg.sender`
     * @param operator An address which is being authorised
     */
    function authorizeOperator(address operator) external validOperatorAddressOnly(operator) {
        _approvals[msg.sender][operator] = true;
        emit AuthorizedOperator(operator, msg.sender);
    }

    /**
     * @notice Revokes authorisation of an operator previously given for all partitions of `msg.sender`
     * @param operator An address which is being de-authorised
     */
    function revokeOperator(address operator) external validOperatorAddressOnly(operator) {
        _approvals[msg.sender][operator] = false;
        emit RevokedOperator(operator, msg.sender);
    }

    /**
     * @notice Authorises an operator for a given partition of `msg.sender`
     * @param partition The partition to which the operator is authorised
     * @param operator An address which is being authorised
     */
    function authorizeOperatorByPartition(bytes32 partition, address operator) external 
    validOperatorAddressOnly(operator) {
        _partitionApprovals[msg.sender][partition][operator] = true;
        emit AuthorizedOperatorByPartition(partition, operator, msg.sender);
    }

    /**
     * @notice Revokes authorisation of an operator previously given for a specified partition of `msg.sender`
     * @notice Authorises an operator for a given partition of `msg.sender`
     * @param partition The partition to which the operator is de-authorised
     * @param operator An address which is being de-authorised
     */
    function revokeOperatorByPartition(bytes32 partition, address operator) external 
    validOperatorAddressOnly(operator) {
        _partitionApprovals[msg.sender][partition][operator] = false;
        emit RevokedOperatorByPartition(partition, operator, msg.sender);
    }

    /**
     * @notice Increases the total supply of the token and the corresponding amount of the specified owners partition
     * @param partition The partition to allocate the increase in balance
     * @param tokenHolder The token holder whose balance should be increased
     * @param value The amount by which to increase the balance
     * @param data Additional data attached to the minting of tokens
     */
    function issueByPartition(bytes32 partition, address tokenHolder, uint256 value, bytes calldata data) external 
    onlyIfIssuanceEnabled {
        _issueByPartition(partition, tokenHolder, value, data);
    }

    /**
     * @notice Decreases totalSupply and the corresponding amount of the specified partition of msg.sender
     * @param partition The partition to allocate the decrease in balance
     * @param value The amount by which to decrease the balance
     * @param data Additional data attached to the burning of tokens
     */
    function redeemByPartition(bytes32 partition, uint256 value, bytes calldata data) external {
        _redeemByPartition(partition, msg.sender, ZERO_ADDRESS, value, data, "");
    }

    /**
     * Transfers the ownership of tokens from a specified partition from one address to another address
     * @param partition The partition from which to transfer tokens
     * @param to The address to which to transfer tokens to
     * @param value The amount of tokens to transfer from `_partition`
     * @param data Additional data attached to the transfer of tokens
     * @return The partition to which the transferred tokens were allocated for the _to address
     */
    function transferByPartition(bytes32 partition, address to, uint256 value, bytes calldata data) external 
    returns (bytes32) {
        return _transferByPartition(msg.sender, to, value, partition, data, ZERO_ADDRESS, "");
    }

    /**
     * @notice Transfers the ownership of tokens from a specified partition from one address to another address
     * @param partition The partition from which to transfer tokens
     * @param from The address from which to transfer tokens from
     * @param to The address to which to transfer tokens to
     * @param value The amount of tokens to transfer from `_partition`
     * @param data Additional data attached to the transfer of tokens
     * @param operatorData Additional data attached to the transfer of tokens by the operator
     * @return The partition to which the transferred tokens were allocated for the _to address
     */
    function operatorTransferByPartition(
        bytes32 partition, 
        address from, 
        address to, 
        uint256 value, 
        bytes calldata data, 
        bytes calldata operatorData
    ) 
    external returns (bytes32) {
        return _operatorTransferByPartition(partition, from, to, value, data, operatorData);
    }

    /**
     * @notice Decreases total supply and the corresponding amount of the specified partition of tokenHolder
     * @param partition The partition to allocate the decrease in balance.
     * @param tokenHolder The token holder whose balance should be decreased
     * @param value The amount by which to decrease the balance
     * @param data Additional data attached to the burning of tokens
     * @param operatorData Additional data attached to the transfer of tokens by the operator
     */
    function operatorRedeemByPartition(
        bytes32 partition, 
        address tokenHolder, 
        uint256 value, 
        bytes calldata data, 
        bytes calldata operatorData) 
    external {
        _operatorRedeemByPartition(partition, tokenHolder, value, data, operatorData);
    }

    /**
     * @notice Allows an authorized address (controller) to transfer tokens between any two token holders.
     * @dev The transfer must still respect the balances of the token holders 
     * (so the transfer must be for at most "balanceOf(_from)" tokens) 
     * and potentially also need to respect other transfer restrictions.
     * This function can only be executed by the controller address.
     *
     * @param from The address which you want to send tokens from
     * @param to The address which you want to transfer to
     * @param value The amount of tokens to be transferred
     * @param data The data to validate the transfer.
     * @param operatorData The data attached by the controller during the token tranfer.
     * It usually contains a reason string (for example "force transfer") in order to provide transparency on-chain. 
     */
    function controllerTransfer(
        address from, 
        address to, 
        uint256 value, 
        bytes calldata data, 
        bytes calldata operatorData
    ) 
    external onlyIfControllable onlyController(msg.sender) {
        // Transfer a given amount of tokens between the two addresses specified.
        // Notice that the token transfer takes place on the default partition.
        address operator = msg.sender;
        _transferByPartition(from, to, value, DEFAULT_PARTITION, data, operator, operatorData);

        // Emit the "ControllerTransfer" event as per ERC-1644
        emit ControllerTransfer(msg.sender, from, to, value, data, operatorData);
    }

    /**
     * @notice This function allows an authorized address to redeem tokens for any token holder.
     * The redemption must still respect the balances of the token holder (so the redemption must be for at most
     * "balanceOf(_tokenHolder)" tokens) and potentially also need to respect other transfer restrictions.
     * This function can only be executed by the controller address.
     *
     * @param tokenHolder The account whose tokens will be redeemed.
     * @param value The amount of tokens that need to be redeemed.
     * @param data The data to validate the transfer.
     * @param operatorData The data attached to the transfer by controller to emit in event. 
     * It is more like a reason string for calling this function (aka force transfer) 
     * which provides the transparency on-chain. 
     */
    function controllerRedeem(
        address tokenHolder, 
        uint256 value, 
        bytes calldata data, 
        bytes calldata operatorData
    ) 
    external onlyIfControllable onlyController(msg.sender) {
        // Redeem (burn) a given amount of tokens from the holder specified
        address operator = msg.sender;

        _redeemByPartition(DEFAULT_PARTITION, tokenHolder, operator, value, data, operatorData);

        // Emit the "ControllerRedemption" event as per ERC-1644
        emit ControllerRedemption(msg.sender, tokenHolder, value, data, operatorData);
    }

    /**
     * @notice Indicates whether the token is controllable or not.
     * If the token is controllable then the controller address is allowed to do the following:
     * 1) To transfer tokens between any two token holders, by calling the function "controllerTransfer"
     * 2) To redeem a given amount of tokens by calling the function "controllerRedeem"
     * 
     * If the token is not controllable then the functions "controllerTransfer" and "controllerRedeem" 
     * are guaranteed to fail because they they can only be called by a controller.
     *
     * @return returns true if the token is controllable
     */
    function isControllable() external view returns (bool) {
        return _isControllable();
    }

    /**
     * Counts the sum of all partitions balances assigned to an owner
     * @param addr An address for whom to query the balance
     * @return The number of tokens owned by the token holder
     */
    function balanceOf(address addr) external view returns (uint256) {
        return _balances[addr];
    }

    /**
     * Counts the balance associated with a specific partition assigned to an token holder
     * @param partition The partition for which to query the balance
     * @param addr An address for whom to query the balance
     * @return The number of tokens owned by the holder
     */
    function balanceOfByPartition(bytes32 partition, address addr) external view returns (uint256) {
        if (_isValidPartition(partition, addr))
            return _partitions[addr][_partitionToIndex[addr][partition] - 1].amount;
        else
            return 0;
    }

    /**
     * Gets the list of partitions available to a token holder
     * @param addr An address corresponds whom partition list is queried
     * @return returns a list of partitions
     */
    function partitionsOf(address addr) external view returns (bytes32[] memory) {
        bytes32[] memory partitionsList = new bytes32[](_partitions[addr].length);
        for (uint256 i = 0; i < _partitions[addr].length; i++) {
            partitionsList[i] = _partitions[addr][i].partition;
        } 
        return partitionsList;
    }

    /**
     * @dev Total number of tokens in existence
     */
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    /**
     * Indicates if the operator specified is an authorized operator for all partitions of the token holder.
     * @param operator The operator to check
     * @param tokenHolder The token holder to check
     * @return returns true if the operator is authorized.
     */
    function isOperator(address operator, address tokenHolder) external view returns (bool) {
        return _approvals[tokenHolder][operator];
    }

    /**
     * Indicates if an operator is an authorized on a given partition of the token holder specified.
     * @param partition The partition to check
     * @param operator The operator to check
     * @param tokenHolder The token holder to check
     * @return returns true if the operator is authorized.
     */
    function isOperatorForPartition(bytes32 partition, address operator, address tokenHolder) external view 
    returns (bool) {
        return _partitionApprovals[tokenHolder][partition][operator];
    }

    /**
     * @notice The standard provides an on-chain function to determine whether a transfer will succeed,
     * and return details indicating the reason if the transfer is not valid.
     * @param from The address from whom the tokens get transferred.
     * @param to The address to which to transfer tokens to.
     * @param partition The partition from which to transfer tokens
     * @param value The amount of tokens to transfer from `_partition`
     * @param data Additional data attached to the transfer of tokens
     * @return ESC (Ethereum Status Code) following the EIP-1066 standard
     * @return Application specific reason codes with additional details
     * @return The partition to which the transferred tokens were allocated for the _to address
     */
    function canTransferByPartition(address from, address to, bytes32 partition, uint256 value, bytes calldata data) 
    external view returns (byte, bytes32, bytes32) {
        return _canTransferByPartition(from, to, partition, value, data);
    }

    /**
     * @notice Indicates if the address specified is the controller of the security token.
     * @return returns true if the address specified is the controller of the security token.
     */
    function isController(address addr) public view returns (bool) {
        return _isController(addr);
    }

    /**
     * @notice Pauses token trading.
     */
    function pause() public {
        require(canPause(msg.sender), "Insufficient permissions. You are not allowed to pause token trading.");
        require(!_paused, "Token trading is already paused");
        _paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @notice Unpauses token trading.
     */
    function unPause() public {
        require(canPause(msg.sender), "Insufficient permissions. You are not allowed to unpause token trading.");
        require(_paused, "Token trading is already unpaused");
        _paused = false;
        emit UnPaused(msg.sender);
    }

    /**
     * @notice Indicates if token trading is paused.
     * @return returns true if trading is paused.
     */
    function isPaused() public view returns (bool) {
        return _paused;
    }

    /**
     * @notice Indicates if the address specified is allowed to pause/unpause the token.
     * @param addr Specifies the address.
     * @return returns true if the address is allowed to perform the action requested.
     */
    function canPause(address addr) public view returns(bool);

    /**
     * @notice Indicates if the address specified is allowed to issue tokens.
     * @param addr Specifies the address.
     * @return returns true if the address is allowed to perform the action requested.
     */
    function canIssue(address addr) public view returns(bool);

    /**
     * @notice Indicates if the address specified is allowed to redeem tokens.
     * @param addr Specifies the address.
     * @return returns true if the address is allowed to perform the action requested.
     */
    function canRedeem(address addr) public view returns(bool);

    /**
     * @notice Indicates if the address specified is allowed to freeze the issuance of tokens.
     * @param addr Specifies the address.
     * @return returns true if the address is allowed to perform the action requested.
     */
    function canFreezeMinting(address addr) public view returns(bool);

    // ------------------------------------------------------------------------------------------
    // Internal functions
    // ------------------------------------------------------------------------------------------
    /**
     * @notice Indicates if the issuance has finished for the token, as per ERC-1594
     * If a token returns FALSE for isIssuable() then it MUST always return FALSE in the future.
     * If a token returns FALSE for isIssuable() then it MUST never allow additional tokens to be issued.
     * @return returns true if no new tokens can be minted or issued.
     */
    function _isIssuable() internal view returns (bool) {
        return !_issuanceStopped;
    }

    function bytes32ToString(bytes32 x) internal pure returns (string memory) {
        bytes memory bytesString = new bytes(32);
        uint charCount = 0;
        for (uint j = 0; j < 32; j++) {
            byte char = byte(bytes32(uint(x) * 2 ** (8 * j)));
            if (char != 0) {
                bytesString[charCount] = char;
                charCount++;
            }
        }
        bytes memory bytesStringTrimmed = new bytes(charCount);
        for (uint j = 0; j < charCount; j++) {
            bytesStringTrimmed[j] = bytesString[j];
        }
        return string(bytesStringTrimmed);
    }

    /**
    * @notice Changes a string to upper case
    * @param base String to change
    */
    function toUpper(string memory base) internal pure returns (string memory) {
        bytes memory _baseBytes = bytes(base);
        for (uint i = 0; i < _baseBytes.length; i++) {
            bytes1 b1 = _baseBytes[i];
            if (b1 >= 0x61 && b1 <= 0x7A) {
                b1 = bytes1(uint8(b1)-32);
            }
            _baseBytes[i] = b1;
        }
        return string(_baseBytes);
    }

    /**
     * @notice Increases the total supply of the token and the corresponding amount of the specified owners partition
     * @param partition The partition to allocate the increase in balance
     * @param tokenHolder The token holder whose balance should be increased
     * @param value The amount by which to increase the balance
     * @param data Additional data attached to the minting of tokens
     */
    function _issueByPartition(bytes32 partition, address tokenHolder, uint256 value, bytes memory data) 
    internal onlyIfIssuanceEnabled onlyIfNotPaused nonReentrant {
        require(value != uint256(0), "Zero value not allowed");
        require(partition != bytes32(0), "The partition is required");
        require(isSafeAddress(tokenHolder), "Invalid token holder");
        require(canIssue(msg.sender), "Insufficient permissions. You are not allowed to issue tokens.");

        uint256 index = _partitionToIndex[tokenHolder][partition];
        if (index == 0) {
            _partitions[tokenHolder].push(Partition(value, partition));
            _partitionToIndex[tokenHolder][partition] = _partitions[tokenHolder].length;
        } else {
            _partitions[tokenHolder][index - 1].amount = _partitions[tokenHolder][index - 1].amount.add(value);
        }
        _totalSupply = _totalSupply.add(value);
        _balances[tokenHolder] = _balances[tokenHolder].add(value);
        emit IssuedByPartition(partition, tokenHolder, value, data);
    }

    function _isValidPartition(bytes32 partition, address addr) internal view returns(bool) {
        if (!isSafeAddress(addr)) return false;
        if (_partitions[addr].length < _partitionToIndex[addr][partition] || _partitionToIndex[addr][partition] == 0)
            return false;
        else
            return true;
    }

    /**
     * @notice Runs application specific validations before proceeding with a transfer of tokens.
     * This function allows any derived contract to run any additional checks and token transfer restrictions on-chain.
     *
     * @dev Please notice that this function is required to return an ESC (Ethereum Status Code) as per EIP-1066
     * A default implementation is provided below. 
     * Derived contracts can override this function in order to implement any app-specific token restrictions.
     *
     * @param from The address from whom the tokens get transferred.
     * @param to The address to which to transfer tokens to.
     * @param partition The partition from which to transfer tokens
     * @param data Additional data attached to the transfer of tokens
     * @return ESC (Ethereum Status Code) following the EIP-1066 standard
     * @return Application specific reason codes with additional details
     */
    function _validateTokenTransfer(address from, address to, bytes32 partition, bytes memory data) 
    internal view returns (byte, bytes32);

    function _transferByPartition
    (
        address from, 
        address to, 
        uint256 value, 
        bytes32 partition, 
        bytes memory data, 
        address operator, 
        bytes memory operatorData
    ) 
    internal onlyIfNotPaused nonReentrant
    returns (bytes32) {
        requireValidTransfer(from, to, value, partition, data);

        require(_partitions[from][_partitionToIndex[from][partition] - 1].amount >= value, "Insufficient balance");
        uint256 fromIndex = _partitionToIndex[from][partition] - 1;
        uint256 toIndex = _partitionToIndex[to][partition] - 1;
        
        // Changing the state values
        _partitions[from][fromIndex].amount = _partitions[from][fromIndex].amount.sub(value);
        _balances[from] = _balances[from].sub(value);
        _partitions[to][toIndex].amount = _partitions[to][toIndex].amount.add(value);
        _balances[to] = _balances[to].add(value);
        
        // Emit transfer event.
        emit TransferByPartition(partition, operator, from, to, value, data, operatorData);

        return partition;
    }

    /**
     * @notice This function allows an authorized address to redeem tokens for any token holder.
     * @param partition The partition 
     * @param from The account whose tokens will be redeemed.
     * @param operator The operator
     * @param value The amount of tokens that need to be redeemed.
     * @param data The data to validate the redemption of tokens.
     * @param operatorData The data attached to the redemption by the controller to emit in event.
     */
    function _redeemByPartition(
        bytes32 partition, 
        address from, 
        address operator, 
        uint256 value, 
        bytes memory data, 
        bytes memory operatorData
    ) 
    internal onlyIfNotPaused nonReentrant {
        require(isSafeAddress(from), "Invalid token holder");
        require(value != uint256(0), "Zero value not allowed");
        require(partition != bytes32(0), "The partition is required");
        require(_isValidPartition(partition, from), "Invalid partition");

        if (!_isController(msg.sender)) {
            require(canRedeem(msg.sender), "Insufficient permissions. You are not allowed to redeem tokens.");
        }

        uint256 index = _partitionToIndex[from][partition] - 1;
        require(_partitions[from][index].amount >= value, "Insufficient value");

        if (_partitions[from][index].amount == value) {
            _deletePartitionForHolder(from, partition, index);
        } else {
            _partitions[from][index].amount = _partitions[from][index].amount.sub(value);
        }
        _balances[from] = _balances[from].sub(value);
        _totalSupply = _totalSupply.sub(value);
        emit RedeemedByPartition(partition, operator, from, value, data, operatorData);
    }

    /**
     * @notice Transfers the ownership of tokens from a specified partition from one address to another address
     * @param partition The partition from which to transfer tokens
     * @param from The address from which to transfer tokens from
     * @param to The address to which to transfer tokens to
     * @param value The amount of tokens to transfer from `_partition`
     * @param data Additional data attached to the transfer of tokens
     * @param operatorData Additional data attached to the transfer of tokens by the operator
     * @return The partition to which the transferred tokens were allocated for the _to address
     */
    function _operatorTransferByPartition
    (
        bytes32 partition, address from, address to, uint256 value, bytes memory data, bytes memory operatorData
    ) internal onlyIfNotPaused returns (bytes32) {
        require(isSafeAddress(from), "Invalid source address");
        require(isSafeAddress(to), "Invalid target address");
        require(
            this.isOperator(msg.sender, from) || this.isOperatorForPartition(partition, msg.sender, from),
            "Invalid operator. Not authorised."
        );
        _transferByPartition(from, to, value, partition, data, msg.sender, operatorData);

        return partition;
    }

    /**
     * @notice Decreases total supply and the corresponding amount of the specified partition of tokenHolder
     * @param partition The partition to allocate the decrease in balance.
     * @param tokenHolder The token holder whose balance should be decreased
     * @param value The amount by which to decrease the balance
     * @param data Additional data attached to the burning of tokens
     * @param operatorData Additional data attached to the transfer of tokens by the operator
     */
    function _operatorRedeemByPartition
    (
        bytes32 partition, address tokenHolder, uint256 value, bytes memory data, bytes memory operatorData
    ) internal onlyIfNotPaused {
        require(isSafeAddress(tokenHolder), "Invalid token holder");
        require(
            this.isOperator(msg.sender, tokenHolder) || 
            this.isOperatorForPartition(partition, msg.sender, tokenHolder),
            "Not authorised"
        );

        _redeemByPartition(partition, tokenHolder, msg.sender, value, data, operatorData);
    }

    /**
     * @notice The standard provides an on-chain function to determine whether a transfer will succeed,
     * and return details indicating the reason if the transfer is not valid.
     * @param from The address from whom the tokens get transferred.
     * @param to The address to which to transfer tokens to.
     * @param partition The partition from which to transfer tokens
     * @param value The amount of tokens to transfer from `_partition`
     * @param data Additional data attached to the transfer of tokens
     * @return ESC (Ethereum Status Code) following the EIP-1066 standard
     * @return Application specific reason codes with additional details
     * @return The partition to which the transferred tokens were allocated for the _to address
     */
    function _canTransferByPartition(address from, address to, bytes32 partition, uint256 value, bytes memory data) 
    internal view returns (byte, bytes32, bytes32) {
        byte ethereumStatusCode;
        bytes32 reason;
        bytes32 validatedPartition;
        (ethereumStatusCode, reason, validatedPartition) = _runBasicValidations(from, to, partition, value);

        if (ethereumStatusCode != EIP1066_TOKEN_TRANSFER_SUCCESSFUL) {
            return (ethereumStatusCode, reason, ZERO_BYTES32);
        }

        if (!_isController(msg.sender)) {
            // This is the most likely scenario. 
            // This is a token transfer between two regular parties (sender and receiver).
            if (_paused) { 
                return (EIP1066_TOKEN_TRANSFER_FAILED, "Token trading is paused", ZERO_BYTES32); 
            }

            // Provide a hook in order for derived contracts to run application-specific validations 
            // before the transfer of tokens take place.
            (ethereumStatusCode, reason) = _validateTokenTransfer(from, to, partition, data);

            if (ethereumStatusCode != EIP1066_TOKEN_TRANSFER_SUCCESSFUL) {
                return (ethereumStatusCode, reason, ZERO_BYTES32);
            }
        }

        // All validations passed. The token transfer will succeed
        return (EIP1066_TOKEN_TRANSFER_SUCCESSFUL, "Success", partition);
    }

    /**
     * @notice Indicates if the address specified is considered a safe address.
     * @param addr The address to evaluate
     * @return returns true if the address is considered safe
     */
    function isSafeAddress(address addr) internal view returns (bool) {
        return ((addr != ZERO_ADDRESS) && (addr != address(this)));
    }

    // ------------------------------------------------------------------------------------------
    // Private functions
    // ------------------------------------------------------------------------------------------
    /**
     * @notice Indicates whether the token is controllable or not.
     * If the token is controllable then the controller address is allowed to do the following:
     * 1) To transfer tokens between any two token holders, by calling the function "controllerTransfer"
     * 2) To redeem a given amount of tokens by calling the function "controllerRedeem"
     * 
     * If the token is not controllable then the functions "controllerTransfer" and "controllerRedeem" 
     * are guaranteed to fail because they they can only be called by a controller.
     *
     * @return returns true if the token is controllable
     */
    function _isControllable() private view returns (bool) {
        return _controllerAddress != ZERO_ADDRESS;
    }

    /**
     * @notice Indicates if the address specified is the controller of the security token.
     * @return returns true if the address specified is the controller of the security token.
     */
    function _isController(address addr) private view returns (bool) {
        return _isControllable() && isSafeAddress(addr) && (_controllerAddress == addr);
    }

    /**
     * @notice Permanently freezes minting of this security token.
     */
    function _freezeMinting() private onlyIfIssuanceEnabled {
        require(canFreezeMinting(msg.sender), "Insufficient permissions. You are not allowed to freeze minting.");
        _issuanceStopped = true;
    }

    function _runBasicValidations(address from, address to, bytes32 partition, uint256 value) 
    private view returns (byte, bytes32, bytes32) {
        // Run the very basic validations common to all scenarios
        if (!isSafeAddress(from)) return (0x57, "Invalid sender", ZERO_BYTES32);
        if (!isSafeAddress(to)) return (0x57, "Invalid receiver", ZERO_BYTES32);

        if (!_isValidPartition(partition, from)) { 
            return (EIP1066_TOKEN_TRANSFER_FAILED, "The partition does not exist", ZERO_BYTES32); 
        } 
        if (_partitions[from][_partitionToIndex[from][partition] - 1].amount < value) { 
            return (EIP1066_AWAITING_PAYMENT_FROM_OTHERS, "Insufficent balance", ZERO_BYTES32); 
        } 
        if (!KindMath.checkSub(_balances[from], value) || !KindMath.checkAdd(_balances[to], value)) { 
            return (EIP1066_TOKEN_TRANSFER_FAILED, "Overflow", ZERO_BYTES32); 
        }

        return (EIP1066_TOKEN_TRANSFER_SUCCESSFUL, "Success", partition);
    }

    /**
     * @notice Enforces validation during a tokens transfer between two parties.
     * @param from The address from whom the tokens get transferred.
     * @param to The address to which to transfer tokens to.
     * @param value The amount of tokens to transfer on the partition specified.
     * @param partition The partition where the token transfer takes place.
     * @param data Any additional data attached to the transfer of tokens
     */
    function requireValidTransfer(address from, address to, uint256 value, bytes32 partition, bytes memory data) 
    private view {
        byte ethereumStatusCode;
        bytes32 reason;
        bytes32 validatedPartition;
        (ethereumStatusCode, reason, validatedPartition) = _canTransferByPartition(from, to, partition, value, data);
        bool success = (ethereumStatusCode == EIP1066_TOKEN_TRANSFER_SUCCESSFUL);

        require(success, bytes32ToString(reason));
    }

    function _deletePartitionForHolder(address holder, bytes32 partition, uint256 index) private {
        if (index != _partitions[holder].length - 1) {
            _partitions[holder][index] = _partitions[holder][_partitions[holder].length - 1];
            _partitionToIndex[holder][_partitions[holder][index].partition] = index + 1;
        }
        delete _partitionToIndex[holder][partition];
        _partitions[holder].length--;
    }

}