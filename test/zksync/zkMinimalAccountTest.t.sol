// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;
import {Test} from "lib/forge-std/src/Test.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {DeployMinimal} from "script/DeployMinimal.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp, PackedUserOperation, IEntryPoint} from "script/SendPackedUserOp.s.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {ZkSyncChainChecker} from "lib/foundry-devops/src/ZkSyncChainChecker.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {MinimalAccountZK} from "src/zksync/MinimalAccountZK.sol";
import {Transaction} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
contract ZKMinimalAccountTest is Test, ZkSyncChainChecker {
    using MessageHashUtils for bytes32;
    MinimalAccountZK minimalAccount;
    ERC20Mock usdc;
    bytes4 constant EIP1271_SUCCESS_RETURN_VALUE = 0x1626ba7e;

    uint256 constant AMOUNT = 1e18;
    bytes32 constant EMPTY_BYTES32 = bytes32(0);
    address constant ANVIL_DEFAULT_ACCOUNT =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    function setUp() public {
        minimalAccount = new MinimalAccountZK();
        minimalAccount.transferOwnership(ANVIL_DEFAULT_ACCOUNT);
        usdc = new ERC20Mock();
        vm.deal(address(minimalAccount), AMOUNT);
    }
    function testZkOwnerCanExecuteCommands() public {
        // Arrange
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(minimalAccount),
            AMOUNT
        );

        Transaction memory transaction = _createUnsignedTransaction(
            minimalAccount.owner(),
            113,
            dest,
            value,
            functionData
        );

        // Act
        vm.prank(minimalAccount.owner());
        minimalAccount.executeTransaction(
            EMPTY_BYTES32,
            EMPTY_BYTES32,
            transaction
        );

        // Assert
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }
    // You'll also need --system-mode=true to run this test
    function testZkValidateTransaction() public onlyZkSync {
        // Arrange
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(minimalAccount),
            AMOUNT
        );
        Transaction memory transaction = _createUnsignedTransaction(
            minimalAccount.owner(),
            113,
            dest,
            value,
            functionData
        );
        transaction = _signTransaction(transaction);

        // Act
        vm.prank(BOOTLOADER_FORMAL_ADDRESS);
        bytes4 magic = minimalAccount.validateTransaction(
            EMPTY_BYTES32,
            EMPTY_BYTES32,
            transaction
        );

        // Assert
        assertEq(magic, ACCOUNT_VALIDATION_SUCCESS_MAGIC);
    }
    /*//////////////////////////////////////////////////////////////
                        HELPERS
//////////////////////////////////////////////////////////////*/
    function _signTransaction(
        Transaction memory transaction
    ) internal view returns (Transaction memory) {
        bytes32 unsignedTransactionHash = MemoryTransactionHelper.encodeHash(
            transaction
        );
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, unsignedTransactionHash);
        Transaction memory signedTransaction = transaction;
        signedTransaction.signature = abi.encodePacked(r, s, v);
        return signedTransaction;
    }
    /**
     * @notice Creates an unsigned zkSync Transaction struct for testing purposes.
     * @dev This helper function constructs a Transaction struct with the provided parameters and default values for other fields.
     *      The nonce is fetched from the minimalAccount contract. The signature is left empty.
     * @param from The address initiating the transaction.
     * @param transactionType The type of the transaction (e.g., 0x71 for EIP-712).
     * @param to The recipient address of the transaction.
     * @param value The amount of ETH (or token) to send with the transaction.
     * @param data The calldata to be sent with the transaction.
     * @return txn The constructed Transaction struct, ready to be signed or used in tests.
     */
    function _createUnsignedTransaction(
        address from,
        uint8 transactionType,
        address to,
        uint256 value,
        bytes memory data
    ) internal view returns (Transaction memory txn) {
        // Fetch the current nonce for the minimalAccount contract
        uint256 nonce = vm.getNonce(address(minimalAccount));
        // Initialize an empty array for factory dependencies
        bytes32[] memory factoryDeps = new bytes32[](0);

        // Construct and return the Transaction struct
        return
            Transaction({
                txType: transactionType, // Transaction type (e.g., 0x71 for EIP-712)
                from: uint256(uint160(from)), // Convert address to uint256
                to: uint256(uint160(to)), // Convert address to uint256
                gasLimit: 16777216, // Set a high gas limit for testing
                gasPerPubdataByteLimit: 16777216, // Set a high pubdata gas limit
                maxFeePerGas: 16777216, // Set a high max fee per gas
                maxPriorityFeePerGas: 16777216, // Set a high priority fee per gas
                paymaster: 0, // No paymaster by default
                nonce: nonce, // Use the current nonce
                value: value, // Amount to send
                reserved: [uint256(0), uint256(0), uint256(0), uint256(0)], // Reserved fields set to zero
                data: data, // Calldata for the transaction
                signature: hex"", // Empty signature (unsigned)
                factoryDeps: factoryDeps, // No factory dependencies
                paymasterInput: hex"", // No paymaster input
                reservedDynamic: hex"" // Reserved dynamic field set to empty
            });
    }
}
