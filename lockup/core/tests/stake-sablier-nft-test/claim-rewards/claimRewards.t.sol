// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { StakeSablierNFT_Fork_Test } from "../StakeSablierNFT.t.sol";

contract ClaimRewards_Test is StakeSablierNFT_Fork_Test {
    function test_WhenCallerIsNotStaker() external {
        // Change the caller to a staker.
        resetPrank({ msgSender: users.joe.addr });

        // Expect no transfer.
        vm.expectCall({
            callee: address(rewardToken),
            data: abi.encodeCall(rewardToken.transfer, (users.joe.addr, 0)),
            count: 0
        });

        // Claim rewards.
        stakingContract.claimRewards();
    }

    function test_WhenCallerIsStaker() external {
        // Prank the caller to a staker.
        resetPrank({ msgSender: users.alice.addr });

        vm.warp(block.timestamp + 1 days);

        uint256 expectedReward = 1 days * rewardRate;
        uint256 initialBalance = rewardToken.balanceOf(users.alice.addr);

        // Claim the rewards.
        stakingContract.claimRewards();

        // Assert balance increased by the expected reward.
        uint256 finalBalance = rewardToken.balanceOf(users.alice.addr);
        assertApproxEqAbs(finalBalance - initialBalance, expectedReward, 0.0001e18);

        // Assert rewards has been set to 0.
        assertEq(stakingContract.rewards(users.alice.addr), 0);
    }
}
