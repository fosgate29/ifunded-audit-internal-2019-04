const TestPaymentToken = artifacts.require("./TestPaymentToken.sol");


module.exports = (deployer, networks, accounts) => {
    deployer.deploy(TestPaymentToken, { from: accounts[0] });
}