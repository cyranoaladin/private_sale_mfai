// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title PrivateSaleMFAI
 * @dev Private sale contract with three tiers.
 *      - Tier 1: Cumulative contribution limit of 30 BNB.
 *      - Tier 2: Additional contribution of 60 BNB (cumulative 90 BNB).
 *      - Tier 3: Additional contribution of 60 BNB (cumulative 150 BNB).
 *      If a contribution exceeds the tier limit, the excess is applied to the next tier.
 *      In tier 3, if totalFunds + contribution >= 150 BNB, the entire contribution is accepted and the sale ends.
 *      All funds are transferred to the wallet (vault).
 */
contract PrivateSaleMFAI is Ownable, ReentrancyGuard, Pausable {
    /// @notice Address of the wallet (vault) receiving all funds.
    address public wallet;

    /// @notice Cumulative limits for each tier.
    uint256 public tier1Limit;
    uint256 public tier2Limit;
    uint256 public tier3Limit; // Total limit for all tiers (150 BNB)

    /// @notice Total amount collected during the sale.
    uint256 public totalFunds;

    /// @notice Current tier: 1, 2, or 3. Value 0 indicates that the sale is finished.
    uint256 public currentTier;

    /// @notice Maximum contribution per participant (for tiers 1 and 2).
    uint256 public maxContribution = 10 ether;

    /// @notice Maximum limit for pagination.
    uint256 public maxPageSize = 100;

    /// @notice Minimum contribution increment (in wei). Default is 1 BNB.
    uint256 public contributionIncrement = 1 ether;

    /// @notice Delay before the new increment takes effect.
    uint256 public timelockDelay = 2 hours;

    /// @notice Timestamp when the new increment will take effect.
    uint256 public contributionIncrementEffectiveTime;

    /// @notice New increment awaiting application.
    uint256 public pendingContributionIncrement;

    /**
     * @notice Structure for storing contributions by tier.
     */
    struct Contribution {
        uint256 total;
        uint256 tier1;
        uint256 tier2;
        uint256 tier3;
    }

    /// @notice Mapping of contributions by address.
    mapping(address => Contribution) public contributions;

    /// @notice List of participating addresses.
    address[] public participants;

    /// @notice Events
    event ContributionEvent(address indexed participant, uint256 amount, uint256 tier);
    event TierAdvanced(uint256 newTier);
    event TierLimitUpdated(uint256 tier, uint256 newLimit);
    event ContributionIncrementUpdated(uint256 newIncrement);

    /**
     * @notice Initializes the contract with the vault address and tier limits.
     * @param _wallet Address of the wallet (vault) to receive funds.
     */
    constructor(address _wallet) Ownable(msg.sender) {
        require(_wallet != address(0), "Wallet address cannot be zero");
        wallet = _wallet;
        currentTier = 1;
        tier1Limit = 30 ether;    // Tier 1 = 30 BNB
        tier2Limit = 90 ether;    // Tier 2 = 60 BNB additional (30 + 60)
        tier3Limit = 150 ether;   // Tier 3 = 60 BNB additional (90 + 60)
        contributionIncrementEffectiveTime = 0;
    }

    /**
     * @notice Allows contribution to the private sale.
     * @dev Contribution must be a multiple of contributionIncrement.
     *      In tier 3, if totalFunds + contribution >= tier3Limit, the sale ends.
     *      All funds are transferred to the wallet.
     */
    function contribute() external payable nonReentrant whenNotPaused {
        require(msg.value > 0, "Amount must be positive");
        require(msg.value % contributionIncrement == 0, "Amount must be a multiple of the contribution increment");

        if (currentTier < 3) {
            require(contributions[msg.sender].total + msg.value <= maxContribution, "Contribution exceeds individual limit");
        }

        uint256 remaining = msg.value;
        while (remaining > 0 && currentTier != 0) {
            if (currentTier < 3) {
                uint256 tierRemaining = getCurrentTierLimit() - totalFunds;
                if (remaining <= tierRemaining) {
                    totalFunds += remaining;
                    recordContribution(msg.sender, remaining);
                    remaining = 0;
                    if (totalFunds >= getCurrentTierLimit()) {
                        advanceTier();
                    }
                } else {
                    totalFunds += tierRemaining;
                    recordContribution(msg.sender, tierRemaining);
                    remaining -= tierRemaining;
                    advanceTier();
                }
            } else if (currentTier == 3) {
                if (totalFunds + remaining >= tier3Limit) {
                    uint256 accepting = tier3Limit - totalFunds;
                    totalFunds += accepting;
                    recordContribution(msg.sender, accepting);
                    remaining -= accepting;
                    currentTier = 0; // End the sale
                    emit TierAdvanced(currentTier);
                } else {
                    totalFunds += remaining;
                    recordContribution(msg.sender, remaining);
                    remaining = 0;
                }
            }
        }
        (bool sent, ) = wallet.call{value: msg.value}("");
        require(sent, "Transfer to wallet failed");
    }

    /**
     * @notice Records a participant's contribution for the current tier.
     * @param participant Address of the participant.
     * @param amount Amount contributed.
     */
    function recordContribution(address participant, uint256 amount) internal {
        if (contributions[participant].total == 0) {
            participants.push(participant);
        }
        contributions[participant].total += amount;
        if (currentTier == 1) {
            contributions[participant].tier1 += amount;
        } else if (currentTier == 2) {
            contributions[participant].tier2 += amount;
        } else if (currentTier == 3 || currentTier == 0) {
            contributions[participant].tier3 += amount;
        }
        emit ContributionEvent(participant, amount, (currentTier == 0) ? 3 : currentTier);
    }

    /**
     * @notice Returns the limit of the current tier.
     * @return The limit in BNB.
     */
    function getCurrentTierLimit() public view returns (uint256) {
        if (currentTier == 1) return tier1Limit;
        if (currentTier == 2) return tier2Limit;
        if (currentTier == 3) return tier3Limit;
        return 0;
    }

    /**
     * @notice Advances immediately to the next tier.
     */
    function advanceTier() internal {
        if (currentTier == 1 && totalFunds >= tier1Limit) {
            currentTier = 2;
            emit TierAdvanced(currentTier);
        } else if (currentTier == 2 && totalFunds >= tier2Limit) {
            currentTier = 3;
            emit TierAdvanced(currentTier);
        }
    }

    /**
     * @notice Resets the private sale (only by the owner).
     */
    function resetPrivateSale() external onlyOwner {
        totalFunds = 0;
        currentTier = 1;
        for (uint256 i = 0; i < participants.length;) {
            contributions[participants[i]] = Contribution(0, 0, 0, 0);
            unchecked { i++; }
        }
        delete participants;
    }

    /**
     * @notice Exports participant data with pagination (only by the owner).
     * @param page Page number (starting from 1).
     * @param pageSize Number of participants per page.
     * @return participantAddresses Array of addresses and participantData array of contributions.
     */
    function exportParticipants(uint256 page, uint256 pageSize)
        external
        view
        onlyOwner
        returns (address[] memory, Contribution[] memory)
    {
        require(page > 0, "Page number must be greater than zero");
        require(pageSize > 0 && pageSize <= maxPageSize, "Page size must be > 0 and <= maxPageSize");
        uint256 startIndex = (page - 1) * pageSize;
        require(startIndex < participants.length, "Invalid start index");
        uint256 endIndex = startIndex + pageSize;
        if (endIndex > participants.length) {
            endIndex = participants.length;
        }
        uint256 count = endIndex - startIndex;
        address[] memory participantAddresses = new address[](count);
        Contribution[] memory participantData = new Contribution[](count);
        for (uint256 i = startIndex; i < endIndex; i++) {
            participantAddresses[i - startIndex] = participants[i];
            participantData[i - startIndex] = contributions[participants[i]];
        }
        return (participantAddresses, participantData);
    }

    /**
     * @notice Returns the total number of participants.
     * @return The number of participants.
     */
    function getParticipantCount() public view returns (uint256) {
        return participants.length;
    }

    /**
     * @notice Returns the contributions of a participant.
     * @param participant Address of the participant.
     * @return The total contribution and per-tier contributions.
     */
    function getContributions(address participant) external view returns (Contribution memory) {
        return contributions[participant];
    }

    /**
     * @notice Schedules an update to the contribution increment (only by the owner).
     * @param _newIncrement New increment (in wei).
     */
    function updateContributionIncrement(uint256 _newIncrement) external onlyOwner {
        require(_newIncrement > 0, "Increment must be positive");
        require(_newIncrement != contributionIncrement, "New increment must be different from current increment");
        require(_newIncrement <= 1 ether, "Must be less than 1 ether");
        pendingContributionIncrement = _newIncrement;
        contributionIncrementEffectiveTime = block.timestamp + timelockDelay;
        emit ContributionIncrementUpdated(_newIncrement);
    }

    /**
     * @notice Applies the new contribution increment after the delay (only by the owner).
     */
    function applyContributionIncrement() external onlyOwner {
        require(pendingContributionIncrement > 0, "No increment update pending");
        require(block.timestamp >= contributionIncrementEffectiveTime, "Timelock delay not yet elapsed");
        contributionIncrement = pendingContributionIncrement;
        pendingContributionIncrement = 0;
    }

    /**
     * @notice Updates a tier limit (only by the owner).
     * @param tier Tier number (1, 2, or 3).
     * @param newLimit New limit.
     */
    function updateTierLimit(uint256 tier, uint256 newLimit) external onlyOwner {
        require(tier >= 1 && tier <= 3, "Invalid tier");
        require(newLimit > 0, "New limit must be positive");
        require(currentTier <= tier, "Cannot update a completed tier");
        if (tier == 1) {
            require(newLimit >= totalFunds, "New limit must be >= total funds collected");
            tier1Limit = newLimit;
        } else if (tier == 2) {
            require(newLimit >= totalFunds - tier1Limit, "New limit must be >= total funds minus Tier 1");
            tier2Limit = newLimit;
        } else if (tier == 3) {
            tier3Limit = newLimit;
        }
        emit TierLimitUpdated(tier, newLimit);
    }

    /**
     * @notice Updates the maximum page size (only by the owner).
     * @param newMaxPageSize New maximum size.
     */
    function updateMaxPageSize(uint256 newMaxPageSize) external onlyOwner {
        require(newMaxPageSize > 0, "Page size must be positive");
        maxPageSize = newMaxPageSize;
    }

    /**
     * @notice Updates the maximum contribution per participant (only by the owner).
     * @param newLimit New limit.
     */
    function updateMaxContribution(uint256 newLimit) external onlyOwner {
        require(newLimit > 0, "Contribution limit must be positive");
        maxContribution = newLimit;
    }

    /**
     * @notice Rejects direct ether transfers.
     */
    receive() external payable {
        revert("Direct transfers not allowed");
    }

    /**
     * @notice Handles calls to non-existent functions.
     */
    fallback() external payable {
        revert("Fallback: function does not exist");
    }
}
