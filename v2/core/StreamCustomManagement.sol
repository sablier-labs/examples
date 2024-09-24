// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { ud60x18 } from "@prb/math/src/UD60x18.sol";
import { ISablierV2LockupLinear } from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import { Broker, LockupLinear } from "@sablier/v2-core/src/types/DataTypes.sol";
import { ISablierLockupRecipient } from "@sablier/v2-core/src/interfaces/ISablierLockupRecipient.sol";

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title StreamCustomManagement
 * @notice This contract integrates with Sablier's V2 token streaming to create secure, efficient, and transparent
 * token streams, with the added benefit of enforcing custom business logic. It leverages the robust Sablier
 * streaming protocol while restricting access to the stream's management to this contract.
 *
 * By integrating Sablier's secure stream architecture, we ensure the tokens are streamed continuously and safely,
 * while utilizing custom restrictions for stream withdrawals. This flexibility allows us to build tailored access
 * controls for our userbase, ensuring streams can only be accessed under predefined conditions.
 *
 * Key benefits include:
 * - Custom withdrawal logic embedded into the contract, enabling precise control over when and how users can
 *   access streamed tokens.
 * - Secure integration with Sablier’s protocol ensures a highly reliable and transparent streaming mechanism
 *    with additional custom control over stream interactions.
 */
contract StreamCustomManagement is ISablierLockupRecipient {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    ISablierV2LockupLinear public immutable sablier;

    mapping(uint256 streamId => address recipient) internal _streamRecipients;

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

    /// @notice Creates a custom stream.
    /// Stream's recipient is set to this contract, so this contract will be the owner of the Sablier's ERC721 token.
    /// Stream is non-cancelable and non-transferable.
    /// @dev This function references the official Sablier V2 guide for stream creation:
    /// https://docs.sablier.com/contracts/v2/guides/create-airstream
    /// It sets up parameters to create a stream that cannot be canceled or transferred once deployed, except by this
    /// contract.
    /// @param recipient The address that will receive the stream's benefits.
    /// @param totalAmount The total amount of tokens to be streamed.
    /// @return streamId The unique ID of the created stream.
    function create(address recipient, uint128 totalAmount) external returns (uint256 streamId) {
        // Transfer the tokens from the sender to this contract, which will manage the streaming.
        token.transferFrom(msg.sender, address(this), totalAmount);

        // Grant the Sablier contract permission to spend the transferred tokens on behalf of this contract.
        token.approve(address(sablier), totalAmount);

        // Prepare the necessary parameters for creating the custom stream.
        LockupLinear.CreateWithDurations memory params;

        // This stream is configured to be non-cancelable.
        // This means that any attempts to cancel it using the following Sablier V2 functions will revert:
        // - cancel(uint256 streamId)
        // - cancelMultiple(uint256[] calldata streamIds)
        // - renounce(uint256 streamId)
        params.cancelable = false;

        // This stream is also set to be non-transferable.
        // This will make the execution of the internal override "_update" function of Sablier's ISablierV2Lockup
        // smart contract revert.
        //
        // Though, the "burn" function implementation will ignore the transferable flag.
        // The "burn" function will only be executed if the stream is depleted.
        //
        // Also, it will revert if the `msg.sender` is not the owner of the stream, which in our scenario, the owner of
        // the stream is this contract, which does not have the functionality to call the "burn" function.
        params.transferable = false;

        // Set this contract as the recipient.
        // This means the owner of each of the ERC721's that the SablierV2LockupLinear mints will be this contract.
        // The SablierV2LockupLinear's "withdraw" public function will revert if the caller is not this contract, thanks
        // to the "onSablierLockupWithdraw" hook implementation that restricts the caller of the "withdraw" public
        // function to this contract.
        params.recipient = address(this);

        params.totalAmount = totalAmount; // Total amount is the amount inclusive of all fees
        params.asset = token; // The streaming asset
        params.sender = address(this);
        params.durations = LockupLinear.Durations({
            cliff: 4 weeks, // Assets will be unlocked only after 4 weeks
            total: 52 weeks // Setting a total duration of ~1 year
         });
        params.broker = Broker(address(0), ud60x18(0)); // Optional parameter for charging a fee

        // Finally, create the stream with the specified parameters.
        streamId = sablier.createWithDurations(params);

        // Store the recipient of the stream according to this contract's logic.
        _streamRecipients[streamId] = recipient;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    02-WITHDRAW
    //////////////////////////////////////////////////////////////////////////*/

    // This function can have all the custom logic to allow the withdrawal of tokens from the stream.
    function withdraw(uint256 streamId, uint128 amount) external {
        // Obtain the recipient of the stream according to this contract's logic.
        address recipient = _streamRecipients[streamId];

        // Check if the caller is authorized to withdraw.
        if (!_isAllowedToWithdraw(recipient)) revert Unauthorized();

        // Withdraw the specified amount from the stream.
        sablier.withdraw({ streamId: streamId, to: address(this), amount: amount });

        // Forward the withdrawn tokens to the recipient. Not using `safeTransfer` to prevent re-entrancy issues.
        token.transfer(recipient, amount);

        // Get the remaining withdrawable amount of the stream.
        bool isDepleted = sablier.isDepleted(streamId);

        // If is depleted, burn the Sablier ERC721 token.
        // Since the owner of the Sablier ERC721 token is this contract, only this contract can burn its own tokens.
        if (isDepleted) sablier.burn(streamId);
    }

    // This function can have all the custom logic to allow the withdrawal of tokens from the stream.
    function withdrawMax(uint256 streamId) external {
        // Obtain the recipient of the stream according to this contract's logic.
        address recipient = _streamRecipients[streamId];

        // Check if the caller is authorized to withdraw.
        if (!_isAllowedToWithdraw(recipient)) revert Unauthorized();

        // Withdraw the maximum amount from the stream.
        uint128 amount = sablier.withdrawMax({ streamId: streamId, to: address(this) });

        // Forward the withdrawn tokens to the recipient. Not using `safeTransfer` to prevent re-entrancy issues.
        token.transfer(recipient, amount);

        // Burn the Sablier ERC721 token.
        sablier.burn(streamId);
    }

    /// @notice This function can have any custom logic to allow the withdrawal of tokens from the stream.
    function _isAllowedToWithdraw(address recipient) internal view returns (bool isAllowed) {
        // Example custom logic to allow only the recipient to withdraw from the stream.
        isAllowed = recipient == msg.sender;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    HOOKS
    //////////////////////////////////////////////////////////////////////////*/

    // {IERC165-supportsInterface} implementation as required by `ISablierLockupRecipient` interface.
    function supportsInterface(bytes4 interfaceId) public pure override(IERC165) returns (bool) {
        return interfaceId == 0xf8ee98d3;
    }

    /// @notice Hook executed during the "withdraw" function of the SablierV2LockupLinear smart contract.
    /// This hook is triggered when the "withdraw" function passes all necessary checks, and lastly when the condition
    /// `msg.sender != recipient && _allowedToHook[recipient]` is met.
    ///
    /// In this example, the recipient is set to this contract. Therefore, any attempt by an address other than this
    /// contract to call the SablierV2LockupLinear "withdraw" function, aiming to withdraw tokens from streams
    /// where this contract is the recipient, will result in this hook being executed.
    ///
    /// @dev The "onSablierLockupWithdraw" hook function reverts if:
    /// - The caller is not the SablierV2LockupLinear smart contract.
    /// - The caller is not this contract itself, which will cause the "withdraw" function to revert.
    ///
    /// This ensures that any external actor, apart from this contract, attempting to call the "withdraw" function
    /// and modify the withdrawal state or logic of this contract's stream will be blocked, preventing unauthorized
    /// actions.
    ///
    /// @param caller The address that called the "withdraw" public function
    function onSablierLockupWithdraw(
        uint256, /* streamId */
        address caller,
        address, /* to */
        uint128 /* amount */
    )
        external
        view
        returns (bytes4 selector)
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

    /// @notice Hook triggered during the "cancel" function of the SablierV2LockupLinear smart contract.
    /// @dev This hook will never be executed as the stream is set to be non-cancelable.
    /// However, if custom logic is required to manage stream cancellations, allowing cancellations only through
    /// this contract, this hook can be implemented with a similar approach to the "onSablierLockupWithdraw" hook.
    function onSablierLockupCancel(
        uint256, /* streamId */
        address sender,
        uint128, /* senderAmount */
        uint128 /* recipientAmount */
    )
        external
        view
        returns (bytes4 selector)
    {
        // Check: the caller is the lockup contract.
        if (msg.sender != address(sablier)) {
            revert CallerNotSablierContract(msg.sender, address(sablier));
        }

        // Check: this condition will make revert possible calls to Sablier's SablierV2LockupLinear smart contract
        // "cancel" public function from any address except this contract.
        if (sender != address(this)) revert CallerNotThisContract();

        return ISablierLockupRecipient.onSablierLockupCancel.selector;
    }
}
