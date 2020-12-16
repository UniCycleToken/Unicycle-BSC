pragma solidity >= 0.6.0 < 0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Interfaces.sol";


contract Auction is Context, Ownable {
    using SafeMath for uint256;

    // TODO AuctionParticipant -> Auctioneer ??? (Participant)
    struct AuctionParticipant {
        address payable participantAddress;
        uint256 amountETHParticipated;
    }

    struct Stake {
        // TODO unic -> UNIC
        uint256 unicStaked;
        uint256 ethReward;
        uint256 stakeEndTime;
    }

    struct Staker {
        uint256 stakeAmount;
        uint256 stakeStartTime;
    }

    struct LPStaker {
        address lpStakerAddress;
        uint256 lpStaked;
    }

    LPStaker[] public lpStakers;
    mapping(address => uint256) public lpStakersIds;

    Staker[] public activeStakers;
    mapping(address => uint256) public activeStakersIds;

    uint256 public _totalStakedLP;
    uint256 public _totalStakedUnic;
    // TODO ??
    IUnicToken internal _unicToken;

    uint256 public constant DAILY_MINT_CAP = 2_500_000_000_000_000_000_000_000;
    uint256 public constant PERCENT_100 = 10 ** 18;

    AuctionParticipant[] public participants;

    uint256[] public mintTimes;
    mapping(uint256 => mapping(address => uint256)) public dailyStakedUnic;
    mapping(uint256 => mapping(address => uint256)) public dailyParticipatedETH;
    mapping(uint256 => uint256) public dailyTotalStakedUnic;
    mapping(uint256 => uint256) public dailyTotalParticipatedETH;
    
    modifier hasStakes(address account) {
        require(activeStakersIds[account] > 0, "No stakes");
        _;
    }

    constructor (address unicTokenAddress, uint256 mintTime) public {
        require(unicTokenAddress != 0x0000000000000000000000000000000000000000, 'ZERO ADDRESS');
        _unicToken = IUnicToken(unicTokenAddress);
        setLastMintTime(mintTime);
    }

    function getMintTimestamp(uint256 index) external view returns(uint256) {
        return mintTimes[index];
    } 

    function canUnlockTokens(uint256 mintTime) external view returns(uint256) {
        return dailyParticipatedETH[mintTime][_msgSender()];
    }

    function getLastMintTime() public view returns(uint256) {
        return mintTimes[mintTimes.length - 1];
    }

    function getMintTimesLength() public view returns(uint256) {
        return mintTimes.length;
    }

    function setLastMintTime(uint256 mintTime) internal {
        mintTimes.push(mintTime);
    }

    function getParticipatedETHAmount(uint256 mintTime) public view returns(uint256) {
        return dailyParticipatedETH[mintTime][_msgSender()];
    }

    function getDailyTotalStakedUnic(uint256 stakeTime) external view returns(uint256) {
        return dailyTotalStakedUnic[stakeTime];
    }

    function getStakedUnic(uint256 stakeTime) external view returns(uint256) {
        return dailyStakedUnic[stakeTime][_msgSender()];
    }

    function startAuction(uint256 startTime) internal  {
        setLastMintTime(startTime);
        _unicToken.mint(DAILY_MINT_CAP);
    }

    function participate() external payable {
        require(msg.value > 0, 'Insufficient participation');
        if (getLastMintTime().add(86400) < now) {
            uint256 newLastMintTime = getLastMintTime().add(((now.sub(getLastMintTime())).div(86400)).mul(86400));
            startAuction(newLastMintTime);
        }
        dailyTotalParticipatedETH[getLastMintTime()] = dailyTotalParticipatedETH[getLastMintTime()].add(msg.value);
        dailyParticipatedETH[getLastMintTime()][_msgSender()] = dailyParticipatedETH[getLastMintTime()][_msgSender()].add(msg.value);
    }

    function unlockTokens(uint256 mintTime) public {
        require(dailyParticipatedETH[mintTime][_msgSender()] > 0, 'Nothing to unlock');
        uint256 unicPercentPayout = DAILY_MINT_CAP.div(dailyTotalParticipatedETH[mintTime]);
        _unicToken.transfer(_msgSender(), dailyParticipatedETH[mintTime][_msgSender()].mul(unicPercentPayout));
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Invalid stake amount");
        uint256 stakeTime;
        if (getLastMintTime().add(86400) <= now) {
            stakeTime = getLastMintTime().add(((now.sub(getLastMintTime())).div(86400)).mul(86400));
        } else {
            stakeTime = getLastMintTime();
        }
        dailyTotalStakedUnic[stakeTime] = dailyTotalStakedUnic[stakeTime].add(amount);
        dailyStakedUnic[stakeTime][_msgSender()] = dailyStakedUnic[stakeTime][_msgSender()].add(amount);
        uint256 fivePercentOfStake = amount.div(20);
        _unicToken.transferFrom(_msgSender(), address(this), amount);
        _unicToken.burn(amount.sub(fivePercentOfStake));
    }

    function unStake(uint256 stakeTime) external {
        require(dailyStakedUnic[stakeTime][_msgSender()] > 0, "Nothing to unstake");
        require(stakeTime.add(86400) < now, 'At least 1 day must pass');
        uint256 i;
        uint256 totalStakeEarnings;
        for (i = stakeTime; i <= now && i < stakeTime.add(86400 * 100); i += 86400) {
            if (dailyTotalParticipatedETH[i] > 0) {
                uint256 stakeEarningsPercent = dailyStakedUnic[stakeTime][_msgSender()]
                    .mul(PERCENT_100)
                    // .div(dailyTotalStakedUnic[i])
                    .div(dailyTotalStakedUnic[i] > 0 ? dailyTotalStakedUnic[i].add(stakeTime != i ? dailyTotalStakedUnic[stakeTime] : 0) : dailyTotalStakedUnic[stakeTime])
                    .mul(100)
                    .div(PERCENT_100);
                uint256 stakersETHShare = dailyTotalParticipatedETH[i] - dailyTotalParticipatedETH[i].div(20);
                totalStakeEarnings = totalStakeEarnings.add(
                    stakersETHShare
                        .mul(PERCENT_100)
                        .div(100)
                        .mul(stakeEarningsPercent)
                        .div(PERCENT_100)
                );
            }
        }
        delete dailyStakedUnic[stakeTime][_msgSender()];
        _msgSender().transfer(totalStakeEarnings);
    }

    // function stake(uint256 amount, uint256 duration) external {
    //     // check for balance and allowance
    //     require(duration <= 100, "Cant stake more than 100 days");
    //     require(amount <= _unicToken.balanceOf(_msgSender()), "Insufficient balance");
    //     require(_unicToken.allowance(_msgSender(), address(this)) >= amount, "Insufficient allowance");
    //     // add to address aray for later ethReward payout
    //     uint256 id = activeStakersIds[_msgSender()];
    //     if (id == 0) {
    //         activeStakers.push();
    //         id = activeStakers.length;
    //         activeStakersIds[_msgSender()] = id;
    //         activeStakers[id - 1].stakerAddress = _msgSender();
    //     }
    //     // modify stakers
    //     Staker storage staker = activeStakers[id - 1];
    //     Stake memory newStake;
    //     newStake.unicStaked = amount;
    //     newStake.stakeEndTime = block.timestamp.add(duration.mul(86400));
    //     staker.stakes.push(newStake);
    //     // modify storage
    //     _totalStakedUnic = _totalStakedUnic.add(amount);
    //     // TODO: transfer 5% to LP stakers or do it in unlock function
    //     uint256 fivePercentForLPStakers = amount.div(20);
    //     //transfer tokens for later burn
    //     _unicToken.transferFrom(_msgSender(), address(this), amount);
    //     for (uint256 i = 0; i < lpStakers.length; i++) {
    //         uint256 unicTokensToAddToEachLPStaker = (fivePercentForLPStakers.mul(lpStakers[i].lpStaked)).div(_totalStakedLP);
    //         _unicToken.transfer(lpStakers[i].lpStakerAddress, unicTokensToAddToEachLPStaker);
    //     }
    // }

    // function unlockTokens() public {
    //     // TODO participant can participate 0 eth, check participate
    //     require(_totalAuctionedETH > 0, "No participants");
    //     uint256 unicPercentPayout = DAILY_MINT_CAP.div(_totalAuctionedETH);
    //     // TODO each user should take it by self
    //     // eth also user should take by self
    //     // (any) -> 
    //     for (uint256 i = 0; i < participants.length; i++) {
    //         _unicToken.transfer(participants[i].participantAddress, participants[i].amountETHParticipated.mul(unicPercentPayout));
    //     }
    //     uint256 fivePercentOfETH = _totalAuctionedETH.div(20);
    //     // TODO: send to team fivePercentOfETH
    //     // stakers 95% eth payout
    //     if (activeStakers.length > 0) {
    //         for (uint256 i = 0; i < activeStakers.length; i++) {
    //             Staker storage currentStaker = activeStakers[i];
    //             for (uint j = 0; j < currentStaker.stakes.length; j++) {
    //                 if (currentStaker.stakes[j].stakeEndTime > block.timestamp) {
    //                     uint256 currentEthReward = (_totalAuctionedETH.sub(fivePercentOfETH)).mul(10 ** 18).div(_totalStakedUnic).mul(currentStaker.stakes[j].unicStaked);
    //                     currentStaker.stakes[j].ethReward = currentStaker.stakes[j].ethReward.add(currentEthReward.div(10 ** 18));
    //                 }
    //             }
    //         }
    //     }
    //     delete participants;
    //     _totalAuctionedETH = 0;
    //     _totalStakedUnic = 0;
    //     uint256 balanceToBurn = _unicToken.balanceOf(address(this));
    //     _unicToken.burn(balanceToBurn);
    //     _unicToken.mint(DAILY_MINT_CAP);
    // }

    // function getLPStakeInfo() external view returns (address, uint256) {
    //     return (lpStakers[lpStakersIds[_msgSender()] - 1].lpStakerAddress, lpStakers[lpStakersIds[_msgSender()] - 1].lpStaked);
    // }

    // function getNumOfLPStakers() external view returns (uint256) {
    //     return lpStakers.length;
    // }

    // // TODO getNumOfActiveStakers -> getActiveStakersCount
    // function getNumOfActiveStakers() external view returns (uint256) {
    //     return activeStakers.length;
    // }

    // // TODO ^
    // function getNumOfStakes() external view hasStakes(_msgSender()) returns (uint256) {
    //     return activeStakers[activeStakersIds[_msgSender()] - 1].stakes.length;
    // }

    // function getStakeInfo(uint256 stakeIndex) external view returns (uint256, uint256, uint256) {
    //     Stake memory stakeInfo = activeStakers[activeStakersIds[_msgSender()] - 1].stakes[stakeIndex];
    //     return (stakeInfo.unicStaked, stakeInfo.ethReward, stakeInfo.stakeEndTime);
    // }

    // function getAuctionInfo() external view onlyOwner returns (address, uint256) {
    //     return (address(_unicToken), _totalAuctionedETH);
    // }

    // function stake(uint256 amount, uint256 duration) external {
    //     // check for balance and allowance
    //     require(duration <= 100, "Cant stake more than 100 days");
    //     require(amount <= _unicToken.balanceOf(_msgSender()), "Insufficient balance");
    //     require(_unicToken.allowance(_msgSender(), address(this)) >= amount, "Insufficient allowance");
    //     // add to address aray for later ethReward payout
    //     uint256 id = activeStakersIds[_msgSender()];
    //     if (id == 0) {
    //         activeStakers.push();
    //         id = activeStakers.length;
    //         activeStakersIds[_msgSender()] = id;
    //         activeStakers[id - 1].stakerAddress = _msgSender();
    //     }
    //     // modify stakers
    //     Staker storage staker = activeStakers[id - 1];
    //     Stake memory newStake;
    //     newStake.unicStaked = amount;
    //     newStake.stakeEndTime = block.timestamp.add(duration.mul(86400));
    //     staker.stakes.push(newStake);
    //     // modify storage
    //     _totalStakedUnic = _totalStakedUnic.add(amount);
    //     // TODO: transfer 5% to LP stakers or do it in unlock function
    //     uint256 fivePercentForLPStakers = amount.div(20);
    //     //transfer tokens for later burn
    //     _unicToken.transferFrom(_msgSender(), address(this), amount);
    //     for (uint256 i = 0; i < lpStakers.length; i++) {
    //         uint256 unicTokensToAddToEachLPStaker = (fivePercentForLPStakers.mul(lpStakers[i].lpStaked)).div(_totalStakedLP);
    //         _unicToken.transfer(lpStakers[i].lpStakerAddress, unicTokensToAddToEachLPStaker);
    //     }
    // }

    // function unStake(uint256 stakeIndex) external hasStakes(_msgSender()) {
    //     Staker storage currentStaker = activeStakers[activeStakersIds[_msgSender()] - 1];
    //     _msgSender().transfer(currentStaker.stakes[stakeIndex].ethReward);
    //     if (stakeIndex != currentStaker.stakes.length - 1) {
    //         currentStaker.stakes[stakeIndex] = currentStaker.stakes[currentStaker.stakes.length - 1];
    //         currentStaker.stakes.pop();
    //     } else {
    //         currentStaker.stakes.pop();
    //     }
    //     if (currentStaker.stakes.length == 0) {
    //         if (activeStakers.length > 1) {
    //             currentStaker.stakerAddress = activeStakers[activeStakers.length - 1].stakerAddress;
    //             currentStaker.stakes = activeStakers[activeStakers.length - 1].stakes;
    //             activeStakersIds[activeStakers[activeStakers.length - 1].stakerAddress] = activeStakersIds[_msgSender()];
    //         }
    //         delete activeStakersIds[_msgSender()];
    //         activeStakers.pop();
    //     }
    // }

    // function LPStake(address token, uint256 amount) external {
    //     require(_unicToken.isBlacklisted(token), "Token not added");
    //     uint256 id = lpStakersIds[_msgSender()];
    //     if (id == 0) {
    //         lpStakers.push();
    //         id = lpStakers.length;
    //         lpStakersIds[_msgSender()] = id;
    //         lpStakers[id - 1].lpStakerAddress = _msgSender();
    //     }
    //     lpStakers[id - 1].lpStaked = lpStakers[id - 1].lpStaked.add(amount);
    //     _totalStakedLP = _totalStakedLP.add(amount);
    // }
}
