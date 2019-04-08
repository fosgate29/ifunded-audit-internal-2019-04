const TokenVoting = artifacts.require("./TokenVoting.sol");


module.exports = (deployer, networks, accounts) => {
    deployer.deploy(TokenVoting, { from: accounts[0] });
}