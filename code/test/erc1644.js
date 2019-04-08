import { catchRevert } from "./helpers/exceptions";
import { takeSnapshot, revertToSnapshot } from "./helpers/time";

const ERC1644Token = artifacts.require("./SecurityToken.sol");
const Whitelist_Contract = artifacts.require(
  "./DefaultSecurityTokenWhitelist.sol"
);
const RBAC = artifacts.require("./PlatformProviderRbac.sol");

const Web3 = require("web3");
const BigNumber = require("bignumber.js");
const web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545")); // Hardcoded development port

contract("ERC1644", accounts => {
  let tokenOwner;
  let controller;
  let tokenHolder1;
  let tokenHolder2;
  let tokenHolder3;
  let tokenHolder4;
  let securityOperator;
  let address_with_security_level_2;
  let address_with_security_level_1;
  let erc1644Token;
  let whitelist;
  let erc1644TokenZero;
  let rbac;

  const empty_controller = "0x0000000000000000000000000000000000000000";

  before(async () => {
    tokenHolder1 = accounts[3];
    tokenHolder2 = accounts[2];
    tokenHolder3 = accounts[6];
    tokenHolder4 = accounts[7];
    controller = accounts[5];
    tokenOwner = accounts[0];
    securityOperator = accounts[1];
    address_with_security_level_2 = accounts[4];
    address_with_security_level_1 = accounts[8];

    erc1644Token = await ERC1644Token.deployed();
    whitelist = await Whitelist_Contract.deployed();
    rbac = await RBAC.deployed();
  });

  describe(`Test cases for the ERC1644 contract\n`, async () => {
    describe("Test cases for isControllable()\n", async () => {
      it("\t Should return true when controller is non-zero address\n", async () => {
        assert.isTrue(await erc1644Token.isControllable.call());
      });
    });

    describe("Test cases for the controllerTransfer()\n", async () => {
      it("\t Should revert during controllerTransfer() because _from doesn't have sufficent balance\n", async () => {
        await catchRevert(
          erc1644Token.controllerTransfer(
            tokenHolder1,
            tokenHolder2,
            web3.utils.toWei("600"),
            web3.utils.fromAscii("0x0"),
            web3.utils.fromAscii("Stolen tokens"),
            { from: controller }
          )
        );
      });

      it("\t Should revert during controllerTransfer() because _to address is 0x\n", async () => {
        await catchRevert(
          erc1644Token.controllerTransfer(
            tokenHolder1,
            "0x0000000000000000000000000000000000000000",
            web3.utils.toWei("100"),
            web3.utils.fromAscii("0x0"),
            web3.utils.fromAscii("Stolen tokens"),
            { from: controller }
          )
        );
      });

      it("\t Should sucessfully controllerTransfer() and verify the `ControllerTransfer` event params value\n", async () => {
        await rbac.addOperator(
          securityOperator,
          web3.utils.fromAscii("iEstate STO Platform"),
          { from: tokenOwner }
        );
        await rbac.addToLevel1(address_with_security_level_1, { from: securityOperator });
        await rbac.addToLevel2(address_with_security_level_2, { from: securityOperator });

        await whitelist.addVerified(
          tokenHolder3,
          web3.utils.fromAscii("John Doe from Alaska"),
          web3.utils.fromAscii("iEstate STO Platform"),
          { from: address_with_security_level_1 }
        );
        await whitelist.addVerified(
          tokenHolder4,
          web3.utils.fromAscii("John Doe from Alaska"),
          web3.utils.fromAscii("iEstate STO Platform"),
          { from: address_with_security_level_1 }
        );

        await erc1644Token.issueByPartition(
          web3.utils.fromAscii("default"),
          tokenHolder3,
          web3.utils.toWei("10"),
          web3.utils.fromAscii("0x0"),
          { from: address_with_security_level_2 }
        );
        await erc1644Token.issueByPartition(
          web3.utils.fromAscii("default"),
          tokenHolder4,
          web3.utils.toWei("10"),
          web3.utils.fromAscii("0x0"),
          { from: address_with_security_level_2 }
        );

        let tx = await erc1644Token.controllerTransfer(
          tokenHolder3,
          tokenHolder4,
          web3.utils.toWei("1"),
          web3.utils.fromAscii("0x0"),
          web3.utils.fromAscii("Stolen tokens"),
          { from: controller }
        );
        // Verify the transfer event values
        assert.equal(
          (await erc1644Token.balanceOf.call(tokenHolder3)) / 10 ** 18,
          9
        );
        assert.equal(
          (await erc1644Token.balanceOf.call(tokenHolder4)) / 10 ** 18,
          11
        );
      });

      it("\t Should revert after finalization of the controller feature\n", async () => {
        await erc1644Token.finalizeControllable({ from: tokenOwner });
        assert.isFalse(await erc1644Token.isControllable.call());
        await catchRevert(
          erc1644Token.controllerTransfer(
            tokenHolder1,
            tokenHolder2,
            web3.utils.toWei("100"),
            web3.utils.fromAscii("0x0"),
            web3.utils.fromAscii("Stolen tokens"),
            { from: controller }
          )
        );
      });
    });

      describe("Test cases for the controllerRedeem()\n", async() => {

        it("\t Should revert during controllerRedeem() because msg.sender is not authorised\n", async() => {
            await catchRevert(
                erc1644Token.controllerRedeem(tokenHolder2, web3.utils.toWei("100"),  web3.utils.fromAscii("0x0"), web3.utils.fromAscii("Incorrect receiver of tokens"), {from: tokenOwner})
            );
        });

        it("\t Should revert during controllerRedeem() when controller is zero address or `isControllable()` returns false\n", async() => {
            await catchRevert(
              erc1644Token.controllerRedeem(tokenHolder2, web3.utils.toWei("200"),  web3.utils.fromAscii("0x0"), web3.utils.fromAscii("Incorrect receiver of tokens"), {from: controller})
            );
        })

        it("\t Should revert during controllerRedeem() because tokenHolder doesn't have sufficent balance\n", async() => {
            await catchRevert(
              erc1644Token.controllerRedeem(tokenHolder2, web3.utils.toWei("400"),  web3.utils.fromAscii("0x0"), web3.utils.fromAscii("Incorrect receiver of tokens"), {from: controller})
            );
        });

        it("\t Should revert during controllerRedeem() because tokenHolder2 address is 0x\n", async() => {
            await catchRevert(
              erc1644Token.controllerRedeem("0x0000000000000000000000000000000000000000", web3.utils.toWei("200"),  web3.utils.fromAscii("0x0"), web3.utils.fromAscii("Incorrect receiver of tokens"), {from: controller})
            );
        });

      });
  });
});
