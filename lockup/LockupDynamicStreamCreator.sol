// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ud2x18 } from "@prb/math/src/UD2x18.sol";
import { ud60x18 } from "@prb/math/src/UD60x18.sol";
import { ISablierLockup } from "@sablier/lockup/src/interfaces/ISablierLockup.sol";
import { Broker, Lockup, LockupDynamic } from "@sablier/lockup/src/types/DataTypes.sol";

/// @notice Example of how to create a Lockup Dynamic stream.
/// @dev This code is referenced in the docs:
/// https://docs.sablier.com/guides/lockup/examples/create-stream/lockup-dynamic
contract LockupDynamicStreamCreator {
    // sepolia addresses
    IERC20 public constant DAI = IERC20(0x68194a729C2450ad26072b3D33ADaCbcef39D574);
    ISablierLockup public constant LOCKUP = ISablierLockup(0xC2Da366fD67423b500cDF4712BdB41d0995b0794);

    /// @dev For this function to work, the sender must have approved this dummy contract to spend DAI.
    function createStream(uint128 amount0, uint128 amount1) public returns (uint256 streamId) {
        // Sum the segment amounts
        uint256 totalAmount = amount0 + amount1;

        // Transfer the provided amount of DAI tokens to this contract
        DAI.transferFrom(msg.sender, address(this), totalAmount);

        // Approve the Sablier contract to spend DAI
        DAI.approve(address(LOCKUP), totalAmount);

        // Declare the params struct
        Lockup.CreateWithTimestamps memory params;

        // Declare the function parameters
        params.sender = msg.sender; // The sender will be able to cancel the stream
        params.recipient = address(0xCAFE); // The recipient of the streamed tokens
        params.totalAmount = uint128(totalAmount); // Total amount is the amount inclusive of all fees
        params.token = DAI; // The streaming token
        params.cancelable = true; // Whether the stream will be cancelable or not
        params.transferable = true; // Whether the stream will be transferable or not
        params.timestamps.start = uint40(block.timestamp + 100 seconds);
        params.timestamps.end = uint40(block.timestamp + 52 weeks);

        // Declare some dummy segments
        LockupDynamic.Segment[] memory segments = new LockupDynamic.Segment[](2);
        segments[0] = LockupDynamic.Segment({
            amount: amount0,
            exponent: ud2x18(1e18),
            timestamp: uint40(block.timestamp + 4 weeks)
        });
        segments[1] = (
            LockupDynamic.Segment({
                amount: amount1,
                exponent: ud2x18(3.14e18),
                timestamp: uint40(block.timestamp + 52 weeks)
            })
        );

        params.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Create the LockupDynamic stream
        streamId = LOCKUP.createWithTimestampsLD(params, segments);
    }
}
