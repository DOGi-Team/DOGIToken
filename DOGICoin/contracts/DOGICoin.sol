pragma solidity ^0.4.24;

import './lib/SafeMath.sol';
import "./lib/ERC20.sol";
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
    uint256 public releasedMonth = 0;

    // released finished
    bool public done = false;

    // vest bonus
    uint256 public bonus;

    // every 30 days can release token amount,not include last month
    uint256 public monthRelease;

    // approve address
    address public approveAddr;
    

    /**
     * @dev Creates a vesting contract that vests its balance of DOGICoin token
     * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
     * @param _bonus vest amount
     * @param _approveAddr approve address
    */
    constructor (address _beneficiary,uint256 _bonus,address _approveAddr) public {
        require(_beneficiary != address(0));
        beneficiary = _beneficiary;
        start = now;
        approveAddr = _approveAddr;
        bonus = _bonus;
        monthRelease = _bonus / 12;
    }
    
    /**
     * @dev release vest token
     * @param token token address
    */
    function release(DOGICoin token) public {
        uint256 canReleasedMonth = (now - start) / 30 days;
        uint256 month = canReleasedMonth.sub(releasedMonth);
        if(month <= 0)
            return; 
        uint256 amount;
        if(canReleasedMonth < 12) {
            amount = month.mul(monthRelease);
        } else {
            // last time release
            amount = bonus.sub(releasedMonth.mul(monthRelease));
            done = true;
        }
        releasedMonth = canReleasedMonth;
        token.safeTransferFrom(approveAddr,msg.sender,amount);
        emit Released(amount);   
    }
}

/**
 * @title DOGICoin
 * @dev https://github.com/DOGi-Team
 */
contract DOGICoin is ERC20 {
    using SafeMath for uint256;
    using SafeERC20 for DOGICoin;
    
    string public constant name = 'DOGI';
    
    string public constant symbol = 'DOGI';

    mapping (address => SingleVesting) private vesting;
    
    function releaseVestedTokens(address beneficiary) public {      
        SingleVesting tokenVesting = vesting[beneficiary];
        require(tokenVesting != address(0));
        tokenVesting.release(this);
    }
   
    /**
     * @dev vest bonus
     * @param beneficiary vest address
     * @param bonus vest tokens
     */
    function vestBonus(address beneficiary, uint256 bonus) public {
        require(beneficiary != 0x0 && bonus > 0);
        this.safeApprove(beneficiary,bonus);
        vesting[beneficiary] = new SingleVesting(beneficiary,bonus,tokenConctractOwner);
    }    
}