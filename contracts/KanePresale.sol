// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@OpenZeppelin/contracts/utils/Context.sol";
import "@OpenZeppelin/contracts/token/ERC20/IERC20.sol";
import "@OpenZeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@OpenZeppelin/contracts/utils/math/SafeMath.sol";
import "@OpenZeppelin/contracts/utils/Address.sol";
import "@OpenZeppelin/contracts/access/Ownable.sol";

contract KanePresale is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    IERC20 public kane;
    
    mapping (address => bool) public whitelistedAddresses;

    uint256 public kaneTarget;
    uint256 public weiTarget;
    uint256 public multiplier;
    bool public startUnlocked;
    bool public endUnlocked;
    bool public claimUnlocked;
    uint256 public minWei;
    uint256 public maxWei;

    uint256 public totalOwed;
    mapping(address => uint256) public claimable;
    uint256 public weiRaised;
    
    constructor(
        IERC20 _kane,
        uint256 _kaneTarget,
        uint256 _weiTarget,
        uint256 _minWei,
        uint256 _maxWei
    ) {
        kane = _kane;
        kaneTarget = _kaneTarget;
        weiTarget = _weiTarget;
        multiplier = kaneTarget.div(weiTarget);
        minWei = _minWei;
        maxWei = _maxWei;
    }
    
    event StartUnlockedEvent(uint256 startTimestamp);
    event EndUnlockedEvent(uint256 endTimestamp);
    event ClaimUnlockedEvent(uint256 claimTimestamp);
    
    function setKaneTarget(uint256 _kaneTarget) external onlyOwner {
        require(!startUnlocked, 'Presale already started!');
        kaneTarget = _kaneTarget;
        multiplier = kaneTarget.div(weiTarget);
    }
    
    function setWeiTarget(uint256 _weiTarget) external onlyOwner {
        require(!startUnlocked, 'Presale already started!');
        weiTarget = _weiTarget;
        multiplier = kaneTarget.div(weiTarget);
    }
    
    function unlockStart() external onlyOwner {
        require(!startUnlocked, 'Presale already started!');
        startUnlocked = true;
        StartUnlockedEvent(block.timestamp);
    }
    function unlockEnd() external onlyOwner {
        require(!endUnlocked, 'Presale already ended!');
        endUnlocked = true;
        EndUnlockedEvent(block.timestamp);
    }
    function unlockClaim() external onlyOwner { 
        require(!claimUnlocked, 'Claim already allowed!');
        claimUnlocked = true; 
        ClaimUnlockedEvent(block.timestamp);
    }
    function setMinWei(uint256 _minWei) external onlyOwner {
        require(!startUnlocked, 'Presale already started!');
        minWei = _minWei;
        
    }
    function setMaxWei(uint256 _maxWei) external onlyOwner {
        require(!startUnlocked, 'Presale already started!');
        maxWei = _maxWei;
    }
    
    function addWhitelistedAddress(address _address) external onlyOwner {
        whitelistedAddresses[_address] = true;
    }
    
    function addMultipleWhitelistedAddresses(address[] calldata _addresses) external onlyOwner {
         for (uint i=0; i<_addresses.length; i++) {
             whitelistedAddresses[_addresses[i]] = true;
         }
    }

    function removeWhitelistedAddress(address _address) external onlyOwner {
        whitelistedAddresses[_address] = false;
    }
    
    function withdrawWei(uint256 amount) public onlyOwner {
        require(endUnlocked, 'presale has not yet ended');
        msg.sender.transfer(amount);   
    }
    
    function claimableAmount(address user) external view returns (uint256) {
        return claimable[user].mul(multiplier);
    }

    function withdrawToken() external onlyOwner {
        require(endUnlocked, "presale has not yet ended");
        kane.transfer(msg.sender, kane.balanceOf(address(this)).sub(totalOwed));
    }

    function claim() external {
        require(claimUnlocked, "claiming not allowed yet");
        require(claimable[msg.sender] > 0, "nothing to claim");

        uint256 amount = claimable[msg.sender].mul(multiplier);

        claimable[msg.sender] = 0;
        totalOwed = totalOwed.sub(amount);

        require(kane.transfer(msg.sender, amount), "failed to claim");
    }

    function buy() public payable {
        require(startUnlocked, "presale has not yet started");
        require(!endUnlocked, "presale already ended");
        require(msg.value >= minWei, "amount too low");
        require(weiRaised.add(msg.value) <= weiTarget, "target already hit");
        require(whitelistedAddresses[msg.sender] == true, "you are not whitelisted");
        
        uint256 amount = msg.value.mul(multiplier);
        require(totalOwed.add(amount) <= kane.balanceOf(address(this)), "sold out");
        require(claimable[msg.sender].add(msg.value) <= maxWei, "maximum purchase cap hit");

        claimable[msg.sender] = claimable[msg.sender].add(msg.value);
        totalOwed = totalOwed.add(amount);
        weiRaised = weiRaised.add(msg.value);
    }
    
    fallback() external payable { buy(); }
    receive() external payable { buy(); }
}
