pragma solidity ^0.4.24;

import './lib/SafeMath.sol';
import './lib/Pausable.sol';
import './DOGICoin.sol';
import './RefundVault.sol';

/// 1. First you set the address of the wallet in the RefundVault contract that will store the deposit of ether
// 2. If the goal is reached, the state of the vault will change and the ether will be sent to the address
// 3. If the goal is not reached , the state of the vault will change to refunding and the users will be able to call claimRefund() to get their ether

/// @title Tokensale contract to carry out an ICO with the DOGICoin
/// Tokensale have a start and end timestamps, where investors can make
/// token purchases and the Tokensale will assign them tokens based
/// on a token per ETH rate. Funds collected are forwarded to a wallet
/// as they arrive.
/// @author https://github.com/DOGi-Team
contract TokenSale is Pausable {
    using SafeMath for uint256;
    
    // The token being sold
    DOGICoin public token;
    
    // The vault that will store the ether until the goal is reached
    RefundVault public vault;

    // 1 ether exchange 6256 DOGICoin
    uint256 public constant ethToDOGICoin = 6256;
    
    // The block number of when the Tokensale starts
    // 10/15/2017 @ 11:00am (UTC)
    // 10/15/2017 @ 12:00pm (GMT + 1)
    uint256 public startTime = 1508065200;
    
    // The block number of when the Tokensale ends
    // 11/13/2017 @ 11:00am (UTC)
    // 11/13/2017 @ 12:00pm (GMT + 1)
    uint256 public endTime = 1510570800;
    
    // The wallet that holds the Wei raised on the Tokensale
    address public wallet;

    // The wallet that holds the Wei raised on the Tokensale after soft cap reached
    address public walletB;
    
    // Max number of tires during token sale
    uint256 public constant MAX_NUM_TIRES = 6;
    
    // The amount of wei raised
    uint256 public etherRaisedInWei = 0;
    
    // The amount of tokens raised
    uint256 public tokensRaised = 0;
    
    // The rate of tokens per ether. Only applied for the first tier, the first
    // 35 million tokens sold
    uint256 public rateTier1 = 55;
    
    // The rate of tokens per ether. Only applied for the second tier, at between
    // 35 million tokens sold and 70 million tokens sold
    uint256 public rateTier2 = 70;
    
    // The rate of tokens per ether. Only applied for the third tier, at between
    // 70 million tokens sold and 119 million tokens sold
    uint256 public rateTier3 = 80;
    
    // The rate of tokens per ether. Only applied for the fourth tier, at between
    // 119 million tokens sold and 126 million tokens sold
    uint256 public rateTier4 = 90;
    
    // The rate of tokens per ether. Only applied for the fourth tier, at between
    // 126 million tokens sold and 133 million tokens sold
    uint256 public rateTier5 = 95;
    
    // The rate of tokens per ether. Only applied for the fourth tier, at between
    // 133 million tokens sold and 140 million tokens sold
    uint256 public rateTier6 = 100;
    
    // The maximum amount of tokens for tire1
    uint256 public limitTier1 = 35e6 * (10 ** token.decimals());
    
    // The maximum amount of tokens for tire1
    uint256 public limitTier2 = 70e6 * (10 ** token.decimals());
    
    // The maximum amount of tokens for tire1
    uint256 public limitTier3 = 119e6 * (10 ** token.decimals());
    
    // The maximum amount of tokens for tire1
    uint256 public limitTier4 = 126e6 * (10 ** token.decimals());
    
    // The maximum amount of tokens for tire1
    uint256 public limitTier5 = 133e6 * (10 ** token.decimals());
    
    // The maximum amount of tokens for tire6 which is also the max amount of tokens for token sale
    uint256 public maxTokensRaised = 140e6 * (10 ** token.decimals());
    
    // The minimum amount of Wei you must pay to participate in the cornerstone sale
    uint256 public constant minPurchaseCornerstone = 50 ether;
    
    // The minimum amount of Wei you must pay to participate in the private sale
    uint256 public constant minPurchasePrivatesale = 50 ether;
    
    // The minimum amount of Wei you must pay to participate in the Tokensale
    uint256 public constant minPurchaseCrowdsale = 1 ether;
    
    // The maximum amount of Wei you must pay to participate in the cornerstone sale
    uint256 public constant maxPurchaseCornerstone = 800 ether;
    
    // The maximum amount of Wei you must pay to participate in the private sale
    uint256 public constant maxPurchasePrivatesale = 800 ether;
    
    // The maximum amount of Wei you must pay to participate in the Tokensale
    uint256 public constant maxPurchaseCrowdsale = 100 ether;
    
    // Minimum amount of tokens to be raised. 7.5 million tokens which is the 15%
    // of the total of 50 million tokens sold in the Tokensale
    // 7.5e6 + 1e18
    uint256 public constant minimumGoal = 5.33e24;
    
    // If the Tokensale wasn't successful, this will be true and users will be able
    // to claim the refund of their ether
    //bool public isRefunding = false;
    
    // If the Tokensale has ended or not
    bool public isEnded = false;
    
    // The number of transactions
    //uint256 public numberOfTransactions;
    
    // The gas price to buy tokens must be 50 gwei or below
    //uint256 public limitGasPrice = 50000000000 wei;
    
    // How much each user paid for the Tokensale
    mapping(address => uint256) public balancesInWei;
    
    // How many tokens each user got for the Tokensale
    mapping(address => uint256) public tokenPurchased;
    
    // To indicate who purchased what amount of tokens and who received what amount of wei
    event TokenPurchase(address indexed buyer, uint256 value, uint256 amountOfTokens);
    
    // Indicates if the Tokensale has ended
    event Finalized();
    
    /// @notice Constructor of the crowsale to set up the main variables and create a token
    /// @param _wallet The wallet address that stores the Wei raised
    /// @param _tokenAddress The token used for the ICO
    constructor (
        address _wallet,
        address _tokenAddress,
        uint256 _startTime,
        uint256 _endTime)
    public {
        require(_startTime != 0 && _endTime != 0 && _startTime < _endTime &&
                _tokenAddress != address(0) && _wallet != address(0));
        wallet = _wallet;
        token = DOGICoin(_tokenAddress);
        vault = new RefundVault(_wallet);
    }
    
    /// @notice Fallback function to buy tokens
    function () payable {
        buyTokens();
    }
    
    /// @notice To buy tokens given an address
    function buyTokens() public payable whenNotPaused {
        require(_validPurchase());
        
        uint256 actualTokenPurchased = 0;
        uint256 actualAmountPaid = _calculateActualAmountToPay();
        
        if (tokensRaised < limitTier1) {
            actualTokenPurchased = actualAmountPaid.mul(rateTier1);
            
            if (tokensRaised.add(actualTokenPurchased) > limitTier1) {
                actualTokenPurchased = _handleCrossTirePurchase(actualAmountPaid, limitTier1, 1, rateTier1);
            }
        } else if (tokensRaised >= limitTier1 && tokensRaised < limitTier2) {
            actualTokenPurchased = actualAmountPaid.mul(rateTier2);
            
            if (tokensRaised.add(actualTokenPurchased) > limitTier2) {
                actualTokenPurchased = _handleCrossTirePurchase(actualAmountPaid, limitTier2, 2, rateTier2);
            }
        } else if (tokensRaised >= limitTier2 && tokensRaised < limitTier3) {
            actualTokenPurchased = actualAmountPaid.mul(rateTier3);
            
            if (tokensRaised.add(actualTokenPurchased) > limitTier3) {
                actualTokenPurchased = _handleCrossTirePurchase(actualAmountPaid, limitTier3, 3, rateTier3);
            }
        } else if(tokensRaised >= limitTier3) {
            actualTokenPurchased = actualAmountPaid.mul(rateTier4);
        }
        
        etherRaisedInWei = etherRaisedInWei.add(actualAmountPaid);
        uint256 tokensRaisedBeforeThisTransaction = tokensRaised;
        tokensRaised = tokensRaised.add(actualTokenPurchased);
        token.LockTokensWithTimeBasedVesting(msg.sender, actualTokenPurchased, 0, 0, 0);
        
        // Keep a record of how many tokens everybody gets in case we need to do refunds
        tokenPurchased[msg.sender] = tokenPurchased[msg.sender].add(actualTokenPurchased);
        emit TokenPurchase(msg.sender, actualAmountPaid, actualTokenPurchased);
        // numberOfTransactions = numberOfTransactions.add(1);
        
        /*
        if(tokensRaisedBeforeThisTransaction > minimumGoal) {
            walletB.transfer(actualAmountPaid);
        } else {
            vault.deposit.value(actualAmountPaid)(msg.sender);
            if(goalReached()) {
                vault.close();
            }
        }
        */
        
        // If the minimum goal of the ICO has been reach, close the vault to send
        // the ether to the wallet of the Tokensale
        //checkCompletedTokensale();
    }
   
    /// @notice Calculates how many ether will be used to generate the tokens in
    /// case the buyer sends more than the maximum balance but has some balance left
    /// and updates the balance of that buyer.
    /// For instance if he's 500 balance and he sends 1000, it will return 500
    /// and refund the other 500 ether
    function _calculateActualAmountToPay() internal whenNotPaused returns (uint256 amountPaid) {
        amountPaid = msg.value;
        uint256 amountExceedLimitInWei = 0;
        uint256 amountExceedMaxInWei = 0;
        
        // If we're in the last tier, check that the limit hasn't been reached
        // and if so, refund the difference and return what will be used to
        // buy the remaining tokens
        if (tokensRaised >= limitTier5) {
            uint256 tokensCanBuy = amountPaid.mul(10 ** token.decimals()).div(1 ether).mul(rateTier6);
            //uint256 addedTokens = tokensRaised.add(amountPaid.mul(rateTier4));
            
            // If tokensRaised + what you paid converted to tokens is bigger than the max
            if (tokensRaised.add(tokensCanBuy) > maxTokensRaised) {
                // Refund the difference
                amountExceedLimitInWei = tokensRaised.add(tokensCanBuy).sub(maxTokensRaised).div(rateTier6);
                amountPaid = amountPaid.sub(amountExceedLimitInWei);
            }
        }
        
        uint256 addedBalance = balancesInWei[msg.sender].add(amountPaid);
        uint256 maxPurchase = _calculateMaxPurchase();
        
        // Checking that the individual limit of 1000 ETH per user is not reached
        if (addedBalance > maxPurchase) {
            amountExceedMaxInWei = addedBalance.sub(maxPurchase);
            amountPaid = amountPaid.sub(amountExceedMaxInWei);
        }

        balancesInWei[msg.sender] = balancesInWei[msg.sender].add(amountPaid);
        
        // Make the transfers at the end of the function for security purposes
        if (amountExceedLimitInWei > 0) {
            msg.sender.transfer(amountExceedLimitInWei);
        }
        
        if (amountExceedMaxInWei > 0) {
            msg.sender.transfer(amountExceedMaxInWei);
        }
    }
   
    /// @notice Handle the cross tire purchase
    /// @param _amountInWei The amount of ether in wei paid to buy the tokens
    /// @param _tire The tier selected
    /// @param _limit The limit of tokens of that tier
    /// @param _rate The rate used for that `_tire`
    /// @return uint The total amount of tokens bought combining the tier prices
    function _handleCrossTirePurchase(
        uint256 _amountInWei,
        uint256 _tire,
        uint256 _limit,
        uint256 _rate
    ) public returns(uint256 totalTokens) {
        require(_amountInWei > 0 && _limit > 0 && _rate > 0 && _limit > tokensRaised);
        require(_tire >= 1 && _tire <= MAX_NUM_TIRES);
        
        uint256 weiThisTier = _limit.sub(tokensRaised).mul(1 ether).div(10 ** token.decimals()).div(_rate);
        uint256 weiNextTier = _amountInWei.sub(weiThisTier);
        uint256 numTokensNextTier = 0;
        bool returnTokens = false;
        
        // If there's excessive wei for the last tier, refund those
        if(_tire != MAX_NUM_TIRES) {
            numTokensNextTier = _calculateNumTokensCanBuy(weiNextTier, _tire.add(1));
        } else {
            returnTokens = true;
        }
        
        totalTokens = _limit.sub(tokensRaised).add(numTokensNextTier);
        
        // Do the transfer at the end
        if(returnTokens) {
            msg.sender.transfer(weiNextTier);
        }
    }
    
    /// @notice Buys the tokens given the price of the tier and the wei paid
    /// @param _amountInWei The amount of wei paid that will be used to buy tokens
    /// @param _tire The tier that you'll use for thir purchase
    /// @return calculatedTokens Returns how many tokens you've bought for that wei paid
    function _calculateNumTokensCanBuy(uint256 _amountInWei, uint256 _tire) internal constant returns(uint256) {
        require(_amountInWei > 0);
        require(_tire >= 1 && _tire <= MAX_NUM_TIRES);

        uint256 numTokens = 0;

        if (_tire == 1) {
            numTokens = _amountInWei.mul(10 ** token.decimals()).div(1 ether).mul(rateTier1);
        } else if(_tire == 2) {
            numTokens = _amountInWei.mul(10 ** token.decimals()).div(1 ether).mul(rateTier2);
        } else if(_tire == 3) {
            numTokens = _amountInWei.mul(10 ** token.decimals()).div(1 ether).mul(rateTier3);
        } else if(_tire == 4) {
            numTokens = _amountInWei.mul(10 ** token.decimals()).div(1 ether).mul(rateTier4);
        } else if(_tire == 5) {
            numTokens = _amountInWei.mul(10 ** token.decimals()).div(1 ether).mul(rateTier5);
        } else if(_tire == 6) {
            numTokens = _amountInWei.mul(10 ** token.decimals()).div(1 ether).mul(rateTier6);
        }

        return numTokens;
    }
    
    /// @notice Mininum ETH should be paid for the current tire
    /// @return Returns the mininum ETH should be paid for the current tire
    function _calculateMinPurchase() internal constant returns (uint256) {
        uint256 minPurchase = minPurchaseCornerstone;

        if(tokensRaised < limitTier1) {
            minPurchase = minPurchaseCornerstone;
        } else if(tokensRaised >= limitTier1 && tokensRaised < limitTier3) {
            minPurchase = minPurchasePrivatesale;
        } else if(tokensRaised >= limitTier3 && tokensRaised < maxTokensRaised) {
            minPurchase = minPurchaseCrowdsale;
        }

        return minPurchase;
    }
    
    /// @notice Maximum ETH could be paid for the current tire
    /// @return Returns the maximum ETH could be paid for the current tire
    function _calculateMaxPurchase() internal constant returns (uint256) {
        uint256 maxPurchase = maxPurchaseCornerstone;

        if(tokensRaised < limitTier1) {
            maxPurchase = maxPurchaseCornerstone;
        } else if(tokensRaised >= limitTier1 && tokensRaised < limitTier3) {
            maxPurchase = maxPurchasePrivatesale;
        } else if(tokensRaised >= limitTier3 && tokensRaised < maxTokensRaised) {
            maxPurchase = maxPurchaseCrowdsale;
        }

        return maxPurchase;
    }
    
    /// @notice Checks if a purchase is considered valid
    /// @return bool If the purchase is valid or not
    function _validPurchase() internal constant returns (bool) {
        bool nonZeroPurchase = msg.value > 0;
        bool withinPeriod = now >= startTime && now <= endTime;
        bool withinTokenLimit = tokensRaised < maxTokensRaised;
        bool minimumPurchase = (msg.value >= _calculateMinPurchase());
        bool hasBalanceAvailable = (balancesInWei[msg.sender] < _calculateMaxPurchase());

        // We want to limit the gas to avoid giving priority to the biggest paying contributors
        //bool limitGas = tx.gasprice <= limitGasPrice;
        
        return nonZeroPurchase && withinPeriod && withinTokenLimit && minimumPurchase && hasBalanceAvailable;
   }
}
