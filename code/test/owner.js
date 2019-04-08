const Owner = artifacts.require("./SecurityToken.sol");

const Web3 = require("web3");
const web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545")); // Hardcoded development port

contract("ERC1644", accounts => {
  let tokenOwner;
  let ownerContract;

  const empty_controller = "0x0000000000000000000000000000000000000000";

  before(async () => {
    tokenOwner = accounts[0];
    ownerContract = await Owner.deployed();
  });

  describe(`Test cases for the Owner contract\n`, async () => {
    it("\t Should get the owner \t", async () => {
      const owner = await ownerContract.owner();
      assert.equal(owner, tokenOwner);
    });

    it("\t Test isOwner \t", async () => {
      const owner = await ownerContract.isOwner(tokenOwner);
      assert.equal(owner, true);
    });
  });
});
