pragma solidity ^0.5.4;

import "./../RoleBasedAccessControl.sol";

/**
 * @title PlatformProviderRoleAccess
 * @dev This contract implements RBAC on the iEstate Platform.
 */
contract PlatformProviderRbac is RoleBasedAccessControl {

    // The security roles defined in our custom implementation
    bytes32 constant private APP_IDENTIFIER = "iEstate STO Platform";
    bytes32 constant private SECURITY_LEVEL1 = "iEstate STO Platform - Level1";
    bytes32 constant private SECURITY_LEVEL2 = "iEstate STO Platform - Level2";

    /**
     * Constructor
     * @param owner The owner of the smart contract
     */
    constructor(address owner) public RoleBasedAccessControl(owner) { // solhint-disable-line no-empty-blocks
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