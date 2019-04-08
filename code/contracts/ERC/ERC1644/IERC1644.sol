pragma solidity ^0.5.4;

/**
 * @title Defines the interface of ERC-1644 (Controller Token Operation Standard) 
 * as per https://github.com/ethereum/EIPs/issues/1644
 */
interface IERC1644 {

    /**
     * @notice This function allows an authorized address to transfer tokens between any two token holders.
     * The transfer must still respect the balances of the token holders 
     * (so the transfer must be for at most "balanceOf(_from)" tokens) 
     * and potentially also need to respect other transfer restrictions.
     * This function can only be executed by the controller address.
     *
     * @param from The address which you want to send tokens from
     * @param to The address which you want to transfer to
     * @param value The amount of tokens to be transferred
     * @param data The data to validate the transfer.
     * @param operatorData The data attached to the transfer by controller to emit in event. 
     * It is more like a reason string for calling this function (aka force transfer) which provides the 
     * transparency on-chain. 
     */
    function controllerTransfer(
        address from, address to, uint256 value, bytes calldata data, bytes calldata operatorData
        ) external;

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
     * It is more like a reason string for calling this function (aka force transfer) which provides the 
     * transparency on-chain. 
     */
    function controllerRedeem(
        address tokenHolder, uint256 value, bytes calldata data, bytes calldata operatorData
        ) external;

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