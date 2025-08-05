// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;
import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_SUCCESS, SIG_VALIDATION_FAILED} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

contract MinimalAccount is IAccount, Ownable {
    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/
    error MinimalAccount__NotFromEntryPoint();
    error MinimalAccount__NotFromEntryPointOrOwner();
    error MinimalAccount__CallFailed(bytes);
    IEntryPoint private immutable i_entryPoint;
    modifier requireFromEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert MinimalAccount__NotFromEntryPoint();
        }
        _;
    }
    modifier requireFromEntryPointOrOwner() {
        if (msg.sender != address(i_entryPoint) && msg.sender != owner()) {
            revert MinimalAccount__NotFromEntryPointOrOwner();
        }
        _;
    }
    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
    }
    receive() external payable {}
    /**
     * @notice Executes a call to a specified address with provided value and calldata.
     * @dev Can only be called by the EntryPoint contract or the account owner.
     *      Reverts with MinimalAccount__CallFailed if the call fails.
     * @param dest The destination address to call.
     * @param value The amount of Ether (in wei) to send with the call.
     * @param functionData The calldata to send to the destination address.
     */
    function execute(
        address dest,
        uint256 value,
        bytes calldata functionData
    ) external requireFromEntryPointOrOwner {
        // Perform the external call to the destination address with the specified value and calldata
        (bool success, bytes memory result) = dest.call{value: value}(
            functionData
        );
        // If the call fails, revert and return the error data
        if (!success) {
            revert MinimalAccount__CallFailed(result);
        }
    }
    // A signature is valid, if it's the MinimalAccount owner
    /**
     * @notice Validates a UserOperation by checking the signature and paying any required prefund.
     * @dev This function is called by the EntryPoint contract or the account owner to validate a UserOperation.
     *      It first validates the signature of the operation using the owner's address.
     *      Then, it pays any missing account funds required for the operation to proceed.
     *      Returns a validation data value indicating the result of the signature check.
     * @param userOp The packed user operation containing all relevant data, including the signature.
     * @param userOpHash The hash of the user operation, used for signature verification.
     * @param missingAccountFunds The amount of funds that need to be sent to the EntryPoint to cover the operation.
     * @return validationData A uint256 value indicating the result of the signature validation (success or failure).
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external requireFromEntryPointOrOwner returns (uint256 validationData) {
        // Validate the signature of the user operation.
        validationData = _validateSignature(userOp, userOpHash);

        // Pay any missing funds required for the operation.
        _payPrefund(missingAccountFunds);

        // Return the result of the signature validation.
        return validationData;
    }

    // EIP-191 version of the signed hash
    /**
     * @notice Validates the signature of a UserOperation.
     * @dev Recovers the signer address from the EIP-191 signed message hash of the userOpHash and compares it to the account owner.
     *      Returns SIG_VALIDATION_SUCCESS if the signature is valid, otherwise returns SIG_VALIDATION_FAILED.
     * @param userOp The packed user operation containing the signature to validate.
     * @param userOpHash The hash of the user operation (to be signed and verified).
     * @return validationData Returns SIG_VALIDATION_SUCCESS if the signature is valid, otherwise SIG_VALIDATION_FAILED.
     */
    function _validateSignature(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) internal view returns (uint256 validationData) {
        // Compute the EIP-191 Ethereum signed message hash from the user operation hash
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(
            userOpHash
        );
        // Recover the signer address from the signature and the signed message hash
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);
        // If the recovered signer is not the owner, return failure code
        if (signer != owner()) {
            return SIG_VALIDATION_FAILED;
        }
        // If the signature is valid, return success code
        return SIG_VALIDATION_SUCCESS;
    }

    /**
     * @notice Pays the EntryPoint any missing funds required for the user operation to proceed.
     * @dev If there are missing account funds, this function sends the specified amount of Ether
     *      to the caller (expected to be the EntryPoint) using a low-level call.
     *      The call is performed with the maximum possible gas and ignores the returned success value,
     *      as failure to pay should not revert the entire operation.
     * @param missingAccountFunds The amount of Ether that needs to be sent to the EntryPoint.
     */
    function _payPrefund(uint256 missingAccountFunds) internal {
        // Only attempt to pay if there are missing funds
        if (missingAccountFunds != 0) {
            // Send the missing funds to the EntryPoint (msg.sender)
            // Use a low-level call with maximum gas and ignore the success result
            (bool success, ) = payable(msg.sender).call{
                value: missingAccountFunds,
                gas: type(uint256).max
            }("");
            // Explicitly ignore the success value to suppress compiler warnings
            (success);
        }
    }
}
