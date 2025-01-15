// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ud21x18, UD21x18 } from "@prb/math/src/UD21x18.sol";
import { ud60x18 } from "@prb/math/src/UD60x18.sol";
import { Broker, ISablierFlow } from "@sablier/flow/src/interfaces/ISablierFlow.sol";

/// @notice The `Batch` contract, inherited in SablierFlow, allows multiple function calls to be batched together. This
/// enables any possible combination of functions to be executed within a single transaction.
/// @dev For some functions to work, `msg.sender` must have approved this contract to spend USDC.
contract FlowBatchable {
    // Sepolia addresses
    IERC20 public constant USDC = IERC20(0xf08A50178dfcDe18524640EA6618a1f965821715);
    ISablierFlow public constant FLOW = ISablierFlow(0x52ab22e769E31564E17D524b683264B65662A014);

    /// @dev A function to adjust the rate per second and deposit into a stream in a single transaction.
    /// Note: The streamId's sender must be this contract, otherwise, the call will fail due to no authorization.
    function adjustRatePerSecondAndDeposit(uint256 streamId) external {
        UD21x18 newRatePerSecond = ud21x18(0.0002e18);
        uint128 depositAmount = 1000e6;

        // Transfer to this contract the amount to deposit in the stream.
        USDC.transferFrom(msg.sender, address(this), depositAmount);

        // Approve the Sablier contract to spend USDC.
        USDC.approve(address(FLOW), depositAmount);

        // Fetch the stream recipient.
        address recipient = FLOW.getRecipient(streamId);

        // The call data declared as bytes.
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(FLOW.adjustRatePerSecond, (streamId, newRatePerSecond));
        calls[1] = abi.encodeCall(FLOW.deposit, (streamId, depositAmount, msg.sender, recipient));

        FLOW.batch(calls);
    }

    /// @dev A function to create a stream and deposit via a broker in a single transaction.
    function createAndDepositViaBroker() external returns (uint256 streamId) {
        address sender = msg.sender;
        address recipient = address(0xCAFE);
        UD21x18 ratePerSecond = ud21x18(0.0001e18);
        uint128 depositAmount = 1000e6;
        bool transferable = true;

        // The broker struct.
        Broker memory broker = Broker({
            account: address(0xDEAD),
            fee: ud60x18(0.0001e18) // the fee percentage
         });

        // Transfer to this contract the amount to deposit in the stream.
        USDC.transferFrom(msg.sender, address(this), depositAmount);

        // Approve the Sablier contract to spend USDC.
        USDC.approve(address(FLOW), depositAmount);

        streamId = FLOW.nextStreamId();

        // The call data declared as bytes
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(FLOW.create, (sender, recipient, ratePerSecond, USDC, transferable));
        calls[1] = abi.encodeCall(FLOW.depositViaBroker, (streamId, depositAmount, sender, recipient, broker));

        // Execute multiple calls in a single transaction using the prepared call data.
        FLOW.batch(calls);
    }

    /// @dev A function to create multiple streams in a single transaction.
    function createMultiple() external returns (uint256[] memory streamIds) {
        address sender = msg.sender;
        address firstRecipient = address(0xCAFE);
        address secondRecipient = address(0xBEEF);
        UD21x18 firstRatePerSecond = ud21x18(0.0001e18);
        UD21x18 secondRatePerSecond = ud21x18(0.0002e18);
        bool transferable = true;

        // The call data declared as bytes
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(FLOW.create, (sender, firstRecipient, firstRatePerSecond, USDC, transferable));
        calls[1] = abi.encodeCall(FLOW.create, (sender, secondRecipient, secondRatePerSecond, USDC, transferable));

        // Prepare the `streamIds` array to return them
        uint256 nextStreamId = FLOW.nextStreamId();
        streamIds = new uint256[](2);
        streamIds[0] = nextStreamId;
        streamIds[1] = nextStreamId + 1;

        // Execute multiple calls in a single transaction using the prepared call data.
        FLOW.batch(calls);
    }

    /// @dev A function to create multiple streams and deposit via a broker into all the stream in a single transaction.
    function createMultipleAndDepositViaBroker() external returns (uint256[] memory streamIds) {
        address sender = msg.sender;
        address firstRecipient = address(0xCAFE);
        address secondRecipient = address(0xBEEF);
        UD21x18 ratePerSecond = ud21x18(0.0001e18);
        uint128 depositAmount = 1000e6;
        bool transferable = true;

        // Transfer the deposit amount of USDC tokens to this contract for both streams
        USDC.transferFrom(msg.sender, address(this), 2 * depositAmount);

        // Approve the Sablier contract to spend USDC.
        USDC.approve(address(FLOW), 2 * depositAmount);

        // The broker struct
        Broker memory broker = Broker({
            account: address(0xDEAD),
            fee: ud60x18(0.0001e18) // the fee percentage
         });

        uint256 nextStreamId = FLOW.nextStreamId();
        streamIds = new uint256[](2);
        streamIds[0] = nextStreamId;
        streamIds[1] = nextStreamId + 1;

        // We need to have 4 different function calls, 2 for creating streams and 2 for depositing via broker
        bytes[] memory calls = new bytes[](4);
        calls[0] = abi.encodeCall(FLOW.create, (sender, firstRecipient, ratePerSecond, USDC, transferable));
        calls[1] = abi.encodeCall(FLOW.create, (sender, secondRecipient, ratePerSecond, USDC, transferable));
        calls[2] = abi.encodeCall(FLOW.depositViaBroker, (streamIds[0], depositAmount, sender, firstRecipient, broker));
        calls[3] = abi.encodeCall(FLOW.depositViaBroker, (streamIds[1], depositAmount, sender, secondRecipient, broker));

        // Execute multiple calls in a single transaction using the prepared call data.
        FLOW.batch(calls);
    }

    /// @dev A function to pause a stream and withdraw the maximum available funds.
    /// Note: The streamId's sender must be this contract, otherwise, the call will fail due to no authorization.
    function pauseAndWithdrawMax(uint256 streamId) external {
        // The call data declared as bytes.
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(FLOW.pause, (streamId));
        calls[1] = abi.encodeCall(FLOW.withdrawMax, (streamId, address(0xCAFE)));

        // Execute multiple calls in a single transaction using the prepared call data.
        FLOW.batch(calls);
    }

    /// @dev A function to void a stream and withdraw what is left.
    /// Note: The streamId's sender must be this contract, otherwise, the call will fail due to no authorization.
    function voidAndWithdrawMax(uint256 streamId) external {
        // The call data declared as bytes
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(FLOW.void, (streamId));
        calls[1] = abi.encodeCall(FLOW.withdrawMax, (streamId, address(0xCAFE)));

        // Execute multiple calls in a single transaction using the prepared call data.
        FLOW.batch(calls);
    }

    /// @dev A function to withdraw maximum available funds from multiple streams in a single transaction.
    function withdrawMaxMultiple(uint256[] calldata streamIds) external {
        uint256 count = streamIds.length;

        // Iterate over the streamIds and prepare the call data for each stream.
        bytes[] memory calls = new bytes[](count);
        for (uint256 i = 0; i < count; ++i) {
            address recipient = FLOW.getRecipient(streamIds[i]);
            calls[i] = abi.encodeCall(FLOW.withdrawMax, (streamIds[i], recipient));
        }

        // Execute multiple calls in a single transaction using the prepared call data.
        FLOW.batch(calls);
    }
}
