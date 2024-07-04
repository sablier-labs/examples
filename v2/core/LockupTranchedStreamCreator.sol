// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ud60x18 } from "@prb/math/src/UD60x18.sol";
import { ISablierV2LockupTranched } from "@sablier/v2-core/src/interfaces/ISablierV2LockupTranched.sol";
import { Broker, LockupTranched } from "@sablier/v2-core/src/types/DataTypes.sol";

/// @notice Example of how to create a Lockup Tranched stream.
/// @dev This code is referenced in the docs: https://docs.sablier.com/contracts/v2/guides/create-stream/lockup-tranched
contract LockupTranchedStreamCreator {
    // sepolia addresses
    IERC20 public constant DAI = IERC20(0x68194a729C2450ad26072b3D33ADaCbcef39D574);
    ISablierV2LockupTranched public constant LOCKUP_TRANCHED =
        ISablierV2LockupTranched(0x7CC7e125d83A581ff438608490Cc0f7bDff79127);

    /// @dev For this function to work, the sender must have approved this dummy contract to spend DAI.
    function createStream(uint128 amount0, uint128 amount1) public returns (uint256 streamId) {
        // Sum the segment amounts
        uint256 totalAmount = amount0 + amount1;

        // Transfer the provided amount of DAI tokens to this contract
        DAI.transferFrom(msg.sender, address(this), totalAmount);

        // Approve the Sablier contract to spend DAI
        DAI.approve(address(LOCKUP_TRANCHED), totalAmount);

        // Declare the params struct
        LockupTranched.CreateWithDurations memory params;

        // Declare the function parameters
        params.sender = msg.sender; // The sender will be able to cancel the stream
        params.recipient = address(0xCAFE); // The recipient of the streamed assets
        params.totalAmount = uint128(totalAmount); // Total amount is the amount inclusive of all fees
        params.asset = DAI; // The streaming asset
        params.cancelable = true; // Whether the stream will be cancelable or not
        params.transferable = true; // Whether the stream will be transferable or not

        // Declare some dummy tranches
        params.tranches = new LockupTranched.TrancheWithDuration[](2);
        params.tranches[0] = LockupTranched.TrancheWithDuration({ amount: amount0, duration: uint40(4 weeks) });
        params.tranches[1] = (LockupTranched.TrancheWithDuration({ amount: amount1, duration: uint40(6 weeks) }));

        params.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Create the LockupTranched stream
        streamId = LOCKUP_TRANCHED.createWithDurations(params);
    }
}
