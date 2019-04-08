import { catchRevert, catchInvalidOpcode } from "./helpers/exceptions";
import { takeSnapshot, revertToSnapshot } from "./helpers/time";

const SecurityToken = artifacts.require('./SecurityToken.sol');
const Whitelist = artifacts.require("./DefaultSecurityTokenWhitelist.sol");
const RBAC = artifacts.require("./PlatformProviderRbac.sol");

const Web3 = require("web3");
const BigNumber = require("bignumber.js");
const web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545")); // Hardcoded development port

contract("ERC1410", accounts => {
    
let tokenOwner;
let operator1;
let operator2;
let tokenHolder1;
let tokenHolder2;
let securityToken;
let securityOperator;
let address_with_security_level_2;
let address_with_security_level_1;
let whitelist;
let rbac;

const partition1 = web3.utils.fromAscii("default");
const partition2 = web3.utils.fromAscii("Equity");
const partition3 = web3.utils.fromAscii("locked");

const empty_data = "0x0000000000000000000000000000000000000000000000000000000000000000";
const zero_address = "0x0000000000000000000000000000000000000000";

    before(async () => {
        tokenHolder1 = accounts[3];
        tokenHolder2 = accounts[2];
        operator1 = accounts[5];
        operator2 = accounts[6];
        tokenOwner = accounts[0];
        securityOperator = accounts[1];
        address_with_security_level_1 = accounts[4];
        address_with_security_level_2 = accounts[7];

        securityToken = await SecurityToken.deployed();
        whitelist = await Whitelist.deployed();
        rbac = await RBAC.deployed();

    });

    describe(`Test cases for the ERC1410 contract\n`, async () => {

        describe(`Test cases for the issuance/Minting`, async() => {

            it("\t Test canIssue \t", async () => {
                await rbac.addOperator(securityOperator, web3.utils.fromAscii("iEstate STO Platform"), { from: tokenOwner });
                await rbac.addToLevel1(address_with_security_level_1, { from: securityOperator });
                await rbac.addToLevel2(address_with_security_level_2, { from: securityOperator });

                const canIssue = await securityToken.canIssue(address_with_security_level_2);
                assert.equal(canIssue, true);
            })

            it("\t Test canRedeem \t", async () => {

                const canRedeem = await securityToken.canRedeem(address_with_security_level_2);
                assert.equal(canRedeem, true);
            })


            it("\t Should issue the tokens by the partition\n", async() => {
                await whitelist.addVerified(tokenHolder1, web3.utils.fromAscii("John from Alaska"), web3.utils.fromAscii("iEstate STO Platform"), {from: address_with_security_level_1});
                await securityToken.issueByPartition(partition1, tokenHolder1, web3.utils.toWei("10"), "0x0", {from: address_with_security_level_2});

                assert.equal(web3.utils.fromWei((await securityToken.totalSupply.call()).toString()), 10);
                assert.equal(web3.utils.fromWei((await securityToken.balanceOf.call(tokenHolder1)).toString()), 10);
                assert.equal(
                    web3.utils.fromWei((await securityToken.balanceOfByPartition.call(partition1, tokenHolder1)).toString()),
                    10
                );
                assert.equal(
                    (await securityToken.partitionsOf(tokenHolder1)).length, 1
                );
                let fetched_partition = await securityToken.partitionsOf(tokenHolder1);
                
                assert.equal(
                    fetched_partition[0],
                    partition1
                );
            });

            it("\t Should issue more tokens to the same token holder \n", async() => {
                await securityToken.issueByPartition(partition1, tokenHolder1, web3.utils.toWei("20"), "0x0", {from: address_with_security_level_2});

                assert.equal(web3.utils.fromWei((await securityToken.totalSupply.call()).toString()), 30);
                assert.equal(web3.utils.fromWei((await securityToken.balanceOf.call(tokenHolder1)).toString()), 30);
                
                assert.equal(
                    web3.utils.fromWei((await securityToken.balanceOfByPartition.call(partition1, tokenHolder1)).toString()),
                    30
                );
                assert.equal(
                    (await securityToken.partitionsOf(tokenHolder1)).length, 1
                );
                let fetched_partition = await securityToken.partitionsOf(tokenHolder1);

                assert.equal(
                    fetched_partition[0],
                    partition1
                );
            });


            it("\t Should issue some more tokens to another token holder of the same partition \n", async() => {
                await whitelist.addVerified(tokenHolder2, web3.utils.fromAscii("John from Alaska"), web3.utils.fromAscii("iEstate STO Platform"), {from: address_with_security_level_1});

                await securityToken.issueByPartition(partition1, tokenHolder2, web3.utils.toWei("50"), "0x0", {from: address_with_security_level_2});

                assert.equal(web3.utils.fromWei((await securityToken.totalSupply.call()).toString()), 80);
                assert.equal(web3.utils.fromWei((await securityToken.balanceOf.call(tokenHolder2)).toString()), 50);
                assert.equal(
                    web3.utils.fromWei((await securityToken.balanceOfByPartition.call(partition1, tokenHolder2)).toString()),
                    50
                );
                assert.equal(
                    (await securityToken.partitionsOf(tokenHolder2)).length, 1
                );
                let fetched_partition = await securityToken.partitionsOf(tokenHolder1);
                assert.equal(
                    fetched_partition[0],
                    partition1
                );
            });

            it("\t Should failed to issue tokens by partition because of unauthorised msg.sender \n", async() => {
                await catchRevert(
                    securityToken.issueByPartition(partition1, tokenHolder1, web3.utils.toWei("10"), "0x0", {from: operator1})
                );
            });

            it("\t Should failed to issue tokens because of invalid partition \n", async() => {
                await catchRevert(
                    securityToken.issueByPartition("0x0", tokenHolder1, web3.utils.toWei("10"), "0x0", {from: address_with_security_level_2})
                );
            });

            it("\t Should failed to issue tokens because reciever address is 0x \n", async() => {
                await catchRevert(
                    securityToken.issueByPartition(partition1, zero_address, web3.utils.toWei("10"), "0x0", {from: address_with_security_level_2})
                );
            });

            it("\t Should failed to issue tokens because value is 0 \n", async() => {
                await catchRevert(
                    securityToken.issueByPartition(partition1, tokenHolder2, 0, "0x0", {from: address_with_security_level_2})
                );
            });
        });

        describe("Transfer the tokens (transferByPartition)", async() => {

            it("\t Should transfer the tokens from token holder 1 to token holder 2 \n", async() => {
                let tx = await securityToken.transferByPartition(partition1, tokenHolder1, web3.utils.toWei("5"), web3.utils.fromAscii(""), {from: tokenHolder2});

                // verify the event
                assert.equal(tx.logs[0].args._fromPartition, partition1);
                assert.equal(tx.logs[0].args._operator, zero_address);
                assert.equal(tx.logs[0].args._from, tokenHolder2);
                assert.equal(tx.logs[0].args._to, tokenHolder1);
                assert.equal(web3.utils.fromWei((tx.logs[0].args._value).toString()), 5);
                assert.equal(tx.logs[0].args._data, empty_data);
                console.log(tx.logs[0].args._operatorData, null);
                assert.equal(tx.logs[0].args._operatorData, null);
            });

            it("\t Should transfer the tokens from token holder 2 to token holder 1 \n", async() => {
                let tx = await securityToken.transferByPartition(partition1, tokenHolder2, web3.utils.toWei("10"), web3.utils.fromAscii(""), {from: tokenHolder1});

                // verify the event
                assert.equal(tx.logs[0].args._fromPartition, partition1);
                assert.equal(tx.logs[0].args._operator, zero_address);
                assert.equal(tx.logs[0].args._from, tokenHolder1);
                assert.equal(tx.logs[0].args._to, tokenHolder2);
                assert.equal(web3.utils.fromWei((tx.logs[0].args._value).toString()), 10);

                assert.equal(web3.utils.fromWei((await securityToken.balanceOf.call(tokenHolder2)).toString()), 55);
                assert.equal(
                    web3.utils.fromWei((await securityToken.balanceOfByPartition.call(partition1, tokenHolder2)).toString()),
                    55
                );
            });

            it("\t Should fail to transfer the tokens from a invalid partition\n", async() => {
                await catchRevert(
                    securityToken.transferByPartition(web3.utils.fromAscii("locked"), tokenHolder2, web3.utils.toWei("10"), web3.utils.fromAscii(""), {from: tokenHolder1})
                );
            });

            it("\t Should fail to transfer when partition balance is insufficient\n", async() => {
                await catchRevert(
                    securityToken.transferByPartition(partition1, tokenHolder2, web3.utils.toWei("30"), web3.utils.fromAscii(""), {from: tokenHolder1})
                );
            });

            it("\t Should fail to transfer when reciever address is 0x\n", async() => {
                await catchRevert(
                    securityToken.transferByPartition(partition1, zero_address, web3.utils.toWei("10"), web3.utils.fromAscii(""), {from: tokenHolder1})
                );
            });

            it("\t Should issue more tokens of different partitions to token holder 1 & 2\n", async() => {
                await securityToken.issueByPartition(partition2, tokenHolder1, web3.utils.toWei("20"), "0x0", {from: address_with_security_level_2});

                assert.equal(web3.utils.fromWei((await securityToken.totalSupply.call()).toString()), 100);
                assert.equal(web3.utils.fromWei((await securityToken.balanceOf.call(tokenHolder1)).toString()), 45);
                assert.equal(
                    web3.utils.fromWei((await securityToken.balanceOfByPartition.call(partition2, tokenHolder1)).toString()),
                    20
                );
                assert.equal(
                    (await securityToken.partitionsOf(tokenHolder1)).length, 2
                );

                let fetched_partition = await securityToken.partitionsOf(tokenHolder1)
                assert.equal(
                    fetched_partition[1],
                    partition2
                );

                await securityToken.issueByPartition(partition3, tokenHolder2, web3.utils.toWei("30"), "0x0", {from: address_with_security_level_2});

                assert.equal(web3.utils.fromWei((await securityToken.totalSupply.call()).toString()), 130);
                assert.equal(web3.utils.fromWei((await securityToken.balanceOf.call(tokenHolder2)).toString()), 85);
                assert.equal(
                    web3.utils.fromWei((await securityToken.balanceOfByPartition.call(partition3, tokenHolder2)).toString()),
                    30
                );
                assert.equal(
                    (await securityToken.partitionsOf(tokenHolder2)).length, 2
                );

                fetched_partition = await securityToken.partitionsOf(tokenHolder2)
                assert.equal(
                    fetched_partition[1],
                    partition3
                );
            });

            it("\t Should fail to transfer the tokens from a partition because reciever doesn't have the partition tokens\n", async() => {
                await catchInvalidOpcode(
                    securityToken.transferByPartition(partition2, tokenHolder2, web3.utils.toWei("3"), web3.utils.fromAscii(""), {from: tokenHolder1})
                );
            });
        });

        describe("Test cases for verifying the output of canTransferByPartition()", async() => {

            it("\t Should transfer the tokens from token holder 1 to token holder 2 \n", async() => {
                let op = await securityToken.canTransferByPartition.call(tokenHolder2, tokenHolder1, partition1, web3.utils.toWei("5"), web3.utils.fromAscii(""));
                assert.equal(op[0], 0x51);
                assert.equal(web3.utils.toUtf8(op[1]), "Success");
                assert.equal(op[2], partition1);
            })

            it("\t Should transfer the tokens from token holder 2 to token holder 1 \n", async() => {
                let op = await securityToken.canTransferByPartition.call(tokenHolder1, tokenHolder2, partition1, web3.utils.toWei("10"), web3.utils.fromAscii(""));
                assert.equal(op[0], 0x51);
                assert.equal(web3.utils.toUtf8(op[1]), "Success");
                assert.equal(op[2], partition1);
            })

            it("\t Should fail to transfer the tokens from a invalid partition\n", async() => {
                let op = await securityToken.canTransferByPartition.call(tokenHolder1, tokenHolder2, web3.utils.fromAscii("Vested"), web3.utils.toWei("10"), web3.utils.fromAscii(""));
                assert.equal(op[0], 0x50);
                assert.equal(web3.utils.toUtf8(op[1]), "The partition does not exist");
                assert.equal(op[2], web3.utils.fromAscii(""));
            })

            it("\t Should fail to transfer when partition balance is insufficient\n", async() => {
                let op = await securityToken.canTransferByPartition.call(tokenHolder1, tokenHolder2, partition1, web3.utils.toWei("30"), web3.utils.fromAscii(""));
                assert.equal(op[0], 0x52);
                assert.equal(web3.utils.toUtf8(op[1]), "Insufficent balance");
                assert.equal(op[2], web3.utils.fromAscii(""));
            })

        });

        describe("Test cases for the Operator functionality", async() => {
            
            it("\t Should authorize the operator\n", async() => {
                let tx = await securityToken.authorizeOperator(operator1, {from: tokenHolder1});
                assert.equal(tx.logs[0].args.operator, operator1);
                assert.equal(tx.logs[0].args.tokenHolder, tokenHolder1);
            });

            it("\t Should check for the operator \n", async() => {
                assert.isTrue(await securityToken.isOperator.call(operator1, tokenHolder1));
            });

            it("\t Should return false by the isOperatorForPartition \n", async() => {
                assert.isFalse(await securityToken.isOperatorForPartition.call(partition1, operator1, tokenHolder1));
            });

            it(" \t Should transfer the tokens by OperatorByPartition\n", async() => {
                let tx = await securityToken.operatorTransferByPartition(
                    partition1, tokenHolder1, tokenHolder2, web3.utils.toWei("2"), web3.utils.fromAscii(""), web3.utils.fromAscii("Lawyer"), {from: operator1}
                );

                // verify the event
                assert.equal(tx.logs[0].args._fromPartition, partition1);
                assert.equal(tx.logs[0].args._operator, operator1);
                assert.equal(tx.logs[0].args._from, tokenHolder1);
                assert.equal(tx.logs[0].args._to, tokenHolder2);
                assert.equal(web3.utils.fromWei((tx.logs[0].args._value).toString()), 2);


                assert.equal(web3.utils.fromWei((await securityToken.balanceOf.call(tokenHolder2)).toString()), 87);
                assert.equal(
                    web3.utils.fromWei((await securityToken.balanceOfByPartition.call(partition1, tokenHolder2)).toString()),
                    57
                );
            });

            it("\t Should fail to transfer the tokens by OperatorByPartition because of unauthorised operator\n", async() => {
                await catchRevert(
                    securityToken.operatorTransferByPartition(
                        partition1, tokenHolder1, tokenHolder2, web3.utils.toWei("2"), web3.utils.fromAscii(""), web3.utils.fromAscii("Lawyer"), {from: operator2}
                    )
                );
            });

            it("\t Should revoke the operator\n", async() => {
                let tx = await securityToken.revokeOperator(operator1, {from: tokenHolder1});
                assert.equal(tx.logs[0].args.operator, operator1);
                assert.equal(tx.logs[0].args.tokenHolder, tokenHolder1);
            });

            it("\t Should succesfully authorize the operator by partition\n", async() => {
                let tx = await securityToken.authorizeOperatorByPartition(partition1, operator2, {from: tokenHolder1});
                assert.equal(tx.logs[0].args.operator, operator2);
                assert.equal(tx.logs[0].args.partition, partition1);
                assert.equal(tx.logs[0].args.tokenHolder, tokenHolder1);
            });

            it("\t Should give true by isOperatorForPartition\n", async() => {
                assert.isTrue(await securityToken.isOperatorForPartition.call(partition1, operator2, tokenHolder1));
            });

            it("\t Should transfer the tokens usng operator\n", async() => {
                let tx = await securityToken.operatorTransferByPartition(
                    partition1, tokenHolder1, tokenHolder2, web3.utils.toWei("2"), web3.utils.fromAscii(""), web3.utils.fromAscii("Lawyer"), {from: operator2}
                );

                // verify the event
                assert.equal(tx.logs[0].args._fromPartition, partition1);
                assert.equal(tx.logs[0].args._operator, operator2);
                assert.equal(tx.logs[0].args._from, tokenHolder1);
                assert.equal(tx.logs[0].args._to, tokenHolder2);
                

                assert.equal(web3.utils.fromWei((await securityToken.balanceOf.call(tokenHolder2)).toString()), 89);
                assert.equal(
                    web3.utils.fromWei((await securityToken.balanceOfByPartition.call(partition1, tokenHolder2)).toString()),
                    59
                );
            });

            it("\t Should fail to transfer the token because operator is get revoked\n", async() => {
                let tx = await securityToken.revokeOperatorByPartition(partition1, operator2, {from: tokenHolder1});
                assert.equal(tx.logs[0].args.operator, operator2);
                assert.equal(tx.logs[0].args.partition, partition1);
                assert.equal(tx.logs[0].args.tokenHolder, tokenHolder1);
            });

            it("\t Should fail to transfer the tokens by OperatorByPartition because of unauthorised operator\n", async() => {
                await catchRevert(
                    securityToken.operatorTransferByPartition(
                        partition1, tokenHolder1, tokenHolder2, web3.utils.toWei("2"), web3.utils.fromAscii(""), web3.utils.fromAscii("Lawyer"), {from: operator2}
                    )
                );
            });
        });

        describe("Test the redeem functionality", async() => {
            
            it("\t Should fail to redeem the tokens as the value is 0 \n", async() => {
                await catchRevert(
                    securityToken.redeemByPartition(partition1, 0, web3.utils.fromAscii(""), {from: tokenHolder2})
                );
            });

            it("\t Should fail to redeem the tokens as the partition is 0 \n", async() => {
                await catchRevert(
                    securityToken.redeemByPartition(empty_data, 0, web3.utils.fromAscii(web3.utils.toWei("7")), {from: tokenHolder2})
                );
            });

            it("\t Should fail to redeem the tokens as the partition is invalid\n", async() => {
                await catchRevert(
                    securityToken.redeemByPartition(partition2, 0,  web3.utils.fromAscii(web3.utils.toWei("7")), {from: tokenHolder2})
                );
            });

            it("\t Should fail to redeem the tokens because holder doesn't have sufficeint balance\n", async() => {
                await catchRevert(
                    securityToken.redeemByPartition(partition2, 0,  web3.utils.fromAscii(web3.utils.toWei("70")), {from: tokenHolder2})
                );
            });

            it("\t Should successfully redeem the tokens\n", async() => {
                await rbac.addToLevel2(tokenHolder2, { from: securityOperator });

                let tx = await securityToken.redeemByPartition(partition1,  web3.utils.toWei("7"),  web3.utils.fromAscii(""), {from: tokenHolder2});

                // verify the event
                assert.equal(tx.logs[0].args.partition, partition1);
                assert.equal(tx.logs[0].args.operator, zero_address);
                assert.equal(tx.logs[0].args.from, tokenHolder2);

            });

            it("\t Should fail to redeem tokens by the operator because token holder is zero address\n", async() => {
                await securityToken.authorizeOperatorByPartition(partition3, operator2, {from: tokenHolder2});
                let value = (await securityToken.balanceOfByPartition.call(partition3, tokenHolder2)).toString();
                await catchRevert(
                    securityToken.operatorRedeemByPartition(
                        partition3, zero_address, value,  web3.utils.fromAscii(""),  web3.utils.fromAscii("illegal"), {from: operator2}
                    )
                );
            });

            it("\t Should fail to redeem to tokens by the operator because operator is invalid\n", async() => {
                let value = (await securityToken.balanceOfByPartition.call(partition3, tokenHolder2)).toString();
                await catchRevert(
                    securityToken.operatorRedeemByPartition(
                        partition3, zero_address, value, web3.utils.fromAscii(""), web3.utils.fromAscii("illegal"), {from: operator1}
                    )
                );
            })

            it("\t Should successfully redeem tokens by the operator \n", async() => {
                
                let value = await securityToken.balanceOfByPartition.call(partition3, tokenHolder2);
                await rbac.addToLevel2(operator2, { from: securityOperator });

                let tx = await securityToken.operatorRedeemByPartition(
                    partition3, tokenHolder2, value, web3.utils.fromAscii(""), web3.utils.fromAscii("illegal"), {from: operator2}
                );

                // verify the event
                assert.equal(tx.logs[0].args.partition, partition3);
                assert.equal(tx.logs[0].args.operator, operator2);
                assert.equal(tx.logs[0].args.from, tokenHolder2);

            });

        })
    });
});