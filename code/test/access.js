import { catchRevert, catchInvalidOpcode } from "./helpers/exceptions";

const RBAC = artifacts.require("./PlatformProviderRbac.sol");

const Web3 = require("web3");
const BigNumber = require("bignumber.js");
const web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545")); // Hardcoded development port

contract("Test Role based access (RBAC) functions", accounts => {
  let tokenOwner;
  let nonOwner;
  let operator;
  let nonOperator;
  let rbac;

  const asset = web3.utils.fromAscii("iEstate STO Platform");

  const empty_data = "0x0000000000000000000000000000000000000000";
  const zero_address = "0x0000000000000000000000000000000000000000";

  before(async () => {
    operator = accounts[5];

    tokenOwner = accounts[0];
    nonOwner = accounts[1];
    nonOperator = accounts[1];
    rbac = await RBAC.deployed();
  });

  describe(`Test cases for Role based access`, async () => {

    it("\t Should not add operator using non-owner address\n", async () => {
      await catchRevert(rbac.addOperator(
        operator,
        asset,
        { from: nonOwner }
      ));
    });

    it("\t Should successfully add operator using owner address\n", async () => {
      await rbac.addOperator(
        operator,
        asset,
        { from: tokenOwner }
      );

      const result = await rbac.isSecurityOperator(
        operator,
        asset
      );

      assert.equal(result, true);
    });

    it("\t Should not remove operator using non-owner address \t", async () => {
      await catchRevert(rbac.removeOperator(
        operator,
        asset,
        { from: nonOwner }
      ));
    });

    it("\t Should successfully remove operator using owner address \t", async () => {
      await rbac.removeOperator(
        operator,
        asset,
        { from: tokenOwner }
      );

      const result = await rbac.isSecurityOperator(
        operator,
        asset
      );

      assert.equal(result, false);
    });

    it("\t Test app identifier \t", async () => {
      const app_identifier = await rbac.getAppIdentifier();
      assert.equal(
        app_identifier,
        asset
      );
    });

    it("\t Should not add address to Security level 1 using non-operator address\t", async () => {
      await rbac.addOperator(
        operator,
        asset,
        { from: tokenOwner }
      );
      await catchRevert( rbac.addToLevel1(accounts[6], { from: nonOperator }));

    });

    it("\t Should add address to Security level 1 using operator address\t", async () => {
      await rbac.addToLevel1(accounts[6], { from: operator });

      const exists = await rbac.isLevel1(accounts[6]);
      assert.equal(exists, true);
    });

    it("\t Should not add address to Security level 2 using non-operator address\t", async () => {
      await catchRevert( rbac.addToLevel2(accounts[7], { from: nonOperator }));
    });

    it("\t Should add address to Security level 2 using operator address\t", async () => {
      await rbac.addToLevel2(accounts[7], { from: operator });
      const exists = await rbac.isLevel2(accounts[7]);
      assert.equal(exists, true);
    });

    it("\t Should not remove address from security level 1 using non-operator address \t", async () => {
      await catchRevert(
        rbac.removeFromLevel1(accounts[6], { from: nonOperator })
      );
    });

    it("\t Should remove address from security level 1 using operator \t", async () => {
      await rbac.removeFromLevel1(accounts[6], { from: operator })
      const exists = await rbac.isLevel1(accounts[6]);
      assert.equal(exists, false);
    })

    it("\t Should not remove address from security level 2 using non-operator address\t", async () => {
      await catchRevert( rbac.removeFromLevel2(accounts[7], { from: nonOperator }));
    }) 

    it("\t Should remove address from security level 2 using operator\t", async () => {
      await rbac.removeFromLevel2(accounts[7], { from: operator })
      const exists = await rbac.isLevel2(accounts[7]);
      assert.equal(exists, false);
    })

  });
});
