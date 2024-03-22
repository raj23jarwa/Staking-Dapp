// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Staking is ReentrancyGuard {
    using SafeMath for uint256;
    IERC20 public s_stakingToken;
    IERC20 public s_rewardToken;

    uint256 public constant REWARD_RATE = 10;
    uint256 private totalStakedTokens;
    uint256 private rewardPerTokenStored;
    uint256 public lastUpdatedTime;

    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public userRewardperTokenPaid;

    event staked(address indexed user, uint256 indexed amount);
    event withDrawn(address indexed user, uint256 indexed amount);
    event RewardsClaimed(address indexed user, uint256 indexed amount);

    constructor(address stakingToken, address rewardToken) {
        s_stakingToken = IERC20(stakingToken);
        s_rewardToken = IERC20(rewardToken);
    }

    function rewardPerToken() public view returns(uint){
        if(totalStakedTokens==0){
            return rewardPerTokenStored;
        }
        uint totalTime = block.timestamp - lastUpdatedTime;
        uint totalRewards= REWARD_RATE*totalTime;
        return rewardPerTokenStored+totalRewards/totalStakedTokens;
    }

    function earned(address account) public view returns(uint){
        return ((stakedBalance[account])*(rewardPerToken()-userRewardperTokenPaid[account]));
    }

    // modifier updateReward(address account){
    //     rewardPerTokenStored=rewardPerToken();
    //     lastUpdatedTime=block.timestamp;
    //     rewards[account]=earned(account);
    //     userRewardperTokenPaid[account] =rewardPerTokenStored;
    //     _;
    // }
  modifier updateReward(address account){
    rewardPerTokenStored = rewardPerToken();
    uint256 newRewardPerToken = rewardPerTokenStored;
    uint256 lastPaid = userRewardperTokenPaid[account];
    rewards[account] = (stakedBalance[account] * (newRewardPerToken - lastPaid)) + rewards[account];
    userRewardperTokenPaid[account] = newRewardPerToken;
    lastUpdatedTime = block.timestamp;
    _;
}



    // function stake(uint amount) external nonReentrant updateReward(msg.sender) { 
    //     require (amount>0, "Amount must be greater than zero");
    //     totalStakedTokens+=amount;
    //     stakedBalance[msg.sender]+=amount;
    //     emit staked(msg.sender, amount);
    //     bool success = s_stakingToken.transferFrom(msg.sender, address(this), amount);
    //     require(success,"Transfer Failed");
    // }
    function stake(uint amount) external nonReentrant updateReward(msg.sender) { 
    require(amount > 0, "Amount must be greater than zero");

    totalStakedTokens += amount;
    stakedBalance[msg.sender] += amount;

    // Update user's last paid reward per token to current reward per token
    userRewardperTokenPaid[msg.sender] = rewardPerToken();

    emit staked(msg.sender, amount);

    bool success = s_stakingToken.transferFrom(msg.sender, address(this), amount);
    require(success, "Transfer failed");
}

   function withdraw(uint amount) external nonReentrant updateReward(msg.sender) { 
    require(amount > 0, "Amount must be greater than zero");

    totalStakedTokens -= amount;
    stakedBalance[msg.sender] -= amount;

    // Update user's last paid reward per token to current reward per token
    userRewardperTokenPaid[msg.sender] = rewardPerToken();

    emit withDrawn(msg.sender, amount);

    bool success = s_stakingToken.transfer(msg.sender, amount);
    require(success, "Transfer failed");
}

     function getReward() external nonReentrant updateReward(msg.sender) { 
        uint reward =rewards[msg.sender]; 
        require(reward>0,"No rewards to claim");    
        rewards[msg.sender]=0; 
        emit RewardsClaimed(msg.sender, reward);
        bool success = s_rewardToken.transfer(msg.sender, reward);
        require(success,"Transfer Failed");
    }
}

