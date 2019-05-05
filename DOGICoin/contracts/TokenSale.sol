pragma solidity ^0.4.24;

import './lib/SafeMath.sol';
import './DOGICoin.sol';

/**
  * @dev 1. First you set the address of the wallet in the RefundVault contract that will store the deposit of ether
  *      2. If the goal is reached, the state of the vault will change and the ether will be sent to the address
  *      3. If the goal is not reached , the state of the vault will change to refunding and 
  *         the users will be able to call claimRefund() to get their ether
  * @author https://github.com/DOGi-Team
  */

contract TokenSale {
    using SafeMath for uint256;
    using SafeERC20 for DOGICoin;

    struct Tier {
        // 1 ether can buy tokens
        uint256 rate;
        // 1 ether can reward tokens 
        uint256 bonus;
        // tier end token
        uint256 limit;
    }
    
    // The token being sold
    DOGICoin public token;

    address public owner;
        
    // The start time of the Tokensale
    uint256 public startTime = now;
    
    // The end time of the Tokensale
    uint256 public endTime = now + 30 days;
           
    // The amount of wei raised
    uint256 public etherRaisedInWei = 0;
    
    // The amount of tokens raised
    uint256 public tokensRaised = 0;

    mapping (uint256 => Tier) tiers;
    
    uint256 public currentTier = 1;
        
    // Minimum amount of tokens to be raised
    uint256 public minGoal;
    
    // If refunding state
    bool public isRefunding = false;
    
    // If the Tokensale has ended or not
    bool public isEnded = false;
        
    // each account cost wei to buy tokens
    mapping(address => uint256) public balancesInWei;
    
    // each account have tokens
    mapping(address => uint256) public tokenPurchased;
    
    // To indicate who purchased what amount of tokens and who received what amount of wei
    event TokenPurchase(address indexed buyer, uint256 value, uint256 amountOfTokens);
    
    // Indicates if the Tokensale has ended
    event Finalized();
    
    /**
      * @dev Constructor of the crowsale to set up the main variables and create a token
      * @param _startTime token begin to sale
      * @param _endTime the soft cap end time
      * @param _minGoal minimum goal
      */
    constructor (uint256 _startTime,uint256 _endTime,uint256 _minGoal) public {
        require(_startTime != 0 && _endTime != 0 && _startTime < _endTime);
        startTime = _startTime;
        endTime = _endTime;
        minGoal = _minGoal;
        owner = msg.sender;
        token = new DOGICoin();
        uint256 total = token.totalSupply();
        uint256 tier1 = total * 5 / 100;
        uint256 tier2 = total * 5 / 100;
        uint256 tier3 = total * 7 / 100;
        uint256 tier4 = total * 1 / 100;
        uint256 tier5 = total * 1 / 100;
        uint256 tier6 = total * 1 / 100;
        tiers[1] = Tier(11250,80,tier1);
        tiers[2] = Tier(8750,40,tier2);
        tiers[3] = Tier(7820,25,tier3);
        tiers[4] = Tier(6889,10,tier4);
        tiers[5] = Tier(6586,5,tier5);
        tiers[6] = Tier(6256,0,tier6);
    }
        
    /// @dev To buy tokens given an address
    function buyTokens() public payable onlyOnSale {
        require(_validPurchase());
        uint256 bonusToken;
        uint256 buyToken;
        uint256 remain;
        uint256 actualAmountPaid;
        uint256 actualTokenPurchased;
        (bonusToken,buyToken,remain) = _calcBonusAndBuy();
        if(remain == 0){
            actualAmountPaid = msg.value;
        }else{
            actualAmountPaid = msg.value.sub(remain);
            msg.sender.transfer(remain);
        }
        actualTokenPurchased = bonusToken.add(buyToken);
        tokensRaised = tokensRaised.add(actualTokenPurchased);
        token.safeTransfer(msg.sender,buyToken);
        token.vestBonus(msg.sender,bonusToken);
        emit TokenPurchase(msg.sender, actualAmountPaid, actualTokenPurchased);
    }

    /**
     * @dev do not possible cross two tier
     */
    function _calcBonusAndBuy() internal returns(uint256 bonusToken,uint256 buyToken,uint256 remain)  {
        uint256 canUse;
        uint256 already = balancesInWei[msg.sender];
        (canUse,remain) = _canUse(msg.sender,msg.value);
        Tier storage thisTier = tiers[currentTier];
        buyToken = canUse.mul(thisTier.rate);
        bonusToken = canUse.mul(thisTier.bonus);
        if(tokensRaised.add(buyToken).add(bonusToken) > thisTier.limit){
            uint256 thisTierBuyToken;
            uint256 thisTierBonusToken;
            uint256 thisTierCost;
            (thisTierBuyToken,thisTierBonusToken,thisTierCost) = _specificTire(currentTier);
            balancesInWei[msg.sender] = already.add(thisTierCost);
            uint256 newValue = canUse.sub(thisTierCost);
            currentTier++;
            uint256 newCanUse;
            uint256 newRemain;
            (newCanUse,newRemain) = _canUse(msg.sender,newValue);
            thisTier = tiers[currentTier];
            buyToken = newCanUse.mul(thisTier.rate);
            bonusToken = newCanUse.mul(thisTier.bonus);

            already = balancesInWei[msg.sender];
            balancesInWei[msg.sender] = already.add(newCanUse);
            bonusToken = thisTierBonusToken.add(bonusToken);
            buyToken = thisTierBuyToken.add(buyToken);
            remain = remain.add(newRemain);
        }else{
            already = balancesInWei[msg.sender];
            balancesInWei[msg.sender] = already.add(canUse);
        }
    }

    function _canUse(address sender,uint256 value) internal view returns(uint256 canUse,uint256 remain)  {
        uint256 already = balancesInWei[sender];
        uint256 canBuy;
        uint256 limit;
        if(currentTier <= 3){
            limit = 800 ether;
        }else{
            limit = 100 ether;
        }
        canBuy = limit.sub(already);
        assert(canBuy > 0);
        if(canBuy >= value){
            canUse = value;
            remain = 0;
        }else{
            canUse = canBuy;
            remain = value.sub(canBuy);
        }
    }
    

    /**
     * @dev calc cross tier situation
     * @param tier which tier to calc
     */
    function _specificTire(uint256 tier) internal view returns(uint256 buyToken,uint256 bonusToken,uint256 actualCost)  {
        Tier storage thisTier = tiers[tier];
        uint256 thisTierCanBuy = thisTier.limit.sub(tokensRaised);
        actualCost = thisTierCanBuy.div((thisTier.rate.add(thisTier.bonus)));
        bonusToken = thisTierCanBuy.mul(thisTier.bonus).div(thisTier.rate);
        buyToken = thisTierCanBuy.sub(bonusToken);
    }  
   
   
    /**
     * @dev Checks if a purchase is considered valid
     * @return bool If the purchase is valid or not
     */
    function _validPurchase() internal view returns (bool) {
        if(msg.value <= 0)
            return false;
        if(now < startTime || now > endTime)
            return false;
        if(msg.value < 1 ether)
            return false;
        if(currentTier <= 3 && msg.value < 50 ether)
            return false;
        uint256 total = balancesInWei[msg.sender];
        if(total >= 800 ether)
            return false;
        if(currentTier > 3 && total >= 100 ether)
            return false;
        return true;
   }

    /// @dev Fallback function to buy tokens
    function () public payable {
        buyTokens();
    }

    modifier onlyOwner() { 
        require (msg.sender == owner); 
        _; 
    }

    modifier onlyOnSale() { 
        require (now >= startTime && now <= startTime); 
        _; 
    } 
    
}
