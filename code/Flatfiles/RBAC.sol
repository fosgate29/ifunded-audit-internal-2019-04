
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
