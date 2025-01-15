// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ud60x18 } from "@prb/math/src/UD60x18.sol";
import { ISablierLockup } from "@sablier/lockup/src/interfaces/ISablierLockup.sol";
import { Broker, Lockup, LockupLinear } from "@sablier/lockup/src/types/DataTypes.sol";

/// @notice Example of how to create a Lockup Linear stream.
/// @dev This code is referenced in the docs: https://docs.sablier.com/contracts/v2/guides/create-stream/lockup-linear
contract LockupLinearStreamCreator {
    // sepolia addresses
    IERC20 public constant DAI = IERC20(0x68194a729C2450ad26072b3D33ADaCbcef39D574);
    ISablierLockup public constant LOCKUP = ISablierLockup(0xC2Da366fD67423b500cDF4712BdB41d0995b0794);

    /// @dev For this function to work, the sender must have approved this dummy contract to spend DAI.
    function createStream(uint128 totalAmount) public returns (uint256 streamId) {
        // Transfer the provided amount of DAI tokens to this contract
        DAI.transferFrom(msg.sender, address(this), totalAmount);

        // Approve the Sablier contract to spend DAI
        DAI.approve(address(LOCKUP), totalAmount);

        // Declare the params struct
        Lockup.CreateWithDurations memory params;

        // Declare the function parameters
        params.sender = msg.sender; // The sender will be able to cancel the stream
        params.recipient = address(0xCAFE); // The recipient of the streamed tokens
        params.totalAmount = totalAmount; // Total amount is the amount inclusive of all fees
        params.token = DAI; // The streaming token
        params.cancelable = true; // Whether the stream will be cancelable or not
        params.transferable = true; // Whether the stream will be transferable or not
        params.broker = Broker(address(0), ud60x18(0)); // Optional parameter for charging a fee

        LockupLinear.UnlockAmounts memory unlockAmounts = LockupLinear.UnlockAmounts({ start: 0, cliff: 0 });
        LockupLinear.Durations memory durations = LockupLinear.Durations({
            cliff: 0, // Setting a cliff of 0
            total: 52 weeks // Setting a total duration of ~1 year
         });

        // Create the LockupLinear stream using a function that sets the start time to `block.timestamp`
        streamId = LOCKUP.createWithDurationsLL(params, unlockAmounts, durations);
    }
}
