/*
▒█▀▀█ █▀▀█ █▀▀█ █▀▀ █▀▀█ ▒█▀▀█ █▀▀█ █░░█ █▀▀▄ ▀▀█▀▀ █░░█ 
▒█░░░ █░░█ █▄▄▀ ▀▀█ █░░█ ▒█░░░ █░░█ █░░█ █░░█ ░░█░░ █▄▄█ 
▒█▄▄█ ▀▀▀▀ ▀░▀▀ ▀▀▀ ▀▀▀▀ ▒█▄▄█ ▀▀▀▀ ░▀▀▀ ▀░░▀ ░░▀░░ ▄▄▄█
*/
/*
                                                                                                                                                                                                      
                                                        d8   ,ad8888ba,                                                      ,ad8888ba,                                                               
  ,d                                                  ,8P'  d8"'    `"8b                                                    d8"'    `"8b                                          ,d                  
  88                                                 d8"   d8'                                                             d8'                                                    88                  
MM88MMM       88,dPYba,,adPYba,    ,adPPYba,       ,8P'    88              ,adPPYba,   8b,dPPYba,  ,adPPYba,   ,adPPYba,   88              ,adPPYba,   88       88  8b,dPPYba,  MM88MMM  8b       d8  
  88          88P'   "88"    "8a  a8P_____88      d8"      88             a8"     "8a  88P'   "Y8  I8[    ""  a8"     "8a  88             a8"     "8a  88       88  88P'   `"8a   88     `8b     d8'  
  88          88      88      88  8PP"""""""    ,8P'       Y8,            8b       d8  88           `"Y8ba,   8b       d8  Y8,            8b       d8  88       88  88       88   88      `8b   d8'   
  88,    888  88      88      88  "8b,   ,aa   d8"          Y8a.    .a8P  "8a,   ,a8"  88          aa    ]8I  "8a,   ,a8"   Y8a.    .a8P  "8a,   ,a8"  "8a,   ,a88  88       88   88,      `8b,d8'    
  "Y888  888  88      88      88   `"Ybbd8"'  8P'            `"Y8888Y"'    `"YbbdP"'   88          `"YbbdP"'   `"YbbdP"'     `"Y8888Y"'    `"YbbdP"'    `"YbbdP'Y8  88       88   "Y888      Y88'     
                                                                                                                                                                                             d8'      
                                                                                                                                                                                            d8'          
*/
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract CorsoKennel is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 pendingRewards;
        uint256 lastClaim;
    }

    struct PoolInfo {
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accCorsoPerShare;
        uint256 depositedAmount;
        uint256 rewardsAmount;
        uint256 lockupDuration;
    }

    IERC20 public corso;
    uint256 public corsoPerBlock = uint256(80 ether) / (10); //8 corso

    PoolInfo[] public poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    uint256 public totalAllocPoint = 10;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event Claim(address indexed user, uint256 indexed pid, uint256 amount);
    event ClaimAndStake(address indexed user, uint256 indexed pid, uint256 amount);

    function addPool(uint256 _allocPoint, uint256 _lockupDuration) internal {
        poolInfo.push(
            PoolInfo({
                allocPoint: _allocPoint,
                lastRewardBlock: 0,
                accCorsoPerShare: 0,
                depositedAmount: 0,
                rewardsAmount: 0,
                lockupDuration: _lockupDuration
            })
        );
    }
    
    function setCorsoToken(IERC20 _corso) external onlyOwner {
        require(address(corso) == address(0), 'Token already set!');
        corso = _corso;
        addPool(1, 0); //10% staking pool
        addPool(3, 7 days); //30% staking pool
        addPool(6, 30 days); //60% staking pool
    }
    
    function startStaking(uint256 startBlock) external onlyOwner {
        require(poolInfo[0].lastRewardBlock == 0 && poolInfo[1].lastRewardBlock == 0 && poolInfo[2].lastRewardBlock == 0, 'Staking already started');
        poolInfo[0].lastRewardBlock = startBlock;
        poolInfo[1].lastRewardBlock = startBlock;
        poolInfo[2].lastRewardBlock = startBlock;
        
    }

    function pendingRewards(uint256 pid, address _user) external view returns (uint256) {
        require(poolInfo[pid].lastRewardBlock > 0 && block.number >= poolInfo[pid].lastRewardBlock, 'Staking not yet started');
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][_user];
        uint256 accCorsoPerShare = pool.accCorsoPerShare;
        uint256 depositedAmount = pool.depositedAmount;
        if (block.number > pool.lastRewardBlock && depositedAmount != 0) {
            uint256 multiplier = block.number - (pool.lastRewardBlock);
            uint256 corsoReward = multiplier * (corsoPerBlock) * (pool.allocPoint) / (totalAllocPoint);
            accCorsoPerShare = accCorsoPerShare + (corsoReward * (1e12) / (depositedAmount));
        }
        return user.amount * (accCorsoPerShare) / (1e12) - (user.rewardDebt) + (user.pendingRewards);
    }

    function updatePool(uint256 pid) internal {
        require(poolInfo[pid].lastRewardBlock > 0 && block.number >= poolInfo[pid].lastRewardBlock, 'Staking not yet started');
        PoolInfo storage pool = poolInfo[pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 depositedAmount = pool.depositedAmount;
        if (pool.depositedAmount == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = block.number - (pool.lastRewardBlock);
        uint256 corsoReward = multiplier * (corsoPerBlock) * (pool.allocPoint) / (totalAllocPoint);
        pool.rewardsAmount = pool.rewardsAmount + (corsoReward);
        pool.accCorsoPerShare = pool.accCorsoPerShare + (corsoReward * (1e12) / (depositedAmount));
        pool.lastRewardBlock = block.number;
    }

    function deposit(uint256 pid, uint256 amount) external {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        updatePool(pid);
        if (user.amount > 0) {
            uint256 pending = user.amount * (pool.accCorsoPerShare) / (1e12) - (user.rewardDebt);
            if (pending > 0) {
                user.pendingRewards = user.pendingRewards + (pending);
            }
        }
        if (amount > 0) {
            corso.safeTransferFrom(address(msg.sender), address(this), amount);
            user.amount = user.amount + (amount);
            pool.depositedAmount = pool.depositedAmount + (amount);
        }
        user.rewardDebt = user.amount * (pool.accCorsoPerShare) / (1e12);
        user.lastClaim = block.timestamp;
        emit Deposit(msg.sender, pid, amount);
    }

    function withdraw(uint256 pid, uint256 amount) external {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        require(block.timestamp > user.lastClaim + pool.lockupDuration, "You cannot withdraw yet!");
        require(user.amount >= amount, "Withdrawing more than you have!");
        updatePool(pid);
        uint256 pending = user.amount * (pool.accCorsoPerShare) / (1e12) - (user.rewardDebt);
        if (pending > 0) {
            user.pendingRewards = user.pendingRewards + (pending);
        }
        if (amount > 0) {
            corso.safeTransfer(address(msg.sender), amount);
            user.amount = user.amount - (amount);
            pool.depositedAmount = pool.depositedAmount - (amount);
        }
        user.rewardDebt = user.amount * (pool.accCorsoPerShare) / (1e12);
        user.lastClaim = block.timestamp;
        emit Withdraw(msg.sender, pid, amount);
    }

    function claim(uint256 pid) public {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        updatePool(pid);
        uint256 pending = user.amount * (pool.accCorsoPerShare) / (1e12) - (user.rewardDebt);
        if (pending > 0 || user.pendingRewards > 0) {
            user.pendingRewards = user.pendingRewards + (pending);
            uint256 claimedAmount = safeCorsoTransfer(msg.sender, user.pendingRewards, pid);
            emit Claim(msg.sender, pid, claimedAmount);
            user.pendingRewards = user.pendingRewards - (claimedAmount);
            user.lastClaim = block.timestamp;
            pool.rewardsAmount = pool.rewardsAmount - (claimedAmount);
        }
        user.rewardDebt = user.amount * (pool.accCorsoPerShare) / (1e12);
    }
    
    function safeCorsoTransfer(address to, uint256 amount, uint256 pid) internal returns (uint256) {
        PoolInfo memory pool = poolInfo[pid];
        if (amount > pool.rewardsAmount) {
            corso.transfer(to, pool.rewardsAmount);
            return pool.rewardsAmount;
        } else {
            corso.transfer(to, amount);
            return amount;
        }
    }
    
    function setCorsoPerBlock(uint256 _corsoPerBlock) external onlyOwner {
        require(_corsoPerBlock > 0, "corso per block should be greater than 0!");
        corsoPerBlock = _corsoPerBlock;
    }
}