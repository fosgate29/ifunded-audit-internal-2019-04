pragma solidity ^0.5.4;

import "./../ownership/OwnableNonTransferable.sol";

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
    constructor(address owner) internal OwnableNonTransferable(owner) { // solhint-disable-line no-empty-blocks
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