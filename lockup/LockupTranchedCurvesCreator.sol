// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ud60x18 } from "@prb/math/src/UD60x18.sol";
import { ISablierLockup } from "@sablier/lockup/src/interfaces/ISablierLockup.sol";
import { Broker, Lockup, LockupTranched } from "@sablier/lockup/src/types/DataTypes.sol";

import { console } from "forge-std/src/console.sol";

/// @notice Examples of how to create Lockup Linear streams with different curve shapes.
/// @dev A visualization of the curve shapes can be found in the docs:
/// https://docs.sablier.com/concepts/lockup/stream-shapes#lockup-tranched
/// Visualizing the curves while reviewing this code is recommended. The X axis will be assumed to represent "days".
contract LockupTranchedCurvesCreator {
    // Mainnet addresses
    IERC20 public constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    ISablierLockup public constant LOCKUP = ISablierLockup(0x7C01AA3783577E15fD7e272443D44B92d5b21056);

    function createStream_UnlockInSteps() external returns (uint256 streamId) {
        // Declare the total amount as 100 DAI
        uint128 totalAmount = 100e18;

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
        params.broker = Broker(address(0), ud60x18(0)); // Optional broker fee

        // Declare a four-size tranche to match the curve shape
        uint256 trancheSize = 4;
        LockupTranched.TrancheWithDuration[] memory tranches = new LockupTranched.TrancheWithDuration[](trancheSize);

        // The tranches are filled with the same amount and are spaced 25 days apart
        uint128 unlockAmount = uint128(totalAmount / trancheSize);
        for (uint256 i = 0; i < trancheSize; ++i) {
            tranches[i] = LockupTranched.TrancheWithDuration({ amount: unlockAmount, duration: 25 days });
        }

        // Create the Lockup stream using tranche model with periodic unlocks in step
        uint256 beforeGas = gasleft();
        streamId = LOCKUP.createWithDurationsLT(params, tranches);
        uint256 afterGas = gasleft();
        console.log("Gas used: %d for Unlock in steps wiht four-size tranche", beforeGas - afterGas);
    }

    function createStream_MonthlyUnlocks() external returns (uint256 streamId) {
        // Declare the total amount as 120 DAI
        uint128 totalAmount = 120e18;

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
        params.broker = Broker(address(0), ud60x18(0)); // Optional broker fee

        // Declare a twenty four size tranche to match the curve shape
        uint256 trancheSize = 12;
        LockupTranched.TrancheWithDuration[] memory tranches = new LockupTranched.TrancheWithDuration[](trancheSize);

        // The tranches are spaced 30 days apart (~one month)
        uint128 unlockAmount = uint128(totalAmount / trancheSize);
        for (uint256 i = 0; i < trancheSize; ++i) {
            tranches[i] = LockupTranched.TrancheWithDuration({ amount: unlockAmount, duration: 30 days });
        }

        // Create the Lockup stream using tranche model with web2 style monthly unlocks
        uint256 beforeGas = gasleft();
        streamId = LOCKUP.createWithDurationsLT(params, tranches);
        uint256 afterGas = gasleft();
        console.log("Gas used: %d for Monthly unlocks with twelve-size tranche", beforeGas - afterGas);
    }

    function createStream_Timelock() external returns (uint256 streamId) {
        // Declare the total amount as 100 DAI
        uint128 totalAmount = 100e18;

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
        params.broker = Broker(address(0), ud60x18(0)); // Optional broker fee

        // Declare a two-size tranche to match the curve shape
        LockupTranched.TrancheWithDuration[] memory tranches = new LockupTranched.TrancheWithDuration[](1);
        tranches[0] = LockupTranched.TrancheWithDuration({ amount: 100e18, duration: 90 days });

        // Create the Lockup stream using tranche model with full unlock only at the end
        uint256 beforeGas = gasleft();
        streamId = LOCKUP.createWithDurationsLT(params, tranches);
        uint256 afterGas = gasleft();
        console.log("Gas used: %d for Timelock shape", beforeGas - afterGas);
    }
}
