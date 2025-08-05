// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;
import {IAccount, ACCOUNT_VALIDATION_SUCCESS_MAGIC} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";

import {Transaction, MemoryTransactionHelper} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {SystemContractsCaller} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/SystemContractsCaller.sol";
import {NONCE_HOLDER_SYSTEM_CONTRACT, BOOTLOADER_FORMAL_ADDRESS, DEPLOYER_SYSTEM_CONTRACT} from "lib/foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
import {INonceHolder} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/INonceHolder.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {Utils} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/Utils.sol";
contract ZKMinimalAccount is IAccount, Ownable {
    using MemoryTransactionHelper for Transaction;

    error ZkMinimalAccount__NotEnoughBalance();
    error ZkMinimalAccount__NotFromBootLoader();
    error ZkMinimalAccount__ExecutionFailed();
    error ZkMinimalAccount__NotFromBootLoaderOrOwner();
    error ZkMinimalAccount__FailedToPay();
    error ZkMinimalAccount__InvalidSignature();
    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier requireFromBootLoader() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
            revert ZkMinimalAccount__NotFromBootLoader();
        }
        _;
    }

    modifier requireFromBootLoaderOrOwner() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS && msg.sender != owner()) {
            revert ZkMinimalAccount__NotFromBootLoaderOrOwner();
        }
        _;
    }
    constructor() Ownable(msg.sender) {}

    receive() external payable {}
    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice must increase the nonce
     * @notice must validate the transaction (chech the owner signed the transaction)
     * @notice also check to see if we have enough money in our account
     */
    function validateTransaction(
        bytes32 /*_txHash*/,
        bytes32 /*_suggestedSignedHash*/,
        Transaction calldata _transaction
    ) external payable requireFromBootLoader returns (bytes4 magic) {
        _validateTransaction(_transaction);
    }

    function executeTransaction(
        bytes32 /*_txHash*/,
        bytes32 /*_suggestedSignedHash*/,
        Transaction calldata _transaction
    ) external payable requireFromBootLoaderOrOwner {
        _executeTransaction(_transaction);
    }

    // There is no point in providing possible signed hash in the `executeTransactionFromOutside` method,
    // since it typically should not be trusted.
    /**
     * @notice Executes a transaction from an external caller after validating the signature.
     * @dev Validates the transaction signature and executes the transaction if valid.
     *      Reverts if the signature is invalid.
     * @param _transaction The transaction data to be executed.
     */
    function executeTransactionFromOutside(
        Transaction calldata _transaction // The transaction data to execute
    ) external payable {
        bytes4 magic = _validateTransaction(_transaction); // Validate the transaction and get the magic value
        if (magic != ACCOUNT_VALIDATION_SUCCESS_MAGIC) {
            // Check if the validation was successful
            revert ZkMinimalAccount__InvalidSignature(); // Revert if the signature is invalid
        }
        _executeTransaction(_transaction); // Execute the transaction if validation passed
    }

    /**
     * @notice Pays the required transaction fee to the bootloader.
     * @dev This function is called by the bootloader to transfer the necessary fee for processing the transaction.
     *      It attempts to pay the fee using the `payToTheBootloader` method of the Transaction struct.
     *      If the payment fails, the function reverts with a custom error.
     * @param _txHash The hash of the transaction (for explorer and tracking purposes).
     * @param _suggestedSignedHash The hash that may be signed by EOAs (not used in this implementation).
     * @param _transaction The transaction data containing payment and execution details.
     */
    function payForTransaction(
        bytes32 /*_txHash*/,
        bytes32 /*_suggestedSignedHash*/,
        Transaction calldata _transaction
    ) external payable {
        // Attempt to pay the bootloader for transaction processing
        bool success = _transaction.payToTheBootloader();
        // If payment fails, revert with a custom error
        if (!success) {
            revert ZkMinimalAccount__FailedToPay();
        }
    }

    /**
     * @notice Prepares the account for paymaster interaction by attempting to pay the bootloader.
     * @dev This function is called to process payment to the bootloader, typically in the context of paymaster flows.
     *      It uses the `payToTheBootloader` method of the Transaction struct to attempt the payment.
     *      If the payment fails, it reverts with a custom error.
     * @param _txHash The hash of the transaction (for explorer and tracking purposes).
     * @param _possibleSignedHash The hash that may be signed by EOAs (not used in this implementation).
     * @param _transaction The transaction data containing payment and execution details.
     */
    function prepareForPaymaster(
        bytes32 /*_txHash*/,
        bytes32 /*_suggestedSignedHash*/, // The hash that may be signed by EOAs (not used here)
        Transaction calldata _transaction // The transaction data
    ) external payable {
        bool success = _transaction.payToTheBootloader(); // Attempt to pay the bootloader for transaction processing
        if (!success) {
            // If payment fails
            revert ZkMinimalAccount__FailedToPay(); // Revert with a custom error
        }
    }
    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _validateTransaction(
        Transaction memory _transaction
    ) internal returns (bytes4 magic) {
        // Call nonceholder
        // increment nonce
        // call(x, y, z) -> system contract call
        SystemContractsCaller.systemCallWithPropagatedRevert(
            uint32(gasleft()),
            address(NONCE_HOLDER_SYSTEM_CONTRACT),
            0,
            abi.encodeCall(
                INonceHolder.incrementMinNonceIfEquals,
                (_transaction.nonce)
            )
        );

        // Check for fee to pay
        uint256 totalRequiredBalance = _transaction.totalRequiredBalance();
        if (totalRequiredBalance > address(this).balance) {
            revert ZkMinimalAccount__NotEnoughBalance();
        }

        // Check the signature
        bytes32 txHash = _transaction.encodeHash();
        // bytes32 convertedHash = MessageHashUtils.toEthSignedMessageHash(txHash);
        address signer = ECDSA.recover(txHash, _transaction.signature);
        bool isValidSigner = signer == owner();
        if (isValidSigner) {
            magic = ACCOUNT_VALIDATION_SUCCESS_MAGIC;
        } else {
            magic = bytes4(0);
        }
        return magic;
    }
    /**
     * @notice Executes a transaction, either as a system contract call or a regular call.
     * @dev Handles both system contract calls (with propagated revert) and regular contract calls.
     *      Reverts if the call fails.
     * @param _transaction The transaction to execute.
     */
    function _executeTransaction(Transaction memory _transaction) internal {
        address to = address(uint160(_transaction.to)); // Convert the transaction's 'to' field to an address
        uint128 value = Utils.safeCastToU128(_transaction.value); // Safely cast the transaction value to uint128
        bytes memory data = _transaction.data; // Get the calldata for the transaction

        if (to == address(DEPLOYER_SYSTEM_CONTRACT)) {
            // Check if the destination is the deployer system contract
            uint32 gas = Utils.safeCastToU32(gasleft()); // Safely cast the remaining gas to uint32
            SystemContractsCaller.systemCallWithPropagatedRevert(
                gas, // Amount of gas to forward
                to, // Destination address
                value, // Amount of value to send
                data // Calldata to send
            ); // Perform the system contract call with revert propagation
        } else {
            bool success; // Variable to store the result of the call
            assembly {
                success := call(
                    gas(), // Forward all available gas
                    to, // Destination address
                    value, // Amount of value to send
                    add(data, 0x20), // Pointer to calldata (skip the length prefix)
                    mload(data), // Length of calldata
                    0, // Output location (none)
                    0 // Output size (none)
                )
            }
            if (!success) {
                // If the call failed
                revert ZkMinimalAccount__ExecutionFailed(); // Revert with a custom error
            }
        }
    }
}
