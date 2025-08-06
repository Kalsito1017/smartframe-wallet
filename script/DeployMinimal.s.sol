// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;
import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Script} from "lib/forge-std/src/Script.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
contract DeployMinimal is Script {
    function run() public {}
    /**
     * @notice Deploys a new MinimalAccount contract and sets its owner.
     * @dev
     *  - Instantiates a new HelperConfig to fetch network configuration.
     *  - Broadcasts the deployment transaction from the configured account.
     *  - Deploys the MinimalAccount contract using the entryPoint address from config.
     *  - Transfers ownership of the deployed MinimalAccount to the configured account.
     *  - Stops broadcasting and returns the HelperConfig and deployed MinimalAccount.
     * @return helperConfig The HelperConfig instance used for deployment.
     * @return minimalAccount The deployed MinimalAccount contract instance.
     */
    function deployMinimalAccount()
        public
        returns (HelperConfig helperConfig, MinimalAccount minimalAccount)
    {
        // Create a new HelperConfig instance to access network configuration
        helperConfig = new HelperConfig();

        // Retrieve the network configuration (entryPoint, account, etc.)
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        // Start broadcasting transactions as the configured account
        vm.startBroadcast(config.account);

        // Deploy the MinimalAccount contract with the specified entryPoint address
        minimalAccount = new MinimalAccount(config.entryPoint);

        // Transfer ownership of the MinimalAccount to the configured account
        minimalAccount.transferOwnership(config.account);

        // Stop broadcasting transactions
        vm.stopBroadcast();

        // Return the HelperConfig and deployed MinimalAccount contract
        return (helperConfig, minimalAccount);
    }
}
