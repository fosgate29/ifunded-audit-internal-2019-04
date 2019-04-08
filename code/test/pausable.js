import { catchRevert, catchInvalidOpcode } from "./helpers/exceptions";

const SecurityToken = artifacts.require("./SecurityToken.sol");
const Whitelist_Contract = artifacts.require(
  "./DefaultSecurityTokenWhitelist.sol"
);
const RBAC = artifacts.require("./PlatformProviderRbac.sol");

const Web3 = require("web3");
const BigNumber = require("bignumber.js");
const web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545")); // Hardcoded development port

contract("Test token pausing functionality", accounts => {
  let tokenOwner;
  let operator;
  let address_with_security_level_2;
  let address_with_security_level_1;
  let unauthorized_address;
  let tokenHolder1;
  let tokenHolder2;
  let whitelist;
  let securityToken;
  const partition1 = web3.utils.fromAscii("default");
  let asset = web3.utils.fromAscii("iEstate STO Platform");
  let rbac;

  const empty_data = "0x0000000000000000000000000000000000000000";
  const zero_address = "0x0000000000000000000000000000000000000000";

  before(async () => {
    tokenHolder1 = accounts[3];
    tokenHolder2 = accounts[2];
    operator = accounts[5];
    address_with_security_level_2 = accounts[6];
    address_with_security_level_1 = accounts[8];
    unauthorized_address = accounts[7];
    tokenOwner = accounts[0];

    whitelist = await Whitelist_Contract.deployed();
    securityToken = await SecurityToken.deployed();
    rbac = await RBAC.deployed();
  });

  describe(`Test cases for the pausing/unpausing token contract`, async () => {

    it("\t An unauthorized address should not be able to pause the token \t", async () => {
      const canPause = await securityToken.canPause(unauthorized_address);
      assert.equal(canPause, false);
    });

    it("\t An authorized address should be able to pause the token \t", async () => {
      await rbac.addOperator(
        operator,
        asset,
        { from: tokenOwner }
      );
      await rbac.addToLevel2(address_with_security_level_2, { from: operator });
      const canPause = await securityToken.canPause(address_with_security_level_2);
      assert.equal(canPause, true);
    });

    it("\t An unauthorized address should not be able to unpause Token \t", async () => {
      await catchRevert( securityToken.unPause({ from: unauthorized_address }));
    })

    it("\t An authorized address should be able to unpause Token \t", async () => {
      let isPaused = await securityToken.isPaused();
      assert.equal(isPaused, false);

      await securityToken.pause({ from: address_with_security_level_2 });
      
      isPaused = await securityToken.isPaused();
      assert.equal(isPaused, true);

      await securityToken.unPause({ from: address_with_security_level_2 });
      
      isPaused = await securityToken.isPaused();
      assert.equal(isPaused, false);
    })
    
    it("\t Should successfully transfer tokens when token unpaused\n", async () => {
      await rbac.addToLevel1(address_with_security_level_1, { from: operator });
      await whitelist.addVerified(
        tokenHolder1,
        web3.utils.fromAscii("John Doe from Alaska"),
        asset,
        { from: address_with_security_level_1 }
      );
      await securityToken.issueByPartition(
        partition1,
        tokenHolder1,
        web3.utils.toWei("10"),
        web3.utils.fromAscii("0x0"),
        { from: address_with_security_level_2 }
      );

      await whitelist.addVerified(
        tokenHolder2,
        web3.utils.fromAscii("John Doe from Canada"),
        asset,
        { from: address_with_security_level_1 }
      );
      await securityToken.issueByPartition(
        partition1,
        tokenHolder2,
        web3.utils.toWei("10"),
        web3.utils.fromAscii("0x0"),
        { from: address_with_security_level_2 }
      );

      await securityToken.transferByPartition(
        partition1,
        tokenHolder1,
        web3.utils.toWei("1"),
        web3.utils.fromAscii(""),
        { from: tokenHolder2 }
      );
    });

    it("\t Should not transfer tokens when token is paused \n", async () => {
      await securityToken.pause({ from: address_with_security_level_2 });

      await catchRevert(
        securityToken.transferByPartition(
          partition1,
          tokenHolder1,
          web3.utils.toWei("1"),
          web3.utils.fromAscii(""),
          { from: tokenHolder2 }
        )
      );
    });
  });
});
