// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.13;

import { ISablierV2LockupLinear } from "@sablier/v2-core/interfaces/ISablierV2LockupLinear.sol";
import { Broker, LockupLinear } from "@sablier/v2-core/types/DataTypes.sol";
import { ud60x18 } from "@sablier/v2-core/types/Math.sol";
import { IERC20 } from "@sablier/v2-core/types/Tokens.sol";

contract LinearStreamCreator {
    IERC20 public constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    ISablierV2LockupLinear public immutable sablier;

    constructor(ISablierV2LockupLinear sablier_) {
        sablier = sablier_;
    }

    function createLinearStream(uint256 amount) external returns (uint256 streamId) {
        // Transfer the provided amount of DAI tokens to this contract
        DAI.transferFrom(msg.sender, address(this), amount);

        // Approve the Sablier contract to spend DAI
        DAI.approve(address(sablier), amount);

        // Prepare the parameters
        LockupLinear.CreateWithDurations memory params;
        params.sender = msg.sender; // The sender will be able to cancel the stream
        params.recipient = address(0xcafe); // The recipient of the streamed assets
        params.totalAmount = amount; // Total amount is the amount inclusive of all fees
        params.asset = DAI; // The streaming asset is DAI
        params.cancelable = true; // Whether the stream will be cancelable or not
        params.durations = LockupLinear.Durations({
            cliff: 4 weeks, // Assets will be unlocked only after 4 weeks
            total: 52 weeks // Setting a total duration of ~1 year
         });
        params.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Create the sablier stream using a function that sets the start time to `block.timestamp`
        streamId = sablier.createWithDurations(params);
    }
}
