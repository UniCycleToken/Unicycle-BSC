pragma solidity >= 0.6.0 < 0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Interfaces.sol";


contract Auction is Context, Ownable {
    using SafeMath for uint256;

    struct AuctionParticipant {
        address payable participantAddress;
        uint256 amountETHParticipated;
    }

    struct Stake {
        uint256 unicStaked;
        uint256 ethReward;
        uint256 stakeEndTime;
    }

    struct Staker {
        address stakerAddress;
        Stake[] stakes;
    }

    struct LPStaker {
        address lpStakerAddress;
        uint256 lpStaked;
    }

    LPStaker[] public lpStakers;
    mapping(address => uint256) lpStakersIds;

    Staker[] public activeStakers;
    mapping(address => uint256) activeStakersIds;

    uint256 public _totalStakedLP;
    uint256 public _totalStakedUnic;
    uint256 public _totalAuctionedETH;

    IUnicToken internal _unicToken;

    uint256 public MINT_CAP_UNIC_CONST = 2500000 * (10 ** 18);
    AuctionParticipant[] public participants;


    constructor (address unicTokenAddress) public {
        _unicToken = IUnicToken(unicTokenAddress);
    }

    function getLPStakeInfo() external view returns (address, uint256) {
        return (lpStakers[lpStakersIds[_msgSender()] - 1].lpStakerAddress, lpStakers[lpStakersIds[_msgSender()] - 1].lpStaked);
    }

    function getNumOfLPStakers() external view returns (uint256) {
        return lpStakers.length;
    }

    function getActiveStaterInfo() external view returns (address, uint256) {
        return (activeStakers[activeStakersIds[_msgSender()] - 1].stakerAddress, activeStakers[activeStakersIds[_msgSender()] - 1].stakes.length);
    }

    function getNumOfActiveStakers() external view returns (uint256) {
        return activeStakers.length;
    }

    function getNumOfStakes() external view returns (uint256) {
        require(activeStakersIds[_msgSender()] > 0, "No stakes");
        return activeStakers[activeStakersIds[_msgSender()] - 1].stakes.length;
    }

    function getStakerId() external view returns (uint256) {
        return activeStakersIds[_msgSender()];
    }

    function getStakeInfo(uint256 stakeIndex) external view returns (uint256, uint256, uint256) {
        Stake memory stakeInfo = activeStakers[activeStakersIds[_msgSender()] - 1].stakes[stakeIndex];
        return (stakeInfo.unicStaked, stakeInfo.ethReward, stakeInfo.stakeEndTime);
    }

    function getAuctionInfo() external view onlyOwner returns (address, uint256) {
        return (address(_unicToken), _totalAuctionedETH);
    }

    function participate() external payable {
        _totalAuctionedETH = _totalAuctionedETH.add(msg.value);
        AuctionParticipant memory participant;
        participant.participantAddress = _msgSender();
        participant.amountETHParticipated = msg.value;
        participants.push(participant);
    }

    function stake(uint256 amount, uint256 duration) external {
        // check for balance and allowance
        require(duration <= 100, "Cant stake more than 100 days");
        require(amount <= _unicToken.balanceOf(_msgSender()), "Insufficient balance");
        require(_unicToken.allowance(_msgSender(), address(this)) >= amount, "Insufficient allowance");
        // add to address aray for later ethReward payout
        uint256 id = activeStakersIds[_msgSender()];
        if (id == 0) {
            activeStakers.push();
            id = activeStakers.length;
            activeStakersIds[_msgSender()] = id;
            activeStakers[id - 1].stakerAddress = _msgSender();
        }
        // modify stakers
        Staker storage staker = activeStakers[id - 1];
        Stake memory newStake;
        newStake.unicStaked = amount;
        newStake.stakeEndTime = block.timestamp.add(duration.mul(86400));
        staker.stakes.push(newStake);
        // modify storage
        _totalStakedUnic = _totalStakedUnic.add(amount);
        // TODO: transfer 5% to LP stakers or do it in unlock function
        uint256 fivePercentForLPStakers = amount.div(20);
        //transfer tokens for later burn
        _unicToken.transferFrom(_msgSender(), address(this), amount);
        for (uint256 i = 0; i < lpStakers.length; i++) {
            uint256 unicTokensToAddToEachLPStaker = (fivePercentForLPStakers.mul(lpStakers[i].lpStaked)).div(_totalStakedLP);
            _unicToken.transfer(lpStakers[i].lpStakerAddress, unicTokensToAddToEachLPStaker);
        }
    }

    function unStake(uint256 stakeIndex) external {
        Staker storage currentStaker = activeStakers[activeStakersIds[_msgSender()] - 1];
        require(currentStaker.stakes[stakeIndex].unicStaked > 0, "No stake with this index");

        _msgSender().transfer(currentStaker.stakes[stakeIndex].ethReward);
        if (stakeIndex != currentStaker.stakes.length - 1) {
            currentStaker.stakes[stakeIndex] = currentStaker.stakes[currentStaker.stakes.length - 1];
            currentStaker.stakes.pop();
        } else {
            currentStaker.stakes.pop();
        }
        if (currentStaker.stakes.length == 0) {
            if (activeStakers.length > 1) {
                currentStaker.stakerAddress = activeStakers[activeStakers.length - 1].stakerAddress;
                currentStaker.stakes = activeStakers[activeStakers.length - 1].stakes;
                activeStakersIds[activeStakers[activeStakers.length - 1].stakerAddress] = activeStakersIds[_msgSender()];
            }
            delete activeStakersIds[_msgSender()];
            activeStakers.pop();
        }
    }

    function LPStake(address token, uint256 amount) external {
        require(_unicToken.getIsBlackListed(token), "Token not added");
        uint256 id = lpStakersIds[_msgSender()];
        if (id == 0) {
            lpStakers.push();
            id = lpStakers.length;
            lpStakersIds[_msgSender()] = id;
            lpStakers[id - 1].lpStakerAddress = _msgSender();
        }
        lpStakers[id - 1].lpStaked = lpStakers[id - 1].lpStaked.add(amount);
        _totalStakedLP = _totalStakedLP.add(amount);
    }

    function unlockTokens() public {
        require(_totalAuctionedETH > 0, "No participants");
        uint256 unicPercentPayout = MINT_CAP_UNIC_CONST.div(_totalAuctionedETH);
        for (uint256 i = 0; i < participants.length; i++) {
            _unicToken.transfer(participants[i].participantAddress, participants[i].amountETHParticipated.mul(unicPercentPayout));
        }
        uint256 fivePercentOfETH = _totalAuctionedETH.div(20);
        if (_totalAuctionedETH > 0) {
        // TODO: send to team fivePercentOfETH
        // stakers 95% eth payout
            if (activeStakers.length > 0) {
                for (uint256 i = 0; i < activeStakers.length; i++) {
                    Staker storage currentStaker = activeStakers[i];
                    for (uint j = 0; j < currentStaker.stakes.length; j++) {
                        if (currentStaker.stakes[j].stakeEndTime > block.timestamp) {
                            uint256 currentEthReward = (_totalAuctionedETH.sub(fivePercentOfETH)).mul(10 ** 18).div(_totalStakedUnic).mul(currentStaker.stakes[j].unicStaked);
                            currentStaker.stakes[j].ethReward = currentStaker.stakes[j].ethReward.add(currentEthReward.div(10 ** 18));
                        }
                    }
                }
            }
        }
        delete participants;
        _totalAuctionedETH = 0;
        _totalStakedUnic = 0;
        uint256 balanceToBurn = _unicToken.balanceOf(address(this));
        _unicToken.burn(balanceToBurn);
        _unicToken.mint(MINT_CAP_UNIC_CONST);
    }
}
