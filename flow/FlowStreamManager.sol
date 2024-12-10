// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { ud21x18 } from "@prb/math/src/UD21x18.sol";

import { ISablierFlow } from "@sablier/flow/src/interfaces/ISablierFlow.sol";

contract FlowStreamManager {
    // Sepolia addres
    ISablierFlow public constant FLOW = ISablierFlow(0x5Ae8c13f6Ae094887322012425b34b0919097d8A);

    function adjustRatePerSecond(uint256 streamId) external {
        FLOW.adjustRatePerSecond({ streamId: streamId, newRatePerSecond: ud21x18(0.0001e18) });
    }

    function deposit(uint256 streamId) external {
        FLOW.deposit(streamId, 3.14159e18, msg.sender, address(0xCAFE));
    }

    function depositAndPause(uint256 streamId) external {
        FLOW.depositAndPause(streamId, 3.14159e18);
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
