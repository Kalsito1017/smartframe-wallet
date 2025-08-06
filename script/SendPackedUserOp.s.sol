// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Script} from "lib/forge-std/src/Script.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;
    // Make sure you trust this user - don't run this on Mainnet!
    address constant RANDOM_APPROVER = "YOUR APPROVER WALLET"; //YOUR APPROVER WALLET ADDRESS
    function run() public {
        // Setup
        HelperConfig helperConfig = new HelperConfig();
        address dest = helperConfig.getConfig().usdc; // arbitrum mainnet USDC address
        uint256 value = 0;
        address minimalAccountAddress = DevOpsTools.get_most_recent_deployment(
            "MinimalAccount",
            block.chainid
        );

        bytes memory functionData = abi.encodeWithSelector(
            IERC20.approve.selector,
            RANDOM_APPROVER,
            1e18
        );
        bytes memory executeCalldata = abi.encodeWithSelector(
            MinimalAccount.execute.selector,
            dest,
            value,
            functionData
        );
        PackedUserOperation memory userOp = generateSignedUserOperation(
            executeCalldata,
            helperConfig.getConfig(),
            minimalAccountAddress
        );
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        // Send transaction
        vm.startBroadcast();
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(
            ops,
            payable(helperConfig.getConfig().account)
        );
        vm.stopBroadcast();
    }
    /**
     * @notice Generates a signed PackedUserOperation for use with EntryPoint.
     * @dev
     *  - Generates an unsigned user operation for the given calldata and account.
     *  - Computes the user operation hash as per EntryPoint.
     *  - Signs the hash using the appropriate private key (Anvil default or configured account).
     *  - Packs the signature into the user operation struct.
     * @param callData The calldata to be executed by the account.
     * @param config The HelperConfig.NetworkConfig containing network and account configuration.
     * @param minimalAccount The address of the MinimalAccount contract (sender).
     * @return The signed PackedUserOperation struct ready to be sent to EntryPoint.
     */
    function generateSignedUserOperation(
        bytes memory callData,
        HelperConfig.NetworkConfig memory config,
        address minimalAccount
    ) public view returns (PackedUserOperation memory) {
        // 1. Generate the unsigned user operation with the correct nonce.
        //    vm.getNonce returns the next nonce, so subtract 1 to get the current.
        uint256 nonce = vm.getNonce(minimalAccount) - 1;
        PackedUserOperation memory userOp = _generateUnsignedUserOperation(
            callData,
            minimalAccount,
            nonce
        );

        // 2. Compute the user operation hash as required by EntryPoint.
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(
            userOp
        );

        // 3. Convert the hash to an Ethereum signed message hash (EIP-191).
        bytes32 digest = userOpHash.toEthSignedMessageHash();

        // 4. Sign the digest using the appropriate private key.
        //    Use the Anvil default key for local testing (chainid 31337), otherwise use the configured account.
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        if (block.chainid == 31337) {
            // Local Anvil: sign with the default private key.
            (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
        } else {
            // Other networks: sign with the configured account's private key.
            (v, r, s) = vm.sign(config.account, digest);
        }

        // 5. Pack the signature as (r, s, v) and assign to the user operation.
        userOp.signature = abi.encodePacked(r, s, v); // Note: order is r, s, v

        // 6. Return the fully signed user operation.
        return userOp;
    }
    /**
     * @notice Generates an unsigned PackedUserOperation struct for use with EntryPoint.
     * @dev This function sets up a user operation with default gas and fee values, and empty signature.
     *      The returned struct can be signed and sent to EntryPoint for execution.
     * @param callData The calldata to be executed by the account.
     * @param sender The address of the account sending the operation.
     * @param nonce The nonce for the operation (should be current account nonce).
     * @return userOp The unsigned PackedUserOperation struct.
     */
    function _generateUnsignedUserOperation(
        bytes memory callData,
        address sender,
        uint256 nonce
    ) internal pure returns (PackedUserOperation memory userOp) {
        // Set a high verification gas limit for safety (16,777,216)
        uint128 verificationGasLimit = 16_777_216;
        // Use the same value for call gas limit for simplicity
        uint128 callGasLimit = verificationGasLimit;
        // Set a low max priority fee per gas (256 wei)
        uint128 maxPriorityFeePerGas = 256;
        // Set max fee per gas equal to max priority fee per gas
        uint128 maxFeePerGas = maxPriorityFeePerGas;

        // Construct the PackedUserOperation struct
        userOp = PackedUserOperation({
            sender: sender, // The account address
            nonce: nonce, // The account nonce
            initCode: hex"", // No initCode for existing accounts
            callData: callData, // The calldata to execute
            // Pack verificationGasLimit and callGasLimit into a single bytes32
            accountGasLimits: bytes32(
                (uint256(verificationGasLimit) << 128) | callGasLimit
            ),
            preVerificationGas: verificationGasLimit, // Use verificationGasLimit as preVerificationGas
            // Pack maxPriorityFeePerGas and maxFeePerGas into a single bytes32
            gasFees: bytes32(
                (uint256(maxPriorityFeePerGas) << 128) | maxFeePerGas
            ),
            paymasterAndData: hex"", // No paymaster
            signature: hex"" // Empty signature (to be filled in later)
        });
    }
}
