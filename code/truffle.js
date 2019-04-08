require('babel-register');
require('babel-polyfill');

var HDWalletProvider = require("truffle-hdwallet-provider");

var mnemonic = "avocado armed also position solution total token maze deny neutral bless share"; //takes any length mnemonic, uses m/44'/60'/0'/0/0 derivation path to resolve address[0]

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*" // Match any network id,
    },
    coverage: {
      host: "localhost",
      network_id: "*",
      port: 8555,         // <-- If you change this, also set the port option in .solcover.js.
      gas: 0xfffffffffff, // <-- Use this high gas value
      gasPrice: 0x01      // <-- Use this low gas price
    },
    ropsten: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "https://ropsten.infura.io/QWMgExFuGzhpu2jUr6Pq",0,9)
      },
      network_id: 3,
      gas: 4712388

    },
    rinkeby: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "https://rinkeby.infura.io/QWMgExFuGzhpu2jUr6Pq",0 ,9)
      },
      network_id: 4,
      // gas: 6712388,
      // gasPrice:8000000000
    },
    mainnet: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "https://mainnet.infura.io/QWMgExFuGzhpu2jUr6Pq")
      },
      network_id: 1,
      gas: 4712388

    }   
    
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 200
    }
  }};