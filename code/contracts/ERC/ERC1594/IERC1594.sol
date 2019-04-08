pragma solidity ^0.5.4;

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
    
    function canTransferFrom(address from, address to, uint256 value, bytes calldata data) 
    external view returns (bool, byte, bytes32);

    // Issuance / Redemption Events
    event Issued(address indexed operator, address indexed to, uint256 value, bytes data);
    event Redeemed(address indexed operator, address indexed from, uint256 value, bytes data);

}