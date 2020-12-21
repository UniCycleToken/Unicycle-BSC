pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Interfaces.sol";


contract Auction is Context, Ownable {
    using SafeMath for uint256;

    struct LPStaker {
        uint256 amountStaked;
        uint256 lastUnlockTime;
    }

    uint256 public constant DAILY_MINT_CAP = 2_500_000_000_000_000_000_000_000;
    uint256 public constant PERCENT_100 = 10**18;
    uint256 private constant SECONDS_IN_DAY = 86400;

    uint256[] private _mintTimes;
    uint256[] private _stakeTimes;
    uint256[] private _lpStakeTimes;

    mapping(uint256 => mapping(address => uint256)) private _dailyStakedUnic;
    mapping(uint256 => uint256) private _accumulativeStakedUnic;

    mapping(uint256 => mapping(address => uint256)) private _dailyParticipatedETH;
    mapping(uint256 => uint256) private _dailyTotalParticipatedETH;

    mapping(uint256 => mapping(address => LPStaker)) private _LPStakers;
    mapping(uint256 => uint256) private _accumulativeStakedLP;
   
    address payable private _teamAddress;
    uint256 private _teamETHShare;
    bool private _isFirstDayETHTaken;

    IUnicToken private _unicToken;

    constructor(address unicTokenAddress, uint256 mintTime, address payable teamAddress) public {
        require(unicTokenAddress != 0x0000000000000000000000000000000000000000, "ZERO ADDRESS");
        _unicToken = IUnicToken(unicTokenAddress);
        _teamAddress = teamAddress;
        _setLastMintTime(mintTime);
        _isFirstDayETHTaken = false;
    }

    function getTeamETHShare() external onlyOwner view returns (uint256) {
        return _teamETHShare;
    }

    function getTeamAddress() external onlyOwner view returns (address) {
        return _teamAddress;
    }

    function getLastLpUnlockTime(uint256 stakeTime) external view returns (uint256) {
        return _LPStakers[stakeTime][_msgSender()].lastUnlockTime;
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

    function getParticipatedETHAmount(uint256 mintTime) public view returns (uint256) {
        return _dailyParticipatedETH[mintTime][_msgSender()];
    }

    function getStakedUnic(uint256 stakeTime) external view returns (uint256) {
        return _dailyStakedUnic[stakeTime][_msgSender()];
    }

    function getStakedLP(uint256 stakeTime) external view returns (uint256) {
        return _LPStakers[stakeTime][_msgSender()].amountStaked;
    }

    // function getDailyTotalStakedLP(uint256 stakeTime) external view returns (uint256) {
    //     return accumulativeStakedLP[stakeTime];
    // }

    function getTotalParticipateAmount() external view returns (uint256) {
        uint256 totalEth;
        for (uint256 i = 0; i < _mintTimes.length; i++) {
            totalEth = totalEth.add(_dailyParticipatedETH[_mintTimes[i]][_msgSender()]);
        }
        return totalEth;
    }

    function canUnlockTokens(uint256 mintTime) external view returns (uint256) {
        if (_dailyTotalParticipatedETH[mintTime] > 0) {
            uint256 unicSharePayout = DAILY_MINT_CAP.div(_dailyTotalParticipatedETH[mintTime]);
            return _dailyParticipatedETH[mintTime][_msgSender()].mul(unicSharePayout);
        }
        return 0;
    }

    function canUnStake(uint256 stakeTime) external view returns (uint256) {
        if (_dailyStakedUnic[stakeTime][_msgSender()] > 0 && stakeTime.add(SECONDS_IN_DAY) < now) {
            return _calculateUnicStakeReward(stakeTime);
        }
        return 0;
    }

    function canUnlockLPReward(uint256 stakeTime) external view returns (uint256) {
        if (_LPStakers[stakeTime][_msgSender()].amountStaked > 0) {
            return _calculateLPStakeReward(stakeTime);
            
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

    function participate() external payable {
        require(msg.value > 0, "Insufficient participation");
        uint256 lastMintTime = getLastMintTime();
        if (lastMintTime.add(SECONDS_IN_DAY) <= now) {
            uint256 newLastMintTime = lastMintTime.add(((now.sub(lastMintTime)).div(SECONDS_IN_DAY)).mul(SECONDS_IN_DAY));
            _startNextRound(newLastMintTime);
            lastMintTime = getLastMintTime();
        }
        _dailyTotalParticipatedETH[lastMintTime] = _dailyTotalParticipatedETH[lastMintTime].add(msg.value);
        _dailyParticipatedETH[lastMintTime][_msgSender()] = _dailyParticipatedETH[lastMintTime][_msgSender()].add(msg.value);
        _teamETHShare = _teamETHShare.add(msg.value.div(20));
    }

    function unlockTokens(uint256 mintTime) external {
        require(_dailyParticipatedETH[mintTime][_msgSender()] > 0, "Nothing to unlock");
        // require(mintTime.add(SECONDS_IN_DAY) < now);
        uint256 unicSharePayout = DAILY_MINT_CAP.div(_dailyTotalParticipatedETH[mintTime]);
        _unicToken.transfer(_msgSender(), _dailyParticipatedETH[mintTime][_msgSender()].mul(unicSharePayout));
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Invalid stake amount");
        uint256 stakeTime = _getRightStakeTime();
        if (stakeTime > getLastStakeTime()) {
            _accumulativeStakedUnic[stakeTime] = _accumulativeStakedUnic[stakeTime].add(_accumulativeStakedUnic[getLastStakeTime()]);
        }
        _accumulativeStakedUnic[stakeTime] = _accumulativeStakedUnic[stakeTime].add(amount);
        _dailyStakedUnic[stakeTime][_msgSender()] = _dailyStakedUnic[stakeTime][_msgSender()].add(amount);
        _stakeTimes.push(stakeTime);
        uint256 fivePercentOfStake = amount.div(20);
        _unicToken.transferFrom(_msgSender(), address(this), amount);
        _unicToken.burn(amount.sub(fivePercentOfStake));
    }

    function unStake(uint256 stakeTime) external {
        require(_dailyStakedUnic[stakeTime][_msgSender()] > 0, "Nothing to unstake");
        require(stakeTime.add(SECONDS_IN_DAY) < now, 'At least 1 day must pass');
        uint256 unStakeRewardAmount = _calculateUnicStakeReward(stakeTime);
        uint256 lastStakeTime = getLastStakeTime();
        delete _dailyStakedUnic[stakeTime][_msgSender()];
        _msgSender().transfer(unStakeRewardAmount);
        _accumulativeStakedUnic[lastStakeTime] = _accumulativeStakedUnic[lastStakeTime].sub(_dailyStakedUnic[stakeTime][_msgSender()]);
    }

    function stakeLP(address token, uint256 amount) external {
        require(_unicToken.isBlacklisted(token), 'Token is not supported');
        require(amount > 0, "Invalid stake amount");
        uint256 stakeTime = _getRightStakeTime();
        if (stakeTime > getLastLPStakeTime()) {
            _accumulativeStakedLP[stakeTime] = _accumulativeStakedLP[stakeTime].add(_accumulativeStakedLP[getLastLPStakeTime()]);
        }
        _accumulativeStakedLP[stakeTime] = _accumulativeStakedLP[stakeTime].add(amount);
        LPStaker storage staker = _LPStakers[stakeTime][_msgSender()];
        staker.amountStaked = staker.amountStaked.add(amount);
        staker.lastUnlockTime = stakeTime;
        _lpStakeTimes.push(stakeTime);
        ERC20(token).transferFrom(_msgSender(), address(this), amount);
    }

    function unlockLPReward(uint256 stakeTime) external {
        require(_LPStakers[stakeTime][_msgSender()].amountStaked > 0, "Nothing to unlock");
        uint256 lpStakeReward = _calculateLPStakeReward(stakeTime);
        _LPStakers[stakeTime][_msgSender()].lastUnlockTime = _getRightStakeTime();
        _unicToken.transfer(_msgSender(), lpStakeReward);
    }

    function _getRightStakeTime() private view returns(uint256) {
        uint256 lastMintTime = getLastMintTime();
        if (lastMintTime.add(SECONDS_IN_DAY) <= now) {
            uint256 newStakeTime = lastMintTime.add(((now.sub(lastMintTime)).div(SECONDS_IN_DAY)).mul(SECONDS_IN_DAY));
            return newStakeTime;
        }
        return lastMintTime;
    }


    function _calculateUnicStakeReward(uint256 stakeTime) private view returns (uint256) {
        uint256 unicStakeReward;
        uint256 accumulativeDailyStakedUnic = _accumulativeStakedUnic[stakeTime];
        for (uint256 i = stakeTime; i <= now && i < stakeTime.add(SECONDS_IN_DAY * 100); i += SECONDS_IN_DAY) {
            if (_dailyTotalParticipatedETH[i] > 0) {
                accumulativeDailyStakedUnic = _accumulativeStakedUnic[i] == 0 ? accumulativeDailyStakedUnic : _accumulativeStakedUnic[i];
                uint256 stakeEarningsPercent = _dailyStakedUnic[stakeTime][_msgSender()]
                    .mul(PERCENT_100)
                    .div(accumulativeDailyStakedUnic)
                    .mul(100)
                    .div(PERCENT_100);
                unicStakeReward = unicStakeReward.add(
                    _dailyTotalParticipatedETH[i]
                        .mul(PERCENT_100)
                        .div(100)
                        .mul(stakeEarningsPercent)
                        .div(PERCENT_100)
                );
            }
        }
        return unicStakeReward - unicStakeReward.div(20);
    }

    function _calculateLPStakeReward(uint256 stakeTime) private view returns (uint256) {
        uint256 lpStakeReward;
        uint256 accumulativeDailyStakedLP = _accumulativeStakedLP[stakeTime];
        for (uint256 i = _LPStakers[stakeTime][_msgSender()].lastUnlockTime; i <= now; i += SECONDS_IN_DAY) {
            accumulativeDailyStakedLP = _accumulativeStakedLP[i] == 0 ? accumulativeDailyStakedLP : _accumulativeStakedLP[i];
            if (_dailyTotalParticipatedETH[i] > 0) {
                uint256 lpRewardPercent = _LPStakers[stakeTime][_msgSender()].amountStaked
                    .mul(PERCENT_100)
                    .div(accumulativeDailyStakedLP)
                    .mul(100)
                    .div(PERCENT_100);
                lpStakeReward = lpStakeReward.add(
                    DAILY_MINT_CAP
                        .div(20)
                        .mul(PERCENT_100)
                        .div(100)
                        .mul(lpRewardPercent)
                        .div(PERCENT_100)
                );
            }
        }
        return lpStakeReward;
    }

    function _setLastMintTime(uint256 mintTime) private {
        _mintTimes.push(mintTime);
    }

    function _startNextRound(uint256 startTime) private {
        _setLastMintTime(startTime);
        _unicToken.mint(DAILY_MINT_CAP);
    }

    function _takeTeamETHShare() external onlyOwner {
        uint256 teamETHShare = _teamETHShare;
        _teamETHShare = 0;
        if(!_isFirstDayETHTaken) {
            _unicToken.mint(DAILY_MINT_CAP);
            teamETHShare = teamETHShare.add(_dailyTotalParticipatedETH[_mintTimes[1]] - _dailyTotalParticipatedETH[_mintTimes[1]].div(20));
            _unicToken.transfer(_teamAddress, DAILY_MINT_CAP);
            _isFirstDayETHTaken = true;
        }
        _teamAddress.transfer(teamETHShare);
    }
}
