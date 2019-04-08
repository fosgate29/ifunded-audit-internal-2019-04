const RBAC = artifacts.require("./PlatformProviderRbac.sol");
const Whitelist = artifacts.require("./DefaultSecurityTokenWhitelist.sol");
const SecurityToken = artifacts.require("./SecurityToken.sol");
const InterestDistribution = artifacts.require("./InterestDistribution.sol");

module.exports = (deployer, network, accounts) => {
  const owner = accounts[0];
  const name = "Test Security Token";
  const symbol = "TST";
  const controller = accounts[5];

  deployer.deploy(RBAC, owner, { from: accounts[1] }).then(() => {
    return deployer
      .deploy(Whitelist, owner, RBAC.address, { from: accounts[2] })
      .then(() => {
        return deployer.deploy(
          SecurityToken,
          owner,
          controller,
          Whitelist.address,
          name,
          symbol,
          { from: accounts[0] }
        ).then(() => {
          return deployer.deploy(InterestDistribution, Whitelist.address, owner, { from: accounts[3] });
        })
      });
  });
};
