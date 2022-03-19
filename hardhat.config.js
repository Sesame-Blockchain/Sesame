require("dotenv").config();
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-web3");
require("hardhat-gas-reporter");
require("solidity-coverage");
require('@openzeppelin/hardhat-upgrades');
require('hardhat-contract-sizer');
require("hardhat-erc1820");

module.exports = {
  defaultNetwork: "hardhat",
  solidity: {
    version: "0.8.7",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1,
      },
    },
  },
  networks: {
    ganache: {
      chainId: 1337,
      url: "HTTP://127.0.0.1:8545"
    },
    bscTestnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      gasPrice: 20000000000,
      from: process.env.ADMIN_PRIVATE_KEY,
      accounts: [
        process.env.ADMIN_PRIVATE_KEY,
        process.env.USER_1_KEY,
        process.env.USER_2_KEY
      ]
    },
    bsc: {
      url: "https://bsc-dataseed.binance.org/",
      chainId: 56,
      gasPrice: 20000000000,
      from: process.env.ADMIN_PRIVATE_KEY_PROD,
      accounts: [process.env.ADMIN_PRIVATE_KEY_PROD]
    }
  },
  etherscan: {
    apiKey: {
      bsc: process.env.BSCSCAN_TOKEN,
      bscTestnet: process.env.BSCSCAN_TOKEN
    }
  },
  gasReporter: {
    enabled: false,
    coinmarketcap: process.env.COIN_MARKET_CAP_API_KEY,
    currency: "USD"
  }
};
