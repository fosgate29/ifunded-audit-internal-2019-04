import { catchRevert, catchInvalidOpcode } from "./helpers/exceptions";
import { takeSnapshot, revertToSnapshot } from "./helpers/time";

const SecurityToken = artifacts.require('./SecurityToken.sol');
const Whitelist = artifacts.require("./DefaultSecurityTokenWhitelist.sol");
const RBAC = artifacts.require("./PlatformProviderRbac.sol");

const Web3 = require("web3");
const BigNumber = require("bignumber.js");
const web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545")); // Hardcoded development port

contract("ERC20", accounts => {

    let tokenOwner;
    let operator1;
    let operator2;
    let tokenHolder1;
    let tokenHolder2;
    let securityOperator;
    let address_with_security_level_2;
    let address_with_security_level_1;
    let securityToken;
    let whitelist;
    let rbac;

    const partition1 = web3.utils.fromAscii("default");

    const empty_data = "0x0000000000000000000000000000000000000000";
    const zero_address = "0x0000000000000000000000000000000000000000";

    before(async () => {
        tokenHolder1 = accounts[3];
        tokenHolder2 = accounts[2];
        operator1 = accounts[5];
        operator2 = accounts[6];
        tokenOwner = accounts[0];
        address_with_security_level_2 = accounts[4];
        address_with_security_level_1 = accounts[8];
        securityOperator = accounts[7];

        securityToken = await SecurityToken.deployed();
        whitelist = await Whitelist.deployed();
        rbac = await RBAC.deployed();
    });

    describe(`Test cases for the ERC20 contract\n`, async () => {

        describe(`Test cases for Transfer and TransferFrom`, async () => {

            it("\t Transfer tokens\n", async () => {
                await rbac.addOperator(securityOperator, web3.utils.fromAscii("iEstate STO Platform"), { from: tokenOwner });
                await rbac.addToLevel1(address_with_security_level_1, { from: securityOperator });
                await rbac.addToLevel2(address_with_security_level_2, { from: securityOperator });
                await whitelist.addVerified(tokenHolder1, web3.utils.fromAscii("John from Alaska"), web3.utils.fromAscii("iEstate STO Platform"), { from: address_with_security_level_1 });
                await securityToken.issueByPartition(partition1, tokenHolder1, web3.utils.toWei("10"), web3.utils.fromAscii("0x0"), { from: address_with_security_level_2 });

                await whitelist.addVerified(tokenHolder2, web3.utils.fromAscii("John from Jordan"), web3.utils.fromAscii("iEstate STO Platform"), { from: address_with_security_level_1 });
                await securityToken.issueByPartition(partition1, tokenHolder2, web3.utils.toWei("10"), web3.utils.fromAscii("0x0"), { from: address_with_security_level_2 });

                await securityToken.canTransfer(tokenHolder1, web3.utils.toWei("5"), web3.utils.fromAscii(""), { from: tokenHolder2 });
                await securityToken.transfer(tokenHolder1,  web3.utils.toWei("5"), {from: tokenHolder2});
                await securityToken.transferWithData(tokenHolder1, web3.utils.toWei("5"), web3.utils.fromAscii(""), { from: tokenHolder2 });

                let holder1_balance = await securityToken.balanceOf.call(tokenHolder1);
               

                assert.equal(BigNumber(holder1_balance).isEqualTo(web3.utils.toBN(web3.utils.toWei("20"))), true);
                
            });

            it("\t TransferFrom tokens\n", async () => {
                await securityToken.approve(tokenHolder2, web3.utils.toWei("10"), {from: tokenHolder1});
               
                let allowance = await securityToken.allowance.call(tokenHolder1, tokenHolder2);
                assert.equal(BigNumber(allowance).isEqualTo(web3.utils.toWei("10")), true);

                await securityToken.canTransferFrom(tokenHolder1, tokenHolder2, web3.utils.toWei("5"), web3.utils.fromAscii(""), { from: tokenHolder2 })
                await securityToken.transferFrom(tokenHolder1, tokenHolder2,  web3.utils.toWei("5"), {from: tokenHolder2});
                await securityToken.transferFromWithData(tokenHolder1, tokenHolder2, web3.utils.toWei("5"), web3.utils.fromAscii(""), { from: tokenHolder2 });

                allowance = await securityToken.allowance.call(tokenHolder1, tokenHolder2);
                assert.equal(BigNumber(allowance).isEqualTo(0), true);
                
                let holder1_balance = await securityToken.balanceOf.call(tokenHolder1);

                assert.equal(BigNumber(holder1_balance).isEqualTo(web3.utils.toWei("10")), true);
            });

            it("\t Test canFreezeMinting \t", async () => {
                const canFreezeMinting = await securityToken.canFreezeMinting(address_with_security_level_2);
                assert.equal(canFreezeMinting, true);
            })

            it("\t Issue tokens \t", async () => {
                const receiver = accounts[9];

                const issuable = await securityToken.isIssuable();
                assert.equal(issuable, true);

                await securityToken.issue(receiver, web3.utils.toWei("10"), web3.utils.fromAscii(""), { from: address_with_security_level_2 });

                const balance = await securityToken.balanceOf(receiver);
                assert.equal(BigNumber(balance).isEqualTo(web3.utils.toWei("10")), true);
            })


            describe(`Test cases for Token information`, async () => {

                it("\t Check token name\n", async () => {
                 const name = await securityToken.name();
                 assert.equal(name, "Test Security Token");   
                })
    
                it("\t Check token symbol\n", async () => {
                    const symbol = await securityToken.symbol();
                    assert.equal(symbol, "TST");   
                })
    
                it("\t Check token decimals\n", async () => {
                    const decimals = await securityToken.decimals();
                    assert.equal(decimals, 0);   
                   })
            });

        })
    });

});