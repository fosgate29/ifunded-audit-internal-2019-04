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