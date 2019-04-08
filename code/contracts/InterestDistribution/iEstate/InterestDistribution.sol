pragma solidity ^0.5.4;

import "../../ERC/ERC20/IERC20.sol";
import "../../whitelists/iEstate/DefaultSecurityTokenWhitelist.sol";
import "../IInterestDistribution.sol";
import "../../ownership/OwnableNonTransferable.sol";
import "../../math/SafeMath.sol";


contract InterestDistribution is IInterestDistribution, OwnableNonTransferable {
    
    using SafeMath for uint;

    // The whitelist interface
    DefaultSecurityTokenWhitelist private _whitelistInterface;

    // token_rates mapping for storing token and their corresponding rates against our security token
    mapping(address => mapping(address => uint )) public interestPaymentsinTokens;
    
    mapping(address => uint) public interestPaymentsinEther;

    // The security roles defined in our custom implementation
    bytes32 constant private APP_IDENTIFIER = "iEstate STO Platform";
    bytes32 constant private SECURITY_LEVEL2 = "iEstate STO Platform - Level2";

    constructor(
        address whitelistAddr,
        address owner
    ) public OwnableNonTransferable(owner) {
        _whitelistInterface = DefaultSecurityTokenWhitelist(whitelistAddr);
    }

     //fallback function for accepting Ethers
    function() external payable { // solhint-disable-line no-empty-blocks
        require(msg.data.length == 0, "Invalid call to the contract.");
    }

    /**
    * Withdraws interest payment for the caller in the form of ERC20 tokens or Ethers.
    * @param token The address of token with which the interest payment is paid.
    */
    function withdrawInterest(IERC20 token) external {

        if (address(token) == address(0x0)) {
            // make interest payment in Ethers
            makeInterestPaymentinEthers();       
        } else {
            // make interest payment in tokens
            makeInterestPaymentinTokens(token);
        }      

    }

    /**
    * Sets interest payments for all the token holders.
    * @notice if the param _token provided is zero then it deals payments 
    *as Ethers otherwise it deals payments as _token
    * @param token The address of token with which the interest payment is paid.
    * @param investors The list of addresses which accept interest payment in _token
    * @param payments The list of payments corresponding to each address in _investors
    * @param data It contains any data associated with the interest payment such as dates, exchange rate. 
    */
    function setInterestPaymentforWithdrawals(
        IERC20 token,
        address[] calldata investors,
        uint[] calldata payments,
        bytes calldata data
        ) external {

        require(canSetOrTransferInterestPayment(msg.sender), "msg.sender is unauthorized to set interest payments");
        require(investors.length > 0, "investors should have at least one address.");
        require(payments.length > 0, "investors should have at least one payment.");
        require(investors.length == payments.length, "investors and payments are of different lengths.");

        uint i = 0;

        if (address(token) == address(0x0)) {

            for (i; i < investors.length; i++) {
                interestPaymentsinEther[investors[i]] = interestPaymentsinEther[investors[i]].add(payments[i]);
                
                emit InterestPaymentSet(investors[i], address(token), payments[i], data);
            }

        } else {

            for (i; i < investors.length; i++) {
                interestPaymentsinTokens[investors[i]][address(token)]
                = interestPaymentsinTokens[investors[i]][address(token)]
                .add(payments[i]);

                emit InterestPaymentSet(investors[i], address(token), payments[i], data);
            }
        }
    }

    /**
    * Transfers interest payment to an investor by the controller.
    * @notice if the param _token provided is zero then it deals with 
    * withdraw as Ethers otherwise it deals with withdraw as _token.
    * @param investor The address of an investor.
    * @param paymentToken The address of token which is withdrawn.
    * @param amount The amount of tokens or Wei to withdraw.
    */
    function transferInterestPaymentByOwner(address payable investor, IERC20 paymentToken, uint amount) 
    external onlyOwner {

        if (address(paymentToken) == address(0x0)) {
            validateInterestPaymentinEthers(amount);
            investor.transfer(amount);
        } else {
            validateInterestPaymentinTokens(amount, paymentToken);
            paymentToken.transfer(investor, amount);
        }

        emit InterestReceived(investor, address(paymentToken), amount);
    }

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
    external {
       
        require(canSetOrTransferInterestPayment(msg.sender), "msg.sender is unauthorized to adjust interest payments");

        if (address(token) == address(0x0)) {
            interestPaymentsinEther[investor] = amount;
        } else {
            interestPaymentsinTokens[investor][address(token)] = amount;
        }
        
        emit InterestPaymentAdjusted(investor, address(token), amount, data);
    }

    /**
    * Withdraws residual tokens or Ethers by controller.
    * @notice if the param _token provided is zero then it deals with 
    * withdraw as Ethers otherwise it deals with withdraw as _token.
    * @param paymentToken The address of token which is withdrawn.
    * @param amount The amount of tokens or Wei to withdraw.
    */
    function withdrawByOwner(IERC20 paymentToken, uint amount) external onlyOwner {
        
        if (address(paymentToken) == address(0x0)) {
            require(amount <= address(this).balance, "amount is greater than the balance of contract");
            msg.sender.transfer(amount);
        } else {
            require(
                amount <= paymentToken.balanceOf(address(this)),
                "The contract's balance of tokens is less than the amount"
            );
            paymentToken.transfer(msg.sender, amount);
        }

        emit WithdrawnByOwner(msg.sender, address(paymentToken), amount);
    }

    /**
     * @notice Indicates if the address specified is allowed to set interest payments.
     * @param addr Specifies the address.
     * @return returns true if the address is allowed to perform the action requested.
     */
    function canSetOrTransferInterestPayment(address addr) public view returns(bool) {
        return _whitelistInterface.isMemberOf(addr, SECURITY_LEVEL2, APP_IDENTIFIER);
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
    * @param interestPaymentToken It is an instance/address of the token contract which is paid as interest payment.
    */
    function makeInterestPaymentinTokens(IERC20 interestPaymentToken) private {
            
        uint interestPayment = interestPaymentsinTokens[msg.sender][address(interestPaymentToken)];
        
        validateInterestPaymentinTokens(interestPayment, interestPaymentToken);
            
        interestPaymentsinTokens[msg.sender][address(interestPaymentToken)] = 0;
        interestPaymentToken.transfer(msg.sender, interestPayment);

        emit InterestReceived(msg.sender, address(interestPaymentToken), interestPayment);
    }

    /**
    * Validates interest payment of Ethers by making sure the contract has enough Ethers.
    * @param interestPayment It is the amount of Ethers.
    */
    function validateInterestPaymentinEthers(uint interestPayment) private view {
        require(interestPayment > 0, "Interest payment in Ethers has zero balance.");
        require(interestPayment <= address(this).balance, "The contract does not have enough Ethers.");
    }

    /**
    * Validates interest payment of tokens by making sure the contract has enough of the tokens.
    * @param interestPayment It is the amount of tokens.
    * @param interestPaymentToken It is an instance/address of the token contract which is paid as interest payment.
    */
    function validateInterestPaymentinTokens(uint interestPayment, IERC20 interestPaymentToken) private view {
        require(interestPayment > 0, "Interest payment in chosen token has zero balance.");
        require(
            interestPayment <= interestPaymentToken.balanceOf(address(this)),
            "The contract does not have token balance."
        );
    }

    
}