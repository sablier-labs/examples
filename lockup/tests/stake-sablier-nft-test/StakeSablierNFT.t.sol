// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ud60x18 } from "@prb/math/src/UD60x18.sol";
import { ISablierLockup } from "@sablier/lockup/src/interfaces/ISablierLockup.sol";
import { Broker, Lockup, LockupLinear } from "@sablier/lockup/src/types/DataTypes.sol";
import { Test } from "forge-std/src/Test.sol";

import { StakeSablierNFT } from "../../StakeSablierNFT.sol";

struct StreamOwner {
    address addr;
    uint256 streamId;
}

struct Users {
    // Creator of the NFT staking contract.
    address admin;
    // Alice has already staked her NFT.
    StreamOwner alice;
    // Bob is unauthorized to stake.
    StreamOwner bob;
    // Joe wants to stake his NFT.
    StreamOwner joe;
}

abstract contract StakeSablierNFT_Fork_Test is Test {
    // Errors
    error AlreadyStaking(address account, uint256 streamId);
    error DifferentStreamingToken(uint256 streamId, IERC20 rewardToken);
    error ProvidedRewardTooHigh();
    error StakingAlreadyActive();
    error UnauthorizedCaller(address account, uint256 streamId);
    error ZeroAddress(address account);
    error ZeroAmount();
    error ZeroDuration();

    // Events
    event RewardAdded(uint256 reward);
    event RewardDurationUpdated(uint256 newDuration);
    event RewardPaid(address indexed user, uint256 reward);
    event Staked(address indexed user, uint256 streamId);
    event Unstaked(address indexed user, uint256 streamId);

    IERC20 public constant DAI = IERC20(0x776b6fC2eD15D6Bb5Fc32e0c89DE68683118c62A);
    IERC20 public constant USDC = IERC20(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238);

    // Get the latest deployment address from the docs: https://docs.sablier.com/contracts/v2/deployments.
    ISablierLockup internal constant SABLIER = ISablierLockup(0xC2Da366fD67423b500cDF4712BdB41d0995b0794);

    // Set a stream ID to stake.
    uint256 internal stakingStreamId = 2;

    // Reward rate based on the total amount staked.
    uint256 internal rewardRate;

    // Token used for creating streams as well as to distribute rewards.
    IERC20 internal rewardToken = DAI;

    StakeSablierNFT internal stakingContract;

    uint256 internal constant AMOUNT_IN_STREAM = 1000e18;

    Users internal users;

    function setUp() public {
        // Fork Ethereum Sepolia
        vm.createSelectFork({ urlOrAlias: "sepolia", blockNumber: 7_497_776 });

        // Create users.
        users.admin = makeAddr("admin");
        users.alice.addr = makeAddr("alice");
        users.bob.addr = makeAddr("bob");
        users.joe.addr = makeAddr("joe");

        // Mint some reward tokens to the admin address which will be used to deposit to the staking contract.
        deal({ token: address(rewardToken), to: users.admin, give: 10_000e18 });

        // Make the admin the `msg.sender` in all following calls.
        vm.startPrank({ msgSender: users.admin });

        // Deploy the staking contract.
        stakingContract =
            new StakeSablierNFT({ initialAdmin: users.admin, rewardERC20Token_: rewardToken, sablierLockup_: SABLIER });

        // Set expected reward rate.
        rewardRate = 10_000e18 / uint256(1 weeks);

        // Fund the staking contract with some reward tokens.
        rewardToken.transfer(address(stakingContract), 10_000e18);

        // Start the staking period.
        stakingContract.startStakingPeriod(10_000e18, 1 weeks);

        // Stake some streams.
        _createAndStakeStreamBy({ recipient: users.alice, token: DAI, stake: true });
        _createAndStakeStreamBy({ recipient: users.bob, token: USDC, stake: false });
        _createAndStakeStreamBy({ recipient: users.joe, token: DAI, stake: false });

        // Make the stream owner the `msg.sender` in all the subsequent calls.
        resetPrank({ msgSender: users.joe.addr });

        // Approve the staking contract to spend the NFT.
        SABLIER.setApprovalForAll(address(stakingContract), true);
    }

    /// @dev Stops the active prank and sets a new one.
    function resetPrank(address msgSender) internal {
        vm.stopPrank();
        vm.startPrank(msgSender);
    }

    function _createLockupLinearStreams(address recipient, IERC20 token) private returns (uint256 streamId) {
        deal({ token: address(token), to: users.admin, give: AMOUNT_IN_STREAM });

        resetPrank({ msgSender: users.admin });

        token.approve(address(SABLIER), type(uint256).max);

        // Declare the params struct
        Lockup.CreateWithDurations memory params;

        // Declare the function parameters
        params.sender = users.admin; // The sender will be able to cancel the stream
        params.recipient = recipient; // The recipient of the streamed tokens
        params.totalAmount = uint128(AMOUNT_IN_STREAM); // Total amount is the amount inclusive of all fees
        params.token = token; // The streaming token
        params.cancelable = true; // Whether the stream will be cancelable or not
        params.transferable = true; // Whether the stream will be transferable or not
        params.broker = Broker(address(0), ud60x18(0)); // Optional parameter for charging a fee

        LockupLinear.UnlockAmounts memory unlockAmounts = LockupLinear.UnlockAmounts({ start: 0, cliff: 0 });
        LockupLinear.Durations memory durations = LockupLinear.Durations({
            cliff: 0, // Setting a cliff of 0
            total: 52 weeks // Setting a total duration of ~1 year
         });

        // Create the Sablier stream using a function that sets the start time to `block.timestamp`
        streamId = SABLIER.createWithDurationsLL(params, unlockAmounts, durations);
    }

    function _createAndStakeStreamBy(StreamOwner storage recipient, IERC20 token, bool stake) private {
        resetPrank({ msgSender: users.admin });

        uint256 streamId = _createLockupLinearStreams(recipient.addr, token);
        recipient.streamId = streamId;

        // Make the stream owner the `msg.sender` in all the subsequent calls.
        resetPrank({ msgSender: recipient.addr });

        // Approve the staking contract to spend the NFT.
        SABLIER.setApprovalForAll(address(stakingContract), true);

        // Stake a few NFTs to simulate the actual staking behavior.
        if (stake) {
            stakingContract.stake(streamId);
        }
    }
}
