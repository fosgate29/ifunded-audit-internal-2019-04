import { catchRevert, catchInvalidOpcode } from "./helpers/exceptions";
import { AssertionError } from "assert";

const Whitelist = artifacts.require("./DefaultSecurityTokenWhitelist.sol");
const RBAC = artifacts.require("./PlatformProviderRbac.sol");
const SecurityToken = artifacts.require("./SecurityToken.sol");
const TestPaymentToken = artifacts.require("./TestPaymentToken.sol");
const InterestDistribution = artifacts.require("./InterestDistribution.sol");

const Web3 = require("web3");
const BigNumber = require("bignumber.js");
const web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545")); // Hardcoded development port

contract("Start Test", accounts => {
  let tokenOwner;
  let operator_whitelist;
  let address_security_level_2;
  let nonWhitelist;
  let tokenHolder1;
  let tokenHolder2;
  let tokenHolder3;
  let whitelist;
  let rbac;
  let asset;
  let securityToken;
  let testToken;
  let interestDistribution;
  let security_level_1;
  const partition1 = web3.utils.fromAscii("default");

  const empty_data = "0x0000000000000000000000000000000000000000";
  const zero_address = "0x0000000000000000000000000000000000000000";

  before(async () => {
    tokenHolder1 = accounts[8];
    tokenHolder2 = accounts[9];
    tokenHolder3 = accounts[3];
    operator_whitelist = accounts[5];
    address_security_level_2 = accounts[4];
    nonWhitelist = accounts[6];
    tokenOwner = accounts[0];
    asset = web3.utils.fromAscii("iEstate STO Platform");
    security_level_1 = web3.utils.fromAscii("iEstate STO Platform - Level1");

    whitelist = await Whitelist.deployed();
    rbac = await RBAC.deployed();
    securityToken = await SecurityToken.deployed();
    testToken = await TestPaymentToken.deployed();
    interestDistribution = await InterestDistribution.deployed();
  });

  describe(`Test interest payment functionality`, async () => {
    // ======================================= Interest Payments in test tokens =======================================
    it("Should set interest payments in test tokens ", async () => {

      const token = testToken.address;

      const addresses = [
        tokenHolder1,
        tokenHolder2
      ]

      const payments = [
        web3.utils.toWei("1000"),
        web3.utils.toWei("2000")
      ]

      await rbac.addOperator(
        tokenOwner,
        web3.utils.fromAscii("iEstate STO Platform"),
        { from: tokenOwner }
      );

      await rbac.addToLevel2(address_security_level_2, { from: tokenOwner });

      await interestDistribution.setInterestPaymentforWithdrawals(token, addresses, payments, "0x0", {
        from: address_security_level_2
      });

      const balance_tokenHolder1 = await interestDistribution.interestPaymentsinTokens(tokenHolder1, token);
      assert.equal(BigNumber(balance_tokenHolder1).toNumber(), payments[0]);

      const balance_tokenHolder2 = await interestDistribution.interestPaymentsinTokens(tokenHolder2, token);
      assert.equal(BigNumber(balance_tokenHolder2).toNumber(), payments[1]);
    })

    it("Should transfer test tokens to the interest distribution contract", async () => {
      const interestDistributionAddress = interestDistribution.address;
      const amount = web3.utils.toWei("10000");

      await testToken.transfer(interestDistributionAddress, amount, { from: tokenOwner });
      const balance = await testToken.balanceOf(interestDistributionAddress);
      assert.equal(BigNumber(balance).toNumber(), amount);
    });

    it("Should do successful withdrawal of test token by tokenHolder1", async () => {
      const testTokenAddress = testToken.address;

      await interestDistribution.withdrawInterest(testTokenAddress, { from: tokenHolder1 });
      const testTokenBalanceByTokenHolder1 = await testToken.balanceOf(tokenHolder1);

      assert.equal(BigNumber(testTokenBalanceByTokenHolder1).toNumber(), web3.utils.toWei("1000"));
    })

    it("Should do successful withdrawal of test token by tokenHolder2", async () => {
      const testTokenAddress = testToken.address;

      await interestDistribution.withdrawInterest(testTokenAddress, { from: tokenHolder2 });
      const testTokenBalanceByTokenHolder2 = await testToken.balanceOf(tokenHolder2);

      assert.equal(BigNumber(testTokenBalanceByTokenHolder2).toNumber(), web3.utils.toWei("2000"));
    })

    it("Should do unsuccessful withdrawal of test token by tokenHolder3", async () => {
      const testTokenAddress = testToken.address;

      await catchRevert(interestDistribution.withdrawInterest(testTokenAddress, { from: tokenHolder3 }));

    })

    // ======================================= END =======================================

    // ======================================= Interest Payments in Ethers =======================================
    it("Should set interest payments in Ethers ", async () => {

      const token = zero_address; // when the payments are in Ether we set token to zero_address

      const addresses = [
        tokenHolder1,
        tokenHolder2
      ]

      const payments = [
        web3.utils.toWei("1"),
        web3.utils.toWei("2")
      ]

      await interestDistribution.setInterestPaymentforWithdrawals(token, addresses, payments, "0x0", {
        from: address_security_level_2
      });

      const balance_tokenHolder1 = await interestDistribution.interestPaymentsinEther(tokenHolder1);
      assert.equal(BigNumber(balance_tokenHolder1).toNumber(), payments[0]);

      const balance_tokenHolder2 = await interestDistribution.interestPaymentsinEther(tokenHolder2);
      assert.equal(BigNumber(balance_tokenHolder2).toNumber(), payments[1]);
    })

    it("Should transfer Ethers to the interest distribution contract", async () => {
      const interestDistributionAddress = interestDistribution.address;
      const amount = web3.utils.toWei("10");

      await web3.eth.sendTransaction({ to: interestDistributionAddress, value: amount, from: tokenOwner });

      const interestDistributionEtherBalance = await web3.eth.getBalance(interestDistributionAddress);
      assert.equal(BigNumber(interestDistributionEtherBalance).toNumber(), amount);

    });

    it("Should do successful withdrawal of Ethers by tokenHolder1", async () => {
      const token = zero_address;


      const tokenHolder1EtherBalance_before = await web3.eth.getBalance(tokenHolder1);

      await interestDistribution.withdrawInterest(token, { from: tokenHolder1 });
      const tokenHolder1EtherBalance_after = await web3.eth.getBalance(tokenHolder1);

      assert.equal(BigNumber(tokenHolder1EtherBalance_after).toString().substring(0, 1), BigNumber(tokenHolder1EtherBalance_before).plus(BigNumber(web3.utils.toWei("1"))).toString().substring(0, 1));
    })

    it("Should do successful withdrawal of Ethers by tokenHolder2", async () => {
      const token = zero_address;

      const tokenHolder2EtherBalance_before = await web3.eth.getBalance(tokenHolder2);

      await interestDistribution.withdrawInterest(token, { from: tokenHolder2 });
      const tokenHolder2EtherBalance_after = await web3.eth.getBalance(tokenHolder2);
      assert.equal(BigNumber(tokenHolder2EtherBalance_after).toString().substring(0, 1), BigNumber(tokenHolder2EtherBalance_before).plus(BigNumber(web3.utils.toWei("2"))).toString().substring(0, 1));

    })

    it("Should do unsuccessful withdrawal of Ethers by tokenHolder3", async () => {
      const token = zero_address;

      await catchRevert(interestDistribution.withdrawInterest(token, { from: tokenHolder3 }));

    })

    // ======================================= END =======================================

    // ======================================= Withdraw by Owner =======================================
    it("Withdraw Ethers by Owner", async () => {
      const amount = web3.utils.toWei("7");
      const interestDistributionAddress = interestDistribution.address;

      await interestDistribution.withdrawByOwner(zero_address, amount, { from: tokenOwner })
      const balance = await web3.eth.getBalance(interestDistributionAddress);
      assert.equal(balance, 0);
    })

    it("Withdraw test tokens by Owner", async () => {
      const amount = web3.utils.toWei("7000");
      const testTokenAddress = testToken.address;

      await interestDistribution.withdrawByOwner(testTokenAddress, amount, { from: tokenOwner })
      const balance = await testToken.balanceOf(interestDistribution.address);
      assert.equal(BigNumber(balance).isEqualTo(0), true);
    })
    // ======================================= END =======================================

    // ======================================= Test transfer interest payment by Owner =======================================
    it("Transfer interest payment by Owner in Ether and tokens", async () => {
      //transfer 10 Ethers to interest distribution contract
      const interestDistributionAddress = interestDistribution.address;
      const amount_ETH = web3.utils.toWei("10");
      await web3.eth.sendTransaction({ to: interestDistributionAddress, value: amount_ETH, from: tokenOwner });

      //transfer ETH by Owner to tokenHolder3
      let token = zero_address;
      const balance_before_tokenHolder3 = await web3.eth.getBalance(tokenHolder3);

      await interestDistribution.transferInterestPaymentByOwner(tokenHolder3, token, amount_ETH, { from: tokenOwner });
      const balance_after_tokenHolder3 = await web3.eth.getBalance(tokenHolder3);
      assert.equal(BigNumber(balance_after_tokenHolder3).toNumber(), (BigNumber(balance_before_tokenHolder3).plus(amount_ETH).toNumber()));

      //transfer 10,000 test tokens to the interest distribution contract
      const amount_tokens = web3.utils.toWei("10000");
      await testToken.transfer(interestDistributionAddress, amount_tokens, { from: tokenOwner });

      //transfer testTokens by Owner to tokenHolder3
      token = testToken.address
      await interestDistribution.transferInterestPaymentByOwner(tokenHolder3, token, amount_tokens, { from: tokenOwner });
      const balance_token_tokenHolder3 = await testToken.balanceOf(tokenHolder3);
      assert.equal(BigNumber(balance_token_tokenHolder3).toNumber(), (BigNumber(amount_tokens).toNumber()));
    })
    // ======================================= END =======================================

    // ======================================= Test adjustment of interest payment by Owner =======================================
    it("Adjust interest payment by Owner in Ether and tokens", async () => {

      //Adjust ETH amount
      let token = zero_address;
      const amount_ETH = web3.utils.toWei("10");

      await interestDistribution.adjustInterestPaymentforAnInvestor(tokenHolder2, token, amount_ETH, "0x0", { from: address_security_level_2 });
      const interestPaymentinEthersforTokenHolder2 = await interestDistribution.interestPaymentsinEther(tokenHolder2);
      assert.equal(BigNumber(interestPaymentinEthersforTokenHolder2).toNumber(), (BigNumber(amount_ETH).toNumber()));


      //transfer testTokens by Owner to tokenHolder2
      const amount_tokens = web3.utils.toWei("10000");
      token = testToken.address
      await interestDistribution.adjustInterestPaymentforAnInvestor(tokenHolder2, token, amount_tokens, "0x0", { from: address_security_level_2 });
      const interestPaymentinTokensforTokenHolder2 = await interestDistribution.interestPaymentsinTokens(tokenHolder2, token);
      assert.equal(BigNumber(interestPaymentinTokensforTokenHolder2).toNumber(), (BigNumber(amount_tokens).toNumber()));
    })
    // ======================================= END =======================================


  });
});
