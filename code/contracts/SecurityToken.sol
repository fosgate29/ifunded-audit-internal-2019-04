pragma solidity ^0.5.4;

import "./whitelists/iEstate/DefaultSecurityTokenWhitelist.sol";
import "./ERC/ERC1400/ERC1400.sol";

/**
 * @title Represents a security token compliant with the ERC-1400 family of standards.
 */
contract SecurityToken is ERC1400 {

    // The whitelist interface
    DefaultSecurityTokenWhitelist private _whitelist;

    // The security roles defined in our custom implementation
    bytes32 constant private APP_IDENTIFIER = "iEstate STO Platform";
    bytes32 constant private SECURITY_LEVEL1 = "iEstate STO Platform - Level1";
    bytes32 constant private SECURITY_LEVEL2 = "iEstate STO Platform - Level2";

    /**
     * @notice Constructor 
     * @param owner The address of the contract owner (aka: the "owner" of the security token)
     * @param controllerAddr The address of the controller, if any, as per ERC-1644
     * @param whitelistProxy The whitelist's proxy interface
     * @param tokenName The name of the token
     * @param tokenSymbol The symbol of the token
     */
    constructor
    (
        address owner, 
        address controllerAddr, 
        DefaultSecurityTokenWhitelist whitelistProxy,
        string memory tokenName, 
        string memory tokenSymbol
    ) 
    public ERC1400(owner, controllerAddr, APP_IDENTIFIER, tokenName, tokenSymbol, 0) {
        _whitelist = whitelistProxy;
    }

    /**
     * @notice Indicates if the address specified is allowed to pause/unpause the token.
     * @param addr Specifies the address.
     * @return returns true if the address is allowed to perform the action requested.
     */
    function canPause(address addr) public view returns(bool) {
        return _whitelist.isMemberOf(addr, SECURITY_LEVEL2, APP_IDENTIFIER);
    }

    /**
     * @notice Indicates if the address specified is allowed to issue tokens.
     * @param addr Specifies the address.
     * @return returns true if the address is allowed to perform the action requested.
     */
    function canIssue(address addr) public view returns(bool) {
        return _whitelist.isMemberOf(addr, SECURITY_LEVEL2, APP_IDENTIFIER);
    }

    /**
     * @notice Indicates if the address specified is allowed to redeem tokens.
     * @param addr Specifies the address.
     * @return returns true if the address is allowed to perform the action requested.
     */
    function canRedeem(address addr) public view returns(bool) {
        return _whitelist.isMemberOf(addr, SECURITY_LEVEL2, APP_IDENTIFIER);
    }

    /**
     * @notice Indicates if the address specified is allowed to freeze the issuance of tokens.
     * @param addr Specifies the address.
     * @return returns true if the address is allowed to perform the action requested.
     */
    function canFreezeMinting(address addr) public view returns(bool) {
        return _whitelist.isMemberOf(addr, SECURITY_LEVEL2, APP_IDENTIFIER);
    }

    /**
     * @notice Indicates if the address specified is whitelisted
     * @param addr Specifies the address.
     * @return returns true if the address is whitelisted.
     */
    function isWhitelisted(address addr) public view returns(bool) {
        return _whitelist.isWhitelisted(addr, APP_IDENTIFIER);
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
     * @return ESC (Ethereum Status Code) following the EIP-1066 standard
     * @return Application specific reason codes with additional details
     */
    function _validateTokenTransfer(address from, address to, bytes32, bytes memory) 
    internal view returns (byte, bytes32) {

        // Make sure the from address is whitelisted
        if (!_whitelist.isWhitelisted(from, APP_IDENTIFIER)) {
            return (EIP1066_NOT_FOUND, "The sender is not whitelisted.");
        }

        // Make sure the receiver is whitelisted
        if (!_whitelist.isWhitelisted(to, APP_IDENTIFIER)) {
            return (EIP1066_NOT_FOUND, "The receiver is not whitelisted.");
        }

        return (EIP1066_TOKEN_TRANSFER_SUCCESSFUL, "Transfer Successful");
    }

}