pragma solidity ^0.4.24;

import './lib/SafeMath.sol';
import './lib/ERC20Pausable.sol';
import './lib/SafeERC20.sol';

contract SingleVesting {
    using SafeMath for uint256;
    using SafeERC20 for DOGICoin;
    
    event Released(uint256 amount);
    
    // vest address
    address public beneficiary;
    
    // vest start time
    uint256 public start;
    
    // already released month nums
    uint256 public relasedMonth = 0;

    // released finished
    uint256 public done = false;

    // vest bonus
    uint256 public bonus;

    // every 30 days can release amount,not include last month
    uint256 public monthRelease;

    // approve address
    address public tokenOwner;
    

    /**
     * @dev Creates a vesting contract that vests its balance of DOGICoin token
     * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
     * @param _start start timestamp
     * @param _bouns vest amount
    */
    constructor (address _beneficiary, uint256 _start,uint256 _bonus,address _tokenOwner) public {
        require(_beneficiary != address(0));
        beneficiary = _beneficiary;
        start = _start;
        tokenOwner = _tokenOwner;
        bonus = _bonus;
        monthRelease = _bonus / 12;
    }
    
    /**
     * @dev release vest token
     * @param DOGICoin
    */
    function release(DOGICoin token) public {
        require (msg.sender == beneficiary);
        uint256 canReleasedMonth = (now - start) / 30 days;
        uint256 month = canReleasedMonth.sub(releasedMonth);
        if(month <= 0)
            return; 
        uint256 amount；
        if(canReleasedMonth < 12) {
            amount = month.mul(monthRelease);
        } else {
            // last time release
            amount = bonus.sub(releasedMonth.mul(monthRelease));
            done = true;
        }
        releasedMonth = canReleasedMonth;
        token.safeTransferFrom(tokenOwner,msg.sender,amount);
        emit Released(unreleased);   
    }
}

contract VestingToken is ERC20Pausable {
    
    mapping (address => SingleVesting) public vesting;
    
    function releaseVestedTokens() public {      
        SingleVesting tokenVesting = vesting[msg.sender];
        require(tokenVesting != address(0));
        tokenVesting.release(this);
    }
}


/**
 * @title DOGICoin
 * @dev https://github.com/DOGi-Team
 */
contract DOGICoin is VestingToken {
    using SafeMath for uint256;
    
    string public constant name = 'DOGI';
    
    string public constant symbol = 'DOGI';
    
    uint256 public constant decimals = 18;
    
    uint256 public totalSupply = 7e28;
    
    // The tokens already used for the ICO buyers
    uint256 public tokensDistributedCrowdsale = 0;
    
    
    /**
     * @dev constructor
     */
    constructor() public {
        balances[msg.sender] = totalSupply;
    }
    

    /// @notice member function to mint time based vesting tokens to a beneficiary
    /// @param beneficiary The buyer address
    /// @param tokens The amount of tokens to send to that address
    /// @param start The buyer address
    /// @param cliff The amount of tokens to send to that address
    /// @param duration The amount of tokens to send to that address
    function LockTokensWithTimeBasedVesting (
        address beneficiary,
        uint256 tokens,
        uint256 start,
        uint256 cliff,
        uint256 duration
    ) public onlyOwner {
        require(beneficiary != 0x0);
        require(tokens > 0);

        // Check that the limit of 50M ICO tokens hasn't been met yet
        require(tokensDistributedCrowdsale < limitCrowdsale);
        require(tokensDistributedCrowdsale.add(tokens) <= limitCrowdsale);
        
        tokensDistributedCrowdsale = tokensDistributedCrowdsale.add(tokens);
        
        vesting[beneficiary] = new SingleVesting(beneficiary, start, cliff, duration);
        _lock(address(vesting[beneficiary]), tokens);
    }    
    
    /// @notice Function to lock tokens
    /// @param _to The address that will receive the minted tokens.
    /// @param _amount The amount of tokens to mint.
    /// @return A boolean that indicates if the operation was successful.
    function _lock(address _to, uint256 _amount) internal returns (bool) {
        totalSupply = totalSupply.add(_amount);
        balances[_to] = balances[_to].add(_amount);
        emit Transfer(address(0), _to, _amount);
        return true;
    }
}