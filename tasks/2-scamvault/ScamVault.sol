// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ScamVault is ERC20 {

    ScamVault private immutable self = this;
    address public user;

    mapping(address => address) public partner;
    mapping(address => address[]) public referrals;
    mapping(address => uint256) public lastTapTimestamp;

    uint256 public TAP_DELAY;
    uint256 public REWARD_DELAY;
    uint32 public rewardAmount;
    uint256 public lastClaimedReward;
    bool isReward;

    modifier onReward {
        require(isReward == true);
        _;
    }

    constructor(uint256 _RewardDelay, uint256 _tapDelay, uint32 _rewardAmount, uint256 initialSupply,
                address _user) ERC20("Scam token", "SCAM") {
        lastClaimedReward = block.timestamp;
        REWARD_DELAY = _RewardDelay;
        TAP_DELAY = _tapDelay;
        rewardAmount = _rewardAmount;
        user = _user;

        _mint(address(this), initialSupply);
    }

    function tap() external {
        if (lastTapTimestamp[msg.sender] != 0 && block.timestamp < lastTapTimestamp[msg.sender] + TAP_DELAY) {
            revert("Wait for next tap");
        }

        uint reffers_cnt = referrals[msg.sender].length;

        lastTapTimestamp[msg.sender] = block.timestamp;

        _mint(msg.sender, reffers_cnt + 1);

    }

    function claim_reward() external {
        require(block.timestamp >= lastClaimedReward + REWARD_DELAY, "Not now");
        require(!isReward);

        isReward = true;

        address[] storage reffers = referrals[msg.sender];
        for (uint i = 0; i < reffers.length; i++) {
            self.claim_reward_for_reffer(reffers[i]);
        }

        lastClaimedReward = block.timestamp;
        
        _mint(msg.sender, rewardAmount);

        isReward = false;
    }

    function claim_reward_for_reffer(address reffer) external onReward {
        _mint(reffer, rewardAmount);
    }

    function follow_the_link(address _partner) external {
        require(_partner != msg.sender, "Forbidden");
        self.isAlreadyFollow(_partner);

        partner[msg.sender] = _partner;
        referrals[_partner].push(msg.sender);
    }

    function isAlreadyFollow(address _partner) external view {
        address[] storage reffers = referrals[_partner];
        for (uint i = 0; i < reffers.length; i++) {
            require(msg.sender != reffers[i], "Already follow");
        }
    }
}