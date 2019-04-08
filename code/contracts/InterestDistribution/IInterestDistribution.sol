pragma solidity ^0.5.4;

import "../ERC/ERC20/IERC20.sol";

interface IInterestDistribution {

    /**
    * Withdraws interest payment for the caller.
    * @param token The address of token with which the interest payment is paid.
    */
    function withdrawInterest(IERC20 token) external;
    
    /**
    * Sets interest payments for all the token holders.
    * @notice if the param token provided is zero then it deals 
    * payments as Ethers otherwise it deals payments as token
    * @param token The address of token with which the interest payment is paid.
    * @param investors The list of addresses which accept interest payment in token
    * @param payments The list of payments corresponding to each address in _addresses
    * @param data It contains any data associated with the interest payment such as dates, exchange rate. 
    */
    function setInterestPaymentforWithdrawals(
        IERC20 token, 
        address[] calldata investors, 
        uint[] calldata payments, 
        bytes calldata data
        ) external;

    /**
    * Transfers interest payment to an investor by the controller.
    * @notice if the param _token provided is zero then it deals with 
    * withdraw as Ethers otherwise it deals with withdraw as token.
    * @param investor The address of an investor.
    * @param token The address of token which is withdrawn.
    * @param amount The amount of tokens or Wei to withdraw.
    */
    function transferInterestPaymentByOwner(address payable investor, IERC20 token, uint amount) external;

    /**
    * Adjusts payment for an investor by the controller.
    * @notice if the param _token provided is zero then it deals with 
    * withdraw as Ethers otherwise it deals with withdraw as _token.
    * @param investor The address of an investor.
    * @param token The address of token which is withdrawn.
    * @param amount The amount of tokens or Wei to withdraw.
    * @param data Contains any reason associated with adjustment of interest payment.
    */
    function adjustInterestPaymentforAnInvestor(address investor, IERC20 token, uint amount, bytes calldata data)
    external;

    /**
    * Withdraw tokens or Ethers by controller.
    * @notice if the param token provided is zero then it deals with
    * withdraw as Ethers otherwise it deals with withdraw as token
    * @param token The address of token which is withdrawn.
    * @param amount The amount of tokens or Wei to withdraw
    */
    function withdrawByOwner(IERC20 token, uint amount) external;

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
    event WithdrawnByOwner(address investor, address token, uint amount);


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