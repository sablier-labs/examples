// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { ISablierV2LockupLinear } from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import { Broker, LockupLinear } from "@sablier/v2-core/src/types/DataTypes.sol";
import { ud60x18 } from "@sablier/v2-core/src/types/Math.sol";
import { IERC20 } from "@sablier/v2-core/src/types/Tokens.sol";

contract SingleLockupLinearStreamCreator {
    IERC20 public constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    // See https://docs.sablier.com/contracts/v2/deployments for all deployments
    ISablierV2LockupLinear public constant LOCKUP_LINEAR =
        ISablierV2LockupLinear(0xB10daee1FCF62243aE27776D7a92D39dC8740f95);

    function singleCreateLockupLinearStream(uint256 totalAmount) public returns (uint256 streamId) {
        // Transfer the provided amount of DAI tokens to this contract
        DAI.transferFrom(msg.sender, address(this), totalAmount);

        // Approve the Lockup Linear contract to spend DAI
        uint256 allowance = DAI.allowance(address(this), address(LOCKUP_LINEAR));
        if (allowance < totalAmount) {
            DAI.approve({ spender: address(LOCKUP_LINEAR), amount: type(uint256).max });
        }

        // Declare the create function params
        LockupLinear.CreateWithDurations memory createParams;
        createParams.sender = address(0xABCD); // The sender to stream the assets, he will be able to cancel the stream
        createParams.recipient = address(0xCAFE); // The recipient of the streamed assets
        createParams.totalAmount = uint128(totalAmount); // Total amount is the amount inclusive of all fees
        createParams.asset = DAI; // The streaming asset is DAI
        createParams.cancelable = true; // Whether the stream will be cancelable or not
        createParams.durations = LockupLinear.Durations({
            cliff: 4 weeks, // Assets will be unlocked only after 4 weeks
            total: 52 weeks // Setting a total duration of ~1 year
         });
        createParams.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        streamId = LOCKUP_LINEAR.createWithDurations(createParams);
    }
}
