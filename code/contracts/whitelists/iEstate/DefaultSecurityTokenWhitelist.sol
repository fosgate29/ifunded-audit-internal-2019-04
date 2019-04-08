pragma solidity ^0.5.4;

import "./../../access/iEstate/PlatformProviderRbac.sol";
import "./../FungibleWhitelist.sol";

/**
 * @title DefaultSecurityTokenWhitelist
 * @dev This contract allows to manage whitelists on the iEstate Platform.
 */
contract DefaultSecurityTokenWhitelist is FungibleWhitelist {
    
    // The contract responsible for handling role-based access permissions on a given platform.
    PlatformProviderRbac private _rbac;

    /**
     * Constructor
     * @param owner The owner of the smart contract
     * @param rbac The address of the smart contract that implements RBAC.
     */
    constructor(address owner, PlatformProviderRbac rbac) public FungibleWhitelist(owner) {
        _rbac = rbac;
    }

    /**
     * Indicates if the operator specified is allowed to whitelist addresses.
     * Only the owner of the contract is allowed to add/remove operators.
     * @param addr The address of the operator
     * @return returns true if the operator specified is allowed to whitelist other addresses.
     */
    function isWhitelistOperator(address addr, bytes32) external view returns (bool) {
        return _rbac.isLevel1(addr);
    }

    /**
     * Indicates whether a given address belongs to the role specified.
     * @param addr Specifies the address.
     * @param role Specifies the role.
     * @param asset The asset the operator is allowed to manage.
     */
    function isMemberOf(address addr, bytes32 role, bytes32 asset) public view returns (bool) {
        return _rbac.isMemberOf(addr, role, asset);
    }
}
