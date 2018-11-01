pragma solidity ^0.4.24;

import 'openzeppelin-solidity/contracts/math/SafeMath.sol';
import 'openzeppelin-solidity/contracts/token/ERC20/PausableToken.sol';
import 'openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol';

contract SingleVesting {
    using SafeMath for uint256;
    using SafeERC20 for ERC20Basic;
    
    event Released(uint256 amount);
    
    address public beneficiary;
    uint256 public cliff;
    uint256 public start;
    uint256 public duration;
    
    mapping (address => uint256) public released;

    /**
     * @dev Creates a vesting contract that vests its balance of any ERC20 token to the
     * _beneficiary, gradually in a linear fashion until _start + _duration. By then all
     * of the balance will have vested.
     * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
     * @param _start start timestamp
     * @param _cliff duration in seconds of the cliff in which tokens will begin to vest
     * @param _duration duration in seconds of the period in which the tokens will vest
    */
    constructor (address _beneficiary, uint256 _start, uint256 _cliff, uint256 _duration) public {
        require(_beneficiary != address(0));
        require(_cliff <= _duration);
        
        beneficiary = _beneficiary;
        duration = _duration;
        cliff = _start.add(_cliff);
        start = _start;
    }
    
    /**
     * @notice Transfers vested tokens to beneficiary.
     * @param token ERC20 token which is being vested
    */
    function release(ERC20Basic token) public {
        uint256 unreleased = releasableAmount(token);
        
        require(unreleased > 0);
        
        released[token] = released[token].add(unreleased);
        
        token.safeTransfer(beneficiary, unreleased);
        
        emit Released(unreleased);
    }
    
    /**
     * @dev Calculates the amount that has already vested but hasn't been released yet.
     * @param token ERC20 token which is being vested
    */
    function releasableAmount(ERC20Basic token) public view returns (uint256) {
        return vestedAmount(token).sub(released[token]);
    }
    
    /**
     * @dev Calculates the amount that has already vested.
     * @param token ERC20 token which is being vested
    */
    function vestedAmount(ERC20Basic token) public view returns (uint256) {
        uint256 currentBalance = token.balanceOf(this);
        uint256 totalBalance = currentBalance.add(released[token]);
        
        if (now < cliff) {
            return 0;
        } else if (now >= start.add(duration)) {
            return totalBalance;
        } else {
            //return totalBalance.mul(now.sub(start)).div(duration);
            uint256 elapsed = now.sub(cliff);
            uint256 percent = (elapsed.div(30 days)).add(1);
            percent = percent > 12 ? 12 : percent;
            return totalBalance.mul(percent).div(12);
        }
    }
}

contract VestingToken is PausableToken {
    
    mapping (address => SingleVesting) public vesting;
    
    // member function that can be called to release vested tokens periodically
    function releaseVestedTokens(address beneficiary) public {
        require(beneficiary != 0x0);
        
        SingleVesting tokenVesting = vesting[beneficiary];
        tokenVesting.release(this);
    }
}

// @title The DOGICoin
/// @author https://github.com/DOGi-Team
contract DOGICoin is VestingToken {
    using SafeMath for uint256;
    
    string public constant name = 'DOGI';
    
    string public constant symbol = 'DOGI';
    
    uint256 public constant decimals = 18;
    
    uint256 public totalSupply = 0;
    
    // The tokens already used for the ICO buyers
    uint256 public tokensDistributedCrowdsale = 0;
    
    // The address of the crowdsale
    address public crowdsale;
    
    // The initial supply used for platform and development as specified in the whitepaper
    uint256 public initialSupply = 0;
    
    // The maximum amount of tokens sold in the crowdsale
    uint256 public limitCrowdsale = 0;
    
    /// @notice Only allows the execution of the function if it's comming from crowdsale
    modifier onlyCrowdsale() {
        require(msg.sender == crowdsale);
        _;
    }
    
    /// @notice Constructor used to set the platform & development tokens. This is
    /// The 20% + 20% of the 100 M tokens used for platform and development team.
    /// The owner, msg.sender, is able to do allowance for other contracts. Remember
    /// to use `transferFrom()` if you're allowed
    constructor() public {
        balances[msg.sender] = initialSupply; // 40M tokens wei
    }
    
    /// @notice Function to set the crowdsale smart contract's address only by the owner of this token
    /// @param _crowdsale The address that will be used
    function setCrowdsaleAddress(address _crowdsale) external onlyOwner whenNotPaused {
        require(_crowdsale != address(0));
        crowdsale = _crowdsale;
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