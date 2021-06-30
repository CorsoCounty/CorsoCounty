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
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../tokens/Cane.sol";


contract Molossus is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    struct UserInfo {
        uint256 amount; 
        uint256 rewardDebt; 
    }
 
    struct PoolInfo {
        IERC20 lpToken;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accCanePerShare;
    }
 
    CaneToken public cane;
    address public devaddr;
   
    uint256 public bonusEndBlock;
    uint256 public canePerBlock;
    uint256 public constant BONUS_MULTIPLIER = 10;
    PoolInfo[] public poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    uint256 public totalAllocPoint = 0;
    uint256 public startBlock;
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor(
        CaneToken _cane,
        address _devaddr,
        uint256 _canePerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock
    ) public {
        cane = _cane;
        devaddr = _devaddr;
        canePerBlock = _canePerBlock;
        bonusEndBlock = _bonusEndBlock;
        startBlock = _startBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock =
            block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accCanePerShare: 0
            })
        );
    }

    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
    }



    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        if (_to <= bonusEndBlock) {
            return _to.sub(_from).mul(BONUS_MULTIPLIER);
        } else if (_from >= bonusEndBlock) {
            return _to.sub(_from);
        } else {
            return
                bonusEndBlock.sub(_from).mul(BONUS_MULTIPLIER).add(
                    _to.sub(bonusEndBlock)
                );
        }
    }

    function pendingCane(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accCanePerShare = pool.accCanePerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier =
                getMultiplier(pool.lastRewardBlock, block.number);
            uint256 caneReward =
                multiplier.mul(canePerBlock).mul(pool.allocPoint).div(
                    totalAllocPoint
                );
            accCanePerShare = accCanePerShare.add(
                caneReward.mul(1e12).div(lpSupply)
            );
        }
        return user.amount.mul(accCanePerShare).div(1e12).sub(user.rewardDebt);
    }

    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 caneReward =
            multiplier.mul(canePerBlock).mul(pool.allocPoint).div(
                totalAllocPoint
            );
        cane.mint(devaddr, caneReward.div(10));
        cane.mint(address(this), caneReward);
        pool.accCanePerShare = pool.accCanePerShare.add(
            caneReward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending =
                user.amount.mul(pool.accCanePerShare).div(1e12).sub(
                    user.rewardDebt
                );
            safeCaneTransfer(msg.sender, pending);
        }
        pool.lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accCanePerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending =
            user.amount.mul(pool.accCanePerShare).div(1e12).sub(
                user.rewardDebt
            );
        safeCaneTransfer(msg.sender, pending);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accCanePerShare).div(1e12);
        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    function safeCaneTransfer(address _to, uint256 _amount) internal {
        uint256 caneBal = cane.balanceOf(address(this));
        if (_amount > caneBal) {
            cane.transfer(_to, caneBal);
        } else {
            cane.transfer(_to, _amount);
        }
    }

    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }
}