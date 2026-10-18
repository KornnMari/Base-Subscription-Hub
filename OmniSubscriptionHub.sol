// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

contract OmniSubscriptionHub {
    struct SubscriptionTier {
        address payable creator;
        uint256 priceWei;
        uint256 durationSeconds;
        bool isActive;
        bytes32 tierHash;
    }

    address payable public immutable hubAdmin;
    string public hubDescriptor;
    uint256 public platformFeeBps; // 250 = 2.5%
    uint256 public tierCounter;
    uint256 public accumulatedFees;
    bool public isHubHalted;

    mapping(uint256 => SubscriptionTier) public tiers;
    mapping(address => uint256) public creatorEarnings;
    mapping(uint256 => mapping(address => uint256)) public subscriptionExpiry;

    event TierCreated(uint256 indexed tierId, address indexed creator, uint256 price, uint256 duration);
    event TierCanceled(uint256 indexed tierId);
    event TreasuryDeposited(address indexed funder, uint256 amount);
    event ReservesDrained(address indexed admin, uint256 amount);
    event FeesGathered(address indexed admin, uint256 amount);
    event HubHaltToggled(bool isHalted);
    event Subscribed(uint256 indexed tierId, address indexed subscriber, uint256 expiry);
    event DescriptorUpdated(string newDescriptor);
    event EarningsWithdrawn(address indexed creator, uint256 amount);

    modifier onlyAdmin() {
        require(msg.sender == hubAdmin, "OmniSub: Access denied");
        _;
    }

    modifier whenNotHalted() {
        require(!isHubHalted, "OmniSub: Hub is halted");
        _;
    }

    constructor() {
        hubAdmin = payable(msg.sender);
        hubDescriptor = "Omni Base Subscription Hub v1";
        platformFeeBps = 250; // 2.5%
        isHubHalted = false;
    }

    // 1. cancelSubscriptionTier
    function cancelSubscriptionTier(uint256 tierId) external {
        SubscriptionTier storage t = tiers[tierId];
        require(tierId > 0 && tierId <= tierCounter, "OmniSub: Invalid ID");
        require(msg.sender == t.creator || msg.sender == hubAdmin, "OmniSub: Unauthorized");
        require(t.isActive, "OmniSub: Already inactive");

        t.isActive = false;
        emit TierCanceled(tierId);
    }

    // 2. createSubscriptionTier
    function createSubscriptionTier(uint256 priceWei, uint256 durationSeconds, bytes32 tierHash) external whenNotHalted returns (uint256) {
        require(priceWei > 0, "OmniSub: Zero price");
        require(durationSeconds > 0, "OmniSub: Zero duration");

        tierCounter++;
        tiers[tierCounter] = SubscriptionTier({
            creator: payable(msg.sender),
            priceWei: priceWei,
            durationSeconds: durationSeconds,
            isActive: true,
            tierHash: tierHash
        });

        emit TierCreated(tierCounter, msg.sender, priceWei, durationSeconds);
        return tierCounter;
    }

    // 3. depositPlatformTreasury
    function depositPlatformTreasury() external payable whenNotHalted {
        require(msg.value > 0, "OmniSub: Zero deposit");
        accumulatedFees += msg.value;
        emit TreasuryDeposited(msg.sender, msg.value);
    }

    // 4. drainPlatformReserves
    function drainPlatformReserves() external onlyAdmin {
        uint256 balance = address(this).balance;
        require(balance > 0, "OmniSub: Zero balance");

        accumulatedFees = 0;
        (bool sent, ) = hubAdmin.call{value: balance}("");
        require(sent, "OmniSub: Sweep failed");

        emit ReservesDrained(hubAdmin, balance);
    }

    // 5. gatherPlatformFees
    function gatherPlatformFees() external onlyAdmin {
        uint256 amount = accumulatedFees;
        require(amount > 0, "OmniSub: Zero fees");

        accumulatedFees = 0;
        (bool sent, ) = hubAdmin.call{value: amount}("");
        require(sent, "OmniSub: Harvest failed");

        emit FeesGathered(hubAdmin, amount);
    }

    // 6. haltSubscriptionHub
    function haltSubscriptionHub(bool isHalted) external onlyAdmin {
        isHubHalted = isHalted;
        emit HubHaltToggled(isHalted);
    }

    // 7. subscribeToTier
    function subscribeToTier(uint256 tierId) external payable whenNotHalted {
        SubscriptionTier storage t = tiers[tierId];
        require(tierId > 0 && tierId <= tierCounter, "OmniSub: Invalid ID");
        require(t.isActive, "OmniSub: Tier inactive");
        require(msg.value >= t.priceWei, "OmniSub: Insufficient payment");

        uint256 fee = (msg.value * platformFeeBps) / 10000;
        uint256 creatorShare = msg.value - fee;

        accumulatedFees += fee;
        creatorEarnings[t.creator] += creatorShare;

        uint256 currentExpiry = subscriptionExpiry[tierId][msg.sender];
        if (currentExpiry < block.timestamp) {
            subscriptionExpiry[tierId][msg.sender] = block.timestamp + t.durationSeconds;
        } else {
            subscriptionExpiry[tierId][msg.sender] = currentExpiry + t.durationSeconds;
        }

        emit Subscribed(tierId, msg.sender, subscriptionExpiry[tierId][msg.sender]);
    }

    // 8. updateHubDescriptor
    function updateHubDescriptor(string calldata newDescriptor) external onlyAdmin {
        require(bytes(newDescriptor).length > 0, "OmniSub: Empty string");
        hubDescriptor = newDescriptor;
        emit DescriptorUpdated(newDescriptor);
    }

    // 9. withdrawCreatorEarnings
    function withdrawCreatorEarnings() external {
        uint256 amount = creatorEarnings[msg.sender];
        require(amount > 0, "OmniSub: Zero earnings");

        creatorEarnings[msg.sender] = 0;
        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent, "OmniSub: Withdrawal failed");

        emit EarningsWithdrawn(msg.sender, amount);
    }
}