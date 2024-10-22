// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { ud60x18 } from "@prb/math/src/UD60x18.sol";
import { ISablierLockupRecipient } from "@sablier/v2-core/src/interfaces/ISablierLockupRecipient.sol";
import { ISablierV2LockupLinear } from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import { Broker, LockupLinear } from "@sablier/v2-core/src/types/DataTypes.sol";

/// @notice Example of creating Sablier streams and managing them on behalf of users with some withdrawal restrictions
/// powered by Sablier hooks.
/// @dev To read more about the hooks, visit https://docs.sablier.com/concepts/protocol/hooks.
contract StreamManagementWithHook is ISablierLockupRecipient {
    using SafeERC20 for IERC20;

    error CallerNotSablierContract(address caller, address sablierLockup);
    error CallerNotThisContract();
    error Unauthorized();

    ISablierV2LockupLinear public immutable SABLIER;
    IERC20 public immutable TOKEN;

    /// @dev Stream IDs mapped to their beneficiaries.
    mapping(uint256 streamId => address beneficiary) public streamBeneficiaries;

    /// @dev This modifier will restrict the function to be called only by the stream beneficiary.
    modifier onlyStreamBeneficiary(uint256 streamId) {
        if (msg.sender != streamBeneficiaries[streamId]) {
            revert Unauthorized();
        }

        _;
    }

    /// @dev Constructor will set the address of the lockup contract and ERC20 token.
    constructor(ISablierV2LockupLinear sablier_, IERC20 token_) {
        SABLIER = sablier_;
        TOKEN = token_;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                       CREATE
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Creates a non-cancelable, non-transferable stream on behalf of `beneficiary`.
    /// @dev The stream recipient is set to `this` contract to have control over "withdraw" from streams. Actual
    /// recipient is managed via `streamBeneficiaries` mapping.
    /// @param beneficiary The ultimate recipient of the stream's token.
    /// @param totalAmount The total amount of tokens to be streamed.
    /// @return streamId The stream Id.
    function create(address beneficiary, uint128 totalAmount) external returns (uint256 streamId) {
        // Check: verify that this contract is allowed to hook into Sablier Lockup.
        if (!SABLIER.isAllowedToHook(address(this))) {
            revert Unauthorized();
        }

        // Transfer tokens to this contract and approve Sablier to spend them.
        TOKEN.transferFrom(msg.sender, address(this), totalAmount);
        TOKEN.approve(address(SABLIER), totalAmount);

        LockupLinear.CreateWithDurations memory params;
        params.transferable = false;
        params.cancelable = true;
        // Set `this` as the recipient of the Stream. Only `this` will be able to call the "withdraw" function.
        params.recipient = address(this);
        // Set `this` as the sender of the Stream. Only `this` will be able to call the "cancel" function
        params.sender = address(this);
        params.totalAmount = totalAmount;
        params.asset = TOKEN;
        params.durations = LockupLinear.Durations({
            cliff: 4 weeks, // Assets unlocked after 4 weeks
            total: 52 weeks // Total duration of 1 year
         });
        params.broker = Broker(address(0), ud60x18(0)); // No broker fee

        // Create the stream.
        streamId = SABLIER.createWithDurations(params);

        // Set the `beneficiary` .
        streamBeneficiaries[streamId] = beneficiary;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     WITHDRAW
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev This function can only be called by the stream beneficiary.
    function withdraw(uint256 streamId, uint128 amount) external onlyStreamBeneficiary(streamId) {
        // Withdraw the specified amount from the stream to the stream beneficiary.
        SABLIER.withdraw({ streamId: streamId, to: streamBeneficiaries[streamId], amount: amount });
    }

    /// @dev This function can only be called by the stream beneficiary.
    function withdrawMax(uint256 streamId) external onlyStreamBeneficiary(streamId) {
        // Withdraw the maximum amount from the stream to the stream beneficiary.
        SABLIER.withdrawMax({ streamId: streamId, to: streamBeneficiaries[streamId] });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                       HOOKS
    //////////////////////////////////////////////////////////////////////////*/

    // {IERC165-supportsInterface} implementation as required by `ISablierLockupRecipient` interface.
    function supportsInterface(bytes4 interfaceId) public pure override(IERC165) returns (bool) {
        return interfaceId == 0xf8ee98d3;
    }

    /// @notice This will be called by `SABLIER` contract everytime withdraw is called on a stream.
    /// @dev Reverts if the `msg.sender` is not `this` contract, preventing anyone else from calling the publicly
    /// callable "withdraw" function.
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
        // Check: the `msg.sender` is the lockup contract.
        if (msg.sender != address(SABLIER)) {
            revert CallerNotSablierContract(msg.sender, address(SABLIER));
        }

        // Check: the `msg.sender` to the `SABLIER` contract is `this` contract.
        if (caller != address(this)) {
            revert CallerNotThisContract();
        }

        return ISablierLockupRecipient.onSablierLockupWithdraw.selector;
    }

    /// @notice This will be called by `SABLIER` contract when cancel is called on a stream.
    /// @dev Since only the stream sender, which is `this` contract, can cancel the stream, this function does not
    /// require a check similar to `onSablierLockupWithdraw`.
    function onSablierLockupCancel(
        uint256, /* streamId */
        address, /* sender */
        uint128, /* senderAmount */
        uint128 /* recipientAmount */
    )
        external
        view
        returns (bytes4 selector)
    {
        // Check: the `msg.sender` is the lockup contract.
        if (msg.sender != address(SABLIER)) {
            revert CallerNotSablierContract(msg.sender, address(SABLIER));
        }

        return ISablierLockupRecipient.onSablierLockupCancel.selector;
    }
}
