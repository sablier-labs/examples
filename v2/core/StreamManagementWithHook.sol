// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { ud60x18 } from "@prb/math/src/UD60x18.sol";
import { ISablierV2LockupLinear } from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import { Broker, LockupLinear } from "@sablier/v2-core/src/types/DataTypes.sol";
import { ISablierLockupRecipient } from "@sablier/v2-core/src/interfaces/ISablierLockupRecipient.sol";

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Example of creating and managing Sablier streams with custom restrictions using hooks.
contract StreamManagementWithHook is ISablierLockupRecipient {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    ISablierV2LockupLinear public immutable sablier;

    mapping(uint256 => address) internal _streamRecipients;

    error Unauthorized();
    error CallerNotThisContract();
    error CallerNotSablierContract(address caller, address sablierLockup);

    constructor(ISablierV2LockupLinear sablier_, IERC20 token_) {
        sablier = sablier_;
        token = token_;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    01-CREATE
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Creates a non-cancelable, non-transferable stream with custom recipient.
    /// @dev The stream recipient is this contract; actual recipient is managed via mapping.
    /// @param recipient The address that will receive the stream's benefits.
    /// @param totalAmount The total amount of tokens to be streamed.
    /// @return streamId The unique ID of the created stream.
    function create(address recipient, uint128 totalAmount) external returns (uint256 streamId) {
        // Security check: Verify that this contract is allowed to be hook'd by Sablier's SablierV2LockupLinear.
        // This will make sure that no one else can alter the withdrawal state or logic of this contract's stream.
        if (!sablier.isAllowedToHook(address(this))) revert Unauthorized();

        token.transferFrom(msg.sender, address(this), totalAmount);
        token.approve(address(sablier), totalAmount);

        LockupLinear.CreateWithDurations memory params;
        params.transferable = false; // Not transferable
        params.cancelable = true; // Cancelable
        params.recipient = address(this); // This will be the address owning the NFT from SablierV2Lockup contract.
        params.sender = address(this); // This is the only address that can call the "cancel" function.
        params.totalAmount = totalAmount;
        params.asset = token;
        params.durations = LockupLinear.Durations({
            cliff: 4 weeks, // Assets unlocked after 4 weeks
            total: 52 weeks // Total duration of 1 year
         });
        params.broker = Broker(address(0), ud60x18(0)); // No broker fee

        // Create the stream with the specified parameters.
        streamId = sablier.createWithDurations(params);

        // Store the recipient of the stream according to this contract's logic.
        _streamRecipients[streamId] = recipient;

        // Add more custom logic here
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    02-WITHDRAW
    //////////////////////////////////////////////////////////////////////////*/

    // This function can be called by the allowed recipient
    function withdraw(uint256 streamId, uint128 amount) external {
        address recipient = _streamRecipients[streamId];

        _customRestrictionsSucceeded(recipient);

        // Withdraw the specified amount from the stream. To the allowed recipient.
        sablier.withdraw({ streamId: streamId, to: recipient, amount: amount });

        // If the stream is depleted, burn the stream.
        if (sablier.isDepleted(streamId)) sablier.burn(streamId);
    }

    // This function can be called by the allowed recipient
    function withdrawMax(uint256 streamId) external {
        address recipient = _streamRecipients[streamId];

        if (recipient != msg.sender) revert Unauthorized();

        _customRestrictionsSucceeded(recipient);

        // Withdraw the maximum amount from the stream. To the allowed recipient.
        sablier.withdrawMax({ streamId: streamId, to: recipient });

        // If the stream is depleted, burn the stream.
        if (sablier.isDepleted(streamId)) sablier.burn(streamId);
    }

    // This function allows to add custom restrictions to withdrawals
    function _customRestrictionsSucceeded(address recipient) internal view returns (bool) {
        // Add custom restrictions to withdrawals here

        if (recipient != msg.sender) revert Unauthorized();

        return true;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     03-CANCEL
    //////////////////////////////////////////////////////////////////////////*/

    // This function can be called by either the sender or the recipient
    function cancel(uint256 streamId) external {
        // Can add custom logic here

        // Cancel the stream
        sablier.cancel(streamId);
    }

    // This function can be called only by the sender
    function cancelMultiple(uint256[] calldata streamIds) external {
        // Can add custom logic here

        // Cancel the streams
        sablier.cancelMultiple(streamIds);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    04-RENOUNCE
    //////////////////////////////////////////////////////////////////////////*/

    // This function can be called only by the sender
    function renounce(uint256 streamId) external {
        // Can add custom logic here

        // Renounce the stream
        sablier.renounce(streamId);
    }

    /*//////////////////////////////////////////////////////////////////////////
                               HOOKS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public pure override(IERC165) returns (bool) {
        return interfaceId == 0xf8ee98d3;
    }

    /// @notice Hook executed during SablierV2LockupLinear 'withdraw' function.
    ///
    /// @dev Reverts withdrawals from Sablier contracts if the caller is not this contract, preventing unauthorized
    /// withdrawals to this contract that might alter the intended flow of the stream.
    function onSablierLockupWithdraw(
        uint256, /* streamId */
        address caller,
        address, /* to */
        uint128 /* amount */
    )
        external
        view
        returns (bytes4)
    {
        // Check: the caller is the lockup contract.
        if (msg.sender != address(sablier)) {
            revert CallerNotSablierContract(msg.sender, address(sablier));
        }

        // Check: this condition will make revert possible calls to Sablier's SablierV2LockupLinear smart contract
        // "withdraw" public function from any address except this contract.
        if (caller != address(this)) revert CallerNotThisContract();

        return ISablierLockupRecipient.onSablierLockupWithdraw.selector;
    }

    /// @notice Hook executed during SablierV2LockupLinear 'cancel' function.
    ///
    /// @dev This hook doesn't work like the withdrawal hook, since the the cancel function in SablierV2Lockup contract
    /// is strictly restricted to be called by the `params.sender` address in the stream creation function. So, no need to 
    /// do the same as the above webhook logic.
    function onSablierLockupCancel(
        uint256, /* streamId */
        address sender,
        uint128, /* senderAmount */
        uint128 /* recipientAmount */
    )
        external
        view
        returns (bytes4)
    {
        // Check: the caller is the lockup contract.
        if (msg.sender != address(sablier)) {
            revert CallerNotSablierContract(msg.sender, address(sablier));
        }

        // Custom logic here

        return ISablierLockupRecipient.onSablierLockupCancel.selector;
    }
}
