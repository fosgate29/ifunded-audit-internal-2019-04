
// File: contracts/ownership/OwnableNonTransferable.sol

pragma solidity ^0.5.4;

/**
 * @title OwnableNonTransferable
 * @dev This contract defines an non-transferable owner.
 * In this contract the owner cannot renounce to their ownership nor transfer ownership to others.
 */
contract OwnableNonTransferable {
    address private _owner;

    /**
     * Constructor
     * @param addr The owner of the smart contract
     */
    constructor (address addr) internal {
        require(addr != address(0), "The address of the owner is required");
        _owner = addr;
    }

    /**
     * @return the address of the owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyContractOwner(address addr) {
        require(isOwner(addr), "Only the owner of the contract is allowed to call this function.");
        _;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(msg.sender), "Only the owner of the smart contract is allowed to call this function.");
        _;
    }

    /**
     * @return true if `msg.sender` is the owner of the contract.
     */
    function isOwner(address addr) public view returns (bool) {
        return addr == _owner;
    }    
}

// File: contracts/access/RoleBasedAccessControl.sol

pragma solidity ^0.5.4;


/**
 * @title RoleBasedAccessControl
 * @dev This contract implements generic roles-based access control.
 */
contract RoleBasedAccessControl is OwnableNonTransferable {

    // Constants    
    bytes32 constant private ZERO_BYTES = bytes32(0);
    address constant private ZERO_ADDRESS = address(0);

    // Mappings
    mapping (address => mapping (bytes32 => bool)) private _securityOperators;
    mapping (address => mapping (bytes32 => mapping (bytes32 => bool))) private _addressRoles;

    event SecurityOperatorAdded(address indexed operator, bytes32 indexed asset);
    event SecurityOperatorRemoved(address indexed operator, bytes32 indexed asset);

    /**
     * Constructor
     * @param owner The owner of the smart contract
     */
    constructor(address owner) internal OwnableNonTransferable(owner) {
    }

    /**
     * Checks if the sender is allowed to define role members.
     */
    modifier onlySecurityOperator(bytes32 asset) {
        require(isSecurityOperator(msg.sender, asset), 
        "Only RBAC security operators are allowed to define roles membership");
        _;
    }

    /**
     * Indicates if the address specified is allowed to define role membership.
     * @param addr The address of the operator.
     * @param asset The asset the operator is allowed to manage.
     * @return returns true if the operator specified is permitted to define role membership.
     */
    function isSecurityOperator(address addr, bytes32 asset) public view returns (bool) {
        return _securityOperators[addr][asset];
    }

    /**
     * Allows the address specified to define role membership.
     * Only the owner of the contract is allowed to add/remove operators.
     * @param addr The address of the operator.
     * @param asset The asset the operator is allowed to manage.
     */
    function addOperator(address addr, bytes32 asset) public onlyContractOwner(msg.sender) {
        require(addr != ZERO_ADDRESS, "The address is required.");
        require(!isSecurityOperator(addr, asset), "The operator already exists.");
        _securityOperators[addr][asset] = true;
        emit SecurityOperatorAdded(addr, asset);
    }

    /**
     * Revokes access to the operator specified.
     * Only the owner of the contract is allowed to add/remove operators.
     * @param addr The address of the operator
     * @param asset The asset the operator is allowed to manage.
     */
    function removeOperator(address addr, bytes32 asset) public onlyContractOwner(msg.sender) {
        require(addr != ZERO_ADDRESS, "The address of the whitelist operator is required.");
        require(isSecurityOperator(addr, asset), "The operator does not exist.");
        _securityOperators[addr][asset] = false;
        emit SecurityOperatorRemoved(addr, asset);
    }

    /**
     * Indicates whether a given address belongs to the role specified.
     * @param addr Specifies the address.
     * @param role Specifies the role.
     * @param asset The asset the operator is allowed to manage.
     */
    function isMemberOf(address addr, bytes32 role, bytes32 asset) public view returns (bool) {
        require(addr != ZERO_ADDRESS, "The address is required.");
        require(role != ZERO_BYTES, "The role is required.");
        require(asset != ZERO_BYTES, "The asset is required.");
        return _addressRoles[addr][role][asset];
    }

    /**
     * Adds a public address to the role specified.
     * @param addr Specifies the address.
     * @param role Specifies the role.
     * @param asset The asset the operator is allowed to manage.
     */
    function addToRole(address addr, bytes32 role, bytes32 asset) public onlySecurityOperator(asset) {
        require(addr != ZERO_ADDRESS, "The address is required.");
        require(role != ZERO_BYTES, "The role is required.");
        require(asset != ZERO_BYTES, "The asset is required.");
        require(!isMemberOf(addr, role, asset), "The address has been added to this role already.");
        _addressRoles[addr][role][asset] = true;
    }
    
     /**
     * Removes a public address from the role specified.
     * @param addr Specifies the address.
     * @param role Specifies the role.
     * @param asset The asset the operator is allowed to manage.
     */
    function removeFromRole(address addr, bytes32 role, bytes32 asset) public onlySecurityOperator(asset) {
        require(addr != ZERO_ADDRESS, "The address is required.");
        require(role != ZERO_BYTES, "The role is required.");
        require(asset != ZERO_BYTES, "The asset is required.");
        require(isMemberOf(addr, role, asset), "The address is not a member of this role.");
        _addressRoles[addr][role][asset] = false;
    }
}

// File: contracts/access/iEstate/PlatformProviderRbac.sol

pragma solidity ^0.5.4;


/**
 * @title PlatformProviderRoleAccess
 * @dev This contract implements RBAC on the iEstate Platform.
 */
contract PlatformProviderRbac is RoleBasedAccessControl {

    // The security roles defined in our custom implementation
    bytes32 constant internal APP_IDENTIFIER = "iEstate STO Platform";
    bytes32 constant internal SECURITY_LEVEL1 = "iEstate STO Platform - Level1";
    bytes32 constant internal SECURITY_LEVEL2 = "iEstate STO Platform - Level2";

    /**
     * Constructor
     * @param owner The owner of the smart contract
     */
    constructor(address owner) public RoleBasedAccessControl(owner) {
    }

    /**
     * Checks that the address specified has Level-1 access.
     * @param addr The address to evaluate
     */
    modifier onlyLevel1(address addr) {
        require(isLevel1(addr), "Insufficient permissions. This function requires Level 1 access.");
        _;
    }

    /**
     * Checks that the address specified has Level-2 access.
     * @param addr The address to evaluate
     */
    modifier onlyLevel2(address addr) {
        require(isLevel2(addr), "Insufficient permissions. This function requires Level 2 access.");
        _;
    }

    /**
     * Gets the application identifier.
     * @return returns the app identifier.
     */
    function getAppIdentifier() public pure returns (bytes32) {
        return APP_IDENTIFIER;
    }

    /**
     * Adds the address specified to the application role "Level 1".
     * Only security operators are allowed to define role membership.
     * @param addr Specifies the address
     */
    function addToLevel1(address addr) public onlySecurityOperator(APP_IDENTIFIER) {
        addToRole(addr, SECURITY_LEVEL1, APP_IDENTIFIER);
    }

    /**
     * Adds the address specified to the application role "Level 2".
     * Only security operators are allowed to define role membership.
     * @param addr Specifies the address
     */
    function addToLevel2(address addr) public onlySecurityOperator(APP_IDENTIFIER) {
        addToRole(addr, SECURITY_LEVEL2, APP_IDENTIFIER);
    }

    /**
     * Removes the address specified from the application role "Level 1".
     * Only security operators are allowed to define role membership.
     * @param addr Specifies the address
     */
    function removeFromLevel1(address addr) public onlySecurityOperator(APP_IDENTIFIER) {
        removeFromRole(addr, SECURITY_LEVEL1, APP_IDENTIFIER);
    }

    /**
     * Removes the address specified from the application role "Level 2".
     * Only security operators are allowed to define role membership.
     * @param addr Specifies the address
     */
    function removeFromLevel2(address addr) public onlySecurityOperator(APP_IDENTIFIER) {
        removeFromRole(addr, SECURITY_LEVEL2, APP_IDENTIFIER);
    }

    /**
     * Indicates if the address specified belongs to the role "Level 1"
     * @param addr Specifies the address to check
     * @return returns true if the address belongs to the role.
     */
    function isLevel1(address addr) public view returns (bool) {
        return isMemberOf(addr, SECURITY_LEVEL1, APP_IDENTIFIER);
    }

    /**
     * Indicates if the address specified belongs to the role "Level 2"
     * @param addr Specifies the address to check
     * @return returns true if the address belongs to the role.
     */
    function isLevel2(address addr) public view returns (bool) {
        return isMemberOf(addr, SECURITY_LEVEL2, APP_IDENTIFIER);
    }
}

// File: contracts/whitelists/IFungibleWhitelist.sol

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
     * @param hash A cryptographic hash of the address holder's verified information.
     * @param asset Specifies the asset identifier.
     * @param caller Specifies the caller.
     */
    function addVerified(address addr, bytes32 hash, bytes32 asset, address caller) external;

    /**
     * @notice Removes an address from the whitelist.
     * The address is removed from the asset specified only.
     * If the address is unknown to the contract then this does nothing. 
     * If the address is successfully removed, this function emits an "VerifiedAddressRemoved" event.
     * @param addr The verified address to be removed.
     * @param asset Specifies the asset identifier.
     * @param caller Specifies the caller.
     */
    function removeVerified(address addr, bytes32 asset, address caller) external;

     /**
     * @notice Updates the hash of a verified address on the asset specified.
     * Upon successful update of a verified address the contract will emit an "VerifiedAddressUpdated" event.
     * If the hash is the same as the value already stored then no "VerifiedAddressUpdated" event is to be emitted.
     * It MUST throw if the hash is zero, or if the address is unverified.
     * @param addr The verified address of the person represented by the supplied hash.
     * @param hash A new cryptographic hash of the address holder's updated verified information.
     * @param asset Specifies the asset identifier.
     * @param caller Specifies the caller.
     */
    function updateVerified(address addr, bytes32 hash, bytes32 asset, address caller) external;

    /**
     * @notice Adds a list of verified addresses to the whitelist, along with their respective verification hash.
     * The addresses are whitelisted on the asset specified only.
     * This function emits an "VerifiedAddressAdded" event upon successful addition of all verified address.
     * It throws an error if the supplied address or hash are zero, or if the address has already been supplied.
     * @param addresses The list of addresses to add.
     * @param hashes The cryptographic hashes to add.
     * @param asset Specifies the asset identifier.
     * @param caller Specifies the caller.
     */
    function addVerifiedAsBulk(address[] calldata addresses, bytes32[] calldata hashes, bytes32 asset, address caller) 
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

// File: contracts/whitelists/FungibleWhitelist.sol

pragma solidity ^0.5.4;



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
    constructor(address owner) public OwnableNonTransferable(owner) {
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
     * @param hash A cryptographic hash of the address holder's verified information.
     * @param asset Specifies the asset identifier.
     * @param caller Specifies the caller.
     */
    function addVerified(address addr, bytes32 hash, bytes32 asset, address caller) external 
    onlyWhitelistOperator(caller, asset)
    {
        require(addr != ZERO_ADDRESS, "The address is required.");
        require(hash != ZERO_BYTES, "The verification hash is required.");
        require(_verified[asset][addr] == ZERO_BYTES, "The address has already been supplied.");

        _verified[asset][addr] = hash;
        emit VerifiedAddressAdded(addr, hash, asset, caller);
    }

    /**
     * @notice Removes an address from the whitelist.
     * The address is removed from the asset specified only.
     * If the address is unknown to the contract then this does nothing. 
     * If the address is successfully removed, this function emits an "VerifiedAddressRemoved" event.
     * @param addr The verified address to be removed.
     * @param asset Specifies the asset identifier.
     * @param caller Specifies the caller.
     */
    function removeVerified(address addr, bytes32 asset, address caller) external onlyWhitelistOperator(caller, asset)
    {
        require(addr != ZERO_ADDRESS, "The address is required.");

        if (_verified[asset][addr] != ZERO_BYTES) {
            _verified[asset][addr] = ZERO_BYTES;
            emit VerifiedAddressRemoved(addr, asset, caller);
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
     * @param caller Specifies the caller.
     */
    function updateVerified(address addr, bytes32 hash, bytes32 asset, address caller) external 
    onlyWhitelistOperator(caller, asset)
    {
        require(addr != ZERO_ADDRESS, "The address is required.");
        require(hash != ZERO_BYTES, "The verification hash is required.");

        bytes32 oldHash = _verified[asset][addr];
        require(oldHash != ZERO_BYTES, "The address does not exist.");

        if (oldHash != hash) {
            _verified[asset][addr] = hash;
            emit VerifiedAddressUpdated(addr, oldHash, hash, asset, caller);
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
    function addVerifiedAsBulk(address[] calldata addresses, bytes32[] calldata hashes, bytes32 asset, address caller) 
    external onlyWhitelistOperator(caller, asset) {
        require(addresses.length == hashes.length, "Addresses and hashes should be of the same length.");
        
        for (uint256 i = 0; i < addresses.length; i++) {
            this.addVerified(addresses[i], hashes[i], asset, caller);
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
}

// File: contracts/whitelists/iEstate/DefaultSecurityTokenWhitelist.sol

pragma solidity ^0.5.4;



/**
 * @title DefaultSecurityTokenWhitelist
 * @dev This contract allows to manage whitelists on the iEstate Platform.
 */
contract DefaultSecurityTokenWhitelist is FungibleWhitelist {
    
    // The contract responsible for handling role-based access permissions on a given platform.
    PlatformProviderRbac private rbac;

    /**
     * Constructor
     * @param owner The owner of the smart contract
     * @param rbacAddress The address of the smart contract that implements RBAC.
     */
    constructor(address owner, address rbacAddress) public FungibleWhitelist(owner) {
        rbac = PlatformProviderRbac(rbacAddress);
    }

    /**
     * Indicates if the operator specified is allowed to whitelist addresses.
     * Only the owner of the contract is allowed to add/remove operators.
     * @param addr The address of the operator
     * @return returns true if the operator specified is allowed to whitelist other addresses.
     */
    function isWhitelistOperator(address addr, bytes32) external view returns (bool) {
        return rbac.isLevel1(addr);
    }

    /**
     * Indicates whether a given address belongs to the role specified.
     * @param addr Specifies the address.
     * @param role Specifies the role.
     * @param asset The asset the operator is allowed to manage.
     */
    function isMemberOf(address addr, bytes32 role, bytes32 asset) public view returns (bool) {
        return rbac.isMemberOf(addr, role, asset);
    }
}
