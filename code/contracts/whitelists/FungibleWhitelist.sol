pragma solidity ^0.5.4;

import "./../ownership/OwnableNonTransferable.sol";
import "./IFungibleWhitelist.sol";

/**
 * @title FungibleWhitelist
 * @dev This contract implements an operator-based Fungible Whitelist.
 *
 * The owner of the contract grants/revokes access to whitelist operators.
 * Only operators are allowed to add/remove recipients from the whitelist.
 */
contract FungibleWhitelist is IFungibleWhitelist, OwnableNonTransferable {

    // Constants
    bytes32 constant private ZERO_BYTES = bytes32(0);
    address constant private ZERO_ADDRESS = address(0);

    // Mappings
    mapping (bytes32 => mapping (address => bytes32)) private _verified;

    /**
     * @notice Constructor
     * @param owner The owner of the smart contract
     */
    constructor(address owner) public OwnableNonTransferable(owner) { // solhint-disable-line no-empty-blocks
    }

    /**
     * @notice Ensures that the sender is allowed to whitelist other addresses on the asset specified.
     * @param addr The address of the operator
     * @param asset The asset the operator is allowed to manage
     */
    modifier onlyWhitelistOperator(address addr, bytes32 asset) {
        require(this.isWhitelistOperator(addr, asset), 
        "Only operators are allowed to add or remove addresses from the whitelist on the asset specified");
        _;
    }

    /**
     * @notice Adds a verified address, along with an associated verification hash to the contract.
     * The address is whitelisted on the asset specified only.
     * Upon successful addition of a verified address the contract emits an "VerifiedAddressAdded" event.
     * It MUST throw if the supplied address or hash are zero, or if the address has already been supplied.
     * @param addr The address of the person represented by the supplied hash.
     * @param verificationHash A cryptographic hash of the address holder's verified information.
     * @param asset Specifies the asset identifier.
     */
    function addVerified(address addr, bytes32 verificationHash, bytes32 asset) external 
    onlyWhitelistOperator(msg.sender, asset)
    {
        _addVerified(addr, verificationHash, asset);
    }

    /**
     * @notice Removes an address from the whitelist.
     * The address is removed from the asset specified only.
     * If the address is unknown to the contract then this does nothing. 
     * If the address is successfully removed, this function emits an "VerifiedAddressRemoved" event.
     * @param addr The verified address to be removed.
     * @param asset Specifies the asset identifier.
     */
    function removeVerified(address addr, bytes32 asset) external onlyWhitelistOperator(msg.sender, asset)
    {
        require(addr != ZERO_ADDRESS, "The address is required.");

        if (_verified[asset][addr] != ZERO_BYTES) {
            _verified[asset][addr] = ZERO_BYTES;
            emit VerifiedAddressRemoved(addr, asset, msg.sender);
        }
    }

     /**
     * @notice Updates the hash of a verified address on the asset specified.
     * Upon successful update of a verified address the contract will emit an "VerifiedAddressUpdated" event.
     * If the hash is the same as the value already stored then no "VerifiedAddressUpdated" event is to be emitted.
     * It MUST throw if the hash is zero, or if the address is unverified.
     * @param addr The verified address of the person represented by the supplied hash.
     * @param hash A new cryptographic hash of the address holder's updated verified information.
     * @param asset Specifies the asset identifier.
     */
    function updateVerified(address addr, bytes32 hash, bytes32 asset) external 
    onlyWhitelistOperator(msg.sender, asset)
    {
        require(addr != ZERO_ADDRESS, "The address is required.");
        require(hash != ZERO_BYTES, "The verification hash is required.");

        bytes32 oldHash = _verified[asset][addr];
        require(oldHash != ZERO_BYTES, "The address does not exist.");

        if (oldHash != hash) {
            _verified[asset][addr] = hash;
            emit VerifiedAddressUpdated(addr, oldHash, hash, asset, msg.sender);
        }
    }

    /**
     * @notice Adds a list of verified addresses to the whitelist, along with their respective verification hash.
     * The addresses are whitelisted on the asset specified only.
     * This function emits an "VerifiedAddressAdded" event upon successful addition of all verified address.
     * It throws an error if the supplied address or hash are zero, or if the address has already been supplied.
     * @param addresses The list of addresses to add.
     * @param hashes The cryptographic hashes to add.
     * @param asset Specifies the asset identifier.
     */
    function addVerifiedAsBulk(address[] calldata addresses, bytes32[] calldata hashes, bytes32 asset) 
    external onlyWhitelistOperator(msg.sender, asset) {
        require(addresses.length == hashes.length, "Addresses and hashes should be of the same length.");
        
        for (uint256 i = 0; i < addresses.length; i++) {
            _addVerified(addresses[i], hashes[i], asset);
        }
    }

    /**
     * @notice Indicates if the operator specified is allowed to whitelist addresses.
     * Only the owner of the contract is allowed to add/remove operators.
     * @param addr The address of the operator
     * @param asset The asset the operator is allowed to manage
     * @return returns true if the operator specified is allowed to whitelist other addresses.
     */
    function isWhitelistOperator(address addr, bytes32 asset) external view returns (bool);

    /**
     * @notice Checks that the supplied hash is associated with the given address and asset.
     * @param addr The address to test.
     * @param hash The hash to test.
     * @param asset Specifies the asset identifier.
     * @return true if the hash matches the one supplied with the address in "addVerified" or "updateVerified".
     */
    function hasHash(address addr, bytes32 hash, bytes32 asset) external view returns(bool)
    {
        if (addr == ZERO_ADDRESS) {
            return false;
        } else {
            return _verified[asset][addr] == hash;
        }
    }

    /**
     * @notice Indicates if a given address is whitelisted on the asset specified.
     * @param addr The address to test.
     * @param asset Specifies the asset identifier.
     * @return returns true if the address is whitelisted.
     */
    function isWhitelisted(address addr, bytes32 asset) external view returns(bool) {
        return _verified[asset][addr] != ZERO_BYTES;
    }

    /**
     * @notice Adds a verified address, along with an associated verification hash to the contract.
     * The address is whitelisted on the asset specified only.
     * Upon successful addition of a verified address the contract emits an "VerifiedAddressAdded" event.
     * It MUST throw if the supplied address or hash are zero, or if the address has already been supplied.
     * @param addr The address of the person represented by the supplied hash.
     * @param verificationHash A cryptographic hash of the address holder's verified information.
     * @param asset Specifies the asset identifier.
     */
    function _addVerified(address addr, bytes32 verificationHash, bytes32 asset) private {
        require(addr != ZERO_ADDRESS, "The address is required.");
        require(verificationHash != ZERO_BYTES, "The verification hash is required.");
        require(_verified[asset][addr] == ZERO_BYTES, "The address has already been supplied.");

        _verified[asset][addr] = verificationHash;
        emit VerifiedAddressAdded(addr, verificationHash, asset, msg.sender);
    }
}
