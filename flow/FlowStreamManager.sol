// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { ud21x18 } from "@prb/math/src/UD21x18.sol";
import { ud60x18 } from "@prb/math/src/UD60x18.sol";
import { Broker, ISablierFlow } from "@sablier/flow/src/interfaces/ISablierFlow.sol";

contract FlowStreamManager {
    // Mainnet address
    ISablierFlow public constant FLOW = ISablierFlow(0x3DF2AAEdE81D2F6b261F79047517713B8E844E04);

    function adjustRatePerSecond(uint256 streamId) external {
        FLOW.adjustRatePerSecond({ streamId: streamId, newRatePerSecond: ud21x18(0.0001e18) });
    }

    function deposit(uint256 streamId) external {
        FLOW.deposit(streamId, 3.14159e18, msg.sender, address(0xCAFE));
    }

    function depositAndPause(uint256 streamId) external {
        FLOW.depositAndPause(streamId, 3.14159e18);
    }

    function depositViaBroker(uint256 streamId) external {
        Broker memory broker = Broker({ account: address(0xDEAD), fee: ud60x18(0.0001e18) });

        FLOW.depositViaBroker({
            streamId: streamId,
            totalAmount: 3.14159e18,
            sender: msg.sender,
            recipient: address(0xCAFE),
            broker: broker
        });
    }

    function pause(uint256 streamId) external {
        FLOW.pause(streamId);
    }

    function refund(uint256 streamId) external {
        FLOW.refund({ streamId: streamId, amount: 1.61803e18 });
    }

    function refundAndPause(uint256 streamId) external {
        FLOW.refundAndPause({ streamId: streamId, amount: 1.61803e18 });
    }

    function refundMax(uint256 streamId) external {
        FLOW.refundMax(streamId);
    }

    function restart(uint256 streamId) external {
        FLOW.restart({ streamId: streamId, ratePerSecond: ud21x18(0.0001e18) });
    }

    function restartAndDeposit(uint256 streamId) external {
        FLOW.restartAndDeposit({ streamId: streamId, ratePerSecond: ud21x18(0.0001e18), amount: 2.71828e18 });
    }

    function void(uint256 streamId) external {
        FLOW.void(streamId);
    }

    function withdraw(uint256 streamId) external {
        FLOW.withdraw({ streamId: streamId, to: address(0xCAFE), amount: 2.71828e18 });
    }

    function withdrawMax(uint256 streamId) external {
        FLOW.withdrawMax({ streamId: streamId, to: address(0xCAFE) });
    }
}
