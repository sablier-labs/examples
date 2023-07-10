// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { ISablierV2LockupLinear } from "@sablier/v2-core/interfaces/ISablierV2LockupLinear.sol";
import { LockupLinear } from "@sablier/v2-core/types/DataTypes.sol";
import { ud60x18 } from "@sablier/v2-core/types/Math.sol";
import { IERC20 } from "@sablier/v2-core/types/Tokens.sol";
import { ISablierV2ProxyTarget } from "@sablier/v2-periphery/interfaces/ISablierV2ProxyTarget.sol";
import { Batch, Broker } from "@sablier/v2-periphery/types/DataTypes.sol";
import { IAllowanceTransfer, Permit2Params } from "@sablier/v2-periphery/types/Permit2.sol";
import { IPRBProxy, IPRBProxyRegistry } from "@sablier/v2-periphery/types/Proxy.sol";

import { ERC1271 } from "./ERC1271.sol";

contract BatchLockupLinearStreamCreator is ERC1271 {
    IERC20 public constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IAllowanceTransfer public constant PERMIT2 = IAllowanceTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    IPRBProxyRegistry public constant PROXY_REGISTRY = IPRBProxyRegistry(0xD42a2bB59775694c9Df4c7822BfFAb150e6c699D);
    ISablierV2LockupLinear public immutable lockupLinear;
    ISablierV2ProxyTarget public immutable proxyTarget;

    constructor(ISablierV2LockupLinear lockupLinear_, ISablierV2ProxyTarget proxyTarget_) {
        lockupLinear = lockupLinear_;
        proxyTarget = proxyTarget_;
    }

    function batchCreateLockupLinearStream(uint256 perStreamAmount) public returns (uint256[] memory streamIds) {
        // Get the proxy for this contract and deploy it if it doesn't exist
        IPRBProxy proxy = PROXY_REGISTRY.getProxy({ owner: address(this) });
        if (address(proxy) == address(0)) {
            proxy = PROXY_REGISTRY.deployFor(address(this));
        }

        // Create a batch of two streams
        uint256 batchSize = 2;

        // Calculate the combined amount of DAI assets to transfer to this contract
        uint256 transferAmount = perStreamAmount * batchSize;

        // Transfer the provided amount of DAI tokens to this contract
        DAI.transferFrom(msg.sender, address(this), transferAmount);

        // Approve the Permit2 contract to spend DAI
        uint256 allowance = DAI.allowance(address(this), address(PERMIT2));
        if (allowance < transferAmount) {
            DAI.approve({ spender: address(PERMIT2), amount: type(uint256).max });
        }

        // Set up Permit2. See the full documentation at https://github.com/Uniswap/permit2
        IAllowanceTransfer.PermitDetails memory permitDetails;
        permitDetails.token = address(DAI);
        permitDetails.amount = uint160(transferAmount);
        permitDetails.expiration = type(uint48).max; // maximum expiration possible
        (,, permitDetails.nonce) =
            PERMIT2.allowance({ user: address(this), token: address(DAI), spender: address(proxy) });

        IAllowanceTransfer.PermitSingle memory permitSingle;
        permitSingle.details = permitDetails;
        permitSingle.spender = address(proxy); // the proxy will be the spender
        permitSingle.sigDeadline = type(uint48).max; // same deadline as expiration

        // Declare the Permit2 params needed by Sablier
        Permit2Params memory permit2Params;
        permit2Params.permitSingle = permitSingle;
        permit2Params.signature = bytes(""); // contracts don't sign transactions

        // Declare the first stream in the batch
        Batch.CreateWithDurations memory stream0;
        stream0.sender = address(proxy); // The sender will be able to cancel the stream
        stream0.recipient = address(0xcafe); // The recipient of the streamed assets
        stream0.totalAmount = uint128(perStreamAmount); // The total amount of each stream, inclusive of all fees
        stream0.cancelable = true; // Whether the stream will be cancelable or not
        stream0.durations = LockupLinear.Durations({
            cliff: 4 weeks, // Assets will be unlocked only after 4 weeks
            total: 52 weeks // Setting a total duration of ~1 year
         });
        stream0.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Declare the second stream in the batch
        Batch.CreateWithDurations memory stream1;
        stream1.sender = address(proxy); // The sender will be able to cancel the stream
        stream1.recipient = address(0xbeef); // The recipient of the streamed assets
        stream1.totalAmount = uint128(perStreamAmount); // The total amount of each stream, inclusive of all fees
        stream1.cancelable = false; // Whether the stream will be cancelable or not
        stream1.durations = LockupLinear.Durations({
            cliff: 1 weeks, // Assets will be unlocked only after 1 week
            total: 26 weeks // Setting a total duration of ~6 months
         });
        stream1.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Fill the batch param
        Batch.CreateWithDurations[] memory batch = new Batch.CreateWithDurations[](batchSize);
        batch[0] = stream0;
        batch[1] = stream1;

        // Encode the data for the proxy target call
        bytes memory data =
            abi.encodeCall(proxyTarget.batchCreateWithDurations, (lockupLinear, DAI, batch, permit2Params));

        // Create a batch of Lockup Linear streams via the proxy and Sablier's proxy target
        bytes memory response = proxy.execute(address(proxyTarget), data);
        streamIds = abi.decode(response, (uint256[]));
    }
}
