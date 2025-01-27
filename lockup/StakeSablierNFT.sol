// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC721Holder } from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { Adminable } from "@sablier/lockup/src/abstracts/Adminable.sol";
import { ISablierLockupRecipient } from "@sablier/lockup/src/interfaces/ISablierLockupRecipient.sol";
import { ISablierLockup } from "@sablier/lockup/src/interfaces/ISablierLockup.sol";

/// @title StakeSablierNFT
///
/// @notice DISCLAIMER: This template has not been audited and is provided "as is" with no warranties of any kind,
/// either express or implied. It is intended solely for demonstration purposes on how to build a staking contract using
/// Sablier NFT. This template should not be used in a production environment. It makes specific assumptions that may
/// not apply to your particular needs.
///
/// @dev This template allows users to stake Sablier NFTs and earn staking rewards based on the total amount available
/// in the stream. The implementation is inspired by the Synthetix staking contract:
/// https://github.com/Synthetixio/synthetix/blob/develop/contracts/StakingRewards.sol.
///
/// Assumptions:
///   - The Sablier NFT must be transferable because staking requires transferring the NFT to the staking contract.
///   - This staking contract assumes that one user can only stake one NFT at a time.
contract StakeSablierNFT is Adminable, ERC721Holder, ISablierLockupRecipient {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////////////////
                                       ERRORS
    //////////////////////////////////////////////////////////////////////////*/

    error AlreadyStaking(address account, uint256 streamId);
    error DifferentStreamingToken(uint256 streamId, IERC20 rewardToken);
    error ProvidedRewardTooHigh();
    error StakingAlreadyActive();
    error UnauthorizedCaller(address account, uint256 streamId);
    error ZeroAddress(address account);
    error ZeroAmount();
    error ZeroDuration();

    /*//////////////////////////////////////////////////////////////////////////
                                       EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    event RewardAdded(uint256 reward);
    event RewardDurationUpdated(uint256 newDuration);
    event RewardPaid(address indexed user, uint256 reward);
    event Staked(address indexed user, uint256 streamId);
    event Unstaked(address indexed user, uint256 streamId);

    /*//////////////////////////////////////////////////////////////////////////
                                USER-FACING STATE
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev The last time when rewards were updated.
    uint256 public lastUpdateTime;

    /// @dev This should be your own ERC-20 token in which the staking rewards will be distributed.
    IERC20 public rewardERC20Token;

    /// @dev Total rewards to be distributed per second.
    uint256 public rewardRate;

    /// @dev Earned rewards for each account.
    mapping(address account => uint256 earned) public rewards;

    /// @dev Duration for which staking is live.
    uint256 public rewardsDuration;

    /// @dev This should be the Sablier Lockup contract.
    ISablierLockup public sablierLockup;

    /// @dev The staked stream IDs mapped by user addresses.
    mapping(address account => uint256 streamId) public stakedStreams;

    /// @dev The owners of the streams mapped by stream IDs.
    mapping(uint256 streamId => address account) public stakedUsers;

    /// @dev The timestamp when the staking ends.
    uint256 public stakingEndTime;

    /// @dev The total amount of ERC-20 tokens staked through Sablier NFTs.
    uint256 public totalERC20StakedSupply;

    /// @dev Keeps track of the total rewards distributed divided by total staked supply.
    uint256 public totalRewardPaidPerERC20Token;

    /// @dev The rewards paid to each account per ERC-20 token mapped by the account.
    mapping(address account => uint256 reward) public userRewardPerERC20Token;

    /*//////////////////////////////////////////////////////////////////////////
                                     MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Modifier used to keep track of the earned rewards for user each time a `stake`, `unstake` or
    /// `claimRewards` is called.
    modifier updateReward(address account) {
        totalRewardPaidPerERC20Token = rewardPaidPerERC20Token();
        lastUpdateTime = lastTimeRewardsApplicable();
        rewards[account] = calculateUserRewards(account);
        userRewardPerERC20Token[account] = totalRewardPaidPerERC20Token;
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    /// @param initialAdmin The address of the initial contract admin.
    /// @param rewardERC20Token_ The address of the ERC-20 token used for rewards.
    /// @param sablierLockup_ The address of the ERC-721 Contract.
    constructor(
        address initialAdmin,
        IERC20 rewardERC20Token_,
        ISablierLockup sablierLockup_
    )
        Adminable(initialAdmin)
    {
        rewardERC20Token = rewardERC20Token_;
        sablierLockup = sablierLockup_;
    }

    /*//////////////////////////////////////////////////////////////////////////
                            USER-FACING CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Calculate the earned rewards for an account.
    /// @param account The address of the account to calculate available rewards for.
    /// @return earned The amount available as rewards for the account.
    function calculateUserRewards(address account) public view returns (uint256 earned) {
        if (stakedStreams[account] == 0) {
            return rewards[account];
        }

        uint256 amountInStream = _getAmountInStream(stakedStreams[account]);
        uint256 userRewardPerERC20Token_ = userRewardPerERC20Token[account];
        uint256 rewardsSinceLastTime = (amountInStream * (rewardPaidPerERC20Token() - userRewardPerERC20Token_)) / 1e18;

        return rewardsSinceLastTime + rewards[account];
    }

    /// @notice Get the last time when rewards were applicable
    function lastTimeRewardsApplicable() public view returns (uint256) {
        return block.timestamp < stakingEndTime ? block.timestamp : stakingEndTime;
    }

    /// @notice Calculates the total rewards distributed per ERC-20 token.
    /// @dev This is called by `updateReward`, which also updates the value of `totalRewardPaidPerERC20Token`.
    function rewardPaidPerERC20Token() public view returns (uint256) {
        // If the total staked supply is zero or staking has ended, return the stored value of reward per ERC-20.
        if (totalERC20StakedSupply == 0 || block.timestamp >= stakingEndTime) {
            return totalRewardPaidPerERC20Token;
        }

        uint256 totalRewardsPerERC20InCurrentPeriod =
            ((lastTimeRewardsApplicable() - lastUpdateTime) * rewardRate * 1e18) / totalERC20StakedSupply;

        return totalRewardPaidPerERC20Token + totalRewardsPerERC20InCurrentPeriod;
    }

    // {IERC165-supportsInterface} implementation as required by `ISablierLockupRecipient` interface.
    function supportsInterface(bytes4 interfaceId) public pure override(IERC165) returns (bool) {
        return interfaceId == 0xf8ee98d3;
    }

    /*//////////////////////////////////////////////////////////////////////////
                         USER-FACING NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Function called by the user to claim his accumulated rewards.
    function claimRewards() public updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            delete rewards[msg.sender];

            rewardERC20Token.safeTransfer(msg.sender, reward);

            emit RewardPaid(msg.sender, reward);
        }
    }

    /// @notice Implements the hook to handle cancelation events. This will be called by Sablier contract when a stream
    /// is canceled by the sender.
    /// @dev This function subtracts the amount refunded to the sender from `totalERC20StakedSupply`.
    ///   - This function also updates the rewards for the staker.
    function onSablierLockupCancel(
        uint256 streamId,
        address, /* sender */
        uint128 senderAmount,
        uint128 /* recipientAmount */
    )
        external
        updateReward(stakedUsers[streamId])
        returns (bytes4 selector)
    {
        // Check: the caller is the Lockup contract.
        if (msg.sender != address(sablierLockup)) {
            revert UnauthorizedCaller(msg.sender, streamId);
        }

        // Effect: update the total staked amount.
        totalERC20StakedSupply -= senderAmount;

        return ISablierLockupRecipient.onSablierLockupCancel.selector;
    }

    /// @notice Implements the hook to handle withdraw events. This will be called by Sablier contract when withdraw is
    /// called on a stream.
    /// @dev This function transfers `amount` to the original staker.
    function onSablierLockupWithdraw(
        uint256 streamId,
        address, /* caller */
        address, /* recipient */
        uint128 amount
    )
        external
        updateReward(stakedUsers[streamId])
        returns (bytes4 selector)
    {
        // Check: the caller is the Lockup contract
        if (msg.sender != address(sablierLockup)) {
            revert UnauthorizedCaller(msg.sender, streamId);
        }

        address staker = stakedUsers[streamId];

        // Check: the staker is not the zero address.
        if (staker == address(0)) {
            revert ZeroAddress(staker);
        }

        // Effect: update the total staked amount.
        totalERC20StakedSupply -= amount;

        // Interaction: transfer the withdrawn amount to the original staker.
        rewardERC20Token.safeTransfer(staker, amount);

        return ISablierLockupRecipient.onSablierLockupWithdraw.selector;
    }

    /// @notice Stake a Sablier NFT with specified base token.
    /// @dev The `msg.sender` must approve the staking contract to spend the Sablier NFT before calling this function.
    /// One user can only stake one NFT at a time.
    /// @param streamId The stream ID of the Sablier NFT to be staked.
    function stake(uint256 streamId) external updateReward(msg.sender) {
        // Check: the Sablier NFT is streaming the staking token.
        if (sablierLockup.getUnderlyingToken(streamId) != rewardERC20Token) {
            revert DifferentStreamingToken(streamId, rewardERC20Token);
        }

        // Check: the user is not already staking.
        if (stakedStreams[msg.sender] != 0) {
            revert AlreadyStaking(msg.sender, stakedStreams[msg.sender]);
        }

        // Effect: store the owner of the Sablier NFT.
        stakedUsers[streamId] = msg.sender;

        // Effect: store the stream ID.
        stakedStreams[msg.sender] = streamId;

        // Effect: update the total staked amount.
        totalERC20StakedSupply += _getAmountInStream(streamId);

        // Interaction: transfer NFT to the staking contract.
        sablierLockup.safeTransferFrom({ from: msg.sender, to: address(this), tokenId: streamId });

        emit Staked(msg.sender, streamId);
    }

    /// @notice Unstaking a Sablier NFT will transfer the NFT back to the `msg.sender`.
    /// @param streamId The stream ID of the Sablier NFT to be unstaked.
    function unstake(uint256 streamId) public updateReward(msg.sender) {
        // Check: the caller is the stored owner of the NFT.
        if (stakedUsers[streamId] != msg.sender) {
            revert UnauthorizedCaller(msg.sender, streamId);
        }

        // Effect: update the total staked amount.
        totalERC20StakedSupply -= _getAmountInStream(streamId);

        _unstake({ streamId: streamId, account: msg.sender });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                 PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Determine the amount available in the stream.
    /// @dev The following function determines the amounts of tokens in a stream irrespective of its cancelable status.
    function _getAmountInStream(uint256 streamId) private view returns (uint256 amount) {
        // The tokens in the stream = amount deposited - amount withdrawn - amount refunded.
        return sablierLockup.getDepositedAmount(streamId) - sablierLockup.getWithdrawnAmount(streamId)
            - sablierLockup.getRefundedAmount(streamId);
    }

    function _unstake(uint256 streamId, address account) private {
        // Check: account is not zero.
        if (account == address(0)) {
            revert ZeroAddress(account);
        }

        // Effect: delete the owner of the staked stream.
        delete stakedUsers[streamId];

        // Effect: delete the Sablier NFT.
        delete stakedStreams[account];

        // Interaction: transfer stream back to user.
        sablierLockup.safeTransferFrom({ from: address(this), to: account, tokenId: streamId });

        emit Unstaked(account, streamId);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Start a Staking period and set the amount of ERC-20 tokens to be distributed as rewards in said period.
    /// @dev The Staking Contract have to already own enough Rewards Tokens to distribute all the rewards, so make sure
    /// to send all the tokens to the contract before calling this function.
    /// @param rewardAmount The amount of Reward Tokens to be distributed.
    /// @param newDuration The duration in which the rewards will be distributed.
    function startStakingPeriod(uint256 rewardAmount, uint256 newDuration) external onlyAdmin {
        // Check: the amount is not zero
        if (rewardAmount == 0) {
            revert ZeroAmount();
        }

        // Check: the duration is not zero.
        if (newDuration == 0) {
            revert ZeroDuration();
        }

        // Check: the staking period is not already active.
        if (block.timestamp <= stakingEndTime) {
            revert StakingAlreadyActive();
        }

        // Effect: update the rewards duration.
        rewardsDuration = newDuration;

        // Effect: update the reward rate.
        rewardRate = rewardAmount / rewardsDuration;

        // Check: the contract has enough tokens to distribute as rewards.
        uint256 balance = rewardERC20Token.balanceOf(address(this));
        if (rewardRate > balance / rewardsDuration) {
            revert ProvidedRewardTooHigh();
        }

        // Effect: update the `lastUpdateTime`.
        lastUpdateTime = block.timestamp;

        // Effect: update the `stakingEndTime`.
        stakingEndTime = block.timestamp + rewardsDuration;

        emit RewardAdded(rewardAmount);

        emit RewardDurationUpdated(rewardsDuration);
    }
}
