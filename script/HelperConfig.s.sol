// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;
import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Script, console2} from "lib/forge-std/src/Script.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {EntryPoint} from "lib/account-abstraction/contracts/core/EntryPoint.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
contract HelperConfig is Script {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        address entryPoint;
        address usdc;
        address account;
    }
    uint256 constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ZKSYNC_SEPOLIA_CHAIN_ID = 300;
    uint256 constant LOCAL_CHAIN_ID = 31337;
    // Update the BURNER_WALLET to your burner wallet!
    address constant BURNER_WALLET = 0x71BeB7064D6dA1E27278F3d17F0436E389D7E686; //zkSyncSepolia
    uint256 constant ARBITRUM_MAINNET_CHAIN_ID = 42_161;
    uint256 constant ZKSYNC_MAINNET_CHAIN_ID = 324;
    address constant ANVIL_DEFAULT_ACCOUNT =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;
    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
        networkConfigs[ETH_MAINNET_CHAIN_ID] = getEthMainnetConfig();
        networkConfigs[ZKSYNC_MAINNET_CHAIN_ID] = getZkSyncConfig();
        networkConfigs[ARBITRUM_MAINNET_CHAIN_ID] = getArbMainnetConfig();
    }
    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(
        uint256 chainId
    ) public returns (NetworkConfig memory) {
        if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else if (networkConfigs[chainId].account != address(0)) {
            return networkConfigs[chainId];
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }
    function getEthMainnetConfig() public pure returns (NetworkConfig memory) {
        // This is v7
        return
            NetworkConfig({
                entryPoint: 0x0000000071727De22E5E9d8BAf0edAc6f37da032,
                usdc: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, //The official USDC contract address on Ethereum Mainnet
                account: BURNER_WALLET
            });
        // https://blockscan.com/address/0x0000000071727De22E5E9d8BAf0edAc6f37da032
    }
    function getEthSepoliaConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entryPoint: address(0x71BeB7064D6dA1E27278F3d17F0436E389D7E686),
                usdc: address(0), // Replace with actual USDC address on Sepolia if needed
                account: BURNER_WALLET
            });
    }
    function getArbMainnetConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entryPoint: 0x0000000071727De22E5E9d8BAf0edAc6f37da032,
                usdc: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831, //arbMainnet usdc address
                account: BURNER_WALLET
            });
    }
    function getZkSyncSepoliaConfig()
        public
        pure
        returns (NetworkConfig memory)
    {
        return
            NetworkConfig({
                entryPoint: address(0x71BeB7064D6dA1E27278F3d17F0436E389D7E686),
                usdc: 0xAe045DE5638162fa134807Cb558E15A3F5A7F853, // Replace with actual USDC address on Sepolia if needed
                account: BURNER_WALLET
            });
    }
    function getZkSyncConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entryPoint: address(0), // supports native AA, so no entry point needed
                usdc: 0x1d17CBcF0D6D143135aE902365D2E5e2A16538D4,
                account: BURNER_WALLET
            });
    }
    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.account != address(0)) {
            return localNetworkConfig;
        }
        // deploy mocks
        console2.log("Deploying mocks...");

        vm.startBroadcast(ANVIL_DEFAULT_ACCOUNT);
        EntryPoint entryPoint = new EntryPoint();
        ERC20Mock erc20Mock = new ERC20Mock();
        vm.stopBroadcast();
        console2.log("Mocks deployed!");

        localNetworkConfig = NetworkConfig({
            entryPoint: address(entryPoint),
            usdc: address(erc20Mock),
            account: ANVIL_DEFAULT_ACCOUNT
        });
        return localNetworkConfig;
    }
}
