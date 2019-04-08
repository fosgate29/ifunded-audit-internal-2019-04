pragma solidity ^0.5.4;

/**
 * @title Defines an interface for whitelisting public addresses on a given asset.
 */
interface IFungibleWhitelist {

    /**
     * @notice This event is emitted when a verified address and associated identity hash are
     * added to the contract.
     * @param addr The address that was added.
     * @param hash The identity hash associated with the address.
     * @param asset Specifies the asset identifier.
     * @param sender The address that caused the address to be added.
     */
    event VerifiedAddressAdded(address indexed addr, bytes32 hash, bytes32 asset, address indexed sender);

    /**
     * @notice This event is emitted when a verified address its associated identity hash are
     * removed from the contract.
     * @param addr The address that was removed.
     * @param asset Specifies the asset identifier.
     * @param sender The address that caused the address to be removed.
     */
    event VerifiedAddressRemoved(address indexed addr, bytes32 asset, address indexed sender);

    /**
     * @notice This event is emitted when the identity hash associated with a verified address is updated.
     * @param addr The address whose hash was updated.
     * @param oldHash The identity hash that was associated with the address.
     * @param hash The hash now associated with the address.
     * @param asset Specifies the asset identifier.
     * @param sender The address that caused the hash to be updated.
     */
    event VerifiedAddressUpdated(
        address indexed addr,
        bytes32 oldHash,
        bytes32 hash,
        bytes32 asset,
        address indexed sender
    );

    /**
     * @notice Adds a verified address, along with an associated verification hash to the contract.
     * The address is whitelisted on the asset specified only.
     * Upon successful addition of a verified address the contract emits an "VerifiedAddressAdded" event.
     * It MUST throw if the supplied address or hash are zero, or if the address has already been supplied.
     * @param addr The address of the person represented by the supplied hash.
     * @param verificationHash A cryptographic hash of the address holder's verified information.
     * @param asset Specifies the asset identifier.
     */
    function addVerified(address addr, bytes32 verificationHash, bytes32 asset) external;

    /**
     * @notice Removes an address from the whitelist.
     * The address is removed from the asset specified only.
     * If the address is unknown to the contract then this does nothing. 
     * If the address is successfully removed, this function emits an "VerifiedAddressRemoved" event.
     * @param addr The verified address to be removed.
     * @param asset Specifies the asset identifier.
     */
    function removeVerified(address addr, bytes32 asset) external;

     /**
     * @notice Updates the hash of a verified address on the asset specified.
     * Upon successful update of a verified address the contract will emit an "VerifiedAddressUpdated" event.
     * If the hash is the same as the value already stored then no "VerifiedAddressUpdated" event is to be emitted.
     * It MUST throw if the hash is zero, or if the address is unverified.
     * @param addr The verified address of the person represented by the supplied hash.
     * @param hash A new cryptographic hash of the address holder's updated verified information.
     * @param asset Specifies the asset identifier.
     */
    function updateVerified(address addr, bytes32 hash, bytes32 asset) external;

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
    external;

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
    function hasHash(address addr, bytes32 hash, bytes32 asset) external view returns(bool);

    /**
     * @notice Indicates if a given address is whitelisted on the asset specified.
     * @param addr The address to test.
     * @param asset Specifies the asset identifier.
     * @return returns true if the address is whitelisted.
     */
    function isWhitelisted(address addr, bytes32 asset) external view returns(bool);
}
