import { catchRevert, catchInvalidOpcode } from "./helpers/exceptions";

const TokenVoting = artifacts.require("./TokenVoting.sol");
const SecurityToken = artifacts.require("./SecurityToken.sol");

const Web3 = require("web3");
const BigNumber = require("bignumber.js");
const web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545")); // Hardcoded development port

contract("Start Test", accounts => {
    let tokenOwner;
    let voter1;
    let voter2;
    let voter3;
    let voter4;
    let nonwhitelist_voter1;
    let tokenVoting;
    let securityToken;
    let controller;
    const partition1 = web3.utils.fromAscii("default");
    let asset;
    const empty_data = "0x0000000000000000000000000000000000000000000000000000000000000000";
    const zero_address = "0x0000000000000000000000000000000000000000";

    before(async () => {
        voter1 = accounts[1];
        voter2 = accounts[2];
        voter3 = accounts[3];
        voter4 = accounts[4];
        nonwhitelist_voter1 = accounts[8];

        tokenOwner = accounts[0];
        controller = accounts[5];

        asset = web3.utils.fromAscii("iEstate STO Platform");

        tokenVoting = await TokenVoting.deployed();
        securityToken = await SecurityToken.deployed();
    });

    describe(`Test Token Voting functionality`, async () => {

        it("\t A non-controller should not be able to create Vote \t", async () => {
            const tokenAddress = securityToken.address;
            const partition = partition1;
            const topic = web3.utils.fromAscii("Choosing a president");
            const blockNumber = 12345678;
            const durationInSeconds = 5;

            const options = [
                web3.utils.fromAscii("Donald Trump"),
                web3.utils.fromAscii("Tim Apple"),
                web3.utils.fromAscii("Steve Jobs")
            ]

            const targetAudience = [
                voter1, voter2
            ]

            await catchRevert(tokenVoting.createVote(tokenAddress, partition, topic, blockNumber, options, targetAudience, durationInSeconds, { from: accounts[9] }));
        })

        it("\t A controller should not be able to create Vote with duplicate voters \t", async () => {
            const tokenAddress = securityToken.address;
            const partition = partition1;
            const topic = web3.utils.fromAscii("Choosing a president");
            const blockNumber = 12345678;
            const durationInSeconds = 5;

            const options = [
                web3.utils.fromAscii("Donald Trump"),
                web3.utils.fromAscii("Tim Apple"),
                web3.utils.fromAscii("Steve Jobs")
            ]

            const targetAudience = [
                voter1, voter1, voter1
            ]

            await catchRevert(tokenVoting.createVote(tokenAddress, partition, topic, blockNumber, options, targetAudience, durationInSeconds, { from: controller }));
        })

        it("\t A controller should be able to create Vote \t", async () => {
            const tokenAddress = securityToken.address;
            const partition = partition1;
            const topic = web3.utils.fromAscii("Choosing a president");
            const blockNumber = 12345678;
            const durationInSeconds = 5;

            const options = [
                web3.utils.fromAscii("Donald Trump"),
                web3.utils.fromAscii("Tim Apple"),
                web3.utils.fromAscii("Steve Jobs")
            ]

            const targetAudience = [
                voter1, voter2
            ]

            await tokenVoting.createVote(tokenAddress, partition, topic, blockNumber, options, targetAudience, durationInSeconds, { from: controller })
        })

        it("\t Adding existing voters to the vote should fail \t", async () => {
            const tokenAddress = securityToken.address;
            const partition = partition1;
            const topic = web3.utils.fromAscii("Choosing a president");
            const blockNumber = 12345678;

            const options = [
                web3.utils.fromAscii("Donald Trump"),
                web3.utils.fromAscii("Tim Apple"),
                web3.utils.fromAscii("Steve Jobs")
            ]

            const targetAudience = [
                voter1, voter2
            ]

            await catchRevert(tokenVoting.appendVoters(tokenAddress, partition, topic, blockNumber, targetAudience, { from: controller }))
        })

        it("\t A controller should be able to add voters to an already existing vote\t", async () => {
            const tokenAddress = securityToken.address;
            const partition = partition1;
            const topic = web3.utils.fromAscii("Choosing a president");
            const blockNumber = 12345678;

            const options = [
                web3.utils.fromAscii("Donald Trump"),
                web3.utils.fromAscii("Tim Apple"),
                web3.utils.fromAscii("Steve Jobs")
            ]

            const targetAudience = [
                voter3, voter4
            ]

            await tokenVoting.appendVoters(tokenAddress, partition, topic, blockNumber, targetAudience, { from: controller })
        })

        it("\t Get the number of votes \t", async () => {
            const tokenAddress = securityToken.address;
            const partition = partition1;
            const topic = web3.utils.fromAscii("Choosing a president");
            const blockNumber = 12345678;

            const response = await tokenVoting.getStats(tokenAddress, partition, topic, blockNumber);

            assert.equal(BigNumber(response["1"][0]).toNumber(), 0);
            assert.equal(BigNumber(response["1"][1]).toNumber(), 0);
            assert.equal(BigNumber(response["1"][2]).toNumber(), 0);
        })

        it("\t Submit vote by voter1 \t", async () => {
            const tokenAddress = securityToken.address;
            const partition = partition1;
            const topic = web3.utils.fromAscii("Choosing a president");
            const blockNumber = 12345678;
            const vote = web3.utils.fromAscii("Tim Apple");

            await tokenVoting.submitVote(tokenAddress, partition, topic, blockNumber, vote, { from: voter1 });
        })

        it("\t A non-whitelist address shoudn't be able to submit vote \t", async () => {
            const tokenAddress = securityToken.address;
            const partition = partition1;
            const topic = web3.utils.fromAscii("Choosing a president");
            const blockNumber = 12345678;
            const vote = web3.utils.fromAscii("Tim Apple");

            await catchRevert(tokenVoting.submitVote(tokenAddress, partition, topic, blockNumber, vote, { from: nonwhitelist_voter1 }));
        })

        it("\t Submit vote by voter2 \t", async () => {
            const tokenAddress = securityToken.address;
            const partition = partition1;
            const topic = web3.utils.fromAscii("Choosing a president");
            const blockNumber = 12345678;
            const vote = web3.utils.fromAscii("Steve Jobs");

            await tokenVoting.submitVote(tokenAddress, partition, topic, blockNumber, vote, { from: voter2 });
        })

        it("\t Submit vote by voter3 \t", async () => {
            const tokenAddress = securityToken.address;
            const partition = partition1;
            const topic = web3.utils.fromAscii("Choosing a president");
            const blockNumber = 12345678;
            const vote = web3.utils.fromAscii("Tim Apple");

            await tokenVoting.submitVote(tokenAddress, partition, topic, blockNumber, vote, { from: voter3 });
        })

        it("\t Submit vote by voter4 \t", async () => {
            const tokenAddress = securityToken.address;
            const partition = partition1;
            const topic = web3.utils.fromAscii("Choosing a president");
            const blockNumber = 12345678;
            const vote = web3.utils.fromAscii("Donald Trump");

            await tokenVoting.submitVote(tokenAddress, partition, topic, blockNumber, vote, { from: voter4 });
        })

        it("\t Should get empty votes when the vote is open\t", async () => {
            const tokenAddress = securityToken.address;
            const partition = partition1;
            const topic = web3.utils.fromAscii("Choosing a president");
            const blockNumber = 12345678;
            const options = [
                web3.utils.fromAscii("Donald Trump"),
                web3.utils.fromAscii("Tim Apple"),
                web3.utils.fromAscii("Steve Jobs")
            ]

            const response = await tokenVoting.getVotes(tokenAddress, partition, topic, blockNumber, { from: accounts[9] });

            assert.equal(response["1"][0], empty_data);
            assert.equal(response["1"][1], empty_data);
            assert.equal(response["1"][2], empty_data);
            assert.equal(response["1"][3], empty_data);

        })

        it("\t Should Get All votes \t", async () => {
            const tokenAddress = securityToken.address;
            const partition = partition1;
            const topic = web3.utils.fromAscii("Choosing a president");
            const blockNumber = 12345678;
            const options = [
                web3.utils.fromAscii("Donald Trump"),
                web3.utils.fromAscii("Tim Apple"),
                web3.utils.fromAscii("Steve Jobs")
            ]

            return new Promise((resolve, reject) => {
                setTimeout(async () => {
                    try {
                        const response = await tokenVoting.getVotes(tokenAddress, partition, topic, blockNumber, { from: accounts[9] });

                        assert.equal(response["1"][0], options[1]);
                        assert.equal(response["1"][1], options[2]);
                        assert.equal(response["1"][2], options[1]);
                        assert.equal(response["1"][3], options[0]);
                        resolve(true);
                    } catch (err) {
                        reject(err);
                    }

                }, 5000);
            })


        })

        it("\t Test the winner option \t", async () => {
            const tokenAddress = securityToken.address;
            const partition = partition1;
            const topic = web3.utils.fromAscii("Choosing a president");
            const blockNumber = 12345678;

            const options = [
                web3.utils.fromAscii("Donald Trump"),
                web3.utils.fromAscii("Tim Apple"),
                web3.utils.fromAscii("Steve Jobs")
            ]

            const response = await tokenVoting.getStats(tokenAddress, partition, topic, blockNumber);

            let maxVotesCount = 0;
            let maxVotesOption = ""
            for (let i = 0; i < response["0"].length; i++) {
                if (response["1"][i] > maxVotesCount) {
                    maxVotesOption = response["0"][i];
                    maxVotesCount = BigNumber(response["1"][i]).toNumber();
                }
            }

            assert.equal(maxVotesOption, options[1])
            assert.equal(maxVotesCount, 2);

        });


        // =============================== Test with manual closure of Votes =======================
        it("\t A controller should be able to create Vote \t", async () => {
            const tokenAddress = securityToken.address;
            const partition = partition1;
            const topic = web3.utils.fromAscii("Choosing a president");
            const blockNumber = 12345679;
            const durationInSeconds = 2000;

            const options = [
                web3.utils.fromAscii("Donald Trump"),
                web3.utils.fromAscii("Tim Apple"),
                web3.utils.fromAscii("Steve Jobs")
            ]

            const targetAudience = [
                voter1, voter2
            ]

            await tokenVoting.createVote(tokenAddress, partition, topic, blockNumber, options, targetAudience, durationInSeconds, { from: controller })
        })

        it("\t Submit vote by voter1 \t", async () => {
            const tokenAddress = securityToken.address;
            const partition = partition1;
            const topic = web3.utils.fromAscii("Choosing a president");
            const blockNumber = 12345679;
            const vote = web3.utils.fromAscii("Steve Jobs");

            await tokenVoting.submitVote(tokenAddress, partition, topic, blockNumber, vote, { from: voter1 });
        })

        it("\t Submit vote by voter2 \t", async () => {
            const tokenAddress = securityToken.address;
            const partition = partition1;
            const topic = web3.utils.fromAscii("Choosing a president");
            const blockNumber = 12345679;
            const vote = web3.utils.fromAscii("Tim Apple");

            await tokenVoting.submitVote(tokenAddress, partition, topic, blockNumber, vote, { from: voter2 });
        })

        it("\t Manually close the vote by controller \t", async () => {
            const tokenAddress = securityToken.address;
            const partition = partition1;
            const topic = web3.utils.fromAscii("Choosing a president");
            const blockNumber = 12345679;

            await tokenVoting.closeVoteManually(tokenAddress, partition, topic, blockNumber, { from: controller });

            const isVoteClosed = await tokenVoting.votingIsClosed(tokenAddress, partition, topic, blockNumber);
            assert.equal(isVoteClosed, true);
        })

        it("\t Should Get All votes \t", async () => {
            const tokenAddress = securityToken.address;
            const partition = partition1;
            const topic = web3.utils.fromAscii("Choosing a president");
            const blockNumber = 12345679;
            const options = [
                web3.utils.fromAscii("Donald Trump"),
                web3.utils.fromAscii("Tim Apple"),
                web3.utils.fromAscii("Steve Jobs")
            ]


            const response = await tokenVoting.getVotes(tokenAddress, partition, topic, blockNumber, { from: accounts[9] });

            assert.equal(response["1"][0], options[2]);
            assert.equal(response["1"][1], options[1]);
        })

    });

});