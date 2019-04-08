pragma solidity ^0.5.4;

interface IERC1410 {

    // Token Transfers
    function transferByPartition(bytes32 partition, address to, uint256 value, bytes calldata data) 
    external returns (bytes32);

    function operatorTransferByPartition(
        bytes32 partition, address from, address to, uint256 value, bytes calldata data, bytes calldata operatorData
        ) external returns (bytes32);

    // Operator Management
    function authorizeOperator(address operator) external;
    function revokeOperator(address operator) external;
    function authorizeOperatorByPartition(bytes32 partition, address operator) external;
    function revokeOperatorByPartition(bytes32 partition, address operator) external;

    // Issuance / Redemption
    function issueByPartition(bytes32 partition, address tokenHolder, uint256 value, bytes calldata data) external;
    function redeemByPartition(bytes32 partition, uint256 value, bytes calldata data) external;

    function operatorRedeemByPartition(
        bytes32 partition, address tokenHolder, uint256 value, bytes calldata data, bytes calldata operatorData
        ) external;

    // Token Information
    function balanceOf(address addr) external view returns (uint256);
    function balanceOfByPartition(bytes32 partition, address addr) external view returns (uint256);
    function partitionsOf(address addr) external view returns (bytes32[] memory);
    function totalSupply() external view returns (uint256);

    // Operator Information
    function isOperator(address operator, address tokenHolder) external view returns (bool);

    function isOperatorForPartition(bytes32 partition, address operator, address tokenHolder) 
    external view returns (bool);

    function canTransferByPartition(
        address from, address to, bytes32 partition, uint256 value, bytes calldata data
        ) external view returns (byte, bytes32, bytes32);    

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

    event AuthorizedOperatorByPartition(
        bytes32 indexed partition, address indexed operator, address indexed tokenHolder
        );

    event RevokedOperatorByPartition(bytes32 indexed partition, address indexed operator, address indexed tokenHolder);

    // Issuance / Redemption Events
    event IssuedByPartition(bytes32 indexed partition, address indexed to, uint256 value, bytes data);

    event RedeemedByPartition(
        bytes32 indexed partition, 
        address indexed operator, 
        address indexed from, 
        uint256 value, 
        bytes data, 
        bytes operatorData
        );

}