import { catchRevert, catchInvalidOpcode } from "./helpers/exceptions";

const Whitelist = artifacts.require("./DefaultSecurityTokenWhitelist.sol");
const RBAC = artifacts.require("./PlatformProviderRbac.sol");

const Web3 = require("web3");
const BigNumber = require("bignumber.js");
const web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545")); // Hardcoded development port

contract("Start Test", accounts => {
  let tokenOwner;
  let operator_whitelist;
  let nonWhitelist;
  let tokenHolder1;
  let whitelist;
  let securityOperator;
  let rbac;
  let asset;
  let security_level_1;
  const partition1 = "default";

  const empty_data = "0x0000000000000000000000000000000000000000";
  const zero_address = "0x0000000000000000000000000000000000000000";

  before(async () => {
    tokenHolder1 = accounts[3];
    securityOperator = accounts[2];
    operator_whitelist = accounts[4];
    nonWhitelist = accounts[6];
    tokenOwner = accounts[0];
    asset = web3.utils.fromAscii("iEstate STO Platform");
    security_level_1 = web3.utils.fromAscii("iEstate STO Platform - Level1");

    whitelist = await Whitelist.deployed();
    rbac = await RBAC.deployed();
  });

  describe(`Test whitelisiting functionality`, async () => {

    it("\t An unauthorized address should not be a whitelist operator \t", async () => {
      const exists = await whitelist.isWhitelistOperator(nonWhitelist, asset);
      assert.equal(exists, false);
    })

    it("\t An authorized address should be a whitelist operator \t", async () => {
      await rbac.addOperator(securityOperator, asset, { from: tokenOwner });
      await rbac.addToLevel1(operator_whitelist, { from: securityOperator });
      const exists = await whitelist.isWhitelistOperator(operator_whitelist, asset);
      assert.equal(exists, true);

      
    });

    it("\t Address has a role against an asset \t", async () => {
      const exists = await whitelist.isMemberOf(
        operator_whitelist,
        security_level_1,
        asset
      );
      assert.equal(exists, true);
    });

    it("\t Should not whitelist an address using nonWhitelist address \n", async () => {
      await catchRevert( whitelist.addVerified(
        tokenHolder1,
        web3.utils.fromAscii("John Doe from Alaska"),
        asset,
        { from: nonWhitelist }
      ));
    });

    it("\t Should whitelist an address using whitelist operator \n", async () => {
      await whitelist.addVerified(
        tokenHolder1,
        web3.utils.fromAscii("John Doe from Alaska"),
        asset,
        { from: operator_whitelist }
      );
      const exists = await whitelist.isWhitelisted(tokenHolder1, asset);

      assert.equal(exists, true);
    });

    it("\t Shoud not whitelist an already whitelisted address\n", async () => {
      await catchRevert(
        whitelist.addVerified(
          tokenHolder1,
          web3.utils.fromAscii("John Doe from Alaska"),
          asset,
          { from: operator_whitelist }
        )
      );
    });

    it("\t Shoult not remove whitelisted address using non-operator address \t", async () => {
      await catchRevert( whitelist.removeVerified(tokenHolder1, asset, { from: nonWhitelist }));

    });

    it("\t Should remove whitelisted address using whitelist_operator\t", async () => {
      await whitelist.removeVerified(tokenHolder1, asset, { from: operator_whitelist });
      const exists = await whitelist.isWhitelisted(tokenHolder1, asset);

      assert.equal(exists, false);
    });

    it("\t Should verify hash for address \t", async () => {
      await whitelist.addVerified(
        tokenHolder1,
        web3.utils.fromAscii("John Doe from Alaska"),
        asset,
        { from: operator_whitelist }
      );

      const exists = await whitelist.hasHash(tokenHolder1, web3.utils.fromAscii("John Doe from Alaska"), asset);
      assert.equal(exists, true);

    });

    it("\t Should update a hash for address \t", async () => {
        await whitelist.updateVerified(tokenHolder1, web3.utils.fromAscii("Jane Doe from Paris"), asset, { from: operator_whitelist });
        const exists = await whitelist.hasHash(tokenHolder1, web3.utils.fromAscii("Jane Doe from Paris"), asset);
        assert.equal(exists, true);
    })

    it("\t Should successfull do bulk whitelisting", async () => {
      const addresses = [
        "0x5dc362449a62dbcfa63a5ff0DaeFa95C745c9C6C",
        "0x293fB30E203670a30eB2FeEE61821F4c4a92CF07",
        "0x2026ecb1F511B41494f4aCC9AC623888Ce58cEdc",
        "0x6fa4D991dd17BBC8efB8f1eCBEdE4aC2663658F8",
        "0xA72CBCcd54d90fd227114c1022c4083EC473EaD0",
        "0xe97c54B4e9987dFd6F3985385B017c6d5f9F49d7",
        "0xd5a7Ced634eB0f643DB7EA18c4753539CE0d95aa",
        "0x698184A8e1c95d805209bc2CBaBa9FB4fa00b46c",
        "0x9047300A0BBdD0b60ec1d48c23956d63831FdE29",
        "0x9B5E3BFa1543447c8774A1432cCec9fF9c320540"
      ];

      const contacts = [
        "John from Alaska",
        "John from Georgia",
        "John from Nevada",
        "John from New York",
        "John from California",
        "John from Washington",
        "John from Texas",
        "John from Albuquerque",
        "John from Toronto",
        "John from Lahore"
      ];

      const hashes = contacts.map(contact => {
        return web3.utils.sha3(contact);
      });

      await whitelist.addVerifiedAsBulk(addresses, hashes, asset, { from: operator_whitelist });

      for (let i = 0; i < addresses.length; i++) {
        const result = await whitelist.hasHash(
          addresses[i],
          web3.utils.sha3(contacts[i]),
          asset
        );
        assert.equal(result, true);
      }
    });
  });
});
