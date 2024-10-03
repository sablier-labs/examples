// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ud21x18, UD21x18 } from "@prb/math/src/UD21x18.sol";
import { ud60x18, UD60x18 } from "@prb/math/src/UD60x18.sol";

import { Broker, SablierFlow } from "../repos/flow/src/SablierFlow.sol";

/// @dev The `Batch` contract, inherited in SablierFlow, allows multiple function calls to be batched together.
/// This enables any possible combination of functions to be executed within a single transaction.
contract FlowBatchable {
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    SablierFlow public immutable sablierFlow;

    constructor(SablierFlow sablierFlow_) {
        sablierFlow = sablierFlow_;
    }

    /// @dev A function to adjust the rate per second and deposits into a stream.
    function adjustRatePerSecondAndDeposit(uint256 streamId) external {
        UD21x18 newRatePerSecond = ud21x18(0.0001e18);
        uint128 depositAmount = 1000e6;

        // The calldata declared as bytes
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(sablierFlow.adjustRatePerSecond, (streamId, newRatePerSecond));
        calls[1] = abi.encodeCall(sablierFlow.deposit, (streamId, depositAmount));

        sablierFlow.batch(calls);
    }

    /// @dev A function to create multiple streams in a single transaction.
    function createMultiple() external returns (uint256[] memory streamIds) {
        address sender = msg.sender;
        address firstRecipient = address(0xCAFE);
        address secondRecipient = address(0xBEEF);
        UD21x18 firstRatePerSecond = ud21x18(0.0001e18);
        UD21x18 secondRatePerSecond = ud21x18(0.0002e18);

        // The calldata declared as bytes
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(sablierFlow.create, (sender, firstRecipient, firstRatePerSecond, USDC, true));
        calls[1] = abi.encodeCall(sablierFlow.create, (sender, secondRecipient, secondRatePerSecond, USDC, true));

        // Prepare the `streamIds` array to return them
        uint256 nextStreamId = sablierFlow.nextStreamId();
        streamIds = new uint256[](2);
        streamIds[0] = nextStreamId;
        streamIds[1] = nextStreamId + 1;

        // Execute multiple calls in a single transaction using the prepared call data.
        sablierFlow.batch(calls);
    }

    /// @dev A function to create a stream and deposit via a broker in a single transaction.
    function createAndDepositViaBroker() external returns (uint256 streamId) {
        address sender = msg.sender;
        address recipient = address(0xCAFE);
        UD21x18 ratePerSecond = ud21x18(0.0001e18);
        uint128 depositAmount = 1000e6;

        // The broker struct
        Broker memory broker = Broker({
            account: address(0xDEAD),
            fee: ud60x18(0.0001e18) // the fee percentage
         });

        streamId = sablierFlow.nextStreamId();

        // The calldata declared as bytes
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(sablierFlow.create, (sender, recipient, ratePerSecond, USDC, true));
        calls[1] = abi.encodeCall(sablierFlow.depositViaBroker, (streamId, depositAmount, broker));

        // Execute multiple calls in a single transaction using the prepared call data.
        sablierFlow.batch(calls);
    }

    /// @dev A function to create multiple streams and deposit via a broker in a single transaction.
    function createMultipleAndDepositViaBroker() external returns (uint256[] memory streamIds) {
        address sender = msg.sender;
        address firstRecipient = address(0xCAFE);
        address secondRecipient = address(0xBEEF);
        UD21x18 ratePerSecond = ud21x18(0.0001e18);
        uint128 depositAmount = 1000e6;

        // The broker struct
        Broker memory broker = Broker({
            account: address(0xDEAD),
            fee: ud60x18(0.0001e18) // the fee percentage
         });

        uint256 nextStreamId = sablierFlow.nextStreamId();
        streamIds = new uint256[](2);
        streamIds[0] = nextStreamId;
        streamIds[1] = nextStreamId + 1;

        // We need to have 4 different function calls, 2 for creating streams and 2 for depositing via broker
        bytes[] memory calls = new bytes[](4);
        calls[0] = abi.encodeCall(sablierFlow.create, (sender, firstRecipient, ratePerSecond, USDC, true));
        calls[1] = abi.encodeCall(sablierFlow.create, (sender, secondRecipient, ratePerSecond, USDC, true));
        calls[2] = abi.encodeCall(sablierFlow.depositViaBroker, (sablierFlow.nextStreamId(), depositAmount, broker));
        calls[3] = abi.encodeCall(sablierFlow.depositViaBroker, (sablierFlow.nextStreamId(), depositAmount, broker));

        // Execute multiple calls in a single transaction using the prepared call data.
        sablierFlow.batch(calls);
    }

    /// @dev A function to pause a stream and withdraw the maximum available funds.
    function pauseAndWithdrawMax(uint256 streamId) external {
        // The calldata declared as bytes
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(sablierFlow.pause, (streamId));
        calls[1] = abi.encodeCall(sablierFlow.withdrawMax, (streamId, address(0xCAFE)));

        // Execute multiple calls in a single transaction using the prepared call data.
        sablierFlow.batch(calls);
    }

    /// @dev A function to void a stream and withdraw what is left.
    function voidAndWithdrawMax(uint256 streamId) external {
        // The calldata declared as bytes
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(sablierFlow.void, (streamId));
        calls[1] = abi.encodeCall(sablierFlow.withdrawMax, (streamId, address(0xCAFE)));

        // Execute multiple calls in a single transaction using the prepared call data.
        sablierFlow.batch(calls);
    }

    /// @dev A function to withdraw maximum available funds from multiple streams in a single transaction.
    function withdrawMaxMultiple(uint256[] calldata streamIds) external {
        uint256 count = streamIds.length;

        // Iterate over the streamIds and prepare the call data for each stream
        bytes[] memory calls = new bytes[](count);
        for (uint256 i = 0; i < count; ++i) {
            address recipient = sablierFlow.getRecipient(streamIds[i]);
            calls[i] = abi.encodeCall(sablierFlow.withdrawMax, (streamIds[i], recipient));
        }

        // Execute multiple calls in a single transaction using the prepared call data.
        sablierFlow.batch(calls);
    }
}
