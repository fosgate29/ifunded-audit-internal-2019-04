pragma solidity ^0.5.4;

import "./../ERC1410/ERC1410.sol";
import "./../ERC20/IERC20.sol";
import "./../ERC1594/IERC1594.sol";

/**
 * @title Represents an abstract security token compliant with the ERC-1400 family of standards.
 * @dev This contract guarantees compliance with ERC-1400 as per interfaces declared below, 
 * leaving minor implementation details to a derived contract.
 */
contract ERC1400 is IERC20, IERC1594, IERC1643, IERC1644, IERC1410, ERC1410 {

    using SafeMath for uint256;

    // Attributes of a detailed ERC-20 token
    string private _tokenName;
    string private _tokenSymbol;
    uint8 private _tokenDecimals;

    // The allowance mapping required to implement ERC-20
    mapping (address => mapping (address => uint256)) private _allowed;

    /**
     * @notice Constructor
     * @param owner The owner of the smart contract
     * @param controllerAddr The address of the controller delegated by the issuer
     * @param appIdentifier The application identifier, if any
     * @param tokenName The name of the token
     * @param tokenSymbol The symbol of the token
     * @param tokenDecimals The number of decimals of the token
     */
    constructor(
        address owner, 
        address controllerAddr, 
        bytes32 appIdentifier, 
        string memory tokenName, 
        string memory tokenSymbol, 
        uint8 tokenDecimals
    ) public ERC1410(owner, controllerAddr, appIdentifier) {
        _tokenName = tokenName;
        _tokenSymbol = toUpper(tokenSymbol);
        _tokenDecimals = tokenDecimals;
    }

    /**
    * @notice Transfer token for a specified address
    * @param to The address to transfer to.
    * @param value The amount to be transferred.
    */
    function transfer(address to, uint256 value) external returns (bool) {
        // Transfer the tokens through the ERC-1410 interface
        super._transferByPartition(msg.sender, to, value, DEFAULT_PARTITION, "", address(0), "");

        // Emit the "Transfer" event as per ERC-20
        emit Transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @notice Transfer tokens from one address to another.
     * Note that while this function emits an Approval event, this is not required as per the specification,
     * and other compliant implementations may not emit the event.
     * @param from The address which you want to send tokens from
     * @param to The address which you want to transfer to
     * @param value The amount of tokens to be transferred
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        return _transferFromWithData(from, to, value, "");
    }

    /**
     * @notice Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
     * Beware that changing an allowance with this method brings the risk that someone may use both the old
     * and the new allowance by unfortunate transaction ordering. 
     * One possible solution to mitigate this race condition is to first reduce the spender's allowance to 0 
     * and set the desired value afterwards: https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @return returns true if the spender is approved
     */
    function approve(address spender, uint256 value) external returns (bool) {
        require(isSafeAddress(spender), "Invalid spender");

        _allowed[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @notice Increases the total supply of the token and the corresponding amount of the specified owners partition
     * @param tokenHolder The token holder whose balance should be increased
     * @param value The amount by which to increase the balance
     * @param data Additional data attached to the minting of tokens
     */
    function issue(address tokenHolder, uint256 value, bytes calldata data) external 
    onlyIfIssuanceEnabled onlyIfNotPaused {
        // Issue by partition as per ERC-1410
        super._issueByPartition(DEFAULT_PARTITION, tokenHolder, value, data);

        // Emit the "Issued" event as per ERC-1594
        emit Issued(msg.sender, tokenHolder, value, data);
    }

    /**
     * @notice Transfers tokens from one address to another including additional data, as per ERC-1594
     * @param from The address which you want to send tokens from
     * @param to The address which you want to transfer to
     * @param value The amount of tokens to be transferred
     * @param data Additional data attached to the transfer
     */
    function transferFromWithData(address from, address to, uint256 value, bytes calldata data) external {
        _transferFromWithData(from, to, value, data);
    }

    /**
    * @notice Transfers tokens to the address specified including additional data, as per ERC-1594
    * @param to The address to transfer to.
    * @param value The amount to be transferred.
    * @param data Additional data attached to the transfer
    */
    function transferWithData(address to, uint256 value, bytes calldata data) external {
        super._transferByPartition(msg.sender, to, value, DEFAULT_PARTITION, data, address(0), "");

        // Emit the "Transfer" event as per ERC-20
        emit Transfer(msg.sender, to, value);
    }

    /**
     * @notice Burns (redeems) a given amount of tokens from the sender.
     * @param value The amount by which to decrease the balance
     * @param data Additional data attached to the burning of tokens
     */
    function redeem(uint256 value, bytes calldata data) external {
        _redeemByPartition(DEFAULT_PARTITION, msg.sender, address(0), value, data, "");
    }

    /**
     * @notice Burns (redeems) a given amount of tokens from the holder specified.
     * @param value The amount by which to decrease the balance
     * @param data Additional data attached to the burning of tokens
     */
    function redeemFrom(address tokenHolder, uint256 value, bytes calldata data) external {
        _redeemByPartition(DEFAULT_PARTITION, tokenHolder, msg.sender, value, data, "");
    }

    /**
     * @notice Function to check the amount of tokens that an owner allowed to a spender.
     * @param owner address The address which owns the funds.
     * @param spender address The address which will spend the funds.
     * @return A uint256 specifying the amount of tokens still available for the spender.
     */
    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowed[owner][spender];
    }

    /**
     * @notice Indicates if the issuance has finished for the token, as per ERC-1594
     * If a token returns FALSE for isIssuable() then it MUST always return FALSE in the future.
     * If a token returns FALSE for isIssuable() then it MUST never allow additional tokens to be issued.
     * @return returns true if no new tokens can be minted or issued.
     */
    function isIssuable() external view returns (bool) {
        return super._isIssuable();
    }

    /**
     * @notice Indicates if the transfer will succeed, as per ERC-1594
     * @param from The address which you want to send tokens from
     * @param to The address of the receiver
     * @param value The amount to transfer
     * @param data Additional data attached to the transfer
     * @return returns true if the transfer will succeed
     */
    function canTransferFrom(address from, address to, uint256 value, bytes calldata data) 
    external view returns (bool, byte, bytes32) {
        byte statusCode;
        bytes32 reason;
        bytes32 partition;
        (statusCode, reason, partition) = _canTransferByPartition(from, to, DEFAULT_PARTITION, value, data);
        bool success = (statusCode == EIP1066_TOKEN_TRANSFER_SUCCESSFUL);
        return (success, statusCode, reason);
    }

    /**
     * @notice Indicates if the transfer will succeed, as per ERC-1594
     * @param to The address of the receiver
     * @param value The amount to transfer
     * @param data Additional data attached to the transfer
     * @return returns true if the transfer will succeed
     */
    function canTransfer(address to, uint256 value, bytes calldata data) external view returns (bool, byte, bytes32) {
        byte statusCode;
        bytes32 reason;
        bytes32 partition;
        (statusCode, reason, partition) = _canTransferByPartition(msg.sender, to, DEFAULT_PARTITION, value, data);
        bool success = (statusCode == EIP1066_TOKEN_TRANSFER_SUCCESSFUL);
        return (success, statusCode, reason);
    }

    /**
    * @notice Gets the descriptive name of the token
    * @return the name of the token.
    */
    function name() public view returns (string memory) {
        return _tokenName;
    }

    /**
    * @notice Gets the symbol of the token
    * @return the symbol of the token.
    */
    function symbol() public view returns (string memory) {
        return _tokenSymbol;
    }

    /**
    * @notice Gets the number of decimals of the token.
    * @return the number of decimals of the token.
    */
    function decimals() public view returns (uint8) {
        return _tokenDecimals;
    }

    /**
     * @notice Transfers tokens from one address to another including additional data, as per ERC-1594
     * @param from The address which you want to send tokens from
     * @param to The address which you want to transfer to
     * @param value The amount of tokens to be transferred
     * @param data Additional data attached to the transfer
     */
    function _transferFromWithData(address from, address to, uint256 value, bytes memory data) private returns(bool) {
        require(value <= _allowed[from][msg.sender], "Insufficient allowance");
        _allowed[from][msg.sender] = _allowed[from][msg.sender].sub(value);

        // Transfer the tokens through the ERC-1410 interface
        super._transferByPartition(from, to, value, DEFAULT_PARTITION, data, msg.sender, "");

        emit Approval(from, msg.sender, _allowed[from][msg.sender]);

        // Emit the "Transfer" event as per ERC-20
        emit Transfer(from, to, value);

        return true;
    }

}