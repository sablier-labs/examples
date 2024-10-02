// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { ud21x18, UD21x18 } from "@prb/math/src/UD21x18.sol";

import { ISablierFlow } from "../repos/flow/src/interfaces/ISablierFlow.sol";

contract FlowManager {
    ISablierFlow public immutable sablierFlow;

    constructor(ISablierFlow sablierFlow_) {
        sablierFlow = sablierFlow_;
    }

    function adjustRatePerSecond(uint256 streamId) external {
        sablierFlow.adjustRatePerSecond({ streamId: streamId, newRatePerSecond: ud21x18(0.0001e18) });
    }

    function deposit(uint256 streamId) external {
        sablierFlow.deposit(streamId, 3.14159e18);
    }

    function depositAndPause(uint256 streamId) external {
        sablierFlow.depositAndPause(streamId, 3.14159e18);
    }

    function pause(uint256 streamId) external {
        sablierFlow.pause(streamId);
    }

    function refund(uint256 streamId) external {
        sablierFlow.refund({ streamId: streamId, amount: 1.61803e18 });
    }

    function refundAndPause(uint256 streamId) external {
        sablierFlow.refundAndPause({ streamId: streamId, amount: 1.61803e18 });
    }

    function restart(uint256 streamId) external {
        sablierFlow.restart({ streamId: streamId, ratePerSecond: ud21x18(0.0001e18) });
    }

    function restartAndDeposit(uint256 streamId) external {
        sablierFlow.restartAndDeposit({ streamId: streamId, ratePerSecond: ud21x18(0.0001e18), amount: 2.71828e18 });
    }

    function void(uint256 streamId) external {
        sablierFlow.void(streamId);
    }

    function withdraw(uint256 streamId) external {
        sablierFlow.withdraw({ streamId: streamId, to: address(0xCAFE), amount: 2.71828e18 });
    }

    function withdrawMax(uint256 streamId) external {
        sablierFlow.withdrawMax({ streamId: streamId, to: address(0xCAFE) });
    }
}
