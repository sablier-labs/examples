// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { ISablierV2LockupLinear } from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import { ud60x18 } from "@sablier/v2-core/src/types/Math.sol";
import { IERC20 } from "@sablier/v2-core/src/types/Tokens.sol";
import { IPRBProxy, IPRBProxyRegistry } from "@sablier/v2-periphery/src/types/Proxy.sol";
import { ISablierV2ProxyTarget } from "@sablier/v2-periphery/src/interfaces/ISablierV2ProxyTarget.sol";
import { Broker, LockupLinear } from "@sablier/v2-periphery/src/types/DataTypes.sol";

contract SingleLockupLinearStreamCreator {
    // Mainnet addresses
    IERC20 public constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    // See https://docs.sablier.com/contracts/v2/deployments for all deployments
    ISablierV2LockupLinear public constant LOCKUP_LINEAR =
        ISablierV2LockupLinear(0x39EFdC3dbB57B2388CcC4bb40aC4CB1226Bc9E44);
    ISablierV2ProxyTarget public constant PROXY_TARGET_APPROVE =
        ISablierV2ProxyTarget(0x638a7aC8315767cEAfc57a6f5e3559454347C3f6);

    IPRBProxyRegistry public constant PROXY_REGISTRY = IPRBProxyRegistry(0x584009E9eDe26e212182c9745F5c000191296a78);

    function singleCreateStream(uint128 totalAmount) public returns (uint256[] memory streamIds) {
        // Get the proxy for this contract and deploy it if it doesn't exist
        IPRBProxy proxy = PROXY_REGISTRY.getProxy({ user: address(this) });
        if (address(proxy) == address(0)) {
            proxy = PROXY_REGISTRY.deployFor(address(this));
        }

        // Transfer the provided amount of DAI tokens to this contract
        DAI.transferFrom(msg.sender, address(this), totalAmount);

        // Approve the Proxy contract to spend DAI
        uint256 allowance = DAI.allowance(address(this), address(proxy));
        if (allowance < totalAmount) {
            DAI.approve({ spender: address(proxy), amount: type(uint256).max });
        }

        // Declare the create function params
        LockupLinear.CreateWithDurations memory createParams;
        createParams.sender = msg.sender; // The sender will be able to cancel the stream
        createParams.recipient = address(0xcafe); // The recipient of the streamed assets
        createParams.totalAmount = totalAmount; // Total amount is the amount inclusive of all fees
        createParams.asset = DAI; // The streaming asset is DAI
        createParams.cancelable = true; // Whether the stream will be cancelable or not
        createParams.durations = LockupLinear.Durations({
            cliff: 4 weeks, // Assets will be unlocked only after 4 weeks
            total: 52 weeks // Setting a total duration of ~1 year
         });
        createParams.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Encode the data for the proxy
        bytes memory data = abi.encodeCall(PROXY_TARGET_APPROVE.createWithDurations, (LOCKUP_LINEAR, createParams, ""));

        // Create a single Lockup Linear stream via the proxy and Sablier's proxy target approve
        bytes memory response = proxy.execute(address(PROXY_TARGET_APPROVE), data);
        streamIds = abi.decode(response, (uint256[]));
    }
}
