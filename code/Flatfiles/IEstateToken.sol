
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

// File: contracts/math/SafeMath.sol

 

/**
 * @title SafeMath
 * @dev Unsigned math operations with safety checks that revert on error
 */
library SafeMath {
    /**
    * @dev Multiplies two unsigned integers, reverts on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "mul error");

        return c;
    }

    /**
    * @dev Integer division of two unsigned integers truncating the quotient, reverts on division by zero.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "div error: b needs to be greater than zero");
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
    * @dev Subtracts two unsigned integers, reverts on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "sub error: b <= a");
        uint256 c = a - b;

        return c;
    }

    /**
    * @dev Adds two unsigned integers, reverts on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "add error: c >= a");

        return c;
    }

    /**
    * @dev Divides two unsigned integers and returns the remainder (unsigned integer modulo),
    * reverts when dividing by zero.
    */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "mod error: b != 0");
        return a % b;
    }
}

// File: contracts/math/KindMath.sol

 

/**
 * @title KindMath
 * @notice ref. https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/contracts/math/SafeMath.sol
 * @dev Math operations with safety checks that returns boolean
 */
library KindMath {

    /**
     * @dev Multiplies two numbers, return false on overflow.
     */
    function checkMul(uint256 a, uint256 b) internal pure returns (bool) {
        // Gas optimization: this is cheaper than requireing 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return true;
        }

        uint256 c = a * b;
        if (c / a == b)
            return true;
        else 
            return false;
    }

    /**
    * @dev Subtracts two numbers, return false on overflow (i.e. if subtrahend is greater than minuend).
    */
    function checkSub(uint256 a, uint256 b) internal pure returns (bool) {
        if (b <= a)
            return true;
        else
            return false;
    }

    /**
    * @dev Adds two numbers, return false on overflow.
    */
    function checkAdd(uint256 a, uint256 b) internal pure returns (bool) {
        uint256 c = a + b;
        if (c < a)
            return false;
        else
            return true;
    }
}

// File: contracts/access/ReentrancyGuard.sol

 

/**
 * @title Helps contracts guard against reentrancy attacks.
 * @author Remco Bloemen <remco@2π.com>, Eenae <alexey@mixbytes.io>
 * @dev If you mark a function `nonReentrant`, you should also
 * mark it `external`.
 */
contract ReentrancyGuard {
    /// @dev counter to allow mutex lock with only one SSTORE operation
    uint256 private _guardCounter;

    constructor () internal {
        // The counter starts at one to prevent changing it from zero to a non-zero
        // value, which is a more expensive operation.
        _guardCounter = 1;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _guardCounter += 1;
        uint256 localCounter = _guardCounter;
        _;
        require(localCounter == _guardCounter, "Reentrancy error");
    }
}

// File: contracts/ERC/ERC1643/IERC1643.sol

 

/**
 * @title IERC1643 Document Management (part of the ERC1400 Security Token Standards)
 * @dev See https://github.com/SecurityTokenStandard/EIP-Spec
 */
interface IERC1643 {

    // Document Management
    function setDocument(bytes32 _name, string calldata _uri, bytes32 _documentHash) external;
    function removeDocument(bytes32 _name) external;
    function getDocument(bytes32 _name) external view returns (string memory, bytes32, uint256);
    function getAllDocuments() external view returns (bytes32[] memory);

    // Document Events
    event DocumentRemoved(bytes32 indexed _name, string _uri, bytes32 _documentHash);
    event DocumentUpdated(bytes32 indexed _name, string _uri, bytes32 _documentHash);

}

// File: contracts/ERC/ERC1643/ERC1643.sol

 



/**
 * @title Standard implementation of ERC1643 Document management
 */
contract ERC1643 is IERC1643, OwnableNonTransferable {

    struct Document {
        bytes32 docHash;       // Hash of the document
        uint256 lastModified;  // Timestamp at which document details was last modified
        string uri;            // URI of the document that exist off-chain
    }

    // mapping to store the documents details in the document
    mapping(bytes32 => Document) private _documents;

    // mapping to store the document name indexes
    mapping(bytes32 => uint256) private _docIndexes;

    // Array use to store all the document name present in the contracts
    bytes32[] private _docNames;
    
    /**
     * Constructor
     * @param owner The owner of the smart contract
     */
    constructor(address owner) public OwnableNonTransferable(owner) {
    }

    /**
     * @notice Used to attach a new document to the contract, 
     * or update the URI or hash of an existing attached document
     * @dev Can only be executed by the owner of the contract.
     * @param _name Name of the document. It should be unique always
     * @param _uri Off-chain uri of the document from where it is accessible to investors/advisors to read.
     * @param _documentHash hash (of the contents) of the document.
     */
    function setDocument(bytes32 _name, string calldata _uri, bytes32 _documentHash) external onlyOwner {
        require(_name != bytes32(0), "Zero value is not allowed");
        require(bytes(_uri).length > 0, "Should not be a empty uri");
        if (_documents[_name].lastModified == uint256(0)) {
            _docNames.push(_name);
            _docIndexes[_name] = _docNames.length;
        }
        _documents[_name] = Document(_documentHash, now, _uri);
        emit DocumentUpdated(_name, _uri, _documentHash);
    }

    /**
     * @notice Used to remove an existing document from the contract by giving the name of the document.
     * @dev Can only be executed by the owner of the contract.
     * @param _name Name of the document. It should be unique always
     */
    function removeDocument(bytes32 _name) external onlyOwner {
        require(_documents[_name].lastModified != uint256(0), "Document should be existed");
        uint256 index = _docIndexes[_name] - 1;
        if (index != _docNames.length - 1) {
            _docNames[index] = _docNames[_docNames.length - 1];
            _docIndexes[_docNames[index]] = index + 1; 
        }
        _docNames.length--;
        emit DocumentRemoved(_name, _documents[_name].uri, _documents[_name].docHash);
        delete _documents[_name];
    }

    /**
     * @notice Used to return the details of a document with a known name (`bytes32`).
     * @param _name Name of the document
     * @return string The URI associated with the document.
     * @return bytes32 The hash (of the contents) of the document.
     * @return uint256 the timestamp at which the document was last modified.
     */
    function getDocument(bytes32 _name) external view returns (string memory, bytes32, uint256) {
        return (
            _documents[_name].uri,
            _documents[_name].docHash,
            _documents[_name].lastModified
        );
    }

    /**
     * @notice Used to retrieve a full list of documents attached to the smart contract.
     * @return bytes32 List of all documents names present in the contract.
     */
    function getAllDocuments() external view returns (bytes32[] memory) {
        return _docNames;
    }
}

// File: contracts/ERC/ERC1644/IERC1644.sol

 

/**
 * @title Defines the interface of ERC-1644 (Controller Token Operation Standard) as per https://github.com/ethereum/EIPs/issues/1644
 */
interface IERC1644 {

    /**
     * @notice This function allows an authorized address to transfer tokens between any two token holders.
     * The transfer must still respect the balances of the token holders (so the transfer must be for at most "balanceOf(_from)" tokens) 
     * and potentially also need to respect other transfer restrictions.
     * This function can only be executed by the controller address.
     *
     * @param from The address which you want to send tokens from
     * @param to The address which you want to transfer to
     * @param value The amount of tokens to be transferred
     * @param data The data to validate the transfer.
     * @param operatorData The data attached to the transfer by controller to emit in event. It is more like a reason string 
     * for calling this function (aka force transfer) which provides the transparency on-chain. 
     */
    function controllerTransfer(address from, address to, uint256 value, bytes calldata data, bytes calldata operatorData) external;

    /**
     * @notice This function allows an authorized address to redeem tokens for any token holder.
     * The redemption must still respect the balances of the token holder (so the redemption must be for at most
     * "balanceOf(_tokenHolder)" tokens) and potentially also need to respect other transfer restrictions.
     * This function can only be executed by the controller address.
     *
     * @param tokenHolder The account whose tokens will be redeemed.
     * @param value The amount of tokens that need to be redeemed.
     * @param data The data to validate the transfer.
     * @param operatorData The data attached to the transfer by controller to emit in event. It is more like a reason string 
     * for calling this function (aka force transfer) which provides the transparency on-chain. 
     */
    function controllerRedeem(address tokenHolder, uint256 value, bytes calldata data, bytes calldata operatorData) external;

    /**
     * @notice Indicates whether the token is controllable or not.
     * If the token is controllable then the controller address is allowed to do the following:
     * 1) To transfer tokens between any two token holders, by calling the function "controllerTransfer"
     * 2) To redeem a given amount of tokens by calling the function "controllerRedeem"
     * 
     * If the token is not controllable then the functions "controllerTransfer" and "controllerRedeem" are guaranteed to fail
     * because they they can only be called by a controller.
     *
     * @return returns true if the token is controllable
     */
    function isControllable() external view returns (bool);

    /**
     * @notice This event is emitted when a controller transfers a given token amount between two addresses.
     * @param controller The address of the controller
     * @param from The address of the tokens holder
     * @param to The address of the receiver
     * @param value The amount of tokens to be transferred
     * @param data The data to validate the transfer
     * @param operatorData The data attached by the controller during the token tranfer.
     * It usually contains a reason string (for example "force transfer") in order to provide transparency on-chain. 
     */
    event ControllerTransfer(
        address controller,
        address indexed from,
        address indexed to,
        uint256 value,
        bytes data,
        bytes operatorData
    );

    event ControllerRedemption(
        address controller,
        address indexed tokenHolder,
        uint256 value,
        bytes data,
        bytes operatorData
    );

}

// File: contracts/ERC/ERC1410/IERC1410.sol

 

interface IERC1410 {

    // Token Transfers
    function transferByPartition(bytes32 partition, address to, uint256 value, bytes calldata data) external returns (bytes32);
    function operatorTransferByPartition(bytes32 partition, address from, address to, uint256 value, bytes calldata data, bytes calldata operatorData) external returns (bytes32);

    // Operator Management
    function authorizeOperator(address operator) external;
    function revokeOperator(address operator) external;
    function authorizeOperatorByPartition(bytes32 partition, address operator) external;
    function revokeOperatorByPartition(bytes32 partition, address operator) external;

    // Issuance / Redemption
    function issueByPartition(bytes32 partition, address tokenHolder, uint256 value, bytes calldata data) external;
    function redeemByPartition(bytes32 partition, uint256 value, bytes calldata data) external;
    function operatorRedeemByPartition(bytes32 partition, address tokenHolder, uint256 value, bytes calldata data, bytes calldata operatorData) external;

    // Token Information
    function balanceOf(address addr) external view returns (uint256);
    function balanceOfByPartition(bytes32 partition, address addr) external view returns (uint256);
    function partitionsOf(address addr) external view returns (bytes32[] memory);
    function totalSupply() external view returns (uint256);

    // Operator Information
    function isOperator(address operator, address tokenHolder) external view returns (bool);
    function isOperatorForPartition(bytes32 partition, address operator, address tokenHolder) external view returns (bool);
    function canTransferByPartition(address from, address to, bytes32 partition, uint256 value, bytes calldata data) external view returns (byte, bytes32, bytes32);    

    // Transfer Events
    event TransferByPartition(
        bytes32 indexed _fromPartition,
        address _operator,
        address indexed _from,
        address indexed _to,
        uint256 _value,
        bytes _data,
        bytes _operatorData
    );

    // Operator Events
    event AuthorizedOperator(address indexed operator, address indexed tokenHolder);
    event RevokedOperator(address indexed operator, address indexed tokenHolder);
    event AuthorizedOperatorByPartition(bytes32 indexed partition, address indexed operator, address indexed tokenHolder);
    event RevokedOperatorByPartition(bytes32 indexed partition, address indexed operator, address indexed tokenHolder);

    // Issuance / Redemption Events
    event IssuedByPartition(bytes32 indexed partition, address indexed to, uint256 value, bytes data);
    event RedeemedByPartition(bytes32 indexed partition, address indexed operator, address indexed from, uint256 value, bytes data, bytes operatorData);

}

// File: contracts/ERC/ERC1410/ERC1410.sol

 







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
        if (!isSafeAddress(addr)) { return false; }
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
            if (_paused) { return (EIP1066_TOKEN_TRANSFER_FAILED, "Token trading is paused", ZERO_BYTES32); }

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
        if (!isSafeAddress(from)) { return (0x57, "Invalid sender", ZERO_BYTES32); }
        if (!isSafeAddress(to)) { return (0x57, "Invalid receiver", ZERO_BYTES32); }

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

// File: contracts/ERC/ERC20/IERC20.sol

 

/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
interface IERC20 {
    /**
    * Transfer token for a specified address
    * @param to The address to transfer to.
    * @param value The amount to be transferred.
    */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * Transfer tokens from one address to another.
     * Note that while this function emits an Approval event, this is not required as per the specification,
     * and other compliant implementations may not emit the event.
     * @param from address The address which you want to send tokens from
     * @param to address The address which you want to transfer to
     * @param value uint256 the amount of tokens to be transferred
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);

    /**
     * Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
     * Beware that changing an allowance with this method brings the risk that someone may use both the old
     * and the new allowance by unfortunate transaction ordering. 
     * One possible solution to mitigate this race condition is to first reduce the spender's allowance to 0 
     * and set the desired value afterwards: https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * Returns the total number of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
    * Gets the balance of the address specified.
    * @param addr The address to query the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function balanceOf(address addr) external view returns (uint256);

    /**
     * Function to check the amount of tokens that an owner allowed to a spender.
     * @param owner address The address which owns the funds.
     * @param spender address The address which will spend the funds.
     * @return A uint256 specifying the amount of tokens still available for the spender.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * This event is triggered when a given amount of tokens is sent to an address.
     * @param from The address of the sender
     * @param to The address of the receiver
     * @param value The amount transferred
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * This event is triggered when a given address is approved to spend a specific amount of tokens on behalf of the sender.
     * @param owner The owner of the token
     * @param spender The spender
     * @param value The amount to transfer
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

}

// File: contracts/ERC/ERC1594/IERC1594.sol

 

/**
 * @title Defines the interface of ERC-1594 (Security Token Standard) 
 * as per https://github.com/ethereum/EIPs/issues/1594
 */
interface IERC1594 {

    // Transfers
    function transferWithData(address to, uint256 value, bytes calldata data) external;
    function transferFromWithData(address from, address to, uint256 value, bytes calldata data) external;

    // Token Redemption
    function redeem(uint256 value, bytes calldata data) external;
    function redeemFrom(address tokenHolder, uint256 value, bytes calldata data) external;

    // Token Issuance
    function issue(address tokenHolder, uint256 value, bytes calldata data) external;
    function isIssuable() external view returns (bool);

    // Transfer Validity
    function canTransfer(address to, uint256 value, bytes calldata data) external view returns (bool, byte, bytes32);
    function canTransferFrom(address from, address to, uint256 value, bytes calldata data) external view returns (bool, byte, bytes32);

    // Issuance / Redemption Events
    event Issued(address indexed operator, address indexed to, uint256 value, bytes data);
    event Redeemed(address indexed operator, address indexed from, uint256 value, bytes data);

}

// File: contracts/ERC/ERC1400/ERC1400.sol

 




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

// File: contracts/SecurityToken/SecurityToken.sol

 



/**
 * @title Represents a security token compliant with the ERC-1400 family of standards.
 */
contract SecurityToken is ERC1400 {

    // The whitelist interface
    DefaultSecurityTokenWhitelist internal _whitelistInterface;

    // The security roles defined in our custom implementation
    bytes32 constant internal APP_IDENTIFIER = "iEstate STO Platform";
    bytes32 constant internal SECURITY_LEVEL1 = "iEstate STO Platform - Level1";
    bytes32 constant internal SECURITY_LEVEL2 = "iEstate STO Platform - Level2";

    /**
     * @notice Constructor 
     * @param owner The address of the contract owner (aka: the "owner" of the security token)
     * @param controllerAddr The address of the controller, if any, as per ERC-1644
     * @param whitelistAddr The address of the whitelist
     * @param tokenName The name of the token
     * @param tokenSymbol The symbol of the token
     */
    constructor
    (
        address owner, 
        address controllerAddr, 
        address whitelistAddr,
        string memory tokenName, 
        string memory tokenSymbol
    ) 
    public ERC1400(owner, controllerAddr, APP_IDENTIFIER, tokenName, tokenSymbol, 0) {
        _whitelistInterface = DefaultSecurityTokenWhitelist(whitelistAddr);
    }

    /**
     * @notice Indicates if the address specified is allowed to pause/unpause the token.
     * @param addr Specifies the address.
     * @return returns true if the address is allowed to perform the action requested.
     */
    function canPause(address addr) public view returns(bool) {
        return _whitelistInterface.isMemberOf(addr, SECURITY_LEVEL2, APP_IDENTIFIER);
    }

    /**
     * @notice Indicates if the address specified is allowed to issue tokens.
     * @param addr Specifies the address.
     * @return returns true if the address is allowed to perform the action requested.
     */
    function canIssue(address addr) public view returns(bool) {
        return _whitelistInterface.isMemberOf(addr, SECURITY_LEVEL2, APP_IDENTIFIER);
    }

    /**
     * @notice Indicates if the address specified is allowed to redeem tokens.
     * @param addr Specifies the address.
     * @return returns true if the address is allowed to perform the action requested.
     */
    function canRedeem(address addr) public view returns(bool) {
        return _whitelistInterface.isMemberOf(addr, SECURITY_LEVEL2, APP_IDENTIFIER);
    }

    /**
     * @notice Indicates if the address specified is allowed to freeze the issuance of tokens.
     * @param addr Specifies the address.
     * @return returns true if the address is allowed to perform the action requested.
     */
    function canFreezeMinting(address addr) public view returns(bool) {
        return _whitelistInterface.isMemberOf(addr, SECURITY_LEVEL2, APP_IDENTIFIER);
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
    internal view returns (byte, bytes32) {

        // Make sure the from address is whitelisted
        if (!_whitelistInterface.isWhitelisted(from, APP_IDENTIFIER)) {
            return (EIP1066_NOT_FOUND, "The sender is not whitelisted.");
        }

        // Make sure the receiver is whitelisted
        if (!_whitelistInterface.isWhitelisted(to, APP_IDENTIFIER)) {
            return (EIP1066_NOT_FOUND, "The receiver is not whitelisted.");
        }

        return (EIP1066_TOKEN_TRANSFER_SUCCESSFUL, "Transfer Successful");
    }

}

// File: contracts/InterestDistributingToken/IInterestDistributingToken.sol

 

interface IInterestDistributingToken {

    /**
    * Withdraws interest payment for the caller.
    * @param _token The address of token with which the interest payment is paid.
    */
    function withdrawInterest(address _token) external;
    
    /**
    * Sets interest payments for all the token holders.
    * @notice if the param _token provided is zero then it deals 
    * payments as Ethers otherwise it deals payments as _token
    * @param _token The address of token with which the interest payment is paid.
    * @param _investors The list of addresses which accept interest payment in _token
    * @param _payments The list of payments corresponding to each address in _addresses
    * @param _data It contains any data associated with the interest payment such as dates, exchange rate. 
    */
    function setInterestPaymentforWithdrawals(address _token, address[] calldata _investors, uint[] calldata _payments, bytes calldata _data) external;

    /**
    * Transfers interest payment to an investor by the controller.
    * @notice if the param _token provided is zero then it deals with 
    * withdraw as Ethers otherwise it deals with withdraw as _token.
    * @param _investor The address of an investor.
    * @param _token The address of token which is withdrawn.
    * @param _amount The amount of tokens or Wei to withdraw.
    */
    function transferInterestPaymentByController(address payable _investor, address _token, uint _amount) external;

    /**
    * Adjusts payment for an investor by the controller.
    * @notice if the param _token provided is zero then it deals with 
    * withdraw as Ethers otherwise it deals with withdraw as _token.
    * @param _investor The address of an investor.
    * @param _token The address of token which is withdrawn.
    * @param _amount The amount of tokens or Wei to withdraw.
    * @param _data Contains any reason associated with adjustment of interest payment.
    */
    function adjustInterestPaymentforAnInvestor(address _investor, address _token, uint _amount, bytes calldata _data) external;

    /**
    * Withdraw tokens or Ethers by controller.
    * @notice if the param _token provided is zero then it deals with
    * withdraw as Ethers otherwise it deals with withdraw as _token
    * @param _token The address of token which is withdrawn.
    * @param _amount The amount of tokens or Wei to withdraw
    */
    function withdrawByController(address _token, uint _amount) external;

    /**
     * This event is triggered when an address withdraws his part of the interest payment.
     * @param beneficiary The address receiving the interest payment
     * @param token The token with which the interest payment is paid
     * @param amount The amount of interest payment
     */
    event InterestReceived(address beneficiary, address token, uint amount);

    /**
    * This event is fired when a controller withdraws tokens or Ethers.
    * @param investor The address which withdraws tokens or Ethers.
    * @param token The address of token which is withdrawn.
    * @param amount The amount of tokens or Wei to withdraw
    */
    event WithdrawnByController(address investor, address token, uint amount);


    /**
    * This event is fired when a controller sets interest payment for an investor.
    * @param investor The address which withdraws tokens or Ethers.
    * @param token The address of token which is withdrawn.
    * @param amount The amount of tokens or Wei to withdraw
    * @param data It contains any data associated with the interest payment such as dates, exchange rate. 
    */
    event InterestPaymentSet(address investor, address token, uint amount, bytes data);

    /**
    * This event is fired when a controller adjusts interest payment for an investor.
    * @param investor The address for which the interest payment is adjusted in the form of tokens or Ethers.
    * @param token The address of token which is withdrawn.
    * @param amount The amount of tokens or Wei to withdraw
    * @param data It contains any data associated with the interest payment such as dates, exchange rate. 
    */
    event InterestPaymentAdjusted(address investor, address token, uint amount, bytes data);

}

// File: contracts/InterestDistributingToken/iEstate/InterestDistributingToken.sol

 



contract InterestDistributingToken is SecurityToken, IInterestDistributingToken {
    
    // token_rates mapping for storing token and their corresponding rates against our security token
    mapping(address => mapping(address => uint )) public interestPaymentsinTokens;
    
    mapping(address => uint) public interestPaymentsinEther;

    constructor
    (
        address owner, 
        address controllerAddr, 
        address whitelistAddr,
        string memory tokenName, 
        string memory tokenSymbol
    ) 
    public SecurityToken(owner, controllerAddr, whitelistAddr, tokenName, tokenSymbol) {

    }

    /**
    * Withdraws interest payment for the caller in the form of ERC20 tokens or Ethers.
    * @param _token The address of token with which the interest payment is paid.
    */
    function withdrawInterest(address _token) external {

        if(_token == address(0x0)) {
            // make interest payment in Ethers
            makeInterestPaymentinEthers();       
        } else {
            // make interest payment in tokens
            makeInterestPaymentinTokens(_token);
        }      

    }

    /**
    * Makes interest payment in the form Ethers to the investor
    */
    function makeInterestPaymentinEthers() private {
        uint interestPayment = interestPaymentsinEther[msg.sender];
        
        validateInterestPaymentinEthers(interestPayment);

        interestPaymentsinEther[msg.sender] = 0;
            
        msg.sender.transfer(interestPayment);    
        emit InterestReceived(msg.sender, address(0x0), interestPayment);
    }

    /**
    * Makes interest payment in the form tokens to the investor
    * @param _token It is an instance/address of the token contract which is paid as interest payment.
    */
    function makeInterestPaymentinTokens(address _token) private {
        IERC20 interestPaymentToken = IERC20(_token);   
            
        uint interestPayment = interestPaymentsinTokens[msg.sender][_token];
        
        validateInterestPaymentinTokens(interestPayment, interestPaymentToken);
            
        interestPaymentsinTokens[msg.sender][_token] = 0;
        interestPaymentToken.transfer(msg.sender, interestPayment);

        emit InterestReceived(msg.sender, _token, interestPayment);
    }

    /**
    * Validates interest payment of Ethers by making sure the contract has enough Ethers.
    * @param _interestPayment It is the amount of Ethers.
    */
    function validateInterestPaymentinEthers(uint _interestPayment) private view {
        require(_interestPayment > 0, "Interest payment in Ethers has zero balance.");
        require(_interestPayment <= address(this).balance, "The contract does not have enough Ethers.");
    }

    /**
    * Validates interest payment of tokens by making sure the contract has enough of the tokens.
    * @param _interestPayment It is the amount of tokens.
    * @param _interestPaymentToken It is an instance/address of the token contract which is paid as interest payment.
    */
    function validateInterestPaymentinTokens(uint _interestPayment, IERC20 _interestPaymentToken) private view {
        require(_interestPayment > 0, "Interest payment in chosen token has zero balance.");
        require(
            _interestPayment <= _interestPaymentToken.balanceOf(address(this)),
            "The contract does not have token balance."
        );
    }

    /**
    * Sets interest payments for all the token holders.
    * @notice if the param _token provided is zero then it deals payments 
    *as Ethers otherwise it deals payments as _token
    * @param _token The address of token with which the interest payment is paid.
    * @param _investors The list of addresses which accept interest payment in _token
    * @param _payments The list of payments corresponding to each address in _investors
    * @param _data It contains any data associated with the interest payment such as dates, exchange rate. 
    */
    function setInterestPaymentforWithdrawals(address _token, address[] calldata _investors, uint[] calldata _payments, bytes calldata _data)
    external {

        require(canSetInterestPayment(msg.sender), "msg.sender is unauthorized to set interest payments");
        require(_investors.length > 0, "_investors should have atleast one address.");
        require(_payments.length > 0, "_investors should have atleast one address.");
        require(_investors.length == _payments.length, "_investors and _payments are of different lengths.");

        uint i = 0;

        if(_token == address(0x0)) {

            for( i; i < _investors.length; i++) {
                interestPaymentsinEther[_investors[i]] = interestPaymentsinEther[_investors[i]].add(_payments[i]);
                
                emit InterestPaymentSet(_investors[i], _token, _payments[i], _data);
            }

        } else {

            for(i; i < _investors.length; i++) {
                interestPaymentsinTokens[_investors[i]][_token] = interestPaymentsinTokens[_investors[i]][_token]
                .add(_payments[i]);

                emit InterestPaymentSet(_investors[i], _token, _payments[i], _data);
            }
        }
    }

    /**
    * Transfers interest payment to an investor by the controller.
    * @notice if the param _token provided is zero then it deals with 
    * withdraw as Ethers otherwise it deals with withdraw as _token.
    * @param _investor The address of an investor.
    * @param _token The address of token which is withdrawn.
    * @param _amount The amount of tokens or Wei to withdraw.
    */
    function transferInterestPaymentByController(address payable _investor, address _token, uint _amount) external {
        require(
            _whitelistInterface.isMemberOf(msg.sender, SECURITY_LEVEL2, APP_IDENTIFIER),
            "msg.sender does not have authorization of security level - 2"
        );
        
        if(_token == address(0x0)) {
            validateInterestPaymentinEthers(_amount);
            _investor.transfer(_amount);
            emit InterestReceived(_investor, _token, _amount);

        } else {
            IERC20 token = IERC20(_token);
            validateInterestPaymentinTokens(_amount, token);
            token.transfer(_investor, _amount);
        }

        emit InterestReceived(_investor, _token, _amount);
    }

    /**
    * Adjusts payment for an investor by the controller.
    * @notice if the param _token provided is zero then it deals with 
    * withdraw as Ethers otherwise it deals with withdraw as _token.
    * @param _investor The address of an investor.
    * @param _token The address of token which is withdrawn.
    * @param _amount The amount of tokens or Wei to withdraw.
    * @param _data Contains any reason associated with adjustment of interest payment.
    */
    function adjustInterestPaymentforAnInvestor(address _investor, address _token, uint _amount, bytes calldata _data)
    external {
        require(
            _whitelistInterface.isMemberOf(msg.sender, SECURITY_LEVEL2, APP_IDENTIFIER),
            "msg.sender does not have authorization of security level - 2"
        );
        
        if(_token == address(0x0)) {
           interestPaymentsinEther[_investor] = _amount;
        } else {
            interestPaymentsinTokens[_investor][_token] = _amount;
        }

       emit InterestPaymentAdjusted(_investor, _token, _amount, _data);
    }

    /**
    * Withdraws residual tokens or Ethers by controller.
    * @notice if the param _token provided is zero then it deals with 
    * withdraw as Ethers otherwise it deals with withdraw as _token.
    * @param _token The address of token which is withdrawn.
    * @param _amount The amount of tokens or Wei to withdraw.
    */
    function withdrawByController(address _token, uint _amount) external {
        require(
            _whitelistInterface.isMemberOf(msg.sender, SECURITY_LEVEL2, APP_IDENTIFIER),
            "msg.sender does not have authorization of security level - 2"
        );
        
        if(_token == address(0x0)) {
            require(_amount <= address(this).balance, "_amount is greater than the balance of contract");
            msg.sender.transfer(_amount);
        } else {
            IERC20 token = IERC20(_token);
            require(
                _amount <= token.balanceOf(address(this)),
                "The contract's balance of tokens is less than the _amount"
            );
            token.transfer(msg.sender, _amount);
        }

        emit WithdrawnByController(msg.sender, _token, _amount);
    }

    /**
     * @notice Indicates if the address specified is allowed to set interest payments.
     * @param addr Specifies the address.
     * @return returns true if the address is allowed to perform the action requested.
     */
    function canSetInterestPayment(address addr) public view returns(bool) {
        return _whitelistInterface.isMemberOf(addr, SECURITY_LEVEL2, APP_IDENTIFIER);
    }


    
}

// File: contracts/IEsateSecurityToken.sol

 


contract IEstateSecurityToken is InterestDistributingToken {
    constructor
    (
        address owner, 
        address controllerAddr, 
        address whitelistAddr,
        string memory tokenName, 
        string memory tokenSymbol
    ) 
    public InterestDistributingToken(owner, controllerAddr, whitelistAddr, tokenName, tokenSymbol) {

    }

    // fallback function for accepting Ethers
    function() external payable {

    }
}
