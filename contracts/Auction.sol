pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Interfaces.sol";


contract Auction is Context, Ownable {
    using SafeMath for uint256;

    struct LPStake {
        uint256 amount;
        uint256 lastUnlockTime;
    }

    uint256 private constant DAILY_MINT_CAP = 2_500_000 * 10 ** 18;
    uint256 private constant PERCENT_100 = 10**18;
    uint256 private constant SECONDS_IN_DAY = 86400;

    uint256[] private _mintTimes;
    uint256[] private _stakeTimes;
    uint256[] private _lpStakeTimes;
    // timestamp => address => data
    mapping(uint256 => mapping(address => uint256)) private _dailyParticipatedETH;
    mapping(uint256 => mapping(address => uint256)) private _dailyStakedUnic;
    mapping(uint256 => mapping(address => LPStake)) private _LPStakes;
    // timestamp => data
    mapping(uint256 => uint256) private _dailyTotalParticipatedETH;
    mapping(uint256 => uint256) private _accumulativeStakedUnic;
    mapping(uint256 => uint256) private _accumulativeStakedLP;
    
    
   
    address payable private _teamAddress;
    uint256 private _teamETHShare;
    bool private _isFirstDayETHTaken;

    IUnicToken private _unicToken;

    event Stake(uint256 amount, uint256 stakeTime, address account);
    event Unstake(uint256 reward, uint256 stakeTime, address account);

    constructor(address unicTokenAddress, uint256 mintTime, address payable teamAddress) public {
        require(unicTokenAddress != address(0), "ZERO ADDRESS");
        _unicToken = IUnicToken(unicTokenAddress);
        _teamAddress = teamAddress;
        _setLastMintTime(mintTime);
        _isFirstDayETHTaken = false;
    }

    function getUnicAddress() external view returns (address) {
        return address(_unicToken);
    } 

    function getDailyTotalStakes(uint256 index) external view returns (uint256) {
        return _stakeTimes[index];
    }

    function getStakeTimesLength() external view returns (uint256) {
        return _stakeTimes.length;
    }

    function getTeamInfo() external onlyOwner view returns (uint256, address) {
        return (_teamETHShare, _teamAddress);
    }

    function getLastLpUnlockTime(uint256 stakeTime, address user) external view returns (uint256) {
        return _LPStakes[stakeTime][user].lastUnlockTime;
    }

    function getAccumulativeUnic() external view returns (uint256) {
        return _accumulativeStakedUnic[getLastStakeTime()];
    }

    function getAccumulativeLP() external view returns (uint256) {
        return _accumulativeStakedLP[getLastLPStakeTime()];
    }

    function getMintTimesLength() external view returns (uint256) {
        return _mintTimes.length;
    }

    function getParticipatedETHAmount(uint256 mintTime, address user) external view returns (uint256) {
        return _dailyParticipatedETH[mintTime][user];
    }

    function getStakedUnic(uint256 stakeTime, address user) external view returns (uint256) {
        return _dailyStakedUnic[stakeTime][user];
    }

    function getStakedLP(uint256 stakeTime, address user) external view returns (uint256) {
        return _LPStakes[stakeTime][user].amount;
    }

    // function getDailyTotalStakedLP(uint256 stakeTime) external view returns (uint256) {
    //     return accumulativeStakedLP[stakeTime];
    // }

    function getTotalParticipateAmount(address user) external view returns (uint256) {
        uint256 totalEth;
        for (uint256 i = 0; i < _mintTimes.length; i++) {
            totalEth = totalEth.add(_dailyParticipatedETH[_mintTimes[i]][user]);
        }
        return totalEth;
    }

    function canUnlockTokens(uint256 mintTime, address user) external view returns (uint256) {
        if (_dailyTotalParticipatedETH[mintTime] > 0) {
            uint256 unicSharePayout = DAILY_MINT_CAP.div(_dailyTotalParticipatedETH[mintTime]);
            return _dailyParticipatedETH[mintTime][user].mul(unicSharePayout);
        }
        return 0;
    }

    function canUnstake(uint256 stakeTime, address user) external view returns (uint256) {
        if (_dailyStakedUnic[stakeTime][user] > 0 && stakeTime.add(SECONDS_IN_DAY) < block.timestamp) {
            return _calculateUnicStakeReward(stakeTime, user);
        }
        return 0;
    }

    function canUnlockLPReward(uint256 stakeTime, address user) external view returns (uint256) {
        if (_LPStakes[stakeTime][user].amount > 0) {
            uint256 lpStakeReward;
            (lpStakeReward,) = _calculateLPStakeReward(stakeTime);
            return lpStakeReward;
            
        }
        return 0;
    }

    function getLastMintTime() public view returns (uint256) {
        return _mintTimes[_mintTimes.length - 1];
    }

    function getLastStakeTime() public view returns (uint256) {
        if (_stakeTimes.length > 0) {
            return _stakeTimes[_stakeTimes.length - 1];
        }
        return 0;
    }

    function getLastLPStakeTime() public view returns (uint256) {
        if (_lpStakeTimes.length > 0) {
            return _lpStakeTimes[_lpStakeTimes.length - 1];
        }
        return 0;
    }

    function takeTeamETHShare() external onlyOwner {
        uint256 teamETHShare = _teamETHShare;
        _teamETHShare = 0;
        if(!_isFirstDayETHTaken) {
            _unicToken.mint(DAILY_MINT_CAP);
            teamETHShare = teamETHShare.add(_dailyTotalParticipatedETH[_mintTimes[1]].mul(95).div(100));
            _unicToken.transfer(_teamAddress, DAILY_MINT_CAP);
            _isFirstDayETHTaken = true;
        }
        _teamAddress.transfer(teamETHShare);
    }

    function participate() external payable {
        require(msg.value > 0, "Insufficient participation");
        uint256 lastMintTime = getLastMintTime();
        if (lastMintTime.add(SECONDS_IN_DAY) <= block.timestamp) {
            uint256 newLastMintTime = lastMintTime.add(((block.timestamp.sub(lastMintTime)).div(SECONDS_IN_DAY)).mul(SECONDS_IN_DAY));
            _startNextRound(newLastMintTime);
            lastMintTime = getLastMintTime();
        }
        _dailyTotalParticipatedETH[lastMintTime] = _dailyTotalParticipatedETH[lastMintTime].add(msg.value);
        _dailyParticipatedETH[lastMintTime][_msgSender()] = _dailyParticipatedETH[lastMintTime][_msgSender()].add(msg.value);
        _teamETHShare = _teamETHShare.add(msg.value.div(20));
    }

    function unlockTokens(uint256 mintTime, address user) external {
        require(_dailyParticipatedETH[mintTime][user] > 0, "Nothing to unlock");
        require(mintTime.add(SECONDS_IN_DAY) < block.timestamp);
        uint256 participatedAmount = _dailyParticipatedETH[mintTime][user];
        delete _dailyParticipatedETH[mintTime][user];
        uint256 unicSharePayout = DAILY_MINT_CAP.div(_dailyTotalParticipatedETH[mintTime]);
        _unicToken.transfer(user, participatedAmount.mul(unicSharePayout));
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Invalid stake amount");
        uint256 stakeTime = _getRightStakeTime();
        uint256 lastStakeTime = getLastStakeTime();
        if (stakeTime > lastStakeTime) {
            _accumulativeStakedUnic[stakeTime] = _accumulativeStakedUnic[lastStakeTime];
        }
        _accumulativeStakedUnic[stakeTime] = _accumulativeStakedUnic[stakeTime].add(amount);
        _dailyStakedUnic[stakeTime][_msgSender()] = _dailyStakedUnic[stakeTime][_msgSender()].add(amount);
        _stakeTimes.push(stakeTime);
        uint256 fivePercentOfStake = amount.div(20);
        _unicToken.transferFrom(_msgSender(), address(this), amount);
        _unicToken.burn(amount.sub(fivePercentOfStake));
        emit Stake(amount, stakeTime, _msgSender());
    }

    function unstake(uint256 stakeTime, address payable user) external {
        require(_dailyStakedUnic[stakeTime][user] > 0, "Nothing to unstake");
        require(stakeTime.add(SECONDS_IN_DAY) < block.timestamp, 'At least 1 day must pass');
        uint256 unstakeRewardAmount = _calculateUnicStakeReward(stakeTime, user);
        uint256 lastStakeTime = getLastStakeTime();
        delete _dailyStakedUnic[stakeTime][user];
        user.transfer(unstakeRewardAmount);
        _accumulativeStakedUnic[lastStakeTime] = _accumulativeStakedUnic[lastStakeTime].sub(_dailyStakedUnic[stakeTime][user]);
        emit Unstake(unstakeRewardAmount, stakeTime, user);
    }

    function stakeLP(address token, uint256 amount) external {
        require(_unicToken.isBlacklisted(token), 'Token is not supported');
        require(amount > 0, "Invalid stake amount");
        uint256 stakeTime = _getRightStakeTime();
        uint256 lastLPStakeTime = getLastLPStakeTime();
        if (stakeTime > lastLPStakeTime) {
            _accumulativeStakedLP[stakeTime] = _accumulativeStakedLP[lastLPStakeTime];
        }
        _accumulativeStakedLP[stakeTime] = _accumulativeStakedLP[stakeTime].add(amount);
        LPStake storage staker = _LPStakes[stakeTime][_msgSender()];
        staker.amount = staker.amount.add(amount);
        staker.lastUnlockTime = stakeTime;
        _lpStakeTimes.push(stakeTime);
        IERC20(token).transferFrom(_msgSender(), address(this), amount);
    }

    function unlockLPReward(uint256 stakeTime, address user) external {
        require(_LPStakes[stakeTime][user].amount > 0, "Nothing to unlock");
        uint256 lpStakeReward;
        uint256 lastStakeTime;
        (lpStakeReward, lastStakeTime) = _calculateLPStakeReward(stakeTime);
        _LPStakes[stakeTime][user].lastUnlockTime = lastStakeTime;
        _unicToken.transfer(user, lpStakeReward);
    }

    function _getRightStakeTime() private view returns(uint256) {
        uint256 lastMintTime = getLastMintTime();
        if (lastMintTime.add(SECONDS_IN_DAY) <= block.timestamp) {
            uint256 newStakeTime = lastMintTime.add(((block.timestamp.sub(lastMintTime)).div(SECONDS_IN_DAY)).mul(SECONDS_IN_DAY));
            return newStakeTime;
        }
        return lastMintTime;
    }


    function _calculateUnicStakeReward(uint256 stakeTime, address user) private view returns (uint256) {
        uint256 unicStakeReward;
        uint256 accumulativeDailyStakedUnic = _accumulativeStakedUnic[stakeTime];
        uint256 amountStaked = _dailyStakedUnic[stakeTime][user];
        for (uint256 i = stakeTime; i <= block.timestamp && i < stakeTime.add(SECONDS_IN_DAY * 100); i += SECONDS_IN_DAY) {
            if (_dailyTotalParticipatedETH[i] > 0) {
                accumulativeDailyStakedUnic = _accumulativeStakedUnic[i] == 0 ? accumulativeDailyStakedUnic : _accumulativeStakedUnic[i];
                unicStakeReward = unicStakeReward.add(
                    _dailyTotalParticipatedETH[i]
                        .mul(amountStaked)
                        .div(accumulativeDailyStakedUnic)
                );
            }
        }
        return unicStakeReward.mul(95).div(100);
    }

    function _calculateLPStakeReward(uint256 stakeTime) private view returns (uint256, uint256) {
        uint256 lpStakeReward;
        uint256 accumulativeDailyStakedLP = _accumulativeStakedLP[stakeTime];
        uint256 amountStaked = _LPStakes[stakeTime][_msgSender()].amount;
        uint256 lastUnlockTime = _LPStakes[stakeTime][_msgSender()].lastUnlockTime;
        for (;lastUnlockTime <= block.timestamp ;) {
            accumulativeDailyStakedLP = _accumulativeStakedLP[lastUnlockTime] == 0 ? accumulativeDailyStakedLP : _accumulativeStakedLP[lastUnlockTime];
            if (_dailyTotalParticipatedETH[lastUnlockTime] > 0) {
                lpStakeReward = lpStakeReward.add(
                    DAILY_MINT_CAP
                        .div(20)
                        .mul(amountStaked)
                        .div(accumulativeDailyStakedLP)
                );
            }
            if (gasleft() < 100000) {
                return(lpStakeReward, lastUnlockTime.sub(SECONDS_IN_DAY));
            }
            lastUnlockTime = lastUnlockTime.add(SECONDS_IN_DAY);
        }
        return (lpStakeReward, lastUnlockTime.sub(SECONDS_IN_DAY));
    }

    function _setLastMintTime(uint256 mintTime) private {
        _mintTimes.push(mintTime);
    }

    function _startNextRound(uint256 startTime) private {
        _setLastMintTime(startTime);
        _unicToken.mint(DAILY_MINT_CAP);
    }
}
